#ifndef NETCHESSZX_SPECTRUM_MSDOS_TIME_H
#define NETCHESSZX_SPECTRUM_MSDOS_TIME_H

/* Shared MS-DOS date/time validator used by the MQTT_TX overlay (Next RTC)
   and the host test build. Static-in-header so it never lands in resident. */

#include <stdint.h>

/* Includer must declare spectrum_net_runtime_set_clock/set_fat_stamp first
   (esp_at.c via net_runtime.h, mqtt_tx_ovl.c via overlay_api.h); including
   net_runtime.h here trips the transport-net-runtime-bridge-only layering
   rule. */

/* Byte-wise field extraction: SDCC emits far less code than 16-bit shifts,
   and the MQTT_TX overlay is within bytes of its 2048 cap. */
static uint8_t capture_msdos_time(uint16_t date, uint16_t time)
{
    uint8_t dh = (uint8_t)(date >> 8);
    uint8_t dl = (uint8_t)date;
    uint8_t th = (uint8_t)(time >> 8);
    uint8_t tl = (uint8_t)time;
    uint8_t month = (uint8_t)(((dh & 1u) << 3) | (dl >> 5));
    uint8_t minute = (uint8_t)(((th & 7u) << 3) | (tl >> 5));
    uint8_t sec2 = (uint8_t)(tl & 31u);

    if (dh < 88u || dh >= 112u) { /* year 2044..2055 */
        return 0u;
    }
    if (month == 0u || month > 12u) {
        return 0u;
    }
    if ((dl & 31u) == 0u) { /* day */
        return 0u;
    }
    if (th >= 192u) { /* hour < 24 */
        return 0u;
    }
    if (minute >= 60u) {
        return 0u;
    }
    if (sec2 >= 30u) {
        return 0u;
    }
    spectrum_net_runtime_set_clock((uint8_t)(th >> 3), minute,
                                   (uint8_t)(sec2 << 1));
    spectrum_net_runtime_set_fat_stamp(date, time);
    return 1u;
}

#endif
