# Rez2ANS Next

> **Image → ANSI → BBS → Scene**

Rez2ANS Next is a modern image-to-ANSI conversion workshop for the BBS, textmode, and retro-computing communities. Created by **Dennis Martin — Sudden Death**, it turns prepared artwork into authentic CP437 ANSI for BBSes, scene releases, and manual finishing in an ANSI editor.

This is the official **release and documentation** repository. It provides ready-to-install packages, guides, release notes, and community information. Source code is not published here at this time.

## Start here

- [Download the current release](#current-release)
- [Install on Windows or Linux](docs/INSTALLATION.md)
- [Flatpak guide and performance note](docs/FLATPAK.md)
- [Convert your first image](docs/QUICK_START.md)
- [Try the sample conversion profiles](profiles/README.md)
- [Create source artwork with prompt guides](prompts/README.md)
- [Get help or share results](docs/COMMUNITY.md)
- [Contribute, test, or help document the project](docs/CONTRIBUTING.md)
- [See the project direction](docs/ROADMAP.md)

## What it does

Rez2ANS Next analyzes an image in textmode-sized cells and represents each cell with a CP437 character plus DOS-style foreground and background colors. It is not a retro filter: the result is ANSI-oriented artwork built with the same character, color, and grid constraints used by traditional textmode art.

Current release features include:

- CP437 character and 16-color ANSI conversion
- Adjustable image preparation, crop, sizing, palette, and color controls
- ANSI and TheDraw BinaryText (`.bin`) export with SAUCE metadata
- PNG export of the rendered ANSI preview
- Profiles for saving and restoring conversion settings
- A configurable output directory
- Thread-safe multithreaded conversion
- Optional Vulkan acceleration with compatible hardware and drivers
- Windows installer plus Debian/Ubuntu/Mint, AppImage, and Flatpak x64 packages

## Who it is for

Rez2ANS Next is made for BBS sysops, BBS developers, ANSI and ASCII artists, scene coders, art groups, retro-computing fans, and anyone exploring textmode graphics. It can help with board logos, login screens, menus, bulletins, advertisements, scrollers, prototypes, and learning how ANSI construction works.

Automatic conversion is a starting point, not a replacement for an artist’s eye. The strongest results usually come from a good source image followed by manual cleanup in an ANSI editor.

## Current release

### Rez2ANS Next 3.1.0

| Platform | Package | Notes |
| --- | --- | --- |
| Windows x64 | `Rez2ANS-Next-3.1.0-Windows-x64-Setup.exe` | Installer, Start Menu shortcut, and uninstaller |
| Debian/Ubuntu/Mint x64 | `rez2ans-next_3.1.0_amd64.deb` | Native package with portable Qt dependency names |
| Linux x64 | `Rez2ANS_v3.1-x86_64.AppImage` | Portable desktop package; no installation required |
| Linux x64 | `Rez2ANS-Next-3.1.0-x86_64.flatpak` | Sandboxed package; CPU-only and may be slower |

The files and their checksums are in [releases/v3.1.0](releases/v3.1.0). Read the [release notes](releases/v3.1.0/RELEASE_NOTES.md) before installing.

```bash
sha256sum -c SHA256SUMS
```

## A practical workflow

1. Pick or create a source image with a clear subject and strong contrast.
2. Crop and size it for the ANSI screen you want to make.
3. Adjust the image and conversion controls, then generate a preview.
4. Save ANSI, BIN, or a PNG preview.
5. Open the result in an ANSI editor for final lettering, cleanup, and polish.

See the [Quick Start](docs/QUICK_START.md) for source-image guidance and export information.

## Profiles and source-art prompts

The [sample profiles](profiles/README.md) give you ready-to-load starting settings for BBS logos, portraits, and tall scrollers. The [source-art prompt guides](prompts/README.md) help create clear, high-contrast artwork that converts well. Both are starting points: adjust them for the image and save your own successful profiles.

## Project history and respect

Rez2ANS grew from the BBS and ANSI-art tradition. It is intended to make textmode artwork more approachable while respecting the artists, techniques, and culture that made the scene possible. The original FreePascal-era project is preserved by Grymmjack at [grymmjack/rez2ans](https://github.com/grymmjack/rez2ans).

Rez2ANS Next is created and maintained by Dennis Martin, known as **Sudden Death** and co-founder of **CIA — Creators of Intense Art**.

## Community and support

Questions, examples, bug reports, feature ideas, configuration sharing, and general BBS or ANSI discussion are welcome in the Instant Demise Support Discord:

[Join the Instant Demise Discord](https://discord.gg/bemze78N7f)

For public project help, please use the Discord so answers can help the rest of the community too. See [Community and Support](docs/COMMUNITY.md) for what to include in a useful report.

## Development and releases

Rez2ANS Next is actively developed. Settings, conversion behavior, and output may change between releases. Packages are staged in this repository, and a GitHub release is prepared automatically when a matching version tag is published.

## License

Rez2ANS Next is released under **The Unlicense** and is provided as-is, without warranty. Users are responsible for ensuring they have the right to convert and distribute their source images.

---

**Created by Dennis Martin — Sudden Death**
**Rez2ANS Next: Image → ANSI → BBS → Scene**
