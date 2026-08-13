#!/usr/bin/env python3
"""Guard the Spectrum/Next transport buffer-ownership contract."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


def fail(msg: str) -> None:
    raise SystemExit(f"[ERR] transport contract: {msg}")


def fn_body(source: str, name: str) -> str:
    match = re.search(
        rf"{name}\s*\([^)]*\)(?:\s+[_A-Za-z]\w*)*\s*\{{(?P<body>.*?)\n\}}",
        source,
        re.S,
    )
    if not match:
        fail(f"missing {name}()")
    return match.group("body")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=".")
    args = parser.parse_args()

    root = Path(args.root)
    app_c = (root / "src/spectrum/app/app.c").read_text(encoding="utf-8")
    net_c = (root / "src/spectrum/transport/net.c").read_text(encoding="utf-8")
    link_h = (root / "src/spectrum/transport/link.h").read_text(encoding="utf-8")

    if "Transport contract shared by Spectrum and Next" not in link_h:
        fail("missing link.h ownership contract")
    scratch_body = fn_body(net_c, "spectrum_net_payload_scratch")
    if "netchesszx_transport_is_mqtt()" not in scratch_body:
        fail("payload_scratch() must select storage by active transport")
    if "direct_rx_payload" not in scratch_body:
        fail("MQTT payload scratch must use inactive DIRECT storage")
    if "SPECTRUM_MQTT_PACKET_SCRATCH" not in scratch_body:
        fail("DIRECT payload scratch must use inactive MQTT storage")
    if "direct_rx_payload2" in scratch_body:
        fail("payload_scratch() aliases the MQTT queued-publish buffer")

    drain_body = fn_body(net_c, "mqtt_drain_uart_budget")
    full_check = drain_body.find("mqtt_stream_len >= MQTT_STREAM_MAX")
    uart_read = drain_body.find("spectrum_uart_read()")
    if full_check < 0 or uart_read < 0 or full_check > uart_read:
        fail("MQTT stream capacity must be checked before consuming UART")

    stream_body = fn_body(net_c, "mqtt_enter_stream_mode")
    if "!spectrum_uart_send_string(\"AT+CIPSEND\")" not in stream_body:
        fail("MQTT stream entry must propagate AT+CIPSEND TX failure")
    if "!spectrum_uart_send_crlf()" not in stream_body:
        fail("MQTT stream entry must propagate CRLF TX failure")

    chat_body = fn_body(app_c, "send_local_chat")
    if "NETCHESSZX_NEXT" in chat_body:
        fail("send_local_chat() must stay client-agnostic")
    if "spectrum_link_payload_scratch()" not in chat_body:
        fail("send_local_chat() must use link scratch storage")

    print("[OK] transport contract: active-backend buffers stay isolated")


if __name__ == "__main__":
    main()
