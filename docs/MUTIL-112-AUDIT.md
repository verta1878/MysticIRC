# MUTIL 1.12 A49 Audit

Version: MUTIL v1.12 A49 Windows/32 Compiled 2024/05/29

## Command Line

| Command | Description |
|---------|-------------|
| `MUTIL` | Execute using mutil.ini |
| `MUTIL [IniFile]` | Execute using custom INI file |
| `MUTIL [IniFile] -RUN [Command]` | Execute specific functions |
| `MUTIL -RUN [Command]` | Execute one or more (comma separated) |
| `MUTIL -LIST` | List all MUTIL functions |
| `MUTIL -VER` | Show version information |
| `MUTIL -NOSCREEN` | Execute without screen output |

## All Tasks (25 functions)

| INI Key | Display Name | Description |
|---------|-------------|-------------|
| ImportEchoMail | Importing EchoMail | Import Binkley-style FLO echomail/netmail |
| ExportEchoMail | Exporting EchoMail | Export Binkley-style FLO echomail/netmail |
| Import_MessageBase | Import Message Bases | Import by datafile analysis |
| Import_FIDONET.NA | Import FIDONET.NA | Import into message bases |
| Import_FILEBONE.NA | Import FILEBONE.NA | Import into file bases |
| Export_FILEBONE.NA | Export FILEBONE.NA | Export from file bases |
| Export_AREAS.BBS | Export AREAS.BBS | Export from message bases |
| Export_Golded | Export Golded Areas | Export Golded config |
| Import_FILES.BBS | Import FILES.BBS | Import into file bases |
| MassUpload | Mass Upload Files | Mass upload with FILE_ID.DIZ |
| GenerateTopLists | Generating Top Lists | Top callers/posters/etc |
| GenerateAllFiles | Generating AllFiles List | All files listing |
| PurgeMessageBases | Purging Message Bases | By age and max messages |
| PackMessageBases | Packing Message Bases | Pack and renumber |
| PostTextFiles | Post Messages | Post text files to bases |
| MergeNodeLists | Merging Nodelists | Merge into Mystic format |
| FileToss | Toss FDN/TIC Files | TIC + files to BBS/downlinks |
| PackFileBases | Pack File Bases | Pack and check integrity |
| FileSort | FileSort | Sort file base listings |
| LinkMessages | Linking Messages | Echomail reply linking |
| PurgeUserBase | Purge User Base | Mark inactive for deletion |
| PackUserBase | Pack User Base | Remove deleted users + private msgs |
| AutoHatch | Auto Hatch | Auto-hatch files to FDN |
| EchoNodeTracker | Echo Node Tracker | Track echo node activity |
| EchoUnlink | Echomail Unlink | Unlink dead echo areas |

## Logging System

### Configuration (mutil.ini [General])

```ini
logfile = mutil.log          ; comment out to disable
logcache = true              ; 8KB write buffer (recommended)
loglevel = 2                 ; 1=normal, 2=verbose
logstamp = NNN DD HH:II:SS  ; timestamp format (customizable)

; Log roller
logtype = 0                  ; 0=none, 1=by size, 2=by days
maxlogfiles = 3              ; files to keep
maxlogsize = 500             ; KB per file (for type 1)
```

### Log Format
- Each task logs start/completion with timing
- Per-stanza loglevel override (can set verbose for one task only)
- Pipe codes in log: `|15` for values, `|07` for normal text
- BSY file: `mutil.bsy` prevents concurrent execution
- `-NOSCREEN` suppresses console output but still writes log

### Log Messages (from binary)

```
MUTIL v1.12 A49 2024/05/29
Importing EchoMail
  Import from [node]
  Import #[N]
  Export to [node]
  Export [N]
Exporting EchoMail
  Cannot export. Some nodes are BUSY
Purging Message Bases
  Purge by age: [N]
  Purge by max msgs: [N]
  Purge private messages
  Purged [N]
Packing Message Bases
  Packing msgbase: [name]
  Packing lastread
  Packing scan settings
Linking Messages
  Link #[N]
  Linked |15[N]
Merging Nodelists
  Merged |15[N]
Generating Top Lists
  Top Posts
Generating AllFiles List
Mass Upload Files
Toss FDN/TIC Files
  Auto hatch in Base #[N]
  Failed moving TIC file
  Failed moving file
Pack File Bases
  Packing filebase: [name]
FileSort
  Too many files to sort
Purge User Base
Pack User Base
Echomail Unlink
  Unlink [N]
  unlinked
Echo Node Tracker
  Deactivating node [N]
[N] processes complete
```

### Error Messages

```
MUTIL already running (mutil.bsy in Semaphore dir)
Session startup attempted while already running
Cannot open INI file: [path]
Cannot read MYSTIC.DAT
Cannot export. Some nodes are BUSY
Cannot import. Some nodes are BUSY
ERROR: Unable to find echonode [addr]
ERROR: Message in PKT is missing AREA
Error saving message
Error posting
Error creating file: [path]
FAILED TO CREATE ([path])
FAILED TO REMOVE BSY FILE ([path])
FAILED TO REMOVE STALE BSY ([path])
Failed data validation
WARNING: No TAG for [area]
Invalid BaseIdx: [N]
```

## What We Have vs 1.12

| Feature | Our Status | 1.12 |
|---------|-----------|------|
| Core tasks (import/export/pack/purge) | ✅ | ✅ |
| -RUN command (execute specific tasks) | ✅ done | ✅ |
| -LIST (list functions) | ✅ done | ✅ |
| -NOSCREEN | ✅ done | ✅ |
| Log roller (by size/days) | ✅ done | ✅ |
| Per-stanza loglevel override | ✅ done | ✅ |
| Customizable log timestamp | ✅ done | ✅ |
| Log cache (8KB buffer) | ✅ done | ✅ |
| Process timing in log | ✅ done | ✅ |
| EchoNodeTracker | ✅ done | ✅ |
| EchoUnlink | ✅ done | ✅ |
| AutoHatch | ✅ done | ✅ |
| BSY file locking | ✅ | ✅ |
