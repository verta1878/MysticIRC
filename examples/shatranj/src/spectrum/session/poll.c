#include "spectrum/session/poll.h"

#include "common/savegame/savegame_format.h"
#include "spectrum/config/session.h"
#include "spectrum/session/outgoing.h"
#include "spectrum/transport/link.h"
#include "spectrum/transport/keepalive_protocol.h"

uint8_t netchesszx_session_poll(netchesszx_session_ping_t *ping,
                                char *payload,
                                uint8_t payload_cap,
                                netchesszx_session_poll_result_t *out)
{
    int16_t link;
    uint8_t payload_flags = 0u;
    uint8_t retained = 0u;
    uint8_t is_mqtt = netchesszx_transport_is_mqtt();
    uint8_t ping_ev;

    out->event = NETCHESSZX_SESSION_EVENT_UNKNOWN;
    out->retained = 0u;
    if (payload_cap != 0u) {
        payload[0] = '\0';
        payload[(uint8_t)(payload_cap - 1u)] = '\0';
        if (payload_cap > NETCHESSZX_SAVE_RESTORE_FRAME_MAX) {
            payload[NETCHESSZX_SAVE_RESTORE_FRAME_MAX] = (char)0xff;
        }
    }

    link = spectrum_link_read_payload(payload, payload_cap);
    /* Broker PINGRESP no longer resets the session miss counter: it proves
       the BROKER is alive, not the peer. Peer liveness now runs on
       app-level PING/ACK PING over the topics (send_ping). */
    if (link == -2) {
        return NETCHESSZX_SESSION_POLL_DISCONNECTED;
    }
    if (link == SPECTRUM_LINK_READ_TIMEOUT) {
        if (is_mqtt && !netchesszx_session_peer_ready_state) {
            return NETCHESSZX_SESSION_POLL_NONE;
        }
        ping_ev = netchesszx_session_ping_timeout(
            ping,
            is_mqtt,
            (uint8_t)(is_mqtt || !netchesszx_session_is_host()));
        if (ping_ev != NETCHESSZX_SESSION_PING_NONE) {
            if (ping_ev == NETCHESSZX_SESSION_PING_LOST) {
                if ((uint8_t)(is_mqtt &
                              netchesszx_session_peer_ready_state) &&
                    netchesszx_session_is_host()) {
                    ping_ev = spectrum_link_mqtt_publish_offline(
                        SPECTRUM_LINK_ROUTE_PRESENCE_PEER);
                    if (ping_ev) {
                        out->event = NETCHESSZX_SESSION_EVENT_BYE;
                        return NETCHESSZX_SESSION_POLL_EVENT;
                    }
                    (void)spectrum_link_mqtt_publish_offline(
                        SPECTRUM_LINK_ROUTE_PRESENCE);
                }
                return NETCHESSZX_SESSION_POLL_DISCONNECTED;
            }
            if (!netchesszx_session_send_ping()) {
                if ((uint8_t)(is_mqtt & netchesszx_session_role)) {
                    (void)spectrum_link_mqtt_publish_offline(
                        SPECTRUM_LINK_ROUTE_PRESENCE);
                }
                return NETCHESSZX_SESSION_POLL_DISCONNECTED;
            }
            netchesszx_session_ping_sent(ping, is_mqtt);
        }
        return NETCHESSZX_SESSION_POLL_NONE;
    }
    if (link < 0) {
        return NETCHESSZX_SESSION_POLL_NONE;
    }

    if (!is_mqtt) {
        netchesszx_session_ping_rx_data(ping);
    }
    spectrum_link_background_drain();
    if (is_mqtt) {
        payload_flags = spectrum_link_payload_flags();
        retained = (uint8_t)((payload_flags &
                              SPECTRUM_LINK_PAYLOAD_RETAINED) != 0u);
    }
    out->event = netchesszx_session_classify_event(payload,
                                                   is_mqtt,
                                                   retained,
                                                   netchesszx_session_is_host());
    out->retained = retained;
    if (is_mqtt && out->event == NETCHESSZX_SESSION_EVENT_MOVE &&
        (payload_flags & SPECTRUM_LINK_PAYLOAD_GAME_ROUTE) == 0u) {
        out->event = NETCHESSZX_SESSION_EVENT_UNKNOWN;
        out->retained = 0u;
        return NETCHESSZX_SESSION_POLL_NONE;
    }
    if (netchesszx_session_event_ignores_retained(out->event, retained)) {
        out->event = NETCHESSZX_SESSION_EVENT_UNKNOWN;
        out->retained = 0u;
        return NETCHESSZX_SESSION_POLL_NONE;
    }
    if ((uint8_t)(is_mqtt & netchesszx_session_peer_ready_state) &&
        out->event >= NETCHESSZX_SESSION_EVENT_PING &&
        out->event <= NETCHESSZX_SESSION_EVENT_HOST_BUSY &&
        out->event != NETCHESSZX_SESSION_EVENT_ACK_MOVE &&
        out->event != NETCHESSZX_SESSION_EVENT_NACK_MOVE &&
        (out->event != NETCHESSZX_SESSION_EVENT_ACK_PING ||
         ping->misses != 0u)) {
        netchesszx_session_ping_rx_data(ping);
        ++retained;
    }
    if (out->event == NETCHESSZX_SESSION_EVENT_PING) {
        if (is_mqtt) {
            if (!retained) {
                out->event = NETCHESSZX_SESSION_EVENT_UNKNOWN;
                out->retained = 0u;
                return NETCHESSZX_SESSION_POLL_NONE;
            }
        } else {
            netchesszx_session_ping_rx_direct_peer_ping(ping);
        }
        /* DIRECT: dropped ACK send = peer counts one miss and re-pings. */
        if (!netchesszx_session_send_ack_ping() && is_mqtt) {
            return NETCHESSZX_SESSION_POLL_DISCONNECTED;
        }
        out->event = NETCHESSZX_SESSION_EVENT_UNKNOWN;
        out->retained = 0u;
        return NETCHESSZX_SESSION_POLL_NONE;
    }
    if (out->event == NETCHESSZX_SESSION_EVENT_ACK_PING) {
        (void)payload;
        (void)netchesszx_session_ping_ack(ping, is_mqtt);
        out->event = NETCHESSZX_SESSION_EVENT_UNKNOWN;
        out->retained = 0u;
        return NETCHESSZX_SESSION_POLL_NONE;
    }
    return NETCHESSZX_SESSION_POLL_EVENT;
}
