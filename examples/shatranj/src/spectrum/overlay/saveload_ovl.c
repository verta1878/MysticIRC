#include "spectrum/overlay/overlay_api.h"
#include "spectrum/overlay/overlay_context.h"
#include "common/savegame/savegame_format.h"

extern uint8_t esx_handle;
extern uint16_t esx_buf;
extern uint16_t esx_count;
extern uint16_t esx_result;
void esx_fopen(const char *path) __z88dk_fastcall;
void esx_fcreate(const char *path) __z88dk_fastcall;
void esx_fread(void);
void esx_fwrite(void);
uint8_t esx_fclose(void);
void esx_funlink(const char *path) __z88dk_fastcall;

#define SAVELOAD_DIR "/SYS/CONFIG/"
#define SAVELOAD_EXT ".STJ"
#define SAVELOAD_NAME_MAX 8u
#define SAVELOAD_PATH_MAX 25u

static char saveload_path[SAVELOAD_PATH_MAX];

static uint8_t saveload_name_char_ok(char c)
{
    return (uint8_t)((c >= 'A' && c <= 'Z') ||
                     (c >= 'a' && c <= 'z') ||
                     (c >= '0' && c <= '9') ||
                     c == '_');
}

static char saveload_upper(char c) __z88dk_fastcall
{
    if (c >= 'a' && c <= 'z') {
        c = (char)(c - ('a' - 'A'));
    }
    return c;
}

static char saveload_b32_char(uint8_t v) __z88dk_fastcall
{
    return (char)(v < 10u ? ('0' + v) : ('A' + v - 10u));
}

static uint8_t saveload_stamp_valid(uint8_t year,
                                    uint8_t month,
                                    uint8_t day,
                                    uint8_t hour,
                                    uint8_t minute)
{
    if (year < 40u) {
        return 0u;
    }
    if (year > 71u) {
        return 0u;
    }
    if (month == 0u || month > 12u) {
        return 0u;
    }
    if (day == 0u || day > 31u) {
        return 0u;
    }
    if (hour >= 24u || minute >= 60u) {
        return 0u;
    }
    return 1u;
}

static void saveload_write_stamp(char *out) __z88dk_fastcall
{
    uint16_t date = spectrum_net_runtime_fat_date();
    uint16_t time = spectrum_net_runtime_fat_time();
    uint8_t year = (uint8_t)(date >> 9);
    uint8_t month = (uint8_t)((date >> 5) & 15u);
    uint8_t day = (uint8_t)(date & 31u);
    uint8_t hour = (uint8_t)(time >> 11);
    uint8_t minute = (uint8_t)((time >> 5) & 63u);
    char tens = '0';

    if (saveload_stamp_valid(year, month, day, hour, minute)) {
        year = (uint8_t)(year - 40u);
    } else {
        year = month = day = hour = minute = 0u;
    }
    while (minute >= 10u) {
        minute = (uint8_t)(minute - 10u);
        ++tens;
    }
    out[0] = saveload_b32_char(year);
    out[1] = saveload_b32_char(month);
    out[2] = saveload_b32_char(day);
    out[3] = saveload_b32_char(hour);
    out[4] = tens;
    out[5] = (char)('0' + minute);
}

static uint8_t saveload_build_path(const char *name, uint8_t stamp_slot)
{
    static const char dir[] = SAVELOAD_DIR;
    static const char ext[] = SAVELOAD_EXT;
    uint8_t i;
    uint8_t out = 0u;

    if (name == 0 || name[0] == '\0') {
        return 0u;
    }
    for (i = 0u; dir[i] != '\0'; ++i) {
        saveload_path[out++] = dir[i];
    }
    if (stamp_slot && name[0] >= '0' && name[0] <= '9' &&
        name[1] >= '0' && name[1] <= '9' && name[2] == '\0') {
        saveload_path[out++] = name[0];
        saveload_path[out++] = name[1];
        saveload_write_stamp(saveload_path + out);
        out = (uint8_t)(out + 6u);
    } else {
        for (i = 0u; name[i] != '\0'; ++i) {
            if (i >= SAVELOAD_NAME_MAX || !saveload_name_char_ok(name[i])) {
                return 0u;
            }
            saveload_path[out++] = saveload_upper(name[i]);
        }
    }
    for (i = 0u; ext[i] != '\0'; ++i) {
        saveload_path[out++] = ext[i];
    }
    saveload_path[out] = '\0';
    return 1u;
}
static const char *saveload_ctx_name(uint8_t *ctx)
{
    return (const char *)((uint16_t)ctx[SPECTRUM_OVL_CTX_SAVELOAD_NAME_LO] |
                          ((uint16_t)ctx[SPECTRUM_OVL_CTX_SAVELOAD_NAME_HI] << 8));
}

static char *saveload_ctx_buf(uint8_t *ctx)
{
    return (char *)((uint16_t)ctx[SPECTRUM_OVL_CTX_SAVELOAD_BUF_LO] |
                    ((uint16_t)ctx[SPECTRUM_OVL_CTX_SAVELOAD_BUF_HI] << 8));
}

uint8_t saveload_erase_nczs_ovl(uint8_t *ctx) __z88dk_fastcall
{
    ctx[SPECTRUM_OVL_CTX_SAVELOAD_RESULT] = SPECTRUM_OVL_SAVELOAD_ERR_NAME;
    if (!saveload_build_path(saveload_ctx_name(ctx), 0u)) {
        return 0u;
    }
    ctx[SPECTRUM_OVL_CTX_SAVELOAD_RESULT] = SPECTRUM_OVL_SAVELOAD_ERR_OPEN;
    esx_funlink(saveload_path);
    if (!esx_result) {
        return 0u;
    }
    ctx[SPECTRUM_OVL_CTX_SAVELOAD_RESULT] = SPECTRUM_OVL_SAVELOAD_OK;
    return 1u;
}

uint8_t saveload_load_nczs_ovl(uint8_t *ctx) __z88dk_fastcall
{
    char *buf = saveload_ctx_buf(ctx);

    ctx[SPECTRUM_OVL_CTX_SAVELOAD_RESULT] = SPECTRUM_OVL_SAVELOAD_ERR_NAME;
    if (buf == 0 || !saveload_build_path(saveload_ctx_name(ctx), 0u)) {
        return 0u;
    }
    esx_fopen(saveload_path);
    if (esx_handle == 0u) {
        ctx[SPECTRUM_OVL_CTX_SAVELOAD_RESULT] = SPECTRUM_OVL_SAVELOAD_ERR_OPEN;
        return 0u;
    }
    spectrum_net_background_drain();
    esx_buf = (uint16_t)buf;
    esx_count = NETCHESSZX_SAVE_WIRE_B64_SIZE;
    esx_fread();
    if (esx_fclose() || esx_result != NETCHESSZX_SAVE_WIRE_B64_SIZE) {
        ctx[SPECTRUM_OVL_CTX_SAVELOAD_RESULT] = SPECTRUM_OVL_SAVELOAD_ERR_DATA;
        return 0u;
    }
    ctx[SPECTRUM_OVL_CTX_SAVELOAD_RESULT] = SPECTRUM_OVL_SAVELOAD_OK;
    return 1u;
}

uint8_t saveload_save_nczs_ovl(uint8_t *ctx) __z88dk_fastcall
{
    const char *buf = saveload_ctx_buf(ctx);

    ctx[SPECTRUM_OVL_CTX_SAVELOAD_RESULT] = SPECTRUM_OVL_SAVELOAD_ERR_NAME;
    if (buf == 0 || !saveload_build_path(saveload_ctx_name(ctx), 1u)) {
        return 0u;
    }
    esx_fcreate(saveload_path);
    if (esx_handle == 0u) {
        ctx[SPECTRUM_OVL_CTX_SAVELOAD_RESULT] = SPECTRUM_OVL_SAVELOAD_ERR_OPEN;
        return 0u;
    }
    spectrum_net_background_drain();
    esx_buf = (uint16_t)buf;
    esx_count = NETCHESSZX_SAVE_WIRE_B64_SIZE;
    esx_fwrite();
    if (esx_fclose() || esx_result != NETCHESSZX_SAVE_WIRE_B64_SIZE) {
        ctx[SPECTRUM_OVL_CTX_SAVELOAD_RESULT] = SPECTRUM_OVL_SAVELOAD_ERR_IO;
        return 0u;
    }
    ctx[SPECTRUM_OVL_CTX_SAVELOAD_RESULT] = SPECTRUM_OVL_SAVELOAD_OK;
    return 1u;
}
