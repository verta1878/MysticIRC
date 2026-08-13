#ifndef NETCHESSZX_SPECTRUM_ESP_AT_H
#define NETCHESSZX_SPECTRUM_ESP_AT_H

#include <stdint.h>

#ifndef NETCHESSZX_FASTCALL
#ifdef NETCHESSZX_SDCC_IY
#define NETCHESSZX_FASTCALL __z88dk_fastcall
#else
#define NETCHESSZX_FASTCALL
#endif
#endif

void net_wait_frame(void);
void reset_line_buf(void);
uint8_t read_line(uint16_t frames) NETCHESSZX_FASTCALL;
uint8_t wait_for_prompt(uint16_t frames) NETCHESSZX_FASTCALL;

const char *spectrum_net_last_ip(void);
uint8_t spectrum_net_at_cmd(const char *cmd, uint16_t frames);
void spectrum_net_guard_wait(uint16_t frames) NETCHESSZX_FASTCALL;
uint8_t spectrum_net_ensure_command_mode(void);
uint8_t spectrum_net_sync_time(void);

#define spectrum_esp_at_last_ip spectrum_net_last_ip
#define spectrum_esp_at_cmd spectrum_net_at_cmd
#define spectrum_esp_at_guard_wait spectrum_net_guard_wait
#define spectrum_esp_at_ensure_command_mode spectrum_net_ensure_command_mode
#define spectrum_esp_at_sync_time spectrum_net_sync_time

#ifdef NETCHESSZX_HOST_TEST
void netchesszx_esp_at_test_capture_ip(const char *line);
void netchesszx_esp_at_test_capture_time(const char *line);
uint8_t netchesszx_esp_at_test_capture_msdos_time(uint16_t date,
                                                  uint16_t time);
#endif

#endif
