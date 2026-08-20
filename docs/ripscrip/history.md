# RIPscrip / TeleGrafix - A Documented History

A timeline of TeleGrafix Communications, Inc. and its RIPscrip products, as far as surviving documentation allows. Every date below is tied to a cited source; claims that rest on inference or a single recollection are flagged. See [rights.md](../reference/rights.md) for the fate of the intellectual property, and [README.md](README.md) for what each specification version represents.

**Terminology:** **RIPscrip** is the language itself. **RIPterm** was TeleGrafix's BBS client for dial-up/modem connections; **RIPtel** was its telnet-based successor. RIPaint and RIPdraw were the companion paint/drawing tools.

## Origins (1992-1993)

TeleGrafix Communications, Inc. was founded in **1992** in Huntington Beach, California by **Jeff Reeder** (who left AST Research to co-found), **Jim Bergman**, and **Mark Hayton**. Their idea: bring point-and-click vector graphics to text-only Bulletin Board Systems over dial-up modems.

The specification went through rapid public revisions in 1993:

| Spec | Date | Notes |
| --- | --- | --- |
| RIPscrip 1.50 | Jan 18, 1993 | First public specification, built on Borland BGI graphics primitives |
| RIPscrip 1.50.02 | Mar 1, 1993 |  |
| RIPscrip 1.51 | Mar 29, 1993 |  |
| RIPscrip 1.52 | Apr 20, 1993 |  |
| RIPscrip 1.53 | May 12, 1993 |  |
| **RIPscrip 1.54** | **Jul 19, 1993** | The classic standard - the version the BBS world actually deployed. Preserved here: [1.5x edition](1.54/ripscrip/README.md) |

(Spec dates per the [Break Into Chat wiki](https://breakintochat.com/wiki/Remote_imaging_protocol) and the [BBS Documentary library](http://www.bbsdocumentary.com/library/PROGRAMS/GRAPHICS/RIPSCRIPT/); 1.54 confirmed by the original text preserved in this repository.)

Adoption was fast - John C. Dvorak praised RIPscrip in PC Magazine in 1993, and Searchlight BBS became the first BBS package with built-in RIP support. RIPterm (DOS) was TeleGrafix's own terminal, with RIPaint and RIPdraw as its paint/drawing tools; RIPterm 1.54 was also distributed as FreeWare.

In **1994**, broadcasting-industry veteran **Pat Clawson** purchased a large stake in the company and became President & CEO - just as the public World Wide Web began collapsing the BBS market RIPscrip was built for ("It was a tidal wave," Clawson later told the [Washington Post](https://www.washingtonpost.com/archive/business/1997/01/06/upstaged-but-hardly-undone/a9d123c5-8c50-4012-b83f-a8a67b9d96eb/)).

## The 2.x era (1993-1997)

The 2.0 specification circulated as five ALPHA drafts (A0-A4); the last published RIPscrip document of any kind is [**2.00 ALPHA 4**, Dec 13, 1994](2.0/ripscrip/README.md).

| Release | Date | Notes |
| --- | --- | --- |
| RIPterm Professional 2.0 (DOS install, two-disk set) | Jan 23-24, 1995 | ["TeleGrafix Ships First RIPscrip 2.0 Online Multimedia Software"](https://web.archive.org/web/20080122111345/http://scout.wisc.edu/Projects/PastProjects/NH/95-01/95-01-30/0003.html) - JPEG images, outline fonts (shipped as Atech FastFont `.FF1` files, the "Adobe Type 1/TrueType-style" fonts of the press release); GIF dropped over the Unisys LZW licensing dispute. A commercial (non-shareware) 32-bit DOS4GW protected-mode program; the recovered install (see [CONTRIBUTING.md](../CONTRIBUTING.md)) confirms digitized **.WAV audio** (HMI sound drivers, 19 supported sound boards), **JPEG decoding**, **BMP/BMM/BMH icons** with automatic conversion of 1.x `.ICN`/`.MSK`/`.HOT` icons, and eight video modes up to **1024×768×256** (117 card/mode combinations). The launch letter announced Mac and Windows versions "soon" (with ResNova Software) and a "Project Apache" Internet/WWW effort - neither verifiably shipped under those names. |
| RIPterm Test Drive 2.00.01 | 1995 | Crippleware evaluation build of RIPterm Pro 2.0 (self-extractor banner "RIPterm Test Drive v2.00.01 … Copyright (c) 1992-95"; [preserved download](../reference/downloads.md)) |
| RIPterm Pro Test Drive 2.10.00 / 2.11.00 | Aug 13 / Sep 7, 1995 | Test Drive line continued - the "RIPterm 2.1" long assumed never to have existed. Documented by the v2.11.00 README.DOC changelog ([preserved download](../reference/downloads.md)); 2.11.00's listed changes: JPEG display ~20% faster, Sound Blaster 16/ASP-16/AWE-32 detection fixes, keystroke-macro saving fix, and button world-coordinate/font-size corrections |
| RIPterm 2.20.00 / RIP-2 launch | Nov 19 / [Dec 20, 1995](https://groups.google.com/g/nz.comp/c/uqvFCUynE5w) | "RIP-2 Internet Multimedia": RIPterm v2.2 shareware (DOS), RIPaint-2, RIPweb - "integrates JPEG photographic images, complex SVGA graphics, text and digital WAV sound" |
| RIPterm 2.20.01 | Nov 28, 1995 | Maintenance release; extended the wire protocol past the published spec (icon-transparency flag on RIP_BUTTON_STYLE) |
| RIPterm 2.30 "Evaluation Edition" | [Oct 27, 1997](https://web.archive.org/web/20000919190158/http://www.telegrafix.com:80/products/ripterm/) | Final RIPterm; shareware distribution with a DOS-based installer (`INSTALL.BAT` + PKZIP self-extractor). Its own changelog (dated 10/25/97; packaged 10/27) says "primarily a maintenance release" - the substantive change is a DOS/4GW → DOS/4GW Professional 2.01a extender upgrade fixing OS/2 crashes and improving Windows DOS-box reliability. Undocumented package changes (per the recovered distribution): the five `.FF1` outline fonts reformatted to `.RFF` (the exact font set RIPtel 3.1 later ships), all legacy 1.x-format icons (`.ICN`/`.MSK`/`.HIC`) dropped, 60-day evaluation licensing added. The engine still identifies as `RIPSCRIP020000` - no language change |

Three things the record makes clear, contrary to common assumption:

- **"RIPterm 2.1" did exist - but only as Test Drive crippleware.** The commercial/shareware line jumps 2.0 → 2.20.00 → 2.20.01 → 2.30, and the gap is filled by the crippleware Test Drive releases v2.10.00 (Aug 13, 1995) and v2.11.00 (Sep 7, 1995) - documented by the v2.11.00 README.DOC changelog in the [preserved distribution](../reference/downloads.md). **No RIPscrip 2.1/2.2 specification** was ever published; those numbers exist only as product versions.
- **Every RIPterm 2.x release was a DOS product - installers and programs alike.** RIPterm 2.0 was a two-disk DOS install; the 2.30 shareware distribution installs via `INSTALL.BAT` and a PKZIP self-extractor, and the client itself is a 32-bit DOS4GW protected-mode DOS executable throughout the line. The 2.30 install ships Windows DOS-box conveniences (`.PIF` launch profiles, icons, HMI `.386` sound drivers for enhanced-mode Windows) but no Windows program; a Windows-native or Mac client never verifiably shipped.
- **The "multimedia" features often credited to 3.x shipped in January 1995 with RIPterm Pro 2.0** - background **.WAV audio**, JPEG display, SVGA/256-color modes, BMP icons, and Atech outline fonts are all present in the 2.0 install, not later additions of the 2.2x or 3.x releases (see the [3.x revision-history note](3.0/ripscrip/1.0-introduction.md#revision-history) and the [2.x assets](2.0/assets/fonts/README.md)).

In **April 1996** the company relocated from Huntington Beach to Winchester, Virginia (near Clawson's home), reincorporating as a Virginia corporation.

## The 3.x era and RIPtel (1996-1997)

| Event | Date | Notes |
| --- | --- | --- |
| ["Web & Telnet Sites Go Graphical with RIPscrip-3"](https://groups.google.com/g/comp.os.ms-windows.programmer.graphics/c/PMcnQe8n58Y) | Nov 12, 1996 | Usenet announcement by Clawson |
| [RIPscrip 3.0 Technical White Paper](3.0/text/RIPScrip-3.x-technical-whitepaper.txt) | Dec 6, 1996 | By Jeff Reeder - the only 3.0 document ever published. A promised 450-page specification never appeared |
| RIPtel Visual Telnet 3.0 (pre-release) | Dec 25, 1996 | Two years in development as codename "Mohawk"; Win 3.1/95/NT, telnet-based ([Washington Post](https://www.washingtonpost.com/archive/business/1997/01/06/upstaged-but-hardly-undone/a9d123c5-8c50-4012-b83f-a8a67b9d96eb/), [Usenet](https://groups.google.com/g/comp.bbs.majorbbs/c/x25xTrBYTH8)); commercial release followed in 1997 |
| **RIPtel Visual Telnet 3.1** | [Oct 21, 1997](https://web.archive.org/web/20010513104306/http://www.telegrafix.com:80/products/riptel/) | The final RIPscrip client, shipping RIPscrip driver 3.0.7 - the engine this repository's [3.x reconstruction](3.0/ripscrip/README.md) documents |

Later accounts (including Wikipedia) describe RIPscrip 3.0 as merely "planned" - that is wrong. RIPscrip 3.x **absolutely shipped**, as evidenced by the RIPtel 3.0 and 3.1 releases; what never appeared was the 3.0 _specification_ (the promised 450-page document), which is why the 3.x record here is a reconstruction.

## Decline and fade-out (1998-2006)

RIPtel could not compete with the Web. In **1998** TeleGrafix pivoted, acquiring **Searchlight BBS** (with the Spinnaker web server) and **ProBoard BBS**, announcing a merged product codenamed "Cherokee" that never shipped. Activity wound down through ProBoard Y2K betas (2000) to the last documented site update - ProBoard v2.20h, **July 26, 2001** ([last live homepage capture](https://web.archive.org/web/20011126224446/http://telegrafix.com:80/)).

No shutdown was ever announced; the company simply faded. The telegrafix.com domain **expired June 18, 2006** ([parking-page capture](https://web.archive.org/web/20060629195123/http://www.telegrafix.com:80/)), and with it the last trace of TeleGrafix online. No formal dissolution record, and no transfer of the RIPscrip intellectual property, has ever been found - see [rights.md](../reference/rights.md).

## The people

**Pat Clawson** (Nov 5, 1954 - Oct 29, 2015) - President & CEO from 1994. Before TeleGrafix he was an investigative journalist and broadcaster (CNN, NBC News Radio, Radio & Records Washington Bureau Chief). He died at his home in Swartz Creek, Michigan, at age 60 ([obituary](https://www.sharpfuneralhomes.com/obituaries/patrick-clawson), [AllAccess](https://www.allaccess.com/net-news/archive/story/147244/former-r-r-washington-bureau-chief-longtime-invest)). _Identification note: the obituaries do not mention TeleGrafix; the match rests on the exact career correspondence with the "broadcasting industry veteran" of the 1997 Washington Post profile, and is considered near-certain but inferred._

**Jeff Reeder** - co-founder, principal designer of RIPscrip, author of the 3.0 white paper (his corporate title was, wonderfully, "Chairman of the Board & Cyberwizard"). No verifiable post-TeleGrafix trail has been found - but of the company's principals, he is realistically **the only person left who may hold more information** about RIPscrip's undocumented 2.x/3.x internals, the unpublished 3.0 specification, or the fate of the company's materials.

**Jim Bergman** (EVP) and **Mark Hayton** (VP/CTO) - co-founders; no post-TeleGrafix trail found.

## Primary sources

- [Break Into Chat wiki - Remote Imaging Protocol](https://breakintochat.com/wiki/Remote_imaging_protocol)
- [BBS Documentary library - RIPscrip](http://www.bbsdocumentary.com/library/PROGRAMS/GRAPHICS/RIPSCRIPT/) (spec archives, white paper)
- [Washington Post, "Upstaged but Hardly Undone" (Jan 6, 1997)](https://www.washingtonpost.com/archive/business/1997/01/06/upstaged-but-hardly-undone/a9d123c5-8c50-4012-b83f-a8a67b9d96eb/)
- Wayback Machine captures of telegrafix.com, 1996-2006 (linked inline above)
- Usenet announcements via Google Groups historical archives (linked inline above)
- [Tedium - "The Great Graphics Face-Off" (2020)](https://tedium.co/2020/07/21/bbs-graphics-history-ripscrip-naplps/)
- [ProBoard history file](http://software.bbsdocumentary.com/IBM/DOS/PROBOARD/pbhistory.txt) · [BBS Software Development News #13](http://archives.thebbs.org/bbsnews/bbsnews13.html)
- This repository's preserved originals: [1.54 spec](1.54/text/RIPScrip-1.54.txt), [2.00 ALPHA 4 spec](2.0/text/RIPScrip-2.0-alpha-4.txt), [3.0 white paper](3.0/text/RIPScrip-3.x-technical-whitepaper.txt), and the RIPterm 2.30 / RIPtel 3.1 install artifacts catalogued in [CONTRIBUTING.md](../CONTRIBUTING.md)
