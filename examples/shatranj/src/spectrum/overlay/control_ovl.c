#include "spectrum/session/event.h"

#include "common/protocol/game_protocol.h"
#include "common/protocol/mqtt_session_protocol.h"
#include "common/savegame/savegame_format.h"

#ifdef NETCHESSZX_FIXED_LOW_RAM
#include "spectrum/overlay/overlay_context.h"
#endif

#define SESSION_CONTROL_ACK 0u
#define SESSION_CONTROL_NACK 1u
#define SESSION_CONTROL_PAYLOAD 2u
#define SESSION_CONTROL_NACK_REASON 0x01u
#define SESSION_CONTROL_PAYLOAD_DETAIL 0x02u

typedef struct session_control_token {
    const char *token;
    uint8_t ack_event;
    uint8_t nack_event;
    uint8_t payload_event;
    uint8_t flags;
} session_control_token_t;

static const session_control_token_t session_control_tokens[] = {
    { NETCHESS_PROTO_GAME_START,
      NETCHESSZX_SESSION_EVENT_ACK_GAME_START,
      NETCHESSZX_SESSION_EVENT_NACK_GAME_START,
      NETCHESSZX_SESSION_EVENT_GAME_START,
      SESSION_CONTROL_NACK_REASON | SESSION_CONTROL_PAYLOAD_DETAIL },
    { NETCHESS_PROTO_RESET,
      NETCHESSZX_SESSION_EVENT_ACK_RESET,
      NETCHESSZX_SESSION_EVENT_NACK_RESET,
      NETCHESSZX_SESSION_EVENT_RESET,
      SESSION_CONTROL_NACK_REASON },
    { NETCHESS_PROTO_DRAW,
      NETCHESSZX_SESSION_EVENT_ACK_DRAW,
      NETCHESSZX_SESSION_EVENT_NACK_DRAW,
      NETCHESSZX_SESSION_EVENT_DRAW,
      0u },
    { NETCHESS_PROTO_RESIGN,
      NETCHESSZX_SESSION_EVENT_ACK_RESIGN,
      NETCHESSZX_SESSION_EVENT_NACK_MOVE,
      NETCHESSZX_SESSION_EVENT_RESIGN,
      0u }
};

static netchesszx_session_event_t session_classify_control(
    const char *text,
    uint8_t mode)
{
    uint8_t i;

    for (i = 0u; i < (uint8_t)(sizeof(session_control_tokens) /
                                sizeof(session_control_tokens[0])); ++i) {
        const session_control_token_t *entry = &session_control_tokens[i];
        const char *tail = netchess_after_prefix(text, entry->token);

        if (tail == 0) {
            continue;
        }
        if (*tail == '\0') {
            if (mode == SESSION_CONTROL_ACK) {
                return (netchesszx_session_event_t)entry->ack_event;
            }
            if (mode == SESSION_CONTROL_NACK) {
                return (netchesszx_session_event_t)entry->nack_event;
            }
            return (netchesszx_session_event_t)entry->payload_event;
        }
        if (*tail == ' ') {
            if (mode == SESSION_CONTROL_NACK &&
                (entry->flags & SESSION_CONTROL_NACK_REASON) != 0u) {
                return (netchesszx_session_event_t)entry->nack_event;
            }
            if (mode == SESSION_CONTROL_PAYLOAD &&
                (entry->flags & SESSION_CONTROL_PAYLOAD_DETAIL) != 0u) {
                return (netchesszx_session_event_t)entry->payload_event;
            }
        }
    }
    if (mode == SESSION_CONTROL_ACK) {
        return NETCHESSZX_SESSION_EVENT_ACK_MOVE;
    }
    return mode == SESSION_CONTROL_NACK
        ? NETCHESSZX_SESSION_EVENT_NACK_MOVE
        : NETCHESSZX_SESSION_EVENT_UNKNOWN;
}

netchesszx_session_event_t netchesszx_session_classify_game_payload(
    const char *payload)
{
    const char *tail;
    uint16_t takeback_ply;

    if (netchess_after_prefix(payload, NETCHESS_PROTO_MOVE_PREFIX) != 0) {
        return NETCHESSZX_SESSION_EVENT_MOVE;
    }
    tail = netchess_after_prefix(payload, NETCHESS_PROTO_TAKEBACK_PREFIX);
    if (tail != 0) {
        tail = netchess_mqtt_session_parse_u16_token(tail, &takeback_ply);
        if (tail != 0 && *tail == '\0' && takeback_ply != 0u) {
            return NETCHESSZX_SESSION_EVENT_TAKEBACK;
        }
    }
    if (netchess_after_prefix(payload, NETCHESS_PROTO_CHAT_PREFIX) != 0) {
        return NETCHESSZX_SESSION_EVENT_CHAT;
    }
    tail = netchess_after_prefix(payload, NETCHESS_PROTO_CANCEL_RESET);
    if (tail != 0 && *tail == '\0') {
        return NETCHESSZX_SESSION_EVENT_CANCEL_RESET;
    }
    tail = netchess_after_prefix(payload, NETCHESS_PROTO_CANCEL_DRAW);
    if (tail != 0 && *tail == '\0') {
        return NETCHESSZX_SESSION_EVENT_CANCEL_DRAW;
    }
    tail = netchess_after_prefix(payload, NETCHESS_PROTO_ACK_PREFIX);
    if (tail != 0) {
        return session_classify_control(tail, SESSION_CONTROL_ACK);
    }
    tail = netchess_after_prefix(payload, NETCHESS_PROTO_NACK_PREFIX);
    if (tail != 0) {
        return session_classify_control(tail, SESSION_CONTROL_NACK);
    }
    tail = netchess_after_prefix(payload, NETCHESS_PROTO_BYE);
    if (tail != 0 && *tail == '\0') {
        return NETCHESSZX_SESSION_EVENT_BYE;
    }
    if (payload[0] == 'B' && payload[1] == 'U' && payload[2] == 'S' &&
        payload[3] == 'Y' && payload[4] == '\0') {
        return NETCHESSZX_SESSION_EVENT_HOST_BUSY;
    }
    {
        netchesszx_session_event_t event =
            session_classify_control(payload, SESSION_CONTROL_PAYLOAD);

        if (event != NETCHESSZX_SESSION_EVENT_UNKNOWN) {
            return event;
        }
    }
    if (payload[0] == 'R') {
        if (payload[2] == '\0') {
            switch (payload[1]) {
            case 'Q': return NETCHESSZX_SESSION_EVENT_RESTORE_RQ;
            case 'Y': return NETCHESSZX_SESSION_EVENT_RESTORE_RY;
            case 'N': return NETCHESSZX_SESSION_EVENT_RESTORE_RN;
            case 'A': return NETCHESSZX_SESSION_EVENT_RESTORE_RA;
            default: break;
            }
        } else if (payload[1] == 'S' && payload[2] == '0' &&
            (payload[3] == '0' || payload[3] == '1') &&
            payload[4] == ' ' &&
            payload[NETCHESSZX_SAVE_RESTORE_FRAME_MAX] == '\0') {
            return NETCHESSZX_SESSION_EVENT_RESTORE_RS;
        }
    }
    return NETCHESSZX_SESSION_EVENT_UNKNOWN;
}

#ifdef NETCHESSZX_FIXED_LOW_RAM
uint8_t control_classify_ovl(volatile uint8_t *ctx) __z88dk_fastcall
{
    uint16_t payload_addr =
        (uint16_t)ctx[SPECTRUM_OVL_CTX_PTR_LO] |
        ((uint16_t)ctx[SPECTRUM_OVL_CTX_PTR_HI] << 8);

    return (uint8_t)netchesszx_session_classify_game_payload(
        (const char *)payload_addr);
}
#endif
