# HTML 1.0 Implementation Notes (v4.0)

## Supported Tags (44)

Document: HTML, HEAD, TITLE, BODY, META
Block: H1-H6, P, BR, HR, PRE, BLOCKQUOTE, CENTER, DIV
Inline: B, I, U, TT, EM, STRONG, SMALL, SUB, SUP, FONT
Lists: UL, OL, LI, DL, DT, DD
Links/images: A, IMG
Tables: TABLE, TR, TD, TH, CAPTION
Forms: FORM, INPUT, SELECT, OPTION, TEXTAREA

## Features

- Full tokenizer with attribute parsing
- Entity decoding (named + numeric, CP437 mapped)
- DOM-lite tree (128 nodes, 4 attrs/node, parent/child/sibling)
- Box model layout (margins, indents, text flow, line breaking)
- Void element detection (BR, HR, IMG, INPUT, META)
- Auto-close for P, LI, DT, DD, TR, TD, TH, OPTION
- Direct pixel rendering (HTMLRenderPage)
- Comment and DOCTYPE support
- Malformed HTML tolerance

## Limitations

- No CSS (fixed default styles per tag)
- No JavaScript
- No frames or iframes
- No table column width calculation (simple flow only)
- No image loading (IMG tag recognized, src stored, not fetched)
- No form input handling (tags recognized, not interactive)
- No FONT color/size attributes (tag recognized, attrs stored)
- Text limited to 80 chars per node (stack safety)
- Max 128 nodes per document
- Max 128 layout boxes per page
- HTMLRenderToRIP delegates to HTMLRenderPage (direct pixel render)

## Extended Features (implemented in v4.0)

- FONT COLOR — #RRGGBB and 10 named colors (red, green, blue,
  white, black, yellow, cyan, magenta, gray, silver)
- FONT SIZE — 1-7 mapped to 8-28px font heights
- BGCOLOR on BODY — #RRGGBB and named colors, fills canvas

## Extended Features (implemented in v4.0 cont.)

- TABLE layout — equal-width column layout, cell count detection
- FORM elements — INPUT, SELECT, TEXTAREA rendered as bordered boxes
- IMG — loads image via engine (JPG, PNG, GIF, BMP, PCX by extension)
- A HREF — creates RIP mouse field for click region (host handles click)

## What Works Well

- Simple text pages with headings, paragraphs, lists
- Bold, italic, underline, monospace formatting
- Horizontal rules
- Ordered and unordered lists with bullets/numbers
- Nested structure (blockquotes, nested lists)
- Comments preserved in DOM tree
- Entity decoding for common HTML entities
