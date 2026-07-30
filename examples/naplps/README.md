# NAPLPS — North American Presentation Layer Protocol Syntax

Vector graphics protocol for videotex/teletext (1983).
Predecessor/competitor to RIPscrip. Used by Prodigy, Telidon.

## Files

- `NAP.txt` — Concise NAPLPS description (martinreddy.net)
- `FIPS121-NAPLPS-1983.pdf` — FIPS 121 standards document (archive.org)

## Reference Links

- Telidon repo: https://github.com/n1ckfg/Telidon
- Java viewer: https://github.com/n1ckfg/Telidon/tree/master/third_party/ajwm-naplps
- Format info: https://www.fileformat.info/format/naplps/egff.htm
- History: https://tedium.co/2020/07/21/bbs-graphics-history-ripscrip-naplps/

## Notes

NAPLPS uses 7-bit ASCII encoding with Picture Description Instructions
(PDIs). Drawing primitives: lines, arcs, rectangles, polygons, filled
shapes. Resolution-independent normalized coordinates (0 to 1).
Similar to RIPscrip but predates it by ~10 years.
