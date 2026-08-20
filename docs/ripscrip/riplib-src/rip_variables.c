/*
 * rip_variables.c — RIPlib variable-expansion engine + user-var storage.
 *
 * Implements the API declared in rip_variables.h.  See that header for
 * the rationale of the extraction and what is in scope for this module.
 *
 * Copyright (c) 2026 SimVU (Brad Hawthorne)
 * Licensed under the MIT License.  See LICENSE.
 */

#include "rip_variables.h"
#include "rip_internal.h"
#include "drawing.h"

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

/* Provided by the host platform (declared in riplib_platform.h). */
extern void riplib_host_tx(const char *buf, int len);

/* ── private helpers — moved from ripscrip.c with no behavioural change ── */

bool rip_var_name_copy(const char *name, int len,
                       char *out, int out_cap) {
    int start = 0;
    int end = len;
    int n;

    if (!name || !out || out_cap <= 0 || len <= 0)
        return false;
    while (start < end && (name[start] == ' ' || name[start] == '\t'))
        start++;
    while (end > start && (name[end - 1] == ' ' || name[end - 1] == '\t'))
        end--;
    if (end - start >= 2 && name[start] == '$' && name[end - 1] == '$') {
        start++;
        end--;
    }
    n = end - start;
    if (n <= 0 || n >= out_cap)
        return false;
    for (int i = 0; i < n; i++) {
        unsigned char c = (unsigned char)name[start + i];
        if (!((c >= 'A' && c <= 'Z') ||
              (c >= 'a' && c <= 'z') ||
              (c >= '0' && c <= '9') ||
              c == '_'))
            return false;
        out[i] = (char)c;
    }
    out[n] = '\0';
    return true;
}

static bool rip_var_name_eq(const char *stored, const char *name, int len) {
    int slen;

    if (!stored || !name || len <= 0)
        return false;
    slen = (int)strlen(stored);
    if (slen != len)
        return false;
    return memcmp(stored, name, (size_t)len) == 0;
}

int rip_user_var_find(const rip_state_t *s, const char *name, int len) {
    if (!s || !name || len <= 0)
        return -1;
    for (int i = 0; i < s->user_var_count && i < RIP_USER_VAR_MAX; i++) {
        if (rip_var_name_eq(s->user_var_names[i], name, len))
            return i;
    }
    return -1;
}

bool rip_user_var_set(rip_state_t *s,
                      const char *name, int name_len,
                      const char *value, int value_len) {
    char key[RIP_USER_VAR_NAME_MAX + 1];
    int idx;
    int copy;

    if (!s || !value || value_len < 0)
        return false;
    if (!rip_var_name_copy(name, name_len, key, sizeof(key)))
        return false;
    if (rip_var_name_eq(key, "APP0", 4) ||
        rip_var_name_eq(key, "APP1", 4) ||
        rip_var_name_eq(key, "APP2", 4) ||
        rip_var_name_eq(key, "APP3", 4) ||
        rip_var_name_eq(key, "APP4", 4) ||
        rip_var_name_eq(key, "APP5", 4) ||
        rip_var_name_eq(key, "APP6", 4) ||
        rip_var_name_eq(key, "APP7", 4) ||
        rip_var_name_eq(key, "APP8", 4) ||
        rip_var_name_eq(key, "APP9", 4)) {
        int app = key[3] - '0';
        copy = value_len < (int)sizeof(s->app_vars[0]) - 1
             ? value_len
             : (int)sizeof(s->app_vars[0]) - 1;
        memcpy(s->app_vars[app], value, (size_t)copy);
        s->app_vars[app][copy] = '\0';
        return true;
    }

    idx = rip_user_var_find(s, key, (int)strlen(key));
    if (idx < 0) {
        if (s->user_var_count >= RIP_USER_VAR_MAX)
            return false;
        idx = s->user_var_count++;
        strcpy(s->user_var_names[idx], key);
    }
    copy = value_len < RIP_USER_VAR_VALUE_MAX ? value_len : RIP_USER_VAR_VALUE_MAX;
    memcpy(s->user_var_values[idx], value, (size_t)copy);
    s->user_var_values[idx][copy] = '\0';
    return true;
}

bool rip_query_prompt_begin(rip_state_t *s,
                            const char *vname, int vlen) {
    char prompt_buf[40];
    int plen = 0;
    int copy;

    if (!s || !vname || vlen <= 0 || s->query_pending)
        return false;

    prompt_buf[plen++] = (char)0x3E;  /* CMD_QUERY_PROMPT marker */
    copy = vlen < (int)sizeof(prompt_buf) - 2
         ? vlen
         : (int)sizeof(prompt_buf) - 2;
    for (int k = 0; k < copy; k++)
        prompt_buf[plen++] = vname[k];
    prompt_buf[plen++] = '\0';
    riplib_host_tx(prompt_buf, plen);

    copy = vlen < (int)sizeof(s->query_var_name) - 1
         ? vlen
         : (int)sizeof(s->query_var_name) - 1;
    memcpy(s->query_var_name, vname, (size_t)copy);
    s->query_var_name[copy] = '\0';
    memset(s->query_response, 0, sizeof(s->query_response));
    s->query_response_len = 0;
    s->query_pending = true;
    return true;
}

static bool rip_parse_host_date(const char *date, int *year, int *month, int *day) {
    int mm;
    int dd;
    int yy;

    if (!date || !year || !month || !day)
        return false;
    if (!(date[0] >= '0' && date[0] <= '9' &&
          date[1] >= '0' && date[1] <= '9' &&
          date[2] == '/' &&
          date[3] >= '0' && date[3] <= '9' &&
          date[4] >= '0' && date[4] <= '9' &&
          date[5] == '/' &&
          date[6] >= '0' && date[6] <= '9' &&
          date[7] >= '0' && date[7] <= '9'))
        return false;
    mm = (date[0] - '0') * 10 + (date[1] - '0');
    dd = (date[3] - '0') * 10 + (date[4] - '0');
    yy = (date[6] - '0') * 10 + (date[7] - '0');
    if (mm < 1 || mm > 12 || dd < 1 || dd > 31)
        return false;
    *year = 2000 + yy;
    *month = mm;
    *day = dd;
    return true;
}

static bool rip_is_leap_year(int year) {
    return ((year % 4) == 0 && (year % 100) != 0) || (year % 400) == 0;
}

static int rip_day_of_year(int year, int month, int day) {
    static const int month_offsets[12] =
        { 0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334 };
    int yday = month_offsets[month - 1] + day;
    if (month > 2 && rip_is_leap_year(year))
        yday++;
    return yday;
}

static int rip_days_from_civil(int year, int month, int day) {
    int y = year;
    unsigned m = (unsigned)month;
    unsigned d = (unsigned)day;
    unsigned mp;
    int era;
    unsigned yoe;
    unsigned doy;
    unsigned doe;

    y -= (m <= 2u);
    era = (y >= 0 ? y : y - 399) / 400;
    yoe = (unsigned)(y - era * 400);
    mp = (m > 2u) ? (m - 3u) : (m + 9u);
    doy = (153u * mp + 2u) / 5u + d - 1u;
    doe = yoe * 365u + yoe / 4u - yoe / 100u + doy;
    return era * 146097 + (int)doe - 719468;
}

static int rip_weekday_monday0(int year, int month, int day) {
    int days = rip_days_from_civil(year, month, day);
    int dow = (days + 3) % 7; /* 1970-01-01 was Thursday. */
    if (dow < 0)
        dow += 7;
    return dow;
}

static int rip_iso_weeks_in_year(int year) {
    int jan1 = rip_weekday_monday0(year, 1, 1);
    return (jan1 == 3 || (jan1 == 2 && rip_is_leap_year(year))) ? 53 : 52;
}

static int rip_iso_week(int year, int month, int day) {
    int doy = rip_day_of_year(year, month, day);
    int dow = rip_weekday_monday0(year, month, day) + 1; /* Monday=1 */
    int week = (doy - dow + 10) / 7;

    if (week < 1)
        return rip_iso_weeks_in_year(year - 1);
    if (week > rip_iso_weeks_in_year(year))
        return 1;
    return week;
}

int rip_expand_variables(rip_state_t *s,
                         const char *in, int in_len,
                         char *out, int max_out) {
    int o = 0;
    int i = 0;

    while (i < in_len && o < max_out - 1) {
        if (in[i] != '$') {
            out[o++] = in[i++];
            continue;
        }

        /* Scan forward for matching closing '$' */
        int j = i + 1;
        while (j < in_len && in[j] != '$') j++;

        if (j >= in_len) {
            /* No closing '$' found — treat as literal and move on */
            out[o++] = in[i++];
            continue;
        }

        /* Variable name occupies in[i+1 .. j-1] */
        const char *vname = in + i + 1;
        int vlen = j - i - 1;
        char val[64];
        int vval_len = -1; /* -1 = unrecognized, emit literal */

        if (vlen == 4 && memcmp(vname, "DATE", 4) == 0) {
            /* $DATE$ — use host-supplied date (CB_GET_TIME equivalent).
             * The host reads its wall-clock source and ships it via the
             * rip_sync_date_byte() accumulator at connect time.  Fall
             * back to the local RTC (time()/localtime()) only when the
             * host has not synced yet.  Calling time() unconditionally
             * here would use the local RTC, which may drift from the
             * BBS host clock — the callback model lets the host be the
             * sole clock authority when it has one. */
            if (s->host_date[0] != '\0') {
                vval_len = (int)rip_strnlen(s->host_date, sizeof(s->host_date) - 1);
                if (vval_len > (int)sizeof(val) - 1) vval_len = (int)sizeof(val) - 1;
                memcpy(val, s->host_date, (size_t)vval_len);
            } else {
                /* Host not yet synced — fall back to local RTC */
                time_t now = time(NULL);
                struct tm *tm = localtime(&now);
                vval_len = snprintf(val, sizeof(val), "%02d/%02d/%02d",
                                    tm->tm_mon + 1, tm->tm_mday, tm->tm_year % 100);
                if (vval_len < 0) vval_len = 0;
            }
        } else if (vlen == 4 && memcmp(vname, "TIME", 4) == 0) {
            /* $TIME$ — use host-supplied time (CB_GET_TIME equivalent).
             * Falls back to local RTC when host has not synced yet. */
            if (s->host_time[0] != '\0') {
                vval_len = (int)rip_strnlen(s->host_time, sizeof(s->host_time) - 1);
                if (vval_len > (int)sizeof(val) - 1) vval_len = (int)sizeof(val) - 1;
                memcpy(val, s->host_time, (size_t)vval_len);
            } else {
                /* Host not yet synced — fall back to local RTC */
                time_t now = time(NULL);
                struct tm *tm = localtime(&now);
                vval_len = snprintf(val, sizeof(val), "%02d:%02d",
                                    tm->tm_hour, tm->tm_min);
                if (vval_len < 0) vval_len = 0;
            }
        } else if (vlen == 4 && memcmp(vname, "USER", 4) == 0) {
            /* $USER$ — no login name on embedded card; substitute empty string */
            val[0] = '\0';
            vval_len = 0;
        /* $RLPROT$ — negotiated resolution mode.
          * RENAMED from $PROT$ 2026-08-12 (X1).  The driver uses $PROT(...)$
          * as a PARAMETERIZED ACTION that protects table entries and save
          * slots; RIPlib was squatting on the bare name with an unrelated
          * value, so a host's $PROT(...)$ fell through as literal text while
          * $PROT$ returned something the record never defined.  The RL prefix
          * cannot collide with a driver name.
          * 0=EGA(640x350), 1=VGA(640x480), 2=SVGA, 3=XGA, 4=HIGH. */
        } else if (vlen == 6 && memcmp(vname, "RLPROT", 6) == 0) {
            vval_len = snprintf(val, sizeof(val), "%u", s->resolution_mode);
            if (vval_len < 0) vval_len = 0;
        } else if (vlen == 9 && memcmp(vname, "COLORMODE", 9) == 0) {
            /* $COLORMODE$ returns 0 in palette-mapping mode, or the RGB
             * bits/component value (1..8) in direct RGB mode. */
            unsigned mode = (s->color_mode == 0) ? 0u : (unsigned)s->color_bits;
            vval_len = snprintf(val, sizeof(val), "%u", mode);
            if (vval_len < 0) vval_len = 0;
        } else if (vlen == 9 && memcmp(vname, "COORDSIZE", 9) == 0) {
            vval_len = snprintf(val, sizeof(val), "%u", s->coordinate_size);
            if (vval_len < 0) vval_len = 0;
        } else if (vlen == 9 && memcmp(vname, "ISPALETTE", 9) == 0) {
            val[0] = '1';
            vval_len = 1;
        } else if (vlen == 4 && vname[0] == 'A' && vname[1] == 'P' &&
                   vname[2] == 'P' && vname[3] >= '0' && vname[3] <= '9') {
            /* $APP0$-$APP9$ — application-defined variables */
            int idx = vname[3] - '0';
            vval_len = (int)rip_strnlen(s->app_vars[idx], sizeof(s->app_vars[0]));
            if (vval_len > (int)sizeof(val) - 1) vval_len = (int)sizeof(val) - 1;
            memcpy(val, s->app_vars[idx], (size_t)vval_len);

        /* Sound text variables (CB_PLAY_SOUND callback equivalent).
         * In RIPSCRIP.DLL the host filled the sound callback slot and the DLL
         * called it when these variables were expanded.  RIPlib doesn't
         * own an audio path; instead we push markers through the TX FIFO
         * and let the host emit the actual sound:
         *   $BEEP$  — push BEL (0x07) through TX FIFO; the host is
         *             expected to ring an audible bell on receipt.
         *   Others  — push CMD_PLAY_SOUND marker (0x3D) + sound-token string
         *             + NUL so the host can dispatch to its sound subsystem.
         * All sound variables expand to the empty string in the text stream. */
        } else if (vlen == 4 && memcmp(vname, "BEEP", 4) == 0) {
            /* $BEEP$ — BEL character; host bridge handles audible beep */
            riplib_host_tx("\x07", 1);
            val[0] = '\0';
            vval_len = 0;
        } else if (vlen == 4 && memcmp(vname, "BLIP", 4) == 0) {
            /* $BLIP$ — short click tone; send CMD_PLAY_SOUND token to host */
            riplib_host_tx("\x3D" "BLIP\0", 6);  /* marker + "BLIP" + NUL */
            val[0] = '\0';
            vval_len = 0;
        } else if (vlen == 5 && memcmp(vname, "ALARM", 5) == 0) {
            /* $ALARM$ — alarm tone sequence */
            riplib_host_tx("\x3D" "ALARM\0", 7);
            val[0] = '\0';
            vval_len = 0;
        } else if (vlen == 6 && memcmp(vname, "PHASER", 6) == 0) {
            /* $PHASER$ — phaser sweep tone */
            riplib_host_tx("\x3D" "PHASER\0", 8);
            val[0] = '\0';
            vval_len = 0;
        } else if (vlen == 5 && memcmp(vname, "MUSIC", 5) == 0) {
            /* $MUSIC$ — background music cue */
            riplib_host_tx("\x3D" "MUSIC\0", 7);
            val[0] = '\0';
            vval_len = 0;

        /* $RAND$ — pseudo-random number.
         * 32-bit LCG with the standard Knuth/POSIX constants (multiplier
         * 1103515245, addend 12345).  The sequence is deterministic and
         * reproducible from a fixed seed, which is the property RIPscrip
         * streams rely on.  (Bit-for-bit equivalence with the original
         * RIPSCRIP.DLL rand() is unverified — see open question U-005.) */
        } else if (vlen == 4 && memcmp(vname, "RAND", 4) == 0) {
            s->rand_state = s->rand_state * 1103515245u + 12345u;
            vval_len = snprintf(val, sizeof(val), "%u",
                                (unsigned)((s->rand_state >> 16) & 0x7FFFu));
            if (vval_len < 0) vval_len = 0;

        /* $RIPVER$ — protocol version string.
         * DLL ripTextVarEngine returns "RIPSCRIP030001" for v3.0.
         * RIPlib reports "RIPSCRIP032001" — v3.2 with the §A2G.8-13
         * QoL extensions on top of the §A2G.1-7 v3.1 baseline. */
        } else if (vlen == 6 && memcmp(vname, "RIPVER", 6) == 0) {
            vval_len = snprintf(val, sizeof(val), "RIPSCRIP032001");
            if (vval_len < 0) vval_len = 0;

        /* $REFRESH$ — re-enable and trigger a full screen refresh.
         * DLL: clears the no-refresh flag and calls ripInvalidateAll().
         * RIPlib:clear refresh_suppress and mark full framebuffer dirty. */
        } else if (vlen == 7 && memcmp(vname, "REFRESH", 7) == 0) {
            s->refresh_suppress = false;
            draw_mark_all_dirty();   /* equivalent to ripInvalidateAll() */
            val[0] = '\0';
            vval_len = 0;

        /* $NOREFRESH$ — suppress automatic screen refresh.
         * DLL: sets the no-refresh flag so that intermediate drawing steps
         * don't cause visible flicker during multi-command scene build. */
        } else if (vlen == 9 && memcmp(vname, "NOREFRESH", 9) == 0) {
            s->refresh_suppress = true;
            val[0] = '\0';
            vval_len = 0;

        /* $TEXTDATA$ — contents of the active bounded text buffer.
         * DLL: returns the accumulated text from the '"' (ICON_QUERY) bounded
         * text parameter.  RIPlib:return empty string (no bounded text buffer
         * maintained inside RIPlib; text is rendered immediately on receipt). */
        } else if (vlen == 8 && memcmp(vname, "TEXTDATA", 8) == 0) {
            val[0] = '\0';
            vval_len = 0;

        /* $YEAR$ — 4-digit current year.
         * DLL ripTextVarEngine @ 0x026218, handler @ 0x0390CA.
         * Use host_date if synced (via rip_sync_date_byte); fall back to local RTC. */
        /* $YEAR$ is the TWO-digit year; $FYEAR$ is the four-digit one.
         * Both names are present as distinct strings in RIPSCRIP.DLL 3.0.7.
         * RIPlib returned four digits from $YEAR$ until 2026-08-12, which is
         * a silent mismatch: a host comparing <<IF $YEAR$=26>> saw "2026".
         * Corrected as part of X1 (see design/bbs-land-alignment.md). */
        } else if ((vlen == 4 && memcmp(vname, "YEAR", 4) == 0) ||
                   (vlen == 5 && memcmp(vname, "FYEAR", 5) == 0)) {
            bool full = (vlen == 5);
            int yyyy;
            if (s->host_date[0] != '\0') {
                /* host_date is "MM/DD/YY" — year is the last two digits.
                 * Expand to 4-digit year by assuming 2000+ (BBS era is over). */
                int yy = 0;
                const char *p_slash2 = s->host_date + 6;  /* points past "MM/DD/" */
                if (p_slash2[0] >= '0' && p_slash2[0] <= '9' &&
                    p_slash2[1] >= '0' && p_slash2[1] <= '9') {
                    yy = (p_slash2[0] - '0') * 10 + (p_slash2[1] - '0');
                }
                yyyy = 2000 + yy;
            } else {
                time_t now = time(NULL);
                struct tm *tm = localtime(&now);
                yyyy = 1900 + tm->tm_year;
            }
            vval_len = full
                ? snprintf(val, sizeof(val), "%04d", yyyy)
                : snprintf(val, sizeof(val), "%02d", yyyy % 100);
            if (vval_len < 0) vval_len = 0;

        /* $WOYM$ — ISO week-of-year (Monday start), 2-digit string.
         * DLL ripTextVarEngine @ 0x026218, handler @ 0x0390B0 ("WOYM"). */
        } else if (vlen == 4 && memcmp(vname, "WOYM", 4) == 0) {
            int week = 0;
            if (s->host_date[0] != '\0') {
                int year;
                int month;
                int day;
                if (rip_parse_host_date(s->host_date, &year, &month, &day))
                    week = rip_iso_week(year, month, day);
            } else {
                time_t now = time(NULL);
                struct tm *tm = localtime(&now);
                week = rip_iso_week(1900 + tm->tm_year,
                                    tm->tm_mon + 1,
                                    tm->tm_mday);
            }
            if (week < 1) week = 1;
            if (week > 53) week = 53;
            vval_len = snprintf(val, sizeof(val), "%02d", week);
            if (vval_len < 0) vval_len = 0;

        /* $COMPAT$ — compatibility level string.
         * DLL: reports a numeric mode flag used by host to detect capability.
         * RIPlib:return "1" (basic compatibility, level 1 extensions present). */
        /* $RLCOMPAT$ — RIPlib compatibility level.
          * RENAMED from $COMPAT$ 2026-08-12 (X1).  In the record
          * $COMPAT(env)$ drops an environment to 1.54 settings — the standard
          * legacy-mode call, with 21 uses in the shipped corpus.  Occupying
          * the bare name meant a host could not tell a compliant terminal
          * from RIPlib. */
        } else if (vlen == 8 && memcmp(vname, "RLCOMPAT", 8) == 0) {
            vval_len = snprintf(val, sizeof(val), "1");
            if (vval_len < 0) vval_len = 0;

        /* $MKILL$ — kill/clear all mouse fields via text variable.
         * DLL ripTextVarEngine: calling $MKILL$ is equivalent to !|1K|.
         * RIPlib:zero the mouse region table immediately. */
        } else if (vlen == 5 && memcmp(vname, "MKILL", 5) == 0) {
            s->num_mouse_regions = 0;
            val[0] = '\0';
            vval_len = 0;

        /* $RLCOPY$ — set write mode to COPY(0) via text variable.
         * RENAMED from $COPY$ 2026-08-12 (X1).  The record uses
         * $COPY(type,source,dest,...)$ to copy data tables, entries and save
         * slots; the bare name was RIPlib's own shorthand for "write mode
         * COPY" and had to move off it. */
        } else if (vlen == 6 && memcmp(vname, "RLCOPY", 6) == 0) {
            s->write_mode = 0;
            draw_set_write_mode(0);
            val[0] = '\0';
            vval_len = 0;

        /* $COFF$ — cursor off (hide hardware cursor).
         * DLL: calls cursor hide callback.  RIPlib:no hardware cursor;
         * no-op but recognised so the variable doesn't pass through as literal. */
        } else if (vlen == 4 && memcmp(vname, "COFF", 4) == 0) {
            val[0] = '\0';
            vval_len = 0;

        } else if (vlen == 5 && memcmp(vname, "RESET", 5) == 0) {
            rip_reset_windows_state(s, NULL);
            val[0] = '\0';
            vval_len = 0;

        /* $ABORT$ — abort the current RIPscrip scene (reset state).
         * DLL: sets abort flag; parser discards remaining stream bytes.
         * RIPlib:reset the FSM to IDLE so the next !| starts fresh. */
        } else if (vlen == 5 && memcmp(vname, "ABORT", 5) == 0) {
            s->state = RIP_ST_IDLE;
            /* Inlined former clear_levels() — kept here so the
             * variable engine has no link-time dependency on a
             * private helper that still lives in ripscrip.c. */
            s->is_level1 = false;
            s->is_level2 = false;
            s->is_level3 = false;
            s->cmd_len = 0;
            val[0] = '\0';
            vval_len = 0;

        /* §A2G (v3.2): Layout / introspection variables ----------------- */
        } else if (vlen == 2 && memcmp(vname, "CX", 2) == 0) {
            vval_len = snprintf(val, sizeof(val), "%d", s->draw_x);
            if (vval_len < 0) vval_len = 0;
        } else if (vlen == 2 && memcmp(vname, "CY", 2) == 0) {
            vval_len = snprintf(val, sizeof(val), "%d", s->draw_y);
            if (vval_len < 0) vval_len = 0;
        } else if (vlen == 3 && memcmp(vname, "VPW", 3) == 0) {
            vval_len = snprintf(val, sizeof(val), "%d",
                                (int)(s->vp_x1 - s->vp_x0 + 1));
            if (vval_len < 0) vval_len = 0;
        } else if (vlen == 3 && memcmp(vname, "VPH", 3) == 0) {
            vval_len = snprintf(val, sizeof(val), "%d",
                                (int)(s->vp_y1 - s->vp_y0 + 1));
            if (vval_len < 0) vval_len = 0;
        } else if (vlen == 4 && memcmp(vname, "VPCX", 4) == 0) {
            vval_len = snprintf(val, sizeof(val), "%d",
                                (int)((s->vp_x0 + s->vp_x1) / 2));
            if (vval_len < 0) vval_len = 0;
        } else if (vlen == 4 && memcmp(vname, "VPCY", 4) == 0) {
            vval_len = snprintf(val, sizeof(val), "%d",
                                (int)((s->vp_y0 + s->vp_y1) / 2));
            if (vval_len < 0) vval_len = 0;
        } else if (vlen == 4 && memcmp(vname, "CCOL", 4) == 0) {
            vval_len = snprintf(val, sizeof(val), "%d",
                                (int)(s->draw_color & 0x0F));
            if (vval_len < 0) vval_len = 0;
        } else if (vlen == 5 && memcmp(vname, "CFCOL", 5) == 0) {
            vval_len = snprintf(val, sizeof(val), "%d",
                                (int)(s->fill_color & 0x0F));
            if (vval_len < 0) vval_len = 0;
        } else if (vlen == 5 && memcmp(vname, "CBCOL", 5) == 0) {
            vval_len = snprintf(val, sizeof(val), "%d",
                                (int)(s->back_color & 0x0F));
            if (vval_len < 0) vval_len = 0;

        /* §A2G (v3.2): Time component variables ------------------------- */
        /* $HOUR$ is the 12-hour (non-military) hour; $MHOUR$ is the
         * 24-hour form.  Both names exist as distinct NUL-terminated
         * strings in RIPSCRIP.DLL 3.0.7, so they are separate variables.
         * RIPlib previously returned 00-23 from $HOUR$ -- i.e. $MHOUR$'s
         * value under $HOUR$'s name -- which is silently wrong against any
         * conforming terminal.  Corrected 2026-08-12 (X2). */
        } else if (vlen == 5 && memcmp(vname, "MHOUR", 5) == 0) {
            if (s->host_time[0] >= '0' && s->host_time[0] <= '9' &&
                s->host_time[1] >= '0' && s->host_time[1] <= '9') {
                val[0] = s->host_time[0]; val[1] = s->host_time[1];
                vval_len = 2;
            } else {
                time_t now = time(NULL);
                struct tm *tm = localtime(&now);
                vval_len = snprintf(val, sizeof(val), "%02d", tm->tm_hour);
                if (vval_len < 0) vval_len = 0;
            }
        } else if (vlen == 4 && memcmp(vname, "HOUR", 4) == 0) {
            int h24;
            if (s->host_time[0] >= '0' && s->host_time[0] <= '9' &&
                s->host_time[1] >= '0' && s->host_time[1] <= '9') {
                h24 = (s->host_time[0] - '0') * 10 + (s->host_time[1] - '0');
            } else {
                time_t now = time(NULL);
                struct tm *tm = localtime(&now);
                h24 = tm->tm_hour;
            }
            {   /* 00->12, 13..23 -> 1..11; 01..12 unchanged */
                int h12 = h24 % 12;
                if (h12 == 0) h12 = 12;
                vval_len = snprintf(val, sizeof(val), "%02d", h12);
                if (vval_len < 0) vval_len = 0;
            }
        } else if (vlen == 3 && memcmp(vname, "MIN", 3) == 0) {
            if (s->host_time[3] >= '0' && s->host_time[3] <= '9' &&
                s->host_time[4] >= '0' && s->host_time[4] <= '9') {
                val[0] = s->host_time[3]; val[1] = s->host_time[4];
                vval_len = 2;
            } else {
                time_t now = time(NULL);
                struct tm *tm = localtime(&now);
                vval_len = snprintf(val, sizeof(val), "%02d", tm->tm_min);
                if (vval_len < 0) vval_len = 0;
            }
        } else if (vlen == 3 && memcmp(vname, "SEC", 3) == 0) {
            /* host_time is HH:MM only; SEC always reads from RTC. */
            time_t now = time(NULL);
            struct tm *tm = localtime(&now);
            vval_len = snprintf(val, sizeof(val), "%02d", tm->tm_sec);
            if (vval_len < 0) vval_len = 0;
        /* $WDAY$ is the numeric weekday with 0 = SUNDAY; $DOW$ is the day
         * spelled out.  Both names are present in the driver.  RIPlib
         * previously returned a Monday=0 digit from $DOW$, so the README's
         * own example -- <<IF $DOW$=4>>Happy Friday!<<ENDIF>> -- evaluated
         * false on every conforming terminal.  Corrected 2026-08-12 (X2). */
        } else if (vlen == 4 && memcmp(vname, "WDAY", 4) == 0) {
            int year, month, day, wd;
            if (s->host_date[0] != '\0' &&
                rip_parse_host_date(s->host_date, &year, &month, &day)) {
                wd = (rip_weekday_monday0(year, month, day) + 1) % 7;
            } else {
                time_t now = time(NULL);
                struct tm *tm = localtime(&now);
                wd = tm->tm_wday;           /* already 0 = Sunday */
            }
            vval_len = snprintf(val, sizeof(val), "%d", wd);
            if (vval_len < 0) vval_len = 0;
        } else if (vlen == 3 && memcmp(vname, "DOW", 3) == 0) {
            static const char *const k_days[7] = {
                "Sunday", "Monday", "Tuesday", "Wednesday",
                "Thursday", "Friday", "Saturday"
            };
            int year, month, day, dow;
            if (s->host_date[0] != '\0' &&
                rip_parse_host_date(s->host_date, &year, &month, &day)) {
                dow = rip_weekday_monday0(year, month, day);
            } else {
                time_t now = time(NULL);
                struct tm *tm = localtime(&now);
                /* tm_wday: 0=Sunday..6=Saturday. Convert to Monday=0. */
                dow = (tm->tm_wday + 6) % 7;
            }
            {   /* dow is Monday=0; k_days is indexed Sunday=0 */
                int idx = (dow + 1) % 7;
                vval_len = snprintf(val, sizeof(val), "%s", k_days[idx]);
                if (vval_len < 0) vval_len = 0;
            }
        /* The driver has no "DOM" string at all; the day-of-month variable
         * is $DAY$.  Renamed 2026-08-12 (X2). */
        } else if (vlen == 3 && memcmp(vname, "DAY", 3) == 0) {
            int year, month, day;
            if (s->host_date[0] != '\0' &&
                rip_parse_host_date(s->host_date, &year, &month, &day)) {
                vval_len = snprintf(val, sizeof(val), "%02d", day);
            } else {
                time_t now = time(NULL);
                struct tm *tm = localtime(&now);
                vval_len = snprintf(val, sizeof(val), "%02d", tm->tm_mday);
            }
            if (vval_len < 0) vval_len = 0;
        /* $MONTHNUM$ is the numeric month; $MONTH$ is the month spelled
         * out.  Both names are present in the driver.  Corrected
         * 2026-08-12 (X2). */
        } else if (vlen == 8 && memcmp(vname, "MONTHNUM", 8) == 0) {
            int year, month, day;
            if (s->host_date[0] != '\0' &&
                rip_parse_host_date(s->host_date, &year, &month, &day)) {
                vval_len = snprintf(val, sizeof(val), "%02d", month);
            } else {
                time_t now = time(NULL);
                struct tm *tm = localtime(&now);
                vval_len = snprintf(val, sizeof(val), "%02d", tm->tm_mon + 1);
            }
            if (vval_len < 0) vval_len = 0;
        } else if (vlen == 5 && memcmp(vname, "MONTH", 5) == 0) {
            static const char *const k_months[12] = {
                "January", "February", "March", "April", "May", "June",
                "July", "August", "September", "October", "November", "December"
            };
            int year, month, day, m;
            if (s->host_date[0] != '\0' &&
                rip_parse_host_date(s->host_date, &year, &month, &day)) {
                m = month;
            } else {
                time_t now = time(NULL);
                struct tm *tm = localtime(&now);
                m = tm->tm_mon + 1;
            }
            if (m < 1 || m > 12) m = 1;
            vval_len = snprintf(val, sizeof(val), "%s", k_months[m - 1]);
            if (vval_len < 0) vval_len = 0;

        /* §A2G (v3.2): EGA color-name aliases — expand to 2-digit MegaNum
         * suitable as a |c, |S, |k, |a argument.  Each name maps to
         * its EGA palette index (0-15).  Names are 16 chars max. */
        } else if (vlen >= 3 && vlen <= 13) {
            static const struct { const char *name; uint8_t len; uint8_t idx; }
                color_names[] = {
                    { "BLACK",        5, 0x0 },
                    { "BLUE",         4, 0x1 },
                    { "GREEN",        5, 0x2 },
                    { "CYAN",         4, 0x3 },
                    { "RED",          3, 0x4 },
                    { "MAGENTA",      7, 0x5 },
                    { "BROWN",        5, 0x6 },
                    { "LIGHTGRAY",    9, 0x7 },
                    { "DARKGRAY",     8, 0x8 },
                    { "LIGHTBLUE",    9, 0x9 },
                    { "LIGHTGREEN",  10, 0xA },
                    { "LIGHTCYAN",    9, 0xB },
                    { "LIGHTRED",     8, 0xC },
                    { "LIGHTMAGENTA",12, 0xD },
                    { "YELLOW",       6, 0xE },
                    { "WHITE",        5, 0xF },
                };
            bool matched = false;
            for (size_t ci = 0; ci < sizeof(color_names)/sizeof(color_names[0]); ci++) {
                if (color_names[ci].len == (uint8_t)vlen &&
                    memcmp(vname, color_names[ci].name, (size_t)vlen) == 0) {
                    /* MegaNum encoding: index 0-15 → "00".."0F" */
                    val[0] = '0';
                    val[1] = (color_names[ci].idx < 10)
                             ? (char)('0' + color_names[ci].idx)
                             : (char)('A' + color_names[ci].idx - 10);
                    vval_len = 2;
                    matched = true;
                    break;
                }
            }
            if (!matched) {
                /* Not a color name — fall through to user-var lookup */
                int uidx = rip_user_var_find(s, vname, vlen);
                if (uidx >= 0) {
                    vval_len = (int)rip_strnlen(s->user_var_values[uidx],
                                                sizeof(s->user_var_values[uidx]));
                    if (vval_len > (int)sizeof(val) - 1)
                        vval_len = (int)sizeof(val) - 1;
                    memcpy(val, s->user_var_values[uidx], (size_t)vval_len);
                }
            }

        } else {
            int uidx = rip_user_var_find(s, vname, vlen);
            if (uidx >= 0) {
                vval_len = (int)rip_strnlen(s->user_var_values[uidx],
                                            sizeof(s->user_var_values[uidx]));
                if (vval_len > (int)sizeof(val) - 1)
                    vval_len = (int)sizeof(val) - 1;
                memcpy(val, s->user_var_values[uidx], (size_t)vval_len);
            }
        }

        if (vval_len >= 0) {
            /* Recognized variable — substitute its value */
            int copy = vval_len;
            if (o + copy > max_out - 1) copy = max_out - 1 - o;
            memcpy(out + o, val, (size_t)copy);
            o += copy;
            i = j + 1; /* advance past closing '$' */
        } else {
            /* Unrecognized — emit literal '$' and retry from i+1 */
            out[o++] = in[i++];
        }
    }

    out[o] = '\0';
    return o;
}

/* Evaluate a <<IF expr>> expression after variable expansion.  The
 * expression is expanded once into a local buffer, then parsed for
 * the canonical operators in precedence-friendly order (2-char ops
 * first so "5>=5" is parsed as ">=", not "= then >").  Falsy values
 * are empty string and literal "0"; everything else is truthy. */
bool rip_eval_if_expr(rip_state_t *s, const char *expr) {
    char expanded[128];
    rip_expand_variables(s, expr, (int)strlen(expr), expanded, sizeof(expanded));

    /* Check 2-char operators (!=, >=, <=) before 1-char (=, >, <) so
     * that "5>=5" is parsed as ">=" rather than splitting on '='. */
    char *op = strstr(expanded, "!=");
    if (op) {
        *op = '\0';
        return strcmp(expanded, op + 2) != 0;  /* string inequality */
    }
    op = strstr(expanded, ">=");
    if (op) {
        *op = '\0';
        return atoi(expanded) >= atoi(op + 2);
    }
    op = strstr(expanded, "<=");
    if (op) {
        *op = '\0';
        return atoi(expanded) <= atoi(op + 2);
    }
    op = strchr(expanded, '=');
    if (op) {
        *op = '\0';
        return strcmp(expanded, op + 1) == 0;  /* string equality */
    }
    op = strchr(expanded, '>');
    if (op) {
        *op = '\0';
        return atoi(expanded) > atoi(op + 1);
    }
    op = strchr(expanded, '<');
    if (op) {
        *op = '\0';
        return atoi(expanded) < atoi(op + 1);
    }

    /* Boolean: non-empty and not literal "0" */
    return expanded[0] != '\0' && !(expanded[0] == '0' && expanded[1] == '\0');
}
