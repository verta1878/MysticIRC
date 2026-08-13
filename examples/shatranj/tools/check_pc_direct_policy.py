#!/usr/bin/env python3
"""Reject legacy DIRECT or MQTT session policy in the PC client."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


PC_SOURCE_DIR = "src/pc/client"
ADAPTER_SOURCES = {
    f"{PC_SOURCE_DIR}/direct_session_adapter.cpp",
    f"{PC_SOURCE_DIR}/mqtt_session_adapter.cpp",
}
SOURCE_SUFFIXES = {".cc", ".cpp", ".cxx", ".h", ".hh", ".hpp"}
SESSION_STEP = re.compile(r"\bsession_step\s*\(")
SESSION_WIRE_LITERAL = re.compile(r'"[HJOF](?:[ \t][^"\r\n]*)?"')
LWT_PATH = f"{PC_SOURCE_DIR}/main_window.cpp"
LWT_CODEC_PATH = f"{PC_SOURCE_DIR}/desktop_transport_codec.cpp"
LWT_LITERAL = '"F %1 %2"'
MQTT_ADAPTER_PATH = f"{PC_SOURCE_DIR}/mqtt_session_adapter.cpp"
MQTT_TOPIC_LITERALS = {
    "meta", "pres_w", "pres_b", "w2b", "b2w", "ack_w", "ack_b"
}
FORBIDDEN = (
    (
        re.compile(r"common/protocol/direct_session_protocol\.h"),
        "DIRECT parser/builder header outside the reducer",
    ),
    (
        re.compile(r"common/protocol/(?:game_protocol|mqtt_session_protocol)\.h"),
        "MQTT parser/builder header outside the reducer",
    ),
    (
        re.compile(r"\b(?:directHelloLine|sendDirectHello|handleDirectHello)\b"),
        "legacy DIRECT HELLO helper",
    ),
    (
        re.compile(r"\bnetchess_direct_[A-Za-z0-9_]*\s*\("),
        "legacy DIRECT parser/builder",
    ),
    (re.compile(r"\bresetDirectPingState\b"), "legacy DIRECT ping reset"),
    (
        re.compile(
            r"\b(?:directReady_|directHelloRetries_|"
            r"directPingOutstanding_|directPingMisses_)\b"
        ),
        "legacy DIRECT transition state",
    ),
    (
        re.compile(
            r"\bkDirect(?:HandshakeRetryMs|PingIdleMs|"
            r"PingTimeoutMs|PingMissMax)\b"
        ),
        "legacy DIRECT retry/liveness policy",
    ),
    (re.compile(r"HELLO DIRECT"), "legacy DIRECT HELLO wire decision"),
    (re.compile(r'"BUSY\\n"'), "legacy direct-socket BUSY decision"),
    (
        re.compile(r'payload\.(?:startsWith\("NACK"\)|operator==\("RN"\))|payload\s*==\s*"RN"'),
        "DIRECT adapter reparses a control-result wire verb",
    ),
    (
        re.compile(
            r"\b(?:handleMqttSessionPayload|handleRxLine|handleMqttPeerTimeout|"
            r"announceMqttSetup|activateMqttSide|publishMqttPeerOfflineIfHost|"
            r"publishMqttOfflineIfReady|sendMqttText|sendRequiredMqttLine|"
            r"sendLine|generateHostRoomIfNeeded)\b"
        ),
        "legacy MQTT policy helper",
    ),
    (
        re.compile(r"\bnetchess_mqtt_session_(?:parse|format)[A-Za-z0-9_]*\s*\("),
        "legacy MQTT parser/builder",
    ),
    (
        re.compile(
            r"\b(?:mqttSeatProbe(?:SessionId)?_|mqttPeerReady_|"
            r"mqttPeerPingOutstanding_|mqttSetupAnnounces_|"
            r"pendingPly_|pendingMove_|startPending_|resetPending_|"
            r"drawPending_|resignPending_|takebackPending(?:Ply)?_|"
            r"restore(?:TxState|RxMask|TxPending|AwaitingAck|RxAccepted|"
            r"RxApplied|PromptOpen)_|gameReplyRetry(?:Active|Count|Timer)_)\b"
        ),
        "legacy MQTT transition state",
    ),
)


def line_number(source: str, offset: int) -> int:
    return source.count("\n", 0, offset) + 1


def function_body(source: str, signature: str) -> str | None:
    start = source.find(signature)
    if start < 0:
        return None
    brace = source.find("{", start + len(signature))
    if brace < 0:
        return None
    depth = 0
    for index in range(brace, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[brace + 1:index]
    return None


def check_lwt_exception(sources: dict[str, str]) -> list[str]:
    literals = [
        (path, match.group(0))
        for path, source in sorted(sources.items())
        for match in SESSION_WIRE_LITERAL.finditer(source)
    ]
    if literals != [(LWT_PATH, LWT_LITERAL)]:
        return [
            "session H/J/O/F construction outside reducer; only the "
            "mqttHandshake() host LWT is allowlisted"
        ]

    body = function_body(sources[LWT_PATH], "void mqttHandshake()")
    codec_body = function_body(
        sources.get(LWT_CODEC_PATH, ""),
        "QByteArray DesktopTransportCodec::encodeMqttConnect(",
    )
    required = (
        'QString("F %1 %2")',
        "const bool useWill = pcIsHost_;",
        "DesktopTransportCodec::encodeMqttConnect(",
        "useWill);",
    )
    if (
        body is None
        or any(snippet not in body for snippet in required)
        or codec_body is None
        or "useWill && retainWill ? 1 : 0" not in codec_body
    ):
        return ["mqttHandshake(): host LWT exception changed or moved"]
    return []


def check_mqtt_route_contract(sources: dict[str, str]) -> list[str]:
    source = sources.get(MQTT_ADAPTER_PATH)
    if source is None:
        return [f"{MQTT_ADAPTER_PATH}: missing PC MQTT adapter"]

    inbound = function_body(source, "bool MqttSessionAdapter::routeForTopic")
    outbound = function_body(
        source, "QByteArray MqttSessionAdapter::topicSuffixForRoute"
    )
    if inbound is None or outbound is None:
        return ["PC MQTT route/topic mapping functions missing"]

    inbound_patterns = (
        r'suffix == "meta"\)\s*\{\s*\*route = SESSION_ROUTE_META;',
        r'suffix == "pres_w" \|\| suffix == "pres_b"\)\s*\{\s*'
        r'\*route = SESSION_ROUTE_PRESENCE;',
        r'suffix == "w2b" \|\| suffix == "b2w"\)\s*\{\s*'
        r'\*route = SESSION_ROUTE_GAME;',
        r'suffix == "ack_w" \|\| suffix == "ack_b"\)\s*\{\s*'
        r'\*route = SESSION_ROUTE_ACK;',
    )
    outbound_patterns = (
        r'route == SESSION_ROUTE_META\)\s*\{\s*return "meta";',
        r'state_\.local_color == SESSION_COLOR_UNKNOWN\)\s*\{\s*return \{\};',
        r'case SESSION_ROUTE_CONTROL:\s*return white \? "w2b" : "b2w";',
        r'case SESSION_ROUTE_PRESENCE:\s*return white \? "pres_w" : "pres_b";',
        r'case SESSION_ROUTE_PRESENCE_PEER:\s*return white \? "pres_b" : "pres_w";',
        r'case SESSION_ROUTE_GAME:\s*return white \? "w2b" : "b2w";',
        r'case SESSION_ROUTE_ACK:\s*return white \? "ack_b" : "ack_w";',
    )
    errors = []
    if any(re.search(pattern, inbound) is None for pattern in inbound_patterns):
        errors.append("PC MQTT inbound topic-to-route table changed")
    if any(re.search(pattern, outbound) is None for pattern in outbound_patterns):
        errors.append("PC MQTT outbound route-to-topic table changed")

    literals = set(
        re.findall(r'"(meta|pres_[wb]|[wb]2[wb]|ack_[wb])"', inbound + outbound)
    )
    if literals != MQTT_TOPIC_LITERALS:
        errors.append("PC MQTT route/topic table is incomplete")
    return errors


def check_sources(sources: dict[str, str]) -> list[str]:
    errors = check_lwt_exception(sources) + check_mqtt_route_contract(sources)
    for adapter_path in sorted(ADAPTER_SOURCES):
        adapter = sources.get(adapter_path)
        if adapter is None:
            errors.append(f"{adapter_path}: missing PC session adapter")
        elif not SESSION_STEP.search(adapter):
            errors.append(f"{adapter_path}: adapter does not call session_step()")

    for path in sorted(sources):
        source = sources[path]
        step = SESSION_STEP.search(source)
        if step and path not in ADAPTER_SOURCES:
            errors.append(
                f"{path}:{line_number(source, step.start())}: "
                "session_step() is allowed only in PC session adapters"
            )
        for pattern, description in FORBIDDEN:
            match = pattern.search(source)
            if match:
                errors.append(
                    f"{path}:{line_number(source, match.start())}: "
                    f"{description} ({match.group(0)!r})"
                )
    return errors


def check_tree(root: Path) -> list[str]:
    source_dir = root / PC_SOURCE_DIR
    if not source_dir.is_dir():
        return [f"{PC_SOURCE_DIR}: missing PC client source directory"]

    sources = {
        path.relative_to(root).as_posix(): path.read_text(encoding="utf-8")
        for path in source_dir.rglob("*")
        if path.is_file() and path.suffix.lower() in SOURCE_SUFFIXES
    }
    return check_sources(sources)


def self_test() -> None:
    clean = {
        adapter: "void step() { session_step(state, event); }\n"
        for adapter in ADAPTER_SOURCES
    }
    clean.update({
        LWT_PATH: (
            "void mqttHandshake() {\n"
            "    const bool useWill = pcIsHost_;\n"
            "    willPayload = QString(\"F %1 %2\");\n"
            "    DesktopTransportCodec::encodeMqttConnect(\n"
            "        clientId, 20, willTopic, willPayload, useWill);\n"
            "}\n"
        ),
        LWT_CODEC_PATH: (
            "QByteArray DesktopTransportCodec::encodeMqttConnect() {\n"
            "    encode(useWill && retainWill ? 1 : 0);\n"
            "}\n"
        ),
    })
    clean[MQTT_ADAPTER_PATH] = (
        "void step() { session_step(state, event); }\n"
        "bool MqttSessionAdapter::routeForTopic(const QByteArray &topic, "
        "uint8_t *route) {\n"
        "  if (suffix == \"meta\") { *route = SESSION_ROUTE_META; }\n"
        "  else if (suffix == \"pres_w\" || suffix == \"pres_b\") "
        "{ *route = SESSION_ROUTE_PRESENCE; }\n"
        "  else if (suffix == \"w2b\" || suffix == \"b2w\") "
        "{ *route = SESSION_ROUTE_GAME; }\n"
        "  else if (suffix == \"ack_w\" || suffix == \"ack_b\") "
        "{ *route = SESSION_ROUTE_ACK; }\n"
        "}\n"
        "QByteArray MqttSessionAdapter::topicSuffixForRoute(uint8_t route) "
        "const {\n"
        "  if (route == SESSION_ROUTE_META) { return \"meta\"; }\n"
        "  if (state_.local_color == SESSION_COLOR_UNKNOWN) { return {}; }\n"
        "  switch (route) {\n"
        "  case SESSION_ROUTE_CONTROL: return white ? \"w2b\" : \"b2w\";\n"
        "  case SESSION_ROUTE_PRESENCE: return white ? \"pres_w\" : \"pres_b\";\n"
        "  case SESSION_ROUTE_PRESENCE_PEER: return white ? \"pres_b\" : \"pres_w\";\n"
        "  case SESSION_ROUTE_GAME: return white ? \"w2b\" : \"b2w\";\n"
        "  case SESSION_ROUTE_ACK: return white ? \"ack_b\" : \"ack_w\";\n"
        "  }\n"
        "}\n"
    )
    if check_sources(clean):
        raise SystemExit("[ERR] pc direct policy self-test: clean source rejected")

    legacy = dict(clean)
    legacy[f"{PC_SOURCE_DIR}/main.cpp"] = (
        "bool directReady_;\nvoid f() { sendDirectHello(); }\n"
    )
    errors = check_sources(legacy)
    if not any("transition state" in error for error in errors):
        raise SystemExit("[ERR] pc direct policy self-test: state leak accepted")
    if not any("HELLO helper" in error for error in errors):
        raise SystemExit("[ERR] pc direct policy self-test: helper leak accepted")

    parser_leak = dict(clean)
    parser_leak[f"{PC_SOURCE_DIR}/main.cpp"] = (
        '#include "common/protocol/direct_session_protocol.h"\n'
        'void f() { netchess_direct_parse_start_white_owner("x", 0); }\n'
    )
    errors = check_sources(parser_leak)
    if not any("parser/builder header" in error for error in errors):
        raise SystemExit("[ERR] pc direct policy self-test: parser header accepted")
    if not any("legacy DIRECT parser/builder" in error for error in errors):
        raise SystemExit("[ERR] pc direct policy self-test: parser call accepted")

    misplaced = dict(clean)
    misplaced[f"{PC_SOURCE_DIR}/main.cpp"] = "void f() { session_step(s, e); }\n"
    if not check_sources(misplaced):
        raise SystemExit("[ERR] pc direct policy self-test: direct core call accepted")

    reparsed = dict(clean)
    reparsed[f"{PC_SOURCE_DIR}/main.cpp"] = (
        'bool f(const QByteArray &payload) { return payload.startsWith("NACK"); }\n'
    )
    if not any("reparses" in error for error in check_sources(reparsed)):
        raise SystemExit("[ERR] pc direct policy self-test: typed result reparse accepted")

    mqtt_leak = dict(clean)
    mqtt_leak[f"{PC_SOURCE_DIR}/main.cpp"] = (
        '#include "common/protocol/mqtt_session_protocol.h"\n'
        "bool mqttPeerReady_;\n"
        'void f() { handleRxLine("H W 77"); }\n'
    )
    errors = check_sources(mqtt_leak)
    if not any("MQTT parser/builder header" in error for error in errors):
        raise SystemExit("[ERR] pc direct policy self-test: MQTT parser header accepted")
    if not any("MQTT transition state" in error for error in errors):
        raise SystemExit("[ERR] pc direct policy self-test: MQTT state leak accepted")
    if not any("MQTT policy helper" in error for error in errors):
        raise SystemExit("[ERR] pc direct policy self-test: MQTT helper leak accepted")

    duplicate_lwt = dict(clean)
    duplicate_lwt[LWT_PATH] += 'void f() { QString("F %1 %2"); }\n'
    if not check_lwt_exception(duplicate_lwt):
        raise SystemExit("[ERR] pc direct policy self-test: duplicate LWT accepted")

    bad_route = dict(clean)
    bad_route[MQTT_ADAPTER_PATH] = bad_route[MQTT_ADAPTER_PATH].replace(
        'return white ? "ack_b" : "ack_w";',
        'return white ? "ack_w" : "ack_b";',
    )
    if not check_mqtt_route_contract(bad_route):
        raise SystemExit("[ERR] pc direct policy self-test: bad MQTT route accepted")

    print("[OK] pc session policy self-test")


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
        print("[ERR] pc session policy: legacy policy remains")
        for error in errors:
            print(f"  {error}")
        raise SystemExit(1)

    print(
        "[OK] pc session policy: reducer-owned; MQTT routes pinned; "
        "host LWT pre-link allowlisted"
    )


if __name__ == "__main__":
    main()
