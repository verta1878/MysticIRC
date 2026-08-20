# QWKE extension (as implemented by OpenOLMS)

QWKE extends QWK to carry To/From/Subject longer than QWK's 25-char fields.
See src/olms_qwke.pas.

- The base packet is a normal QWK packet (fully compatible with QWK readers).
- An added text file `TOREADER.EXT` lists long fields, keyed by packet message
  number, one directive per line:
      To: <n> <full recipient>
      From: <n> <full sender>
      Subject: <n> <full subject>
- OpenOLMS emits a directive only when the field exceeds 25 characters, keeping
  the file compact. QWK-only readers ignore TOREADER.EXT.
