
=====================================================================
==       SEGMENT 9: ICON & FILE PIPELINE                           ==
=====================================================================

RIPscrip supports embedded graphics (icons) within BBS screens.
Icons are small bitmapped images used for button faces, decorative
elements, and UI components. This segment documents the icon
storage, lookup, caching, and file transfer pipeline.


---------------------------------------------------------------------
9.1  ICON STORAGE ARCHITECTURE
---------------------------------------------------------------------

Icons are stored in a two-tier hybrid model:

     Tier 1 — Flash-embedded icons:
          Compiled into the firmware binary at build time.
          95 BMP icons (~1.6 MB) + 3 ICN icons (~90 KB).
          Instant lookup, zero load time.

     Tier 2 — Runtime PSRAM cache:
          Populated during a BBS session via file transfer.
          Up to 64 cached entries (ICON_CACHE_MAX).
          Allocated from the per-protocol PSRAM arena.
          Lost on disconnect (session-scoped).

Pixel format: All icons are stored as 8bpp top-down pixel data
(one byte per pixel, palette indices). BMP and ICN source formats
are decoded to this common representation.


---------------------------------------------------------------------
9.2  ICON LOOKUP ORDER
---------------------------------------------------------------------

When a RIP_LOAD_ICON command references an icon by filename, the
lookup proceeds in this order:

     1. PSRAM runtime cache — linear scan of up to 64 entries
     2. Flash BMP table — linear scan of 95 entries
     3. Flash ICN table — linear scan of 3 entries
     4. Not found — queue file request for BBS transfer

The runtime cache is checked FIRST (ahead of the flash tables) so that
an icon uploaded by the BBS, or one captured/generated at runtime
(e.g. via clipboard "write icon"), supersedes a same-named bundled
flash asset for the current session. This lets a stream override a
built-in icon without a name collision. The cache is per-session and
cleared on reset, so the flash defaults are always restored for a new
session. (RIPlib chooses cache-first deliberately; see
`11-dll-deviations.md` §DEV.2 for the rationale and the contrast with
a flash-first order.)

Filename matching:
     - Case-insensitive comparison
     - Extension stripped before matching (.BMP, .ICN removed)
     - Truncated to 12 characters (8.3 compatibility)

     Example: "MYICON.BMP", "myicon", "MYICON" all match
              the same flash entry.


---------------------------------------------------------------------
9.3  FLASH ICON ENTRY FORMAT
---------------------------------------------------------------------

Each flash-embedded icon is stored as a C struct:

     typedef struct {
          const char    *filename;   // uppercase, no extension
          const uint8_t *pixels;     // 8bpp top-down pixel data
          uint16_t       width;      // pixel width
          uint16_t       height;     // pixel height
     } rip_icon_entry_t;

The pixels array is pre-decoded at build time — no runtime
parsing is needed for flash icons. The bgi2c-style tool
(rip_icons2c.py) converts BMP files to C arrays.

Generated data files:
     rip_icons_data.c  — 95 BMP icon pixel arrays (~1.6 MB)
     rip_icons_data.h  — icon table declaration
     rip_icns_data.c   — 3 ICN icon pixel arrays (~90 KB)
     rip_icns_data.h   — ICN table declaration


---------------------------------------------------------------------
9.4  RUNTIME CACHE ENTRY FORMAT
---------------------------------------------------------------------

Runtime-cached icons use the same pixel format:

     typedef struct {
          char     name[13];     // uppercase, no extension
          uint8_t *pixels;       // PSRAM-allocated pixel data
          uint16_t width;
          uint16_t height;
     } icon_cache_entry_t;

Cache management:
     - Entries are added via rip_icon_cache_bmp() or
       rip_icon_cache_pixels()
     - Cache is cleared when the PSRAM arena is reset
       (protocol switch or session disconnect)
     - No eviction policy — cache grows until full (64 entries)
       or arena exhausted


---------------------------------------------------------------------
9.5  BMP FORMAT SUPPORT
---------------------------------------------------------------------

RIPlib supports a subset of the Windows BMP format for icon data:

     Supported:
          - BMP header with 'BM' magic (bytes 0-1)
          - 54-byte minimum header (BITMAPINFOHEADER)
          - 4bpp (16-color) uncompressed
          - 8bpp (256-color) uncompressed
          - BI_RGB compression (type 0) only
          - Dimensions: 1-640 width, 1-400 height
          - Top-down and bottom-up row ordering

     Rejected:
          - RLE4 or RLE8 compression      (compression field != 0)
          - 16bpp, 24bpp, or 32bpp        (bit-count field not 4 or 8)
          - width outside 1-640, height outside 1-400
          - a pixel offset at or past the end of the buffer, or a
            pixel array that would run past it

     The decoder reads the bit count and compression fields at their
     BITMAPINFOHEADER offsets and does NOT inspect the DIB header
     size, which has two consequences worth stating plainly:

          - BITMAPV4/V5 headers are not rejected.  Those layouts keep
            the bit count and compression fields at the same offsets,
            so a V4 or V5 file carrying 4bpp or 8bpp BI_RGB data
            decodes normally.  The extra colour-space fields are
            ignored, which for indexed data changes nothing.

          - OS/2 BITMAPCOREHEADER files are rejected, but as a
            side-effect rather than by a check.  That layout puts
            16-bit width and height at offsets 18 and 20 and the bit
            count at 24, so the fields read at 28 and 30 are not the
            ones intended and effectively always fail the bit-count
            or range tests.  Do not rely on this as a validated
            refusal.

BMP header fields used:

     Offset   Size   Field
     ------   ----   -----
     0-1      2      Magic ('BM')
     10-13    4      Pixel data offset (LE dword)
     18-21    4      Width (signed LE dword)
     22-25    4      Height (signed LE dword, negative=top-down)
     28-29    2      Bits per pixel (4 or 8)
     30-33    4      Compression type (must be 0)

Row stride calculation:

     4bpp: stride = ((width + 1) / 2 + 3) & ~3
     8bpp: stride = (width + 3) & ~3

     Rows are 4-byte aligned per BMP specification.

Decoding to 8bpp:

     4bpp: each byte → two pixels (high nibble first)
           pixel_value = palette_index (0-15)
     8bpp: direct copy (each byte = one palette index)

Output is always top-down regardless of input orientation.


---------------------------------------------------------------------
9.6  ICN FORMAT (BGI PUTIMAGE)
---------------------------------------------------------------------

The ICN format is the Borland BGI putimage binary format. It
stores images as interleaved EGA bitplanes.

Header (6 bytes minimum):

     Offset   Size   Field
     ------   ----   -----
     0-1      2      Width - 1 (LE word)
     2-3      2      Height - 1 (LE word)
     4-5      2      Reserved (ignored)

     Actual width  = header_word_0 + 1
     Actual height = header_word_2 + 1

Pixel data (4 bitplanes per row):

     Each row consists of 4 sequential bitplanes:
          Plane 0 (Blue):      ceil(width/8) bytes
          Plane 1 (Green):     ceil(width/8) bytes
          Plane 2 (Red):       ceil(width/8) bytes
          Plane 3 (Intensity): ceil(width/8) bytes

     Total row stride = ceil(width/8) × 4 bytes

Deinterleaving to 8bpp:

     For each pixel at column x:
          byte_index = x >> 3
          bit_mask   = 0x80 >> (x & 7)

          blue  = (plane0[byte_index] & bit_mask) ? 1 : 0
          green = (plane1[byte_index] & bit_mask) ? 1 : 0
          red   = (plane2[byte_index] & bit_mask) ? 1 : 0
          intns = (plane3[byte_index] & bit_mask) ? 1 : 0

          palette_index = (intns << 3) | (red << 2) |
                          (green << 1) | blue

     This maps directly to the EGA 16-color palette (indices 0-15).


---------------------------------------------------------------------
9.7  RAF FORMAT (RIP ARCHIVE)
---------------------------------------------------------------------

RAF (RIP Archive Format) is a compressed archive containing
multiple icon files. It uses a proprietary compression scheme
developed by TeleGrafix.

     Magic:    "SQSH" at offset 0x10 in the 0x64-byte header
     Format:   0x13-byte index entries (XOR-encoded)
     Compress: LZ-based with ring buffer

RAF support is optional in RIPlib (guarded by RIPLIB_HAS_RAF).
When available, the archive is decompressed member-by-member,
and each member is routed to the BMP or ICN parser based on
magic bytes or heuristic size analysis.

     DLL reference:
          ripResFileReadIndex (RVA 0x0648B9) — index parsing
          sub_0756C4 — XOR decoding of index entries
          rafDecompressEntry (RVA 0x064D68) — decompression
          rafInflateBlock (RVA 0x06522A) — block inflate


---------------------------------------------------------------------
9.8  FILE REQUEST QUEUE
---------------------------------------------------------------------

When an icon lookup fails (not in flash or cache), the filename
is queued for file transfer from the BBS.

Queue parameters:
     Maximum pending requests: 16
     Maximum filename length:  12 characters
     Deduplication:           yes (scan before enqueue)
     Order:                   FIFO

API:

     bool rip_icon_request_file(name, name_len)
          Enqueue a file request. Returns false if queue full.
          Strips extension, normalizes to uppercase.
          Rejects duplicates (returns true if already queued).

     int rip_icon_pending_requests(void)
          Returns number of pending requests.

     int rip_icon_dequeue_request(name_out, max_len)
          Dequeue the oldest request (FIFO).
          Returns filename length, or 0 if empty.

     void rip_icon_clear_requests(void)
          Clear all pending requests. Called on session reset
          to prevent cross-session request bleeding.

The file transfer mechanism (Zmodem or platform-specific) is
outside the scope of the icon pipeline. The queue provides
the interface between "icon not found" and "request download."


---------------------------------------------------------------------
9.9  ICON DISPLAY (RIP_LOAD_ICON FLOW)
---------------------------------------------------------------------

Complete flow when |1I (RIP_LOAD_ICON) is processed:

     1. Parse command: x, y, mode, clipboard, filename
     2. Strip extension from filename
     3. Call rip_icon_lookup(name, len, &icon)
     4. If found:
          a. If clipboard flag: copy icon to clipboard buffer
          b. Blit icon pixels to framebuffer at (x, y)
             using draw_restore_region()
          c. Done
     5. If not found:
          a. Call rip_icon_request_file(name, len)
          b. Queue the file for BBS transfer
          c. Icon not displayed (blank area)
          d. When file arrives (via Zmodem or FILE_UPLOAD),
             it is decoded and cached via rip_icon_cache_bmp()
             or rip_icon_cache_pixels()
          e. BBS may re-send the LOAD_ICON command after transfer


---------------------------------------------------------------------
9.10  PSRAM ARENA MANAGEMENT
---------------------------------------------------------------------

Icon pixel data and font data are allocated from a per-protocol
PSRAM arena. The arena is a simple bump allocator:

     typedef struct {
          uint8_t *base;      // start of arena memory
          uint32_t size;      // total capacity
          uint32_t used;      // current allocation offset
     } psram_arena_t;

     void *psram_arena_alloc(arena, size)
          Bump-allocate with 32-byte alignment.
          Returns NULL if insufficient space.

     void psram_arena_reset(arena)
          Reset used to 0 (frees all allocations).

Arena lifecycle:
     - Allocated once at boot (rip_init_first)
     - Reset on protocol switch (rip_session_reset)
     - All cached icons and fonts become invalid after reset
     - Flash-embedded icons remain valid (not arena-allocated)

On desktop platforms (RIPlib standalone), the arena can be
backed by malloc() — see riplib_platform.h for the stub
implementation.


=====================================================================
==                    END OF SEGMENT 9                              ==
==           Icon & File Pipeline                                   ==
=====================================================================

Next: Segment 10 — Appendices
