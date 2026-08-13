#include <stdio.h>
#include <string.h>

#ifndef __at
#define __at(address)
#endif

#include "spectrum/transport/net.c"

void spectrum_mqtt_broker_keepalive_reset(
    spectrum_mqtt_broker_keepalive_t *keepalive)
{
    (void)keepalive;
}

static int failures;

static void check(int ok, const char *label)
{
    if (!ok) {
        printf("FAIL: %s\n", label);
        ++failures;
    }
}

static void set_stream(const uint8_t *data, uint8_t len)
{
    memcpy(MQTT_STREAM, data, len);
    mqtt_stream_len = len;
}

static void test_garbage_compacts_once_to_packet(void)
{
    static const uint8_t stream[] = { 0x01u, 0xffu, 0x30u, 0x02u, 0u, 1u };

    set_stream(stream, sizeof(stream));
    check(mqtt_take_stream_packet() == 4, "garbage: finds MQTT packet");
    check(mqtt_stream_len == 4u, "garbage: discarded prefix once");
    check(MQTT_STREAM[0] == 0x30u && MQTT_STREAM[3] == 1u,
          "garbage: packet stays intact");
}

static void test_garbage_keeps_fragment_start(void)
{
    static const uint8_t stream[] = { 0x01u, 0xffu, 0xd0u };

    set_stream(stream, sizeof(stream));
    check(mqtt_take_stream_packet() == 0, "fragment: waits for final byte");
    check(mqtt_stream_len == 1u && MQTT_STREAM[0] == 0xd0u,
          "fragment: keeps possible packet start");
    MQTT_STREAM[mqtt_stream_len++] = 0u;
    check(mqtt_take_stream_packet() == 2, "fragment: completes PINGRESP");
}

int main(void)
{
    test_garbage_compacts_once_to_packet();
    test_garbage_keeps_fragment_start();

    if (failures != 0) {
        printf("%d MQTT stream tests failed\n", failures);
        return 1;
    }
    puts("MQTT stream tests passed");
    return 0;
}
