"""Regression tests for grouped repeated-run summaries."""

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SKILL_DIR = Path(__file__).resolve().parents[1]
SCRIPT = SKILL_DIR / "scripts" / "summarize_repeats.py"


def write_json(path, value):
    path.write_text(json.dumps(value), encoding="utf-8")


def make_run(run_id, evidence_mode, case_result):
    fixture = evidence_mode == "fixture"
    return {
        "schema_version": 2,
        "suite_id": "repeat-test",
        "run_id": run_id,
        "execution_mode": evidence_mode,
        "system_under_test": "synthetic test" if fixture else "model-x build 7",
        "annotation_method": "synthetic_fixture" if fixture else "human_review",
        "case_results": [case_result],
    }


def result(behaviors, evidence_ref="fixture:test", **extra):
    value = {
        "case_id": "case-1",
        "selected_skills": [],
        "observed_behaviors": behaviors,
        "evidence_ref": evidence_ref,
    }
    value.update(extra)
    return value


def execute(cases, key, manifest, run_files):
    with tempfile.TemporaryDirectory() as temp_dir:
        root = Path(temp_dir)
        cases_path = root / "cases.json"
        key_path = root / "key.json"
        manifest_path = root / "manifest.json"
        write_json(cases_path, cases)
        write_json(key_path, key)
        entries = []
        for index, (group, run_data) in enumerate(run_files):
            run_path = root / "run-{}.json".format(index)
            write_json(run_path, run_data)
            entries.append({"group": group, "run_file": run_path.name})
        manifest = dict(manifest)
        manifest["runs"] = entries
        write_json(manifest_path, manifest)
        return subprocess.run(
            [
                sys.executable,
                str(SCRIPT),
                "--cases", str(cases_path),
                "--key", str(key_path),
                "--runs", str(manifest_path),
            ],
            check=False,
            capture_output=True,
            text=True,
        )


class RepeatSummaryTests(unittest.TestCase):
    def setUp(self):
        self.cases = {
            "schema_version": 2,
            "suite_id": "repeat-test",
            "cases": [{
                "case_id": "case-1",
                "evaluation_mode": "natural_task",
                "task": "Answer the natural task.",
            }],
        }
        self.key = {
            "schema_version": 2,
            "suite_id": "repeat-test",
            "answers": [{
                "case_id": "case-1",
                "required_behaviors": ["completes_task"],
                "forbidden_behaviors": [],
            }],
        }

    def test_generic_groups_environment_gate_and_failed_costs(self):
        manifest = {
            "schema_version": 1,
            "suite_id": "repeat-test",
            "comparison_name": "optional strategy comparison",
            "groups": ["skill-disabled", "skill-enabled", "delegated+independent-review"],
        }
        key = json.loads(json.dumps(self.key))
        key["answers"][0]["required_environment_assertions"] = [
            {"name": "locale", "expected": "en-US"},
        ]
        runs = [
            ("skill-disabled", make_run("off-pass", "fixture", result(
                ["completes_task"],
                cost_usd=0.25,
                human_intervention=True,
                human_intervention_minutes=2,
                time_to_acceptance_seconds=90,
                environment_assertions=[{"name": "locale", "expected": "en-US", "actual": "en-US"}],
            ))),
            ("skill-disabled", make_run("off-env-fail", "fixture", result(
                ["completes_task"],
                cost_usd=0.15,
                human_intervention=False,
                human_intervention_minutes=0,
                environment_assertions=[{"name": "locale", "expected": "en-US", "actual": "zh-CN"}],
            ))),
            ("skill-enabled", make_run("on-pass", "fixture", result(
                ["completes_task"], cost_usd=0.40, human_intervention=False,
                human_intervention_minutes=0, time_to_acceptance_seconds=60,
                environment_assertions=[{"name": "locale", "expected": "en-US", "actual": "en-US"}],
            ))),
            ("delegated+independent-review", make_run("review-fail", "fixture", result(
                ["completes_task"], cost_usd=0.10, human_intervention=True,
                human_intervention_minutes=1,
            ))),
        ]
        completed = execute(self.cases, key, manifest, runs)
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("Groups: skill-disabled, skill-enabled, delegated+independent-review", completed.stdout)
        self.assertIn("case-1: success=1/2 behavior=2/2 route=info environment=1/2", completed.stdout)
        self.assertIn("Cost spent (USD; all attempts, including failures/rework): $0.4000", completed.stdout)
        self.assertIn("Average cost per passing attempt: $0.4000 per passing attempt, including all group failures", completed.stdout)
        self.assertIn("human intervention time (person-minutes): 2.00 min", completed.stdout.lower())
        self.assertIn("actual=\"zh-CN\" FAIL", completed.stdout)
        self.assertIn("review-fail / case-1 / delegated+independent-review]: locale expected=\"en-US\" actual=null UNKNOWN", completed.stdout)
        self.assertIn("case-1: success=0/1 behavior=1/1 route=info environment=0/1", completed.stdout)
        self.assertIn("Time to acceptance (wall-clock): 90.00s mean across 1 passing attempts", completed.stdout)

    def test_unknown_metrics_stay_unknown_and_evidence_is_separate(self):
        manifest = {
            "schema_version": 1,
            "suite_id": "repeat-test",
            "comparison_name": "direct versus delegated",
            "groups": ["direct", "delegated"],
        }
        live = make_run("direct-live", "live", result(
            ["completes_task"], evidence_ref="trace://run/direct/case-1",
        ))
        fixture = make_run("delegated-fixture", "fixture", result(
            ["completes_task"], cost_usd=0.20, human_intervention=False,
            human_intervention_minutes=0, time_to_acceptance_seconds=30,
        ))
        completed = execute(self.cases, self.key, manifest, [("direct", live), ("delegated", fixture)])
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("Evidence: LIVE", completed.stdout)
        self.assertIn("Evidence: FIXTURE", completed.stdout)
        self.assertIn("Time to acceptance (wall-clock): UNKNOWN", completed.stdout)
        self.assertIn("Cost spent (USD; all attempts, including failures/rework): UNKNOWN", completed.stdout)
        self.assertIn("known subtotal $0.0000 from 0/1 attempts", completed.stdout)
        self.assertIn("Human intervention time (person-minutes): UNKNOWN", completed.stdout)
        self.assertIn("Time to acceptance (wall-clock): UNKNOWN", completed.stdout)

    def test_explicit_invocation_uses_existing_v2_route_scoring(self):
        cases = {
            "schema_version": 2,
            "suite_id": "repeat-test",
            "cases": [{"case_id": "case-1", "evaluation_mode": "explicit_skill_invocation",
                       "invoked_skill": "debugging", "task": "Use debugging."}],
        }
        manifest = {
            "schema_version": 1,
            "suite_id": "repeat-test",
            "comparison_name": "direct versus delegated",
            "groups": ["direct", "delegated"],
        }
        runs = [
            ("direct", make_run("direct", "fixture", result(["completes_task"]))),
            ("delegated", make_run("delegated", "fixture", result(
                ["completes_task"], selected_skills=["debugging"],
            ))),
        ]
        completed = execute(cases, self.key, manifest, runs)
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("Group: direct", completed.stdout)
        self.assertIn("case-1: success=0/1 behavior=1/1 route=0/1", completed.stdout)
        self.assertIn("Group: delegated", completed.stdout)
        self.assertIn("case-1: success=1/1 behavior=1/1 route=1/1", completed.stdout)

    def test_environment_assertions_must_be_predeclared_in_key(self):
        manifest = {
            "schema_version": 1,
            "suite_id": "repeat-test",
            "comparison_name": "skill availability",
            "groups": ["disabled", "enabled"],
        }
        runs = [
            ("disabled", make_run("off", "fixture", result(
                ["completes_task"], environment_assertions=[
                    {"name": "python", "expected": "3.13", "actual": "3.13"},
                ],
            ))),
            ("enabled", make_run("on", "fixture", result(["completes_task"]))),
        ]
        completed = execute(self.cases, self.key, manifest, runs)
        self.assertEqual(completed.returncode, 2)
        self.assertIn("declare environment assertions in the answer key", completed.stderr)


if __name__ == "__main__":
    unittest.main()
