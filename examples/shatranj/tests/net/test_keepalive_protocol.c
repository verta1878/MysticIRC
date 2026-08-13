#include "spectrum/transport/keepalive_protocol.h"

#include <stdio.h>

static int failures;

static void check(int ok, const char *label)
{
    if (!ok) {
        printf("FAIL: %s\n", label);
        ++failures;
    }
}

static void test_ping_prefix(void)
{
    check(spectrum_keepalive_is_ping("PING"), "ping exact");
    check(!spectrum_keepalive_is_ping("PINGX"), "ping prefix rejected");
    check(!spectrum_keepalive_is_ping("APING"), "ping rejects offset");
}

static void test_ack_prefix(void)
{
    check(spectrum_keepalive_is_ack_ping("ACK PING"), "ack exact");
    check(!spectrum_keepalive_is_ack_ping("ACK PINGX"), "ack prefix rejected");
    check(!spectrum_keepalive_is_ack_ping("ACK PIN"), "ack rejects short");
}

int main(void)
{
    test_ping_prefix();
    test_ack_prefix();

    if (failures != 0) {
        printf("keepalive protocol tests failed: %d\n", failures);
        return 1;
    }
    printf("keepalive protocol tests ok\n");
    return 0;
}
