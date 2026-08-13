#include "spectrum/platform/net_runtime.h"

#include "spectrum/platform/platform.h"
#include "spectrum/transport/link.h"
#include "spectrum/ui/gui.h"

static uint8_t runtime_clock_ready;
static uint16_t runtime_fat_date;
static uint16_t runtime_fat_time;

void spectrum_net_runtime_wait_frame(void)
{
    spectrum_frame_wait();
    spectrum_link_background_drain();
    spectrum_gui_tick();
}

void spectrum_net_runtime_wait_frame_plain(void)
{
    spectrum_frame_wait();
    spectrum_gui_tick();
}

void spectrum_net_runtime_set_clock(uint8_t hour, uint8_t minute, uint8_t second)
{
    if (hour >= 24u || minute >= 60u || second >= 60u) {
        return;
    }
    spectrum_gui_set_clock(hour, minute, second);
    runtime_clock_ready = 1u;
}

uint8_t spectrum_net_runtime_clock_ready(void)
{
    return runtime_clock_ready;
}

void spectrum_net_runtime_set_fat_stamp(uint16_t date, uint16_t time)
{
    runtime_fat_date = date;
    runtime_fat_time = time;
}

uint16_t spectrum_net_runtime_fat_date(void)
{
    return runtime_fat_date;
}

uint16_t spectrum_net_runtime_fat_time(void)
{
    return runtime_fat_time;
}
