# RIP v2/v3/v4 Monolith API Units (pre-VIPER-5)

These are the 5000-8600 line monolith units that duplicated the entire
v1 engine plus version-specific extensions. VIPER-5 replaces them with
slim extension units that import v1's shared base.

- rip2api.pas (5394 lines) — v2 extensions: forms, RFF fonts, higher res
- rip3api.pas (8371 lines) — v3 extensions: client/server, tables, codecs
- rip4api.pas (8646 lines) — v4 extensions: JPEG, print, HTML
- rip3client.pas / rip3server.pas — v3 client/server demos
- rip4client.pas / rip4server.pas — v4 client/server demos

Snapshot date: 2026-09-02, Session 9 VIPER cleanup.
