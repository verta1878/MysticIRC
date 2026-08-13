# mystic_perl — Perl Integration for Mystic BBS

## Status
Planning stage. Mystic 1.12 shipped with Python 2.7/3.x embedding
but no Perl support. This directory will hold the Perl integration.

## Approach
Same pattern as Python — load perl DLL/SO at runtime, expose
mystic_bbs functions to Perl scripts via XS or FFI.

- Windows: `perl5xx.dll` (Strawberry Perl or ActivePerl)
- Linux: `libperl.so`
- Optional — auto-detect at startup, skip if not found

## BBS Functions to Expose
Same API as Python's `mystic_bbs` module:
- write, writeln, getkey, getstr, getuser
- onekey, keypressed, menucmd, shutdown
- gotoxy, textattr, showfile, access, hangup, log

## Menu Commands
- PERL [drive][path]filename — Execute Perl script

## Example

```perl
#!/usr/bin/perl
use mystic_bbs;

mystic_bbs::writeln("Welcome to the Perl door!");
mystic_bbs::write("Enter your name: ");
my $name = mystic_bbs::getstr(0, 30, 30, "");
mystic_bbs::writeln("Hello, $name!");
mystic_bbs::writeln("Press any key...");
mystic_bbs::getkey();
```

## Dependencies
- Perl 5.x installed on the system
- 32-bit Perl for 32-bit Mystic, 64-bit for 64-bit
