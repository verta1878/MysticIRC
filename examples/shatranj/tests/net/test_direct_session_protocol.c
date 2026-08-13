#include "common/protocol/direct_session_protocol.h"

#include <stdio.h>
#include <string.h>

static int failures;

static void check(int ok, const char *label)
{
    if (!ok) {
        printf("FAIL: %s\n", label);
        ++failures;
    }
}

static void check_text(const char *got, const char *expected, const char *label)
{
    if (strcmp(got, expected) != 0) {
        printf("FAIL: %s got='%s' expected='%s'\n", label, got, expected);
        ++failures;
    }
}

static void test_start_white_owner(void)
{
    uint8_t owner = 0xFFu;

    check(netchess_direct_parse_start_white_owner("GAME START WHITE=HOST",
                                                  &owner),
          "parse host white owner");
    check(owner == NETCHESS_DIRECT_WHITE_OWNER_HOST, "host owns white");
    check(netchess_direct_parse_start_white_owner("GAME START WHITE=GUEST",
                                                  &owner),
          "parse guest white owner");
    check(owner == NETCHESS_DIRECT_WHITE_OWNER_GUEST, "guest owns white");
    check(!netchess_direct_parse_start_white_owner("GAME STARTED WHITE=HOST",
                                                   &owner),
          "reject game started");
    check(!netchess_direct_parse_start_white_owner("GAME START WHITE=DEVICE",
                                                   &owner),
          "reject non-role owner");
    check(!netchess_direct_parse_start_white_owner("GAME START WHITE=BAD",
                                                   &owner),
          "reject bad owner");
}

static void test_hello_parsing(void)
{
    uint8_t owner = 0xFFu;

    check(netchess_direct_is_hello("HELLO DIRECT GUEST"), "is hello guest");
    check(netchess_direct_is_hello("HELLO DIRECT HOST WHITE=HOST"),
          "is hello host");
    check(!netchess_direct_is_hello("GAME START WHITE=HOST"), "not hello");

    check(netchess_direct_parse_guest_hello("HELLO DIRECT GUEST"),
          "parse guest hello");
    check(!netchess_direct_parse_guest_hello("HELLO DIRECT GUESTX"),
          "reject guest hello suffix");
    check(!netchess_direct_parse_guest_hello("HELLO DIRECT HOST WHITE=HOST"),
          "guest parser rejects host hello");

    check(netchess_direct_parse_host_hello("HELLO DIRECT HOST WHITE=HOST",
                                           &owner),
          "parse host hello white=host");
    check(owner == NETCHESS_DIRECT_WHITE_OWNER_HOST, "host hello host owner");
    check(netchess_direct_parse_host_hello("HELLO DIRECT HOST WHITE=GUEST",
                                           &owner),
          "parse host hello white=guest");
    check(owner == NETCHESS_DIRECT_WHITE_OWNER_GUEST, "host hello guest owner");
    check(!netchess_direct_parse_host_hello("HELLO DIRECT HOST WHITE=DEVICE",
                                            &owner),
          "reject non-role host hello");
    check(!netchess_direct_parse_host_hello("HELLO DIRECT GUEST", &owner),
          "host parser rejects guest hello");
}

static void test_hello_emit(void)
{
    check_text(netchess_direct_hello(1u, 1u),
               "HELLO DIRECT HOST WHITE=HOST",
               "emit host white hello");
    check_text(netchess_direct_hello(1u, 0u),
               "HELLO DIRECT HOST WHITE=GUEST",
               "emit host black hello");
    check_text(netchess_direct_hello(0u, 1u),
               "HELLO DIRECT GUEST",
               "emit guest hello (white ignored)");
    check_text(netchess_direct_hello(0u, 0u),
               "HELLO DIRECT GUEST",
               "emit guest hello");
}

int main(void)
{
    test_start_white_owner();
    test_hello_parsing();
    test_hello_emit();

    if (failures != 0) {
        printf("direct session protocol tests failed: %d\n", failures);
        return 1;
    }
    printf("direct session protocol tests ok\n");
    return 0;
}
