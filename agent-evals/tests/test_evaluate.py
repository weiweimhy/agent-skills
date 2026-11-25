"""Repeatable CLI regression tests for routing and behavior score semantics."""

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SKILL_DIR = Path(__file__).resolve().parents[1]
SCRIPT = SKILL_DIR / "scripts" / "evaluate.py"
EXAMPLES = SKILL_DIR / "examples"


def base_run(version, case_results):
    return {
        "schema_version": version,
        "suite_id": "test-suite",
        "run_id": "test-run",
        "execution_mode": "fixture",
        "system_under_test": "synthetic test",
        "annotation_method": "synthetic_fixture",
        "case_results": case_results,
    }


def case_result(case_id, version, behaviors, skills=None, route=None):
    result = {
        "case_id": case_id,
        "observed_behaviors": behaviors,
        "evidence_ref": "fixture:test",
    }
    if version == 1:
        result["selected_route"] = route
    else:
        result["selected_skills"] = skills or []
    return result


def answer(case_id, version, required=None, expected_route=None, route_policy=None, expected_skills=None):
    result = {
        "case_id": case_id,
        "required_behaviors": required or [],
        "forbidden_behaviors": [],
    }
    if version == 1:
        result["expected_route"] = expected_route
    else:
        if route_policy is not None:
            result["route_policy"] = route_policy
        if expected_skills is not None:
            result["expected_skills"] = expected_skills
    return result


def run_cli(cases, key, run):
    with tempfile.TemporaryDirectory() as temp_dir:
        paths = {}
        for label, value in (("cases", cases), ("key", key), ("run", run)):
            path = Path(temp_dir) / (label + ".json")
            path.write_text(json.dumps(value), encoding="utf-8")
            paths[label] = path
        return subprocess.run(
            [
                sys.executable,
                str(SCRIPT),
                "--cases", str(paths["cases"]),
                "--key", str(paths["key"]),
                "--run", str(paths["run"]),
            ],
            check=False,
            capture_output=True,
            text=True,
        )


class EvaluateCliTests(unittest.TestCase):
    def test_explicit_invocation_requires_named_skill_and_allows_extras(self):
        cases = {
            "schema_version": 2,
            "suite_id": "test-suite",
            "cases": [{
                "case_id": "explicit",
                "evaluation_mode": "explicit_skill_invocation",
                "invoked_skill": "debugging",
                "task": "Use debugging to diagnose the startup failure.",
            }],
        }
        key = {
            "schema_version": 2,
            "suite_id": "test-suite",
            "answers": [answer("explicit", 2)],
        }
        passing_run = base_run(2, [case_result("explicit", 2, [], ["debugging", "observability"])])
        passing = run_cli(cases, key, passing_run)
        self.assertEqual(passing.returncode, 0, passing.stdout + passing.stderr)
        self.assertIn("Routing: 1/1", passing.stdout)

        failing_run = base_run(2, [case_result("explicit", 2, [], ["observability"])])
        failing = run_cli(cases, key, failing_run)
        self.assertEqual(failing.returncode, 1, failing.stdout + failing.stderr)
        self.assertIn("missing_skills=debugging", failing.stdout)

        exact_key = {
            "schema_version": 2,
            "suite_id": "test-suite",
            "answers": [answer(
                "explicit", 2, route_policy="exact", expected_skills=["debugging"]
            )],
        }
        exact = run_cli(cases, exact_key, passing_run)
        self.assertEqual(exact.returncode, 1, exact.stdout + exact.stderr)
        self.assertIn("unexpected_skills=observability", exact.stdout)

    def test_natural_zero_or_multiple_skills_are_informational_but_behavior_fails(self):
        cases = {
            "schema_version": 2,
            "suite_id": "test-suite",
            "cases": [
                {"case_id": "zero", "evaluation_mode": "natural_task", "task": "Convert abc to uppercase."},
                {"case_id": "many", "evaluation_mode": "natural_task", "task": "Plan a reproducible comparison."},
            ],
        }
        key = {
            "schema_version": 2,
            "suite_id": "test-suite",
            "answers": [
                answer("zero", 2, ["answers_directly"]),
                answer("many", 2, ["defines_baseline"]),
            ],
        }
        passing_run = base_run(2, [
            case_result("zero", 2, ["answers_directly"], []),
            case_result("many", 2, ["defines_baseline"], ["experiment", "backend-patterns"]),
        ])
        passing = run_cli(cases, key, passing_run)
        self.assertEqual(passing.returncode, 0, passing.stdout + passing.stderr)
        self.assertIn("Routing: not scored; 2 informational", passing.stdout)
        self.assertIn("Behavior: 2/2", passing.stdout)

        failing_run = base_run(2, [
            case_result("zero", 2, ["answers_directly"], []),
            case_result("many", 2, [], ["experiment", "backend-patterns"]),
        ])
        failing = run_cli(cases, key, failing_run)
        self.assertEqual(failing.returncode, 1, failing.stdout + failing.stderr)
        self.assertIn("Routing: not scored; 2 informational", failing.stdout)
        self.assertIn("Behavior: 1/2", failing.stdout)

    def test_exact_policy_can_require_zero_skills_but_must_declare_the_set(self):
        cases = {
            "schema_version": 2,
            "suite_id": "test-suite",
            "cases": [{"case_id": "zero-only", "evaluation_mode": "natural_task", "task": "Convert abc."}],
        }
        key = {
            "schema_version": 2,
            "suite_id": "test-suite",
            "answers": [answer(
                "zero-only", 2, route_policy="exact", expected_skills=[]
            )],
        }
        no_skills = run_cli(cases, key, base_run(2, [case_result("zero-only", 2, [], [])]))
        self.assertEqual(no_skills.returncode, 0, no_skills.stdout + no_skills.stderr)
        self.assertIn("Routing: 1/1", no_skills.stdout)

        with_skill = run_cli(
            cases, key, base_run(2, [case_result("zero-only", 2, [], ["debugging"])])
        )
        self.assertEqual(with_skill.returncode, 1, with_skill.stdout + with_skill.stderr)
        self.assertIn("unexpected_skills=debugging", with_skill.stdout)

        missing_set_key = {
            "schema_version": 2,
            "suite_id": "test-suite",
            "answers": [answer("zero-only", 2, route_policy="exact")],
        }
        missing_set = run_cli(cases, missing_set_key, base_run(2, [case_result("zero-only", 2, [], [])]))
        self.assertEqual(missing_set.returncode, 2, missing_set.stdout + missing_set.stderr)
        self.assertIn("'exact' routing requires 'expected_skills'", missing_set.stderr)

    def test_v1_fixture_and_strict_single_route_semantics_remain(self):
        legacy = EXAMPLES / "legacy-v1"
        command = [
            sys.executable,
            str(SCRIPT),
            "--cases", str(legacy / "cases.json"),
            "--key", str(legacy / "answer-key.json"),
            "--run", str(legacy / "fixture-run.json"),
        ]
        fixture = subprocess.run(command, check=False, capture_output=True, text=True)
        self.assertEqual(fixture.returncode, 0, fixture.stdout + fixture.stderr)
        self.assertIn("Routing: 4/4", fixture.stdout)

        cases = {
            "schema_version": 1,
            "suite_id": "test-suite",
            "cases": [{"case_id": "legacy", "task": "Do the task."}],
        }
        key = {
            "schema_version": 1,
            "suite_id": "test-suite",
            "answers": [answer("legacy", 1, expected_route="debugging")],
        }
        run = base_run(1, [case_result("legacy", 1, [], route="debugging,observability")])
        result = run_cli(cases, key, run)
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("Routing: 0/1", result.stdout)


if __name__ == "__main__":
    unittest.main()
