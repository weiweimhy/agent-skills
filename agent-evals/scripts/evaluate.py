#!/usr/bin/env python3
"""Deterministically score structured agent-evaluation records (stdlib only)."""

import argparse
import json
import sys
from pathlib import Path


SKILL_DIR = Path(__file__).resolve().parents[1]
EXAMPLES = SKILL_DIR / "examples"


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


def validate_cases(data):
    if data.get("schema_version") != 1:
        raise InputError("cases: 'schema_version' must be 1")
    suite_id = require_string(data.get("suite_id"), "suite_id", "cases")
    entries = require_case_entries(data, "cases", "cases")
    case_ids = set()
    for index, entry in enumerate(entries):
        label = "cases[{}]".format(index)
        if not isinstance(entry, dict):
            raise InputError("{} must be an object".format(label))
        case_id = require_string(entry.get("case_id"), "case_id", label)
        require_string(entry.get("task"), "task", label)
        if case_id in case_ids:
            raise InputError("duplicate case_id '{}' in cases".format(case_id))
        case_ids.add(case_id)
    return suite_id, case_ids


def validate_key(data, suite_id, case_ids):
    if data.get("schema_version") != 1:
        raise InputError("key: 'schema_version' must be 1")
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
        route = require_string(entry.get("expected_route"), "expected_route", label)
        required = require_string_list(entry.get("required_behaviors"), "required_behaviors", label)
        forbidden = require_string_list(entry.get("forbidden_behaviors"), "forbidden_behaviors", label)
        if set(required) & set(forbidden):
            raise InputError("{}: required and forbidden behaviors overlap".format(label))
        if case_id in expected_ids:
            raise InputError("duplicate case_id '{}' in key".format(case_id))
        expected_ids.add(case_id)
        answers[case_id] = {
            "expected_route": route,
            "required_behaviors": set(required),
            "forbidden_behaviors": set(forbidden),
        }
    if expected_ids != case_ids:
        missing = sorted(case_ids - expected_ids)
        extra = sorted(expected_ids - case_ids)
        raise InputError("key case IDs must exactly match cases (missing={}, extra={})".format(missing, extra))
    return answers


def validate_run(data, suite_id, case_ids):
    if data.get("schema_version") != 1:
        raise InputError("run: 'schema_version' must be 1")
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
        route = require_string(entry.get("selected_route"), "selected_route", label)
        observed = require_string_list(entry.get("observed_behaviors"), "observed_behaviors", label)
        evidence_ref = require_string(entry.get("evidence_ref"), "evidence_ref", label)
        if mode == "live" and evidence_ref.lower().startswith("fixture:"):
            raise InputError("live run evidence_ref cannot use the fixture: prefix")
        if mode == "fixture" and not evidence_ref.lower().startswith("fixture:"):
            raise InputError("fixture run evidence_ref must use the fixture: prefix")
        if case_id in result_ids:
            raise InputError("duplicate case_id '{}' in run".format(case_id))
        result_ids.add(case_id)
        results[case_id] = {"selected_route": route, "observed_behaviors": set(observed)}
    if result_ids != case_ids:
        missing = sorted(case_ids - result_ids)
        extra = sorted(result_ids - case_ids)
        raise InputError("run case IDs must exactly match cases (missing={}, extra={})".format(missing, extra))
    return mode, results


def score(answers, results):
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


def main(argv=None):
    args = parse_args(argv)
    try:
        cases = load_json(args.cases, "cases")
        run = load_json(args.run, "run")
        key = load_json(args.key, "key")
        suite_id, case_ids = validate_cases(cases)
        answers = validate_key(key, suite_id, case_ids)
        mode, results = validate_run(run, suite_id, case_ids)
        if args.require_live and mode != "live":
            print("FAIL: --require-live requested, but execution_mode is '{}'".format(mode))
            return 1
        route_pass, behavior_pass, rows = score(answers, results)
    except InputError as error:
        print("INPUT ERROR: {}".format(error), file=sys.stderr)
        return 2

    total = len(rows)
    print("Suite: {}".format(suite_id))
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
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
