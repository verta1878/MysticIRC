#include "spectrum/transport/esp_at.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static uint8_t clock_ready;
static uint8_t clock_hour;
static uint8_t clock_minute;
static uint8_t clock_second;
static uint16_t fat_date;
static uint16_t fat_time;
static const uint8_t *uart_feed;
static uint16_t uart_feed_len;
static uint16_t uart_feed_pos;
static uint8_t uart_string_ok = 1u;
static uint8_t uart_crlf_ok = 1u;
#ifdef NETCHESSZX_NEXT
static uint8_t hard_reset_count;
static uint8_t hard_reset_replies;
static void feed_uart(const char *text);
#endif

extern char line_buf[];
extern char last_ip[];

void spectrum_net_runtime_wait_frame(void)
{
}

void spectrum_net_runtime_wait_frame_plain(void)
{
}

void spectrum_net_runtime_set_clock(uint8_t hour, uint8_t minute, uint8_t second)
{
    clock_ready = 1u;
    clock_hour = hour;
    clock_minute = minute;
    clock_second = second;
}

uint8_t spectrum_net_runtime_clock_ready(void)
{
    return clock_ready;
}

void spectrum_net_runtime_set_fat_stamp(uint16_t date, uint16_t time)
{
    fat_date = date;
    fat_time = time;
}

uint16_t spectrum_net_runtime_fat_date(void)
{
    return fat_date;
}

uint16_t spectrum_net_runtime_fat_time(void)
{
    return fat_time;
}

void spectrum_net_runtime_publish_ip_status(const char *ip)
{
    (void)ip;
}

void spectrum_uart_init(void)
{
}

#ifdef NETCHESSZX_NEXT
void spectrum_uart_hard_reset(void)
{
    ++hard_reset_count;
}
#endif

void spectrum_uart_flush(uint16_t frames)
{
    (void)frames;
}

uint8_t spectrum_uart_send_string(const char *s)
{
    (void)s;
    return uart_string_ok;
}

uint8_t spectrum_uart_send_bytes(const uint8_t *data, uint8_t len)
{
    (void)data;
    (void)len;
    return 1u;
}

uint8_t spectrum_uart_send_crlf(void)
{
#ifdef NETCHESSZX_NEXT
    if (hard_reset_count && hard_reset_replies) {
        hard_reset_replies = 0u;
        feed_uart("OK\n");
    }
#endif
    return uart_crlf_ok;
}

uint8_t spectrum_uart_ready(void)
{
    return (uint8_t)(uart_feed_pos < uart_feed_len);
}

uint8_t spectrum_uart_read(void)
{
    if (uart_feed_pos >= uart_feed_len) {
        return 0u;
    }
    return uart_feed[uart_feed_pos++];
}

static void check(int condition, const char *message)
{
    if (!condition) {
        fprintf(stderr, "FAIL: %s\n", message);
        exit(1);
    }
}

static void reset_clock(void)
{
    clock_ready = 0u;
    clock_hour = 0u;
    clock_minute = 0u;
    clock_second = 0u;
    fat_date = 0u;
    fat_time = 0u;
}

static void feed_uart(const char *text)
{
    uart_feed = (const uint8_t *)text;
    uart_feed_len = (uint16_t)strlen(text);
    uart_feed_pos = 0u;
    reset_line_buf();
}

static void test_read_line(void)
{
    feed_uart("\r\nOK\r\n");
    check(read_line(1u), "reads CRLF line");
    check(strcmp(line_buf, "OK") == 0, "CR stripped and empty line ignored");

    feed_uart("12345678901234567890123456789012345678901234567\n");
    check(read_line(1u), "reads max line");
    check(strlen(line_buf) == 47u, "max line length");

    feed_uart("123456789012345678901234567890123456789012345678\nOK\n");
    check(read_line(1u), "overflow resets and skips overflowing line");
    check(strcmp(line_buf, "OK") == 0, "next line after overflow");

    feed_uart("\n\nA\n");
    check(read_line(1u), "empty lines skipped before payload");
    check(strcmp(line_buf, "A") == 0, "payload after empty lines");
}

static void test_capture_ip(void)
{
    last_ip[0] = '\0';
    netchesszx_esp_at_test_capture_ip("+CIFSR:STAIP,\"192.168.1.44\"");
    check(strcmp(spectrum_net_last_ip(), "192.168.1.44") == 0,
          "captures STAIP");

    netchesszx_esp_at_test_capture_ip("+CIFSR:APIP,\"10.0.0.1\"");
    check(strcmp(spectrum_net_last_ip(), "192.168.1.44") == 0,
          "ignores non-STAIP lines");

    netchesszx_esp_at_test_capture_ip("+CIFSR:STAIP,\"0.0.0.0\"");
    check(spectrum_net_last_ip()[0] == '\0', "zero IP clears last_ip");
}

static void test_capture_time(void)
{
    uint16_t date;
    uint16_t time;

    reset_clock();
    netchesszx_esp_at_test_capture_time(
        "+CIPSNTPTIME:Fri Jun  5 12:34:56 2026");
    check(clock_ready, "captures SNTP time");
    check(clock_hour == 12u && clock_minute == 34u && clock_second == 56u,
          "SNTP time fields");
    check(fat_date == (uint16_t)(((uint16_t)46u << 9) | ((uint16_t)6u << 5) | 5u),
          "SNTP FAT date");
    check(fat_time == (uint16_t)(((uint16_t)12u << 11) | ((uint16_t)34u << 5)),
          "SNTP FAT time");

    reset_clock();
    netchesszx_esp_at_test_capture_time(
        "+CIPSNTPTIME:Thu Jan  1 00:00:01 1970");
    check(!clock_ready, "ignores 1970 default time");

    reset_clock();
    netchesszx_esp_at_test_capture_time(
        "+CIPSNTPTIME:Fri Jun  5 29:01:02 2026");
    check(!clock_ready, "rejects invalid hour");

    reset_clock();
    netchesszx_esp_at_test_capture_time(
        "+CIPSNTPTIME:Fri Jun  5 12:34:56 20K9");
    check(clock_ready && fat_date == 0u && fat_time == 0u,
          "rejects non-digit first year suffix");

    reset_clock();
    netchesszx_esp_at_test_capture_time(
        "+CIPSNTPTIME:Fri Jun  5 12:34:56 201:");
    check(clock_ready && fat_date == 0u && fat_time == 0u,
          "rejects non-digit second year suffix");

    reset_clock();
    date = (uint16_t)(((uint16_t)46u << 9) | ((uint16_t)7u << 5) | 7u);
    time = (uint16_t)(((uint16_t)14u << 11) | ((uint16_t)5u << 5) | 29u);
    check(netchesszx_esp_at_test_capture_msdos_time(date, time),
          "captures RTC MS-DOS time");
    check(clock_hour == 14u && clock_minute == 5u && clock_second == 58u,
          "RTC MS-DOS time fields");
    check(fat_date == date && fat_time == time, "RTC FAT stamp");

    reset_clock();
    date = (uint16_t)(((uint16_t)43u << 9) | ((uint16_t)7u << 5) | 7u);
    check(!netchesszx_esp_at_test_capture_msdos_time(date, time),
          "rejects old RTC date");
    check(!clock_ready, "old RTC date does not set clock");

    reset_clock();
    date = (uint16_t)(((uint16_t)46u << 9) | ((uint16_t)7u << 5) | 7u);
    time = (uint16_t)(((uint16_t)14u << 11) | ((uint16_t)5u << 5) | 30u);
    check(!netchesszx_esp_at_test_capture_msdos_time(date, time),
          "rejects invalid RTC seconds");
}

static void test_at_tx_failure(void)
{
    feed_uart("OK\n");
    uart_string_ok = 0u;
    check(!spectrum_net_at_cmd("AT", 1u), "AT string TX failure propagates");
    check(uart_feed_pos == 0u, "AT string failure does not wait for response");

    uart_string_ok = 1u;
    uart_crlf_ok = 0u;
    check(!spectrum_net_at_cmd("AT", 1u), "AT CRLF TX failure propagates");
    check(uart_feed_pos == 0u, "AT CRLF failure does not wait for response");

    uart_crlf_ok = 1u;
    check(spectrum_net_at_cmd("AT", 1u), "AT succeeds after complete TX");
}

#ifdef NETCHESSZX_NEXT
static void test_next_hard_reset_fallback(void)
{
    feed_uart("");
    hard_reset_count = 0u;
    hard_reset_replies = 1u;
    check(spectrum_net_ensure_command_mode(),
          "Next hard reset retries command mode once");
    check(hard_reset_count == 1u, "Next recovery performs one hard reset");

    feed_uart("");
    hard_reset_count = 0u;
    hard_reset_replies = 0u;
    check(!spectrum_net_ensure_command_mode(),
          "Next recovery propagates failure after hard reset");
    check(hard_reset_count == 1u, "Next recovery never loops hard resets");
}
#endif

int main(void)
{
    test_read_line();
    test_capture_ip();
#ifndef NETCHESSZX_NEXT
    test_capture_time();
#endif
    test_at_tx_failure();
#ifdef NETCHESSZX_NEXT
    test_next_hard_reset_fallback();
#endif
    puts("esp_at tests ok");
    return 0;
}
