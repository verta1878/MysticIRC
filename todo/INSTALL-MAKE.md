# install_make — Building install_data.mys

## What it does

`install_make` creates and appends to `.mys` archive files — Mystic BBS's
own installer payload format. The `install` program reads this file to set
up a fresh BBS installation.

## Quick Start

```
# Build install_data.mys from your Mystic directory:
./make_install_data.sh /home/sysop/mystic

# Or use install_make directly:
./install_make install_data "/path/to/mystic/data/*" DATA
./install_make install_data "/path/to/mystic/text/*" TEXT
./install_make install_data "/path/to/mystic/menus/*" MENUS
./install_make install_data "/path/to/mystic/mystic/scripts/*" SCRIPT
./install_make install_data "/path/to/mystic/docs/*" DOCS
```

## Syntax

```
install_make <NAME> <FILEMASK> <EID>
```

| Parameter | Description |
|-----------|-------------|
| `NAME` | Output filename (without `.mys` extension — it's added automatically) |
| `FILEMASK` | File glob pattern for files to add (e.g. `/path/to/data/*`) |
| `EID` | Section identifier — max 6 chars (e.g. `DATA`, `TEXT`, `MENUS`) |

## How it works

1. First call creates a new `.mys` archive (or opens an existing one to append)
2. All files matching `FILEMASK` are added with the specified `EID` section tag
3. Files are stored **verbatim** — no compression
4. Call it once per section to build the complete archive

## The 6 standard sections

| EID | Source directory | Contents |
|-----|-----------------|----------|
| `DOCS` | `docs/` | Documentation (mystic.txt, records.110, etc) |
| `DATA` | `data/` | Binary data files (.dat, .cfg, default databases) |
| `TEXT` | `text/` | ANSI/ASCII screens and prompts (.ans, .asc) |
| `MENUS` | `menus/` | Menu definitions (.mnu) |
| `SCRIPT` | `mystic/scripts/` | MPL scripts (.mps, .mpx) and helper binaries |
| `ROOT` | `(root)` | Top-level files (mystic.dat, config files) |

The `install` program extracts these sections to their respective directories
when setting up a new BBS.

## Examples

### Build from scratch

```bash
# Start fresh — delete any existing archive
rm -f install_data.mys

# Add each section
./install_make install_data "/home/sysop/mystic/docs/*" DOCS
./install_make install_data "/home/sysop/mystic/data/*" DATA
./install_make install_data "/home/sysop/mystic/text/*" TEXT
./install_make install_data "/home/sysop/mystic/menus/*" MENUS
./install_make install_data "/home/sysop/mystic/mystic/scripts/*" SCRIPT

# Root files (specific files, not everything)
./install_make install_data "/home/sysop/mystic/mystic.dat" ROOT
./install_make install_data "/home/sysop/mystic/default.txt" ROOT
```

### Use the wrapper script

```bash
# Point it at your Mystic install directory
./make_install_data.sh /home/sysop/mystic

# Specify a custom install_make path
INSTALL_MAKE=/usr/local/bin/install_make ./make_install_data.sh /home/sysop/mystic
```

### Build a release package

```bash
# 1. Build install_data.mys from your BBS
./make_install_data.sh /home/sysop/mystic

# 2. Move it where make_release.sh expects it
cp install_data.mys /path/expected/

# 3. Build FULL + UPD packages for all platforms
INSTALL_DATA=./install_data.mys ./make_release.sh
```

## The .mys archive format (version 3)

The MYS format is a simple uncompressed archive. No external tools (zip, tar,
etc) are needed — `install_make` creates it, `install` reads it.

### Archive header (12 bytes, at offset 0)

| Field | Type | Size | Value |
|-------|------|------|-------|
| Header | String[4] | 6 bytes | `'MYS' + #26` |
| Version | Word | 2 bytes | `3` |
| Files | LongInt | 4 bytes | Total file count |

### Per-file record (100 bytes + file data)

| Field | Type | Size | Description |
|-------|------|------|-------------|
| Header | String[4] | 6 bytes | `'MYS' + #26` (validates record) |
| FileName | String[80] | 81 bytes | Lowercase filename (no path) |
| FileSize | LongInt | 4 bytes | Byte count of stored file |
| Execute | Boolean | 1 byte | Executable flag (from +x on Unix) |
| EID | String[6] | 7 bytes | Section identifier |

Immediately followed by `FileSize` raw bytes of the file.

### Verifying an archive

The first 5 bytes of a valid `.mys` file are: `04 4D 59 53 1A`
(`#4 'M' 'Y' 'S' #26`).

## Source files

| File | Description |
|------|-------------|
| `mystic/install_make.pas` | The `install_make` program |
| `mystic/install_arc.pas` | MYS archive format (read/write routines) |
| `mystic/install.pas` | The `install` program (reads install_data.mys) |
| `make_install_data.sh` | Wrapper script — calls install_make for all 6 sections |
| `make_release.sh` | Release builder — creates FULL and UPD packages |

## Notes

- Files are stored uncompressed — archive size equals sum of all files + headers
- Filenames are lowercased automatically by install_make
- Filenames must be <= 80 characters
- EID section tags must be <= 6 characters
- The archive appends — calling install_make multiple times adds to the same file
- Delete the `.mys` file first if you want to start fresh
- The `install` program extracts by matching EID — files with non-matching EIDs are skipped
