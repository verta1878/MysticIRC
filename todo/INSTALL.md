# Mystic BBS 1.11IRC — Installation Guide

## Fresh Install

### 1. Get the compiler
```bash
git clone https://github.com/verta1878/fpc264irc
cd fpc264irc && ./install.sh   # or install.bat on Windows
```

### 2. Build Mystic
```bash
cd mystic-repo
./build-linux.sh               # Linux
build-win32.bat                # Windows
```

### 3. Create BBS directory
```bash
mkdir /mystic
cp out-linux/* /mystic/        # or out-win32/* on Windows
cd /mystic
./mystic -CFG                  # First-time configuration wizard
```

### 4. Start the server
```bash
./mis SERVER                   # Interactive mode
./mis DAEMON                   # Background mode (Linux)
```

### 5. Connect
```bash
telnet localhost 23            # or your configured port
```

## Upgrade from 1.10

### From g00r00 1.10 A38
1. Back up your entire Mystic directory
2. Build 1.11IRC from source
3. Copy new binaries over old ones (mystic, mis, mplc, mide, mutil, fidopoll)
4. Data files are compatible — no conversion needed
5. Run `mystic -CFG` to verify configuration

### From g00r00 1.12
1. Back up your entire Mystic directory
2. Data files from 1.12 may have new fields — check MYSTIC.DAT compatibility
3. Some 1.12 features (TLS, HTTP server, Python) are not yet in 1.11IRC

## Platform Notes

### Windows XP
- Works with 32-bit builds
- IPv4 only (no IPv6 stack)
- Use Strawberry Perl for future Perl integration

### Linux
- Requires 32-bit libraries on 64-bit systems: `apt install lib32z1`
- Set `mysticbbs` environment variable to BBS path
- Use `mis DAEMON` for background operation
- PID file: `mis.pid` in semaphore directory

### FreeBSD
- Same as Linux, use appropriate fpc264irc target
- May need `compat32` package

### OS/2
- Use OS/2 target in fpc264irc
- FOSSIL driver available via netfosdl.pas

## Directory Structure (installed)

```
/mystic/
├── mystic          BBS binary
├── mis             Internet server
├── mplc            MPL compiler
├── mide            MPL IDE
├── mutil           Maintenance utility
├── fidopoll        FidoNet poller
├── mystic.dat      Main configuration
├── mutil.ini       MUTIL configuration
├── data/           User data, message bases
├── text/           Display files (ANSI screens)
├── scripts/        MPL scripts
├── logs/           Log files
├── semaphore/      Lock files (mis.bsy, mutil.bsy)
├── echomail/       FidoNet echomail
└── filebase/       File areas
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "Cannot read MYSTIC.DAT" | Run `mystic -CFG` first, or set `mysticbbs` env var |
| "MUTIL already running" | Delete `mutil.bsy` in semaphore directory |
| "MIS already running" | Delete MIS lock file, or run `mis SHUTDOWN` |
| Port 23 in use | Change telnet port in `mystic -CFG` → Internet servers |
| Blank screen on connect | Check ANSI display files in text/ directory |
