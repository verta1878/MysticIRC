#include "spectrum/overlay/overlay_api.h"
#include "spectrum/lowram_map.h"

#define KEY_UP 0x81u
#define KEY_DOWN 0x82u
#define KEY_LEFT 0x83u
#define KEY_RIGHT 0x84u
#define KEY_HOME 0x88u
#define KEY_END 0x89u
#define INPUT_HISTORY_SIZE 2u
#define INPUT_HISTORY_NONE 0xffu
#define LOCAL_INPUT_MAX ((uint8_t)(NETCHESSZX_LOWRAM_LOCAL_INPUT_SIZE - 1u))
#define INPUT_HISTORY_TEXT_MAX ((uint8_t)((NETCHESSZX_LOWRAM_INPUT_HISTORY_SIZE / INPUT_HISTORY_SIZE) - 1u))

#define local_input ((char *)NETCHESSZX_LOWRAM_LOCAL_INPUT_ADDR)
#define input_history ((char *)NETCHESSZX_LOWRAM_INPUT_HISTORY_ADDR)
#define input_history_slot(index) \
    (input_history + ((uint16_t)(index) * (INPUT_HISTORY_TEXT_MAX + 1u)))

extern uint8_t local_input_len;
extern uint8_t local_input_cursor;
extern uint8_t local_input_mode;
extern uint8_t input_history_count;
extern uint8_t input_history_pos;

static uint8_t input_has_text_ovl(const char *text)
{
    while (*text != '\0') {
        if (*text != ' ') {
            return 1u;
        }
        ++text;
    }
    return 0u;
}

static char edit_char_at(uint8_t pos)
{
    return pos < local_input_len ? local_input[pos] : ' ';
}

static void edit_draw_cell(uint8_t pos, uint8_t cursor)
{
    spectrum_gui_input_cell(pos, edit_char_at(pos), cursor);
}

static void edit_cursor_show(void)
{
    edit_draw_cell(local_input_cursor, 1u);
}

static void edit_render_impl(void)
{
    spectrum_gui_set_input_edit(local_input, local_input_len, local_input_cursor);
}

static void edit_redraw_from(uint8_t start, uint8_t old_len)
{
    uint8_t i;

    for (i = start; i < local_input_len; ++i) {
        edit_draw_cell(i, 0u);
    }
    while (i <= old_len && i <= LOCAL_INPUT_MAX) {
        spectrum_gui_input_cell(i, ' ', 0u);
        ++i;
    }
    edit_cursor_show();
}

static void edit_history_nav_reset(void)
{
    input_history_pos = INPUT_HISTORY_NONE;
}

static void edit_set_text(const char *text)
{
    uint8_t n = 0u;

    while (n < LOCAL_INPUT_MAX && text[n] != '\0') {
        local_input[n] = text[n];
        ++n;
    }
    local_input[n] = '\0';
    local_input_len = n;
    local_input_cursor = n;
    edit_render_impl();
}

static void edit_insert_char(uint8_t key)
{
    char c = (char)key;
    uint8_t old_cursor;
    uint8_t old_len;
    uint8_t i;

    if (key < 32u || key >= 127u || local_input_len >= LOCAL_INPUT_MAX) {
        return;
    }
    old_cursor = local_input_cursor;
    old_len = local_input_len;
    i = (uint8_t)(local_input_len + 1u);
    while (i != local_input_cursor) {
        local_input[i] = local_input[(uint8_t)(i - 1u)];
        --i;
    }
    local_input[local_input_cursor] = c;
    ++local_input_len;
    ++local_input_cursor;
    edit_history_nav_reset();
    if (old_cursor == old_len) {
        spectrum_gui_input_cell(old_cursor, c, 0u);
        edit_cursor_show();
    } else {
        edit_redraw_from(old_cursor, old_len);
    }
}

static void edit_backspace(void)
{
    uint8_t old_len;
    uint8_t i;
    char ch;

    if (local_input_cursor == 0u) {
        return;
    }
    old_len = local_input_len;
    i = local_input_cursor;
    do {
        ch = local_input[i];
        local_input[(uint8_t)(i - 1u)] = ch;
        ++i;
    } while (ch != '\0');
    --local_input_cursor;
    --local_input_len;
    edit_history_nav_reset();
    edit_redraw_from(local_input_cursor, old_len);
}

static void edit_cursor_to(uint8_t cursor)
{
    uint8_t old_cursor = local_input_cursor;

    if (old_cursor != cursor) {
        local_input_cursor = cursor;
        spectrum_gui_input_cell(old_cursor, edit_char_at(old_cursor), 0u);
        edit_cursor_show();
    }
}

static void edit_history_up(void)
{
    uint8_t index;

    if (input_history_count == 0u) {
        return;
    }
    if (input_history_pos == INPUT_HISTORY_NONE) {
        input_history_pos = 0u;
    } else if ((uint8_t)(input_history_pos + 1u) < input_history_count) {
        ++input_history_pos;
    }
    index = (uint8_t)(input_history_count - 1u - input_history_pos);
    edit_set_text(input_history_slot(index));
}

static void edit_history_down(void)
{
    if (input_history_pos == INPUT_HISTORY_NONE) {
        return;
    }
    if (input_history_pos == 0u) {
        input_history_pos = INPUT_HISTORY_NONE;
        edit_set_text("");
        return;
    }
    --input_history_pos;
    edit_set_text(input_history_slot(input_history_count - 1u - input_history_pos));
}

uint8_t input_edit_render_ovl(uint8_t *ctx) __z88dk_fastcall
{
    (void)ctx;
    edit_render_impl();
    return 1u;
}

uint8_t input_edit_begin_empty_ovl(uint8_t *ctx) __z88dk_fastcall
{
    (void)ctx;
    local_input[0] = '\0';
    local_input_len = 0u;
    local_input_cursor = 0u;
    local_input_mode = 1u;
    edit_history_nav_reset();
    edit_render_impl();
    return 1u;
}

uint8_t input_edit_stop_clear_ovl(uint8_t *ctx) __z88dk_fastcall
{
    (void)ctx;
    local_input[0] = '\0';
    local_input_len = 0u;
    local_input_cursor = 0u;
    local_input_mode = 0u;
    edit_history_nav_reset();
    spectrum_gui_set_input("");
    return 1u;
}

uint8_t input_edit_key_ovl(uint8_t *ctx) __z88dk_fastcall
{
    uint8_t key = ctx[SPECTRUM_OVL_CTX_INPUT_KEY];

    if (key == 8u) {
        edit_backspace();
    } else if (key == KEY_LEFT) {
        if (local_input_cursor > 0u) {
            edit_cursor_to((uint8_t)(local_input_cursor - 1u));
        }
    } else if (key == KEY_RIGHT) {
        if (local_input_cursor < local_input_len) {
            edit_cursor_to((uint8_t)(local_input_cursor + 1u));
        }
    } else if (key == KEY_UP) {
        edit_history_up();
    } else if (key == KEY_DOWN) {
        edit_history_down();
    } else if (key == KEY_HOME) {
        edit_cursor_to(0u);
    } else if (key == KEY_END) {
        edit_cursor_to(local_input_len);
    } else {
        edit_insert_char(key);
    }
    return 1u;
}

uint8_t input_edit_history_add_ovl(uint8_t *ctx) __z88dk_fastcall
{
    const char *text =
        (const char *)((uint16_t)ctx[SPECTRUM_OVL_CTX_PTR_LO] |
                       ((uint16_t)ctx[SPECTRUM_OVL_CTX_PTR_HI] << 8));
    char *slot;
    uint8_t i;

    if (!input_has_text_ovl(text)) {
        return 1u;
    }
    if (input_history_count != 0u) {
        const char *last = input_history_slot(input_history_count - 1u);
        i = 0u;
        while (i <= INPUT_HISTORY_TEXT_MAX && last[i] == text[i]) {
            if (last[i] == '\0') {
                return 1u;
            }
            ++i;
        }
    }
    if (input_history_count < INPUT_HISTORY_SIZE) {
        slot = input_history_slot(input_history_count);
        ++input_history_count;
    } else {
        char *dst = input_history_slot(0u);
        const char *src = input_history_slot(1u);

        for (i = 0u; i <= INPUT_HISTORY_TEXT_MAX; ++i) {
            dst[i] = src[i];
        }
        slot = input_history_slot(INPUT_HISTORY_SIZE - 1u);
    }
    for (i = 0u; i < INPUT_HISTORY_TEXT_MAX && text[i] != '\0'; ++i) {
        slot[i] = text[i];
    }
    slot[i] = '\0';
    return 1u;
}
