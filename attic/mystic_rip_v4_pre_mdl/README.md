# RETIRED — RIPscrip v4.0 Engine

## Status: RETIRED (2026-08-19)

This engine is no longer maintained. Preserved with all fixes applied.
Superseded by m_rip.pas in mdl/ (one engine, plugin codecs).

## Final State

- File: rip4api.pas
- Version: 3.1.0-irc
- Lines: 8653
- Commands: ~115
- Fixes applied: WriteIcon (ICN writer), ClipValid, SanitizePath, WriteClipboardICN

## Why Retired

Four engines (v1-v4) consolidated into one (m_rip.pas) per crew decision.
Plugin codec registration replaces hard Uses clause.
Handler registration replaces {} conditionals.
See docs/MYSTIC-RIP-MIGRATION.md for full plan.

## Credits

- kiddo — engine code, bug fixes, stub completion
- sysop/0 — codecs, HTML renderer, audio, print drivers
- hexadecimal — plugin architecture, retirement review
- verta1878 — project lead
