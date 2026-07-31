# utrayit — Console Tray/Minimize Unit for FPC

Cross-platform unit that lets console programs minimize to the Windows
system tray (notification area) or iconify on Unix terminals.

## Quick Start

```pascal
uses utrayit;

var Tray: TTrayIt;
begin
  Tray := TTrayIt.Create;
  Tray.TrayConsole('My App - click to restore');
  { ... your program runs here ... }
  Tray.UnTrayConsole;
  Tray.Free;
end.
```

## Adding a Custom Icon

1. Create your `.ico` file (use `mkicon` from examples/)
2. Create a `.rc` file: `MAINICON ICON "myapp.ico"`
3. Compile: `windres myapp.rc -o myapp.res`
4. Add to program: `{$R myapp.res}`

The tray loads MAINICON from the embedded resource automatically.

## Files

- `utrayit.pas` — the unit (one file, no dependencies)
- `default.ico` — default Mystic icon
- `trayicon.rc` — resource script
- `trayicon.res` — compiled resource

## Platform Support

| Platform | Tray | Notes |
|----------|------|-------|
| Win32/Win64 | Yes | Shell_NotifyIconW |
| Linux/Unix | Iconify | XTWINOPS escape sequences |
| DOS/OS2 | Stubs | Compiles, does nothing |

## License

GPLv3 — Mystic BBS IRC Fork Contributors, 2026.
