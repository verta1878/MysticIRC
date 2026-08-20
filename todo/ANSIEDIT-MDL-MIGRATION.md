# ansiedit m_pd* Units → MDL Migration Plan

## Date: 2026-08-19

## Finding

ALL 20 m_pd* units in mystic/ansiedit/ are standalone — ZERO Mystic
dependencies. They use only SysUtils, Classes, and each other (m_pdtypes).
They belong in mdl/.

## Units To Move

### Core Types (move first — everything depends on this)

| Unit | Lines | What |
|------|-------|------|
| m_pdtypes.pas | 254 | Canvas element, attribute, dimensions |

### Format Loaders/Savers (move second)

| Unit | Lines | What |
|------|-------|------|
| m_pdansi.pas | 383 | ANSI escape code loader |
| m_pdansiw.pas | 166 | ANSI with word-wrap loader |
| m_pdascii.pas | 57 | Plain ASCII loader |
| m_pdavatar.pas | 84 | AVATAR (AVT) format loader |
| m_pdbinary.pas | 60 | Binary (2-byte char+attr) loader |
| m_pdidf.pas | 64 | iCE Draw Format loader |
| m_pdpcboard.pas | 167 | PCBoard @X / Ctrl-A (already in mdl/) |
| m_pdrip.pas | 330 | RIP format handler |
| m_pdtundra.pas | 70 | Tundra format loader |
| m_pdxbin.pas | 163 | XBIN format loader |
| m_pdsauce.pas | 331 | SAUCE metadata reader/writer |

### Graphics / Fonts

| Unit | Lines | What |
|------|-------|------|
| m_pdbitfont.pas | 200 | Bitmap font renderer |

### Editor Core

| Unit | Lines | What |
|------|-------|------|
| m_pdmain.pas | 266 | Main editor dispatcher (loads all formats) |
| m_pdtest.pas | 194 | Test harness |

### Network (teleconference)

| Unit | Lines | What |
|------|-------|------|
| m_pdclient.pas | 234 | PabloDraw client |
| m_pdserver.pas | 177 | PabloDraw server |
| m_pdnet.pas | 940 | Network protocol |

### UI

| Unit | Lines | What |
|------|-------|------|
| m_pdviewfv.pas | 216 | Free Vision viewer (may stay in ansiedit) |
| m_pdcompat.pas | 24 | FPC compatibility shims |

## Migration Phases

| Phase | What | Priority |
|-------|------|----------|
| PD-MIG-1 | Move m_pdtypes.pas to mdl/ | HIGH |
| PD-MIG-2 | Move format loaders (11 units) to mdl/ | HIGH |
| PD-MIG-3 | Move m_pdbitfont.pas to mdl/ | MEDIUM |
| PD-MIG-4 | Move m_pdmain.pas to mdl/ | MEDIUM |
| PD-MIG-5 | Move network units (client/server/net) to mdl/ | MEDIUM |
| PD-MIG-6 | Leave m_pdviewfv.pas in ansiedit (FV-specific UI) | — |
| PD-MIG-7 | Update all Uses clauses in ansiedit | HIGH |
| PD-MIG-8 | Verify ansiedit compiles with mdl/ paths | HIGH |
| PD-MIG-9 | Leave redirects in mystic/ansiedit/ for backward compat | LOW |

## Key Decision

m_pdviewfv.pas stays in ansiedit — it's a Free Vision dialog,
tied to ansiedit's UI. Everything else moves to mdl/.

## Total: ~4,000 lines, 20 units → mdl/

## Dependencies

```
m_pdtypes.pas ← everything depends on this
  ├── m_pdansi.pas, m_pdascii.pas, m_pdavatar.pas, ...
  ├── m_pdbitfont.pas
  ├── m_pdsauce.pas
  └── m_pdmain.pas ← imports all format loaders
        └── m_pdtest.pas ← test harness
```

No circular dependencies. Clean tree. Move m_pdtypes first,
everything else follows.
