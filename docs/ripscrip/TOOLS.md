# RIPscrip Development Tools

Tools used for developing, testing, and debugging the mystic_rip
RIPscrip engine and ans2rip converter.

## ansilove

ANSI art renderer. Converts .ans files to PNG images for visual
comparison against RIP conversions. Standard tool in the IRC/BBS
art scene.

Install:
    apt-get install ansilove

Usage:
    ansilove -o output.png input.ans

Notes:
    - Renders CP437 with 8x16 VGA font
    - Warns if no SAUCE record (harmless)
    - Output is true-color PNG

## ImageMagick

Image processing toolkit. The `compare` command diffs two images
pixel by pixel, highlighting differences in red. The `montage`
command creates side-by-side comparison images.

Install:
    apt-get install imagemagick

Usage:
    # Pixel diff with error count
    compare -metric AE original.png converted.png diff.png

    # Side-by-side comparison
    montage original.png converted.png -tile 2x1 -geometry +4+4 side.png

    # Normalize size for comparison (ANSI is 8x16, RIP is 8x8)
    convert input.png -resize 640x350! normalized.png

    # Convert BMP to PNG
    convert input.bmp -type TrueColor PNG24:output.png

    # Get image info
    identify image.png

## rip_render

Our headless RIP renderer. Part of mystic_rip (FPC, no dependencies).
Renders .rip files to 24-bit BMP via TTermRip + TRipSurface.

Build:
    fpc -Mobjfpc rip_render.pas

Usage:
    rip_render input.rip output.bmp
    rip_render --sample output.bmp

Notes:
    - 640x350 EGA resolution
    - Handles CRLF, LF, and CR line endings
    - Lists mouse hot-regions defined in the RIP stream
    - No SDL or display needed (headless)

## Validation workflow

The standard process for verifying ans2rip conversions:

    # 1. Render the original ANSI
    ansilove -o original.png input.ans

    # 2. Convert ANSI to RIP
    ./ans2rip input.ans output.rip

    # 3. Render the RIP conversion
    ./rip_render output.rip converted.bmp
    convert converted.bmp -type TrueColor PNG24:converted.png

    # 4. Compare (pixel count that differs)
    compare -metric AE original.png converted.png diff.png

    # 5. Side-by-side for visual inspection
    montage original.png converted.png diff.png \
        -tile 3x1 -geometry +4+4 comparison.png

Note: ANSI renders at 8x16 font, RIP at 8x8 pixel bars. Direct
pixel comparison requires normalizing to the same resolution:

    convert original.png -resize 640x350! original_norm.png

The pixel diff count will never be zero due to font differences.
Focus on structural accuracy: correct colors, correct positions,
correct character coverage.

## Bugs found with this workflow

### Bug: chained RIP commands missing !| prefix

Date: 2026-07-17

Symptom: ans2rip output rendered as all-black in rip_render.

Root cause: RipNewCommand in ans2rip.pas wrote |Op (without !)
when chaining commands on one line. RIP requires !| before every
command. TTermRip.ParseLine scans for !| pairs to split commands.

Example:
    Wrong:  !|S0102|B08040F07    (second | has no !)
    Right:  !|S0102!|B08040F07   (both have !|)

Fix: RipNewCommand now always writes !| regardless of line position.

### Bug: rip_render CRLF handling

Date: 2026-07-17

Symptom: RIP files with CRLF line endings rendered as all-black.

Root cause: rip_render only converted LF to CR, not CRLF to CR.
TTermRip.Process uses CR (#13) as the line terminator.

Fix: Added CRLF -> CR conversion before the LF -> CR fallback
in rip_render.pas.
