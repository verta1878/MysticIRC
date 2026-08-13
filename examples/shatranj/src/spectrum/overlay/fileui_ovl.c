/*
 * fileui_ovl.c -- FILE browser overlay: single-column saved-game list
 * inside the board frame, 10 slots with name plus FAT date/time taken
 * straight from the esxDOS directory entry (no extra file I/O). Rows come
 * from a /SYS/CONFIG scan (*.STJ, size>0); remaining slots are free and
 * saving there auto-names NNYMDHMM, where YMDHMM encodes date/time.
 *
 * Cursor navigation is handled by the resident spectrum/fileui module so
 * moving around never reloads this overlay; the overlay only renders the
 * list (RENDER, ctx KEY byte = 1 for list-only refresh without the frame
 * wipe) and resolves the selected/generated file name (PICK).
 */

#include "spectrum/overlay/overlay_api.h"
#include "spectrum/overlay/overlay_context.h"
/* Resident render helpers (declared locally: overlays do not include
   spectrum/ui headers; the capabilities policy governs these imports). */
void spectrum_render_ikkle_at(const char *spec) __z88dk_fastcall;
void spectrum_render_fileui_frame(void);
void spectrum_render_fileui_select(uint16_t slot_on) __z88dk_fastcall;

extern uint8_t spectrum_fileui_count;
extern uint16_t spectrum_fileui_used_mask;
extern uint8_t esx_handle;
extern uint16_t esx_buf;
extern uint16_t esx_count;
extern uint16_t esx_result;
void esx_fopen(const char *path) __z88dk_fastcall;
uint8_t esx_fclose(void);
void esx_opendir(const char *path) __z88dk_fastcall;
void esx_readdir(void);

#define FILEUI_SLOTS 10u
#define FILEUI_NAME_MAX 8u
#define FILEUI_LINE_WIDTH 24u

#define FILEUI_ROW_HEADER 5u
#define FILEUI_ROW_LEGEND 7u
#define FILEUI_ROW_FIRST 9u
#define FILEUI_ROW_FOOTER 20u

#define FILEUI_COL_ITEM 4u
#define FILEUI_COL_HEADER 12u
#define FILEUI_COL_FOOTER 6u

#define FILEUI_ATTR_HEADER 0x38u
#define FILEUI_ATTR_LEGEND 0x06u
#define FILEUI_ATTR_SAVED 0x05u
#define FILEUI_ATTR_FREE 0x07u
#define FILEUI_ATTR_FOOTER 0x06u

/* esxDOS F_READDIR short entry: attr byte, ASCIIZ 8.3 name, 2 bytes time,
   2 bytes date, 4 bytes size. */
#define FILEUI_DIRENT_MAX 24u
#define FILEUI_ATTR_DIR 0x10u

static char fileui_dir[] = "/SYS/CONFIG";
static unsigned char fileui_name_stamp[4];

/* FAT stamp (time lo/hi, date lo/hi) of the entry accepted last by
   fileui_entry_stj; points into the caller's dirent buffer. */
static const unsigned char *fileui_stamp;

static char *fileui_ctx_name(uint8_t *ctx)
{
    return (char *)((uint16_t)ctx[SPECTRUM_OVL_CTX_FILEUI_NAME_LO] |
                    ((uint16_t)ctx[SPECTRUM_OVL_CTX_FILEUI_NAME_HI] << 8));
}

static uint8_t fileui_b32_value(char c)
{
    if (c >= '0' && c <= '9') {
        return (uint8_t)(c - '0');
    }
    if (c >= 'A' && c <= 'V') {
        return (uint8_t)(c - ('A' - 10));
    }
    return 0xffu;
}


static uint8_t fileui_decode_name_stamp(const char *name)
{
    uint8_t year = fileui_b32_value(name[2]);
    uint8_t month = fileui_b32_value(name[3]);
    uint8_t day = fileui_b32_value(name[4]);
    uint8_t hour = fileui_b32_value(name[5]);
    uint8_t minute;

    if (name[6] < '0' || name[6] > '9' ||
        name[7] < '0' || name[7] > '9') {
        return 0u;
    }
    minute = (uint8_t)(((uint8_t)(name[6] - '0') * 10u) +
                       (uint8_t)(name[7] - '0'));
    if (year > 31u || month == 0u || month > 12u ||
        day == 0u || day > 31u || hour >= 24u || minute >= 60u) {
        return 0u;
    }
    fileui_name_stamp[0] = (uint8_t)(minute << 5);
    fileui_name_stamp[1] = (uint8_t)((hour << 3) | (minute >> 3));
    fileui_name_stamp[2] = (uint8_t)(((month & 7u) << 5) | day);
    fileui_name_stamp[3] = (uint8_t)(((year + 40u) << 1) | (month >> 3));
    fileui_stamp = fileui_name_stamp;
    return 1u;
}



/* Accepts a plain *.STJ file entry with size > 0; copies the name without
   the extension into out (out[FILEUI_NAME_MAX + 1]) and latches the FAT
   stamp pointer. */
static uint8_t fileui_entry_stj(const unsigned char *ent, char *out)
{
    const unsigned char *p = ent + 1u;
    const unsigned char *end = ent + FILEUI_DIRENT_MAX;
    const unsigned char *dot = 0;
    uint8_t n = 0u;
    uint8_t slot;

    if (ent[0] & FILEUI_ATTR_DIR) {
        return 0u;
    }
    while (p < end && *p) {
        if (*p == '.') {
            dot = p;
        }
        ++p;
    }
    if (p >= end || !dot || (uint8_t)(p - dot) != 4u ||
        dot[1] != 'S' || dot[2] != 'T' || dot[3] != 'J') {
        return 0u;
    }
    /* size dword follows name NUL + 2 bytes time + 2 bytes date */
    if ((uint8_t)(end - p) <= 8u) {
        return 0u;
    }
    if (!(p[5] | p[6] | p[7] | p[8])) {
        return 0u;
    }
    fileui_stamp = p + 1u;
    p = ent + 1u;
    while (p < dot && n < FILEUI_NAME_MAX) {
        out[n++] = (char)*p++;
    }
    out[n] = '\0';
    out[FILEUI_NAME_MAX] = '\0';
    if (n != FILEUI_NAME_MAX || out[0] < '0' || out[0] > '9' ||
        out[1] < '0' || out[1] > '9') {
        return 0u;
    }
    slot = (uint8_t)(((uint8_t)(out[0] - '0') * 10u) +
                     (uint8_t)(out[1] - '0'));
    if (slot == 0u || slot > FILEUI_SLOTS) {
        return 0u;
    }
    return fileui_decode_name_stamp(out);
}

/* Copies the name of the index-th saved game into out. Returns 1 if found. */
static uint8_t fileui_nth_name(uint8_t index, char *out)
{
    unsigned char ent[FILEUI_DIRENT_MAX];
    uint8_t found = 0u;

    esx_opendir(fileui_dir);
    if (!esx_handle) {
        return 0u;
    }
    for (;;) {
        esx_buf = (uint16_t)ent;
        esx_readdir();
        spectrum_net_background_drain();
        if (!esx_result) {
            break;
        }
        if (fileui_entry_stj(ent, out)) {
            if (found == index) {
                esx_fclose();
                return 1u;
            }
            ++found;
        }
    }
    esx_fclose();
    return 0u;
}


static uint8_t fileui_gen_slot(char *out) __z88dk_fastcall
{
    uint16_t used = spectrum_fileui_used_mask;
    uint16_t bit = 1u;
    uint8_t n;

    for (n = 1u; n <= FILEUI_SLOTS; ++n) {
        if (!(used & bit)) {
            out[0] = '0';
            out[1] = (char)('0' + n);
            if (n == 10u) {
                out[0] = '1';
                out[1] = '0';
            }
            out[2] = '\0';
            return 1u;
        }
        bit <<= 1;
    }
    return 0u;
}
static void fileui_text(uint8_t row, uint8_t col, uint8_t attr,
                        const char *text)
{
    char spec[32]; /* 3-byte header + widest line (24 chars) + NUL */
    char *q = spec + 3;

    spec[0] = (char)row;
    spec[1] = (char)col;
    spec[2] = (char)attr;
    while (*text) {
        *q++ = *text++;
    }
    *q = '\0';
    spectrum_render_ikkle_at(spec);
}

static char *fileui_two(char *q, uint8_t v)
{
    char t = '0';

    while (v >= 10u) {
        v -= 10u;
        ++t;
    }
    *q++ = t;
    *q++ = (char)('0' + v);
    return q;
}

/* "NAME     DD-MM-YY HH:MM" from the dirent name and FAT stamp. */
static void fileui_row(uint8_t slot, const char *name)
{
    char line[FILEUI_LINE_WIDTH + 1u];
    char *q = line;
    const unsigned char *s = fileui_stamp;
    uint8_t v;

    if (name) {
        *q++ = 'G';
        *q++ = 'A';
        *q++ = 'M';
        *q++ = 'E';
        if (name[0] != '0') {
            *q++ = name[0];
        }
        *q++ = name[1];
        while (q < line + FILEUI_NAME_MAX + 1u) {
            *q++ = ' ';
        }
        q = fileui_two(q, (uint8_t)(s[2] & 31u));
        *q++ = '-';
        v = (uint8_t)(((s[3] & 1u) << 3) | (s[2] >> 5));
        q = fileui_two(q, v);
        *q++ = '-';
        v = (uint8_t)(80u + (s[3] >> 1));
        while (v >= 100u) {
            v = (uint8_t)(v - 100u);
        }
        q = fileui_two(q, v);
        *q++ = ' ';
        q = fileui_two(q, (uint8_t)(s[1] >> 3));
        *q++ = ':';
        v = (uint8_t)(((s[1] & 7u) << 3) | (s[0] >> 5));
        q = fileui_two(q, v);
    } else {
        *q++ = '-';
        *q++ = 'F';
        *q++ = 'R';
        *q++ = 'E';
        *q++ = 'E';
        *q++ = '-';
    }
    /* Pad so a shrinking line self-clears its old tail. */
    while (q < line + FILEUI_LINE_WIDTH) {
        *q++ = ' ';
    }
    *q = '\0';
    fileui_text((uint8_t)(FILEUI_ROW_FIRST + slot), FILEUI_COL_ITEM,
                name ? FILEUI_ATTR_SAVED : FILEUI_ATTR_FREE, line);
}

static void fileui_footer(void)
{
    static const char footer[] = "ENTER-LOAD/SAVE  E-ERASE";

    fileui_text(FILEUI_ROW_FOOTER, FILEUI_COL_FOOTER, FILEUI_ATTR_FOOTER,
                footer);
}

uint8_t fileui_render_ovl(uint8_t *ctx) __z88dk_fastcall
{
    static const char header[] = " SAVED GAMES";
    static const char legend[] = "NAME     DATE     TIME";
    unsigned char ent[FILEUI_DIRENT_MAX];
    char name[FILEUI_NAME_MAX + 1u];
    uint8_t sel = ctx[SPECTRUM_OVL_CTX_FILEUI_SEL];
    uint8_t list_only = ctx[SPECTRUM_OVL_CTX_FILEUI_KEY];
    /* List-only refresh: free rows past the previous count are already
       correct on screen, so only repaint up to it. */
    uint8_t limit = list_only ? spectrum_fileui_count : FILEUI_SLOTS;
    uint8_t count = 0u;
    uint8_t slot;
    uint16_t used = 0u;

    /* RENDER must leave a deterministic ACTION for the resident caller. */
    ctx[SPECTRUM_OVL_CTX_FILEUI_ACTION] = SPECTRUM_OVL_FILEUI_ACT_NONE;
    if (!list_only) {
        spectrum_render_fileui_frame();
        fileui_text(FILEUI_ROW_HEADER, FILEUI_COL_HEADER, FILEUI_ATTR_HEADER,
                    header);
        fileui_text(FILEUI_ROW_LEGEND, FILEUI_COL_ITEM, FILEUI_ATTR_LEGEND,
                    legend);
        fileui_footer();
    }
    esx_opendir(fileui_dir);
    if (esx_handle) {
        while (count < FILEUI_SLOTS) {
            esx_buf = (uint16_t)ent;
            esx_readdir();
            spectrum_net_background_drain();
            if (!esx_result) {
                break;
            }
            if (fileui_entry_stj(ent, name)) {
                slot = (uint8_t)(((uint8_t)(name[0] - '0') * 10u) +
                                 (uint8_t)(name[1] - '0'));
                used |= (uint16_t)(1u << (slot - 1u));
                fileui_row(count, name);
                ++count;
            }
        }
        esx_fclose();
    }
    for (slot = count; slot < limit; ++slot) {
        fileui_row(slot, 0);
    }
    spectrum_fileui_count = count;
    spectrum_fileui_used_mask = used;
    spectrum_render_fileui_select((uint16_t)(1u << 8) | sel);
    return 1u;
}

/* Resolves the file name for the current selection into the resident
   buffer: ACTION = 1 existing file name, 2 generated free-slot name,
   0 not found. */
uint8_t fileui_pick_ovl(uint8_t *ctx) __z88dk_fastcall
{
    uint8_t sel = ctx[SPECTRUM_OVL_CTX_FILEUI_SEL];
    uint8_t count = spectrum_fileui_count;
    char *dst = fileui_ctx_name(ctx);


    ctx[SPECTRUM_OVL_CTX_FILEUI_ACTION] = 0u;
    if (sel < count) {
        if (fileui_nth_name(sel, dst)) {
            ctx[SPECTRUM_OVL_CTX_FILEUI_ACTION] = 1u;
        }
    } else if (fileui_gen_slot(dst)) {
        ctx[SPECTRUM_OVL_CTX_FILEUI_ACTION] = 2u;
    }
    return 1u;
}
