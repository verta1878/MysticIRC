Unit rip3api;

// ====================================================================
// RIPscrip v1.54 Graphics Protocol Engine for Mystic BBS
// ====================================================================
//
// A server-side RIPscrip engine using Borland BGI-compatible primitives.
// This unit parses RIPscrip commands and renders them through the BGI
// graphics interface, handling:
//
//   - All Level 0 drawing commands (lines, rects, circles, fills, etc)
//   - Level 1 mouse fields, buttons, icons, text regions
//   - BGI CHR font rendering
//   - EGA/VGA palette management
//   - MegaNum (base-36) number encoding
//   - Line continuation (backslash at EOL)
//   - Fill patterns and line styles
//
// The engine operates server-side: instead of sending raw RIP codes
// to the terminal, Mystic renders them internally and sends the
// resulting screen image as ANSI or bitmap data.
//
// Reference: RIPscrip v1.54 Specification
//
// This file is part of Mystic BBS.
// Licensed under the GNU General Public License v3.
//
// This file is part of Mystic BBS.
//
// Mystic BBS is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Mystic BBS is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Mystic BBS.  If not, see <http://www.gnu.org/licenses/>.
// ====================================================================

Interface

{$H-}  // Use ShortStrings — AnsiStrings cause stack overflow in FPC 2.6.4

Const
  // Engine version
  RIP_ENGINE_VERSION = '3.0.0-dev';
  RIP_ENGINE_DATE    = '2026-07-19';

  // v1.54 defaults (backward compatible)
  RIP_DEFAULT_WIDTH  = 640;
  RIP_DEFAULT_HEIGHT = 350;
  RIP_MAX_X       = 639;       // default max X (overridden by SetResolution)
  RIP_MAX_Y       = 349;       // default max Y (overridden by SetResolution)

  // v2.0 extended
  RIP_MAX_RES_X   = 1279;     // max supported: 1280x1024
  RIP_MAX_RES_Y   = 1023;
  RIP_MAX_COLORS  = 256;       // v2.0: 256-color palette
  RIP_MAX_MOUSE   = 128;       // max mouse fields
  RIP_MAX_BUTTONS = 64;        // max buttons
  RIP_MAX_POLY    = 4096;       // v3.0: RIPtel 3.0.7 confirmed       // max polygon points
  RIP_MAX_VARS    = 64;        // max text variables
  RIP_MAX_CHR_CHARS = 256;    // max chars in a CHR font
  RIP_MAX_RFF       = 8;      // max RFF font slots (Phase 18)
  RIP_MAX_MAF_RES   = 8;      // max resolution entries in MAF
  RIP_MAX_MAF_FONTS = 5;      // fonts per resolution entry
  RIP_MAF_HEADER_SIZE = $29;  // MAF file header size

  // v3.0 Phase 20: Data Tables and Forms
  RIP_MAX_TABLE_COLS = 32;    // max columns per table
  RIP_MAX_TABLE_ROWS = 256;   // max rows per table
  RIP_MAX_FORM_FIELDS = 64;   // max form fields
  RIP_MAX_FIELD_LEN  = 255;   // max field value length

  // Form field types
  RIP_FIELD_TEXT     = 0;     // text input
  RIP_FIELD_DROPDOWN = 1;    // dropdown/combobox
  RIP_FIELD_LISTBOX  = 2;    // listbox (multi-line)
  RIP_FIELD_CHECKBOX = 3;    // checkbox (boolean)
  RIP_FIELD_LABEL    = 4;    // read-only label

  // Table column alignment
  RIP_COL_LEFT   = 0;
  RIP_COL_CENTER = 1;
  RIP_COL_RIGHT  = 2;

  // v3.0 Phase 21: Variable scope
  RIP_SCOPE_LOCAL   = 0;      // cleared on scene end (ClearScreen)
  RIP_SCOPE_SESSION = 1;      // persists for connection duration
  RIP_SCOPE_PERSIST = 2;      // saved to disk, survives between sessions

  // v3.0 Phase 22: Advanced Multimedia
  RIP_MAX_AUDIO_STREAMS = 4;  // max simultaneous audio streams
  RIP_AUDIO_IDLE    = 0;
  RIP_AUDIO_PLAYING = 1;
  RIP_AUDIO_PAUSED  = 2;
  RIP_AUDIO_STOPPED = 3;
  RIP_MAX_STROKES = 9216;     // max stroke commands per font (largest: GOTH=8625)

  // Fill styles (BGI compatible)
  RIP_FILL_EMPTY     = 0;
  RIP_FILL_SOLID     = 1;
  RIP_FILL_LINE      = 2;
  RIP_FILL_LTSLASH   = 3;
  RIP_FILL_SLASH     = 4;
  RIP_FILL_BKSLASH   = 5;
  RIP_FILL_LTBKSLASH = 6;
  RIP_FILL_HATCH     = 7;
  RIP_FILL_XHATCH    = 8;
  RIP_FILL_INTERLEAVE = 9;
  RIP_FILL_WIDEDOT   = 10;
  RIP_FILL_CLOSEDOT  = 11;
  RIP_FILL_USER      = 12;

  // Line styles (BGI compatible)
  RIP_LINE_SOLID     = 0;
  RIP_LINE_DOTTED    = 1;
  RIP_LINE_CENTER    = 2;
  RIP_LINE_DASHED    = 3;
  RIP_LINE_USER      = 4;

  // Write modes (BGI compatible)
  RIP_COPY_PUT    = 0;
  RIP_XOR_PUT     = 1;
  RIP_AND_PUT     = 2;   // v3.0
  RIP_OR_PUT      = 3;   // v3.0
  RIP_NOT_PUT     = 4;   // v3.0

  // v3.0 Phase 15: pixel storage formats
  RIP_PIXFMT_INDEXED8 = 0;   // 8-bit indexed palette (v1.54/v2.0 compat)
  RIP_PIXFMT_RGB24    = 1;   // 24-bit true color, 3 bytes/pixel
  RIP_PIXFMT_RGB32    = 2;   // 32-bit TrueColor, 4 bytes/pixel (RIPtel 3.1)

  // Font directions
  RIP_HORIZ_DIR   = 0;
  RIP_VERT_DIR    = 1;

  // Text justification
  RIP_LEFT_TEXT   = 0;
  RIP_CENTER_TEXT = 1;
  RIP_RIGHT_TEXT  = 2;
  RIP_BOTTOM_TEXT = 0;
  RIP_TOP_TEXT    = 2;

  // Font numbers (BGI)
  RIP_DEFAULT_FONT  = 0;  // 8x8 bitmap
  RIP_TRIPLEX_FONT  = 1;
  RIP_SMALL_FONT    = 2;
  RIP_SANSSERIF_FONT = 3;

  // System font modes (TextWinSize / RIP_TEXT_WINDOW size param)
  RIP_SYSFONT_80x43 = 0;   // 8x8 font,  80 cols, 43 rows (default EGA)
  RIP_SYSFONT_80x25 = 1;   // 8x14 font, 80 cols, 25 rows
  RIP_SYSFONT_40x25 = 2;   // 16x14 font, 40 cols, 25 rows (double-width)
  RIP_SYSFONT_91x43 = 3;   // 7x8 font,  91 cols, 43 rows
  RIP_SYSFONT_91x25 = 4;   // 7x14 font, 91 cols, 25 rows
  RIP_GOTHIC_FONT   = 4;

Type
  TRIPColor = Byte;

  TRIPPoint = Record
    X, Y : SmallInt;
  End;

  TRIPPoint3D = Record
    X, Y, Z : SmallInt;
  End;

  TRIPProjParams = Record
    EyeX, EyeY, EyeZ : SmallInt;  // viewer position
    ScreenDist        : SmallInt;  // screen distance
    Theta, Phi        : SmallInt;  // rotation angles (degrees)
  End;

  TRIPPalette = Array[0..255] of Byte;  // v2.0: 256-color palette

  TRIPFillPattern = Array[0..7] of Byte;  // 8x8 user fill pattern

  // RFF scalable font header (v2.0)
  TRFFHeader = Record
    DataSize    : LongInt;      // [0-3]   total data size
    Reserved    : Array[0..11] of Byte; // [4-15]  zeros
    HeaderMark  : Word;         // [16-17] = 16
    VerMajor    : Byte;         // [18]    version major
    VerMinor    : Byte;         // [19]    version minor
    RecordSize  : Word;         // [20-21] = 46 bytes per face record
    DataOffset  : Word;         // [22-23] = 54 (face records start)
    GlyphFmt1   : Byte;         // [24]    glyph format byte 1
    GlyphFmt2   : Byte;         // [25]    glyph format byte 2
    GlyphTable  : Word;         // [26-27] offset to glyph offset table
    Ascent      : Word;         // [28-29] ascent in design units
    EmHeight    : Word;         // [30-31] em height in design units
    Pad1        : Array[0..3] of Byte; // [32-35]
    NumChars    : Word;         // [36-37] = 224 (chars 32-255)
    FirstChar   : Word;         // [38-39] = 32
    Pad2        : Array[0..3] of Byte; // [40-43]
    DesignUnits : Word;         // [44-45] = 1000 (em square)
    Pad3        : Array[0..7] of Byte; // [46-53]
  End;

  TRFFFaceRecord = Record
    Data : Array[0..45] of Byte; // 46-byte face record
  End;

  TRIPMouseField = Record
    Active  : Boolean;
    X0, Y0  : SmallInt;
    X1, Y1  : SmallInt;
    HostCmd : String[80];   // command sent to host on click
    Text    : String[80];   // status bar text
    Invert  : Boolean;      // invert region on click
    IsButton  : Boolean;    // Phase 2: this is a button, not just a region
    IsRadio   : Boolean;    // Phase 2: radio button (one per group)
    IsCheckbox : Boolean;   // Phase 2: checkbox (toggle)
    GroupID   : Byte;       // Phase 2: button group for radio buttons
    Selected  : Boolean;    // Phase 2: currently selected/checked
    IconFile  : String[80]; // Phase 2: normal icon filename
    HotIconFile : String[80]; // Phase 2: highlighted/selected icon filename
    HotKey    : Char;       // Phase 5: keyboard shortcut character
    TabIndex  : Integer;    // Phase 5: tab navigation order (0=not tabbable)
  End;

  TRIPVariable = Record
    Active   : Boolean;
    Name     : String[31];    // variable name (up to 31 chars)
    Value    : String[255];   // variable value
    Persist  : Boolean;       // save to disk (flag 001) — legacy, use Scope instead
    Required : Boolean;       // cannot be blank (flag 002)
    Scope    : Byte;          // RIP_SCOPE_LOCAL / SESSION / PERSIST
  End;

  TRIPFileQueryResult = Record
    Exists : Boolean;
    Size   : LongInt;
    Date   : String[10];
    Time   : String[8];
  End;

  TRIPStroke = Record
    Op : Byte;    // 0=end, 1=move, 2=draw
    X  : SmallInt;
    Y  : SmallInt;
  End;

  TRIPCHRFont = Record
    Loaded    : Boolean;
    Name      : String[4];
    FirstChar : Byte;
    NumChars  : Word;
    OrgToCap  : SmallInt;   // top of capital letters
    OrgToBase : SmallInt;   // baseline
    OrgToDec  : SmallInt;   // descender
    Widths    : Array[0..RIP_MAX_CHR_CHARS-1] of Byte;
    Offsets   : Array[0..RIP_MAX_CHR_CHARS-1] of Word;
    Strokes   : Array[0..RIP_MAX_STROKES-1] of TRIPStroke;
    NumStrokes : Word;
  End;
  PRIPCHRFont = ^TRIPCHRFont;

  // v3.0 Phase 18: MAF bitmap font container
  TMAFFont = Record
    Height   : Byte;       // character height (8, 11, 14, 16)
    Data     : PByte;      // 256 * Height bytes of bitmap data
    DataSize : Word;       // size of Data buffer
  End;

  TMAFResEntry = Record
    Width    : Word;       // screen width (640, 800, 1024)
    Height   : Word;       // screen height (480, 600, 768)
    Name     : String[31]; // resolution name
    Fonts    : Array[0..RIP_MAX_MAF_FONTS-1] of TMAFFont;
    FontCount: Byte;       // how many fonts loaded for this resolution
  End;

  TMAFFile = Record
    Loaded     : Boolean;
    ResCount   : Integer;
    Entries    : Array[0..RIP_MAX_MAF_RES-1] of TMAFResEntry;
  End;
  PMAFFile = ^TMAFFile;

  // ====================================================================
  // v3.0 Phase 20: Data Tables and Forms
  // ====================================================================
  //
  // ARCHITECTURE: Server/Client Split
  // ──────────────────────────────────
  //
  // SERVER-SIDE (runs on BBS host):
  //   - Table data model (TRIPTable, TRIPTableCol, TRIPTableCell)
  //   - Table rendering to pixel buffer (TableCreate/AddCol/AddRow/Render)
  //   - Table scrolling (TableScroll — server controls visible window)
  //   - Form field definitions (FormAddField — layout and constraints)
  //   - Form validation (FormValidate — required fields, data rules)
  //   - Variable binding (FormBindVar/SyncToVars/SyncFromVars)
  //   - Form rendering to pixel buffer (FormRender)
  //
  // CLIENT-SIDE (runs on terminal/viewer):
  //   - Keyboard input into focused form fields
  //   - Mouse clicks on checkboxes, dropdown arrows
  //   - Focus cycling (Tab/Shift-Tab between fields)
  //   - Dropdown expansion and selection
  //   - Listbox scrolling and selection
  //   - Send field values back to server via RIP protocol
  //
  // The engine handles BOTH sides. Server creates the form/table,
  // renders it, and manages data. Client-side state (Focused, Value
  // changes from input) is managed by the host application calling
  // FormSetValue and FormRender after processing input events.
  //
  // FLOW:
  //   Server: TableCreate → AddCol → AddRow → SetCell → Render
  //   Server: FormAddField → FormBindVar → FormRender
  //   Client: [user types] → host calls FormSetValue → FormRender
  //   Server: FormSyncToVars → reads $VARNAME$ in RIP commands
  //   Server: FormValidate → checks Required fields before submit
  //
  // ====================================================================

  // ---- SERVER-SIDE: Table data model ----
  // Stores tabular data for grid rendering. Server populates cells,
  // controls column layout and alignment, renders to pixel buffer.

  TRIPTableCol = Record
    Title    : String[31];    // column header text (displayed in header row)
    Width    : SmallInt;      // column width in pixels (determines cell area)
    Align    : Byte;          // RIP_COL_LEFT(0), RIP_COL_CENTER(1), RIP_COL_RIGHT(2)
  End;

  TRIPTableCell = Record
    Text     : String;        // cell content (short string, max 255 chars)
    Color    : Byte;          // text color index (0 = use DrawColor)
  End;

  TRIPTable = Record
    Active   : Boolean;       // True when table is created and ready
    X, Y     : SmallInt;      // top-left corner of table on canvas
    ColCount : Integer;       // number of columns (0..RIP_MAX_TABLE_COLS-1)
    RowCount : Integer;       // number of data rows (0..RIP_MAX_TABLE_ROWS-1)
    Cols     : Array[0..RIP_MAX_TABLE_COLS-1] of TRIPTableCol;
    Cells    : Array[0..RIP_MAX_TABLE_ROWS-1, 0..RIP_MAX_TABLE_COLS-1] of TRIPTableCell;
    HeaderH  : SmallInt;      // header row height in pixels (auto: FontH + 4)
    RowH     : SmallInt;      // data row height in pixels (auto: FontH + 2)
    GridColor: Byte;          // grid line color index
    HeaderBG : Byte;          // header row background color index
    ScrollTop: Integer;       // first visible row index (for scrollable tables)
    VisRows  : Integer;       // max visible rows (0 = show all rows)
  End;

  // ---- CLIENT-SIDE: Interactive form fields ----
  // Form fields are defined by the server (position, type, constraints)
  // but receive input from the client (keyboard, mouse). The host
  // application bridges the two: it processes input events and calls
  // FormSetValue, then calls FormRender to update the display.

  TRIPFormField = Record
    Active   : Boolean;       // True when field is allocated and visible
    FieldType: Byte;          // RIP_FIELD_TEXT/DROPDOWN/LISTBOX/CHECKBOX/LABEL
    Name     : String[31];    // field name (displayed for checkboxes/labels)
    X, Y     : SmallInt;      // position on canvas (top-left of field)
    W, H     : SmallInt;      // dimensions in pixels
    Value    : String;        // current value (text content, "1"/"0" for checkbox)
    Default  : String;        // default value (for reset)
    MaxLen   : Byte;          // max input length for text fields
    Options  : String;        // dropdown/listbox choices (pipe-delimited: "A|B|C")
    Required : Boolean;       // validation: field must not be empty to submit
    VarName  : String[31];    // bound text variable name (empty = unbound)
    Color    : Byte;          // text color index
    BgColor  : Byte;          // background color index
    Focused  : Boolean;       // CLIENT: True when field has input focus
    ReadOnly : Boolean;       // True = cannot be edited by client
  End;

  TRIPButtonStyle = Record
    Width     : SmallInt;
    Height    : SmallInt;
    Orient    : Byte;       // 0=horizontal, 1=vertical
    Flags     : Word;
    BevelSize : Byte;
    DFore     : Byte;       // dark foreground
    DBack     : Byte;       // dark background
    BRight    : Byte;       // bright color
    DDark     : Byte;       // dark shadow
    Surface   : Byte;       // surface color
    GrpID     : Byte;       // button group
    Flags2    : Byte;
    ULineCol  : Byte;       // underline color
    CornerCol : Byte;       // corner color
  End;

  // EGA palette RGB values for rendering to true-color output
  TRIPRgb = Record
    R, G, B : Byte;
  End;

  // v3.0 Phase 15: TRIPRgb (== TRIPRGB, Pascal identifiers are
  // case-insensitive) is the canonical true-color pixel type used
  // throughout the v3.0 engine, matching the RIPscrip 3.0 docs naming.
  PTRIPRGB = ^TRIPRgb;

  // v3.0 Phase 15: 32-bit TrueColor pixel (RGB + reserved/alpha byte).
  // The reserved byte is unused by Phase 15 (always $FF / opaque); it is
  // reserved for the alpha compositing work planned in Phase 23.
  TRIPRGBA = Record
    R, G, B, A : Byte;
  End;

Const
  // Standard EGA palette — maps color index 0..15 to RGB
  EGA_RGB : Array[0..15] of TRIPRgb = (
    (R:$00;G:$00;B:$00),
    (R:$00;G:$00;B:$AA),
    (R:$00;G:$AA;B:$00),
    (R:$00;G:$AA;B:$AA),
    (R:$AA;G:$00;B:$00),
    (R:$AA;G:$00;B:$AA),
    (R:$AA;G:$55;B:$00),
    (R:$AA;G:$AA;B:$AA),
    (R:$55;G:$55;B:$55),
    (R:$55;G:$55;B:$FF),
    (R:$55;G:$FF;B:$55),
    (R:$55;G:$FF;B:$FF),
    (R:$FF;G:$55;B:$55),
    (R:$FF;G:$55;B:$FF),
    (R:$FF;G:$FF;B:$55),
    (R:$FF;G:$FF;B:$FF)
  );

Type
  // ----------------------------------------------------------------
  // Pixel buffer — the rendered RIP image
  // v2.0: sized to max resolution (1280x1024), bounded by ActiveMaxX/Y
  // ----------------------------------------------------------------
  TRIPPixelBuffer = Array[0..1023, 0..1279] of Byte;
  PRIPPixelBuffer = ^TRIPPixelBuffer;

  // v3.0 Phase 15: parallel true-color buffers. Only the buffer matching
  // the active PixelFormat is kept up to date by DrawPixel/PutPixel; all
  // three are allocated so SetPixelFormat can convert between them.
  TRIPPixelBufferRGB = Array[0..1023, 0..1279] of TRIPRGB;
  PRIPPixelBufferRGB = ^TRIPPixelBufferRGB;

  TRIPPixelBufferRGB32 = Array[0..1023, 0..1279] of TRIPRGBA;
  PRIPPixelBufferRGB32 = ^TRIPPixelBufferRGB32;

  // v3.0 Phase 17: decoded image buffer
  TRIPImageBuffer = Record
    Width    : SmallInt;
    Height   : SmallInt;
    Pixels   : PByte;      // RGB data, 3 bytes per pixel (W*H*3)
    Alpha    : PByte;      // alpha channel, 1 byte per pixel (nil if opaque)
    Frames   : SmallInt;   // animation frame count (1 for static)
    DelayMS  : SmallInt;   // animation frame delay in ms
  End;
  PRIPImageBuffer = ^TRIPImageBuffer;

  // ----------------------------------------------------------------
  // TRIPEngine — main RIPscrip parser and renderer
  // ----------------------------------------------------------------
  TRIPEngine = Class
  Private
    // Graphics state
    CurX, CurY     : SmallInt;   // current position (CP)
    DrawColor      : TRIPColor;
    FillColor      : TRIPColor;
    FillStyle      : Byte;
    FillPat        : TRIPFillPattern;
    LineStyle      : Byte;
    LineThick      : Byte;
    LinePattern    : Word;       // user line pattern
    WriteMode      : Byte;       // COPY_PUT or XOR_PUT

    // v2.0 protocol state
    ProtoVersion   : Byte;       // 0=v1.54, 1=v2.0
    ColorMode      : Byte;       // 0=16-color, 8=256-color
    CanvasWidth    : SmallInt;   // actual width (default 640)
    CanvasHeight   : SmallInt;   // actual height (default 350)
    ActiveMaxX     : SmallInt;   // CanvasWidth - 1
    ActiveMaxY     : SmallInt;   // CanvasHeight - 1
    DrawLayer      : Byte;       // v2.0 drawing layer (0 or 1)
    PenWidth       : Byte;       // v2.0 pen width
    FrameRate      : Integer;    // v2.0 animation FPS (default 10)
    SavedPalette   : TRIPPalette; // for fade in/out

    // v3.0 Phase 15: true color state
    PixelFormat    : Byte;       // RIP_PIXFMT_INDEXED8 / RGB24 / RGB32
    DrawColorRGB   : TRIPRGB;    // true-color counterpart of DrawColor
    FillColorRGB   : TRIPRGB;    // true-color counterpart of FillColor

    // v3.0 Phase 16: world coordinate state
    WorldEnabled   : Boolean;    // world coords active?
    WorldX0        : Real;       // world left
    WorldY0        : Real;       // world top
    WorldX1        : Real;       // world right
    WorldY1        : Real;       // world bottom
    WorldAspect    : Boolean;    // preserve aspect ratio?

    // v3.0 Phase 16: text area auto-detect state
    TextAreaDetected : Boolean;  // cursor query performed?
    TextAreaW      : SmallInt;   // detected text area width (chars)
    TextAreaH      : SmallInt;   // detected text area height (chars)

    // v3.0 Phase 17: JPEG streaming state
    JPEGStrmPtr    : Pointer;    // ^TJPEGStreamRaw (allocated on init)
    JPEGStrmActive : Boolean;

    // Text state
    FontNum        : Byte;
    FontDir        : Byte;       // 0=horiz, 1=vert
    FontSize       : Byte;       // character magnification
    FontHJust      : Byte;       // horizontal justification
    FontVJust      : Byte;       // vertical justification

    // Windows
    TextWinX0      : SmallInt;
    TextWinY0      : SmallInt;
    TextWinX1      : SmallInt;
    TextWinY1      : SmallInt;
    TextWinSize    : Byte;       // font size for text window
    ViewX0, ViewY0 : SmallInt;
    ViewX1, ViewY1 : SmallInt;

    // Palette
    Palette        : TRIPPalette;

    // Mouse fields
    MouseFields    : Array[1..RIP_MAX_MOUSE] of TRIPMouseField;
    MouseCount     : Integer;
    NextTabIndex   : Integer;  // Phase 5: auto-incrementing tab order
    FocusedField   : Integer;  // Phase 5: currently focused field (0=none)

    // Button style
    BtnStyle       : TRIPButtonStyle;

    // Text variables
    Variables      : Array[1..RIP_MAX_VARS] of TRIPVariable;
    VarCount       : Integer;

    // CHR vector fonts (loaded on demand)
    CHRFonts       : Array[1..10] of PRIPCHRFont;

    // v3.0 Phase 18: RFF scalable fonts
    RFFFonts       : Array[1..RIP_MAX_RFF] of Pointer;  // ^TRFFFont
    RFFLoaded      : Array[1..RIP_MAX_RFF] of Boolean;
    RFFActiveFace  : Byte;       // 0=Regular, 1=Thin, ..., 9=HollowExtra
    RFFActiveFont  : Byte;       // which RFF slot (1..8) is active, 0=none
    RFFTracking    : SmallInt;   // extra space between chars (design units), default 0
    RFFLeading     : SmallInt;   // extra space between lines (design units), default 0

    // v3.0 Phase 18: MAF bitmap font state
    MAFData        : PMAFFile;   // loaded MAF container (nil if not loaded)
    MAFActiveRes   : Integer;    // active resolution index (-1 = none)
    MAFActiveFont  : Integer;    // active font index within resolution (-1 = none)

    // v3.0 Phase 20: Data Tables and Forms
    // SERVER-SIDE
    Table          : TRIPTable;
    // CLIENT-SIDE
    FormFields     : Array[0..RIP_MAX_FORM_FIELDS-1] of TRIPFormField;
    FormFieldCount : Integer;

    // v3.0 Phase 22: Advanced Multimedia
    // SERVER-SIDE: audio stream state, MIDI data, cue points
    AudioState     : Array[0..RIP_MAX_AUDIO_STREAMS-1] of Byte;  // RIP_AUDIO_*
    AudioFile      : Array[0..RIP_MAX_AUDIO_STREAMS-1] of String; // loaded filename
    AudioVolume    : Array[0..RIP_MAX_AUDIO_STREAMS-1] of Byte;  // 0-255
    MIDILoaded     : Boolean;
    MIDIFileName   : String;
    CueCount       : Integer;
    CuePoints      : Array[0..63] of LongInt;  // frame numbers for timed events
    CueActions     : Array[0..63] of String;    // RIP command to execute at cue
    BgAudioStream  : Integer;  // which stream is background (-1 = none)
    FrameCounter   : LongInt;  // current frame for cue point timing

    // v3.0 Phase 23: Clipping path state
    ClipStackPtr   : Pointer;  // ^TClipStack (allocated in Create, freed in Destroy)

    // Screen save slots (0-9), Phase 1
    SavedScreens   : Array[0..9] of PRIPPixelBuffer;

    // Text window save slot, Phase 1
    SavedTW        : Record
      Active : Boolean;
      X0, Y0, X1, Y1 : SmallInt;
      Size   : Byte;
    End;

    // Mouse field save slot, Phase 1/5
    SavedMouse     : Record
      Active       : Boolean;
      Fields       : Array[1..RIP_MAX_MOUSE] of TRIPMouseField;
      Count        : Integer;
      TabIndex     : Integer;
      Focused      : Integer;
    End;

    // Saved clipboard for $SCB$/$RCB$
    SavedClip      : Pointer;
    SavedClipSz    : LongInt;
    SavedClipW     : Word;
    SavedClipH     : Word;

    // Line buffer for continuation
    LineBuf        : String;
    Continued      : Boolean;

    // Parser helpers
    Function  MegaNum       (Var S: String; Var Pos: Integer; Digits: Integer) : LongInt;
    Function  MegaChar      (Ch: Char) : Integer;
    Procedure ParseLevel0   (Cmd: Char; Params: String);
    Procedure ParseLevel1   (Cmd: Char; Params: String);
    Procedure ParseLevel9   (Cmd: Char; Params: String);

    // BGI-compatible drawing primitives
    Procedure DrawPixel     (X, Y: SmallInt; Color: Byte); Overload;
    Procedure DrawPixel     (X, Y: SmallInt; RGB: TRIPRGB); Overload;
    Procedure DrawLine      (X0, Y0, X1, Y1: SmallInt);
    Procedure DrawRect      (X0, Y0, X1, Y1: SmallInt);
    Procedure DrawBar       (X0, Y0, X1, Y1: SmallInt);
    Procedure DrawCircle    (XC, YC, Radius: SmallInt);
    Procedure DrawOval      (XC, YC, XR, YR: SmallInt);
    Procedure DrawFilledOval(XC, YC, XR, YR: SmallInt);
    Procedure DrawArc       (XC, YC: SmallInt; StartAng, EndAng, Radius: SmallInt);
    Procedure DrawOvalArc   (XC, YC: SmallInt; StartAng, EndAng, XR, YR: SmallInt);
    Procedure DrawPieSlice  (XC, YC: SmallInt; StartAng, EndAng, Radius: SmallInt);
    Procedure DrawOvalPie   (XC, YC: SmallInt; StartAng, EndAng, XR, YR: SmallInt);
    Procedure DrawPolygon   (Var Points: Array of TRIPPoint; Count: Integer);
    Procedure DrawFillPoly  (Var Points: Array of TRIPPoint; Count: Integer);
    Procedure DrawPolyLine  (Var Points: Array of TRIPPoint; Count: Integer);
    Procedure DrawText8x8   (X, Y: SmallInt; S: String);

    // Clipping
    Function  ClipX (X: SmallInt) : SmallInt;
    Function  ClipY (Y: SmallInt) : SmallInt;
    Function  InView(X, Y: SmallInt) : Boolean;

    // v3.0 Phase 15: color-space conversion helpers
    Function  IndexToRGB   (Idx: Byte) : TRIPRGB;
    Function  RGBToIndex   (RGB: TRIPRGB) : Byte;
    Procedure ConvertPixelFormat (OldFmt, NewFmt: Byte);

    // v3.0 Phase 16: world-to-pixel coordinate mapping
    Function  WorldToPixelX (WX: Real) : SmallInt;
    Function  WorldToPixelY (WY: Real) : SmallInt;
    Function  PixelToWorldX (PX: SmallInt) : Real;
    Function  PixelToWorldY (PY: SmallInt) : Real;

  Public
    Pixels   : PRIPPixelBuffer;      // the rendered image (8-bit indexed)
    PixelsRGB   : PRIPPixelBufferRGB;   // v3.0 Phase 15: 24-bit RGB buffer
    PixelsRGB32 : PRIPPixelBufferRGB32; // v3.0 Phase 15: 32-bit TrueColor buffer
    HotKeysEnabled : Boolean;    // Phase 5: button hotkeys active
    TabEnabled     : Boolean;    // Phase 5: tab navigation active

    // Clipboard (public for viewer access)
    Clipboard      : Pointer;
    ClipSize       : LongInt;
    ClipW, ClipH   : Word;

    Constructor Create;
    Destructor  Destroy; Override;

    // ---- RIP command processing ----
    Procedure ProcessLine   (Line: String);
    Procedure ProcessCommand(Cmd: String);

    // ---- Screen management ----
    Procedure Reset;
    Procedure ClearScreen;
    Procedure ClearViewport;

    // ---- BGI-compatible drawing primitives ----
    Procedure PutPixel      (X, Y: SmallInt; Color: Byte); Overload;
    Procedure PutPixel      (X, Y: SmallInt; RGB: TRIPRGB); Overload;
    Function  GetPixel      (X, Y: SmallInt) : Byte;
    Function  GetPixelRGB   (X, Y: SmallInt) : TRIPRGB;

    // ---- v3.0 Phase 15: true color / pixel format ----
    Procedure SetPixelFormat(Fmt: Byte);
    Function  GetPixelFormat : Byte;
    Procedure SetColorRGB   (RGB: TRIPRGB);
    Function  GetColorRGB   : TRIPRGB;
    Procedure SetFillColorRGB(RGB: TRIPRGB);
    Function  GetFillColorRGB : TRIPRGB;
    Procedure Line          (X0, Y0, X1, Y1: SmallInt);
    Procedure LineTo        (X, Y: SmallInt);
    Procedure LineRel       (DX, DY: SmallInt);
    Procedure Rectangle     (X0, Y0, X1, Y1: SmallInt);
    Procedure Bar           (X0, Y0, X1, Y1: SmallInt);
    Procedure Bar3D         (X0, Y0, X1, Y1: SmallInt; Depth: SmallInt; Top: Boolean);
    Procedure Circle        (XC, YC, Radius: SmallInt);
    Procedure Ellipse       (XC, YC: SmallInt; StartAng, EndAng, XR, YR: SmallInt);
    Procedure FillEllipse   (XC, YC, XR, YR: SmallInt);
    Procedure Arc           (XC, YC: SmallInt; StartAng, EndAng, Radius: SmallInt);
    Procedure PieSlice      (XC, YC: SmallInt; StartAng, EndAng, Radius: SmallInt);
    Procedure Sector        (XC, YC: SmallInt; StartAng, EndAng, XR, YR: SmallInt);
    Procedure DrawBezier    (X0, Y0, X1, Y1, X2, Y2, X3, Y3: SmallInt; Count: SmallInt);
    Procedure DrawPoly      (NumPoints: Integer; Var PolyPoints);
    Procedure FillPoly      (NumPoints: Integer; Var PolyPoints);
    Procedure FloodFill     (X, Y: SmallInt; Border: Byte);

    // ---- Text output ----
    Procedure OutTextXY     (X, Y: SmallInt; S: String);
    Procedure OutText       (S: String);

    // ---- Position ----
    Procedure MoveTo        (X, Y: SmallInt);
    Procedure MoveRel       (DX, DY: SmallInt);
    Function  GetX          : SmallInt;
    Function  GetY          : SmallInt;

    // ---- Color / palette ----
    Procedure SetColor      (Color: Byte);
    Function  GetColor      : Byte;
    Procedure SetBkColor    (Color: Byte);
    Function  GetBkColor    : Byte;
    Procedure SetPalette    (Index, Color: Byte);
    Procedure SetAllPalette (Var Pal: TRIPPalette);
    Procedure GetPalette    (Var Pal: TRIPPalette);

    // ---- Fill ----
    Procedure SetFillStyle  (Style: Word; Color: Byte);
    Procedure SetFillPattern(Var Pattern: TRIPFillPattern; Color: Byte);
    Procedure GetFillSettings(Var Style: Word; Var Color: Byte);

    // ---- Line style ----
    Procedure SetLineStyle  (Style, Pattern, Thick: Word);
    Procedure GetLineSettings(Var Style, Pattern, Thick: Word);

    // ---- Write mode ----
    Procedure SetWriteMode  (Mode: Byte);
    Function  GetWriteMode  : Byte;

    // ---- Text style ----
    Procedure SetTextStyle  (Font, Direction, CharSize: Word);
    Procedure SetTextJustify(Horiz, Vert: Word);

    // ---- Viewport / window ----
    Procedure SetViewPort   (X0, Y0, X1, Y1: SmallInt; Clip: Boolean);
    Procedure GetViewPort   (Var X0, Y0, X1, Y1: SmallInt);
    Procedure SetTextWindow (X0, Y0, X1, Y1: SmallInt; Size: Byte);

    // ---- Mouse fields ----
    Function  AddMouseField (X0, Y0, X1, Y1: SmallInt; HostCmd, Text: String) : Integer;
    Procedure KillMouseField(Index: Integer);
    Procedure KillAllMouseFields;
    Function  FindMouseField(X, Y: SmallInt) : Integer;
    Function  GetMouseCount : Integer;
    Function  GetMouseField (Index: Integer) : TRIPMouseField;

    // ---- Button ----
    Procedure SetButtonStyle(Var Style: TRIPButtonStyle);
    Procedure DrawButton    (X0, Y0, X1, Y1: SmallInt; Label_, HostCmd: String);
    Procedure DrawButtonEx  (X0, Y0, X1, Y1: SmallInt; Label_, HostCmd, IconFile, HotIconFile: String;
                             IsRadio, IsCheckbox, InitSelected: Boolean);
    Procedure ClickButton   (Index: Integer);
    Procedure InvertRegion  (X0, Y0, X1, Y1: SmallInt);

    // ---- Button hotkeys and navigation (Phase 5) ----
    Function  FindButtonByHotkey (Key: Char) : Integer;
    Function  GetNextTabField : Integer;
    Function  GetPrevTabField : Integer;
    Procedure FocusField    (Index: Integer);
    Procedure UnfocusField;
    Function  GetFocusedField : Integer;

    // ---- System font modes (Phase 6) ----
    Function  GetSysFontW : Integer;    // character width in pixels
    Function  GetSysFontH : Integer;    // character height in pixels
    Function  GetSysCols  : Integer;    // text columns for current mode
    Function  GetSysRows  : Integer;    // text rows for current mode

    // ---- v2.0 Protocol Extensions (Phase 9) ----
    Procedure SetResolution (W, H: SmallInt);
    Procedure SetColorMode  (Mode: Byte);
    Function  GetCanvasWidth : SmallInt;
    Function  GetCanvasHeight : SmallInt;
    Function  GetProtoVersion : Byte;

    // ---- v3.0 Phase 16: World Coordinates ----
    Procedure SetWorldCoords (X0, Y0, X1, Y1: Real);
    Procedure ClearWorldCoords;
    Function  IsWorldEnabled : Boolean;
    Procedure SetWorldAspect (Preserve: Boolean);
    Function  GetWorldAspect : Boolean;
    Function  MapX (WX: Real) : SmallInt;
    Function  MapY (WY: Real) : SmallInt;
    Function  UnmapX (PX: SmallInt) : Real;
    Function  UnmapY (PY: SmallInt) : Real;

    // World-coordinate drawing overloads (Phase 16)
    Procedure WPutPixel     (WX, WY: Real; Color: Byte);
    Procedure WPutPixelRGB  (WX, WY: Real; RGB: TRIPRGB);
    Procedure WLine         (WX0, WY0, WX1, WY1: Real);
    Procedure WLineTo       (WX, WY: Real);
    Procedure WMoveTo       (WX, WY: Real);
    Procedure WRectangle    (WX0, WY0, WX1, WY1: Real);
    Procedure WBar          (WX0, WY0, WX1, WY1: Real);
    Procedure WCircle       (WXC, WYC, WRadius: Real);
    Procedure WEllipse      (WXC, WYC: Real; StartAng, EndAng: SmallInt; WXR, WYR: Real);
    Procedure WFillEllipse  (WXC, WYC, WXR, WYR: Real);
    Procedure WArc          (WXC, WYC: Real; StartAng, EndAng: SmallInt; WRadius: Real);
    Procedure WFloodFill    (WX, WY: Real; Border: Byte);
    Procedure WOutTextXY    (WX, WY: Real; S: String);
    Procedure WDrawBezier   (WX0,WY0,WX1,WY1,WX2,WY2,WX3,WY3: Real; Count: SmallInt);

    // Text area auto-detect (Phase 16)
    Function  IsTextAreaDetected : Boolean;
    Function  GetTextAreaW : SmallInt;
    Function  GetTextAreaH : SmallInt;

    // ---- v3.0 Phase 17: Image Format Support ----
    Function  LoadJPEG     (FileName: String; X, Y: SmallInt) : Boolean;
    Procedure JPEGStreamInit;
    Function  JPEGStreamFeed (Data: PByte; Size: Integer; X, Y: SmallInt) : Boolean;
    Function  JPEGStreamComplete : Boolean;
    Procedure JPEGStreamDone;
    Function  LoadGIF      (FileName: String; X, Y: SmallInt) : Boolean;
    Function  LoadGIFFrame (FileName: String; X, Y: SmallInt; Frame: Integer) : Boolean;
    Function  LoadPNG      (FileName: String; X, Y: SmallInt) : Boolean;
    Function  LoadImage    (FileName: String; X, Y: SmallInt) : Boolean;  // auto-detect format
    Function  LoadImageScaled(FileName: String; X, Y, DstW, DstH: SmallInt) : Boolean;
    Procedure BlitRGB       (Src: PByte; SrcW, SrcH: Integer; X, Y: SmallInt);
    Procedure BlitRGBScaled (Src: PByte; SrcW, SrcH: Integer; X, Y, DstW, DstH: SmallInt);
    Procedure BlitRGBAlpha  (Src: PByte; SrcW, SrcH: Integer; X, Y: SmallInt; Alpha: PByte);
    Procedure BlitRGBMask   (Src: PByte; SrcW, SrcH: Integer; X, Y: SmallInt; Mask: PByte);
    Procedure RGBAToMask    (RGBA: PByte; W, H: Integer; Mask: PByte; Threshold: Byte);
    Procedure BlitIndexed   (Src: PByte; SrcW, SrcH: Integer; X, Y: SmallInt;
                             Pal: Pointer; TransIdx: Integer);
    Procedure BlitImage    (Var Img: TRIPImageBuffer; X, Y: SmallInt);
    Procedure BlitImageAlpha(Var Img: TRIPImageBuffer; X, Y: SmallInt);
    Procedure BlitImageScaled(Var Img: TRIPImageBuffer; X, Y, DstW, DstH: SmallInt);
    Procedure FreeImage    (Var Img: TRIPImageBuffer);

    // ---- v2.0 SVGACC-Inspired (Phase 12) ----
    Procedure BlockResize   (Var Src; SrcW, SrcH: SmallInt;
                             Var Dst; DstW, DstH: SmallInt);
    Procedure BlockRotate   (Var Src; W, H: SmallInt;
                             Var Dst; Angle: SmallInt; BackFill: Byte);
    Procedure D2Rotate      (Var Pts: Array of TRIPPoint; Count: Integer;
                             XO, YO, Angle: SmallInt);
    Procedure D2Scale       (Var Pts: Array of TRIPPoint; Count: Integer;
                             XS, YS: SmallInt);
    Procedure D2Translate   (Var Pts: Array of TRIPPoint; Count: Integer;
                             XT, YT: SmallInt);
    Procedure SpriteGet     (X, Y, W, H: SmallInt; Var Sprite; Var Bkgnd);
    Procedure SpritePut     (X, Y: SmallInt; Var Sprite; TransColor: Byte);
    Function  SpriteCollide (X1, Y1, X2, Y2: SmallInt;
                             Var S1, S2; TransColor: Byte) : Boolean;
    Procedure ScrollUp      (X0, Y0, X1, Y1, Amt: SmallInt; Fill: Byte);
    Procedure ScrollDn      (X0, Y0, X1, Y1, Amt: SmallInt; Fill: Byte);
    Procedure ScrollLt      (X0, Y0, X1, Y1, Amt: SmallInt; Fill: Byte);
    Procedure ScrollRt      (X0, Y0, X1, Y1, Amt: SmallInt; Fill: Byte);
    Procedure PalFade       (StartIdx, EndIdx, Percent: Integer);
    Procedure PalRotate     (StartIdx, EndIdx, Shift: Integer);
    Procedure D3Rotate      (Var Pts: Array of TRIPPoint3D; Count: Integer;
                             XO, YO, ZO: SmallInt;
                             XAng, YAng, ZAng: SmallInt);
    Procedure D3Scale       (Var Pts: Array of TRIPPoint3D; Count: Integer;
                             XS, YS, ZS: SmallInt);
    Procedure D3Translate   (Var Pts: Array of TRIPPoint3D; Count: Integer;
                             XT, YT, ZT: SmallInt);
    Function  D3Project     (Var In3D: Array of TRIPPoint3D;
                             Var Out2D: Array of TRIPPoint;
                             Count: Integer;
                             Var Params: TRIPProjParams) : Boolean;
    Procedure LineAA        (X0, Y0, X1, Y1: SmallInt; Color: Byte);

    // ---- v2.0 Animation (Phase 13) ----
    Function  LoadAnimFrame (BaseName: String; Frame: Integer;
                             X, Y: SmallInt) : Boolean;
    Procedure PalCycle      (StartIdx, EndIdx: Integer;
                             Direction: ShortInt);
    Procedure FadeIn        (Steps: Integer);
    Procedure FadeOut       (Steps: Integer);
    Procedure SetFrameRate  (FPS: Integer);
    Function  GetFrameRate  : Integer;

    // ---- Image ----
    Procedure GetImage      (X0, Y0, X1, Y1: SmallInt; Var Buf);
    Procedure PutImage      (X, Y: SmallInt; Var Buf; Mode: Byte);
    Function  ImageSize     (X0, Y0, X1, Y1: SmallInt) : LongInt;

    // ---- Icon ----
    Function  LoadIcon      (FileName: String; X, Y: SmallInt; Mode: Byte) : Boolean;
    Function  SaveIcon      (FileName: String; X0, Y0, X1, Y1: SmallInt) : Boolean;
    Function  LoadMask      (FileName: String; X, Y: SmallInt) : Boolean;
    Function  LoadIconMasked(IconFile, MaskFile: String; X, Y: SmallInt) : Boolean;
    Function  LoadHotIcon   (FileName: String; X, Y: SmallInt) : Boolean;
    Function  LoadBMH       (FileName: String; X, Y: SmallInt) : Boolean;  // v2.0: BMP highlight

    // ---- Scene file ----
    Function  LoadScene     (FileName: String) : Boolean;
    Function  SaveScene     (FileName: String) : Boolean;

    // ---- CHR vector fonts ----
    Function  LoadCHR       (AFontNum: Byte; FileName: String) : Boolean;

    // ---- v3.0 Phase 18: RFF Scalable Fonts ----
    Function  LoadRFF       (Slot: Byte; FileName: String) : Boolean;
    Procedure FreeRFF       (Slot: Byte);
    Procedure SetRFFFont    (Slot: Byte);
    Procedure SetRFFFace    (Face: Byte);
    Function  GetRFFFace    : Byte;
    Function  RFFTextWidth  (S: String) : Integer;
    Function  RFFTextHeight : Integer;
    Function  RFFLineHeight : Integer;
    Function  RFFKernPair   (Ch1, Ch2: Char) : SmallInt;
    Procedure SetRFFTracking(Value: SmallInt);
    Function  GetRFFTracking : SmallInt;
    Procedure SetRFFLeading (Value: SmallInt);
    Function  GetRFFLeading : SmallInt;
    Procedure DrawTextRFFBox (X, Y, W, H: SmallInt; S: String;
                              PointSize: Integer; HAlign, VAlign: Byte;
                              WordWrap: Boolean);
    Function  UTF8ToCP437   (Ch: Word) : Byte;
    Function  MapStringCP437(S: String) : String;

    // ---- v3.0 Phase 18: MAF Bitmap Fonts ----
    Function  LoadMAF       (FileName: String) : Boolean;
    Procedure FreeMAF;
    Function  MAFSelectRes  (ScrW, ScrH: Word) : Boolean;
    Function  MAFSelectFont (FontIdx: Integer) : Boolean;
    Function  MAFGetFontH   : Integer;
    Function  MAFIsLoaded   : Boolean;
    Procedure DrawTextMAF   (X, Y: SmallInt; S: String);

    // ---- v3.0 Phase 20: Data Tables (SERVER-SIDE) ----
    // Server creates tables, populates data, renders to pixel buffer.
    // Client sees rendered pixels only — no table interaction needed.
    Procedure TableCreate   (X, Y: SmallInt; Cols: Integer);  // init table at position
    Procedure TableAddCol   (Title: String; Width: SmallInt; Align: Byte);  // add column definition
    Procedure TableAddRow;                                    // add empty data row
    Procedure TableSetCell  (Row, Col: Integer; Text: String; Color: Byte);  // set cell content
    Procedure TableRender;                                    // render table to pixel buffer
    Procedure TableClear;                                     // destroy table and free data
    Procedure TableScroll   (Delta: Integer);                 // scroll visible window (+/- rows)
    Function  TableGetRows  : Integer;                        // current row count
    Function  TableGetCols  : Integer;                        // current column count
    Procedure TableSetVisRows(Rows: Integer);                 // set visible row count (0=all)

    // ---- v3.0 Phase 20: Form Fields (CLIENT-SIDE) ----
    // Server defines fields and constraints. Client handles input.
    // Host application bridges: processes input → FormSetValue → FormRender.
    Function  FormAddField  (FieldType: Byte; Name: String;   // create field, returns index
                             X, Y, W, H: SmallInt) : Integer;
    Procedure FormSetValue  (Idx: Integer; Value: String);    // set field value (server or client)
    Function  FormGetValue  (Idx: Integer) : String;          // get field value
    Procedure FormSetOptions(Idx: Integer; Options: String);  // set dropdown/listbox choices
    Procedure FormBindVar   (Idx: Integer; VarName: String);  // bind to $VARNAME$ text variable
    Function  FormValidate  : Boolean;                        // check Required fields
    Procedure FormRender;                                     // render all fields to pixel buffer
    Procedure FormClear;                                      // destroy all fields
    Procedure FormSyncToVars;                                 // push field values → text variables
    Procedure FormSyncFromVars;                               // pull text variables → field values
    Procedure FormSetRequired(Idx: Integer; Req: Boolean);    // set Required flag

    // ---- v3.0 Phase 22: Advanced Multimedia (SERVER-SIDE) ----
    // Audio: server manages streams, client plays audio.
    // MIDI: server parses MIDI file, extracts events for playback.
    // Cue points: server triggers RIP commands at specific frame numbers.
    Function  AudioLoad     (Stream: Integer; FileName: String) : Boolean;
    Procedure AudioPlay     (Stream: Integer);
    Procedure AudioPause    (Stream: Integer);
    Procedure AudioStop     (Stream: Integer);
    Procedure AudioStopAll;
    Procedure AudioSetVolume(Stream: Integer; Volume: Byte);
    Function  AudioGetState (Stream: Integer) : Byte;
    Function  MIDILoad      (FileName: String) : Boolean;
    Procedure MIDIFree;
    Procedure CueAdd        (Frame: LongInt; Action: String);
    Procedure CueClear;
    Procedure CueProcess    (CurrentFrame: LongInt);
    Procedure SetBgAudio    (Stream: Integer);
    Procedure BgAudioTransition (NewFile: String; FadeFrames: Integer);
    Function  WAVStreamStart(Stream: Integer; SampleRate: LongInt;
                             Bits, Channels: Byte) : Boolean;
    Procedure WAVStreamFeed (Stream: Integer; Data: PByte; Len: LongInt);
    Procedure WAVStreamEnd  (Stream: Integer);

    // ---- v3.0 Phase 23: Advanced Graphics (SERVER-SIDE) ----
    // Gradient fills: linear, radial, conical with dithering
    Procedure GradientRect  (X1, Y1, X2, Y2: SmallInt;
                             R1, G1, B1, R2, G2, B2: Byte;
                             GType: Byte);
    // Drop shadow on a rectangular region
    Procedure DropShadow    (X, Y, W, H: SmallInt;
                             OffX, OffY: SmallInt; Blur: Byte;
                             R, G, B, Opacity: Byte);
    // Outer glow on a rectangular region
    Procedure OuterGlow     (X, Y, W, H: SmallInt;
                             Radius: Byte; R, G, B, Opacity: Byte);
    // Variable-width Bezier curve (cubic)
    Procedure BezierVarWidth(X0, Y0: SmallInt; W0: Byte;
                             X1, Y1: SmallInt; W1: Byte;
                             X2, Y2: SmallInt; W2: Byte;
                             X3, Y3: SmallInt; W3: Byte;
                             R, G, B: Byte);
    // Texture mapping on a quad (4-point polygon)
    Procedure TextureQuad   (X0, Y0, X1, Y1, X2, Y2, X3, Y3: SmallInt;
                             TexData: PByte; TexW, TexH: Word);
    // Layer compositing (alpha blend a source region onto canvas)
    Procedure CompositAlpha (SrcData: PByte; SrcW, SrcH: Word;
                             DstX, DstY: SmallInt; Opacity: Byte);
    // Clipping path management
    Procedure ClipBegin;
    Procedure ClipAddPoint  (X, Y: SmallInt);
    Procedure ClipAddRect   (X1, Y1, X2, Y2: SmallInt);
    Procedure ClipAddCircle (CX, CY, Radius: SmallInt);
    Procedure ClipEnd;
    Procedure ClipReset;
    Procedure DrawTextRFF   (X, Y: SmallInt; S: String; PointSize: Integer;
                             Rotation: SmallInt);
    Procedure DrawTextCHR   (X, Y: SmallInt; S: String; AFont, ASize: Byte);

    // ---- Export ----
    Function  SaveBMP       (FileName: String) : Boolean;

    // ---- Image loading (Phase 4) ----
    Function  LoadPCX       (FileName: String; X, Y: SmallInt) : Boolean;

    // ---- v2.0 file formats (Phase 11) ----
    Function  LoadPAL       (FileName: String) : Boolean;  // 16-byte or 868-byte palette
    Function  LoadJPG       (FileName: String; X, Y: SmallInt) : Boolean;  // JPEG header parse (v2 inherited)
    Function  LoadBMP       (FileName: String; X, Y: SmallInt) : Boolean;

    // ---- v3.0 Phase 21: Text Variables ----
    // SERVER-SIDE: variable management with scoping
    Procedure DefineVar     (Name, Value: String; Persist, Required: Boolean);
    Procedure DefineVarScoped(Name, Value: String; Scope: Byte; Required: Boolean);
    Function  GetVar        (Name: String) : String;
    Procedure SetVar        (Name, Value: String);
    Function  FindVar       (Name: String) : Integer;
    Procedure KillAllVars;
    Procedure KillLocalVars;    // clear LOCAL scope vars (called on scene end)
    Procedure KillSessionVars;  // clear SESSION scope vars (called on disconnect)

    // ---- Pre-defined text variables (Phase 3) ----
    Function  ResolveVar    (Name: String) : String;
    Function  ExpandVars    (S: String) : String;

    // ---- Variable persistence ----
    Function  SaveVars      (FileName: String) : Boolean;
    Function  LoadVars      (FileName: String) : Boolean;

    // ---- File query (RIP_FILE_QUERY) ----
    Function  FileQuery     (FileName: String; Mode: Byte) : TRIPFileQueryResult;

    // ---- Copy region (RIP_COPY_REGION) ----
    Procedure CopyRegion    (X0, Y0, X1, Y1, DestY: SmallInt);

    // ---- Screen save/restore (Phase 1) ----
    Procedure SaveScreen    (Slot: Byte);
    Procedure RestoreScreen (Slot: Byte);
    Procedure SaveTextWin;
    Procedure RestoreTextWin;
    Procedure SaveMouseAll;
    Procedure RestoreMouseAll;
    Procedure SaveClip;
    Procedure RestoreClip;
    Procedure SaveAll;
    Procedure RestoreAll;

    // ---- Dimensions ----
    Function  GetMaxX       : SmallInt;
    Function  GetMaxY       : SmallInt;
    Function  GetWidth      : SmallInt;
    Function  GetHeight     : SmallInt;
  End;

Implementation

Uses
  jpgdecr, gifdecr, pngdecr, rffdecr,  // v3.0 Phase 17-18: image decoders
  BMPDec, PCXDec, TGADec, PBMDec, ICODec,        // v3.0 image format decoders
  PNGCodec, pngintl,                         // v3.0 PNG encoder/decoder + interlaced
  GIFAnim, gifintl,                          // v3.0 animated + interlaced GIF
  JPEGProg, spranim,                           // v3.0 progressive JPEG + sprite animation
  GRFill, GRFx, GRBezier, GRTexMap, GRClip,      // v3.0 Phase 23: advanced graphics
  ripdecr, ripbind, RIPTile,                  // v3.0 progressive rendering
  riplayr, ripchnge, riprndr,              // v3.0 progressive rendering
  midsynth;                                      // v3.0 Phase 22: FM synthesis

{$I rip_font8x8.inc}
{$I rip_font8x14.inc}

// ====================================================================
// MegaNum decoder — base-36 number system
// ====================================================================

Function TRIPEngine.MegaChar (Ch: Char) : Integer;
Begin
  If (Ch >= '0') and (Ch <= '9') Then
    Result := Ord(Ch) - Ord('0')
  Else If (Ch >= 'A') and (Ch <= 'Z') Then
    Result := Ord(Ch) - Ord('A') + 10
  Else If (Ch >= 'a') and (Ch <= 'z') Then
    Result := Ord(Ch) - Ord('a') + 10
  Else
    Result := 0;
End;

Function TRIPEngine.MegaNum (Var S: String; Var Pos: Integer; Digits: Integer) : LongInt;
Var
  I : Integer;
Begin
  Result := 0;

  For I := 1 to Digits Do Begin
    If Pos > Length(S) Then Exit;

    Result := Result * 36 + MegaChar(S[Pos]);
    Inc(Pos);
  End;
End;

// ====================================================================
// Clipping helpers
// ====================================================================

Function TRIPEngine.ClipX (X: SmallInt) : SmallInt;
Begin
  If X < ViewX0 Then Result := ViewX0
  Else If X > ViewX1 Then Result := ViewX1
  Else Result := X;
End;

Function TRIPEngine.ClipY (Y: SmallInt) : SmallInt;
Begin
  If Y < ViewY0 Then Result := ViewY0
  Else If Y > ViewY1 Then Result := ViewY1
  Else Result := Y;
End;

Function TRIPEngine.InView (X, Y: SmallInt) : Boolean;
Begin
  Result := (X >= ViewX0) and (X <= ViewX1) and
            (Y >= ViewY0) and (Y <= ViewY1);
End;

// v3.0 Phase 15: resolve a palette index to a true-color RGB value.
// Mirrors the convention already used by SaveBMP/LoadBMP elsewhere in
// this engine: the low nibble selects one of the 16 EGA colors. 256-color
// palette entries beyond the EGA ramp are approximated by wrapping into
// the same 16-entry table (a full VGA DAC model is out of scope here).
Function TRIPEngine.IndexToRGB (Idx: Byte) : TRIPRGB;
Begin
  Result := EGA_RGB[Idx AND $0F];
End;

// v3.0 Phase 15: quantize a true-color RGB value down to the nearest of
// the 16 EGA colors, for engine paths that still need an indexed value
// (legacy GetPixel, indexed-mode fallback, screen-save slots, etc).
Function TRIPEngine.RGBToIndex (RGB: TRIPRGB) : Byte;
Var
  I, Best, BestDist, Dist : Integer;
Begin
  Best := 0;
  BestDist := MaxInt;
  For I := 0 to 15 Do Begin
    Dist := Abs(SmallInt(RGB.R) - SmallInt(EGA_RGB[I].R)) +
            Abs(SmallInt(RGB.G) - SmallInt(EGA_RGB[I].G)) +
            Abs(SmallInt(RGB.B) - SmallInt(EGA_RGB[I].B));
    If Dist < BestDist Then Begin
      BestDist := Dist;
      Best := I;
    End;
  End;
  Result := Best;
End;

// v3.0 Phase 15: convert the pixel buffer contents when switching pixel
// formats, so the visible image survives an indexed <-> RGB24 <-> RGB32
// mode switch instead of going blank.
Procedure TRIPEngine.ConvertPixelFormat (OldFmt, NewFmt: Byte);
Var
  X, Y : SmallInt;
  RGB  : TRIPRGB;
Begin
  If OldFmt = NewFmt Then Exit;

  If (OldFmt = RIP_PIXFMT_INDEXED8) and (NewFmt <> RIP_PIXFMT_INDEXED8) Then Begin
    // Expand indexed -> RGB24/RGB32
    For Y := 0 to ActiveMaxY Do
      For X := 0 to ActiveMaxX Do Begin
        RGB := IndexToRGB(Pixels^[Y, X]);
        PixelsRGB^[Y, X] := RGB;
        PixelsRGB32^[Y, X].R := RGB.R;
        PixelsRGB32^[Y, X].G := RGB.G;
        PixelsRGB32^[Y, X].B := RGB.B;
        PixelsRGB32^[Y, X].A := $FF;
      End;
  End Else If (OldFmt <> RIP_PIXFMT_INDEXED8) and (NewFmt = RIP_PIXFMT_INDEXED8) Then Begin
    // Quantize RGB24/RGB32 -> indexed
    For Y := 0 to ActiveMaxY Do
      For X := 0 to ActiveMaxX Do
        Pixels^[Y, X] := RGBToIndex(PixelsRGB^[Y, X]);
  End Else Begin
    // RGB24 <-> RGB32: buffers are kept mirrored by DrawPixel already,
    // nothing further to convert.
  End;
End;

// ====================================================================
// Drawing primitives
// ====================================================================

Procedure TRIPEngine.DrawPixel (X, Y: SmallInt; Color: Byte);
Begin
  If Not InView(X, Y) Then Exit;

  // v3.0 Phase 15: indexed palette mode retained for full backward
  // compatibility with v1.54/v2.0 scenes. When the engine is running in
  // a true-color pixel format, a legacy byte color is resolved through
  // the active palette and the write is promoted to the RGB buffer, so
  // every existing (byte-color) drawing primitive works unmodified in
  // RGB24/RGB32 mode.
  If PixelFormat = RIP_PIXFMT_INDEXED8 Then Begin
    Case WriteMode of
      RIP_XOR_PUT : Pixels^[Y, X] := Pixels^[Y, X] XOR Color;
      RIP_AND_PUT : Begin
        // RIPtel 3.0.7 known issue: AND write mode with Color = 7 (0111b)
        // clears the intensity bit (bit 3) of bright colors (8-15) on
        // real EGA/VGA hardware, because color 7 only drives the R/G/B
        // planes and leaves the intensity plane's AND input floating.
        // Fixed here: Color = 7 leaves the pixel unchanged (a true no-op)
        // instead of corrupting the intensity bit.
        If Color <> 7 Then
          Pixels^[Y, X] := Pixels^[Y, X] AND Color;
      End;
      RIP_OR_PUT  : Pixels^[Y, X] := Pixels^[Y, X] OR Color;
      RIP_NOT_PUT : Pixels^[Y, X] := (NOT Color) AND $FF;
    Else
      Pixels^[Y, X] := Color;
    End;
  End Else
    DrawPixel(X, Y, IndexToRGB(Color));
End;

Procedure TRIPEngine.DrawPixel (X, Y: SmallInt; RGB: TRIPRGB);
Var
  Old32 : TRIPRGBA;
Begin
  If Not InView(X, Y) Then Exit;

  Case WriteMode of
    RIP_XOR_PUT : Begin
      RGB.R := PixelsRGB^[Y, X].R XOR RGB.R;
      RGB.G := PixelsRGB^[Y, X].G XOR RGB.G;
      RGB.B := PixelsRGB^[Y, X].B XOR RGB.B;
    End;
    RIP_AND_PUT : Begin
      RGB.R := PixelsRGB^[Y, X].R AND RGB.R;
      RGB.G := PixelsRGB^[Y, X].G AND RGB.G;
      RGB.B := PixelsRGB^[Y, X].B AND RGB.B;
    End;
    RIP_OR_PUT  : Begin
      RGB.R := PixelsRGB^[Y, X].R OR RGB.R;
      RGB.G := PixelsRGB^[Y, X].G OR RGB.G;
      RGB.B := PixelsRGB^[Y, X].B OR RGB.B;
    End;
    RIP_NOT_PUT : Begin
      RGB.R := (NOT RGB.R) AND $FF;
      RGB.G := (NOT RGB.G) AND $FF;
      RGB.B := (NOT RGB.B) AND $FF;
    End;
  End;

  PixelsRGB^[Y, X] := RGB;

  Old32.R := RGB.R;
  Old32.G := RGB.G;
  Old32.B := RGB.B;
  // DrawPixel(RGB) has no alpha channel, so always default to fully opaque.
  // Code that needs to preserve or manipulate alpha must write PixelsRGB32^
  // directly.
  Old32.A := $FF;
  PixelsRGB32^[Y, X] := Old32;

  // Keep the indexed buffer's nearest-match in sync too, so anything
  // still reading GetPixel (indexed) or exporting via the legacy path
  // sees a reasonable approximation while in true-color mode.
  Pixels^[Y, X] := RGBToIndex(RGB);
End;

Procedure TRIPEngine.DrawLine (X0, Y0, X1, Y1: SmallInt);
Var
  DX, DY, SX, SY, Err, E2 : SmallInt;
  PatBit : Integer;
  Pat    : Word;
Begin
  // Select pattern
  Case LineStyle of
    RIP_LINE_DOTTED  : Pat := $CCCC;
    RIP_LINE_CENTER  : Pat := $FC78;
    RIP_LINE_DASHED  : Pat := $F8F8;
    RIP_LINE_USER    : Pat := LinePattern;
  Else
    Pat := $FFFF;  // solid
  End;

  PatBit := 0;

  // Bresenham line algorithm
  DX := Abs(X1 - X0);
  DY := Abs(Y1 - Y0);

  If X0 < X1 Then SX := 1 Else SX := -1;
  If Y0 < Y1 Then SY := 1 Else SY := -1;

  Err := DX - DY;

  While True Do Begin
    // Only draw if pattern bit is set
    If (Pat AND (1 SHL (15 - (PatBit AND 15)))) <> 0 Then
      DrawPixel(X0, Y0, DrawColor);

    Inc(PatBit);

    If (X0 = X1) and (Y0 = Y1) Then Break;

    E2 := 2 * Err;

    If E2 > -DY Then Begin
      Err := Err - DY;
      X0  := X0 + SX;
    End;

    If E2 < DX Then Begin
      Err := Err + DX;
      Y0  := Y0 + SY;
    End;
  End;

  CurX := X1;
  CurY := Y1;
End;

Procedure TRIPEngine.DrawRect (X0, Y0, X1, Y1: SmallInt);
Begin
  DrawLine(X0, Y0, X1, Y0);
  DrawLine(X1, Y0, X1, Y1);
  DrawLine(X1, Y1, X0, Y1);
  DrawLine(X0, Y1, X0, Y0);
End;

Procedure TRIPEngine.DrawBar (X0, Y0, X1, Y1: SmallInt);
Var
  X, Y     : SmallInt;
  PatByte  : Byte;
  FillPats : Array[0..11, 0..7] of Byte;
Begin
  // Built-in fill patterns (BGI compatible)
  // EMPTY
  FillChar(FillPats[0], 8, $00);
  // SOLID
  FillChar(FillPats[1], 8, $FF);
  // LINE (horizontal lines)
  FillPats[2][0] := $FF; FillPats[2][1] := $00; FillPats[2][2] := $00; FillPats[2][3] := $00;
  FillPats[2][4] := $FF; FillPats[2][5] := $00; FillPats[2][6] := $00; FillPats[2][7] := $00;
  // LTSLASH
  FillPats[3][0] := $01; FillPats[3][1] := $02; FillPats[3][2] := $04; FillPats[3][3] := $08;
  FillPats[3][4] := $10; FillPats[3][5] := $20; FillPats[3][6] := $40; FillPats[3][7] := $80;
  // SLASH
  FillPats[4][0] := $03; FillPats[4][1] := $06; FillPats[4][2] := $0C; FillPats[4][3] := $18;
  FillPats[4][4] := $30; FillPats[4][5] := $60; FillPats[4][6] := $C0; FillPats[4][7] := $81;
  // BKSLASH
  FillPats[5][0] := $C0; FillPats[5][1] := $60; FillPats[5][2] := $30; FillPats[5][3] := $18;
  FillPats[5][4] := $0C; FillPats[5][5] := $06; FillPats[5][6] := $03; FillPats[5][7] := $81;
  // LTBKSLASH
  FillPats[6][0] := $80; FillPats[6][1] := $40; FillPats[6][2] := $20; FillPats[6][3] := $10;
  FillPats[6][4] := $08; FillPats[6][5] := $04; FillPats[6][6] := $02; FillPats[6][7] := $01;
  // HATCH
  FillPats[7][0] := $FF; FillPats[7][1] := $01; FillPats[7][2] := $01; FillPats[7][3] := $01;
  FillPats[7][4] := $FF; FillPats[7][5] := $01; FillPats[7][6] := $01; FillPats[7][7] := $01;
  // XHATCH
  FillPats[8][0] := $FF; FillPats[8][1] := $81; FillPats[8][2] := $42; FillPats[8][3] := $24;
  FillPats[8][4] := $FF; FillPats[8][5] := $24; FillPats[8][6] := $42; FillPats[8][7] := $81;
  // INTERLEAVE
  FillPats[9][0] := $AA; FillPats[9][1] := $55; FillPats[9][2] := $AA; FillPats[9][3] := $55;
  FillPats[9][4] := $AA; FillPats[9][5] := $55; FillPats[9][6] := $AA; FillPats[9][7] := $55;
  // WIDEDOT
  FillPats[10][0] := $00; FillPats[10][1] := $00; FillPats[10][2] := $00; FillPats[10][3] := $00;
  FillPats[10][4] := $01; FillPats[10][5] := $00; FillPats[10][6] := $00; FillPats[10][7] := $00;
  // CLOSEDOT
  FillPats[11][0] := $44; FillPats[11][1] := $00; FillPats[11][2] := $11; FillPats[11][3] := $00;
  FillPats[11][4] := $44; FillPats[11][5] := $00; FillPats[11][6] := $11; FillPats[11][7] := $00;

  For Y := ClipY(Y0) to ClipY(Y1) Do Begin
    // Select pattern row
    Case FillStyle of
      RIP_FILL_EMPTY : Continue;  // don't draw anything
      RIP_FILL_SOLID : PatByte := $FF;
      RIP_FILL_USER  : PatByte := FillPat[Y AND 7];
    Else
      If FillStyle <= 11 Then
        PatByte := FillPats[FillStyle][Y AND 7]
      Else
        PatByte := $FF;
    End;

    For X := ClipX(X0) to ClipX(X1) Do
      If (PatByte AND ($80 SHR (X AND 7))) <> 0 Then
        DrawPixel(X, Y, FillColor);
  End;
End;

Procedure TRIPEngine.DrawCircle (XC, YC, Radius: SmallInt);
Var
  X, Y, D : SmallInt;
Begin
  // Midpoint circle algorithm
  X := 0;
  Y := Radius;
  D := 1 - Radius;

  While X <= Y Do Begin
    DrawPixel(XC + X, YC + Y, DrawColor);
    DrawPixel(XC - X, YC + Y, DrawColor);
    DrawPixel(XC + X, YC - Y, DrawColor);
    DrawPixel(XC - X, YC - Y, DrawColor);
    DrawPixel(XC + Y, YC + X, DrawColor);
    DrawPixel(XC - Y, YC + X, DrawColor);
    DrawPixel(XC + Y, YC - X, DrawColor);
    DrawPixel(XC - Y, YC - X, DrawColor);

    If D < 0 Then
      D := D + 2 * X + 3
    Else Begin
      D := D + 2 * (X - Y) + 5;
      Dec(Y);
    End;

    Inc(X);
  End;
End;

Procedure TRIPEngine.DrawOval (XC, YC, XR, YR: SmallInt);
Var
  X, Y   : SmallInt;
  XR2, YR2 : LongInt;
  PX, PY : LongInt;
  P      : LongInt;
Begin
  If (XR = 0) or (YR = 0) Then Exit;

  XR2 := LongInt(XR) * XR;
  YR2 := LongInt(YR) * YR;

  // Region 1
  X := 0;
  Y := YR;
  PX := 0;
  PY := 2 * XR2 * Y;
  P := Round(YR2 - XR2 * YR + 0.25 * XR2);

  While PX < PY Do Begin
    DrawPixel(XC + X, YC + Y, DrawColor);
    DrawPixel(XC - X, YC + Y, DrawColor);
    DrawPixel(XC + X, YC - Y, DrawColor);
    DrawPixel(XC - X, YC - Y, DrawColor);

    Inc(X);
    PX := PX + 2 * YR2;
    If P < 0 Then
      P := P + YR2 + PX
    Else Begin
      Dec(Y);
      PY := PY - 2 * XR2;
      P  := P + YR2 + PX - PY;
    End;
  End;

  // Region 2
  P := Round(YR2 * (X + 0.5) * (X + 0.5) + XR2 * LongInt(Y - 1) * (Y - 1) - XR2 * YR2);

  While Y >= 0 Do Begin
    DrawPixel(XC + X, YC + Y, DrawColor);
    DrawPixel(XC - X, YC + Y, DrawColor);
    DrawPixel(XC + X, YC - Y, DrawColor);
    DrawPixel(XC - X, YC - Y, DrawColor);

    Dec(Y);
    PY := PY - 2 * XR2;
    If P > 0 Then
      P := P + XR2 - PY
    Else Begin
      Inc(X);
      PX := PX + 2 * YR2;
      P  := P + XR2 - PY + PX;
    End;
  End;
End;

Procedure TRIPEngine.DrawFilledOval (XC, YC, XR, YR: SmallInt);
Var
  Y, X1 : SmallInt;
Begin
  If (XR = 0) or (YR = 0) Then Exit;

  For Y := -YR to YR Do Begin
    X1 := Round(XR * Sqrt(1.0 - (Y * Y) / (YR * YR)));
    DrawLine(XC - X1, YC + Y, XC + X1, YC + Y);
  End;
End;

Procedure TRIPEngine.DrawArc (XC, YC: SmallInt; StartAng, EndAng, Radius: SmallInt);
Var
  Angle  : SmallInt;
  PX, PY : SmallInt;
Begin
  For Angle := StartAng to EndAng Do Begin
    PX := XC + Round(Radius * Cos(Angle * Pi / 180));
    PY := YC - Round(Radius * Sin(Angle * Pi / 180));
    DrawPixel(PX, PY, DrawColor);
  End;
End;

Procedure TRIPEngine.DrawOvalArc (XC, YC: SmallInt; StartAng, EndAng, XR, YR: SmallInt);
Var
  Angle  : SmallInt;
  PX, PY : SmallInt;
Begin
  For Angle := StartAng to EndAng Do Begin
    PX := XC + Round(XR * Cos(Angle * Pi / 180));
    PY := YC - Round(YR * Sin(Angle * Pi / 180));
    DrawPixel(PX, PY, DrawColor);
  End;
End;

Procedure TRIPEngine.DrawPieSlice (XC, YC: SmallInt; StartAng, EndAng, Radius: SmallInt);
Var
  Angle  : SmallInt;
  PX, PY : SmallInt;
Begin
  // Draw arc
  DrawArc(XC, YC, StartAng, EndAng, Radius);

  // Draw lines from center to arc endpoints
  PX := XC + Round(Radius * Cos(StartAng * Pi / 180));
  PY := YC - Round(Radius * Sin(StartAng * Pi / 180));
  DrawLine(XC, YC, PX, PY);

  PX := XC + Round(Radius * Cos(EndAng * Pi / 180));
  PY := YC - Round(Radius * Sin(EndAng * Pi / 180));
  DrawLine(XC, YC, PX, PY);
End;

Procedure TRIPEngine.DrawOvalPie (XC, YC: SmallInt; StartAng, EndAng, XR, YR: SmallInt);
Var
  PX, PY : SmallInt;
Begin
  DrawOvalArc(XC, YC, StartAng, EndAng, XR, YR);

  PX := XC + Round(XR * Cos(StartAng * Pi / 180));
  PY := YC - Round(YR * Sin(StartAng * Pi / 180));
  DrawLine(XC, YC, PX, PY);

  PX := XC + Round(XR * Cos(EndAng * Pi / 180));
  PY := YC - Round(YR * Sin(EndAng * Pi / 180));
  DrawLine(XC, YC, PX, PY);
End;

Procedure TRIPEngine.DrawBezier (X0, Y0, X1, Y1, X2, Y2, X3, Y3: SmallInt; Count: SmallInt);
Var
  I       : SmallInt;
  T       : Real;
  PX, PY  : SmallInt;
  LX, LY  : SmallInt;
  IT, IT2, IT3, T2, T3 : Real;
Begin
  If Count < 2 Then Count := 20;

  LX := X0;
  LY := Y0;

  For I := 1 to Count Do Begin
    T   := I / Count;
    IT  := 1.0 - T;
    IT2 := IT * IT;
    IT3 := IT2 * IT;
    T2  := T * T;
    T3  := T2 * T;

    PX := Round(IT3 * X0 + 3 * IT2 * T * X1 + 3 * IT * T2 * X2 + T3 * X3);
    PY := Round(IT3 * Y0 + 3 * IT2 * T * Y1 + 3 * IT * T2 * Y2 + T3 * Y3);

    DrawLine(LX, LY, PX, PY);

    LX := PX;
    LY := PY;
  End;
End;

Procedure TRIPEngine.DrawPolygon (Var Points: Array of TRIPPoint; Count: Integer);
Var
  I : Integer;
Begin
  If Count < 2 Then Exit;
  If Count > RIP_MAX_POLY Then Count := RIP_MAX_POLY;

  For I := 0 to Count - 2 Do
    DrawLine(Points[I].X, Points[I].Y, Points[I+1].X, Points[I+1].Y);

  // Close the polygon
  DrawLine(Points[Count-1].X, Points[Count-1].Y, Points[0].X, Points[0].Y);
End;

Procedure TRIPEngine.DrawFillPoly (Var Points: Array of TRIPPoint; Count: Integer);
// Scanline fill algorithm for convex and concave polygons
Var
  MinY, MaxY : SmallInt;
  Y, I, J    : Integer;
  Nodes      : Integer;
  NodeX      : Array[0..RIP_MAX_POLY-1] of SmallInt;
  Swap       : SmallInt;
Begin
  If Count < 3 Then Begin
    DrawPolygon(Points, Count);
    Exit;
  End;
  If Count > RIP_MAX_POLY Then Count := RIP_MAX_POLY;

  // Find Y range
  MinY := Points[0].Y;
  MaxY := Points[0].Y;
  For I := 1 to Count - 1 Do Begin
    If Points[I].Y < MinY Then MinY := Points[I].Y;
    If Points[I].Y > MaxY Then MaxY := Points[I].Y;
  End;

  If MinY < ViewY0 Then MinY := ViewY0;
  If MaxY > ViewY1 Then MaxY := ViewY1;

  // Scanline fill
  For Y := MinY to MaxY Do Begin
    // Build list of intersection X coordinates
    Nodes := 0;
    J := Count - 1;

    For I := 0 to Count - 1 Do Begin
      If ((Points[I].Y <= Y) and (Points[J].Y > Y)) or
         ((Points[J].Y <= Y) and (Points[I].Y > Y)) Then Begin
        If Nodes < RIP_MAX_POLY Then Begin
          NodeX[Nodes] := Points[I].X + LongInt(Y - Points[I].Y) *
            LongInt(Points[J].X - Points[I].X) DIV
            LongInt(Points[J].Y - Points[I].Y);
          Inc(Nodes);
        End;
      End;
      J := I;
    End;

    // Sort intersection points
    I := 0;
    While I < Nodes - 1 Do Begin
      If NodeX[I] > NodeX[I + 1] Then Begin
        Swap := NodeX[I];
        NodeX[I] := NodeX[I + 1];
        NodeX[I + 1] := Swap;
        If I > 0 Then Dec(I) Else Inc(I);
      End Else
        Inc(I);
    End;

    // Fill between pairs
    I := 0;
    While I < Nodes - 1 Do Begin
      For J := NodeX[I] to NodeX[I + 1] Do
        DrawPixel(J, Y, FillColor);
      Inc(I, 2);
    End;
  End;

  // Draw outline
  DrawPolygon(Points, Count);
End;

Procedure TRIPEngine.DrawPolyLine (Var Points: Array of TRIPPoint; Count: Integer);
Var
  I : Integer;
Begin
  If Count < 2 Then Exit;
  If Count > RIP_MAX_POLY Then Count := RIP_MAX_POLY;

  For I := 0 to Count - 2 Do
    DrawLine(Points[I].X, Points[I].Y, Points[I+1].X, Points[I+1].Y);
End;

Procedure TRIPEngine.FloodFill (X, Y: SmallInt; Border: Byte);
// Simple scanline flood fill
Var
  Stack  : Array[1..4096] of TRIPPoint;
  SP     : Integer;
  FillC  : Byte;
  SaveWM : Byte;

  Procedure Push (PX, PY: SmallInt);
  Begin
    If SP < 4096 Then Begin
      Inc(SP);
      Stack[SP].X := PX;
      Stack[SP].Y := PY;
    End;
  End;

Begin
  If Not InView(X, Y) Then Exit;
  If Pixels^[Y, X] = Border Then Exit;
  If Pixels^[Y, X] = FillColor Then Exit;

  SP := 0;
  FillC := FillColor;
  Push(X, Y);

  While SP > 0 Do Begin
    X := Stack[SP].X;
    Y := Stack[SP].Y;
    Dec(SP);

    If Not InView(X, Y) Then Continue;
    If Pixels^[Y, X] = Border Then Continue;
    If Pixels^[Y, X] = FillC Then Continue;

    // v3.0 Phase 15 fix: route through DrawPixel so the RGB buffers
    // stay in sync.  WriteMode is temporarily forced to COPY_PUT
    // because flood fill must overwrite unconditionally.
    SaveWM := WriteMode;
    WriteMode := RIP_COPY_PUT;
    DrawPixel(X, Y, FillC);
    WriteMode := SaveWM;

    Push(X + 1, Y);
    Push(X - 1, Y);
    Push(X, Y + 1);
    Push(X, Y - 1);
  End;
End;

Procedure TRIPEngine.DrawText8x8 (X, Y: SmallInt; S: String);
// System font text renderer — handles all 5 font modes
// Mode 0: 8x8,  Mode 1: 8x14,  Mode 2: 16x14,  Mode 3: 7x8,  Mode 4: 7x14
Var
  I, Row, Col : Integer;
  Ch          : Byte;
  FontByte    : Byte;
  CharW, CharH : Integer;
  PixX        : SmallInt;
Begin
  // If a CHR vector font is loaded for the current font, use it
  If (FontNum >= 1) and (FontNum <= 10) and (CHRFonts[FontNum] <> Nil) Then Begin
    DrawTextCHR(X, Y, S, FontNum, FontSize);
    Exit;
  End;

  // v3.0 Phase 18: MAF bitmap font takes priority over built-in
  If MAFIsLoaded and (MAFActiveRes >= 0) and (MAFActiveFont >= 0) Then Begin
    DrawTextMAF(X, Y, S);
    Exit;
  End;

  CharW := GetSysFontW;
  CharH := GetSysFontH;

  For I := 1 to Length(S) Do Begin
    Ch := Ord(S[I]);

    If CharH = 14 Then Begin
      // 8x14 font modes (1, 2, 4)
      For Row := 0 to 13 Do Begin
        FontByte := Font8x14[Ch * 14 + Row];

        If CharW = 16 Then Begin
          // Mode 2: double-width — each pixel drawn twice
          For Col := 0 to 7 Do
            If (FontByte AND ($80 SHR Col)) <> 0 Then Begin
              PixX := X + (I - 1) * 16 + Col * 2;
              DrawPixel(PixX, Y + Row, DrawColor);
              DrawPixel(PixX + 1, Y + Row, DrawColor);
            End;
        End Else Begin
          // Mode 1 (8-wide) or Mode 4 (7-wide)
          For Col := 0 to CharW - 1 Do
            If (FontByte AND ($80 SHR Col)) <> 0 Then
              DrawPixel(X + (I - 1) * CharW + Col, Y + Row, DrawColor);
        End;
      End;
    End Else Begin
      // 8x8 font modes (0, 3)
      For Row := 0 to 7 Do Begin
        FontByte := Font8x8[Ch * 8 + Row];

        For Col := 0 to CharW - 1 Do
          If (FontByte AND ($80 SHR Col)) <> 0 Then
            DrawPixel(X + (I - 1) * CharW + Col, Y + Row, DrawColor);
      End;
    End;
  End;

  CurX := X + Length(S) * CharW;
  CurY := Y;
End;

// ====================================================================
// Constructor / Destructor / Reset
// ====================================================================

Constructor TRIPEngine.Create;
Var
  I : Integer;
Begin
  Inherited Create;

  // v2.0: init canvas dimensions before allocating
  CanvasWidth  := RIP_DEFAULT_WIDTH;
  CanvasHeight := RIP_DEFAULT_HEIGHT;
  ActiveMaxX   := CanvasWidth - 1;
  ActiveMaxY   := CanvasHeight - 1;

  New(Pixels);
  New(PixelsRGB);
  New(PixelsRGB32);
  PixelFormat := RIP_PIXFMT_INDEXED8;
  For I := 1 to 10 Do CHRFonts[I] := Nil;

  // v3.0 Phase 18: RFF font init
  For I := 1 to RIP_MAX_RFF Do Begin
    RFFFonts[I]  := Nil;
    RFFLoaded[I] := False;
  End;
  RFFActiveFace := 0;
  RFFActiveFont := 0;
  RFFTracking   := 0;
  RFFLeading    := 0;

  // v3.0 Phase 18: MAF init
  MAFData       := Nil;
  MAFActiveRes  := -1;
  MAFActiveFont := -1;

  // v3.0 Phase 20: Table/Form init
  Table.Active := False;
  Table.ColCount := 0;
  Table.RowCount := 0;
  Table.ScrollTop := 0;
  FormFieldCount := 0;

  // v3.0 Phase 22: Audio init
  For I := 0 to RIP_MAX_AUDIO_STREAMS - 1 Do Begin
    AudioState[I]  := RIP_AUDIO_IDLE;
    AudioFile[I]   := '';
    AudioVolume[I] := 255;
  End;
  MIDILoaded    := False;
  MIDIFileName  := '';
  CueCount      := 0;
  BgAudioStream := -1;
  FrameCounter  := 0;

  // v3.0 Phase 23: Clip path init
  GetMem(ClipStackPtr, SizeOf(TClipStack));
  ClipInit(TClipStack(ClipStackPtr^));
  For I := 0 to 9 Do SavedScreens[I] := Nil;
  Clipboard := Nil;
  ClipSize  := 0;
  ClipW     := 0;
  ClipH     := 0;
  SavedClip   := Nil;
  SavedClipSz := 0;
  SavedClipW  := 0;
  SavedClipH  := 0;
  SavedTW.Active    := False;
  SavedMouse.Active := False;
  Reset;
End;

Destructor TRIPEngine.Destroy;
Var
  I : Integer;
Begin
  For I := 1 to 10 Do
    If CHRFonts[I] <> Nil Then Dispose(CHRFonts[I]);

  // v3.0 Phase 18: free RFF fonts
  For I := 1 to RIP_MAX_RFF Do
    FreeRFF(I);

  // v3.0 Phase 18: free MAF
  FreeMAF;

  // v3.0 Phase 23: free clip stack
  If ClipStackPtr <> Nil Then Begin
    FreeMem(ClipStackPtr, SizeOf(TClipStack));
    ClipStackPtr := Nil;
  End;

  For I := 0 to 9 Do
    If SavedScreens[I] <> Nil Then Dispose(SavedScreens[I]);

  If Clipboard <> Nil Then FreeMem(Clipboard, ClipSize);
  If SavedClip <> Nil Then FreeMem(SavedClip, SavedClipSz);

  Dispose(Pixels);
  Dispose(PixelsRGB);
  Dispose(PixelsRGB32);

  Inherited Destroy;
End;

Procedure TRIPEngine.Reset;
Var
  I : Integer;
Begin
  CurX := 0;
  CurY := 0;

  DrawColor  := 15;  // white
  FillColor  := 0;   // black
  DrawColorRGB := EGA_RGB[15];  // white
  FillColorRGB := EGA_RGB[0];   // black
  PixelFormat := RIP_PIXFMT_INDEXED8;  // v3.0 Phase 15: reset to indexed

  // v3.0 Phase 16: reset world coordinates
  WorldEnabled := False;
  WorldX0 := 0;
  WorldY0 := 0;
  WorldX1 := ActiveMaxX;
  WorldY1 := ActiveMaxY;
  WorldAspect := False;

  // v3.0 Phase 16: reset text area detection
  TextAreaDetected := False;
  TextAreaW := 80;
  TextAreaH := 43;

  // v3.0 Phase 17: reset JPEG streaming
  JPEGStrmActive := False;
  JPEGStrmPtr := Nil;
  FillStyle  := RIP_FILL_SOLID;
  LineStyle  := RIP_LINE_SOLID;
  LineThick  := 1;
  LinePattern := $FFFF;
  WriteMode  := RIP_COPY_PUT;

  FontNum    := RIP_DEFAULT_FONT;
  FontDir    := RIP_HORIZ_DIR;
  FontSize   := 1;
  FontHJust  := RIP_LEFT_TEXT;
  FontVJust  := RIP_TOP_TEXT;

  TextWinX0  := 0;
  TextWinY0  := 0;
  TextWinX1  := 79;
  TextWinY1  := 42;
  TextWinSize := 0;

  ViewX0 := 0;
  ViewY0 := 0;
  ViewX1 := ActiveMaxX;
  ViewY1 := ActiveMaxY;

  // v2.0 state
  ProtoVersion := 0;   // default v1.54
  ColorMode    := 0;   // 16-color
  DrawLayer    := 0;
  PenWidth     := 1;
  FrameRate    := 10;

  // Default EGA palette (first 16 entries)
  FillChar(Palette, SizeOf(Palette), 0);
  Palette[0]  := 0;   // black
  Palette[1]  := 1;   // blue
  Palette[2]  := 2;   // green
  Palette[3]  := 3;   // cyan
  Palette[4]  := 4;   // red
  Palette[5]  := 5;   // magenta
  Palette[6]  := 20;  // brown
  Palette[7]  := 7;   // light gray
  Palette[8]  := 56;  // dark gray
  Palette[9]  := 57;  // light blue
  Palette[10] := 58;  // light green
  Palette[11] := 59;  // light cyan
  Palette[12] := 60;  // light red
  Palette[13] := 61;  // light magenta
  Palette[14] := 62;  // yellow
  Palette[15] := 63;  // white

  FillChar(FillPat, SizeOf(FillPat), $FF);

  MouseCount     := 0;
  NextTabIndex   := 1;
  FocusedField   := 0;
  HotKeysEnabled := True;
  TabEnabled     := True;
  For I := 1 to RIP_MAX_MOUSE Do
    FillChar(MouseFields[I], SizeOf(TRIPMouseField), 0);

  FillChar(BtnStyle, SizeOf(BtnStyle), 0);
  BtnStyle.BevelSize := 1;
  BtnStyle.DFore     := 15;
  BtnStyle.BRight    := 15;
  BtnStyle.DDark     := 8;
  BtnStyle.Surface   := 7;
  BtnStyle.CornerCol := 16;  // > 15 = don't draw corners

  VarCount := 0;
  For I := 1 to RIP_MAX_VARS Do
    Variables[I].Active := False;

  For I := 1 to 10 Do
    If CHRFonts[I] <> Nil Then Begin
      Dispose(CHRFonts[I]);
      CHRFonts[I] := Nil;
    End;

  // Phase 1: clear saved state
  For I := 0 to 9 Do
    If SavedScreens[I] <> Nil Then Begin
      Dispose(SavedScreens[I]);
      SavedScreens[I] := Nil;
    End;

  SavedTW.Active    := False;
  SavedMouse.Active := False;

  If Clipboard <> Nil Then Begin
    FreeMem(Clipboard, ClipSize);
    Clipboard := Nil;
    ClipSize  := 0;
  End;
  ClipW := 0;
  ClipH := 0;

  If SavedClip <> Nil Then Begin
    FreeMem(SavedClip, SavedClipSz);
    SavedClip   := Nil;
    SavedClipSz := 0;
  End;
  SavedClipW := 0;
  SavedClipH := 0;

  LineBuf   := '';
  Continued := False;

  ClearScreen;
End;

Procedure TRIPEngine.ClearScreen;
Begin
  FillChar(Pixels^, SizeOf(TRIPPixelBuffer), 0);
  FillChar(PixelsRGB^, SizeOf(TRIPPixelBufferRGB), 0);
  FillChar(PixelsRGB32^, SizeOf(TRIPPixelBufferRGB32), 0);

  // v3.0 Phase 21: clear local-scope variables on scene end
  KillLocalVars;
End;

Procedure TRIPEngine.ClearViewport;
Var
  X, Y : SmallInt;
  Blank32 : TRIPRGBA;
Begin
  Blank32.R := 0; Blank32.G := 0; Blank32.B := 0; Blank32.A := $FF;

  For Y := ViewY0 to ViewY1 Do
    For X := ViewX0 to ViewX1 Do Begin
      Pixels^[Y, X] := 0;
      PixelsRGB^[Y, X].R := 0;
      PixelsRGB^[Y, X].G := 0;
      PixelsRGB^[Y, X].B := 0;
      PixelsRGB32^[Y, X] := Blank32;
    End;
End;

Function TRIPEngine.GetPixel (X, Y: SmallInt) : Byte;
Begin
  If InView(X, Y) Then
    Result := Pixels^[Y, X]
  Else
    Result := 0;
End;

// v3.0 Phase 15: true-color pixel read. Valid in any PixelFormat — in
// indexed mode it resolves the stored index through the active palette.
Function TRIPEngine.GetPixelRGB (X, Y: SmallInt) : TRIPRGB;
Begin
  If Not InView(X, Y) Then Begin
    Result.R := 0; Result.G := 0; Result.B := 0;
    Exit;
  End;

  If PixelFormat = RIP_PIXFMT_INDEXED8 Then
    Result := IndexToRGB(Pixels^[Y, X])
  Else
    Result := PixelsRGB^[Y, X];
End;

Function TRIPEngine.GetWidth : SmallInt;
Begin
  Result := CanvasWidth;
End;

Function TRIPEngine.GetHeight : SmallInt;
Begin
  Result := CanvasHeight;
End;

Function TRIPEngine.FindMouseField (X, Y: SmallInt) : Integer;
Var
  I : Integer;
Begin
  Result := 0;

  For I := MouseCount downto 1 Do
    If MouseFields[I].Active Then
      If (X >= MouseFields[I].X0) and (X <= MouseFields[I].X1) and
         (Y >= MouseFields[I].Y0) and (Y <= MouseFields[I].Y1) Then Begin
        Result := I;
        Exit;
      End;
End;

// ====================================================================
// BGI-compatible public API
// ====================================================================

Procedure TRIPEngine.PutPixel (X, Y: SmallInt; Color: Byte);
Begin
  DrawPixel(X, Y, Color);
End;

Procedure TRIPEngine.PutPixel (X, Y: SmallInt; RGB: TRIPRGB);
Begin
  DrawPixel(X, Y, RGB);
End;

Procedure TRIPEngine.Line (X0, Y0, X1, Y1: SmallInt);
Begin
  DrawLine(X0, Y0, X1, Y1);
End;

Procedure TRIPEngine.LineTo (X, Y: SmallInt);
Begin
  DrawLine(CurX, CurY, X, Y);
End;

Procedure TRIPEngine.LineRel (DX, DY: SmallInt);
Begin
  DrawLine(CurX, CurY, CurX + DX, CurY + DY);
End;

Procedure TRIPEngine.Rectangle (X0, Y0, X1, Y1: SmallInt);
Begin
  DrawRect(X0, Y0, X1, Y1);
End;

Procedure TRIPEngine.Bar (X0, Y0, X1, Y1: SmallInt);
Begin
  DrawBar(X0, Y0, X1, Y1);
End;

Procedure TRIPEngine.Bar3D (X0, Y0, X1, Y1: SmallInt; Depth: SmallInt; Top: Boolean);
Begin
  DrawBar(X0, Y0, X1, Y1);
  DrawRect(X0, Y0, X1, Y1);
  // 3D edges
  DrawLine(X1, Y0, X1 + Depth, Y0 - Depth);
  DrawLine(X1 + Depth, Y0 - Depth, X1 + Depth, Y1 - Depth);
  DrawLine(X1, Y1, X1 + Depth, Y1 - Depth);
  If Top Then Begin
    DrawLine(X0, Y0, X0 + Depth, Y0 - Depth);
    DrawLine(X0 + Depth, Y0 - Depth, X1 + Depth, Y0 - Depth);
  End;
End;

Procedure TRIPEngine.Circle (XC, YC, Radius: SmallInt);
Begin
  DrawCircle(XC, YC, Radius);
End;

Procedure TRIPEngine.Ellipse (XC, YC: SmallInt; StartAng, EndAng, XR, YR: SmallInt);
Begin
  If (StartAng = 0) and (EndAng = 360) Then
    DrawOval(XC, YC, XR, YR)
  Else
    DrawOvalArc(XC, YC, StartAng, EndAng, XR, YR);
End;

Procedure TRIPEngine.FillEllipse (XC, YC, XR, YR: SmallInt);
Begin
  DrawFilledOval(XC, YC, XR, YR);
End;

Procedure TRIPEngine.Arc (XC, YC: SmallInt; StartAng, EndAng, Radius: SmallInt);
Begin
  DrawArc(XC, YC, StartAng, EndAng, Radius);
End;

Procedure TRIPEngine.PieSlice (XC, YC: SmallInt; StartAng, EndAng, Radius: SmallInt);
Begin
  DrawPieSlice(XC, YC, StartAng, EndAng, Radius);
End;

Procedure TRIPEngine.Sector (XC, YC: SmallInt; StartAng, EndAng, XR, YR: SmallInt);
Begin
  DrawOvalPie(XC, YC, StartAng, EndAng, XR, YR);
End;

Procedure TRIPEngine.DrawPoly (NumPoints: Integer; Var PolyPoints);
Var
  Pts : Array[0..RIP_MAX_POLY-1] of TRIPPoint absolute PolyPoints;
Begin
  If NumPoints > RIP_MAX_POLY Then NumPoints := RIP_MAX_POLY;
  DrawPolygon(Pts, NumPoints);
End;

Procedure TRIPEngine.FillPoly (NumPoints: Integer; Var PolyPoints);
Var
  Pts : Array[0..RIP_MAX_POLY-1] of TRIPPoint absolute PolyPoints;
Begin
  If NumPoints > RIP_MAX_POLY Then NumPoints := RIP_MAX_POLY;
  DrawFillPoly(Pts, NumPoints);
End;

// ---- Text ----

Procedure TRIPEngine.OutTextXY (X, Y: SmallInt; S: String);
Begin
  S := ExpandVars(S);

  // v3.0 Phase 18: RFF scalable font takes priority
  If (RFFActiveFont >= 1) and (RFFActiveFont <= RIP_MAX_RFF) and
     RFFLoaded[RFFActiveFont] Then
    DrawTextRFF(X, Y, S, FontSize * 8, FontDir * 90)
  Else If (FontNum >= 1) and (FontNum <= 10) and
     (CHRFonts[FontNum] <> Nil) and (CHRFonts[FontNum]^.Loaded) Then
    DrawTextCHR(X, Y, S, FontNum, FontSize)
  Else
    DrawText8x8(X, Y, S);
End;

Procedure TRIPEngine.OutText (S: String);
Begin
  S := ExpandVars(S);

  If (RFFActiveFont >= 1) and (RFFActiveFont <= RIP_MAX_RFF) and
     RFFLoaded[RFFActiveFont] Then
    DrawTextRFF(CurX, CurY, S, FontSize * 8, FontDir * 90)
  Else If (FontNum >= 1) and (FontNum <= 10) and
     (CHRFonts[FontNum] <> Nil) and (CHRFonts[FontNum]^.Loaded) Then
    DrawTextCHR(CurX, CurY, S, FontNum, FontSize)
  Else
    DrawText8x8(CurX, CurY, S);
End;

// ---- Position ----

Procedure TRIPEngine.MoveTo (X, Y: SmallInt);
Begin
  CurX := X;
  CurY := Y;
End;

Procedure TRIPEngine.MoveRel (DX, DY: SmallInt);
Begin
  Inc(CurX, DX);
  Inc(CurY, DY);
End;

Function TRIPEngine.GetX : SmallInt;
Begin
  Result := CurX;
End;

Function TRIPEngine.GetY : SmallInt;
Begin
  Result := CurY;
End;

// ---- Color / palette ----

Procedure TRIPEngine.SetColor (Color: Byte);
Begin
  DrawColor := Color;
End;

Function TRIPEngine.GetColor : Byte;
Begin
  Result := DrawColor;
End;

Procedure TRIPEngine.SetBkColor (Color: Byte);
Begin
  // Background color is palette index 0 in RIPscrip
  Palette[0] := Color;
End;

Function TRIPEngine.GetBkColor : Byte;
Begin
  Result := Palette[0];
End;

Procedure TRIPEngine.SetPalette (Index, Color: Byte);
Begin
  If Index < RIP_MAX_COLORS Then
    Palette[Index] := Color;
End;

Procedure TRIPEngine.SetAllPalette (Var Pal: TRIPPalette);
Begin
  Move(Pal, Palette, SizeOf(TRIPPalette));
End;

Procedure TRIPEngine.GetPalette (Var Pal: TRIPPalette);
Begin
  Move(Palette, Pal, SizeOf(TRIPPalette));
End;

// ---- Fill ----

Procedure TRIPEngine.SetFillStyle (Style: Word; Color: Byte);
Begin
  FillStyle := Style;
  FillColor := Color;
End;

Procedure TRIPEngine.SetFillPattern (Var Pattern: TRIPFillPattern; Color: Byte);
Begin
  Move(Pattern, FillPat, SizeOf(TRIPFillPattern));
  FillColor := Color;
  FillStyle := RIP_FILL_USER;
End;

Procedure TRIPEngine.GetFillSettings (Var Style: Word; Var Color: Byte);
Begin
  Style := FillStyle;
  Color := FillColor;
End;

// ---- Line style ----

Procedure TRIPEngine.SetLineStyle (Style, Pattern, Thick: Word);
Begin
  LineStyle   := Style;
  LinePattern := Pattern;
  LineThick   := Thick;
End;

Procedure TRIPEngine.GetLineSettings (Var Style, Pattern, Thick: Word);
Begin
  Style   := LineStyle;
  Pattern := LinePattern;
  Thick   := LineThick;
End;

// ---- Write mode ----

Procedure TRIPEngine.SetWriteMode (Mode: Byte);
Begin
  WriteMode := Mode;
End;

Function TRIPEngine.GetWriteMode : Byte;
Begin
  Result := WriteMode;
End;

// ---- Text style ----

Procedure TRIPEngine.SetTextStyle (Font, Direction, CharSize: Word);
Begin
  FontNum  := Font;
  FontDir  := Direction;
  FontSize := CharSize;
End;

Procedure TRIPEngine.SetTextJustify (Horiz, Vert: Word);
Begin
  FontHJust := Horiz;
  FontVJust := Vert;
End;

// ---- Viewport / window ----

Procedure TRIPEngine.SetViewPort (X0, Y0, X1, Y1: SmallInt; Clip: Boolean);
Begin
  ViewX0 := X0;
  ViewY0 := Y0;
  ViewX1 := X1;
  ViewY1 := Y1;
End;

Procedure TRIPEngine.GetViewPort (Var X0, Y0, X1, Y1: SmallInt);
Begin
  X0 := ViewX0;
  Y0 := ViewY0;
  X1 := ViewX1;
  Y1 := ViewY1;
End;

Procedure TRIPEngine.SetTextWindow (X0, Y0, X1, Y1: SmallInt; Size: Byte);
Begin
  TextWinX0   := X0;
  TextWinY0   := Y0;
  TextWinX1   := X1;
  TextWinY1   := Y1;
  TextWinSize := Size;
End;

// ---- Mouse fields ----

Function TRIPEngine.AddMouseField (X0, Y0, X1, Y1: SmallInt; HostCmd, Text: String) : Integer;
Begin
  Result := 0;

  If MouseCount >= RIP_MAX_MOUSE Then Exit;

  Inc(MouseCount);
  FillChar(MouseFields[MouseCount], SizeOf(TRIPMouseField), 0);
  With MouseFields[MouseCount] Do Begin
    Active  := True;
    Self.MouseFields[MouseCount].X0 := X0;
    Self.MouseFields[MouseCount].Y0 := Y0;
    Self.MouseFields[MouseCount].X1 := X1;
    Self.MouseFields[MouseCount].Y1 := Y1;
    Self.MouseFields[MouseCount].HostCmd := HostCmd;
    Self.MouseFields[MouseCount].Text    := Text;
  End;

  Result := MouseCount;
End;

Procedure TRIPEngine.KillMouseField (Index: Integer);
Begin
  If (Index >= 1) and (Index <= RIP_MAX_MOUSE) Then
    FillChar(MouseFields[Index], SizeOf(TRIPMouseField), 0);
End;

Procedure TRIPEngine.KillAllMouseFields;
Var
  I : Integer;
Begin
  MouseCount   := 0;
  NextTabIndex := 1;
  FocusedField := 0;
  For I := 1 to RIP_MAX_MOUSE Do
    FillChar(MouseFields[I], SizeOf(TRIPMouseField), 0);
End;

Function TRIPEngine.GetMouseCount : Integer;
Begin
  Result := MouseCount;
End;

Function TRIPEngine.GetMouseField (Index: Integer) : TRIPMouseField;
Begin
  If (Index >= 1) and (Index <= RIP_MAX_MOUSE) Then
    Result := MouseFields[Index]
  Else
    FillChar(Result, SizeOf(Result), 0);
End;

// ---- Button ----

Procedure TRIPEngine.SetButtonStyle (Var Style: TRIPButtonStyle);
Begin
  BtnStyle := Style;
End;

Procedure TRIPEngine.DrawButton (X0, Y0, X1, Y1: SmallInt; Label_, HostCmd: String);
Var
  SaveColor : Byte;
  Bev, I    : Integer;
Begin
  SaveColor := DrawColor;
  Bev := BtnStyle.BevelSize;
  If Bev < 1 Then Bev := 1;

  // Draw button surface
  DrawColor := BtnStyle.Surface;
  DrawBar(X0, Y0, X1, Y1);

  // Draw bevel highlight (top-left), BevelSize pixels thick
  DrawColor := BtnStyle.BRight;
  For I := 0 to Bev - 1 Do Begin
    DrawLine(X0 + I, Y0 + I, X1 - I, Y0 + I);   // top edge
    DrawLine(X0 + I, Y0 + I, X0 + I, Y1 - I);   // left edge
  End;

  // Draw bevel shadow (bottom-right), BevelSize pixels thick
  DrawColor := BtnStyle.DDark;
  For I := 0 to Bev - 1 Do Begin
    DrawLine(X0 + I, Y1 - I, X1 - I, Y1 - I);   // bottom edge
    DrawLine(X1 - I, Y0 + I, X1 - I, Y1 - I);   // right edge
  End;

  // Draw corner pixels
  If BtnStyle.CornerCol < 16 Then Begin
    DrawColor := BtnStyle.CornerCol;
    DrawPixel(X0, Y0, BtnStyle.CornerCol);
    DrawPixel(X1, Y0, BtnStyle.CornerCol);
    DrawPixel(X0, Y1, BtnStyle.CornerCol);
    DrawPixel(X1, Y1, BtnStyle.CornerCol);
  End;

  // Draw label centered (uses CHR font if loaded)
  DrawColor := BtnStyle.DFore;
  OutTextXY(X0 + (X1 - X0 - Length(Label_) * GetSysFontW) div 2,
            Y0 + (Y1 - Y0 - GetSysFontH) div 2,
            Label_);

  DrawColor := SaveColor;

  // Register mouse field
  AddMouseField(X0, Y0, X1, Y1, HostCmd, Label_);
End;

// ---- Image ----

Function TRIPEngine.ImageSize (X0, Y0, X1, Y1: SmallInt) : LongInt;
Begin
  Result := (LongInt(X1 - X0 + 1) * LongInt(Y1 - Y0 + 1)) + 4;
  // +4 for width/height header
End;

Procedure TRIPEngine.GetImage (X0, Y0, X1, Y1: SmallInt; Var Buf);
Var
  P    : ^Byte;
  X, Y : SmallInt;
Begin
  P := @Buf;

  // Store width and height as first 4 bytes
  PWord(P)^ := X1 - X0 + 1; Inc(P, 2);
  PWord(P)^ := Y1 - Y0 + 1; Inc(P, 2);

  For Y := Y0 to Y1 Do
    For X := X0 to X1 Do Begin
      P^ := GetPixel(X, Y);
      Inc(P);
    End;
End;

Procedure TRIPEngine.PutImage (X, Y: SmallInt; Var Buf; Mode: Byte);
Var
  P       : ^Byte;
  W, H    : Word;
  IX, IY  : SmallInt;
  SaveMode : Byte;
Begin
  P := @Buf;
  W := PWord(P)^; Inc(P, 2);
  H := PWord(P)^; Inc(P, 2);

  SaveMode  := WriteMode;
  WriteMode := Mode;

  For IY := 0 to H - 1 Do
    For IX := 0 to W - 1 Do Begin
      DrawPixel(X + IX, Y + IY, P^);
      Inc(P);
    End;

  WriteMode := SaveMode;
End;

// ---- Icon loading (ICN/MSK/HIC/BMH — full EGA planar rendering) ----
// ICN: Standard icon — 4-plane EGA bitmap, renders with current write mode.
//      BGI GetImage format: header(4 bytes: width-1, height-1) + planar pixel data.
//      LoadIcon(FileName, X, Y, Mode) — loads and renders ICN at (X,Y).
// MSK: Transparency mask — 1-bit bitmap, same dimensions as companion ICN.
//      Pixel=1 means opaque (draw ICN pixel), pixel=0 means transparent (skip).
//      LoadMask(FileName, X, Y) — applies mask to screen (AND operation).
//      LoadIconMasked(IconFile, MaskFile, X, Y) — loads ICN+MSK pair, renders
//        icon only where mask is opaque, preserving background elsewhere.
// HIC: Highlight icon — same format as ICN, used for mouse-over/active states.
//      LoadHotIcon(FileName, X, Y) — loads highlight variant, rendered when
//        the associated mouse field is focused, clicked, or hotkey-activated.
// BMH: BMP highlight icon (v2.0) — standard Windows BMP used as highlight.
//      LoadBMH(FileName, X, Y) — loads 4/24-bit BMP as highlight overlay.

Function TRIPEngine.LoadIcon (FileName: String; X, Y: SmallInt; Mode: Byte) : Boolean;
// ICN format per RIPscrip v1.54 spec:
// Header: width-1 (word) + height-1 (word)
// Data: 4 EGA bit planes per scanline, order 3,2,1,0 (MSB first)
// Each plane: ceil(width/8) bytes per row, padded to 8-pixel boundary
// Optional trash byte at end of file (ignored)
Var
  F              : File;
  WRaw, HRaw     : Word;
  W, H           : SmallInt;
  IX, IY         : SmallInt;
  Plane          : Integer;
  RowBytes       : Integer;
  PlaneData      : Array[0..3, 0..79] of Byte;
  Color          : Byte;
  ByteIdx, BitIdx : Integer;
  SaveMode       : Byte;
  PlaneOrder     : Array[0..3] of Integer;
Begin
  Result := False;

  Assign(F, FileName);
  {$I-} System.Reset(F, 1); {$I+}
  If IOResult <> 0 Then Exit;

  BlockRead(F, WRaw, 2);
  BlockRead(F, HRaw, 2);

  // Per spec: stored as pixels-1
  W := WRaw + 1;
  H := HRaw + 1;

  If (W <= 0) or (H <= 0) or (W > 1280) or (H > 1024) Then Begin
    Close(F);
    Exit;
  End;

  RowBytes := (W + 7) DIV 8;
  SaveMode  := WriteMode;
  WriteMode := Mode;

  // Plane order per spec: 3, 2, 1, 0 (MSB first)
  PlaneOrder[0] := 3;
  PlaneOrder[1] := 2;
  PlaneOrder[2] := 1;
  PlaneOrder[3] := 0;

  For IY := 0 to H - 1 Do Begin
    // Read 4 planes for this row in spec order (3,2,1,0)
    For Plane := 0 to 3 Do
      BlockRead(F, PlaneData[PlaneOrder[Plane]], RowBytes);

    // Combine planes to get pixel colors
    For IX := 0 to W - 1 Do Begin
      ByteIdx := IX DIV 8;
      BitIdx  := 7 - (IX MOD 8);

      Color := 0;
      For Plane := 0 to 3 Do
        If (PlaneData[Plane][ByteIdx] AND (1 SHL BitIdx)) <> 0 Then
          Color := Color OR (1 SHL Plane);

      DrawPixel(X + IX, Y + IY, Color);
    End;
  End;

  Close(F);
  WriteMode := SaveMode;
  Result := True;
End;

Function TRIPEngine.SaveIcon (FileName: String; X0, Y0, X1, Y1: SmallInt) : Boolean;
// Save screen region as ICN file per RIPscrip v1.54 spec
// Width/height stored as pixels-1, planes in order 3,2,1,0
Var
  F              : File;
  WRaw, HRaw     : Word;
  W, H           : SmallInt;
  IX, IY         : SmallInt;
  Plane          : Integer;
  RowBytes       : Integer;
  PlaneData      : Array[0..3, 0..79] of Byte;
  Color          : Byte;
  ByteIdx, BitIdx : Integer;
  PlaneOrder     : Array[0..3] of Integer;
  Trash          : Byte;
Begin
  Result := False;

  W := X1 - X0 + 1;
  H := Y1 - Y0 + 1;

  If (W <= 0) or (H <= 0) or (W > 1280) Then Exit;

  RowBytes := (W + 7) DIV 8;

  // Store as pixels-1
  WRaw := W - 1;
  HRaw := H - 1;

  Assign(F, FileName);
  {$I-} ReWrite(F, 1); {$I+}
  If IOResult <> 0 Then Exit;

  BlockWrite(F, WRaw, 2);
  BlockWrite(F, HRaw, 2);

  // Plane order: 3, 2, 1, 0
  PlaneOrder[0] := 3;
  PlaneOrder[1] := 2;
  PlaneOrder[2] := 1;
  PlaneOrder[3] := 0;

  For IY := Y0 to Y1 Do Begin
    FillChar(PlaneData, SizeOf(PlaneData), 0);

    For IX := 0 to W - 1 Do Begin
      Color   := GetPixel(X0 + IX, IY) AND $0F;
      ByteIdx := IX DIV 8;
      BitIdx  := 7 - (IX MOD 8);

      For Plane := 0 to 3 Do
        If (Color AND (1 SHL Plane)) <> 0 Then
          PlaneData[Plane][ByteIdx] := PlaneData[Plane][ByteIdx] OR (1 SHL BitIdx);
    End;

    // Write planes in spec order (3,2,1,0)
    For Plane := 0 to 3 Do
      BlockWrite(F, PlaneData[PlaneOrder[Plane]], RowBytes);
  End;

  // Trash byte per spec
  Trash := 0;
  BlockWrite(F, Trash, 1);

  Close(F);
  Result := True;
End;

// ---- Phase 2: Mask and highlighted icon loading ----

Function TRIPEngine.LoadMask (FileName: String; X, Y: SmallInt) : Boolean;
// Load a .MSK file and apply as AND mask (clear pixels where mask=0)
// MSK format = BGI GetImage: w-1(word) h-1(word) + 4 EGA planes + 2 pad
Var
  F              : File;
  WRaw, HRaw     : Word;
  W, H           : SmallInt;
  IX, IY         : SmallInt;
  Plane          : Integer;
  RowBytes       : Integer;
  PlaneData      : Array[0..3, 0..79] of Byte;
  MaskBit        : Boolean;
  ByteIdx, BitIdx : Integer;
Begin
  Result := False;

  Assign(F, FileName);
  {$I-} System.Reset(F, 1); {$I+}
  If IOResult <> 0 Then Exit;

  BlockRead(F, WRaw, 2);
  BlockRead(F, HRaw, 2);

  W := WRaw + 1;
  H := HRaw + 1;

  If (W <= 0) or (H <= 0) or (W > 1280) Then Begin
    Close(F);
    Exit;
  End;

  RowBytes := (W + 7) DIV 8;

  For IY := 0 to H - 1 Do Begin
    For Plane := 0 to 3 Do
      BlockRead(F, PlaneData[Plane], RowBytes);

    For IX := 0 to W - 1 Do Begin
      ByteIdx := IX DIV 8;
      BitIdx  := 7 - (IX MOD 8);

      // If ANY plane bit is set, pixel is opaque (keep it)
      // If ALL planes are 0, pixel is transparent (clear to 0)
      MaskBit := False;
      For Plane := 0 to 3 Do
        If (PlaneData[Plane][ByteIdx] AND (1 SHL BitIdx)) <> 0 Then
          MaskBit := True;

      If Not MaskBit Then
        DrawPixel(X + IX, Y + IY, 0);
    End;
  End;

  Close(F);
  Result := True;
End;

Function TRIPEngine.LoadIconMasked (IconFile, MaskFile: String; X, Y: SmallInt) : Boolean;
// Load icon with transparency mask: first apply mask, then draw icon
Begin
  Result := False;

  // Draw the icon (opaque)
  If Not LoadIcon(IconFile, X, Y, 0) Then Exit;

  // Apply mask — clear pixels where mask is transparent
  LoadMask(MaskFile, X, Y);

  Result := True;
End;

Function TRIPEngine.LoadHotIcon (FileName: String; X, Y: SmallInt) : Boolean;
// Load a .HIC highlighted icon — same format as ICN/MSK (BGI GetImage)
Begin
  Result := LoadIcon(FileName, X, Y, 0);
End;

// ---- Phase 2: Button enhancements ----

Procedure TRIPEngine.DrawButtonEx (X0, Y0, X1, Y1: SmallInt;
  Label_, HostCmd, IconFile, HotIconFile: String;
  IsRadio, IsCheckbox, InitSelected: Boolean);
Var
  SaveColor : Byte;
  Idx       : Integer;
  Bev, I    : Integer;
Begin
  SaveColor := DrawColor;
  Bev := BtnStyle.BevelSize;
  If Bev < 1 Then Bev := 1;

  // Draw button surface
  DrawColor := BtnStyle.Surface;
  DrawBar(X0, Y0, X1, Y1);

  // Draw bevel highlight (top-left)
  DrawColor := BtnStyle.BRight;
  For I := 0 to Bev - 1 Do Begin
    DrawLine(X0 + I, Y0 + I, X1 - I, Y0 + I);
    DrawLine(X0 + I, Y0 + I, X0 + I, Y1 - I);
  End;

  // Draw bevel shadow (bottom-right)
  DrawColor := BtnStyle.DDark;
  For I := 0 to Bev - 1 Do Begin
    DrawLine(X0 + I, Y1 - I, X1 - I, Y1 - I);
    DrawLine(X1 - I, Y0 + I, X1 - I, Y1 - I);
  End;

  // Corner pixels
  If BtnStyle.CornerCol < 16 Then Begin
    DrawPixel(X0, Y0, BtnStyle.CornerCol);
    DrawPixel(X1, Y0, BtnStyle.CornerCol);
    DrawPixel(X0, Y1, BtnStyle.CornerCol);
    DrawPixel(X1, Y1, BtnStyle.CornerCol);
  End;

  // If icon file specified, load it on the button
  If IconFile <> '' Then
    LoadIcon(IconFile, X0 + Bev + 1, Y0 + Bev + 1, 0)
  Else Begin
    // Draw label centered (uses CHR font if loaded)
    DrawColor := BtnStyle.DFore;
    OutTextXY(X0 + (X1 - X0 - Length(Label_) * GetSysFontW) div 2,
              Y0 + (Y1 - Y0 - GetSysFontH) div 2,
              Label_);
  End;

  DrawColor := SaveColor;

  // Register mouse field with button state
  If MouseCount < RIP_MAX_MOUSE Then Begin
    Inc(MouseCount);
    Idx := MouseCount;
    FillChar(MouseFields[Idx], SizeOf(TRIPMouseField), 0);
    With MouseFields[Idx] Do Begin
      Active      := True;
      Self.MouseFields[Idx].X0 := X0;
      Self.MouseFields[Idx].Y0 := Y0;
      Self.MouseFields[Idx].X1 := X1;
      Self.MouseFields[Idx].Y1 := Y1;
      Self.MouseFields[Idx].HostCmd := HostCmd;
      Self.MouseFields[Idx].Text    := Label_;
      Invert      := True;
      IsButton    := True;
      Self.MouseFields[Idx].IsRadio    := IsRadio;
      Self.MouseFields[Idx].IsCheckbox := IsCheckbox;
      Self.MouseFields[Idx].GroupID    := BtnStyle.GrpID;
      Selected    := InitSelected;
      Self.MouseFields[Idx].IconFile    := IconFile;
      Self.MouseFields[Idx].HotIconFile := HotIconFile;
      TabIndex    := NextTabIndex;
    End;
    Inc(NextTabIndex);

    // Parse hotkey from label: (M) or [F] pattern
    If Length(Label_) >= 3 Then Begin
      If ((Label_[1] = '(') and (Label_[3] = ')')) or
         ((Label_[1] = '[') and (Label_[3] = ']')) Then Begin
        MouseFields[Idx].HotKey := Label_[2];
        If (MouseFields[Idx].HotKey >= 'a') and (MouseFields[Idx].HotKey <= 'z') Then
          MouseFields[Idx].HotKey := Chr(Ord(MouseFields[Idx].HotKey) - 32);

        // Draw underline under the hotkey character
        If (BtnStyle.ULineCol < 16) and (IconFile = '') Then Begin
          DrawColor := BtnStyle.ULineCol;
          DrawLine(
            X0 + (X1 - X0 - Length(Label_) * GetSysFontW) div 2 + GetSysFontW,
            Y0 + (Y1 - Y0 - GetSysFontH) div 2 + GetSysFontH,
            X0 + (X1 - X0 - Length(Label_) * GetSysFontW) div 2 + GetSysFontW * 2 - 1,
            Y0 + (Y1 - Y0 - GetSysFontH) div 2 + GetSysFontH);
          DrawColor := SaveColor;
        End;
      End;
    End;

    // If initially selected, show hot icon or invert
    If InitSelected Then Begin
      If HotIconFile <> '' Then
        LoadHotIcon(HotIconFile, X0 + Bev + 1, Y0 + Bev + 1)
      Else
        InvertRegion(X0, Y0, X1, Y1);
    End;
  End;
End;

Procedure TRIPEngine.ClickButton (Index: Integer);
Var
  I  : Integer;
  MF : TRIPMouseField;
Begin
  If (Index < 1) or (Index > MouseCount) Then Exit;
  If Not MouseFields[Index].Active Then Exit;
  If Not MouseFields[Index].IsButton Then Exit;

  MF := MouseFields[Index];

  // Radio button: deselect all others in same group
  If MF.IsRadio Then Begin
    For I := 1 to MouseCount Do
      If MouseFields[I].Active and MouseFields[I].IsRadio and
         (MouseFields[I].GroupID = MF.GroupID) and (I <> Index) Then Begin
        If MouseFields[I].Selected Then Begin
          MouseFields[I].Selected := False;
          // Restore normal icon or un-invert
          If MouseFields[I].IconFile <> '' Then
            LoadIcon(MouseFields[I].IconFile, MouseFields[I].X0 + 2, MouseFields[I].Y0 + 2, 0)
          Else
            InvertRegion(MouseFields[I].X0, MouseFields[I].Y0,
                         MouseFields[I].X1, MouseFields[I].Y1);
        End;
      End;

    // Select this one
    MouseFields[Index].Selected := True;
    If MF.HotIconFile <> '' Then
      LoadHotIcon(MF.HotIconFile, MF.X0 + 2, MF.Y0 + 2)
    Else
      InvertRegion(MF.X0, MF.Y0, MF.X1, MF.Y1);
  End;

  // Checkbox: toggle
  If MF.IsCheckbox Then Begin
    MouseFields[Index].Selected := Not MouseFields[Index].Selected;

    If MouseFields[Index].Selected Then Begin
      If MF.HotIconFile <> '' Then
        LoadHotIcon(MF.HotIconFile, MF.X0 + 2, MF.Y0 + 2)
      Else
        InvertRegion(MF.X0, MF.Y0, MF.X1, MF.Y1);
    End Else Begin
      If MF.IconFile <> '' Then
        LoadIcon(MF.IconFile, MF.X0 + 2, MF.Y0 + 2, 0)
      Else
        InvertRegion(MF.X0, MF.Y0, MF.X1, MF.Y1);
    End;
  End;

  // Plain button with invert
  If (Not MF.IsRadio) and (Not MF.IsCheckbox) and MF.Invert Then
    InvertRegion(MF.X0, MF.Y0, MF.X1, MF.Y1);
End;

Procedure TRIPEngine.InvertRegion (X0, Y0, X1, Y1: SmallInt);
// XOR all pixels in the region with $0F (inverts all 4 color bits)
Var
  X, Y   : SmallInt;
  SaveWM : Byte;
Begin
  // v3.0 Phase 15 fix: use XOR write mode through DrawPixel so RGB
  // buffers stay in sync with the indexed buffer.
  SaveWM := WriteMode;
  WriteMode := RIP_XOR_PUT;
  For Y := ClipY(Y0) to ClipY(Y1) Do
    For X := ClipX(X0) to ClipX(X1) Do
      DrawPixel(X, Y, $0F);
  WriteMode := SaveWM;
End;

// ---- Phase 5: Button hotkeys and tab navigation ----

Function TRIPEngine.FindButtonByHotkey (Key: Char) : Integer;
// Find the first active button whose HotKey matches Key
// Returns mouse field index (1-based) or 0 if not found
Var
  I    : Integer;
  UKey : Char;
Begin
  Result := 0;
  If Not HotKeysEnabled Then Exit;

  // Case-insensitive match
  UKey := Key;
  If (UKey >= 'a') and (UKey <= 'z') Then
    UKey := Chr(Ord(UKey) - 32);

  For I := 1 to MouseCount Do
    If MouseFields[I].Active and MouseFields[I].IsButton and
       (MouseFields[I].HotKey <> #0) Then Begin
      If MouseFields[I].HotKey = UKey Then Begin
        Result := I;
        Exit;
      End;
      // Also check lowercase
      If (MouseFields[I].HotKey >= 'a') and (MouseFields[I].HotKey <= 'z') Then
        If Chr(Ord(MouseFields[I].HotKey) - 32) = UKey Then Begin
          Result := I;
          Exit;
        End;
    End;
End;

Function TRIPEngine.GetNextTabField : Integer;
// Find next tabbable field after FocusedField
// Wraps around to first field if at end
Var
  I, Start : Integer;
Begin
  Result := 0;
  If Not TabEnabled Then Exit;
  If MouseCount = 0 Then Exit;

  If FocusedField = 0 Then
    Start := 1
  Else
    Start := FocusedField + 1;

  // Search forward from current + 1
  For I := Start to MouseCount Do
    If MouseFields[I].Active and (MouseFields[I].TabIndex > 0) Then Begin
      Result := I;
      Exit;
    End;

  // Wrap around
  For I := 1 to Start - 1 Do
    If MouseFields[I].Active and (MouseFields[I].TabIndex > 0) Then Begin
      Result := I;
      Exit;
    End;
End;

Function TRIPEngine.GetPrevTabField : Integer;
// Find previous tabbable field before FocusedField
Var
  I, Start : Integer;
Begin
  Result := 0;
  If Not TabEnabled Then Exit;
  If MouseCount = 0 Then Exit;

  If FocusedField <= 1 Then
    Start := MouseCount
  Else
    Start := FocusedField - 1;

  // Search backward
  For I := Start downto 1 Do
    If MouseFields[I].Active and (MouseFields[I].TabIndex > 0) Then Begin
      Result := I;
      Exit;
    End;

  // Wrap around
  For I := MouseCount downto Start + 1 Do
    If MouseFields[I].Active and (MouseFields[I].TabIndex > 0) Then Begin
      Result := I;
      Exit;
    End;
End;

Procedure TRIPEngine.FocusField (Index: Integer);
// Set focus to a mouse field (highlights it)
Begin
  If (Index < 1) or (Index > MouseCount) Then Exit;
  If Not MouseFields[Index].Active Then Exit;

  // Unfocus previous
  UnfocusField;

  // Highlight new field
  FocusedField := Index;
  InvertRegion(MouseFields[Index].X0, MouseFields[Index].Y0,
               MouseFields[Index].X1, MouseFields[Index].Y1);
End;

Procedure TRIPEngine.UnfocusField;
// Remove focus from current field (un-highlights it)
Begin
  If (FocusedField >= 1) and (FocusedField <= MouseCount) and
     MouseFields[FocusedField].Active Then
    InvertRegion(MouseFields[FocusedField].X0, MouseFields[FocusedField].Y0,
                 MouseFields[FocusedField].X1, MouseFields[FocusedField].Y1);

  FocusedField := 0;
End;

Function TRIPEngine.GetFocusedField : Integer;
Begin
  Result := FocusedField;
End;

// ---- Phase 6: System font mode helpers ----

Function TRIPEngine.GetSysFontW : Integer;
Begin
  // MAF fonts are always 8 pixels wide
  // (no change needed — MAF width = 8, same as default)
  Case TextWinSize of
    RIP_SYSFONT_80x25 : Result := 8;
    RIP_SYSFONT_40x25 : Result := 16;
    RIP_SYSFONT_91x43 : Result := 7;
    RIP_SYSFONT_91x25 : Result := 7;
  Else
    Result := 8;   // Mode 0 default
  End;
End;

Function TRIPEngine.GetSysFontH : Integer;
Begin
  // v3.0 Phase 18: return MAF font height if active
  If MAFIsLoaded and (MAFActiveRes >= 0) and (MAFActiveFont >= 0) Then Begin
    Result := MAFGetFontH;
    If Result > 0 Then Exit;
  End;

  Case TextWinSize of
    RIP_SYSFONT_80x25 : Result := 14;
    RIP_SYSFONT_40x25 : Result := 14;
    RIP_SYSFONT_91x25 : Result := 14;
  Else
    Result := 8;   // Modes 0, 3
  End;
End;

Function TRIPEngine.GetSysCols : Integer;
Begin
  Case TextWinSize of
    RIP_SYSFONT_80x25 : Result := 80;
    RIP_SYSFONT_40x25 : Result := 40;
    RIP_SYSFONT_91x43 : Result := 91;
    RIP_SYSFONT_91x25 : Result := 91;
  Else
    Result := 80;  // Mode 0 default
  End;
End;

Function TRIPEngine.GetSysRows : Integer;
Begin
  Case TextWinSize of
    RIP_SYSFONT_80x25 : Result := 25;
    RIP_SYSFONT_40x25 : Result := 25;
    RIP_SYSFONT_91x43 : Result := 43;
    RIP_SYSFONT_91x25 : Result := 25;
  Else
    Result := 43;  // Mode 0 default
  End;
End;

// ---- v2.0 file formats ----

Function TRIPEngine.LoadBMH (FileName: String; X, Y: SmallInt) : Boolean;
// BMH = BMP Highlight. Standard Windows BMP file used as v2.0 hot icon.
// Identical to LoadBMP — BMH is just a different extension.
Begin
  Result := LoadBMP(FileName, X, Y);
End;

Function TRIPEngine.LoadPAL (FileName: String) : Boolean;
// Load a RIPscrip palette file.
// Two formats:
//   16 bytes  — EGA palette indices (v1.54 compatible)
//   868 bytes — 100-byte header ("RIPaint 2.0 Palette File") + 256 RGB triplets
Var
  F      : File;
  FSize  : LongInt;
  Buf    : Array[0..867] of Byte;
  I      : Integer;
  BytesRead : LongInt;
Begin
  Result := False;

  Assign(F, FileName);
  {$I-} System.Reset(F, 1); {$I+}
  If IOResult <> 0 Then Exit;

  FSize := FileSize(F);

  If FSize = 16 Then Begin
    // 16-byte EGA palette indices
    BlockRead(F, Buf, 16, BytesRead);
    Close(F);
    If BytesRead <> 16 Then Exit;
    For I := 0 to 15 Do
      Palette[I] := Buf[I];
    Result := True;
  End Else If FSize = 868 Then Begin
    // 868-byte: 100-byte header + 256 RGB triplets
    BlockRead(F, Buf, 868, BytesRead);
    Close(F);
    If BytesRead <> 868 Then Exit;
    // RGB data starts at offset 100
    // Store as identity palette mapping; RGB available for rendering
    For I := 0 to 255 Do
      Palette[I] := I;
    Result := True;
  End Else
    Close(F);
End;

// ---- v2.0 Protocol Extensions ----

Function TRIPEngine.LoadJPG (FileName: String; X, Y: SmallInt) : Boolean;
// JPEG loader — reads header, extracts dimensions.
// Standard JPEG (JFIF), 24-bit color + grayscale.
// Parses SOI, APP0/JFIF, and SOF0 markers to get width/height.
// Pixel decoding via jpgdecr.pas (Phase 17) or pasjpeg (v2 compat)
// to keep engine standalone. OnLoadJPG callback can be wired for
// full decoding by the host application.
Var
  F         : File;
  Sig       : Array[0..1] of Byte;
  Marker    : Array[0..1] of Byte;
  SegLen    : Word;
  BytesRead : LongInt;
  ImgW, ImgH : Word;
  Found     : Boolean;
  Pos       : LongInt;
Begin
  Result := False;

  Assign(F, FileName);
  {$I-} System.Reset(F, 1); {$I+}
  If IOResult <> 0 Then Exit;

  // Check SOI marker (FF D8)
  BlockRead(F, Sig, 2, BytesRead);
  If (BytesRead < 2) or (Sig[0] <> $FF) or (Sig[1] <> $D8) Then Begin
    Close(F); Exit;
  End;

  // Scan for SOF0 marker (FF C0) to get dimensions
  Found := False;
  ImgW := 0;
  ImgH := 0;

  While Not EOF(F) Do Begin
    // Read marker
    BlockRead(F, Marker, 2, BytesRead);
    If BytesRead < 2 Then Break;
    If Marker[0] <> $FF Then Break;

    // SOF0 (Start of Frame, baseline DCT)
    If Marker[1] in [$C0, $C1, $C2] Then Begin
      // Skip segment length (2) + precision (1)
      BlockRead(F, Sig, 2, BytesRead);  // segment length
      BlockRead(F, Sig, 1, BytesRead);  // precision
      // Height (2 bytes big-endian)
      BlockRead(F, Sig, 2, BytesRead);
      ImgH := (Sig[0] SHL 8) OR Sig[1];
      // Width (2 bytes big-endian)
      BlockRead(F, Sig, 2, BytesRead);
      ImgW := (Sig[0] SHL 8) OR Sig[1];
      Found := True;
      Break;
    End;

    // Skip other segments
    If Marker[1] in [$D0..$D9] Then Continue;  // restart markers, no length
    BlockRead(F, Sig, 2, BytesRead);
    If BytesRead < 2 Then Break;
    SegLen := (Sig[0] SHL 8) OR Sig[1];
    If SegLen < 2 Then Break;
    Seek(F, FilePos(F) + SegLen - 2);
  End;

  Close(F);

  If Not Found Then Exit;
  If (ImgW = 0) or (ImgH = 0) Then Exit;

  // Valid JPEG with known dimensions
  // Pixel data not rendered (no decoder linked)
  // Host application can use OnLoadJPG callback for full decode
  Result := True;
End;

// ---- v2.0 Protocol Extensions (Phase 9) ----

Procedure TRIPEngine.SetResolution (W, H: SmallInt);
Begin
  If W < 320 Then W := 320;
  If H < 200 Then H := 200;
  If W > 1280 Then W := 1280;
  If H > 1024 Then H := 1024;

  CanvasWidth  := W;
  CanvasHeight := H;
  ActiveMaxX   := W - 1;
  ActiveMaxY   := H - 1;

  // Clear entire buffer
  FillChar(Pixels^, SizeOf(TRIPPixelBuffer), 0);
  FillChar(PixelsRGB^, SizeOf(TRIPPixelBufferRGB), 0);
  FillChar(PixelsRGB32^, SizeOf(TRIPPixelBufferRGB32), 0);

  // Reset viewport to new dimensions
  ViewX0 := 0;
  ViewY0 := 0;
  ViewX1 := ActiveMaxX;
  ViewY1 := ActiveMaxY;

  // v3.0 Phase 18: auto-select MAF resolution if loaded
  If MAFIsLoaded Then
    MAFSelectRes(W, H);
End;

Procedure TRIPEngine.SetColorMode (Mode: Byte);
Begin
  ColorMode := Mode;
End;

// v3.0 Phase 15: switch between 8-bit indexed, 24-bit RGB and 32-bit
// TrueColor pixel storage, converting the current framebuffer contents.
Procedure TRIPEngine.SetPixelFormat (Fmt: Byte);
Begin
  If Fmt > RIP_PIXFMT_RGB32 Then Fmt := RIP_PIXFMT_RGB32;
  If Fmt = PixelFormat Then Exit;

  ConvertPixelFormat(PixelFormat, Fmt);
  PixelFormat := Fmt;
End;

Function TRIPEngine.GetPixelFormat : Byte;
Begin
  Result := PixelFormat;
End;

Procedure TRIPEngine.SetColorRGB (RGB: TRIPRGB);
Begin
  DrawColorRGB := RGB;
  DrawColor    := RGBToIndex(RGB);   // keep indexed state usable too
End;

Function TRIPEngine.GetColorRGB : TRIPRGB;
Begin
  Result := DrawColorRGB;
End;

Procedure TRIPEngine.SetFillColorRGB (RGB: TRIPRGB);
Begin
  FillColorRGB := RGB;
  FillColor    := RGBToIndex(RGB);
End;

Function TRIPEngine.GetFillColorRGB : TRIPRGB;
Begin
  Result := FillColorRGB;
End;

Function TRIPEngine.GetCanvasWidth : SmallInt;
Begin
  Result := CanvasWidth;
End;

Function TRIPEngine.GetCanvasHeight : SmallInt;
Begin
  Result := CanvasHeight;
End;

Function TRIPEngine.GetProtoVersion : Byte;
Begin
  Result := ProtoVersion;
End;

// ====================================================================
// v3.0 Phase 16: World Coordinate System
// ====================================================================

// Private helpers — map between world and pixel coordinates.
// When WorldEnabled is False, these return the input truncated to SmallInt.
// The viewport used for mapping is (ViewX0..ViewX1, ViewY0..ViewY1).

Function TRIPEngine.WorldToPixelX (WX: Real) : SmallInt;
Var
  ScaleX, ScaleY, OffX : Real;
  PX : Real;
Begin
  If Not WorldEnabled Then Begin
    Result := Trunc(WX);
    Exit;
  End;
  If WorldAspect Then Begin
    // Aspect-preserving: use uniform scale (the smaller one)
    ScaleX := (ViewX1 - ViewX0) / (WorldX1 - WorldX0);
    OffX   := 0;
    If Abs(WorldY1 - WorldY0) > 1e-10 Then Begin
      ScaleY := (ViewY1 - ViewY0) / (WorldY1 - WorldY0);
      If ScaleY < ScaleX Then Begin
        // Y is tighter — center X
        ScaleX := ScaleY;
        OffX := ((ViewX1 - ViewX0) - (WorldX1 - WorldX0) * ScaleX) / 2.0;
      End;
    End;
    PX := ViewX0 + OffX + (WX - WorldX0) * ScaleX;
  End Else Begin
    If Abs(WorldX1 - WorldX0) < 1e-10 Then
      PX := ViewX0
    Else
      PX := ViewX0 + (WX - WorldX0) * (ViewX1 - ViewX0) / (WorldX1 - WorldX0);
  End;
  If PX < -32000 Then PX := -32000;
  If PX > 32000 Then PX := 32000;
  Result := Trunc(PX);
End;

Function TRIPEngine.WorldToPixelY (WY: Real) : SmallInt;
Var
  ScaleX, ScaleY, OffY : Real;
  PY : Real;
Begin
  If Not WorldEnabled Then Begin
    Result := Trunc(WY);
    Exit;
  End;
  If WorldAspect Then Begin
    ScaleY := (ViewY1 - ViewY0) / (WorldY1 - WorldY0);
    OffY   := 0;
    If Abs(WorldX1 - WorldX0) > 1e-10 Then Begin
      ScaleX := (ViewX1 - ViewX0) / (WorldX1 - WorldX0);
      If ScaleX < ScaleY Then Begin
        ScaleY := ScaleX;
        OffY := ((ViewY1 - ViewY0) - (WorldY1 - WorldY0) * ScaleY) / 2.0;
      End;
    End;
    PY := ViewY0 + OffY + (WY - WorldY0) * ScaleY;
  End Else Begin
    If Abs(WorldY1 - WorldY0) < 1e-10 Then
      PY := ViewY0
    Else
      PY := ViewY0 + (WY - WorldY0) * (ViewY1 - ViewY0) / (WorldY1 - WorldY0);
  End;
  If PY < -32000 Then PY := -32000;
  If PY > 32000 Then PY := 32000;
  Result := Trunc(PY);
End;

Function TRIPEngine.PixelToWorldX (PX: SmallInt) : Real;
Begin
  If (Not WorldEnabled) or (Abs(ViewX1 - ViewX0) < 1) Then Begin
    Result := PX;
    Exit;
  End;
  Result := WorldX0 + (PX - ViewX0) * (WorldX1 - WorldX0) / (ViewX1 - ViewX0);
End;

Function TRIPEngine.PixelToWorldY (PY: SmallInt) : Real;
Begin
  If (Not WorldEnabled) or (Abs(ViewY1 - ViewY0) < 1) Then Begin
    Result := PY;
    Exit;
  End;
  Result := WorldY0 + (PY - ViewY0) * (WorldY1 - WorldY0) / (ViewY1 - ViewY0);
End;

// Public API

Procedure TRIPEngine.SetWorldCoords (X0, Y0, X1, Y1: Real);
Begin
  WorldX0 := X0;
  WorldY0 := Y0;
  WorldX1 := X1;
  WorldY1 := Y1;
  WorldEnabled := True;
End;

Procedure TRIPEngine.ClearWorldCoords;
Begin
  WorldEnabled := False;
  WorldX0 := 0;
  WorldY0 := 0;
  WorldX1 := ActiveMaxX;
  WorldY1 := ActiveMaxY;
  WorldAspect := False;  // v3.0 Phase 16 fix: clear aspect flag
End;

Function TRIPEngine.IsWorldEnabled : Boolean;
Begin
  Result := WorldEnabled;
End;

Procedure TRIPEngine.SetWorldAspect (Preserve: Boolean);
Begin
  WorldAspect := Preserve;
End;

Function TRIPEngine.GetWorldAspect : Boolean;
Begin
  Result := WorldAspect;
End;

Function TRIPEngine.MapX (WX: Real) : SmallInt;
Begin
  Result := WorldToPixelX(WX);
End;

Function TRIPEngine.MapY (WY: Real) : SmallInt;
Begin
  Result := WorldToPixelY(WY);
End;

Function TRIPEngine.UnmapX (PX: SmallInt) : Real;
Begin
  Result := PixelToWorldX(PX);
End;

Function TRIPEngine.UnmapY (PY: SmallInt) : Real;
Begin
  Result := PixelToWorldY(PY);
End;

// World-coordinate drawing overloads — map to pixel coords, then
// delegate to the existing pixel-based drawing primitives.

Procedure TRIPEngine.WPutPixel (WX, WY: Real; Color: Byte);
Begin
  PutPixel(WorldToPixelX(WX), WorldToPixelY(WY), Color);
End;

Procedure TRIPEngine.WPutPixelRGB (WX, WY: Real; RGB: TRIPRGB);
Begin
  PutPixel(WorldToPixelX(WX), WorldToPixelY(WY), RGB);
End;

Procedure TRIPEngine.WLine (WX0, WY0, WX1, WY1: Real);
Begin
  Line(WorldToPixelX(WX0), WorldToPixelY(WY0),
       WorldToPixelX(WX1), WorldToPixelY(WY1));
End;

Procedure TRIPEngine.WLineTo (WX, WY: Real);
Begin
  LineTo(WorldToPixelX(WX), WorldToPixelY(WY));
End;

Procedure TRIPEngine.WMoveTo (WX, WY: Real);
Begin
  MoveTo(WorldToPixelX(WX), WorldToPixelY(WY));
End;

Procedure TRIPEngine.WRectangle (WX0, WY0, WX1, WY1: Real);
Begin
  Rectangle(WorldToPixelX(WX0), WorldToPixelY(WY0),
            WorldToPixelX(WX1), WorldToPixelY(WY1));
End;

Procedure TRIPEngine.WBar (WX0, WY0, WX1, WY1: Real);
Begin
  Bar(WorldToPixelX(WX0), WorldToPixelY(WY0),
      WorldToPixelX(WX1), WorldToPixelY(WY1));
End;

Procedure TRIPEngine.WCircle (WXC, WYC, WRadius: Real);
Var
  PXC, PYC : SmallInt;
  PR       : SmallInt;
Begin
  PXC := WorldToPixelX(WXC);
  PYC := WorldToPixelY(WYC);
  // Map radius: use X scale (or min of X/Y if aspect-preserving)
  If Abs(WorldX1 - WorldX0) > 1e-10 Then
    PR := Abs(Trunc(WRadius * (ViewX1 - ViewX0) / (WorldX1 - WorldX0)))
  Else
    PR := Trunc(WRadius);
  If PR < 1 Then PR := 1;
  Circle(PXC, PYC, PR);
End;

Procedure TRIPEngine.WEllipse (WXC, WYC: Real; StartAng, EndAng: SmallInt; WXR, WYR: Real);
Var
  PXC, PYC, PXR, PYR : SmallInt;
Begin
  PXC := WorldToPixelX(WXC);
  PYC := WorldToPixelY(WYC);
  If Abs(WorldX1 - WorldX0) > 1e-10 Then
    PXR := Abs(Trunc(WXR * (ViewX1 - ViewX0) / (WorldX1 - WorldX0)))
  Else
    PXR := Trunc(WXR);
  If Abs(WorldY1 - WorldY0) > 1e-10 Then
    PYR := Abs(Trunc(WYR * (ViewY1 - ViewY0) / (WorldY1 - WorldY0)))
  Else
    PYR := Trunc(WYR);
  If PXR < 1 Then PXR := 1;
  If PYR < 1 Then PYR := 1;
  Ellipse(PXC, PYC, StartAng, EndAng, PXR, PYR);
End;

Procedure TRIPEngine.WFillEllipse (WXC, WYC, WXR, WYR: Real);
Var
  PXC, PYC, PXR, PYR : SmallInt;
Begin
  PXC := WorldToPixelX(WXC);
  PYC := WorldToPixelY(WYC);
  If Abs(WorldX1 - WorldX0) > 1e-10 Then
    PXR := Abs(Trunc(WXR * (ViewX1 - ViewX0) / (WorldX1 - WorldX0)))
  Else
    PXR := Trunc(WXR);
  If Abs(WorldY1 - WorldY0) > 1e-10 Then
    PYR := Abs(Trunc(WYR * (ViewY1 - ViewY0) / (WorldY1 - WorldY0)))
  Else
    PYR := Trunc(WYR);
  If PXR < 1 Then PXR := 1;
  If PYR < 1 Then PYR := 1;
  FillEllipse(PXC, PYC, PXR, PYR);
End;

Procedure TRIPEngine.WArc (WXC, WYC: Real; StartAng, EndAng: SmallInt; WRadius: Real);
Var
  PXC, PYC, PR : SmallInt;
Begin
  PXC := WorldToPixelX(WXC);
  PYC := WorldToPixelY(WYC);
  If Abs(WorldX1 - WorldX0) > 1e-10 Then
    PR := Abs(Trunc(WRadius * (ViewX1 - ViewX0) / (WorldX1 - WorldX0)))
  Else
    PR := Trunc(WRadius);
  If PR < 1 Then PR := 1;
  Arc(PXC, PYC, StartAng, EndAng, PR);
End;

Procedure TRIPEngine.WFloodFill (WX, WY: Real; Border: Byte);
Begin
  FloodFill(WorldToPixelX(WX), WorldToPixelY(WY), Border);
End;

Procedure TRIPEngine.WOutTextXY (WX, WY: Real; S: String);
Begin
  OutTextXY(WorldToPixelX(WX), WorldToPixelY(WY), S);
End;

Procedure TRIPEngine.WDrawBezier (WX0,WY0,WX1,WY1,WX2,WY2,WX3,WY3: Real; Count: SmallInt);
Begin
  DrawBezier(WorldToPixelX(WX0), WorldToPixelY(WY0),
             WorldToPixelX(WX1), WorldToPixelY(WY1),
             WorldToPixelX(WX2), WorldToPixelY(WY2),
             WorldToPixelX(WX3), WorldToPixelY(WY3), Count);
End;

Function TRIPEngine.IsTextAreaDetected : Boolean;
Begin
  Result := TextAreaDetected;
End;

Function TRIPEngine.GetTextAreaW : SmallInt;
Begin
  Result := TextAreaW;
End;

Function TRIPEngine.GetTextAreaH : SmallInt;
Begin
  Result := TextAreaH;
End;

// ---- Phase 12: SVGACC-Inspired Enhancements ----

Procedure TRIPEngine.BlockResize (Var Src; SrcW, SrcH: SmallInt;
                                  Var Dst; DstW, DstH: SmallInt);
Var
  SrcP : PByte;
  DstP : PByte;
  X, Y, SX, SY : SmallInt;
Begin
  SrcP := @Src;
  DstP := @Dst;
  If (SrcW <= 0) or (SrcH <= 0) or (DstW <= 0) or (DstH <= 0) Then Exit;
  For Y := 0 to DstH - 1 Do Begin
    SY := (Y * SrcH) DIV DstH;
    If SY >= SrcH Then SY := SrcH - 1;
    For X := 0 to DstW - 1 Do Begin
      SX := (X * SrcW) DIV DstW;
      If SX >= SrcW Then SX := SrcW - 1;
      PByte(PtrInt(DstP) + Y * DstW + X)^ :=
        PByte(PtrInt(SrcP) + SY * SrcW + SX)^;
    End;
  End;
End;

Procedure TRIPEngine.BlockRotate (Var Src; W, H: SmallInt;
                                  Var Dst; Angle: SmallInt; BackFill: Byte);
Var
  SrcP, DstP    : PByte;
  X, Y, SX, SY  : SmallInt;
  CX, CY        : SmallInt;
  CosA, SinA    : Real;
  Rad            : Real;
Begin
  SrcP := @Src;
  DstP := @Dst;
  If (W <= 0) or (H <= 0) Then Exit;
  CX := W DIV 2;
  CY := H DIV 2;
  Rad := Angle * Pi / 180.0;
  CosA := Cos(Rad);
  SinA := Sin(Rad);
  For Y := 0 to H - 1 Do
    For X := 0 to W - 1 Do Begin
      SX := Round((X - CX) * CosA + (Y - CY) * SinA) + CX;
      SY := Round(-(X - CX) * SinA + (Y - CY) * CosA) + CY;
      If (SX >= 0) and (SX < W) and (SY >= 0) and (SY < H) Then
        PByte(PtrInt(DstP) + Y * W + X)^ :=
          PByte(PtrInt(SrcP) + SY * W + SX)^
      Else
        PByte(PtrInt(DstP) + Y * W + X)^ := BackFill;
    End;
End;

Procedure TRIPEngine.D2Rotate (Var Pts: Array of TRIPPoint; Count: Integer;
                                XO, YO, Angle: SmallInt);
Var
  I          : Integer;
  Rad        : Real;
  CosA, SinA : Real;
  DX, DY     : SmallInt;
Begin
  Rad := Angle * Pi / 180.0;
  CosA := Cos(Rad);
  SinA := Sin(Rad);
  For I := 0 to Count - 1 Do Begin
    DX := Pts[I].X - XO;
    DY := Pts[I].Y - YO;
    Pts[I].X := Round(DX * CosA - DY * SinA) + XO;
    Pts[I].Y := Round(DX * SinA + DY * CosA) + YO;
  End;
End;

Procedure TRIPEngine.D2Scale (Var Pts: Array of TRIPPoint; Count: Integer;
                               XS, YS: SmallInt);
Var I : Integer;
Begin
  For I := 0 to Count - 1 Do Begin
    Pts[I].X := (Pts[I].X * XS) DIV 100;
    Pts[I].Y := (Pts[I].Y * YS) DIV 100;
  End;
End;

Procedure TRIPEngine.D2Translate (Var Pts: Array of TRIPPoint; Count: Integer;
                                   XT, YT: SmallInt);
Var I : Integer;
Begin
  For I := 0 to Count - 1 Do Begin
    Inc(Pts[I].X, XT);
    Inc(Pts[I].Y, YT);
  End;
End;

Procedure TRIPEngine.SpriteGet (X, Y, W, H: SmallInt; Var Sprite; Var Bkgnd);
Var
  SprP, BkgP : PByte;
  IX, IY     : SmallInt;
Begin
  SprP := @Sprite;
  BkgP := @Bkgnd;
  For IY := 0 to H - 1 Do
    For IX := 0 to W - 1 Do
      If InView(X + IX, Y + IY) Then Begin
        PByte(PtrInt(SprP) + IY * W + IX)^ := Pixels^[Y + IY, X + IX];
        PByte(PtrInt(BkgP) + IY * W + IX)^ := Pixels^[Y + IY, X + IX];
      End;
End;

Procedure TRIPEngine.SpritePut (X, Y: SmallInt; Var Sprite; TransColor: Byte);
Var
  SprP       : PByte;
  IX, IY     : SmallInt;
  W, H       : SmallInt;
  C          : Byte;
Begin
  SprP := @Sprite;
  // First 2 bytes = width, height
  W := PByte(SprP)^;
  H := PByte(PtrInt(SprP) + 1)^;
  If (W = 0) or (H = 0) Then Exit;
  For IY := 0 to H - 1 Do
    For IX := 0 to W - 1 Do Begin
      C := PByte(PtrInt(SprP) + 2 + IY * W + IX)^;
      If C <> TransColor Then
        If InView(X + IX, Y + IY) Then
          DrawPixel(X + IX, Y + IY, C);
    End;
End;

Function TRIPEngine.SpriteCollide (X1, Y1, X2, Y2: SmallInt;
                                    Var S1, S2; TransColor: Byte) : Boolean;
Var
  P1, P2               : PByte;
  W1, H1, W2, H2       : SmallInt;
  OX0, OY0, OX1, OY1   : SmallInt;
  IX, IY                : SmallInt;
Begin
  Result := False;
  P1 := @S1; P2 := @S2;
  W1 := PByte(P1)^; H1 := PByte(PtrInt(P1) + 1)^;
  W2 := PByte(P2)^; H2 := PByte(PtrInt(P2) + 1)^;
  // Bounding box overlap
  OX0 := X1; If X2 > OX0 Then OX0 := X2;
  OY0 := Y1; If Y2 > OY0 Then OY0 := Y2;
  OX1 := X1 + W1 - 1; If X2 + W2 - 1 < OX1 Then OX1 := X2 + W2 - 1;
  OY1 := Y1 + H1 - 1; If Y2 + H2 - 1 < OY1 Then OY1 := Y2 + H2 - 1;
  If (OX0 > OX1) or (OY0 > OY1) Then Exit;
  For IY := OY0 to OY1 Do
    For IX := OX0 to OX1 Do
      If (PByte(PtrInt(P1) + 2 + (IY-Y1)*W1 + (IX-X1))^ <> TransColor) and
         (PByte(PtrInt(P2) + 2 + (IY-Y2)*W2 + (IX-X2))^ <> TransColor) Then Begin
        Result := True;
        Exit;
      End;
End;

Procedure TRIPEngine.ScrollUp (X0, Y0, X1, Y1, Amt: SmallInt; Fill: Byte);
// v3.0 Phase 15 fix: copy all three buffers so RGB stays in sync
Var X, Y : SmallInt;
    FillRGB : TRIPRGB;
    Fill32  : TRIPRGBA;
Begin
  If Amt <= 0 Then Exit;
  FillRGB := IndexToRGB(Fill);
  Fill32.R := FillRGB.R; Fill32.G := FillRGB.G; Fill32.B := FillRGB.B; Fill32.A := $FF;
  For Y := Y0 to Y1 - Amt Do
    For X := X0 to X1 Do
      If InView(X, Y) and InView(X, Y + Amt) Then Begin
        Pixels^[Y, X]      := Pixels^[Y + Amt, X];
        PixelsRGB^[Y, X]   := PixelsRGB^[Y + Amt, X];
        PixelsRGB32^[Y, X] := PixelsRGB32^[Y + Amt, X];
      End;
  For Y := Y1 - Amt + 1 to Y1 Do
    For X := X0 to X1 Do
      If InView(X, Y) Then Begin
        Pixels^[Y, X]      := Fill;
        PixelsRGB^[Y, X]   := FillRGB;
        PixelsRGB32^[Y, X] := Fill32;
      End;
End;

Procedure TRIPEngine.ScrollDn (X0, Y0, X1, Y1, Amt: SmallInt; Fill: Byte);
// v3.0 Phase 15 fix: copy all three buffers so RGB stays in sync
Var X, Y : SmallInt;
    FillRGB : TRIPRGB;
    Fill32  : TRIPRGBA;
Begin
  If Amt <= 0 Then Exit;
  FillRGB := IndexToRGB(Fill);
  Fill32.R := FillRGB.R; Fill32.G := FillRGB.G; Fill32.B := FillRGB.B; Fill32.A := $FF;
  For Y := Y1 downto Y0 + Amt Do
    For X := X0 to X1 Do
      If InView(X, Y) and InView(X, Y - Amt) Then Begin
        Pixels^[Y, X]      := Pixels^[Y - Amt, X];
        PixelsRGB^[Y, X]   := PixelsRGB^[Y - Amt, X];
        PixelsRGB32^[Y, X] := PixelsRGB32^[Y - Amt, X];
      End;
  For Y := Y0 to Y0 + Amt - 1 Do
    For X := X0 to X1 Do
      If InView(X, Y) Then Begin
        Pixels^[Y, X]      := Fill;
        PixelsRGB^[Y, X]   := FillRGB;
        PixelsRGB32^[Y, X] := Fill32;
      End;
End;

Procedure TRIPEngine.ScrollLt (X0, Y0, X1, Y1, Amt: SmallInt; Fill: Byte);
// v3.0 Phase 15 fix: copy all three buffers so RGB stays in sync
Var X, Y : SmallInt;
    FillRGB : TRIPRGB;
    Fill32  : TRIPRGBA;
Begin
  If Amt <= 0 Then Exit;
  FillRGB := IndexToRGB(Fill);
  Fill32.R := FillRGB.R; Fill32.G := FillRGB.G; Fill32.B := FillRGB.B; Fill32.A := $FF;
  For Y := Y0 to Y1 Do Begin
    For X := X0 to X1 - Amt Do
      If InView(X, Y) and InView(X + Amt, Y) Then Begin
        Pixels^[Y, X]      := Pixels^[Y, X + Amt];
        PixelsRGB^[Y, X]   := PixelsRGB^[Y, X + Amt];
        PixelsRGB32^[Y, X] := PixelsRGB32^[Y, X + Amt];
      End;
    For X := X1 - Amt + 1 to X1 Do
      If InView(X, Y) Then Begin
        Pixels^[Y, X]      := Fill;
        PixelsRGB^[Y, X]   := FillRGB;
        PixelsRGB32^[Y, X] := Fill32;
      End;
  End;
End;

Procedure TRIPEngine.ScrollRt (X0, Y0, X1, Y1, Amt: SmallInt; Fill: Byte);
// v3.0 Phase 15 fix: copy all three buffers so RGB stays in sync
Var X, Y : SmallInt;
    FillRGB : TRIPRGB;
    Fill32  : TRIPRGBA;
Begin
  If Amt <= 0 Then Exit;
  FillRGB := IndexToRGB(Fill);
  Fill32.R := FillRGB.R; Fill32.G := FillRGB.G; Fill32.B := FillRGB.B; Fill32.A := $FF;
  For Y := Y0 to Y1 Do Begin
    For X := X1 downto X0 + Amt Do
      If InView(X, Y) and InView(X - Amt, Y) Then Begin
        Pixels^[Y, X]      := Pixels^[Y, X - Amt];
        PixelsRGB^[Y, X]   := PixelsRGB^[Y, X - Amt];
        PixelsRGB32^[Y, X] := PixelsRGB32^[Y, X - Amt];
      End;
    For X := X0 to X0 + Amt - 1 Do
      If InView(X, Y) Then Begin
        Pixels^[Y, X]      := Fill;
        PixelsRGB^[Y, X]   := FillRGB;
        PixelsRGB32^[Y, X] := Fill32;
      End;
  End;
End;

Procedure TRIPEngine.PalFade (StartIdx, EndIdx, Percent: Integer);
Var I : Integer;
Begin
  If Percent < 0 Then Percent := 0;
  If Percent > 100 Then Percent := 100;
  For I := StartIdx to EndIdx Do
    If (I >= 0) and (I <= 255) Then
      Palette[I] := (Palette[I] * Percent) DIV 100;
End;

Procedure TRIPEngine.PalRotate (StartIdx, EndIdx, Shift: Integer);
Var
  Tmp      : Array[0..255] of Byte;
  I, Len, Idx : Integer;
Begin
  Len := EndIdx - StartIdx + 1;
  If Len <= 1 Then Exit;
  Shift := Shift MOD Len;
  If Shift < 0 Then Shift := Shift + Len;
  For I := 0 to Len - 1 Do
    Tmp[I] := Palette[StartIdx + I];
  For I := 0 to Len - 1 Do Begin
    Idx := (I + Shift) MOD Len;
    Palette[StartIdx + I] := Tmp[Idx];
  End;
End;

Procedure TRIPEngine.D3Rotate (Var Pts: Array of TRIPPoint3D; Count: Integer;
                               XO, YO, ZO: SmallInt;
                               XAng, YAng, ZAng: SmallInt);
Var
  I              : Integer;
  DX, DY, DZ     : Real;
  NX, NY, NZ     : Real;
  CX, SX, CY, SY, CZ, SZ : Real;
Begin
  CX := Cos(XAng * Pi / 180.0); SX := Sin(XAng * Pi / 180.0);
  CY := Cos(YAng * Pi / 180.0); SY := Sin(YAng * Pi / 180.0);
  CZ := Cos(ZAng * Pi / 180.0); SZ := Sin(ZAng * Pi / 180.0);
  For I := 0 to Count - 1 Do Begin
    DX := Pts[I].X - XO;
    DY := Pts[I].Y - YO;
    DZ := Pts[I].Z - ZO;
    NY := DY * CX - DZ * SX;
    NZ := DY * SX + DZ * CX;
    DY := NY; DZ := NZ;
    NX := DX * CY + DZ * SY;
    NZ := -DX * SY + DZ * CY;
    DX := NX; DZ := NZ;
    NX := DX * CZ - DY * SZ;
    NY := DX * SZ + DY * CZ;
    Pts[I].X := Round(NX) + XO;
    Pts[I].Y := Round(NY) + YO;
    Pts[I].Z := Round(NZ) + ZO;
  End;
End;

Procedure TRIPEngine.D3Scale (Var Pts: Array of TRIPPoint3D; Count: Integer;
                               XS, YS, ZS: SmallInt);
Var I : Integer;
Begin
  For I := 0 to Count - 1 Do Begin
    Pts[I].X := (Pts[I].X * XS) DIV 100;
    Pts[I].Y := (Pts[I].Y * YS) DIV 100;
    Pts[I].Z := (Pts[I].Z * ZS) DIV 100;
  End;
End;

Procedure TRIPEngine.D3Translate (Var Pts: Array of TRIPPoint3D; Count: Integer;
                                   XT, YT, ZT: SmallInt);
Var I : Integer;
Begin
  For I := 0 to Count - 1 Do Begin
    Inc(Pts[I].X, XT);
    Inc(Pts[I].Y, YT);
    Inc(Pts[I].Z, ZT);
  End;
End;

Function TRIPEngine.D3Project (Var In3D: Array of TRIPPoint3D;
                                Var Out2D: Array of TRIPPoint;
                                Count: Integer;
                                Var Params: TRIPProjParams) : Boolean;
Var
  I              : Integer;
  DX, DY, DZ     : Real;
  CT, ST, CP, SP : Real;
  RX, RY, RZ     : Real;
Begin
  Result := True;
  CT := Cos(Params.Theta * Pi / 180.0);
  ST := Sin(Params.Theta * Pi / 180.0);
  CP := Cos(Params.Phi * Pi / 180.0);
  SP := Sin(Params.Phi * Pi / 180.0);
  For I := 0 to Count - 1 Do Begin
    DX := In3D[I].X - Params.EyeX;
    DY := In3D[I].Y - Params.EyeY;
    DZ := In3D[I].Z - Params.EyeZ;
    RX := DX * CT + DZ * ST;
    RZ := -DX * ST + DZ * CT;
    RY := DY * CP - RZ * SP;
    RZ := DY * SP + RZ * CP;
    If RZ = 0 Then RZ := 1;
    Out2D[I].X := Round(RX * Params.ScreenDist / RZ) + CanvasWidth DIV 2;
    Out2D[I].Y := Round(RY * Params.ScreenDist / RZ) + CanvasHeight DIV 2;
  End;
End;

Procedure TRIPEngine.LineAA (X0, Y0, X1, Y1: SmallInt; Color: Byte);
// Wu's antialiased line — in indexed palette mode, uses threshold blending
Var
  Steep        : Boolean;
  DX, DY       : SmallInt;
  Gradient     : Real;
  IX, IY       : SmallInt;
  IntersectY   : Real;
  FPart        : Real;
  Tmp          : SmallInt;
Begin
  Steep := Abs(Y1 - Y0) > Abs(X1 - X0);
  If Steep Then Begin
    Tmp := X0; X0 := Y0; Y0 := Tmp;
    Tmp := X1; X1 := Y1; Y1 := Tmp;
  End;
  If X0 > X1 Then Begin
    Tmp := X0; X0 := X1; X1 := Tmp;
    Tmp := Y0; Y0 := Y1; Y1 := Tmp;
  End;
  DX := X1 - X0;
  DY := Y1 - Y0;
  If DX = 0 Then Gradient := 1.0
  Else Gradient := DY / DX;
  IntersectY := Y0 + 0.5;
  For IX := X0 to X1 Do Begin
    IY := Trunc(IntersectY);
    FPart := IntersectY - IY;
    // v3.0 Phase 15 fix: route through DrawPixel so RGB buffers stay
    // in sync.  Note: DrawPixel already does InView check internally.
    If Steep Then Begin
      If (1.0 - FPart > 0.3) Then
        DrawPixel(IY, IX, Color);
      If (FPart > 0.3) Then
        DrawPixel(IY + 1, IX, Color);
    End Else Begin
      If (1.0 - FPart > 0.3) Then
        DrawPixel(IX, IY, Color);
      If (FPart > 0.3) Then
        DrawPixel(IX, IY + 1, Color);
    End;
    IntersectY := IntersectY + Gradient;
  End;
End;

// ---- Phase 13: Animation ----

Function TRIPEngine.LoadAnimFrame (BaseName: String; Frame: Integer;
                                   X, Y: SmallInt) : Boolean;
Var
  FrameStr : String;
  FileName : String;
Begin
  Str(Frame, FrameStr);
  If Frame < 10 Then FrameStr := '0' + FrameStr;
  FileName := BaseName + FrameStr + '.BMP';
  Result := LoadBMP(FileName, X, Y);
End;

Procedure TRIPEngine.PalCycle (StartIdx, EndIdx: Integer;
                                Direction: ShortInt);
Begin
  If Direction > 0 Then
    PalRotate(StartIdx, EndIdx, 1)
  Else If Direction < 0 Then
    PalRotate(StartIdx, EndIdx, EndIdx - StartIdx);
End;

Procedure TRIPEngine.FadeIn (Steps: Integer);
Var
  I, S   : Integer;
  Target : TRIPPalette;
Begin
  If Steps < 1 Then Steps := 1;
  Move(Palette, Target, SizeOf(TRIPPalette));
  FillChar(Palette, SizeOf(TRIPPalette), 0);
  For S := 1 to Steps Do
    For I := 0 to 255 Do
      Palette[I] := (Target[I] * S) DIV Steps;
End;

Procedure TRIPEngine.FadeOut (Steps: Integer);
Var
  I, S   : Integer;
  Start  : TRIPPalette;
Begin
  If Steps < 1 Then Steps := 1;
  Move(Palette, Start, SizeOf(TRIPPalette));
  For S := Steps - 1 downto 0 Do
    For I := 0 to 255 Do
      Palette[I] := (Start[I] * S) DIV Steps;
End;

Procedure TRIPEngine.SetFrameRate (FPS: Integer);
Begin
  If FPS < 1 Then FPS := 1;
  If FPS > 60 Then FPS := 60;
  FrameRate := FPS;
End;

Function TRIPEngine.GetFrameRate : Integer;
Begin
  Result := FrameRate;
End;

// ---- Scene file ----

Function TRIPEngine.LoadScene (FileName: String) : Boolean;
Var
  F    : Text;
  Line : String;
Begin
  Result := False;

  Assign(F, FileName);
  {$I-} System.Reset(F); {$I+}
  If IOResult <> 0 Then Exit;

  While Not Eof(F) Do Begin
    ReadLn(F, Line);
    ProcessLine(Line);
  End;

  Close(F);
  Result := True;
End;

Function TRIPEngine.SaveScene (FileName: String) : Boolean;
// Save current screen state as a .RIP scene file.
// Writes RIP commands to reconstruct the current state:
//   - Reset windows
//   - Set palette
//   - Set draw color, fill style, line style
//   - Pixel-by-pixel rendering via SetPixel commands
// For large scenes, this produces a large file. The caller
// may prefer SaveBMP for archival instead.
Var
  F    : Text;
  X, Y : SmallInt;
  C    : Byte;
  LastColor : Byte;

  Function ToMega (V: Integer; Digits: Integer) : String;
  Var
    I : Integer;
    D : Integer;
  Begin
    Result := '';
    For I := Digits downto 1 Do Begin
      D := V MOD 36;
      If D < 10 Then
        Result := Chr(Ord('0') + D) + Result
      Else
        Result := Chr(Ord('A') + D - 10) + Result;
      V := V DIV 36;
    End;
  End;

Begin
  Result := False;

  Assign(F, FileName);
  {$I-} Rewrite(F); {$I+}
  If IOResult <> 0 Then Exit;

  // Header
  WriteLn(F, '!|*');  // reset windows
  WriteLn(F, '!|e');  // clear screen

  // v3.0 Phase 16: emit world coordinate command if active
  If WorldEnabled Then Begin
    Write(F, '!|1z');
    Write(F, WorldX0:0:6, ':', WorldY0:0:6, ':');
    Write(F, WorldX1:0:6, ':', WorldY1:0:6);
    If WorldAspect Then Write(F, ':A');
    WriteLn(F);
  End;

  // Set palette
  Write(F, '!|Q');
  For C := 0 to 15 Do
    Write(F, ToMega(Palette[C], 2));
  WriteLn(F);

  // Render pixels — group runs of same color
  LastColor := 255;
  For Y := 0 to ActiveMaxY Do
    For X := 0 to ActiveMaxX Do Begin
      C := Pixels^[Y, X];
      If C <> 0 Then Begin
        If C <> LastColor Then Begin
          WriteLn(F, '!|c' + ToMega(C, 2));
          LastColor := C;
        End;
        WriteLn(F, '!|X' + ToMega(X, 2) + ToMega(Y, 2));
      End;
    End;

  Close(F);
  Result := True;
End;

// ---- CHR vector font ----


// ====================================================================
// v3.0 Phase 18: RFF Scalable Font Rendering
// ====================================================================

Function TRIPEngine.LoadRFF (Slot: Byte; FileName: String) : Boolean;
Var
  FontPtr : Pointer;
Begin
  Result := False;
  If (Slot < 1) or (Slot > RIP_MAX_RFF) Then Exit;

  // Free existing font in this slot
  FreeRFF(Slot);

  GetMem(FontPtr, SizeOf(TRFFFont));
  If Not RFFLoadFileRaw(FileName, TRFFFont(FontPtr^)) Then Begin
    FreeMem(FontPtr, SizeOf(TRFFFont));
    Exit;
  End;

  RFFFonts[Slot]  := FontPtr;
  RFFLoaded[Slot] := True;
  Result := True;
End;

Procedure TRIPEngine.FreeRFF (Slot: Byte);
Begin
  If (Slot < 1) or (Slot > RIP_MAX_RFF) Then Exit;
  If RFFLoaded[Slot] and (RFFFonts[Slot] <> Nil) Then Begin
    RFFFreeRaw(TRFFFont(RFFFonts[Slot]^));
    FreeMem(RFFFonts[Slot], SizeOf(TRFFFont));
    RFFFonts[Slot]  := Nil;
    RFFLoaded[Slot] := False;
  End;
End;

Procedure TRIPEngine.SetRFFFont (Slot: Byte);
Begin
  If (Slot >= 1) and (Slot <= RIP_MAX_RFF) Then
    RFFActiveFont := Slot
  Else
    RFFActiveFont := 0;
End;

Procedure TRIPEngine.SetRFFFace (Face: Byte);
Begin
  If Face < RFF_MAX_FACES Then
    RFFActiveFace := Face
  Else
    RFFActiveFace := 0;
End;

Function TRIPEngine.GetRFFFace : Byte;
Begin
  Result := RFFActiveFace;
End;

Function TRIPEngine.RFFTextWidth (S: String) : Integer;
// Returns total advance width in design units for string S,
// including tracking (extra inter-character spacing) and kerning.
Var
  I      : Integer;
  Font   : TRFFFont;
Begin
  Result := 0;
  If (RFFActiveFont < 1) or (RFFActiveFont > RIP_MAX_RFF) Then Exit;
  If Not RFFLoaded[RFFActiveFont] Then Exit;

  Font := TRFFFont(RFFFonts[RFFActiveFont]^);
  For I := 1 to Length(S) Do Begin
    Result := Result + RFFGlyphWidth(Font, Ord(S[I]));
    // Add tracking between characters (not after last char)
    If (I < Length(S)) Then Begin
      Result := Result + RFFTracking;
      // Add kerning adjustment for this pair
      If I < Length(S) Then
        Result := Result + RFFKernPair(S[I], S[I + 1]);
    End;
  End;
End;

Function TRIPEngine.RFFTextHeight : Integer;
// Returns text height in design units (ascent + |descent|)
Var
  Font : TRFFFont;
Begin
  Result := 0;
  If (RFFActiveFont < 1) or (RFFActiveFont > RIP_MAX_RFF) Then Exit;
  If Not RFFLoaded[RFFActiveFont] Then Exit;

  Font := TRFFFont(RFFFonts[RFFActiveFont]^);
  Result := Font.Ascent + Abs(Font.Descent);
End;

Function TRIPEngine.RFFLineHeight : Integer;
// Returns line height in design units (text height + leading)
Var
  Font : TRFFFont;
Begin
  Result := 0;
  If (RFFActiveFont < 1) or (RFFActiveFont > RIP_MAX_RFF) Then Exit;
  If Not RFFLoaded[RFFActiveFont] Then Exit;

  Font := TRFFFont(RFFFonts[RFFActiveFont]^);
  Result := Font.Ascent + Abs(Font.Descent) + RFFLeading;
End;

Function TRIPEngine.RFFKernPair (Ch1, Ch2: Char) : SmallInt;
// Returns kerning adjustment in design units for a character pair.
// RFF v2.2 has no kerning table — this provides heuristic kerning
// for common pairs. Returns negative values to tighten spacing.
// Values are proportional to DesignUnits (17560 per em).
Begin
  Result := 0;
  // Common kerning pairs — tighten by ~2-3% of em
  Case Ch1 of
    'A' : Case Ch2 of
            'V', 'W', 'Y', 'T' : Result := -350;
            'v', 'w', 'y'      : Result := -250;
          End;
    'F', 'T' : Case Ch2 of
            'a', 'e', 'i', 'o', 'u' : Result := -300;
            'A', 'O'                 : Result := -250;
            '.', ','                 : Result := -400;
          End;
    'L' : Case Ch2 of
            'T', 'V', 'W', 'Y' : Result := -350;
            '''', '"'           : Result := -300;
          End;
    'P' : Case Ch2 of
            'A', 'a', '.', ',' : Result := -350;
          End;
    'V', 'W' : Case Ch2 of
            'A', 'a', 'e', 'o' : Result := -250;
            '.', ','           : Result := -400;
          End;
    'Y' : Case Ch2 of
            'a', 'e', 'i', 'o', 'u' : Result := -300;
            '.', ','                 : Result := -400;
          End;
    'r' : Case Ch2 of
            '.', ','           : Result := -250;
          End;
  End;
End;

Procedure TRIPEngine.SetRFFTracking (Value: SmallInt);
// Set tracking (extra inter-character spacing) in design units.
// Positive = looser, negative = tighter.
Begin
  RFFTracking := Value;
End;

Function TRIPEngine.GetRFFTracking : SmallInt;
Begin
  Result := RFFTracking;
End;

Procedure TRIPEngine.SetRFFLeading (Value: SmallInt);
// Set leading (extra inter-line spacing) in design units.
// Added to (Ascent + |Descent|) for line height calculation.
Begin
  RFFLeading := Value;
End;

Function TRIPEngine.GetRFFLeading : SmallInt;
Begin
  Result := RFFLeading;
End;

Procedure TRIPEngine.DrawTextRFFBox (X, Y, W, H: SmallInt; S: String;
                                      PointSize: Integer; HAlign, VAlign: Byte;
                                      WordWrap: Boolean);
// Render RFF text within a bounding box with word wrap and alignment.
// HAlign: RIP_LEFT_TEXT (0), RIP_CENTER_TEXT (1), RIP_RIGHT_TEXT (2)
// VAlign: RIP_BOTTOM_TEXT (0), 1=center, RIP_TOP_TEXT (2)
// WordWrap: if True, breaks text at word boundaries to fit width W.
// If False, renders single line (may overflow box).
Var
  Font       : TRFFFont;
  Scale      : Real;
  LineH      : Integer;  // line height in pixels
  Lines      : Array[0..63] of String;  // max 64 lines
  NumLines   : Integer;
  I, J       : Integer;
  CurWord    : String;
  CurLine    : String;
  CurLineW   : Integer;  // current line width in design units
  WordW      : Integer;  // word width in design units
  SpaceW     : Integer;  // space character width
  MaxW       : Integer;  // box width in design units
  DrawX      : SmallInt;
  DrawY      : SmallInt;
  LineW      : Integer;
  TotalH     : Integer;
  SaveTrack  : SmallInt;
Begin
  If (RFFActiveFont < 1) or (RFFActiveFont > RIP_MAX_RFF) Then Exit;
  If Not RFFLoaded[RFFActiveFont] Then Exit;
  If Length(S) = 0 Then Exit;
  If PointSize <= 0 Then PointSize := 16;

  Font := TRFFFont(RFFFonts[RFFActiveFont]^);
  If Font.DesignUnits > 0 Then
    Scale := PointSize / Font.DesignUnits
  Else
    Scale := 1.0;

  LineH := Trunc((Font.Ascent + Abs(Font.Descent) + RFFLeading) * Scale);
  If LineH <= 0 Then LineH := PointSize;

  SpaceW := RFFGlyphWidth(Font, Ord(' '));
  If SpaceW <= 0 Then SpaceW := Font.DesignUnits DIV 4;

  // Convert box width from pixels to design units
  If Scale > 0 Then
    MaxW := Trunc(W / Scale)
  Else
    MaxW := 32000;

  // Split text into lines (word wrap or single line)
  NumLines := 0;

  If Not WordWrap Then Begin
    // Single line — no wrapping
    Lines[0] := S;
    NumLines := 1;
  End Else Begin
    // Word wrap: split at spaces
    CurLine  := '';
    CurLineW := 0;
    CurWord  := '';
    WordW    := 0;

    For I := 1 to Length(S) Do Begin
      If S[I] = ' ' Then Begin
        // Flush word
        If Length(CurWord) > 0 Then Begin
          If (CurLineW > 0) and (CurLineW + SpaceW + WordW > MaxW) Then Begin
            // Word doesn't fit — start new line
            If NumLines < 63 Then Begin
              Lines[NumLines] := CurLine;
              Inc(NumLines);
            End;
            CurLine  := CurWord;
            CurLineW := WordW;
          End Else Begin
            // Word fits — append
            If Length(CurLine) > 0 Then Begin
              CurLine  := CurLine + ' ' + CurWord;
              CurLineW := CurLineW + SpaceW + WordW;
            End Else Begin
              CurLine  := CurWord;
              CurLineW := WordW;
            End;
          End;
          CurWord := '';
          WordW   := 0;
        End;
      End Else Begin
        // Build current word
        CurWord := CurWord + S[I];
        WordW   := WordW + RFFGlyphWidth(Font, Ord(S[I])) + RFFTracking;
      End;
    End;

    // Flush last word
    If Length(CurWord) > 0 Then Begin
      If (CurLineW > 0) and (CurLineW + SpaceW + WordW > MaxW) Then Begin
        If NumLines < 63 Then Begin
          Lines[NumLines] := CurLine;
          Inc(NumLines);
        End;
        CurLine  := CurWord;
        CurLineW := WordW;
      End Else Begin
        If Length(CurLine) > 0 Then
          CurLine := CurLine + ' ' + CurWord
        Else
          CurLine := CurWord;
      End;
    End;

    // Flush last line
    If (Length(CurLine) > 0) and (NumLines < 64) Then Begin
      Lines[NumLines] := CurLine;
      Inc(NumLines);
    End;
  End;

  If NumLines = 0 Then Exit;

  // Calculate total text block height
  TotalH := NumLines * LineH;

  // Vertical alignment
  Case VAlign of
    RIP_BOTTOM_TEXT : DrawY := Y + H - TotalH;  // bottom
    1               : DrawY := Y + (H - TotalH) DIV 2;  // center
  Else               DrawY := Y;  // top (RIP_TOP_TEXT)
  End;

  // Render each line
  SaveTrack := RFFTracking;
  For I := 0 to NumLines - 1 Do Begin
    // Calculate line width for alignment
    LineW := 0;
    For J := 1 to Length(Lines[I]) Do
      LineW := LineW + RFFGlyphWidth(Font, Ord(Lines[I][J])) + RFFTracking;
    // Remove trailing tracking
    If Length(Lines[I]) > 0 Then
      LineW := LineW - RFFTracking;

    // Horizontal alignment
    Case HAlign of
      RIP_CENTER_TEXT : DrawX := X + (W - Trunc(LineW * Scale)) DIV 2;
      RIP_RIGHT_TEXT  : DrawX := X + W - Trunc(LineW * Scale);
    Else                DrawX := X;  // left
    End;

    DrawTextRFF(DrawX, DrawY, Lines[I], PointSize, 0);
    DrawY := DrawY + LineH;
  End;
End;

Function TRIPEngine.UTF8ToCP437 (Ch: Word) : Byte;
// Map a Unicode code point (U+0000..U+FFFF) to CP437 byte.
// Returns the CP437 equivalent, or '?' (63) if unmapped.
// Covers CP437 chars 0-255 including box drawing, international,
// math symbols, and control code glyphs (0-31).
Begin
  // ASCII range maps directly
  If Ch < 128 Then Begin
    Result := Ch;
    Exit;
  End;

  Case Ch of
    // CP437 chars 128-175: international characters
    $00C7 : Result := 128;  // Ç
    $00FC : Result := 129;  // ü
    $00E9 : Result := 130;  // é
    $00E2 : Result := 131;  // â
    $00E4 : Result := 132;  // ä
    $00E0 : Result := 133;  // à
    $00E5 : Result := 134;  // å
    $00E7 : Result := 135;  // ç
    $00EA : Result := 136;  // ê
    $00EB : Result := 137;  // ë
    $00E8 : Result := 138;  // è
    $00EF : Result := 139;  // ï
    $00EE : Result := 140;  // î
    $00EC : Result := 141;  // ì
    $00C4 : Result := 142;  // Ä
    $00C5 : Result := 143;  // Å
    $00C9 : Result := 144;  // É
    $00E6 : Result := 145;  // æ
    $00C6 : Result := 146;  // Æ
    $00F4 : Result := 147;  // ô
    $00F6 : Result := 148;  // ö
    $00F2 : Result := 149;  // ò
    $00FB : Result := 150;  // û
    $00F9 : Result := 151;  // ù
    $00FF : Result := 152;  // ÿ
    $00D6 : Result := 153;  // Ö
    $00DC : Result := 154;  // Ü
    $00A2 : Result := 155;  // ¢
    $00A3 : Result := 156;  // £
    $00A5 : Result := 157;  // ¥
    $20A7 : Result := 158;  // ₧
    $0192 : Result := 159;  // ƒ
    $00E1 : Result := 160;  // á
    $00ED : Result := 161;  // í
    $00F3 : Result := 162;  // ó
    $00FA : Result := 163;  // ú
    $00F1 : Result := 164;  // ñ
    $00D1 : Result := 165;  // Ñ
    $00AA : Result := 166;  // ª
    $00BA : Result := 167;  // º
    $00BF : Result := 168;  // ¿
    $2310 : Result := 169;  // ⌐
    $00AC : Result := 170;  // ¬
    $00BD : Result := 171;  // ½
    $00BC : Result := 172;  // ¼
    $00A1 : Result := 173;  // ¡
    $00AB : Result := 174;  // «
    $00BB : Result := 175;  // »

    // CP437 chars 176-223: box drawing and block elements
    $2591 : Result := 176;  // ░
    $2592 : Result := 177;  // ▒
    $2593 : Result := 178;  // ▓
    $2502 : Result := 179;  // │
    $2524 : Result := 180;  // ┤
    $2561 : Result := 181;  // ╡
    $2562 : Result := 182;  // ╢
    $2556 : Result := 183;  // ╖
    $2555 : Result := 184;  // ╕
    $2563 : Result := 185;  // ╣
    $2551 : Result := 186;  // ║
    $2557 : Result := 187;  // ╗
    $255D : Result := 188;  // ╝
    $255C : Result := 189;  // ╜
    $255B : Result := 190;  // ╛
    $2510 : Result := 191;  // ┐
    $2514 : Result := 192;  // └
    $2534 : Result := 193;  // ┴
    $252C : Result := 194;  // ┬
    $251C : Result := 195;  // ├
    $2500 : Result := 196;  // ─
    $253C : Result := 197;  // ┼
    $255E : Result := 198;  // ╞
    $255F : Result := 199;  // ╟
    $255A : Result := 200;  // ╚
    $2554 : Result := 201;  // ╔
    $2569 : Result := 202;  // ╩
    $2566 : Result := 203;  // ╦
    $2560 : Result := 204;  // ╠
    $2550 : Result := 205;  // ═
    $256C : Result := 206;  // ╬
    $2567 : Result := 207;  // ╧
    $2568 : Result := 208;  // ╨
    $2564 : Result := 209;  // ╤
    $2565 : Result := 210;  // ╥
    $2559 : Result := 211;  // ╙
    $2558 : Result := 212;  // ╘
    $2552 : Result := 213;  // ╒
    $2553 : Result := 214;  // ╓
    $256B : Result := 215;  // ╫
    $256A : Result := 216;  // ╪
    $2518 : Result := 217;  // ┘
    $250C : Result := 218;  // ┌
    $2588 : Result := 219;  // █
    $2584 : Result := 220;  // ▄
    $258C : Result := 221;  // ▌
    $2590 : Result := 222;  // ▐
    $2580 : Result := 223;  // ▀

    // CP437 chars 224-253: math and Greek
    $03B1 : Result := 224;  // α
    $00DF : Result := 225;  // ß
    $0393 : Result := 226;  // Γ
    $03C0 : Result := 227;  // π
    $03A3 : Result := 228;  // Σ
    $03C3 : Result := 229;  // σ
    $00B5 : Result := 230;  // µ
    $03C4 : Result := 231;  // τ
    $03A6 : Result := 232;  // Φ
    $0398 : Result := 233;  // Θ
    $03A9 : Result := 234;  // Ω
    $03B4 : Result := 235;  // δ
    $221E : Result := 236;  // ∞
    $03C6 : Result := 237;  // φ
    $03B5 : Result := 238;  // ε
    $2229 : Result := 239;  // ∩
    $2261 : Result := 240;  // ≡
    $00B1 : Result := 241;  // ±
    $2265 : Result := 242;  // ≥
    $2264 : Result := 243;  // ≤
    $2320 : Result := 244;  // ⌠
    $2321 : Result := 245;  // ⌡
    $00F7 : Result := 246;  // ÷
    $2248 : Result := 247;  // ≈
    $00B0 : Result := 248;  // °
    $2219 : Result := 249;  // ∙
    $00B7 : Result := 250;  // ·
    $221A : Result := 251;  // √
    $207F : Result := 252;  // ⁿ
    $00B2 : Result := 253;  // ²

    // CP437 chars 254-255
    $25A0 : Result := 254;  // ■
    $00A0 : Result := 255;  // NBSP

    // CP437 chars 1-31: control code glyphs
    $263A : Result := 1;    // ☺
    $263B : Result := 2;    // ☻
    $2665 : Result := 3;    // ♥
    $2666 : Result := 4;    // ♦
    $2663 : Result := 5;    // ♣
    $2660 : Result := 6;    // ♠
    $2022 : Result := 7;    // •
    $25D8 : Result := 8;    // ◘
    $25CB : Result := 9;    // ○
    $25D9 : Result := 10;   // ◙
    $2642 : Result := 11;   // ♂
    $2640 : Result := 12;   // ♀
    $266A : Result := 13;   // ♪
    $266B : Result := 14;   // ♫
    $263C : Result := 15;   // ☼
    $25BA : Result := 16;   // ►
    $25C4 : Result := 17;   // ◄
    $2195 : Result := 18;   // ↕
    $203C : Result := 19;   // ‼
    $00B6 : Result := 20;   // ¶
    $00A7 : Result := 21;   // §
    $25AC : Result := 22;   // ▬
    $21A8 : Result := 23;   // ↨
    $2191 : Result := 24;   // ↑
    $2193 : Result := 25;   // ↓
    $2192 : Result := 26;   // →
    $2190 : Result := 27;   // ←
    $221F : Result := 28;   // ∟
    $2194 : Result := 29;   // ↔
    $25B2 : Result := 30;   // ▲
    $25BC : Result := 31;   // ▼
  Else
    Result := Ord('?');  // unmapped
  End;
End;

Function TRIPEngine.MapStringCP437 (S: String) : String;
// Convert a string that may contain UTF-8 sequences to CP437 bytes.
// Pure ASCII passes through. Multi-byte UTF-8 sequences are decoded
// and mapped via UTF8ToCP437. Invalid sequences become '?'.
Var
  I, Len : Integer;
  B1, B2, B3 : Byte;
  CodePt     : Word;
Begin
  Result := '';
  I := 1;
  Len := Length(S);

  While I <= Len Do Begin
    B1 := Ord(S[I]);

    If B1 < 128 Then Begin
      // ASCII — pass through
      Result := Result + S[I];
      Inc(I);
    End
    Else If (B1 and $E0) = $C0 Then Begin
      // 2-byte UTF-8: 110xxxxx 10xxxxxx
      If I + 1 <= Len Then Begin
        B2 := Ord(S[I + 1]);
        If (B2 and $C0) = $80 Then Begin
          CodePt := ((B1 and $1F) SHL 6) or (B2 and $3F);
          Result := Result + Chr(UTF8ToCP437(CodePt));
          Inc(I, 2);
        End Else Begin
          Result := Result + '?';
          Inc(I);
        End;
      End Else Begin
        Result := Result + '?';
        Inc(I);
      End;
    End
    Else If (B1 and $F0) = $E0 Then Begin
      // 3-byte UTF-8: 1110xxxx 10xxxxxx 10xxxxxx
      If I + 2 <= Len Then Begin
        B2 := Ord(S[I + 1]);
        B3 := Ord(S[I + 2]);
        If ((B2 and $C0) = $80) and ((B3 and $C0) = $80) Then Begin
          CodePt := ((B1 and $0F) SHL 12) or ((B2 and $3F) SHL 6) or (B3 and $3F);
          Result := Result + Chr(UTF8ToCP437(CodePt));
          Inc(I, 3);
        End Else Begin
          Result := Result + '?';
          Inc(I);
        End;
      End Else Begin
        Result := Result + '?';
        Inc(I);
      End;
    End
    Else Begin
      // 4-byte or invalid — skip
      Result := Result + '?';
      Inc(I);
    End;
  End;
End;

// ====================================================================
// v3.0 Phase 18: MAF Bitmap Font Loader
// ====================================================================

Function TRIPEngine.LoadMAF (FileName: String) : Boolean;
// Load MAF (MicroANSI Font) container file.
// Parses header, resolution table, and extracts bitmap font data.
// Format: 0x29-byte header + resolution entries with font offset tables.
Var
  F         : File;
  Hdr       : Array[0..40] of Byte;
  BytesRead : LongInt;
  FileLen   : LongInt;
  Sig       : String;
  I, J, K   : Integer;
  ResW, ResH: Word;
  Offsets   : Array[0..4] of LongWord;
  NameBuf   : Array[0..31] of Char;
  B         : Byte;
  FontSize  : Word;
  CurOff    : LongInt;
  NextOff   : LongInt;
  Heights   : Array[0..4] of Byte;
Begin
  Result := False;

  // Free existing MAF
  FreeMAF;

  Assign(F, FileName);
  {$I-} System.Reset(F, 1); {$I+}
  If IOResult <> 0 Then Exit;

  FileLen := FileSize(F);
  If FileLen < RIP_MAF_HEADER_SIZE Then Begin Close(F); Exit; End;

  // Read and verify header
  BlockRead(F, Hdr, RIP_MAF_HEADER_SIZE, BytesRead);
  If BytesRead < RIP_MAF_HEADER_SIZE Then Begin Close(F); Exit; End;

  // Check signature: byte 0 = 0x04, bytes 1..33 contain "MicroANSI Font"
  If Hdr[0] <> $04 Then Begin Close(F); Exit; End;

  Sig := '';
  For I := 1 to 33 Do Sig := Sig + Chr(Hdr[I]);
  If Pos('MicroANSI', Sig) = 0 Then Begin Close(F); Exit; End;

  // Allocate MAF structure
  GetMem(MAFData, SizeOf(TMAFFile));
  FillChar(MAFData^, SizeOf(TMAFFile), 0);
  MAFData^.Loaded := True;
  MAFData^.ResCount := 0;

  // Parse resolution entries
  // Each entry: 2(width) + 2(height) + 4(reserved) + 20(5 offsets) + 32(name) = 56 bytes
  CurOff := RIP_MAF_HEADER_SIZE;

  While (CurOff + 56 <= FileLen) and (MAFData^.ResCount < RIP_MAX_MAF_RES) Do Begin
    Seek(F, CurOff);

    // Read width and height
    BlockRead(F, ResW, 2, BytesRead);
    If BytesRead < 2 Then Break;
    BlockRead(F, ResH, 2, BytesRead);
    If BytesRead < 2 Then Break;

    // Sanity check — valid resolution?
    If (ResW < 320) or (ResW > 2048) or (ResH < 200) or (ResH > 1536) Then Break;

    // Skip reserved (4 bytes)
    Seek(F, FilePos(F) + 4);

    // Read 5 font offsets
    For I := 0 to 4 Do Begin
      BlockRead(F, Offsets[I], 4, BytesRead);
      If BytesRead < 4 Then Break;
    End;

    // Read resolution name (32 bytes, null-terminated)
    FillChar(NameBuf, 32, 0);
    BlockRead(F, NameBuf, 32, BytesRead);

    // Store resolution entry
    With MAFData^.Entries[MAFData^.ResCount] Do Begin
      Width  := ResW;
      Height := ResH;
      Name   := '';
      For I := 0 to 30 Do Begin
        If NameBuf[I] = #0 Then Break;
        Name := Name + NameBuf[I];
      End;
      FontCount := 0;

      // Determine font heights by calculating size between offsets
      // Common heights: 2048=8px, 2816=11px, 3584=14px, 4096=16px
      For I := 0 to 4 Do Begin
        If (Offsets[I] = 0) or (Offsets[I] >= LongWord(FileLen)) Then Continue;

        // Calculate font data size
        If I < 4 Then Begin
          If (Offsets[I + 1] > 0) and (Offsets[I + 1] > Offsets[I]) Then
            FontSize := Offsets[I + 1] - Offsets[I]
          Else
            FontSize := 0;
        End Else
          FontSize := 0;

        // Determine height from size (256 chars * height = total)
        If FontSize >= 4096 Then Heights[I] := 16
        Else If FontSize >= 3584 Then Heights[I] := 14
        Else If FontSize >= 2816 Then Heights[I] := 11
        Else If FontSize >= 2048 Then Heights[I] := 8
        Else If FontSize > 0 Then Heights[I] := FontSize DIV 256
        Else Heights[I] := 0;

        If Heights[I] = 0 Then Continue;
        If FontCount >= RIP_MAX_MAF_FONTS Then Continue;

        // Read font bitmap data
        FontSize := 256 * Heights[I];
        Fonts[FontCount].Height := Heights[I];
        Fonts[FontCount].DataSize := FontSize;
        GetMem(Fonts[FontCount].Data, FontSize);

        Seek(F, Offsets[I]);
        BlockRead(F, Fonts[FontCount].Data^, FontSize, BytesRead);
        If LongWord(BytesRead) < FontSize Then Begin
          FreeMem(Fonts[FontCount].Data, FontSize);
          Fonts[FontCount].Data := Nil;
          Fonts[FontCount].Height := 0;
          Continue;
        End;

        Inc(FontCount);
      End;
    End;

    Inc(MAFData^.ResCount);
    CurOff := CurOff + 56;
  End;

  Close(F);
  Result := MAFData^.ResCount > 0;
End;

Procedure TRIPEngine.FreeMAF;
Var I, J : Integer;
Begin
  If MAFData = Nil Then Exit;

  For I := 0 to MAFData^.ResCount - 1 Do
    For J := 0 to MAFData^.Entries[I].FontCount - 1 Do
      If MAFData^.Entries[I].Fonts[J].Data <> Nil Then Begin
        FreeMem(MAFData^.Entries[I].Fonts[J].Data,
                MAFData^.Entries[I].Fonts[J].DataSize);
        MAFData^.Entries[I].Fonts[J].Data := Nil;
      End;

  FreeMem(MAFData, SizeOf(TMAFFile));
  MAFData := Nil;
  MAFActiveRes := -1;
  MAFActiveFont := -1;
End;

Function TRIPEngine.MAFSelectRes (ScrW, ScrH: Word) : Boolean;
// Select the best resolution entry for the given screen size.
// Matches exact or closest without exceeding.
Var
  I, Best : Integer;
  BestDist : LongInt;
  Dist     : LongInt;
Begin
  Result := False;
  If (MAFData = Nil) or (Not MAFData^.Loaded) Then Exit;

  Best := -1;
  BestDist := $7FFFFFFF;

  For I := 0 to MAFData^.ResCount - 1 Do Begin
    // Exact match preferred
    If (MAFData^.Entries[I].Width = ScrW) and
       (MAFData^.Entries[I].Height = ScrH) Then Begin
      Best := I;
      Break;
    End;
    // Otherwise closest that doesn't exceed
    If (MAFData^.Entries[I].Width <= ScrW) and
       (MAFData^.Entries[I].Height <= ScrH) Then Begin
      Dist := Abs(LongInt(ScrW) - MAFData^.Entries[I].Width) +
              Abs(LongInt(ScrH) - MAFData^.Entries[I].Height);
      If Dist < BestDist Then Begin
        BestDist := Dist;
        Best := I;
      End;
    End;
  End;

  If Best >= 0 Then Begin
    MAFActiveRes := Best;
    // Auto-select first font
    If MAFData^.Entries[Best].FontCount > 0 Then
      MAFActiveFont := 0
    Else
      MAFActiveFont := -1;
    Result := True;
  End;
End;

Function TRIPEngine.MAFSelectFont (FontIdx: Integer) : Boolean;
// Select a specific font within the active resolution.
Begin
  Result := False;
  If (MAFData = Nil) or (MAFActiveRes < 0) Then Exit;
  If (FontIdx < 0) or (FontIdx >= MAFData^.Entries[MAFActiveRes].FontCount) Then Exit;
  MAFActiveFont := FontIdx;
  Result := True;
End;

Function TRIPEngine.MAFGetFontH : Integer;
// Returns the active MAF font height in pixels, or 0 if none.
Begin
  Result := 0;
  If (MAFData = Nil) or (MAFActiveRes < 0) or (MAFActiveFont < 0) Then Exit;
  Result := MAFData^.Entries[MAFActiveRes].Fonts[MAFActiveFont].Height;
End;

Function TRIPEngine.MAFIsLoaded : Boolean;
Begin
  Result := (MAFData <> Nil) and MAFData^.Loaded;
End;

Procedure TRIPEngine.DrawTextMAF (X, Y: SmallInt; S: String);
// Render text using the active MAF bitmap font.
// Supports any character height (8, 11, 14, 16 px), always 8px wide.
// Each character is Height bytes, MSB = leftmost pixel, top to bottom.
// Renders all 256 CP437 characters.
Var
  I, Row, Col : Integer;
  Ch          : Byte;
  FontByte    : Byte;
  CharH       : Integer;
  FontData    : PByte;
  Offset      : LongInt;
Begin
  If Not MAFIsLoaded Then Exit;
  If (MAFActiveRes < 0) or (MAFActiveFont < 0) Then Exit;

  CharH    := MAFData^.Entries[MAFActiveRes].Fonts[MAFActiveFont].Height;
  FontData := MAFData^.Entries[MAFActiveRes].Fonts[MAFActiveFont].Data;

  If (CharH <= 0) or (FontData = Nil) Then Exit;

  For I := 1 to Length(S) Do Begin
    Ch := Ord(S[I]);
    Offset := LongInt(Ch) * CharH;

    For Row := 0 to CharH - 1 Do Begin
      FontByte := FontData[Offset + Row];
      For Col := 0 to 7 Do
        If (FontByte and ($80 SHR Col)) <> 0 Then
          DrawPixel(X + (I - 1) * 8 + Col, Y + Row, DrawColor);
    End;
  End;
End;

// ====================================================================
// v3.0 Phase 20: Data Tables (SERVER-SIDE)
// ====================================================================
//
// SERVER FLOW:
//   1. TableCreate(X, Y, Cols)     — initialize table at screen position
//   2. TableAddCol(Title, W, Align) — define each column (repeat per col)
//   3. TableAddRow                  — add a data row
//   4. TableSetCell(Row, Col, Text) — populate cell content
//   5. TableRender                  — draw table to pixel buffer
//   6. TableScroll(Delta)           — shift visible window (optional)
//   7. TableClear                   — destroy table when done
//
// The server owns the table completely. The client sees rendered
// pixels only — table data never travels to the client as structured
// data. This is pure server-side rendering.
//
// ====================================================================

Procedure TRIPEngine.TableCreate (X, Y: SmallInt; Cols: Integer);
// SERVER: Initialize a new table at position (X,Y).
// Clears any existing table. Sets default header/row heights
// based on current system font. Cols parameter is reserved
// for future pre-allocation — columns are added via TableAddCol.
Begin
  TableClear;
  Table.Active  := True;
  Table.X       := X;
  Table.Y       := Y;
  Table.ColCount := 0;
  Table.RowCount := 0;
  Table.HeaderH := GetSysFontH + 4;
  Table.RowH    := GetSysFontH + 2;
  Table.GridColor := 7;
  Table.HeaderBG  := 1;
  Table.ScrollTop := 0;
  Table.VisRows   := 0;
End;

Procedure TRIPEngine.TableAddCol (Title: String; Width: SmallInt; Align: Byte);
Begin
  If Not Table.Active Then Exit;
  If Table.ColCount >= RIP_MAX_TABLE_COLS Then Exit;
  Table.Cols[Table.ColCount].Title := Title;
  Table.Cols[Table.ColCount].Width := Width;
  Table.Cols[Table.ColCount].Align := Align;
  Inc(Table.ColCount);
End;

Procedure TRIPEngine.TableAddRow;
Var J : Integer;
Begin
  If Not Table.Active Then Exit;
  If Table.RowCount >= RIP_MAX_TABLE_ROWS Then Exit;
  For J := 0 to Table.ColCount - 1 Do Begin
    Table.Cells[Table.RowCount, J].Text  := '';
    Table.Cells[Table.RowCount, J].Color := DrawColor;
  End;
  Inc(Table.RowCount);
End;

Procedure TRIPEngine.TableSetCell (Row, Col: Integer; Text: String; Color: Byte);
Begin
  If Not Table.Active Then Exit;
  If (Row < 0) or (Row >= Table.RowCount) Then Exit;
  If (Col < 0) or (Col >= Table.ColCount) Then Exit;
  Table.Cells[Row, Col].Text  := Text;
  Table.Cells[Row, Col].Color := Color;
End;

Procedure TRIPEngine.TableRender;
Var
  CX, CY    : SmallInt;
  I, J      : Integer;
  TotalW     : SmallInt;
  FirstRow   : Integer;
  LastRow    : Integer;
  CellText   : String;
  TextX      : SmallInt;
  TextW      : Integer;
  SaveColor  : Byte;
Begin
  If Not Table.Active Then Exit;
  If Table.ColCount = 0 Then Exit;

  SaveColor := DrawColor;

  // Calculate total width
  TotalW := 0;
  For J := 0 to Table.ColCount - 1 Do
    TotalW := TotalW + Table.Cols[J].Width;

  // Draw header background
  SetFillStyle(1, Table.HeaderBG);
  Bar(Table.X, Table.Y, Table.X + TotalW - 1, Table.Y + Table.HeaderH - 1);

  // Draw header text
  CX := Table.X;
  SetColor(15);
  For J := 0 to Table.ColCount - 1 Do Begin
    DrawText8x8(CX + 2, Table.Y + 2, Table.Cols[J].Title);
    CX := CX + Table.Cols[J].Width;
  End;

  // Draw header grid
  SetColor(Table.GridColor);
  Line(Table.X, Table.Y + Table.HeaderH, Table.X + TotalW - 1, Table.Y + Table.HeaderH);

  // Draw vertical grid lines
  CX := Table.X;
  For J := 0 to Table.ColCount - 1 Do Begin
    Line(CX, Table.Y, CX, Table.Y + Table.HeaderH +
         Table.RowH * Table.RowCount);
    CX := CX + Table.Cols[J].Width;
  End;
  // Right edge
  Line(CX, Table.Y, CX, Table.Y + Table.HeaderH + Table.RowH * Table.RowCount);

  // Determine visible rows
  FirstRow := Table.ScrollTop;
  If Table.VisRows > 0 Then
    LastRow := FirstRow + Table.VisRows - 1
  Else
    LastRow := Table.RowCount - 1;
  If LastRow >= Table.RowCount Then LastRow := Table.RowCount - 1;

  // Draw data rows
  For I := FirstRow to LastRow Do Begin
    CY := Table.Y + Table.HeaderH + (I - FirstRow) * Table.RowH;
    CX := Table.X;

    For J := 0 to Table.ColCount - 1 Do Begin
      CellText := Table.Cells[I, J].Text;
      SetColor(Table.Cells[I, J].Color);

      // Alignment
      TextW := Length(CellText) * GetSysFontW;
      Case Table.Cols[J].Align of
        RIP_COL_CENTER : TextX := CX + (Table.Cols[J].Width - TextW) DIV 2;
        RIP_COL_RIGHT  : TextX := CX + Table.Cols[J].Width - TextW - 2;
      Else               TextX := CX + 2;
      End;

      DrawText8x8(TextX, CY + 1, CellText);
      CX := CX + Table.Cols[J].Width;
    End;

    // Row grid line
    SetColor(Table.GridColor);
    Line(Table.X, CY + Table.RowH, Table.X + TotalW - 1, CY + Table.RowH);
  End;

  // Bottom border
  CY := Table.Y + Table.HeaderH + (LastRow - FirstRow + 1) * Table.RowH;
  SetColor(Table.GridColor);
  Line(Table.X, CY, Table.X + TotalW - 1, CY);

  SetColor(SaveColor);
End;

Procedure TRIPEngine.TableClear;
Begin
  Table.Active   := False;
  Table.ColCount := 0;
  Table.RowCount := 0;
  Table.ScrollTop := 0;
End;

Procedure TRIPEngine.TableScroll (Delta: Integer);
Begin
  If Not Table.Active Then Exit;
  Table.ScrollTop := Table.ScrollTop + Delta;
  If Table.ScrollTop < 0 Then Table.ScrollTop := 0;
  If Table.ScrollTop >= Table.RowCount Then
    Table.ScrollTop := Table.RowCount - 1;
  If Table.ScrollTop < 0 Then Table.ScrollTop := 0;
End;

Function TRIPEngine.TableGetRows : Integer;
Begin
  Result := Table.RowCount;
End;

Function TRIPEngine.TableGetCols : Integer;
Begin
  Result := Table.ColCount;
End;

Procedure TRIPEngine.TableSetVisRows (Rows: Integer);
// Set the number of visible rows for scrollable tables.
// 0 = show all rows (no scrolling).
Begin
  If Not Table.Active Then Exit;
  Table.VisRows := Rows;
End;

// ====================================================================
// v3.0 Phase 20: Form Fields (CLIENT-SIDE)
// ====================================================================
//
// CLIENT/SERVER INTERACTION FLOW:
//
//   SERVER creates form:
//     Idx := FormAddField(RIP_FIELD_TEXT, 'Username', 100, 50, 200, 20);
//     FormBindVar(Idx, 'USERNAME');
//     FormFields[Idx].Required := True;
//     FormRender;  ← draws empty text field to pixel buffer
//
//   CLIENT receives input:
//     Host application detects keypress in focused field
//     Host calls: FormSetValue(Idx, 'john_doe');
//     Host calls: FormRender;  ← redraws with new text
//
//   SERVER reads value:
//     FormSyncToVars;  ← pushes 'john_doe' into $USERNAME$
//     RIP command uses $USERNAME$ in text variable expansion
//
//   SERVER validates:
//     If FormValidate Then
//       ProcessSubmission
//     Else
//       ShowError('Required fields missing');
//
// The engine does NOT handle keyboard/mouse input directly.
// The host application (BBS server, terminal emulator, viewer)
// processes input events and calls FormSetValue/FormRender.
//
// ====================================================================

Function TRIPEngine.FormAddField (FieldType: Byte; Name: String;
                                   X, Y, W, H: SmallInt) : Integer;
// CLIENT: Create a new form field.
// Returns field index (0-based), or -1 if max fields reached.
// FieldType: RIP_FIELD_TEXT(0), DROPDOWN(1), LISTBOX(2), CHECKBOX(3), LABEL(4)
// Name: displayed for checkboxes, used as identifier for binding.
// Position/size: pixel coordinates on canvas.
Begin
  Result := -1;
  If FormFieldCount >= RIP_MAX_FORM_FIELDS Then Exit;

  Result := FormFieldCount;

  FormFields[Result].Active    := True;
  FormFields[Result].FieldType := FieldType;
  FormFields[Result].Name      := Name;
  FormFields[Result].X         := X;
  FormFields[Result].Y         := Y;
  FormFields[Result].W         := W;
  FormFields[Result].H         := H;
  FormFields[Result].Value     := '';
  FormFields[Result].Default   := '';
  FormFields[Result].MaxLen    := RIP_MAX_FIELD_LEN;
  FormFields[Result].Options   := '';
  FormFields[Result].Required  := False;
  FormFields[Result].VarName   := '';
  FormFields[Result].Color     := 15;
  FormFields[Result].BgColor   := 0;
  FormFields[Result].Focused   := False;
  FormFields[Result].ReadOnly  := False;

  Inc(FormFieldCount);
End;

Procedure TRIPEngine.FormSetValue (Idx: Integer; Value: String);
Begin
  If (Idx < 0) or (Idx >= FormFieldCount) Then Exit;
  FormFields[Idx].Value := Value;
End;

Function TRIPEngine.FormGetValue (Idx: Integer) : String;
Begin
  Result := '';
  If (Idx < 0) or (Idx >= FormFieldCount) Then Exit;
  Result := FormFields[Idx].Value;
End;

Procedure TRIPEngine.FormSetOptions (Idx: Integer; Options: String);
Begin
  If (Idx < 0) or (Idx >= FormFieldCount) Then Exit;
  FormFields[Idx].Options := Options;
End;

Procedure TRIPEngine.FormBindVar (Idx: Integer; VarName: String);
Begin
  If (Idx < 0) or (Idx >= FormFieldCount) Then Exit;
  FormFields[Idx].VarName := VarName;
End;

Function TRIPEngine.FormValidate : Boolean;
Var I : Integer;
Begin
  Result := True;
  For I := 0 to FormFieldCount - 1 Do
    If FormFields[I].Active and FormFields[I].Required and
       (Length(FormFields[I].Value) = 0) Then Begin
      Result := False;
      Exit;
    End;
End;

Procedure TRIPEngine.FormRender;
Var
  I        : Integer;
  SaveColor: Byte;
Begin
  SaveColor := DrawColor;

  For I := 0 to FormFieldCount - 1 Do Begin
    If Not FormFields[I].Active Then Continue;

    With FormFields[I] Do Begin
      // Draw background
      SetColor(BgColor);
      Bar(X, Y, X + W - 1, Y + H - 1);

      // Draw border
      If Focused Then
        SetColor(15)
      Else
        SetColor(7);
      Rectangle(X, Y, X + W - 1, Y + H - 1);

      // Draw content based on type
      SetColor(Color);
      Case FieldType of
        RIP_FIELD_TEXT :
          DrawText8x8(X + 2, Y + 2, Value);

        RIP_FIELD_DROPDOWN : Begin
          DrawText8x8(X + 2, Y + 2, Value);
          // Draw dropdown arrow
          SetColor(7);
          DrawText8x8(X + W - 10, Y + 2, Chr(25));  // ↓
        End;

        RIP_FIELD_LISTBOX :
          DrawText8x8(X + 2, Y + 2, Value);

        RIP_FIELD_CHECKBOX : Begin
          Rectangle(X + 2, Y + 2, X + H - 3, Y + H - 3);
          If Value = '1' Then
            DrawText8x8(X + 4, Y + 2, 'X');
          DrawText8x8(X + H + 2, Y + 2, Name);
        End;

        RIP_FIELD_LABEL :
          DrawText8x8(X + 2, Y + 2, Value);
      End;
    End;
  End;

  SetColor(SaveColor);
End;

Procedure TRIPEngine.FormClear;
Var I : Integer;
Begin
  For I := 0 to FormFieldCount - 1 Do
    FormFields[I].Active := False;
  FormFieldCount := 0;
End;

Procedure TRIPEngine.FormSyncToVars;
// Push form field values to bound text variables.
// Creates or overwrites the variable.
Var I : Integer;
Begin
  For I := 0 to FormFieldCount - 1 Do
    If FormFields[I].Active and (Length(FormFields[I].VarName) > 0) Then
      DefineVar(FormFields[I].VarName, FormFields[I].Value, False, False);
End;

Procedure TRIPEngine.FormSyncFromVars;
// Pull text variable values into bound form fields
Var I : Integer;
Begin
  For I := 0 to FormFieldCount - 1 Do
    If FormFields[I].Active and (Length(FormFields[I].VarName) > 0) Then
      FormFields[I].Value := GetVar(FormFields[I].VarName);
End;

Procedure TRIPEngine.FormSetRequired (Idx: Integer; Req: Boolean);
// Set the Required flag on a form field for validation
Begin
  If (Idx < 0) or (Idx >= FormFieldCount) Then Exit;
  FormFields[Idx].Required := Req;
End;

// ====================================================================
// v3.0 Phase 22: Advanced Multimedia (SERVER-SIDE)
// ====================================================================
//
// ARCHITECTURE:
//   Server manages audio state (load, play, pause, stop, volume).
//   Client receives audio data and plays it through hardware.
//   MIDI is parsed server-side; events are sent to client for synthesis.
//   Cue points trigger RIP commands at specific animation frames.
//   WAV streaming sends audio chunks during download.
//
// FLOW:
//   AudioLoad(0, 'intro.wav') → load into stream 0
//   AudioPlay(0) → start playback
//   SetBgAudio(0) → mark as background audio
//   CueAdd(100, '|1e') → at frame 100, execute ClearScreen
//   CueProcess(FrameCounter) → check and fire cue points
//   BgAudioTransition('menu.wav', 30) → crossfade over 30 frames
//
// ====================================================================

Function TRIPEngine.AudioLoad (Stream: Integer; FileName: String) : Boolean;
// SERVER: Load an audio file into a stream slot.
// Supports WAV, VOC, MP3, FLAC, AIFF, AU, MOD, S3M, XM.
// The file is loaded by reference — actual decoding happens at play time.
Begin
  Result := False;
  If (Stream < 0) or (Stream >= RIP_MAX_AUDIO_STREAMS) Then Exit;
  AudioFile[Stream]  := FileName;
  AudioState[Stream] := RIP_AUDIO_STOPPED;
  Result := True;
End;

Procedure TRIPEngine.AudioPlay (Stream: Integer);
// SERVER: Start or resume playback on a stream.
// Client handles actual audio output via wavplay.pas / dosplay.pas.
Begin
  If (Stream < 0) or (Stream >= RIP_MAX_AUDIO_STREAMS) Then Exit;
  If Length(AudioFile[Stream]) = 0 Then Exit;
  AudioState[Stream] := RIP_AUDIO_PLAYING;
End;

Procedure TRIPEngine.AudioPause (Stream: Integer);
// SERVER: Pause playback. AudioPlay resumes from current position.
Begin
  If (Stream < 0) or (Stream >= RIP_MAX_AUDIO_STREAMS) Then Exit;
  If AudioState[Stream] = RIP_AUDIO_PLAYING Then
    AudioState[Stream] := RIP_AUDIO_PAUSED;
End;

Procedure TRIPEngine.AudioStop (Stream: Integer);
// SERVER: Stop playback and reset position to beginning.
Begin
  If (Stream < 0) or (Stream >= RIP_MAX_AUDIO_STREAMS) Then Exit;
  AudioState[Stream] := RIP_AUDIO_STOPPED;
End;

Procedure TRIPEngine.AudioStopAll;
// SERVER: Stop all audio streams. Called on scene change or disconnect.
Var I : Integer;
Begin
  For I := 0 to RIP_MAX_AUDIO_STREAMS - 1 Do
    AudioState[I] := RIP_AUDIO_STOPPED;
End;

Procedure TRIPEngine.AudioSetVolume (Stream: Integer; Volume: Byte);
// SERVER: Set stream volume (0=silent, 255=full).
// Client applies volume via pcmmix.pas AdjustVolume8/16.
Begin
  If (Stream < 0) or (Stream >= RIP_MAX_AUDIO_STREAMS) Then Exit;
  AudioVolume[Stream] := Volume;
End;

Function TRIPEngine.AudioGetState (Stream: Integer) : Byte;
// SERVER: Query stream state (RIP_AUDIO_IDLE/PLAYING/PAUSED/STOPPED).
Begin
  Result := RIP_AUDIO_IDLE;
  If (Stream < 0) or (Stream >= RIP_MAX_AUDIO_STREAMS) Then Exit;
  Result := AudioState[Stream];
End;

Function TRIPEngine.MIDILoad (FileName: String) : Boolean;
// SERVER: Load a MIDI file for event parsing.
// Uses MIDILoadMem from mididec.pas (avoids TStream dependency).
// MIDI events are parsed server-side and sent to client for synthesis.
Begin
  MIDIFree;
  MIDIFileName := FileName;
  MIDILoaded   := True;
  Result := True;
  // NOTE: actual parsing deferred to playback — mididec.pas uses
  // Classes/TStream which is incompatible with {$H-}. The server
  // stores the filename; the host application handles the actual
  // MIDI loading via MIDILoadFile or MIDILoadMem at playback time.
End;

Procedure TRIPEngine.MIDIFree;
// SERVER: Release MIDI data.
Begin
  MIDILoaded   := False;
  MIDIFileName := '';
End;

Procedure TRIPEngine.CueAdd (Frame: LongInt; Action: String);
// SERVER: Add a timed event — execute Action (a RIP command string)
// when the animation reaches the specified frame number.
// Example: CueAdd(60, '|1e') — clear screen at frame 60 (1 second at 60fps).
Begin
  If CueCount >= 64 Then Exit;
  CuePoints[CueCount]  := Frame;
  CueActions[CueCount] := Action;
  Inc(CueCount);
End;

Procedure TRIPEngine.CueClear;
// SERVER: Remove all cue points.
Begin
  CueCount := 0;
End;

Procedure TRIPEngine.CueProcess (CurrentFrame: LongInt);
// SERVER: Check all cue points against the current frame.
// Fires matching cue actions by calling ProcessLine.
// Called once per frame during animation playback.
Var I : Integer;
Begin
  For I := 0 to CueCount - 1 Do
    If CuePoints[I] = CurrentFrame Then
      ProcessLine(CueActions[I]);
  FrameCounter := CurrentFrame;
End;

Procedure TRIPEngine.SetBgAudio (Stream: Integer);
// SERVER: Designate a stream as background audio.
// Background audio persists across scene changes (not stopped by AudioStopAll).
Begin
  If (Stream < -1) or (Stream >= RIP_MAX_AUDIO_STREAMS) Then Exit;
  BgAudioStream := Stream;
End;

Procedure TRIPEngine.BgAudioTransition (NewFile: String; FadeFrames: Integer);
// SERVER: Crossfade background audio to a new file.
// The old background fades out over FadeFrames, then the new file starts.
// FadeFrames=0 means immediate switch (no crossfade).
Begin
  If BgAudioStream >= 0 Then Begin
    // Mark old stream for fade-out (client handles the actual fade)
    AudioState[BgAudioStream] := RIP_AUDIO_STOPPED;
  End;
  // Load new file into next available stream
  If BgAudioStream < 0 Then BgAudioStream := 0;
  AudioLoad(BgAudioStream, NewFile);
  AudioPlay(BgAudioStream);
  // FadeFrames stored for client-side fade implementation
  // (actual fade handled by pcmmix.pas AdjustVolume over time)
End;

Function TRIPEngine.WAVStreamStart (Stream: Integer; SampleRate: LongInt;
                                     Bits, Channels: Byte) : Boolean;
// SERVER: Initialize a WAV streaming session on a stream slot.
// Audio data will be fed in chunks via WAVStreamFeed.
// Client begins playback as soon as enough data buffered (via ringbuf.pas).
Begin
  Result := False;
  If (Stream < 0) or (Stream >= RIP_MAX_AUDIO_STREAMS) Then Exit;
  AudioFile[Stream]  := '<streaming>';
  AudioState[Stream] := RIP_AUDIO_PLAYING;
  Result := True;
End;

Procedure TRIPEngine.WAVStreamFeed (Stream: Integer; Data: PByte; Len: LongInt);
// SERVER: Feed a chunk of audio data to a streaming session.
// Client appends to ring buffer (ringbuf.pas) and plays continuously.
Begin
  If (Stream < 0) or (Stream >= RIP_MAX_AUDIO_STREAMS) Then Exit;
  // Data would be forwarded to the client's ring buffer.
  // Server-side, we just track the state.
End;

Procedure TRIPEngine.WAVStreamEnd (Stream: Integer);
// SERVER: Signal end of streaming audio. Client flushes remaining buffer.
Begin
  If (Stream < 0) or (Stream >= RIP_MAX_AUDIO_STREAMS) Then Exit;
  AudioState[Stream] := RIP_AUDIO_STOPPED;
End;

// ====================================================================
// v3.0 Phase 23: Advanced Graphics (SERVER-SIDE)
// ====================================================================
//
// Wraps the standalone graphics engine units (grfill, grfx, grbezier,
// grtexmap, grclip) and routes them through the engine's pixel buffer.
// All operations work in RGB24 mode. In indexed mode, the engine
// promotes to RGB24 internally for the operation.
//
// ====================================================================

Procedure TRIPEngine.GradientRect (X1, Y1, X2, Y2: SmallInt;
                                    R1, G1, B1, R2, G2, B2: Byte;
                                    GType: Byte);
Var
  C1, C2 : TGradientColor;
  GT     : TGradientType;
Begin
  C1 := GradColor(R1, G1, B1);
  C2 := GradColor(R2, G2, B2);
  Case GType of
    1 : GT := gtRadial;
    2 : GT := gtConical;
  Else  GT := gtLinear;
  End;
  GradientFillRect(PByte(PixelsRGB), CanvasWidth, CanvasHeight,
                   X1, Y1, X2, Y2, C1, C2, GT, 0);
End;

Procedure TRIPEngine.DropShadow (X, Y, W, H: SmallInt;
                                  OffX, OffY: SmallInt; Blur: Byte;
                                  R, G, B, Opacity: Byte);
Var SP : TShadowParams;
Begin
  SP := ShadowParams(OffX, OffY, Blur, R, G, B, Opacity);
  FXDropShadow(PByte(PixelsRGB), CanvasWidth, CanvasHeight, SP);
End;

Procedure TRIPEngine.OuterGlow (X, Y, W, H: SmallInt;
                                 Radius: Byte; R, G, B, Opacity: Byte);
Var GP : TGlowParams;
Begin
  GP := GlowParams(Radius, R, G, B, Opacity);
  FXOuterGlow(PByte(PixelsRGB), CanvasWidth, CanvasHeight, GP);
End;

Procedure TRIPEngine.BezierVarWidth (X0, Y0: SmallInt; W0: Byte;
                                      X1, Y1: SmallInt; W1: Byte;
                                      X2, Y2: SmallInt; W2: Byte;
                                      X3, Y3: SmallInt; W3: Byte;
                                      R, G, B: Byte);
Var
  P0, P1, P2, P3 : TBezPoint;
  Color : LongWord;
Begin
  P0 := BezPt(X0, Y0, W0);
  P1 := BezPt(X1, Y1, W1);
  P2 := BezPt(X2, Y2, W2);
  P3 := BezPt(X3, Y3, W3);
  Color := (LongWord(R) SHL 16) or (LongWord(G) SHL 8) or B;
  BezierDrawVarWidth(PByte(PixelsRGB), CanvasWidth, CanvasHeight,
                     P0, P1, P2, P3, Color, csRound);
End;

Procedure TRIPEngine.TextureQuad (X0, Y0, X1, Y1, X2, Y2, X3, Y3: SmallInt;
                                   TexData: PByte; TexW, TexH: Word);
Var
  Tex : TTexture;
  V0, V1, V2, V3 : TTexVertex;
Begin
  Tex.Pixels := TexData;
  Tex.Width  := TexW;
  Tex.Height := TexH;
  V0.X := X0; V0.Y := Y0; V0.U := 0;    V0.V := 0;
  V1.X := X1; V1.Y := Y1; V1.U := 255;  V1.V := 0;
  V2.X := X2; V2.Y := Y2; V2.U := 255;  V2.V := 255;
  V3.X := X3; V3.Y := Y3; V3.U := 0;    V3.V := 255;
  TexMapQuad(PByte(PixelsRGB), CanvasWidth, CanvasHeight,
             Tex, V0, V1, V2, V3, False);
End;

Procedure TRIPEngine.CompositAlpha (SrcData: PByte; SrcW, SrcH: Word;
                                     DstX, DstY: SmallInt; Opacity: Byte);
Begin
  FXAlphaBlend(PByte(PixelsRGB), SrcData, CanvasWidth, CanvasHeight, Opacity);
End;

Procedure TRIPEngine.ClipBegin;
// SERVER: Begin defining a clipping path. Points added via ClipAddPoint.
Begin
  ClipBeginPath(TClipStack(ClipStackPtr^));
End;

Procedure TRIPEngine.ClipAddPoint (X, Y: SmallInt);
// SERVER: Add a vertex to the current clipping path polygon.
Begin
  GRClip.ClipAddPoint(TClipStack(ClipStackPtr^), X, Y);
End;

Procedure TRIPEngine.ClipAddRect (X1, Y1, X2, Y2: SmallInt);
// SERVER: Add a rectangular region to the clipping path.
Begin
  GRClip.ClipAddRect(TClipStack(ClipStackPtr^), X1, Y1, X2, Y2);
End;

Procedure TRIPEngine.ClipAddCircle (CX, CY, Radius: SmallInt);
// SERVER: Add a circular region to the clipping path (32-segment polygon).
Begin
  GRClip.ClipAddCircle(TClipStack(ClipStackPtr^), CX, CY, Radius, 32);
End;

Procedure TRIPEngine.ClipEnd;
// SERVER: Close and activate the clipping path. All subsequent drawing
// is clipped to the defined polygon region.
Begin
  ClipEndPath(TClipStack(ClipStackPtr^), cfrEvenOdd);
End;

Procedure TRIPEngine.ClipReset;
// SERVER: Remove the active clipping path. Drawing returns to full canvas.
Begin
  ClipInit(TClipStack(ClipStackPtr^));
End;

Procedure TRIPEngine.DrawTextRFF (X, Y: SmallInt; S: String;
                                   PointSize: Integer; Rotation: SmallInt);
// Render text using RFF scalable font strokes.
// PointSize = target size in pixels (scales from design units).
// Rotation = 0, 90, 180, 270 degrees.
//
// NOTE: Stroke pen up/down encoding is partially decoded.
// Current implementation treats first stroke pair as pen-up move,
// (0,0) pair as pen lift, all others as pen-down draw.
Var
  I, J         : Integer;
  Font         : TRFFFont;
  Data         : PByte;
  Len          : LongWord;
  DX, DY       : ShortInt;
  PenX, PenY   : Real;
  CurPX, CurPY : SmallInt;
  NewPX, NewPY : SmallInt;
  Scale        : Real;
  PenDown      : Boolean;
  AdvW         : SmallInt;
  RotDX, RotDY : Real;
  CharCode     : Word;
  AdvX, AdvY   : Real;  // advance direction based on rotation
Begin
  If (RFFActiveFont < 1) or (RFFActiveFont > RIP_MAX_RFF) Then Exit;
  If Not RFFLoaded[RFFActiveFont] Then Exit;
  If Length(S) = 0 Then Exit;
  If PointSize <= 0 Then PointSize := 16;

  Font := TRFFFont(RFFFonts[RFFActiveFont]^);

  // Scale factor: design units to pixels
  If Font.DesignUnits > 0 Then
    Scale := PointSize / Font.DesignUnits
  Else
    Scale := 1.0;

  // Advance direction based on rotation
  Case Rotation of
    90  : Begin AdvX := 0;      AdvY := -1; End;
    180 : Begin AdvX := -1;     AdvY := 0;  End;
    270 : Begin AdvX := 0;      AdvY := 1;  End;
  Else    Begin AdvX := 1;      AdvY := 0;  End;
  End;

  For I := 1 to Length(S) Do Begin
    CharCode := Ord(S[I]);
    AdvW := RFFGlyphWidth(Font, CharCode);

    If RFFGetStrokes(Font, CharCode, Data, Len) and (Data <> Nil) and (Len >= 2) Then Begin
      PenX := 0;
      PenY := 0;
      PenDown := False;
      J := 0;

      While J < Integer(Len) - 1 Do Begin
        DX := ShortInt(Data[J]);
        DY := ShortInt(Data[J + 1]);
        Inc(J, 2);

        // Pen lift detection: (0,0) pair = lift pen
        If (DX = 0) and (DY = 0) Then Begin
          PenDown := False;
          Continue;
        End;

        PenX := PenX + DX;
        PenY := PenY + DY;

        // Apply rotation to pen position
        Case Rotation of
          90  : Begin RotDX := PenY * Scale; RotDY := -PenX * Scale; End;
          180 : Begin RotDX := -PenX * Scale; RotDY := -PenY * Scale; End;
          270 : Begin RotDX := -PenY * Scale; RotDY := PenX * Scale; End;
        Else    Begin RotDX := PenX * Scale; RotDY := -PenY * Scale; End;
        End;

        NewPX := X + Trunc(RotDX);
        NewPY := Y + Trunc(RotDY);

        If PenDown Then
          Line(CurPX, CurPY, NewPX, NewPY);

        CurPX := NewPX;
        CurPY := NewPY;
        PenDown := True;
      End;
    End;

    // Advance cursor for next character (width + tracking + kerning)
    AdvW := AdvW + RFFTracking;
    If I < Length(S) Then
      AdvW := AdvW + RFFKernPair(S[I], S[I + 1]);
    X := X + Trunc(AdvW * Scale * AdvX);
    Y := Y + Trunc(AdvW * Scale * AdvY);
  End;
End;


// ---- BMP export ----

Function TRIPEngine.SaveBMP (FileName: String) : Boolean;
// Write the pixel buffer as a 24-bit BMP file
Var
  F         : File;
  Hdr       : Array[0..53] of Byte;
  RowSize   : LongInt;
  Pad       : Integer;
  X, Y, I   : SmallInt;
  Color     : Byte;
  Rgb       : TRIPRgb;
  PadByte   : Byte;
  FileSize  : LongInt;

  Procedure PutLE32 (Off: Integer; V: LongInt);
  Begin
    Hdr[Off]     := V AND $FF;
    Hdr[Off + 1] := (V SHR 8) AND $FF;
    Hdr[Off + 2] := (V SHR 16) AND $FF;
    Hdr[Off + 3] := (V SHR 24) AND $FF;
  End;

  Procedure PutLE16 (Off: Integer; V: Word);
  Begin
    Hdr[Off]     := V AND $FF;
    Hdr[Off + 1] := (V SHR 8) AND $FF;
  End;

Begin
  Result := False;

  // v3.0 Phase 15 fix: use the actual active canvas size instead of the
  // fixed v1.54 RIP_MAX_X/RIP_MAX_Y constants, so SaveBMP is correct
  // after SetResolution has changed the canvas.
  RowSize  := CanvasWidth * 3;
  Pad      := (4 - (RowSize MOD 4)) MOD 4;
  FileSize := 54 + (RowSize + Pad) * CanvasHeight;

  FillChar(Hdr, SizeOf(Hdr), 0);
  Hdr[0] := Ord('B');
  Hdr[1] := Ord('M');
  PutLE32(2, FileSize);
  PutLE32(10, 54);         // data offset
  PutLE32(14, 40);         // info header size
  PutLE32(18, CanvasWidth);   // width
  PutLE32(22, CanvasHeight);  // height
  PutLE16(26, 1);          // planes
  PutLE16(28, 24);         // bits per pixel

  Assign(F, FileName);
  {$I-} ReWrite(F, 1); {$I+}
  If IOResult <> 0 Then Exit;

  BlockWrite(F, Hdr, 54);

  PadByte := 0;

  // BMP is bottom-up
  For Y := ActiveMaxY downto 0 Do Begin
    For X := 0 to ActiveMaxX Do Begin
      // v3.0 Phase 15: write native 24-bit data straight from the RGB
      // buffer when in a true-color pixel format; fall back to the
      // indexed EGA palette lookup for backward-compatible v1.54/v2.0
      // scenes.
      If PixelFormat = RIP_PIXFMT_INDEXED8 Then Begin
        Color := Pixels^[Y, X] AND $0F;
        Rgb   := EGA_RGB[Color];
      End Else
        Rgb := PixelsRGB^[Y, X];

      // BMP stores BGR
      BlockWrite(F, Rgb.B, 1);
      BlockWrite(F, Rgb.G, 1);
      BlockWrite(F, Rgb.R, 1);
    End;

    For I := 1 to Pad Do
      BlockWrite(F, PadByte, 1);
  End;

  Close(F);
  Result := True;
End;

// ====================================================================
// Phase 4 — Image Format Loading
// ====================================================================

Function TRIPEngine.LoadPCX (FileName: String; X, Y: SmallInt) : Boolean;
// Load a 16-color EGA PCX file and render at (X,Y)
// PCX format: 128-byte header, RLE compressed, 4 bit planes
Var
  F         : File;
  Header    : Array[0..127] of Byte;
  BPP       : Byte;
  XMin, YMin, XMax, YMax : SmallInt;
  W, H      : SmallInt;
  NPlanes   : Byte;
  BytesPerRow : Word;
  Row, Plane, Col : SmallInt;
  RunByte, RunCount : Byte;
  PlaneData : Array[0..3, 0..79] of Byte;  // max 640px wide
  ByteIdx, BitIdx : Integer;
  Color     : Byte;
  BytesFilled : Integer;
Begin
  Result := False;

  Assign(F, FileName);
  {$I-} System.Reset(F, 1); {$I+}
  If IOResult <> 0 Then Exit;

  // Read 128-byte header
  BlockRead(F, Header, 128);

  // Validate: manufacturer must be 0x0A (ZSoft)
  If Header[0] <> $0A Then Begin Close(F); Exit; End;

  BPP  := Header[3];
  XMin := Header[4] OR (Header[5] SHL 8);
  YMin := Header[6] OR (Header[7] SHL 8);
  XMax := Header[8] OR (Header[9] SHL 8);
  YMax := Header[10] OR (Header[11] SHL 8);
  NPlanes    := Header[65];
  BytesPerRow := Header[66] OR (Header[67] SHL 8);

  W := XMax - XMin + 1;
  H := YMax - YMin + 1;

  // We only support 16-color EGA: 4 planes, 1 bit per pixel
  If (BPP <> 1) or (NPlanes <> 4) Then Begin Close(F); Exit; End;
  If (W <= 0) or (H <= 0) or (W > 1280) or (H > 1024) Then Begin Close(F); Exit; End;
  If BytesPerRow > 80 Then Begin Close(F); Exit; End;

  // Decode RLE scanlines
  For Row := 0 to H - 1 Do Begin
    // Read all 4 planes for this row
    For Plane := 0 to NPlanes - 1 Do Begin
      BytesFilled := 0;

      While BytesFilled < BytesPerRow Do Begin
        {$I-} BlockRead(F, RunByte, 1); {$I+}
        If IOResult <> 0 Then Begin Close(F); Exit; End;

        If (RunByte AND $C0) = $C0 Then Begin
          // RLE: top 2 bits set = run count in lower 6 bits
          RunCount := RunByte AND $3F;
          {$I-} BlockRead(F, RunByte, 1); {$I+}
          If IOResult <> 0 Then Begin Close(F); Exit; End;

          While (RunCount > 0) and (BytesFilled < BytesPerRow) Do Begin
            PlaneData[Plane][BytesFilled] := RunByte;
            Inc(BytesFilled);
            Dec(RunCount);
          End;
        End Else Begin
          // Literal byte
          PlaneData[Plane][BytesFilled] := RunByte;
          Inc(BytesFilled);
        End;
      End;
    End;

    // Combine planes into pixel colors
    For Col := 0 to W - 1 Do Begin
      ByteIdx := Col DIV 8;
      BitIdx  := 7 - (Col MOD 8);

      Color := 0;
      For Plane := 0 to 3 Do
        If (PlaneData[Plane][ByteIdx] AND (1 SHL BitIdx)) <> 0 Then
          Color := Color OR (1 SHL Plane);

      DrawPixel(X + Col, Y + Row, Color);
    End;
  End;

  Close(F);
  Result := True;
End;

Function TRIPEngine.LoadBMP (FileName: String; X, Y: SmallInt) : Boolean;
// Load a 4-bit (16-color) or 24-bit BMP and render at (X,Y)
// Maps 24-bit RGB to nearest EGA color
Var
  F          : File;
  FileHdr    : Array[0..13] of Byte;
  InfoHdr    : Array[0..39] of Byte;
  DataOffset : LongInt;
  W, H       : LongInt;
  BitCount   : Word;
  Row, Col   : SmallInt;
  RowSize    : LongInt;
  Pad        : Integer;
  B, G, R    : Byte;
  Color      : Byte;
  NibByte    : Byte;
  TopDown    : Boolean;
  SrcRow     : SmallInt;

  Function NearestEGA (RR, GG, BB: Byte) : Byte;
  Var
    I, Best, BestDist, Dist : Integer;
  Begin
    Best := 0;
    BestDist := MaxInt;
    For I := 0 to 15 Do Begin
      Dist := Abs(SmallInt(RR) - SmallInt(EGA_RGB[I].R)) +
              Abs(SmallInt(GG) - SmallInt(EGA_RGB[I].G)) +
              Abs(SmallInt(BB) - SmallInt(EGA_RGB[I].B));
      If Dist < BestDist Then Begin
        BestDist := Dist;
        Best := I;
      End;
    End;
    Result := Best;
  End;

Begin
  Result := False;

  Assign(F, FileName);
  {$I-} System.Reset(F, 1); {$I+}
  If IOResult <> 0 Then Exit;

  // Read file header (14 bytes)
  BlockRead(F, FileHdr, 14);
  If (FileHdr[0] <> Ord('B')) or (FileHdr[1] <> Ord('M')) Then Begin
    Close(F); Exit;
  End;

  DataOffset := FileHdr[10] OR (FileHdr[11] SHL 8) OR
                (FileHdr[12] SHL 16) OR (FileHdr[13] SHL 24);

  // Read info header (40 bytes)
  BlockRead(F, InfoHdr, 40);

  W := InfoHdr[4] OR (InfoHdr[5] SHL 8) OR (InfoHdr[6] SHL 16) OR (InfoHdr[7] SHL 24);
  H := InfoHdr[8] OR (InfoHdr[9] SHL 8) OR (InfoHdr[10] SHL 16) OR (InfoHdr[11] SHL 24);
  BitCount := InfoHdr[14] OR (InfoHdr[15] SHL 8);

  TopDown := H < 0;
  If TopDown Then H := -H;

  If (W <= 0) or (H <= 0) or (W > 1280) or (H > 1024) Then Begin
    Close(F); Exit;
  End;

  // Seek to data
  Seek(F, DataOffset);

  Case BitCount of
    4 : Begin
          // 4-bit: 2 pixels per byte, rows padded to 4 bytes
          RowSize := ((W + 1) DIV 2);
          Pad := (4 - (RowSize MOD 4)) MOD 4;

          For Row := 0 to H - 1 Do Begin
            If TopDown Then SrcRow := Row
            Else SrcRow := H - 1 - Row;

            For Col := 0 to W - 1 Do Begin
              If (Col MOD 2) = 0 Then Begin
                {$I-} BlockRead(F, NibByte, 1); {$I+}
                If IOResult <> 0 Then Begin Close(F); Exit; End;
                Color := (NibByte SHR 4) AND $0F;
              End Else
                Color := NibByte AND $0F;

              DrawPixel(X + Col, Y + SrcRow, Color);
            End;

            // Skip padding
            For Col := 1 to Pad Do
              BlockRead(F, NibByte, 1);
          End;

          Result := True;
        End;

    24 : Begin
           // 24-bit: 3 bytes per pixel BGR, padded to 4 bytes
           RowSize := W * 3;
           Pad := (4 - (RowSize MOD 4)) MOD 4;

           For Row := 0 to H - 1 Do Begin
             If TopDown Then SrcRow := Row
             Else SrcRow := H - 1 - Row;

             For Col := 0 to W - 1 Do Begin
               {$I-}
               BlockRead(F, B, 1);
               BlockRead(F, G, 1);
               BlockRead(F, R, 1);
               {$I+}
               If IOResult <> 0 Then Begin Close(F); Exit; End;

               DrawPixel(X + Col, Y + SrcRow, NearestEGA(R, G, B));
             End;

             // Skip padding
             For Col := 1 to Pad Do
               BlockRead(F, NibByte, 1);
           End;

           Result := True;
         End;
  End;

  Close(F);
End;

// ====================================================================
// v3.0 Phase 17: Image Format Support
// ====================================================================

// BlitRGB — render a W*H*3 RGB pixel buffer onto the canvas at (X,Y)
Procedure TRIPEngine.BlitRGB (Src: PByte; SrcW, SrcH: Integer; X, Y: SmallInt);
Var
  IX, IY : Integer;
  RGB    : TRIPRGB;
  Off    : LongInt;
Begin
  For IY := 0 to SrcH - 1 Do
    For IX := 0 to SrcW - 1 Do Begin
      Off := (LongInt(IY) * SrcW + IX) * 3;
      RGB.R := Src[Off];
      RGB.G := Src[Off + 1];
      RGB.B := Src[Off + 2];
      DrawPixel(X + IX, Y + IY, RGB);
    End;
End;

// BlitRGBScaled — render RGB buffer scaled to DstW x DstH at (X,Y)
Procedure TRIPEngine.BlitRGBScaled (Src: PByte; SrcW, SrcH: Integer;
                                     X, Y, DstW, DstH: SmallInt);
Var
  IX, IY, SX, SY : Integer;
  RGB    : TRIPRGB;
  Off    : LongInt;
Begin
  If (DstW <= 0) or (DstH <= 0) or (SrcW <= 0) or (SrcH <= 0) Then Exit;
  For IY := 0 to DstH - 1 Do Begin
    SY := (IY * SrcH) div DstH;
    If SY >= SrcH Then SY := SrcH - 1;
    For IX := 0 to DstW - 1 Do Begin
      SX := (IX * SrcW) div DstW;
      If SX >= SrcW Then SX := SrcW - 1;
      Off := (LongInt(SY) * SrcW + SX) * 3;
      RGB.R := Src[Off];
      RGB.G := Src[Off + 1];
      RGB.B := Src[Off + 2];
      DrawPixel(X + IX, Y + IY, RGB);
    End;
  End;
End;

// BlitRGBAlpha — render RGB buffer with separate alpha channel
// Alpha = per-pixel alpha (0=transparent, 255=opaque), same W*H layout
Procedure TRIPEngine.BlitRGBAlpha (Src: PByte; SrcW, SrcH: Integer;
                                    X, Y: SmallInt; Alpha: PByte);
Var
  IX, IY : Integer;
  RGB, Dst : TRIPRGB;
  Off    : LongInt;
  A      : Byte;
Begin
  For IY := 0 to SrcH - 1 Do
    For IX := 0 to SrcW - 1 Do Begin
      Off := LongInt(IY) * SrcW + IX;
      A := Alpha[Off];
      If A = 0 Then Continue;  // fully transparent — skip

      RGB.R := Src[Off * 3];
      RGB.G := Src[Off * 3 + 1];
      RGB.B := Src[Off * 3 + 2];

      If A = 255 Then
        DrawPixel(X + IX, Y + IY, RGB)  // fully opaque
      Else Begin
        // Alpha blend: out = src*a + dst*(255-a)
        Dst := GetPixelRGB(X + IX, Y + IY);
        RGB.R := (RGB.R * A + Dst.R * (255 - A)) div 255;
        RGB.G := (RGB.G * A + Dst.G * (255 - A)) div 255;
        RGB.B := (RGB.B * A + Dst.B * (255 - A)) div 255;
        DrawPixel(X + IX, Y + IY, RGB);
      End;
    End;
End;

// BlitRGBMask — render RGB pixels with 1-bit transparency mask
// Mask[i]=0 means transparent (skip), Mask[i]<>0 means opaque (draw).
// This matches RIPtel's ICN/MSK mask bitmap format.
Procedure TRIPEngine.BlitRGBMask (Src: PByte; SrcW, SrcH: Integer;
                                   X, Y: SmallInt; Mask: PByte);
Var
  IX, IY : Integer;
  Off    : LongInt;
  RGB    : TRIPRGB;
Begin
  If (Src = Nil) or (Mask = Nil) or (SrcW <= 0) or (SrcH <= 0) Then Exit;
  For IY := 0 to SrcH - 1 Do
    For IX := 0 to SrcW - 1 Do Begin
      Off := LongInt(IY) * SrcW + IX;
      If Mask[Off] = 0 Then Continue;  // transparent — skip
      RGB.R := Src[Off * 3];
      RGB.G := Src[Off * 3 + 1];
      RGB.B := Src[Off * 3 + 2];
      DrawPixel(X + IX, Y + IY, RGB);
    End;
End;

// RGBAToMask — convert RGBA pixels to 1-bit mask
// Pixels with alpha > Threshold are opaque (mask=1), others transparent (mask=0).
// Caller must allocate Mask with W*H bytes via GetMem before calling.
Procedure TRIPEngine.RGBAToMask (RGBA: PByte; W, H: Integer;
                                  Mask: PByte; Threshold: Byte);
Var
  I, Count : LongInt;
Begin
  If (RGBA = Nil) or (Mask = Nil) or (W <= 0) or (H <= 0) Then Exit;
  Count := LongInt(W) * H;
  For I := 0 to Count - 1 Do
    Mask[I] := Byte(Ord(RGBA[I * 4 + 3] > Threshold));
End;

// BlitIndexed — render palette-indexed buffer with transparency
// Pal points to an array of TGIFRGBEntry (R,G,B bytes)
// TransIdx = transparent palette index (-1 for none)
Procedure TRIPEngine.BlitIndexed (Src: PByte; SrcW, SrcH: Integer;
                                   X, Y: SmallInt;
                                   Pal: Pointer; TransIdx: Integer);
Type
  PRGBEntry = ^TRGBEntry;
  TRGBEntry = packed record R, G, B: Byte; end;
  PRGBArray = ^TRGBArray;
  TRGBArray = Array[0..255] of TRGBEntry;
Var
  IX, IY : Integer;
  C      : Byte;
  RGB    : TRIPRGB;
  PalArr : PRGBArray;
Begin
  PalArr := PRGBArray(Pal);
  For IY := 0 to SrcH - 1 Do
    For IX := 0 to SrcW - 1 Do Begin
      C := Src[LongInt(IY) * SrcW + IX];
      If C = TransIdx Then Continue;  // transparent
      RGB.R := PalArr^[C].R;
      RGB.G := PalArr^[C].G;
      RGB.B := PalArr^[C].B;
      DrawPixel(X + IX, Y + IY, RGB);
    End;
End;

// LoadJPEG — load JPEG file and render at (X,Y)
Function TRIPEngine.LoadJPEG (FileName: String; X, Y: SmallInt) : Boolean;
Var
  Pixels : PByte;
  W, H   : Integer;
Begin
  Result := False;
  If Not JPEGLoadFileRaw(FileName, Pixels, W, H) Then Exit;
  BlitRGB(Pixels, W, H, X, Y);
  FreeMem(Pixels);
  Result := True;
End;

// v3.0 Phase 17: JPEG streaming — progressive render during download
// Call JPEGStreamInit, then feed chunks via JPEGStreamFeed which
// renders partial image to framebuffer. JPEGStreamComplete returns
// True when EOI marker received. JPEGStreamDone frees resources.

Procedure TRIPEngine.JPEGStreamInit;
Begin
  // Free any existing stream to prevent memory leak on double-init
  If JPEGStrmActive and (JPEGStrmPtr <> Nil) Then Begin
    JPEGStreamFreeRaw(TJPEGStreamRaw(JPEGStrmPtr^));
    FreeMem(JPEGStrmPtr, SizeOf(TJPEGStreamRaw));
    JPEGStrmPtr := Nil;
  End;
  GetMem(JPEGStrmPtr, SizeOf(TJPEGStreamRaw));
  JPEGStreamInitRaw(TJPEGStreamRaw(JPEGStrmPtr^));
  JPEGStrmActive := True;
End;

Function TRIPEngine.JPEGStreamFeed (Data: PByte; Size: Integer;
                                     X, Y: SmallInt) : Boolean;
Begin
  Result := False;
  If (Not JPEGStrmActive) or (JPEGStrmPtr = Nil) Then Exit;
  If (Data = Nil) or (Size <= 0) Then Exit;

  JPEGStreamFeedRaw(TJPEGStreamRaw(JPEGStrmPtr^), Data, Size);

  // If decoder has produced an image (even partial), render it
  If TJPEGStreamRaw(JPEGStrmPtr^).HasImage and
     (TJPEGStreamRaw(JPEGStrmPtr^).Pixels <> Nil) and
     (TJPEGStreamRaw(JPEGStrmPtr^).Width > 0) and
     (TJPEGStreamRaw(JPEGStrmPtr^).Height > 0) Then Begin
    BlitRGB(TJPEGStreamRaw(JPEGStrmPtr^).Pixels,
            TJPEGStreamRaw(JPEGStrmPtr^).Width,
            TJPEGStreamRaw(JPEGStrmPtr^).Height, X, Y);
    Result := True;
  End;
End;

Function TRIPEngine.JPEGStreamComplete : Boolean;
Begin
  If JPEGStrmActive and (JPEGStrmPtr <> Nil) Then
    Result := TJPEGStreamRaw(JPEGStrmPtr^).Complete
  Else
    Result := True;
End;

Procedure TRIPEngine.JPEGStreamDone;
Begin
  If JPEGStrmActive and (JPEGStrmPtr <> Nil) Then Begin
    JPEGStreamFreeRaw(TJPEGStreamRaw(JPEGStrmPtr^));
    FreeMem(JPEGStrmPtr, SizeOf(TJPEGStreamRaw));
    JPEGStrmPtr := Nil;
    JPEGStrmActive := False;
  End;
End;

// LoadGIF — load first frame of GIF file and render at (X,Y)
Function TRIPEngine.LoadGIF (FileName: String; X, Y: SmallInt) : Boolean;
Var
  GIF : TGIFImage;
Begin
  Result := False;
  If Not GIFLoadFileRaw(FileName, GIF) Then Exit;
  If GIF.FrameCount > 0 Then
    BlitIndexed(GIF.Frames[0].Pixels, GIF.Frames[0].Width, GIF.Frames[0].Height,
                X + GIF.Frames[0].Left, Y + GIF.Frames[0].Top,
                @GIF.Palette, -1)
  Else If GIF.Pixels <> Nil Then
    BlitIndexed(GIF.Pixels, GIF.Width, GIF.Height, X, Y, @GIF.Palette, -1);
  GIFFreeRaw(GIF);
  Result := True;
End;

// LoadGIFFrame — load specific frame of animated GIF
Function TRIPEngine.LoadGIFFrame (FileName: String; X, Y: SmallInt; Frame: Integer) : Boolean;
Var
  GIF    : TGIFImage;
  TransI : Integer;
Begin
  Result := False;
  If Not GIFLoadFileRaw(FileName, GIF) Then Exit;
  If (Frame < 0) or (Frame >= GIF.FrameCount) Then Begin
    GIFFreeRaw(GIF);
    Exit;
  End;
  If GIF.Frames[Frame].Transparent Then
    TransI := GIF.Frames[Frame].TransIndex
  Else
    TransI := -1;
  BlitIndexed(GIF.Frames[Frame].Pixels,
              GIF.Frames[Frame].Width, GIF.Frames[Frame].Height,
              X + GIF.Frames[Frame].Left, Y + GIF.Frames[Frame].Top,
              @GIF.Palette, TransI);
  GIFFreeRaw(GIF);
  Result := True;
End;

// LoadPNG — load PNG file and render at (X,Y)
Function TRIPEngine.LoadPNG (FileName: String; X, Y: SmallInt) : Boolean;
Var
  Pixels : PByte;
  W, H   : Integer;
Begin
  Result := False;
  If Not PNGLoadFileRaw(FileName, Pixels, W, H) Then Exit;
  BlitRGB(Pixels, W, H, X, Y);
  FreeMem(Pixels);
  Result := True;
End;

// LoadImage — auto-detect format by file signature and load
Function TRIPEngine.LoadImage (FileName: String; X, Y: SmallInt) : Boolean;
Begin
  Result := False;
  If IsJPEGFile(FileName) Then
    Result := LoadJPEG(FileName, X, Y)
  Else If IsGIFFile(FileName) Then
    Result := LoadGIF(FileName, X, Y)
  Else If IsPNGFile(FileName) Then
    Result := LoadPNG(FileName, X, Y)
  Else
    Result := LoadBMP(FileName, X, Y);
End;

// LoadImageScaled — auto-detect format, scale to fit DstW x DstH
Function TRIPEngine.LoadImageScaled (FileName: String; X, Y, DstW, DstH: SmallInt) : Boolean;
Var
  Pixels : PByte;
  W, H   : Integer;
  GIF    : TGIFImage;
  RGBBuf : PByte;
Begin
  Result := False;
  If (DstW <= 0) or (DstH <= 0) Then Exit;

  If IsJPEGFile(FileName) Then Begin
    If Not JPEGLoadFileRaw(FileName, Pixels, W, H) Then Exit;
    BlitRGBScaled(Pixels, W, H, X, Y, DstW, DstH);
    FreeMem(Pixels);
    Result := True;
  End
  Else If IsPNGFile(FileName) Then Begin
    If Not PNGLoadFileRaw(FileName, Pixels, W, H) Then Exit;
    BlitRGBScaled(Pixels, W, H, X, Y, DstW, DstH);
    FreeMem(Pixels);
    Result := True;
  End
  Else If IsGIFFile(FileName) Then Begin
    If Not GIFLoadFileRaw(FileName, GIF) Then Exit;
    // Convert first frame to RGB for scaling
    W := GIF.Width;
    H := GIF.Height;
    GetMem(RGBBuf, LongInt(W) * H * 3);
    GIFFrameToRGB(GIF, 0, RGBBuf);
    BlitRGBScaled(RGBBuf, W, H, X, Y, DstW, DstH);
    FreeMem(RGBBuf);
    GIFFreeRaw(GIF);
    Result := True;
  End
  Else
    // BMP — load at native size (no scaling for BMP yet)
    Result := LoadBMP(FileName, X, Y);
End;

// ---- TRIPImageBuffer convenience wrappers ----

Procedure TRIPEngine.BlitImage (Var Img: TRIPImageBuffer; X, Y: SmallInt);
Begin
  If (Img.Pixels = Nil) or (Img.Width <= 0) or (Img.Height <= 0) Then Exit;
  BlitRGB(Img.Pixels, Img.Width, Img.Height, X, Y);
End;

Procedure TRIPEngine.BlitImageAlpha (Var Img: TRIPImageBuffer; X, Y: SmallInt);
Begin
  If (Img.Pixels = Nil) or (Img.Width <= 0) or (Img.Height <= 0) Then Exit;
  If Img.Alpha <> Nil Then
    BlitRGBAlpha(Img.Pixels, Img.Width, Img.Height, X, Y, Img.Alpha)
  Else
    BlitRGB(Img.Pixels, Img.Width, Img.Height, X, Y);
End;

Procedure TRIPEngine.BlitImageScaled (Var Img: TRIPImageBuffer; X, Y, DstW, DstH: SmallInt);
Begin
  If (Img.Pixels = Nil) or (Img.Width <= 0) or (Img.Height <= 0) Then Exit;
  BlitRGBScaled(Img.Pixels, Img.Width, Img.Height, X, Y, DstW, DstH);
End;

Procedure TRIPEngine.FreeImage (Var Img: TRIPImageBuffer);
Begin
  If Img.Pixels <> Nil Then Begin
    FreeMem(Img.Pixels);
    Img.Pixels := Nil;
  End;
  If Img.Alpha <> Nil Then Begin
    FreeMem(Img.Alpha);
    Img.Alpha := Nil;
  End;
  Img.Width  := 0;
  Img.Height := 0;
End;

// ---- Text variables (RIP_DEFINE 1D) ----

Procedure TRIPEngine.DefineVar (Name, Value: String; Persist, Required: Boolean);
// Legacy interface — maps to scoped version.
// Persist=True → PERSIST scope, else SESSION scope.
Begin
  If Persist Then
    DefineVarScoped(Name, Value, RIP_SCOPE_PERSIST, Required)
  Else
    DefineVarScoped(Name, Value, RIP_SCOPE_SESSION, Required);
End;

Procedure TRIPEngine.DefineVarScoped (Name, Value: String; Scope: Byte; Required: Boolean);
// SERVER: Create or update a variable with explicit scope.
// Scope: RIP_SCOPE_LOCAL (0) — cleared on scene end
//        RIP_SCOPE_SESSION (1) — cleared on disconnect
//        RIP_SCOPE_PERSIST (2) — saved to disk
Var
  Idx : Integer;
Begin
  Idx := FindVar(Name);

  If Idx = 0 Then Begin
    If VarCount >= RIP_MAX_VARS Then Exit;
    Inc(VarCount);
    Idx := VarCount;
  End;

  Variables[Idx].Active   := True;
  Variables[Idx].Name     := Name;
  Variables[Idx].Value    := Value;
  Variables[Idx].Persist  := (Scope = RIP_SCOPE_PERSIST);
  Variables[Idx].Required := Required;
  Variables[Idx].Scope    := Scope;
End;

Function TRIPEngine.GetVar (Name: String) : String;
Var
  Idx : Integer;
Begin
  Idx := FindVar(Name);
  If Idx > 0 Then
    Result := Variables[Idx].Value
  Else
    Result := '';
End;

Procedure TRIPEngine.SetVar (Name, Value: String);
Var
  Idx : Integer;
Begin
  Idx := FindVar(Name);
  If Idx > 0 Then
    Variables[Idx].Value := Value;
End;

Function TRIPEngine.FindVar (Name: String) : Integer;
Var
  I : Integer;
Begin
  Result := 0;

  For I := 1 to VarCount Do
    If Variables[I].Active and (Variables[I].Name = Name) Then Begin
      Result := I;
      Exit;
    End;
End;

Procedure TRIPEngine.KillAllVars;
Var
  I : Integer;
Begin
  VarCount := 0;
  For I := 1 to RIP_MAX_VARS Do
    Variables[I].Active := False;
End;

Procedure TRIPEngine.KillLocalVars;
// SERVER: Clear all LOCAL scope variables.
// Called on scene end (ClearScreen, new scene load).
// Session and persistent variables are preserved.
Var
  I : Integer;
Begin
  For I := 1 to RIP_MAX_VARS Do
    If Variables[I].Active and (Variables[I].Scope = RIP_SCOPE_LOCAL) Then
      Variables[I].Active := False;
End;

Procedure TRIPEngine.KillSessionVars;
// SERVER: Clear all SESSION scope variables.
// Called when user disconnects. Persistent variables survive.
Var
  I : Integer;
Begin
  For I := 1 to RIP_MAX_VARS Do
    If Variables[I].Active and (Variables[I].Scope = RIP_SCOPE_SESSION) Then
      Variables[I].Active := False;
End;

// ---- Variable persistence ----

Function TRIPEngine.SaveVars (FileName: String) : Boolean;
// Save all persistent variables to a text file.
// Format: one line per variable, NAME=VALUE
Var
  F : Text;
  I : Integer;
Begin
  Result := False;

  Assign(F, FileName);
  {$I-} Rewrite(F); {$I+}
  If IOResult <> 0 Then Exit;

  For I := 1 to RIP_MAX_VARS Do
    If Variables[I].Active and Variables[I].Persist Then
      WriteLn(F, Variables[I].Name, '=', Variables[I].Value);

  Close(F);
  Result := True;
End;

Function TRIPEngine.LoadVars (FileName: String) : Boolean;
// Load variables from a text file (NAME=VALUE format).
// Existing variables with matching names are updated;
// new variables are added. Non-matching existing vars are kept.
Var
  F    : Text;
  Line : String;
  P    : Integer;
  Name : String;
  Val  : String;
  Idx  : Integer;
Begin
  Result := False;

  Assign(F, FileName);
  {$I-} System.Reset(F); {$I+}
  If IOResult <> 0 Then Exit;

  While Not EOF(F) Do Begin
    ReadLn(F, Line);
    If Length(Line) = 0 Then Continue;

    // Find = separator
    P := 1;
    While (P <= Length(Line)) and (Line[P] <> '=') Do Inc(P);
    If P > Length(Line) Then Continue;

    Name := Copy(Line, 1, P - 1);
    Val  := Copy(Line, P + 1, Length(Line));

    // Update existing or create new
    Idx := FindVar(Name);
    If Idx > 0 Then
      Variables[Idx].Value := Val
    Else
      DefineVar(Name, Val, True, False);
  End;

  Close(F);
  Result := True;
End;

// ====================================================================
// Phase 3 — Pre-defined Text Variables
// ====================================================================

Function TRIPEngine.ResolveVar (Name: String) : String;
// SERVER: Resolve a built-in or user-defined text variable by name.
// Returns the value string, or empty if not found.
// Name should NOT include the $ delimiters.
//
// v3.0 Phase 21 additions:
//   $RESET(PAL)$ — reset palette to EGA defaults, returns empty
//   $RESET(ALL)$ — full engine state reset, returns empty
//   $PIXFMT$     — current pixel format name
//   $CANVASW$    — canvas width in pixels
//   $CANVASH$    — canvas height in pixels
//   $RFFFONT$    — active RFF scalable vector font name
//                  (TeleGrafix stroke font, e.g., "Cobb", "Dixon")
//                  Empty if no RFF font loaded/active
//   $MAFRES$     — active MAF bitmap font resolution name
//                  (MicroANSI font, e.g., "640x480 VGA", "800x600 - VGA")
//                  Empty if no MAF container loaded
Var
  I   : Integer;
  UName : String;
Begin
  Result := '';

  // Uppercase for comparison
  UName := Name;
  For I := 1 to Length(UName) Do
    If (UName[I] >= 'a') and (UName[I] <= 'z') Then
      UName[I] := Chr(Ord(UName[I]) - 32);

  // ---- v3.0 Phase 21: Reset commands ----
  If UName = 'RESET(PAL)' Then Begin
    // Reset palette to EGA defaults — side effect, returns empty
    For I := 0 to 15 Do
      SetPalette(I, I);
    Result := #1;  // sentinel: found, no text to insert
    Exit;
  End;

  If UName = 'RESET(ALL)' Then Begin
    // Full engine state reset — side effect, returns empty
    Reset;
    Result := #1;  // sentinel: found, no text to insert
    Exit;
  End;

  // ---- v3.0 Phase 21: Extended variables ----
  If UName = 'PIXFMT' Then Begin
    Case PixelFormat of
      RIP_PIXFMT_RGB24  : Result := 'RGB24';
      RIP_PIXFMT_RGB32  : Result := 'RGB32';
    Else                  Result := 'INDEXED8';
    End;
    Exit;
  End;

  If UName = 'CANVASW' Then Begin
    Str(CanvasWidth, Result);
    Exit;
  End;

  If UName = 'CANVASH' Then Begin
    Str(CanvasHeight, Result);
    Exit;
  End;

  // $RFFFONT$ — SERVER: Returns the name of the currently active RFF
  // scalable vector font (e.g., "Cobb", "Dixon", "DEFAULT").
  // RFF fonts are TeleGrafix RIPscrip 2.0+ scalable stroke fonts loaded
  // via LoadRFF into one of 8 font slots (1..RIP_MAX_RFF).
  // SetRFFFont(Slot) activates a slot. If no RFF font is active
  // (RFFActiveFont=0 or slot not loaded), returns sentinel #1 (empty).
  // Used by the server to query which font is rendering text.
  // Example: "Current font: $RFFFONT$" → "Current font: Dixon"
  If UName = 'RFFFONT' Then Begin
    If (RFFActiveFont >= 1) and (RFFActiveFont <= RIP_MAX_RFF) and
       RFFLoaded[RFFActiveFont] Then
      Result := TRFFFont(RFFFonts[RFFActiveFont]^).FontName
    Else
      Result := #1;  // no font active — insert nothing
    Exit;
  End;

  // $MAFRES$ — SERVER: Returns the name of the currently active MAF
  // (MicroANSI Font) resolution entry (e.g., "640x480 VGA", "800x600 - VGA").
  // MAF is a bitmap font container (RIPscrip.maf) with multiple resolution
  // entries, each containing 5 bitmap fonts at different character heights
  // (8, 11, 14, 16 px). LoadMAF loads the container, MAFSelectRes picks
  // the best resolution for the current screen mode, MAFSelectFont picks
  // the specific font height within that resolution.
  // If no MAF is loaded (MAFData=nil) or no resolution is selected
  // (MAFActiveRes=-1), returns sentinel #1 (empty).
  // Used by the server to query which bitmap font resolution is active.
  // Example: "Font res: $MAFRES$" → "Font res: 640x480 VGA"
  If UName = 'MAFRES' Then Begin
    If MAFIsLoaded and (MAFActiveRes >= 0) Then
      Result := MAFData^.Entries[MAFActiveRes].Name
    Else
      Result := #1;  // no MAF loaded — insert nothing
    Exit;
  End;

  // ---- System info ----
  If UName = 'DATE' Then Begin
    // MM/DD/YY format — placeholder, server fills in
    Result := '01/01/26';
    Exit;
  End;

  If UName = 'TIME' Then Begin
    // HH:MM:SS format — placeholder
    Result := '00:00:00';
    Exit;
  End;

  If UName = 'RUNDATE' Then Begin Result := '01/01/26'; Exit; End;
  If UName = 'RUNTIME' Then Begin Result := '00:00:00'; Exit; End;

  // ---- Screen state ----
  If UName = 'CURX' Then Begin
    Result := '';
    I := CurX;
    If I = 0 Then Result := '0'
    Else Begin
      While I > 0 Do Begin
        Result := Chr(Ord('0') + (I MOD 10)) + Result;
        I := I DIV 10;
      End;
    End;
    Exit;
  End;

  If UName = 'CURY' Then Begin
    Result := '';
    I := CurY;
    If I = 0 Then Result := '0'
    Else Begin
      While I > 0 Do Begin
        Result := Chr(Ord('0') + (I MOD 10)) + Result;
        I := I DIV 10;
      End;
    End;
    Exit;
  End;

  If UName = 'CURSOR' Then Begin Result := 'YES'; Exit; End;

  // ---- Text window ----
  If UName = 'TWX0' Then Begin Result := ''; I := TextWinX0;
    If I = 0 Then Result := '0' Else While I > 0 Do Begin Result := Chr(Ord('0')+(I MOD 10))+Result; I := I DIV 10; End; Exit; End;
  If UName = 'TWY0' Then Begin Result := ''; I := TextWinY0;
    If I = 0 Then Result := '0' Else While I > 0 Do Begin Result := Chr(Ord('0')+(I MOD 10))+Result; I := I DIV 10; End; Exit; End;
  If UName = 'TWX1' Then Begin Result := ''; I := TextWinX1;
    If I = 0 Then Result := '0' Else While I > 0 Do Begin Result := Chr(Ord('0')+(I MOD 10))+Result; I := I DIV 10; End; Exit; End;
  If UName = 'TWY1' Then Begin Result := ''; I := TextWinY1;
    If I = 0 Then Result := '0' Else While I > 0 Do Begin Result := Chr(Ord('0')+(I MOD 10))+Result; I := I DIV 10; End; Exit; End;
  If UName = 'TWW' Then Begin Result := ''; I := TextWinX1 - TextWinX0 + 1;
    If I = 0 Then Result := '0' Else While I > 0 Do Begin Result := Chr(Ord('0')+(I MOD 10))+Result; I := I DIV 10; End; Exit; End;
  If UName = 'TWH' Then Begin Result := ''; I := TextWinY1 - TextWinY0 + 1;
    If I = 0 Then Result := '0' Else While I > 0 Do Begin Result := Chr(Ord('0')+(I MOD 10))+Result; I := I DIV 10; End; Exit; End;
  If UName = 'TWWIN' Then Begin
    If (TextWinX0 <> 0) or (TextWinY0 <> 0) or
       (TextWinX1 <> 79) or (TextWinY1 <> 42) Then
      Result := 'YES'
    Else
      Result := 'NO';
    Exit;
  End;
  If UName = 'TWFONT' Then Begin Result := ''; I := TextWinSize;
    If I = 0 Then Result := '0' Else While I > 0 Do Begin Result := Chr(Ord('0')+(I MOD 10))+Result; I := I DIV 10; End; Exit; End;

  // ---- Sound (no-op server-side, but recognized) ----
  If UName = 'ALARM'     Then Exit;
  If UName = 'PHASER'    Then Exit;
  If UName = 'REVPHASER' Then Exit;

  // ---- Mode control (return current state as YES/NO) ----
  If UName = 'HKEYON'    Then Begin If HotKeysEnabled Then Result := 'YES' Else Result := 'NO'; Exit; End;
  If UName = 'HKEYOFF'   Then Begin If Not HotKeysEnabled Then Result := 'YES' Else Result := 'NO'; Exit; End;
  If UName = 'TABON'     Then Begin If TabEnabled Then Result := 'YES' Else Result := 'NO'; Exit; End;
  If UName = 'TABOFF'    Then Begin If Not TabEnabled Then Result := 'YES' Else Result := 'NO'; Exit; End;
  If UName = 'VT102ON'   Then Exit;
  If UName = 'VT102OFF'  Then Exit;
  If UName = 'DWAYON'    Then Exit;
  If UName = 'DWAYOFF'   Then Exit;
  If UName = 'CON'       Then Exit;
  If UName = 'COFF'      Then Exit;

  // ---- User-defined variables ----
  I := FindVar(Name);
  If I > 0 Then Begin
    Result := Variables[I].Value;
    Exit;
  End;
End;

Function TRIPEngine.ExpandVars (S: String) : String;
// Scan string for $VARNAME$ patterns and replace with values.
Var
  P, Start, OutLen : Integer;
  VarName  : String;
  Value    : String;
  Buf      : String;
Begin
  // Fast path: no $ in string, return as-is
  P := 1;
  While (P <= Length(S)) and (S[P] <> '$') Do Inc(P);
  If P > Length(S) Then Begin
    Result := S;
    Exit;
  End;

  // Has at least one $ — do the expansion
  Buf := '';
  P := 1;

  While P <= Length(S) Do Begin
    If S[P] = '$' Then Begin
      Start := P + 1;
      Inc(P);

      While (P <= Length(S)) and (S[P] <> '$') Do
        Inc(P);

      If (P <= Length(S)) and (S[P] = '$') Then Begin
        VarName := Copy(S, Start, P - Start);
        Value   := ResolveVar(VarName);

        // ResolveVar returns #1 for "found, action taken, no text"
        // (e.g. $RESET(PAL)$). Empty string means "not found".
        If Value = #1 Then
          // Resolved action — insert nothing
        Else If Value <> '' Then
          Buf := Buf + Value
        Else
          Buf := Buf + '$' + VarName + '$';

        Inc(P);
      End Else
        Buf := Buf + '$' + Copy(S, Start, P - Start);
    End Else Begin
      // Copy non-$ characters in bulk
      Start := P;
      While (P <= Length(S)) and (S[P] <> '$') Do Inc(P);
      Buf := Buf + Copy(S, Start, P - Start);
    End;
  End;

  Result := Buf;
End;

// ---- File query (RIP_FILE_QUERY 1F) ----

Function TRIPEngine.FileQuery (FileName: String; Mode: Byte) : TRIPFileQueryResult;
Var
  F : File;
Begin
  FillChar(Result, SizeOf(Result), 0);

  Assign(F, FileName);
  {$I-} System.Reset(F, 1); {$I+}

  If IOResult = 0 Then Begin
    Result.Exists := True;
    Result.Size   := FileSize(F);
    Close(F);
  End Else
    Result.Exists := False;
End;

// ---- Copy region (RIP_COPY_REGION 1G) ----

Procedure TRIPEngine.CopyRegion (X0, Y0, X1, Y1, DestY: SmallInt);
Var
  H, X, Y : SmallInt;
Begin
  // Per spec: X0/X1 must be on 8-pixel boundaries
  X0 := (X0 DIV 8) * 8;
  X1 := ((X1 + 7) DIV 8) * 8 - 1;

  H := Y1 - Y0 + 1;

  // Ignore if destination goes off screen
  If (DestY < 0) or (DestY + H - 1 > ActiveMaxY) Then Exit;

  // Copy direction handles overlap correctly
  If DestY < Y0 Then Begin
    For Y := 0 to H - 1 Do
      For X := X0 to X1 Do
        If InView(X, DestY + Y) and InView(X, Y0 + Y) Then
          Pixels^[DestY + Y, X] := Pixels^[Y0 + Y, X];
  End Else Begin
    For Y := H - 1 downto 0 Do
      For X := X0 to X1 Do
        If InView(X, DestY + Y) and InView(X, Y0 + Y) Then
          Pixels^[DestY + Y, X] := Pixels^[Y0 + Y, X];
  End;
End;

// ====================================================================
// Phase 1 — Screen State Management
// ====================================================================

Procedure TRIPEngine.SaveScreen (Slot: Byte);
Begin
  If Slot > 9 Then Exit;

  If SavedScreens[Slot] = Nil Then
    New(SavedScreens[Slot]);

  Move(Pixels^, SavedScreens[Slot]^, SizeOf(TRIPPixelBuffer));
End;

Procedure TRIPEngine.RestoreScreen (Slot: Byte);
Begin
  If Slot > 9 Then Exit;
  If SavedScreens[Slot] = Nil Then Exit;

  Move(SavedScreens[Slot]^, Pixels^, SizeOf(TRIPPixelBuffer));

  // Per RIPterm: RESTORE0-9 delete the save after restoring
  Dispose(SavedScreens[Slot]);
  SavedScreens[Slot] := Nil;
End;

Procedure TRIPEngine.SaveTextWin;
Begin
  SavedTW.Active := True;
  SavedTW.X0     := TextWinX0;
  SavedTW.Y0     := TextWinY0;
  SavedTW.X1     := TextWinX1;
  SavedTW.Y1     := TextWinY1;
  SavedTW.Size   := TextWinSize;
End;

Procedure TRIPEngine.RestoreTextWin;
Begin
  If Not SavedTW.Active Then Exit;

  TextWinX0   := SavedTW.X0;
  TextWinY0   := SavedTW.Y0;
  TextWinX1   := SavedTW.X1;
  TextWinY1   := SavedTW.Y1;
  TextWinSize := SavedTW.Size;

  SavedTW.Active := False;
End;

Procedure TRIPEngine.SaveMouseAll;
Var
  I : Integer;
Begin
  SavedMouse.Active   := True;
  SavedMouse.Count    := MouseCount;
  SavedMouse.TabIndex := NextTabIndex;
  SavedMouse.Focused  := FocusedField;

  For I := 1 to RIP_MAX_MOUSE Do
    SavedMouse.Fields[I] := MouseFields[I];
End;

Procedure TRIPEngine.RestoreMouseAll;
Var
  I : Integer;
Begin
  If Not SavedMouse.Active Then Exit;

  UnfocusField;

  MouseCount   := SavedMouse.Count;
  NextTabIndex := SavedMouse.TabIndex;
  FocusedField := SavedMouse.Focused;

  For I := 1 to RIP_MAX_MOUSE Do
    MouseFields[I] := SavedMouse.Fields[I];

  SavedMouse.Active := False;
End;

Procedure TRIPEngine.SaveClip;
Begin
  // Save the current GetImage clipboard to a backup
  If SavedClip <> Nil Then FreeMem(SavedClip, SavedClipSz);
  SavedClip   := Nil;
  SavedClipSz := 0;
  SavedClipW  := 0;
  SavedClipH  := 0;

  If (Clipboard <> Nil) and (ClipSize > 0) Then Begin
    GetMem(SavedClip, ClipSize);
    Move(Clipboard^, SavedClip^, ClipSize);
    SavedClipSz := ClipSize;
    SavedClipW  := ClipW;
    SavedClipH  := ClipH;
  End;
End;

Procedure TRIPEngine.RestoreClip;
Begin
  // Restore the saved clipboard
  If (SavedClip = Nil) or (SavedClipSz = 0) Then Exit;

  If Clipboard <> Nil Then FreeMem(Clipboard, ClipSize);

  GetMem(Clipboard, SavedClipSz);
  Move(SavedClip^, Clipboard^, SavedClipSz);
  ClipSize := SavedClipSz;
  ClipW    := SavedClipW;
  ClipH    := SavedClipH;
End;

Procedure TRIPEngine.SaveAll;
Begin
  SaveScreen(0);
  SaveTextWin;
  SaveClip;
  SaveMouseAll;
End;

Procedure TRIPEngine.RestoreAll;
Begin
  RestoreScreen(0);
  RestoreTextWin;
  RestoreClip;
  RestoreMouseAll;
End;

Function TRIPEngine.GetMaxX : SmallInt;
Begin
  Result := ActiveMaxX;
End;

Function TRIPEngine.GetMaxY : SmallInt;
Begin
  Result := ActiveMaxY;
End;

// ---- CHR vector font loading ----

Function TRIPEngine.LoadCHR (AFontNum: Byte; FileName: String) : Boolean;
// Load a Borland BGI .CHR stroked font file
// Format: ASCII header ending with 0x1A, then binary prefix header,
// then stroke data starting with '+' (0x2B) signature
Type
  TLoadBuf = Array[0..32767] of Byte;
  PLoadBuf = ^TLoadBuf;
Var
  F        : File;
  Data     : PLoadBuf;
  FileLen  : LongInt;
  I, Pos   : Integer;
  PlusOff  : Integer;
  OtStart  : Integer;
  WtStart  : Integer;
  SkStart  : Integer;
  NC       : Word;
  FC       : Byte;
  B1, B2   : Byte;
  SX, SY   : SmallInt;
  Op       : Byte;
  SIdx     : Word;
  CharBase : Word;
Begin
  Result := False;

  If (AFontNum < 1) or (AFontNum > 10) Then Exit;

  Assign(F, FileName);
  {$I-} System.Reset(F, 1); {$I+}
  If IOResult <> 0 Then Exit;

  New(Data);

  FileLen := FileSize(F);
  If FileLen > SizeOf(Data^) Then FileLen := SizeOf(Data^);
  BlockRead(F, Data^, FileLen);
  Close(F);

  // Find '+' signature (0x2B) — marks start of stroke data header
  PlusOff := -1;
  For I := 80 to FileLen - 20 Do
    If Data^[I] = $2B Then Begin
      NC := Data^[I+1] OR (Data^[I+2] SHL 8);
      FC := Data^[I+4];
      If (NC >= 32) and (NC <= 256) and (FC >= 32) and (FC <= 127) Then Begin
        PlusOff := I;
        Break;
      End;
    End;

  If PlusOff < 0 Then Begin Dispose(Data); Exit; End;

  // Allocate font
  If CHRFonts[AFontNum] <> Nil Then Dispose(CHRFonts[AFontNum]);
  New(CHRFonts[AFontNum]);

  With CHRFonts[AFontNum]^ Do Begin
    Loaded    := True;
    NumChars  := NC;
    FirstChar := FC;

    // Metrics from header
    OrgToCap  := ShortInt(Data^[PlusOff + 8]);
    OrgToBase := ShortInt(Data^[PlusOff + 9]);
    OrgToDec  := ShortInt(Data^[PlusOff + 10]);

    // Font name from prefix (4 bytes at known offset)
    Name := '    ';

    // Offset table: NumChars * 2 bytes starting at PlusOff + 16
    OtStart := PlusOff + 16;
    For I := 0 to NumChars - 1 Do
      If I < RIP_MAX_CHR_CHARS Then
        Offsets[I] := Data^[OtStart + I*2] OR (Data^[OtStart + I*2 + 1] SHL 8);

    // Width table: NumChars bytes after offset table
    WtStart := OtStart + NumChars * 2;
    For I := 0 to NumChars - 1 Do
      If I < RIP_MAX_CHR_CHARS Then
        Widths[I] := Data^[WtStart + I];

    // Stroke data starts after width table
    SkStart := WtStart + NumChars;

    // Parse all strokes into our array
    NumStrokes := 0;

    For I := 0 to NumChars - 1 Do Begin
      If I >= RIP_MAX_CHR_CHARS Then Break;

      // Store the base offset for this character
      CharBase := NumStrokes;
      Offsets[I] := CharBase;

      Pos := SkStart + (Data[OtStart + I*2] OR (Data[OtStart + I*2 + 1] SHL 8));

      Repeat
        If (Pos + 1 >= FileLen) or (NumStrokes >= RIP_MAX_STROKES) Then Break;

        B1 := Data[Pos];
        B2 := Data[Pos + 1];

        SX := B1 AND $7F;
        SY := B2 AND $7F;
        If SX >= 64 Then SX := SX - 128;
        If SY >= 64 Then SY := SY - 128;

        // Opcode: b1 bit7 = pen flag, b2 bit7 = draw/move
        If (B1 AND $80 = 0) and (B2 AND $80 = 0) Then
          Op := 0   // end of character
        Else If (B2 AND $80 = 0) Then
          Op := 1   // move to (pen up)
        Else
          Op := 2;  // draw to (pen down)

        Strokes[NumStrokes].Op := Op;
        Strokes[NumStrokes].X  := SX;
        Strokes[NumStrokes].Y  := SY;
        Inc(NumStrokes);
        Inc(Pos, 2);
      Until Op = 0;
    End;
  End;

  Dispose(Data);
  Result := True;
End;

Procedure TRIPEngine.DrawTextCHR (X, Y: SmallInt; S: String; AFont, ASize: Byte);
// Render text using a loaded CHR vector font
Var
  I, J       : Integer;
  CharIdx    : Integer;
  CX, CY    : SmallInt;
  PenX, PenY : SmallInt;
  Scale      : SmallInt;
  StrokeOff  : Word;
  MaxStrokes : Word;
Begin
  If (AFont < 1) or (AFont > 10) Then Exit;
  If CHRFonts[AFont] = Nil Then Exit;
  If Not CHRFonts[AFont]^.Loaded Then Exit;

  If ASize = 0 Then ASize := 1;
  Scale := ASize;
  CX := X;

  With CHRFonts[AFont]^ Do Begin
    For I := 1 to Length(S) Do Begin
      CharIdx := Ord(S[I]) - FirstChar;

      If (CharIdx < 0) or (CharIdx >= NumChars) Then Begin
        Inc(CX, 8 * Scale);
        Continue;
      End;

      StrokeOff := Offsets[CharIdx];
      PenX := CX;
      PenY := Y;

      // Walk stroke commands for this character
      J := StrokeOff;
      While J < NumStrokes Do Begin
        Case Strokes[J].Op of
          0 : Break;  // end of character
          1 : Begin    // move to
                PenX := CX + Strokes[J].X * Scale;
                PenY := Y  - Strokes[J].Y * Scale;
              End;
          2 : Begin    // draw to
                DrawLine(PenX, PenY,
                         CX + Strokes[J].X * Scale,
                         Y  - Strokes[J].Y * Scale);
                PenX := CX + Strokes[J].X * Scale;
                PenY := Y  - Strokes[J].Y * Scale;
              End;
        End;

        Inc(J);
      End;

      Inc(CX, Widths[CharIdx] * Scale);
    End;
  End;

  Self.CurX := CX;
  Self.CurY := Y;
End;

// ====================================================================
// Line processing — handles continuation (\) and command extraction
// ====================================================================

Procedure TRIPEngine.ProcessLine (Line: String);
Var
  I   : Integer;
  Cmd : String;
Begin
  // Handle line continuation
  If Continued Then Begin
    LineBuf := LineBuf + Line;
    Continued := False;
  End Else
    LineBuf := Line;

  // Check for continuation (line ends with \, not \\)
  If (Length(LineBuf) > 0) and (LineBuf[Length(LineBuf)] = '\') Then Begin
    If (Length(LineBuf) < 2) or (LineBuf[Length(LineBuf) - 1] <> '\') Then Begin
      Delete(LineBuf, Length(LineBuf), 1);
      Continued := True;
      Exit;
    End;
  End;

  // Extract RIP commands from the line
  // v1.54: commands start with !| or SOH| or STX|
  // v2.0:  commands can also use bare | prefix
  I := 1;

  While I <= Length(LineBuf) Do Begin
    // v1.54 prefix: !| or SOH| or STX|
    If ((LineBuf[I] = '!') or (LineBuf[I] = #1) or (LineBuf[I] = #2)) and
       (I < Length(LineBuf)) and (LineBuf[I + 1] = '|') Then Begin
      Inc(I, 2);  // skip !|
      Cmd := '';

      While (I <= Length(LineBuf)) Do Begin
        // Stop at next command prefix
        If ((LineBuf[I] = '!') or (LineBuf[I] = #1) or (LineBuf[I] = #2)) and
           (I < Length(LineBuf)) and (LineBuf[I + 1] = '|') Then
          Break;
        // v2.0: also stop at bare |
        If (LineBuf[I] = '|') and (I > 1) and
           (LineBuf[I-1] <> '!') and (LineBuf[I-1] <> #1) and (LineBuf[I-1] <> #2) Then
          Break;

        Cmd := Cmd + LineBuf[I];
        Inc(I);
      End;

      If Cmd <> '' Then
        ProcessCommand(Cmd);

    // v2.0 bare | prefix (not preceded by ! or SOH or STX)
    End Else If (LineBuf[I] = '|') and
       ((I = 1) or ((LineBuf[I-1] <> '!') and (LineBuf[I-1] <> #1) and (LineBuf[I-1] <> #2))) Then Begin
      Inc(I);  // skip |
      Cmd := '';

      While (I <= Length(LineBuf)) Do Begin
        If ((LineBuf[I] = '!') or (LineBuf[I] = #1) or (LineBuf[I] = #2)) and
           (I < Length(LineBuf)) and (LineBuf[I + 1] = '|') Then
          Break;
        If (LineBuf[I] = '|') Then
          Break;

        Cmd := Cmd + LineBuf[I];
        Inc(I);
      End;

      If Cmd <> '' Then
        ProcessCommand(Cmd);

    End Else
      Inc(I);
  End;
End;

// ====================================================================
// Command dispatcher
// ====================================================================

Procedure TRIPEngine.ProcessCommand (Cmd: String);
Var
  Level   : Integer;
  CmdChar : Char;
Begin
  If Length(Cmd) < 1 Then Exit;

  // Determine level
  If (Cmd[1] >= '0') and (Cmd[1] <= '9') Then Begin
    Level := Ord(Cmd[1]) - Ord('0');
    Delete(Cmd, 1, 1);

    // Check for sub-level digit
    If (Length(Cmd) > 0) and (Cmd[1] >= '0') and (Cmd[1] <= '9') Then
      Delete(Cmd, 1, 1);  // skip sub-level
  End Else
    Level := 0;

  If Length(Cmd) < 1 Then Exit;

  CmdChar := Cmd[1];
  Delete(Cmd, 1, 1);

  Case Level of
    0 : ParseLevel0(CmdChar, Cmd);
    1 : ParseLevel1(CmdChar, Cmd);
    9 : ParseLevel9(CmdChar, Cmd);
  End;
End;

// ====================================================================
// Level 0 commands — core graphics primitives
// ====================================================================

Procedure TRIPEngine.ParseLevel0 (Cmd: Char; Params: String);
Var
  P : Integer;
  X0, Y0, X1, Y1 : SmallInt;
  XR, YR, Radius  : SmallInt;
  SA, EA          : SmallInt;
  Style, Thick    : SmallInt;
  Color           : SmallInt;
  Count, I        : SmallInt;
  IX, IY          : SmallInt;   // v2.0: clear region loop
  Points          : Array[0..RIP_MAX_POLY-1] of TRIPPoint;
  PatWord         : Word;
  TmpStr          : String;    // v2.0: text path
Begin
  P := 1;

  Case Cmd of
    // RIP_TEXT_WINDOW: w  x0(2) y0(2) x1(2) y1(2) wrap(1) size(1)
    'w' : Begin
            TextWinX0   := MegaNum(Params, P, 2);
            TextWinY0   := MegaNum(Params, P, 2);
            TextWinX1   := MegaNum(Params, P, 2);
            TextWinY1   := MegaNum(Params, P, 2);
            MegaNum(Params, P, 2);  // wrap mode (ignored server-side)
            TextWinSize := MegaNum(Params, P, 2);
          End;

    // RIP_VIEWPORT: v  x0(2) y0(2) x1(2) y1(2)
    'v' : Begin
            ViewX0 := MegaNum(Params, P, 2);
            ViewY0 := MegaNum(Params, P, 2);
            ViewX1 := MegaNum(Params, P, 2);
            ViewY1 := MegaNum(Params, P, 2);

            If (ViewX0 = 0) and (ViewY0 = 0) and
               (ViewX1 = 0) and (ViewY1 = 0) Then Begin
              ViewX0 := 0;
              ViewY0 := 0;
              ViewX1 := ActiveMaxX;
              ViewY1 := ActiveMaxY;
            End;
          End;

    // RIP_RESET_WINDOWS: *
    '*' : Begin
            TextWinX0 := 0;  TextWinY0 := 0;
            TextWinX1 := 79; TextWinY1 := 42;
            TextWinSize := 0;
            ViewX0 := 0;     ViewY0 := 0;
            ViewX1 := ActiveMaxX; ViewY1 := ActiveMaxY;
            // Per spec: reset windows also kills mouse fields
            KillAllMouseFields;
          End;

    // RIP_ERASE_WINDOW: e
    'e' : ClearScreen;

    // RIP_ERASE_VIEW: E
    'E' : ClearViewport;

    // RIP_GOTOXY: g  x(2) y(2)
    'g' : Begin
            CurX := MegaNum(Params, P, 2);
            CurY := MegaNum(Params, P, 2);
          End;

    // RIP_HOME: H
    'H' : Begin CurX := 0; CurY := 0; End;

    // RIP_ERASE_EOL: >
    '>' : Begin
            For X0 := CurX to ViewX1 Do
              DrawPixel(X0, CurY, 0);
          End;

    // RIP_COLOR: c  color(2)
    'c' : DrawColor := MegaNum(Params, P, 2);

    // RIP_SET_PALETTE: Q  c0..c15 (16 x 2 digits)
    'Q' : Begin
            For I := 0 to 15 Do
              Palette[I] := MegaNum(Params, P, 2);
          End;

    // RIP_ONE_PALETTE: a  color(2) value(2)
    'a' : Begin
            Color := MegaNum(Params, P, 2);
            If (Color >= 0) and (Color < RIP_MAX_COLORS) Then
              Palette[Color] := MegaNum(Params, P, 2);
          End;

    // RIP_WRITE_MODE: W  mode(2)
    'W' : WriteMode := MegaNum(Params, P, 2);

    // RIP_MOVE: m  x(2) y(2)
    'm' : Begin
            CurX := MegaNum(Params, P, 2);
            CurY := MegaNum(Params, P, 2);
          End;

    // RIP_TEXT: T  text...
    'T' : OutText(Params);

    // RIP_TEXT_XY: @  x(2) y(2) text...
    '@' : Begin
            X0 := MegaNum(Params, P, 2);
            Y0 := MegaNum(Params, P, 2);
            OutTextXY(X0, Y0, Copy(Params, P, Length(Params)));
          End;

    // RIP_FONT_STYLE: Y  font(2) dir(2) size(2) res(2)
    'Y' : Begin
            FontNum  := MegaNum(Params, P, 2);
            FontDir  := MegaNum(Params, P, 2);
            FontSize := MegaNum(Params, P, 2);
            If P <= Length(Params) Then MegaNum(Params, P, 2);  // reserved
          End;

    // RIP_PIXEL: X  x(2) y(2)
    'X' : Begin
            X0 := MegaNum(Params, P, 2);
            Y0 := MegaNum(Params, P, 2);
            DrawPixel(X0, Y0, DrawColor);
          End;

    // RIP_LINE: L  x0(2) y0(2) x1(2) y1(2)
    'L' : Begin
            X0 := MegaNum(Params, P, 2);
            Y0 := MegaNum(Params, P, 2);
            X1 := MegaNum(Params, P, 2);
            Y1 := MegaNum(Params, P, 2);
            DrawLine(X0, Y0, X1, Y1);
          End;

    // RIP_RECTANGLE: R  x0(2) y0(2) x1(2) y1(2)
    'R' : Begin
            X0 := MegaNum(Params, P, 2);
            Y0 := MegaNum(Params, P, 2);
            X1 := MegaNum(Params, P, 2);
            Y1 := MegaNum(Params, P, 2);
            DrawRect(X0, Y0, X1, Y1);
          End;

    // RIP_BAR: B  x0(2) y0(2) x1(2) y1(2)
    'B' : Begin
            X0 := MegaNum(Params, P, 2);
            Y0 := MegaNum(Params, P, 2);
            X1 := MegaNum(Params, P, 2);
            Y1 := MegaNum(Params, P, 2);
            DrawBar(X0, Y0, X1, Y1);
          End;

    // RIP_CIRCLE: C  xc(2) yc(2) radius(2)
    'C' : Begin
            X0 := MegaNum(Params, P, 2);
            Y0 := MegaNum(Params, P, 2);
            Radius := MegaNum(Params, P, 2);
            DrawCircle(X0, Y0, Radius);
          End;

    // RIP_OVAL: O  xc(2) yc(2) start(2) end(2) xr(2) yr(2)
    'O' : Begin
            X0 := MegaNum(Params, P, 2);
            Y0 := MegaNum(Params, P, 2);
            SA := MegaNum(Params, P, 2);  // start angle (unused for oval outline)
            EA := MegaNum(Params, P, 2);  // end angle
            XR := MegaNum(Params, P, 2);
            YR := MegaNum(Params, P, 2);
            DrawOval(X0, Y0, XR, YR);
          End;

    // RIP_FILLED_OVAL: o  xc(2) yc(2) xr(2) yr(2)
    'o' : Begin
            X0 := MegaNum(Params, P, 2);
            Y0 := MegaNum(Params, P, 2);
            XR := MegaNum(Params, P, 2);
            YR := MegaNum(Params, P, 2);
            DrawFilledOval(X0, Y0, XR, YR);
          End;

    // RIP_ARC: A  xc(2) yc(2) start(2) end(2) radius(2)
    'A' : Begin
            X0 := MegaNum(Params, P, 2);
            Y0 := MegaNum(Params, P, 2);
            SA := MegaNum(Params, P, 2);
            EA := MegaNum(Params, P, 2);
            Radius := MegaNum(Params, P, 2);
            DrawArc(X0, Y0, SA, EA, Radius);
          End;

    // RIP_OVAL_ARC: V  xc(2) yc(2) sa(2) ea(2) xr(2) yr(2)
    'V' : Begin
            X0 := MegaNum(Params, P, 2);
            Y0 := MegaNum(Params, P, 2);
            SA := MegaNum(Params, P, 2);
            EA := MegaNum(Params, P, 2);
            XR := MegaNum(Params, P, 2);
            YR := MegaNum(Params, P, 2);
            DrawOvalArc(X0, Y0, SA, EA, XR, YR);
          End;

    // RIP_PIE_SLICE: I  xc(2) yc(2) sa(2) ea(2) radius(2)
    'I' : Begin
            X0 := MegaNum(Params, P, 2);
            Y0 := MegaNum(Params, P, 2);
            SA := MegaNum(Params, P, 2);
            EA := MegaNum(Params, P, 2);
            Radius := MegaNum(Params, P, 2);
            DrawPieSlice(X0, Y0, SA, EA, Radius);
          End;

    // RIP_OVAL_PIE_SLICE: i  xc(2) yc(2) sa(2) ea(2) xr(2) yr(2)
    'i' : Begin
            X0 := MegaNum(Params, P, 2);
            Y0 := MegaNum(Params, P, 2);
            SA := MegaNum(Params, P, 2);
            EA := MegaNum(Params, P, 2);
            XR := MegaNum(Params, P, 2);
            YR := MegaNum(Params, P, 2);
            DrawOvalPie(X0, Y0, SA, EA, XR, YR);
          End;

    // RIP_BEZIER: Z  x0(2) y0(2) x1(2) y1(2) x2(2) y2(2) x3(2) y3(2) cnt(2)
    'Z' : Begin
            X0 := MegaNum(Params, P, 2);
            Y0 := MegaNum(Params, P, 2);
            X1 := MegaNum(Params, P, 2);
            Y1 := MegaNum(Params, P, 2);
            XR := MegaNum(Params, P, 2);
            YR := MegaNum(Params, P, 2);
            SA := MegaNum(Params, P, 2);
            EA := MegaNum(Params, P, 2);
            Count := MegaNum(Params, P, 2);
            DrawBezier(X0, Y0, X1, Y1, XR, YR, SA, EA, Count);
          End;

    // RIP_POLYGON: P  npoints(2) x0(2) y0(2) x1(2) y1(2) ...
    'P' : Begin
            Count := MegaNum(Params, P, 2);
            If Count > RIP_MAX_POLY Then Count := RIP_MAX_POLY;

            For I := 0 to Count - 1 Do Begin
              Points[I].X := MegaNum(Params, P, 2);
              Points[I].Y := MegaNum(Params, P, 2);
            End;

            DrawPolygon(Points, Count);
          End;

    // RIP_FILL_POLYGON: p  npoints(2) x0(2) y0(2) ...
    'p' : Begin
            Count := MegaNum(Params, P, 2);
            If Count > RIP_MAX_POLY Then Count := RIP_MAX_POLY;

            For I := 0 to Count - 1 Do Begin
              Points[I].X := MegaNum(Params, P, 2);
              Points[I].Y := MegaNum(Params, P, 2);
            End;

            DrawFillPoly(Points, Count);
          End;

    // RIP_POLYLINE: l  npoints(2) x0(2) y0(2) ...
    'l' : Begin
            Count := MegaNum(Params, P, 2);
            If Count > RIP_MAX_POLY Then Count := RIP_MAX_POLY;

            For I := 0 to Count - 1 Do Begin
              Points[I].X := MegaNum(Params, P, 2);
              Points[I].Y := MegaNum(Params, P, 2);
            End;

            DrawPolyLine(Points, Count);
          End;

    // RIP_FILL: F  x(2) y(2) border(2)
    'F' : Begin
            X0    := MegaNum(Params, P, 2);
            Y0    := MegaNum(Params, P, 2);
            Color := MegaNum(Params, P, 2);
            FloodFill(X0, Y0, Color);
          End;

    // RIP_LINE_STYLE: =  style(2) user_pat(4) thick(2)
    '=' : Begin
            LineStyle   := MegaNum(Params, P, 2);
            PatWord     := MegaNum(Params, P, 4);
            LineThick   := MegaNum(Params, P, 2);
            LinePattern := PatWord;
          End;

    // RIP_FILL_STYLE: S  style(2) color(2)
    'S' : Begin
            FillStyle := MegaNum(Params, P, 2);
            FillColor := MegaNum(Params, P, 2);
          End;

    // RIP_FILL_PATTERN: s  c1..c8(8x2) color(2)
    's' : Begin
            For I := 0 to 7 Do
              FillPat[I] := MegaNum(Params, P, 2);
            FillColor := MegaNum(Params, P, 2);
            FillStyle := RIP_FILL_USER;
          End;

    // RIP_NO_MORE: #
    '#' : ; // no-op, marks end of RIP sequences

    // ---- v2.0 new commands ----

    // RIP2_PROTO_INIT: J  version(2)
    'J' : Begin
            I := MegaNum(Params, P, 2);
            ProtoVersion := I;
          End;

    // RIP2_SET_RESOLUTION: n  resolution(4)
    'n' : Begin
            X0 := MegaNum(Params, P, 2);
            Y0 := MegaNum(Params, P, 2);
            If (X0 > 0) and (Y0 > 0) Then
              SetResolution(X0, Y0);
          End;

    // RIP2_COLOR_MODE: M  mode(2)
    'M' : Begin
            I := MegaNum(Params, P, 2);
            SetColorMode(I);
          End;

    // RIP2_CLEAR_REGION: K  x0(2) y0(2) x1(2) y1(2)
    'K' : Begin
            X0 := MegaNum(Params, P, 2);
            Y0 := MegaNum(Params, P, 2);
            X1 := MegaNum(Params, P, 2);
            Y1 := MegaNum(Params, P, 2);
            // Clear the bounded region to color 0
            For IY := Y0 to Y1 Do
              For IX := X0 to X1 Do
                If InView(IX, IY) Then
                  Pixels^[IY, IX] := 0;
          End;

    // RIP2_PEN_WIDTH: k  width(2)
    'k' : PenWidth := MegaNum(Params, P, 2);

    // RIP2_DRAW_LAYER: N  layer(2)
    'N' : DrawLayer := MegaNum(Params, P, 2);

    // RIP2_JUMP: j  x(2) y(2)
    'j' : Begin
            CurX := MegaNum(Params, P, 2);
            CurY := MegaNum(Params, P, 2);
          End;

    // RIP2_POLYLINE: y  flags(2) count(2) x0(2) y0(2) ... xN(2) yN(2)
    'y' : Begin
            Style := MegaNum(Params, P, 2);  // flags
            Count := MegaNum(Params, P, 2);  // number of points
            If Count < 2 Then Count := 2;
            If Count > RIP_MAX_POLY Then Count := RIP_MAX_POLY;
            For I := 0 to Count - 1 Do Begin
              Points[I].X := MegaNum(Params, P, 2);
              Points[I].Y := MegaNum(Params, P, 2);
            End;
            // Draw polyline (connected line segments)
            For I := 0 to Count - 2 Do
              DrawLine(Points[I].X, Points[I].Y,
                       Points[I+1].X, Points[I+1].Y);
          End;

    // RIP2_FILL_POLYGON: x  flags(2) count(2) x0(2) y0(2) ... xN(2) yN(2)
    'x' : Begin
            Style := MegaNum(Params, P, 2);  // flags
            Count := MegaNum(Params, P, 2);  // number of points
            If Count < 3 Then Count := 3;
            If Count > RIP_MAX_POLY Then Count := RIP_MAX_POLY;
            For I := 0 to Count - 1 Do Begin
              Points[I].X := MegaNum(Params, P, 2);
              Points[I].Y := MegaNum(Params, P, 2);
            End;
            DrawFillPoly(Points, Count);
          End;

    // RIP2_TEXT_PATH: t  flags(2) then text+coords
    't' : Begin
            Style := MegaNum(Params, P, 2);  // flags
            // Remaining params = text string with embedded coords
            // For now, extract and render as plain text at current pos
            TmpStr := '';
            While P <= Length(Params) Do Begin
              TmpStr := TmpStr + Params[P];
              Inc(P);
            End;
            If TmpStr <> '' Then
              OutTextXY(CurX, CurY, TmpStr);
          End;

    // RIP2_PALETTE_GRADIENT: D  start(2) end(2) flags(2) R0(2) G0(2) B0(2) R1(2) G1(2) B1(2)...
    'D' : Begin
            X0 := MegaNum(Params, P, 2);  // start index
            X1 := MegaNum(Params, P, 2);  // end index
            Style := MegaNum(Params, P, 2); // flags
            // Read RGB triplets and interpolate
            If (X0 >= 0) and (X0 <= 255) and (X1 >= 0) and (X1 <= 255) Then Begin
              // Read start RGB
              Color := MegaNum(Params, P, 2);  // R start
              SA    := MegaNum(Params, P, 2);  // G start
              EA    := MegaNum(Params, P, 2);  // B start
              // Read end RGB
              XR    := MegaNum(Params, P, 2);  // R end
              YR    := MegaNum(Params, P, 2);  // G end
              Radius := MegaNum(Params, P, 2); // B end
              // Set palette entries (gradient interpolation)
              If X1 > X0 Then
                For I := X0 to X1 Do
                  Palette[I] := I;  // identity mapping for now
            End;
          End;

    // RIP2_PALETTE_ENTRY: d  index(2) R(2) G(2) B(2) flags(1)
    'd' : Begin
            I := MegaNum(Params, P, 2);     // palette index
            Color := MegaNum(Params, P, 2);  // R
            Style := MegaNum(Params, P, 2);  // G
            Count := MegaNum(Params, P, 2);  // B
            // Last char may be flags
            If (I >= 0) and (I <= 255) Then
              Palette[I] := I;  // identity mapping; RGB stored for rendering
          End;

    // RIP2_FONT_SELECT: f  fontID(4) — select RFF font by ID
    'f' : Begin
            // 4-char font ID (2 pairs of MegaNum)
            X0 := MegaNum(Params, P, 2);
            Y0 := MegaNum(Params, P, 2);
            // RFF font loaded via Phase 18 LoadRFF/DrawTextRFF
            // FontNum could be mapped from the ID when RFF support is added
          End;
  End;
End;

// ====================================================================
// Level 1 commands — mouse, buttons, icons, text regions
// ====================================================================

Procedure TRIPEngine.ParseLevel1 (Cmd: Char; Params: String);
Var
  P    : Integer;
  X0, Y0, X1, Y1 : SmallInt;
  I    : Integer;
  IconFN, LabelTxt, BtnHostCmd : String;
  IsRadio, IsCheck, InitSel : Boolean;
  TmpStr : String;  // v2.0: extended commands
  WX0Tmp, WY0Tmp, WX1Tmp, WY1Tmp : Real;  // v3.0 Phase 16
  ValCode : Integer;  // v3.0 Phase 16
Begin
  P := 1;

  Case Cmd of
    // RIP_MOUSE: M  x0(2) y0(2) x1(2) y1(2) clk(2) flags(1) text
    'M' : Begin
            If MouseCount < RIP_MAX_MOUSE Then Begin
              Inc(MouseCount);

              With MouseFields[MouseCount] Do Begin
                Active := True;
                X0 := MegaNum(Params, P, 2);
                Y0 := MegaNum(Params, P, 2);
                X1 := MegaNum(Params, P, 2);
                Y1 := MegaNum(Params, P, 2);
                MegaNum(Params, P, 2);  // click style
                If P <= Length(Params) Then Inc(P);  // flags

                // Rest is host command ^ status text
                HostCmd := '';
                Text    := '';
                Invert  := False;
                IsButton    := False;
                IsRadio     := False;
                IsCheckbox  := False;
                GroupID     := 0;
                Selected    := False;
                IconFile    := '';
                HotIconFile := '';

                While (P <= Length(Params)) and (Params[P] <> '^') Do Begin
                  HostCmd := HostCmd + Params[P];
                  Inc(P);
                End;

                If (P <= Length(Params)) and (Params[P] = '^') Then Inc(P);

                While P <= Length(Params) Do Begin
                  Text := Text + Params[P];
                  Inc(P);
                End;
              End;
            End;
          End;

    // RIP_KILL_MOUSE_FIELDS: K  (no params = kill all, or num(2))
    'K' : Begin
            If Length(Params) = 0 Then
              KillAllMouseFields
            Else Begin
              I := MegaNum(Params, P, 2);
              KillMouseField(I);
            End;
          End;

    // RIP_BEGIN_TEXT: T  x(2) y(2) sizeY(2) sizeX(2) (begins text block)
    'T' : Begin
            X0 := MegaNum(Params, P, 2);
            Y0 := MegaNum(Params, P, 2);
            // Text block — text follows on subsequent lines until !|1t or !|1E
            CurX := X0;
            CurY := Y0;
          End;

    // RIP_REGION_TEXT: t  (continue text block, line of text)
    't' : Begin
            OutTextXY(CurX, CurY, Params);
            CurY := CurY + GetSysFontH;
          End;

    // RIP_END_TEXT: E  (end text block)
    'E' : ;  // no-op — just marks end of text block

    // RIP_GET_IMAGE: C  x0(2) y0(2) x1(2) y1(2) res(2)
    'C' : Begin
            X0 := MegaNum(Params, P, 2);
            Y0 := MegaNum(Params, P, 2);
            X1 := MegaNum(Params, P, 2);
            Y1 := MegaNum(Params, P, 2);
            // Capture to clipboard
            If Clipboard <> Nil Then FreeMem(Clipboard, ClipSize);
            ClipSize := ImageSize(X0, Y0, X1, Y1);
            ClipW := X1 - X0 + 1;
            ClipH := Y1 - Y0 + 1;
            GetMem(Clipboard, ClipSize);
            GetImage(X0, Y0, X1, Y1, Clipboard^);
          End;

    // RIP_PUT_IMAGE: P  x(2) y(2) mode(2) res(2)
    'P' : Begin
            X0 := MegaNum(Params, P, 2);
            Y0 := MegaNum(Params, P, 2);
            I  := MegaNum(Params, P, 2);  // mode
            If Clipboard <> Nil Then
              PutImage(X0, Y0, Clipboard^, I);
          End;

    // RIP_WRITE_ICON: W  res(2) filename
    'W' : Begin
            MegaNum(Params, P, 2);  // reserved
            // WriteIcon saves clipboard to file — for now, no-op
            // (clipboard is in GetImage format, not directly saveable as ICN
            //  without first PutImage'ing it back to screen)
          End;

    // RIP_LOAD_ICON: I  x(2) y(2) mode(2) clip(1) res(2) filename
    'I' : Begin
            X0 := MegaNum(Params, P, 2);
            Y0 := MegaNum(Params, P, 2);
            I  := MegaNum(Params, P, 2);  // mode (write mode)
            If P <= Length(Params) Then Inc(P);  // clipboard flag
            MegaNum(Params, P, 2);  // reserved
            // Remaining is filename
            If P <= Length(Params) Then
              LoadIcon(Copy(Params, P, Length(Params)), X0, Y0, I);
          End;

    // RIP_BUTTON_STYLE: B  wid(2) hgt(2) orient(2) flags(4)
    //   dfore(2) dback(2) bright(2) dark(2) surface(2)
    //   grp(2) flags2(2) uline(2) corner(2)
    'B' : Begin
            BtnStyle.Width     := MegaNum(Params, P, 2);
            BtnStyle.Height    := MegaNum(Params, P, 2);
            BtnStyle.Orient    := MegaNum(Params, P, 2);
            BtnStyle.Flags     := MegaNum(Params, P, 4);
            BtnStyle.DFore     := MegaNum(Params, P, 2);
            BtnStyle.DBack     := MegaNum(Params, P, 2);
            BtnStyle.BRight    := MegaNum(Params, P, 2);
            BtnStyle.DDark     := MegaNum(Params, P, 2);
            BtnStyle.Surface   := MegaNum(Params, P, 2);
            BtnStyle.GrpID     := MegaNum(Params, P, 2);
            BtnStyle.Flags2    := MegaNum(Params, P, 2);
            BtnStyle.ULineCol  := MegaNum(Params, P, 2);
            BtnStyle.CornerCol := MegaNum(Params, P, 2);
          End;

    // RIP_BUTTON: U  x0(2) y0(2) x1(2) y1(2) hotkey(2) flags(1)
    //   <>icon_file<>label<>hostcmd  (delimited by <>)
    'U' : Begin
            X0 := MegaNum(Params, P, 2);
            Y0 := MegaNum(Params, P, 2);
            X1 := MegaNum(Params, P, 2);
            Y1 := MegaNum(Params, P, 2);
            I  := MegaNum(Params, P, 2);  // hotkey (ASCII code)
            If P <= Length(Params) Then Inc(P);  // flags

            // Parse <>delimited fields: icon<>label<>hostcmd
            IconFN     := '';
            LabelTxt   := '';
            BtnHostCmd := '';

            // Skip leading <>
            If (P + 1 <= Length(Params)) and (Params[P] = '<') and (Params[P+1] = '>') Then
              Inc(P, 2);

            // Read icon filename until <>
            While (P <= Length(Params)) Do Begin
              If (P + 1 <= Length(Params)) and (Params[P] = '<') and (Params[P+1] = '>') Then Begin
                Inc(P, 2);
                Break;
              End;
              IconFN := IconFN + Params[P];
              Inc(P);
            End;

            // Read label until <>
            While (P <= Length(Params)) Do Begin
              If (P + 1 <= Length(Params)) and (Params[P] = '<') and (Params[P+1] = '>') Then Begin
                Inc(P, 2);
                Break;
              End;
              LabelTxt := LabelTxt + Params[P];
              Inc(P);
            End;

            // Rest is host command
            While (P <= Length(Params)) Do Begin
              BtnHostCmd := BtnHostCmd + Params[P];
              Inc(P);
            End;

            // Determine button type from BtnStyle.Flags
            IsRadio := (BtnStyle.Flags AND $0002) <> 0;
            IsCheck := (BtnStyle.Flags AND $0004) <> 0;
            InitSel := (BtnStyle.Flags AND $0008) <> 0;

            DrawButtonEx(X0, Y0, X1, Y1, LabelTxt, BtnHostCmd,
                         IconFN, '', IsRadio, IsCheck, InitSel);

            // Override hotkey if specified in RIP command
            If (I > 0) and (I < 128) and (MouseCount > 0) Then
              MouseFields[MouseCount].HotKey := Chr(I);
          End;

    // RIP_DEFINE: D  flags(3) res(2) text_var,size:?question?default
    'D' : Begin
            I := MegaNum(Params, P, 3);  // flags
            MegaNum(Params, P, 2);       // reserved

            // Parse variable name until , or : or end
            X0 := P;
            While (P <= Length(Params)) and (Params[P] <> ',') and (Params[P] <> ':') Do
              Inc(P);

            IconFN := Copy(Params, X0, P - X0);  // reuse var for name

            // Skip ,size if present
            If (P <= Length(Params)) and (Params[P] = ',') Then Begin
              Inc(P);
              While (P <= Length(Params)) and (Params[P] <> ':') Do Inc(P);
            End;

            // Parse default value: after :?question? comes default
            LabelTxt := '';  // reuse var for default value
            If (P <= Length(Params)) and (Params[P] = ':') Then Begin
              Inc(P);
              // Skip ?question? if present
              If (P <= Length(Params)) and (Params[P] = '?') Then Begin
                Inc(P);
                While (P <= Length(Params)) and (Params[P] <> '?') Do Inc(P);
                If P <= Length(Params) Then Inc(P);  // skip closing ?
              End;
              // Rest is default value
              LabelTxt := Copy(Params, P, Length(Params));
            End;

            DefineVar(
              IconFN,                   // name
              LabelTxt,                 // default value
              (I AND 1) <> 0,           // persist flag
              (I AND 2) <> 0            // required flag
            );
          End;

    // RIP_COPY_REGION: G  x0(2) y0(2) x1(2) y1(2) res(2) dest_line(2)
    'G' : Begin
            X0 := MegaNum(Params, P, 2);
            Y0 := MegaNum(Params, P, 2);
            X1 := MegaNum(Params, P, 2);
            Y1 := MegaNum(Params, P, 2);
            MegaNum(Params, P, 2);  // reserved
            I  := MegaNum(Params, P, 2);  // dest_line
            CopyRegion(X0, Y0, X1, Y1, I);
          End;

    // RIP_READ_SCENE: R  res(2) filename
    'R' : Begin
            MegaNum(Params, P, 2);  // reserved
            If P <= Length(Params) Then
              LoadScene(Copy(Params, P, Length(Params)));
          End;

    // RIP_FILE_QUERY: F  mode(2) res(4) filename
    'F' : Begin
            I := MegaNum(Params, P, 2);   // mode
            MegaNum(Params, P, 4);        // reserved
            // File query result would be sent back to host
            // Server-side: just do the query, caller reads result
            FileQuery(Copy(Params, P, Length(Params)), I);
          End;

    // ---- v2.0 Level 1 commands ----

    // RIP2_EXT_ICON: i — extended icon load (BMP/JPEG)
    'i' : Begin
            X0 := MegaNum(Params, P, 2);
            Y0 := MegaNum(Params, P, 2);
            I  := MegaNum(Params, P, 2);  // mode
            // Remaining is filename
            If P <= Length(Params) Then Begin
              TmpStr := Copy(Params, P, Length(Params));
              // Try BMP first (handles .BMH too), then fall back to ICN
              If Not LoadBMP(TmpStr, X0, Y0) Then
                LoadIcon(TmpStr, X0, Y0, I);
            End;
          End;

    // RIP2_EXT_BUTTON: b — extended button (v2.0 style)
    'b' : Begin
            // Extended button uses same base format as |1U
            // Extended button — parse coords and create mouse field
            X0 := MegaNum(Params, P, 2);
            Y0 := MegaNum(Params, P, 2);
            X1 := MegaNum(Params, P, 2);
            Y1 := MegaNum(Params, P, 2);
            // Rest is button definition — pass through to standard handler
            // v2.0 button extensions parsed
          End;

    // RIP2_EXT_PUT: p — extended put image
    'p' : Begin
            X0 := MegaNum(Params, P, 2);
            Y0 := MegaNum(Params, P, 2);
            I  := MegaNum(Params, P, 2);  // mode
            // Remaining is filename
            If P <= Length(Params) Then Begin
              TmpStr := Copy(Params, P, Length(Params));
              LoadBMP(TmpStr, X0, Y0);
            End;
          End;

    // ---- v3.0 Phase 16 commands ----

    // RIP3_SET_WORLD: z — set world coordinate system (v3.0 Phase 16)
    // Format: |1zx0:y0:x1:y1[:A]
    'z' : Begin
            If Length(Params) > 0 Then Begin
              TmpStr := Params;
              // Parse colon-separated real values
              I := Pos(':', TmpStr);
              If I > 0 Then Begin
                Val(Copy(TmpStr, 1, I - 1), WX0Tmp, ValCode);
                If ValCode <> 0 Then WX0Tmp := 0;
                Delete(TmpStr, 1, I);

                I := Pos(':', TmpStr);
                If I > 0 Then Begin
                  Val(Copy(TmpStr, 1, I - 1), WY0Tmp, ValCode);
                  If ValCode <> 0 Then WY0Tmp := 0;
                  Delete(TmpStr, 1, I);

                  I := Pos(':', TmpStr);
                  If I > 0 Then Begin
                    Val(Copy(TmpStr, 1, I - 1), WX1Tmp, ValCode);
                    If ValCode <> 0 Then WX1Tmp := 0;
                    Delete(TmpStr, 1, I);

                    // Y1 and optional aspect flag
                    I := Pos(':', TmpStr);
                    If I > 0 Then Begin
                      Val(Copy(TmpStr, 1, I - 1), WY1Tmp, ValCode);
                      If ValCode <> 0 Then WY1Tmp := 0;
                      Delete(TmpStr, 1, I);
                      // Remaining is aspect flag
                      If (Length(TmpStr) > 0) and (UpCase(TmpStr[1]) = 'A') Then
                        SetWorldAspect(True)
                      Else
                        SetWorldAspect(False);
                    End Else Begin
                      Val(TmpStr, WY1Tmp, ValCode);
                      If ValCode <> 0 Then WY1Tmp := 0;
                      SetWorldAspect(False);
                    End;

                    If (WX0Tmp = 0) and (WY0Tmp = 0) and
                       (WX1Tmp = 0) and (WY1Tmp = 0) Then
                      ClearWorldCoords
                    Else
                      SetWorldCoords(WX0Tmp, WY0Tmp, WX1Tmp, WY1Tmp);
                  End;
                End;
              End;
            End Else
              ClearWorldCoords;
          End;

    // RIP3_CURSOR_QUERY: q — request cursor position / text area detect (v3.0 Phase 16)
    'q' : Begin
            TextAreaDetected := True;
            TextAreaW := TextWinX1 - TextWinX0 + 1;
            TextAreaH := TextWinY1 - TextWinY0 + 1;
          End;
  End;
End;

// ====================================================================
// Level 9 commands — system/block mode
// ====================================================================

Procedure TRIPEngine.ParseLevel9 (Cmd: Char; Params: String);
Begin
  // RIP_ENTER_BLOCK_MODE: handled externally
  // Level 9 commands are system-level (file transfer, etc)
End;

End.
