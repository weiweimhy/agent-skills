#!/usr/bin/env python3
"""Deterministically score structured agent-evaluation records (stdlib only)."""

import argparse
import json
import sys
from pathlib import Path


SKILL_DIR = Path(__file__).resolve().parents[1]
EXAMPLES = SKILL_DIR / "examples"
SUPPORTED_VERSIONS = (1, 2)
V2_EVALUATION_MODES = ("explicit_skill_invocation", "natural_task")
V2_ROUTE_POLICIES = ("informational", "must_include", "exact")


class InputError(Exception):
    pass


def load_json(path, label):
    try:
        with Path(path).open("r", encoding="utf-8") as stream:
            value = json.load(stream)
    except OSError as error:
        raise InputError("cannot read {} file '{}': {}".format(label, path, error))
    except UnicodeDecodeError as error:
        raise InputError("invalid UTF-8 in {} file '{}': {}".format(label, path, error))
    except json.JSONDecodeError as error:
        raise InputError("invalid JSON in {} file '{}': {}".format(label, path, error))
    if not isinstance(value, dict):
        raise InputError("{} file must contain a JSON object".format(label))
    return value


def require_string(value, field, label):
    if not isinstance(value, str) or not value.strip():
        raise InputError("{}: '{}' must be a non-empty string".format(label, field))
    return value


def require_string_list(value, field, label):
    if not isinstance(value, list) or any(not isinstance(item, str) or not item.strip() for item in value):
        raise InputError("{}: '{}' must be a list of non-empty strings".format(label, field))
    if len(set(value)) != len(value):
        raise InputError("{}: '{}' must not contain duplicates".format(label, field))
    return value


def require_case_entries(data, key, label):
    entries = data.get(key)
    if not isinstance(entries, list) or not entries:
        raise InputError("{}: '{}' must be a non-empty list".format(label, key))
    return entries


def require_version(data, label):
    version = data.get("schema_version")
    if version not in SUPPORTED_VERSIONS:
        raise InputError("{}: 'schema_version' must be 1 or 2".format(label))
    return version


def validate_cases(data):
    version = require_version(data, "cases")
    suite_id = require_string(data.get("suite_id"), "suite_id", "cases")
    entries = require_case_entries(data, "cases", "cases")
    case_ids = set()
    case_modes = {}
    for index, entry in enumerate(entries):
        label = "cases[{}]".format(index)
        if not isinstance(entry, dict):
            raise InputError("{} must be an object".format(label))
        case_id = require_string(entry.get("case_id"), "case_id", label)
        require_string(entry.get("task"), "task", label)
        if case_id in case_ids:
            raise InputError("duplicate case_id '{}' in cases".format(case_id))
        case_ids.add(case_id)
        if version == 2:
            evaluation_mode = entry.get("evaluation_mode")
            if evaluation_mode not in V2_EVALUATION_MODES:
                raise InputError(
                    "{}: 'evaluation_mode' must be 'explicit_skill_invocation' or 'natural_task'".format(label)
                )
            if evaluation_mode == "explicit_skill_invocation":
                invoked_skill = require_string(entry.get("invoked_skill"), "invoked_skill", label)
            else:
                if "invoked_skill" in entry:
                    raise InputError("{}: natural_task cases cannot declare 'invoked_skill'".format(label))
                invoked_skill = None
            case_modes[case_id] = {"evaluation_mode": evaluation_mode, "invoked_skill": invoked_skill}
    return version, suite_id, case_ids, case_modes


def validate_key(data, version, suite_id, case_ids, case_modes):
    if require_version(data, "key") != version:
        raise InputError("key: schema_version does not match cases")
    if data.get("suite_id") != suite_id:
        raise InputError("key: suite_id does not match cases")
    entries = require_case_entries(data, "answers", "key")
    expected_ids = set()
    answers = {}
    for index, entry in enumerate(entries):
        label = "key.answers[{}]".format(index)
        if not isinstance(entry, dict):
            raise InputError("{} must be an object".format(label))
        case_id = require_string(entry.get("case_id"), "case_id", label)
        required = require_string_list(entry.get("required_behaviors"), "required_behaviors", label)
        forbidden = require_string_list(entry.get("forbidden_behaviors"), "forbidden_behaviors", label)
        if set(required) & set(forbidden):
            raise InputError("{}: required and forbidden behaviors overlap".format(label))
        if case_id in expected_ids:
            raise InputError("duplicate case_id '{}' in key".format(case_id))
        expected_ids.add(case_id)
        answer = {
            "required_behaviors": set(required),
            "forbidden_behaviors": set(forbidden),
        }
        if version == 1:
            answer["expected_route"] = require_string(entry.get("expected_route"), "expected_route", label)
        else:
            if case_id not in case_modes:
                raise InputError("{}: unknown case_id '{}'".format(label, case_id))
            case_mode = case_modes[case_id]
            route_policy = entry.get("route_policy")
            has_expected_skills = "expected_skills" in entry
            expected_skills = require_string_list(entry.get("expected_skills", []), "expected_skills", label)
            if route_policy is None:
                if has_expected_skills:
                    raise InputError("{}: 'expected_skills' requires an explicit 'route_policy'".format(label))
                if case_mode["evaluation_mode"] == "explicit_skill_invocation":
                    route_policy = "must_include"
                    expected_skills = [case_mode["invoked_skill"]]
                else:
                    route_policy = "informational"
            elif route_policy not in V2_ROUTE_POLICIES:
                raise InputError("{}: 'route_policy' must be one of {}".format(label, V2_ROUTE_POLICIES))

            if route_policy == "informational":
                if has_expected_skills:
                    raise InputError("{}: informational routing cannot declare 'expected_skills'".format(label))
                if case_mode["evaluation_mode"] == "explicit_skill_invocation":
                    raise InputError("{}: explicit skill invocations must score the named skill".format(label))
            else:
                if route_policy == "must_include" and not expected_skills:
                    raise InputError("{}: '{}' routing requires non-empty 'expected_skills'".format(label, route_policy))
                if route_policy == "exact" and not has_expected_skills:
                    raise InputError("{}: 'exact' routing requires 'expected_skills'".format(label))
                invoked_skill = case_mode["invoked_skill"]
                if invoked_skill and invoked_skill not in expected_skills:
                    raise InputError("{}: expected_skills must include invoked_skill '{}'".format(label, invoked_skill))
            answer["route_policy"] = route_policy
            answer["expected_skills"] = set(expected_skills)
        answers[case_id] = answer
    if expected_ids != case_ids:
        missing = sorted(case_ids - expected_ids)
        extra = sorted(expected_ids - case_ids)
        raise InputError("key case IDs must exactly match cases (missing={}, extra={})".format(missing, extra))
    return answers


def validate_run(data, version, suite_id, case_ids):
    if require_version(data, "run") != version:
        raise InputError("run: schema_version does not match cases")
    if data.get("suite_id") != suite_id:
        raise InputError("run: suite_id does not match cases")
    require_string(data.get("run_id"), "run_id", "run")
    mode = data.get("execution_mode")
    if mode not in ("fixture", "live"):
        raise InputError("run: 'execution_mode' must be 'fixture' or 'live'")
    require_string(data.get("system_under_test"), "system_under_test", "run")
    method = require_string(data.get("annotation_method"), "annotation_method", "run")
    if mode == "fixture" and method != "synthetic_fixture":
        raise InputError("fixture runs must use annotation_method 'synthetic_fixture'")
    if mode == "live" and method == "synthetic_fixture":
        raise InputError("live runs cannot use annotation_method 'synthetic_fixture'")
    entries = require_case_entries(data, "case_results", "run")
    result_ids = set()
    results = {}
    for index, entry in enumerate(entries):
        label = "run.case_results[{}]".format(index)
        if not isinstance(entry, dict):
            raise InputError("{} must be an object".format(label))
        case_id = require_string(entry.get("case_id"), "case_id", label)
        observed = require_string_list(entry.get("observed_behaviors"), "observed_behaviors", label)
        evidence_ref = require_string(entry.get("evidence_ref"), "evidence_ref", label)
        if mode == "live" and evidence_ref.lower().startswith("fixture:"):
            raise InputError("live run evidence_ref cannot use the fixture: prefix")
        if mode == "fixture" and not evidence_ref.lower().startswith("fixture:"):
            raise InputError("fixture run evidence_ref must use the fixture: prefix")
        if case_id in result_ids:
            raise InputError("duplicate case_id '{}' in run".format(case_id))
        result_ids.add(case_id)
        if version == 1:
            route = require_string(entry.get("selected_route"), "selected_route", label)
            results[case_id] = {"selected_route": route, "observed_behaviors": set(observed)}
        else:
            selected_skills = require_string_list(entry.get("selected_skills"), "selected_skills", label)
            results[case_id] = {"selected_skills": set(selected_skills), "observed_behaviors": set(observed)}
    if result_ids != case_ids:
        missing = sorted(case_ids - result_ids)
        extra = sorted(result_ids - case_ids)
        raise InputError("run case IDs must exactly match cases (missing={}, extra={})".format(missing, extra))
    return mode, results


def score_v1(answers, results):
    route_pass = 0
    behavior_pass = 0
    rows = []
    for case_id in sorted(answers):
        expected = answers[case_id]
        actual = results[case_id]
        route_ok = actual["selected_route"] == expected["expected_route"]
        observed = actual["observed_behaviors"]
        missing = sorted(expected["required_behaviors"] - observed)
        violated = sorted(expected["forbidden_behaviors"] & observed)
        behavior_ok = not missing and not violated
        route_pass += int(route_ok)
        behavior_pass += int(behavior_ok)
        rows.append((case_id, route_ok, behavior_ok, missing, violated))
    return route_pass, behavior_pass, rows


def score_v2(answers, results):
    route_pass = 0
    route_scored = 0
    behavior_pass = 0
    rows = []
    for case_id in sorted(answers):
        expected = answers[case_id]
        actual = results[case_id]
        selected_skills = actual["selected_skills"]
        route_policy = expected["route_policy"]
        missing_skills = sorted(expected["expected_skills"] - selected_skills)
        unexpected_skills = []
        if route_policy == "informational":
            route_ok = None
        else:
            route_scored += 1
            route_ok = not missing_skills
            if route_policy == "exact":
                unexpected_skills = sorted(selected_skills - expected["expected_skills"])
                route_ok = route_ok and not unexpected_skills
            route_pass += int(route_ok)
        observed = actual["observed_behaviors"]
        missing_behaviors = sorted(expected["required_behaviors"] - observed)
        violated_behaviors = sorted(expected["forbidden_behaviors"] & observed)
        behavior_ok = not missing_behaviors and not violated_behaviors
        behavior_pass += int(behavior_ok)
        rows.append((
            case_id,
            route_ok,
            behavior_ok,
            sorted(selected_skills),
            missing_skills,
            unexpected_skills,
            missing_behaviors,
            violated_behaviors,
        ))
    return route_pass, route_scored, behavior_pass, rows


def parse_args(argv):
    parser = argparse.ArgumentParser(
        description="Deterministically score structured agent-evaluation records. No model or network calls."
    )
    parser.add_argument("--cases", default=str(EXAMPLES / "cases.json"), help="public task cases JSON")
    parser.add_argument("--run", default=str(EXAMPLES / "fixture-run.json"), help="structured run JSON")
    parser.add_argument("--key", default=str(EXAMPLES / "answer-key.json"), help="evaluator-only answer key JSON")
    parser.add_argument(
        "--require-live",
        action="store_true",
        help="fail unless execution_mode is declared as live (does not authenticate provenance)",
    )
    return parser.parse_args(argv)


def print_v1_report(run, mode, route_pass, behavior_pass, rows):
    total = len(rows)
    print("Suite: {}".format(run["suite_id"]))
    print("Run: {} [{}]".format(run["run_id"], mode))
    print("System under test: {}".format(run["system_under_test"]))
    if mode == "live":
        print("Provenance: declared live; verify the referenced raw traces independently.")
    else:
        print("Provenance: synthetic fixture; this is not evidence of agent execution.")
    case_width = max(20, max(len(row[0]) for row in rows))
    case_format = "{:<" + str(case_width) + "}"
    print("{} {:<7} {:<9} Details".format(case_format.format("Case"), "Route", "Behavior"))
    print("{} ------- --------- ----------------------------------------".format("-" * case_width))
    for case_id, route_ok, behavior_ok, missing, violated in rows:
        details = []
        if not route_ok:
            details.append("route mismatch")
        if missing:
            details.append("missing=" + ",".join(missing))
        if violated:
            details.append("forbidden=" + ",".join(violated))
        print("{} {:<7} {:<9} {}".format(
            case_format.format(case_id), "PASS" if route_ok else "FAIL", "PASS" if behavior_ok else "FAIL", "; ".join(details)
        ))
    print("Routing: {}/{} ({:.1%})".format(route_pass, total, route_pass / total))
    print("Behavior: {}/{} ({:.1%})".format(behavior_pass, total, behavior_pass / total))
    passed = route_pass == total and behavior_pass == total
    print("Acceptance: {}".format("PASS" if passed else "FAIL"))


def print_v2_report(run, mode, route_pass, route_scored, behavior_pass, rows):
    total = len(rows)
    route_informational = total - route_scored
    print("Suite: {}".format(run["suite_id"]))
    print("Run: {} [{}]".format(run["run_id"], mode))
    print("System under test: {}".format(run["system_under_test"]))
    if mode == "live":
        print("Provenance: declared live; verify the referenced raw traces independently.")
    else:
        print("Provenance: synthetic fixture; this is not evidence of agent execution.")
    case_width = max(20, max(len(row[0]) for row in rows))
    case_format = "{:<" + str(case_width) + "}"
    print("{} {:<9} {:<13} Skills / details".format(case_format.format("Case"), "Behavior", "Routing"))
    print("{} --------- ------------- ----------------------------------------".format("-" * case_width))
    for (case_id, route_ok, behavior_ok, selected_skills, missing_skills, unexpected_skills,
         missing_behaviors, violated_behaviors) in rows:
        details = ["skills=" + (",".join(selected_skills) if selected_skills else "(none)")]
        if route_ok is False:
            details.append("missing_skills=" + ",".join(missing_skills))
            if unexpected_skills:
                details.append("unexpected_skills=" + ",".join(unexpected_skills))
        if missing_behaviors:
            details.append("missing_behaviors=" + ",".join(missing_behaviors))
        if violated_behaviors:
            details.append("forbidden_behaviors=" + ",".join(violated_behaviors))
        route_label = "INFO" if route_ok is None else ("PASS" if route_ok else "FAIL")
        print("{} {:<13} {:<9} {}".format(
            case_format.format(case_id), "PASS" if behavior_ok else "FAIL", route_label, "; ".join(details)
        ))
    print("Behavior: {}/{} ({:.1%})".format(behavior_pass, total, behavior_pass / total))
    if route_scored:
        print("Routing: {}/{} ({:.1%}); {} informational".format(
            route_pass, route_scored, route_pass / route_scored, route_informational
        ))
    else:
        print("Routing: not scored; {} informational".format(route_informational))
    passed = route_pass == route_scored and behavior_pass == total
    print("Acceptance: {}".format("PASS" if passed else "FAIL"))


def main(argv=None):
    args = parse_args(argv)
    try:
        cases = load_json(args.cases, "cases")
        run = load_json(args.run, "run")
        key = load_json(args.key, "key")
        version, suite_id, case_ids, case_modes = validate_cases(cases)
        answers = validate_key(key, version, suite_id, case_ids, case_modes)
        mode, results = validate_run(run, version, suite_id, case_ids)
        if args.require_live and mode != "live":
            print("FAIL: --require-live requested, but execution_mode is '{}'".format(mode))
            return 1
        if version == 1:
            route_pass, behavior_pass, rows = score_v1(answers, results)
            print_v1_report(run, mode, route_pass, behavior_pass, rows)
            passed = route_pass == len(rows) and behavior_pass == len(rows)
        else:
            route_pass, route_scored, behavior_pass, rows = score_v2(answers, results)
            print_v2_report(run, mode, route_pass, route_scored, behavior_pass, rows)
            passed = route_pass == route_scored and behavior_pass == len(rows)
    except InputError as error:
        print("INPUT ERROR: {}".format(error), file=sys.stderr)
        return 2
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
