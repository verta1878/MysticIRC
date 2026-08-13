#include "spectrum/platform/uart.h"

#include <stdio.h>
#include <stdlib.h>

static uint8_t tx_failures;
static uint8_t tx_always_fail;
static uint8_t tx_calls;

void net_uart_init(void)
{
}

uint8_t net_uart_send(uint8_t c)
{
    (void)c;
    ++tx_calls;
    if (tx_always_fail) {
        return 1u;
    }
    if (tx_failures != 0u) {
        --tx_failures;
        return 1u;
    }
    return 0u;
}

uint8_t net_uart_ready(void)
{
    return 0u;
}

uint8_t net_uart_read(void)
{
    return 0u;
}

static void check(uint8_t condition, const char *message)
{
    if (!condition) {
        fprintf(stderr, "FAIL: %s\n", message);
        exit(1);
    }
}

int main(void)
{
    static const uint8_t data[] = {'A', 'B'};

    check(spectrum_uart_send_string("AB"), "string TX succeeds");
    check(tx_calls == 2u, "string TX byte count");

    tx_calls = 0u;
    tx_failures = 4u;
    check(!spectrum_uart_send_string("A"), "string TX failure propagates");
    check(tx_calls == 4u, "string TX failure retry count");

    tx_calls = 0u;
    tx_failures = 0u;
    check(spectrum_uart_send_crlf(), "CRLF TX succeeds");
    check(tx_calls == 2u, "CRLF TX byte count");

    tx_calls = 0u;
    tx_failures = 3u;
    check(spectrum_uart_send_bytes(data, sizeof(data)),
          "transient TX busy recovers");
    check(tx_calls == 5u, "transient retry count");

    tx_calls = 0u;
    tx_always_fail = 1u;
    check(!spectrum_uart_send_bytes(data, sizeof(data)),
          "persistent TX busy fails");
    check(tx_calls == 4u, "persistent failure aborts first byte");

    puts("uart platform tests ok");
    return 0;
}
