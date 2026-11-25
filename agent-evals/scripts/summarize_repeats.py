#!/usr/bin/env python3
"""Summarize existing v2 run files by comparison group and evidence type."""

import argparse
import json
import math
import sys
from pathlib import Path

from evaluate import (
    InputError,
    load_json,
    require_case_entries,
    require_string,
    require_string_list,
    score_v2,
    validate_cases,
    validate_key,
    validate_run,
)


def nonnegative_number(value, field, label):
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise InputError("{}: '{}' must be a non-negative number".format(label, field))
    if not math.isfinite(value) or value < 0:
        raise InputError("{}: '{}' must be a finite, non-negative number".format(label, field))
    return float(value)


def validate_assertions(value, label):
    if not isinstance(value, list):
        raise InputError("{}: 'environment_assertions' must be a list".format(label))
    assertions = []
    names = set()
    for index, assertion in enumerate(value):
        assertion_label = "{}.environment_assertions[{}]".format(label, index)
        if not isinstance(assertion, dict):
            raise InputError("{} must be an object".format(assertion_label))
        name = require_string(assertion.get("name"), "name", assertion_label)
        expected = require_string(assertion.get("expected"), "expected", assertion_label)
        actual = assertion.get("actual")
        if actual is not None and (not isinstance(actual, str) or not actual.strip()):
            raise InputError("{}: 'actual' must be a non-empty string or null".format(assertion_label))
        if name in names:
            raise InputError("{}: duplicate environment assertion '{}'".format(label, name))
        names.add(name)
        assertions.append({
            "name": name,
            "expected": expected,
            "actual": actual,
            "passed": expected == actual if actual is not None else None,
        })
    return assertions


def environment_expectations_from_key(key_data, case_ids):
    entries = {entry["case_id"]: entry for entry in key_data["answers"]}
    expectations = {}
    for case_id in case_ids:
        answer = entries[case_id]
        if "required_environment_assertions" not in answer:
            expectations[case_id] = None
            continue
        raw_assertions = answer["required_environment_assertions"]
        if not isinstance(raw_assertions, list):
            raise InputError(
                "key answer '{}': 'required_environment_assertions' must be a list".format(case_id)
            )
        case_expectations = {}
        for index, assertion in enumerate(raw_assertions):
            label = "key answer '{}'.required_environment_assertions[{}]".format(case_id, index)
            if not isinstance(assertion, dict):
                raise InputError("{} must be an object".format(label))
            name = require_string(assertion.get("name"), "name", label)
            expected = require_string(assertion.get("expected"), "expected", label)
            if name in case_expectations:
                raise InputError("{}: duplicate assertion name '{}'".format(label, name))
            case_expectations[name] = expected
        expectations[case_id] = case_expectations
    return expectations


def load_comparison(manifest_path, suite_id, case_ids, answers, environment_expectations):
    manifest = load_json(manifest_path, "runs manifest")
    if manifest.get("schema_version") != 1 or manifest.get("suite_id") != suite_id:
        raise InputError("runs manifest: schema_version or suite_id does not match")
    name = require_string(manifest.get("comparison_name"), "comparison_name", "runs manifest")
    groups = require_string_list(manifest.get("groups"), "groups", "runs manifest")
    if len(groups) < 2:
        raise InputError("runs manifest: 'groups' must name at least two groups")

    entries = require_case_entries(manifest, "runs", "runs manifest")
    base = Path(manifest_path).resolve().parent
    run_ids, used_groups, modes, records = set(), set(), set(), []
    for index, entry in enumerate(entries):
        label = "runs manifest.runs[{}]".format(index)
        if not isinstance(entry, dict):
            raise InputError("{} must be an object".format(label))
        group = require_string(entry.get("group"), "group", label)
        if group not in groups:
            raise InputError("{}: undeclared group '{}'".format(label, group))
        used_groups.add(group)
        path = Path(require_string(entry.get("run_file"), "run_file", label))
        if not path.is_absolute():
            path = base / path
        run = load_json(path, "run")
        mode, results = validate_run(run, 2, suite_id, case_ids)
        run_id = require_string(run.get("run_id"), "run_id", "run")
        if run_id in run_ids:
            raise InputError("duplicate run_id '{}'".format(run_id))
        run_ids.add(run_id)
        modes.add(mode)
        raw_results = {item["case_id"]: item for item in run["case_results"]}
        _, _, _, rows = score_v2(answers, results)
        scores = {row[0]: (row[1], row[2]) for row in rows}

        for case_id in sorted(case_ids):
            raw = raw_results[case_id]
            case_label = "run.case_results[{}]".format(case_id)
            observed = validate_assertions(raw.get("environment_assertions", []), case_label)
            expected = environment_expectations[case_id]
            if expected is None:
                if observed:
                    raise InputError(
                        "{}: declare environment assertions in the answer key before recording them".format(
                            case_label
                        )
                    )
                expected = {}
            actual = {item["name"]: item for item in observed}
            if set(actual) - set(expected):
                raise InputError("{}: environment assertions must match the answer key".format(case_label))
            assertions = []
            for assertion_name, expected_value in expected.items():
                item = actual.get(assertion_name)
                if item and item["expected"] != expected_value:
                    raise InputError("{}: assertion '{}' expected value differs from answer key".format(
                        case_label, assertion_name
                    ))
                actual_value = item["actual"] if item else None
                assertions.append({
                    "name": assertion_name,
                    "expected": expected_value,
                    "actual": actual_value,
                    "passed": expected_value == actual_value if actual_value is not None else None,
                })

            route_ok, behavior_ok = scores[case_id]
            env_ok = all(item["passed"] is True for item in assertions)
            success = behavior_ok and route_ok is not False and env_ok
            metrics = {
                field: nonnegative_number(raw[field], field, case_label) if field in raw else None
                for field in ("cost_usd", "human_intervention_minutes", "time_to_acceptance_seconds")
            }
            intervention = raw.get("human_intervention")
            if intervention is not None and type(intervention) is not bool:
                raise InputError("{}: 'human_intervention' must be a boolean".format(case_label))
            if metrics["human_intervention_minutes"] and intervention is False:
                raise InputError("{}: intervention minutes conflict with human_intervention=false".format(case_label))
            if metrics["time_to_acceptance_seconds"] is not None and not success:
                raise InputError("{}: acceptance time requires a passing result".format(case_label))
            records.append({
                "group": group, "execution_mode": mode, "run_id": run_id, "case_id": case_id,
                "route_ok": route_ok, "behavior_ok": behavior_ok, "environment_assertions": assertions,
                "success": success, "human_intervention": intervention, **metrics,
            })

    if used_groups != set(groups):
        raise InputError("runs manifest must include every declared group")
    return name, groups, modes, records


def count_fraction(success, total):
    return "{}/{}".format(success, total)


def sum_metric(records, field, unit, currency=False):
    if not records:
        return "n/a"
    values = [record[field] for record in records if record[field] is not None]
    missing = len(records) - len(values)
    total = sum(values)
    rendered = "${:.4f}".format(total) if currency else "{:.2f} {}".format(total, unit)
    if missing:
        return "UNKNOWN (known subtotal {} from {}/{} attempts)".format(
            rendered, len(values), len(records)
        )
    return rendered


def mean_time_to_acceptance(records):
    accepted = [record for record in records if record["success"]]
    if not accepted:
        return "n/a (no passing attempts)"
    values = [record["time_to_acceptance_seconds"] for record in accepted
              if record["time_to_acceptance_seconds"] is not None]
    if len(values) != len(accepted):
        if values:
            return "UNKNOWN (known mean {:.2f}s for {}/{} passing attempts)".format(
                sum(values) / len(values), len(values), len(accepted)
            )
        return "UNKNOWN (no passing attempt has a recorded duration)"
    return "{:.2f}s mean across {} passing attempts".format(sum(values) / len(values), len(values))


def print_report(suite_id, comparison_name, groups, modes, records, case_ids):
    print("Suite: {}".format(suite_id))
    print("Comparison: {}".format(comparison_name))
    print("Groups: {}".format(", ".join(groups)))
    for mode in ("live", "fixture"):
        if mode not in modes:
            continue
        label = (
            "LIVE (declared execution; verify raw trace references)"
            if mode == "live"
            else "FIXTURE (synthetic evidence; not evidence of agent execution)"
        )
        print("\nEvidence: {}".format(label))
        mode_records = [record for record in records if record["execution_mode"] == mode]
        for group in groups:
            group_records = [record for record in mode_records if record["group"] == group]
            print("\nGroup: {} ({} run-case observations)".format(group, len(group_records)))
            for case_id in sorted(case_ids):
                case_records = [record for record in group_records if record["case_id"] == case_id]
                success = sum(record["success"] for record in case_records)
                behavior = sum(record["behavior_ok"] for record in case_records)
                scored_routes = [record for record in case_records if record["route_ok"] is not None]
                route_pass = sum(record["route_ok"] for record in scored_routes)
                env_checks = [
                    assertion
                    for record in case_records
                    for assertion in record["environment_assertions"]
                ]
                env_pass = sum(assertion["passed"] is True for assertion in env_checks)
                flags = [record["human_intervention"] for record in case_records]
                yes_count = sum(value is True for value in flags)
                no_count = sum(value is False for value in flags)
                unknown_count = sum(value is None for value in flags)
                intervention_minutes = sum_metric(
                    case_records, "human_intervention_minutes", "min"
                )
                route_label = (
                    "info" if not scored_routes else count_fraction(route_pass, len(scored_routes))
                )
                env_label = "n/a" if not env_checks else count_fraction(env_pass, len(env_checks))
                print("{}: success={} behavior={} route={} environment={} "
                      "human=yes:{}/no:{}/unknown:{} minutes={}".format(
                    case_id,
                    count_fraction(success, len(case_records)),
                    count_fraction(behavior, len(case_records)),
                    route_label,
                    env_label,
                    yes_count,
                    no_count,
                    unknown_count,
                    intervention_minutes,
                ))

            successes = sum(record["success"] for record in group_records)
            interventions = [record["human_intervention"] for record in group_records]
            yes_count = sum(value is True for value in interventions)
            no_count = sum(value is False for value in interventions)
            unknown_interventions = sum(value is None for value in interventions)
            total_cost = sum_metric(group_records, "cost_usd", "USD", currency=True)
            total_minutes = sum_metric(group_records, "human_intervention_minutes", "min")
            if group_records and all(record["cost_usd"] is not None for record in group_records):
                avg_cost = (
                    "n/a (no passing attempts)" if not successes
                    else "${:.4f} per passing attempt, including all group failures".format(
                        sum(record["cost_usd"] for record in group_records) / successes
                    )
                )
            elif group_records:
                known = sum(
                    record["cost_usd"] for record in group_records
                    if record["cost_usd"] is not None
                )
                known_count = sum(record["cost_usd"] is not None for record in group_records)
                avg_cost = "UNKNOWN (known subtotal ${:.4f} from {}/{} attempts)".format(
                    known, known_count, len(group_records)
                )
            else:
                avg_cost = "n/a"
            print("Total success: {}".format(count_fraction(successes, len(group_records))))
            print("Cost spent (USD; all attempts, including failures/rework): {}".format(total_cost))
            print("Average cost per passing attempt: {}".format(avg_cost))
            print("Human intervention flags: yes={} no={} unknown={} / {} attempts".format(
                yes_count, no_count, unknown_interventions, len(group_records)
            ))
            print("Human intervention time (person-minutes): {}".format(total_minutes))
            print("Time to acceptance (wall-clock): {}".format(mean_time_to_acceptance(group_records)))

            for record in group_records:
                for assertion in record["environment_assertions"]:
                    status = "UNKNOWN" if assertion["passed"] is None else (
                        "PASS" if assertion["passed"] else "FAIL"
                    )
                    print("Environment [{} / {} / {}]: {} expected={} actual={} {}".format(
                        record["run_id"],
                        record["case_id"],
                        group,
                        assertion["name"],
                        json.dumps(assertion["expected"], ensure_ascii=False),
                        json.dumps(assertion["actual"], ensure_ascii=False),
                        status,
                    ))


def parse_args(argv):
    parser = argparse.ArgumentParser(
        description="Summarize v2 run files by comparison group, case, and evidence type."
    )
    parser.add_argument("--cases", required=True, help="v2 cases JSON")
    parser.add_argument("--key", required=True, help="evaluator-only v2 answer key JSON")
    parser.add_argument("--runs", required=True, help="manifest listing grouped single-run JSON files")
    parser.add_argument(
        "--require-live",
        action="store_true",
        help="fail unless every included run is declared live; this does not authenticate provenance",
    )
    return parser.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)
    try:
        cases = load_json(args.cases, "cases")
        key = load_json(args.key, "key")
        version, suite_id, case_ids, _case_modes = validate_cases(cases)
        if version != 2:
            raise InputError("repeated summaries require v2 cases")
        answers = validate_key(key, version, suite_id, case_ids, _case_modes)
        environment_expectations = environment_expectations_from_key(key, case_ids)
        comparison_name, groups, modes, records = load_comparison(
            args.runs, suite_id, case_ids, answers, environment_expectations
        )
        print_report(suite_id, comparison_name, groups, modes, records, case_ids)
        if args.require_live and modes != {"live"}:
            print("\nFAIL: --require-live requested, but fixture runs are present")
            return 1
    except InputError as error:
        print("INPUT ERROR: {}".format(error), file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
