#!/usr/bin/env python3
"""Guard target-neutral MQTT expectations and session runtime ownership."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


SOURCE_SUFFIXES = {".c", ".cc", ".cpp", ".cxx", ".h", ".hh", ".hpp"}
SESSION_STEP = re.compile(r"\bsession_step\s*\(")
SESSION_STEP_ALLOWLIST = {
    "src/common/session/session.c": 1,
    "src/common/session/session.h": 1,
    "src/pc/client/direct_session_adapter.cpp": 1,
    "src/pc/client/mqtt_session_adapter.cpp": 1,
}
CORPUS_HEADER = "tests/session/mqtt_session_transcripts.h"
CORPUS_SOURCE = "tests/session/mqtt_session_transcripts.c"
JUDGE_SOURCE = "tests/session/test_mqtt_session_parity.c"
DIRECT_CORPUS_HEADER = "tests/session/direct_parity.h"
DIRECT_JUDGE_SOURCE = "tests/session/test_direct_session_parity.c"
BUILD_FILE = "Makefile"
MQTT_WIRE_SOURCE = "src/spectrum/transport/mqtt_session_wire.c"
MQTT_WIRE_BUILDERS = (
    "spectrum_net_mqtt_out_suffix",
    "spectrum_net_mqtt_in_suffix",
    "spectrum_net_mqtt_out_ack_suffix",
    "spectrum_net_mqtt_in_ack_suffix",
    "spectrum_net_mqtt_presence_suffix",
    "spectrum_net_mqtt_peer_presence_suffix",
    "spectrum_net_mqtt_presence_payload",
    "spectrum_net_mqtt_setup_payload",
    "spectrum_net_mqtt_publish_offline",
)
TARGET_POLICY_IDENTIFIER = re.compile(
    r"\b(?:[A-Za-z0-9_]*(?:spectrum|zx|next|pc|canonical|reference)"
    r"[A-Za-z0-9_]*(?:expected|expectation|flag|skip|only|deviation)"
    r"[A-Za-z0-9_]*|"
    r"[A-Za-z0-9_]*(?:expected|expectation|flag|skip|only|deviation)"
    r"[A-Za-z0-9_]*(?:spectrum|zx|next|pc|canonical|reference)"
    r"[A-Za-z0-9_]*)\b",
    re.IGNORECASE,
)
JUDGE_TARGET_EXPECTATION = re.compile(
    r"\b(?:[A-Za-z0-9_]*(?:spectrum|zx|next|pc|canonical|reference)"
    r"[A-Za-z0-9_]*(?:expected|expectation|skip|only|deviation)"
    r"[A-Za-z0-9_]*|"
    r"[A-Za-z0-9_]*(?:expected|expectation|skip|only|deviation)"
    r"[A-Za-z0-9_]*(?:spectrum|zx|next|pc|canonical|reference)"
    r"[A-Za-z0-9_]*)\b",
    re.IGNORECASE,
)
TARGET_CONDITIONAL = re.compile(
    r"^\s*#\s*(?:if|ifdef|ifndef|elif)\b[^\n]*"
    r"(?:SPECTRUM|NETCHESSZX_(?:NEXT|PC)|__SDCC|__Z88DK|_WIN32)",
    re.IGNORECASE | re.MULTILINE,
)
SHARED_RUNNERS = re.compile(
    r"static\s+void\s+run_shared_transcript\s*\(\s*"
    r"const\s+MqttTranscript\s*\*\s*transcript\s*\)\s*\{\s*"
    r"mqtt_reference_run\s*\(\s*transcript\s*\)\s*;\s*"
    r"mqtt_spectrum_run\s*\(\s*transcript\s*\)\s*;\s*\}",
    re.DOTALL,
)
MQTT_PARITY_SOURCES = re.compile(
    r"SESSION_MQTT_PARITY_TEST_SRC\s*:=(.*?)"
    r"^SESSION_DIRECT_PARITY_TEST\s*:=",
    re.DOTALL | re.MULTILINE,
)


def check_session_step_owners(sources: dict[str, str]) -> list[str]:
    counts = {
        path: len(SESSION_STEP.findall(source))
        for path, source in sources.items()
        if SESSION_STEP.search(source)
    }
    errors: list[str] = []

    for path in sorted(set(counts) | set(SESSION_STEP_ALLOWLIST)):
        actual = counts.get(path, 0)
        expected = SESSION_STEP_ALLOWLIST.get(path, 0)
        if actual != expected:
            errors.append(
                f"{path}: session_step() count {actual}; expected {expected}"
            )
    return errors


def check_mqtt_judge(header: str, corpus: str, judge: str) -> list[str]:
    errors: list[str] = []

    for path, source in ((CORPUS_HEADER, header), (CORPUS_SOURCE, corpus)):
        match = TARGET_POLICY_IDENTIFIER.search(source)
        if match:
            errors.append(
                f"{path}: target-specific shared-corpus policy "
                f"({match.group(0)!r})"
            )
        conditional = TARGET_CONDITIONAL.search(source)
        if conditional:
            errors.append(
                f"{path}: target-specific shared-expected conditional "
                f"({conditional.group(0)!r})"
            )
    judge_match = JUDGE_TARGET_EXPECTATION.search(judge)
    if judge_match:
        errors.append(
            f"{JUDGE_SOURCE}: target-specific expected path "
            f"({judge_match.group(0)!r})"
        )
    judge_conditional = TARGET_CONDITIONAL.search(judge)
    if judge_conditional:
        errors.append(
            f"{JUDGE_SOURCE}: target-specific shared-expected conditional "
            f"({judge_conditional.group(0)!r})"
        )
    if header.count(
        "MqttTranscriptObservation expected[MQTT_TRANSCRIPT_OBSERVATIONS_MAX];"
    ) != 1 or header.count("uint8_t expected_count;") != 1:
        errors.append(
            f"{CORPUS_HEADER}: expected must be one target-neutral field/count"
        )
    if not SHARED_RUNNERS.search(judge):
        errors.append(
            f"{JUDGE_SOURCE}: canonical and Spectrum runners must receive "
            "the same transcript"
        )
    if judge.count("observations_match(observations, action_count, step)") != 1:
        errors.append(f"{JUDGE_SOURCE}: canonical runner bypasses shared expected")
    if judge.count("observations_match(actual, actual_count, step)") != 1:
        errors.append(f"{JUDGE_SOURCE}: Spectrum runner bypasses shared expected")
    return errors


def check_direct_judge(header: str, judge: str) -> list[str]:
    errors: list[str] = []

    match = TARGET_POLICY_IDENTIFIER.search(header)
    if match:
        errors.append(
            f"{DIRECT_CORPUS_HEADER}: target-specific shared-corpus policy "
            f"({match.group(0)!r})"
        )
    conditional = TARGET_CONDITIONAL.search(header)
    if conditional:
        errors.append(
            f"{DIRECT_CORPUS_HEADER}: target-specific shared-expected conditional "
            f"({conditional.group(0)!r})"
        )
    judge_match = JUDGE_TARGET_EXPECTATION.search(judge)
    if judge_match:
        errors.append(
            f"{DIRECT_JUDGE_SOURCE}: target-specific expected path "
            f"({judge_match.group(0)!r})"
        )
    if header.count("const DirectParityObservation *expected;") != 1:
        errors.append(
            f"{DIRECT_CORPUS_HEADER}: expected must be one target-neutral field"
        )
    shared_calls = (
        "direct_reference_run(scenario, &reference)",
        "check_trace(scenario, &reference, \"reference\")",
        "direct_spectrum_run(scenario, &spectrum)",
        "check_trace(scenario, &spectrum, \"Spectrum\")",
    )
    for call in shared_calls:
        if judge.count(call) != 1:
            errors.append(
                f"{DIRECT_JUDGE_SOURCE}: shared scenario bypass at {call}"
            )
    return errors


def check_mqtt_wire_authority(build: str, judge: str) -> list[str]:
    errors: list[str] = []
    source_block = MQTT_PARITY_SOURCES.search(build)

    if source_block is None or MQTT_WIRE_SOURCE not in source_block.group(1):
        errors.append(
            f"{BUILD_FILE}: MQTT parity must compile {MQTT_WIRE_SOURCE}"
        )
    for name in MQTT_WIRE_BUILDERS:
        definition = re.compile(
            rf"^\s*(?:static\s+)?"
            rf"(?:const\s+char\s*\*|char\s+const\s*\*|void|uint8_t)"
            rf"\s*{name}\s*\(",
            re.MULTILINE,
        )
        if definition.search(judge):
            errors.append(
                f"{JUDGE_SOURCE}: substitutes production MQTT builder {name}"
            )
    return errors


def check_tree(root: Path) -> list[str]:
    source_root = root / "src"
    if not source_root.is_dir():
        return ["src: missing production source directory"]

    sources = {
        path.relative_to(root).as_posix(): path.read_text(encoding="utf-8")
        for path in source_root.rglob("*")
        if path.is_file() and path.suffix.lower() in SOURCE_SUFFIXES
    }
    required_names = (
        CORPUS_HEADER,
        CORPUS_SOURCE,
        JUDGE_SOURCE,
        DIRECT_CORPUS_HEADER,
        DIRECT_JUDGE_SOURCE,
        BUILD_FILE,
        MQTT_WIRE_SOURCE,
    )
    required = [root / path for path in required_names]
    missing = [path.relative_to(root).as_posix() for path in required if not path.is_file()]
    if missing:
        return [f"{path}: missing" for path in missing]
    return (
        check_session_step_owners(sources)
        + check_mqtt_judge(
            required[0].read_text(encoding="utf-8"),
            required[1].read_text(encoding="utf-8"),
            required[2].read_text(encoding="utf-8"),
        )
        + check_direct_judge(
            required[3].read_text(encoding="utf-8"),
            required[4].read_text(encoding="utf-8"),
        )
        + check_mqtt_wire_authority(
            required[5].read_text(encoding="utf-8"),
            required[2].read_text(encoding="utf-8"),
        )
    )


def self_test() -> None:
    sources = {
        path: "session_step(state, event);\n"
        for path in SESSION_STEP_ALLOWLIST
    }
    if check_session_step_owners(sources):
        raise SystemExit("[ERR] session boundaries self-test rejected allowlist")
    third = dict(sources)
    third["src/pc/client/third_runtime.cpp"] = "session_step(state, event);\n"
    if not check_session_step_owners(third):
        raise SystemExit("[ERR] session boundaries self-test accepted third runtime")

    header = (
        "MqttTranscriptObservation expected[MQTT_TRANSCRIPT_OBSERVATIONS_MAX];\n"
        "uint8_t expected_count;\n"
    )
    judge = (
        "static void run_shared_transcript(const MqttTranscript *transcript) {\n"
        "    mqtt_reference_run(transcript);\n"
        "    mqtt_spectrum_run(transcript);\n"
        "}\n"
        "observations_match(observations, action_count, step);\n"
        "observations_match(actual, actual_count, step);\n"
    )
    if check_mqtt_judge(header, "", judge):
        raise SystemExit("[ERR] session boundaries self-test rejected shared judge")
    if not check_mqtt_judge(header, "MQTT_SPECTRUM_EXPECTED", judge):
        raise SystemExit("[ERR] session boundaries self-test accepted target expected")
    if not check_mqtt_judge(header, "", judge.replace(
        "mqtt_spectrum_run(transcript)", "mqtt_spectrum_run(spectrum_expected)"
    )):
        raise SystemExit("[ERR] session boundaries self-test accepted split expected")

    direct_header = "const DirectParityObservation *expected;\n"
    direct_judge = (
        "direct_reference_run(scenario, &reference);\n"
        "check_trace(scenario, &reference, \"reference\");\n"
        "direct_spectrum_run(scenario, &spectrum);\n"
        "check_trace(scenario, &spectrum, \"Spectrum\");\n"
    )
    if check_direct_judge(direct_header, direct_judge):
        raise SystemExit("[ERR] session boundaries self-test rejected DIRECT judge")
    if not check_direct_judge(
        direct_header,
        direct_judge.replace(
            "check_trace(scenario, &spectrum, \"Spectrum\")",
            "check_trace(direct_spectrum_expected, &spectrum, \"Spectrum\")",
        ),
    ):
        raise SystemExit("[ERR] session boundaries self-test accepted DIRECT split expected")

    build = (
        "SESSION_MQTT_PARITY_TEST_SRC := "
        "src/spectrum/transport/mqtt_session_wire.c\n"
        "SESSION_DIRECT_PARITY_TEST := direct\n"
    )
    if check_mqtt_wire_authority(build, judge):
        raise SystemExit("[ERR] session boundaries self-test rejected MQTT wire source")
    if not check_mqtt_wire_authority(
        build,
        judge + "const char *spectrum_net_mqtt_out_suffix(void) { return 0; }\n",
    ):
        raise SystemExit("[ERR] session boundaries self-test accepted MQTT wire stub")
    print("[OK] session boundaries self-test")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=".")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        self_test()
        return
    errors = check_tree(Path(args.root))
    if errors:
        print("[ERR] session boundaries violated")
        for error in errors:
            print(f"  {error}")
        raise SystemExit(1)
    print(
        "[OK] session boundaries: target-neutral MQTT/DIRECT expected; "
        "production MQTT wire; two PC reducer calls"
    )


if __name__ == "__main__":
    main()
