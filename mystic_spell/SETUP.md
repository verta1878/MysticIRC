# Hunspell Spell Check Setup

Mystic BBS and mterm use Hunspell for spell checking. Two things are
needed: the library (DLL/SO) and a dictionary.

## 1. Hunspell Library

### Windows
Place ONE of these in the BBS root or system PATH:
- `libhunspell32.dll` (32-bit, for our i386 build)
- `hunspell.dll`

Sources:
- Mystic 1.12 ships `mystic_spellcheck_v2.zip` with the DLL
- LibreOffice/OpenOffice includes hunspell DLLs
- Firefox/Thunderbird include hunspell DLLs
- Build from source: https://github.com/hunspell/hunspell

### Linux
Install via package manager:
```
apt install libhunspell-dev    # Debian/Ubuntu
yum install hunspell-devel     # RHEL/CentOS
```
Library names tried: `libhunspell.so`, `libhunspell-1.7.so.0`, `libhunspell-1.6.so.0`

### macOS
```
brew install hunspell
```
Library: `libhunspell.dylib`

## 2. Dictionary Files

Two files needed in your BBS data directory:
- `dictionary.aff` — affix rules
- `dictionary.dic` — word list

### Download English (US) Dictionary

From LibreOffice (recommended):
```
wget -O dictionary.aff "https://cgit.freedesktop.org/libreoffice/dictionaries/plain/en/en_US.aff"
wget -O dictionary.dic "https://cgit.freedesktop.org/libreoffice/dictionaries/plain/en/en_US.dic"
```

Or from the wooorm/dictionaries GitHub:
```
https://github.com/wooorm/dictionaries/tree/main/dictionaries/en
```
Download `index.aff` → rename to `dictionary.aff`
Download `index.dic` → rename to `dictionary.dic`

### Other Languages

Hunspell dictionaries are available for 100+ languages. Download
the `.aff` and `.dic` for your language from:
- LibreOffice: https://cgit.freedesktop.org/libreoffice/dictionaries/
- OpenOffice extensions: https://extensions.openoffice.org/
- Mozilla/Firefox addons (`.xpi` files are ZIP — extract the .aff/.dic)

Rename to `dictionary.aff` and `dictionary.dic` and place in data path.

## 3. Custom Word List (Optional)

Create `spellcheck.txt` in your data directory with BBS-specific terms:
```
BBS
ANSI
RIPscrip
FidoNet
sysop
telnet
echomail
netmail
QWK
```
One word per line. These words won't be flagged as misspelled.

## 4. Verify

If spell check is working, the FS editor command menu shows 'K' for
spell check. If the library or dictionary is missing, it shows
"Spell check not available (dictionary not found)".

## File Locations

```
c:\mystic\                     BBS root
  libhunspell32.dll            Hunspell library
  data\
    dictionary.aff             Affix rules
    dictionary.dic             Word list
    spellcheck.txt             Custom words (optional)
```

## Pre-built Libraries in Repo

The attic has pre-built hunspell libraries:
```
attic/retired-libs/win32/libhunspell32.dll       (Windows 32-bit)
attic/retired-libs/linux-i386/libhunspell-1.7.so.0  (Linux i386)
attic/retired-libs/darwin-i386/libhunspell-1.6.0.dylib  (macOS)
```
Copy the appropriate one to your BBS directory.
