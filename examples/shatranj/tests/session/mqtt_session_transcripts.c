#include "mqtt_session_transcripts.h"

#include "common/session/session.h"

#define CHAT_MAX_SAMPLE "123456789012345678901234567890123456789012"

#define EV_LINK_UP(id) \
    {0, 0u, MQTT_TRANSCRIPT_LINK_UP, 0u, 0u, 0u, (id), 0u}
#define EV_LINK_DOWN(id) \
    {0, 0u, MQTT_TRANSCRIPT_LINK_DOWN, 0u, 0u, 0u, (id), 0u}
#define EV_RX(text, route_value, flag_value, id) \
    {(text), 0u, MQTT_TRANSCRIPT_RX, 0u, (route_value), (flag_value), (id), 0u}
#define EV_TX_OK \
    {0, 0u, MQTT_TRANSCRIPT_TX_OK, 0u, 0u, 0u, 0u, 0u}
#define EV_TX_OK_ID(id) \
    {0, 0u, MQTT_TRANSCRIPT_TX_OK, 0u, 0u, 0u, (id), 0u}
#define EV_TX_FAILED \
    {0, 0u, MQTT_TRANSCRIPT_TX_FAILED, 0u, 0u, 0u, 0u, 0u}
#define EV_TIMEOUT(timer) \
    {0, 0u, MQTT_TRANSCRIPT_TIMEOUT, (timer), 0u, 0u, 0u, 0u}
#define EV_LOCAL(request_value, number, text, phase_value) \
    {(text), (number), MQTT_TRANSCRIPT_LOCAL, (request_value), 0u, 0u, 0u, \
     (phase_value)}
#define EV_GAME_RESULT(result_value, number, text) \
    {(text), (number), MQTT_TRANSCRIPT_GAME_RESULT, (result_value), \
     0u, 0u, 0u, 0u}
#define EV_GAME_RESULT_ID(result_value, number, text, id) \
    {(text), (number), MQTT_TRANSCRIPT_GAME_RESULT, (result_value), \
     0u, 0u, (id), 0u}
#define EV_DECISION(decision_value) \
    {0, 0u, MQTT_TRANSCRIPT_DECISION, (decision_value), 0u, 0u, 0u, 0u}
#define EV_DECISION_ID(decision_value, id) \
    {0, 0u, MQTT_TRANSCRIPT_DECISION, (decision_value), 0u, 0u, (id), 0u}

#define OBS_SEND(text, route_value, retain_value, id) \
    {(text), 0u, MQTT_OBSERVE_SEND, 0u, 0u, (route_value), \
     (retain_value), (id)}
#define OBS_SEND_NACK_COMPAT(text, route_value, retain_value, id) \
    {(text), 0u, MQTT_OBSERVE_SEND, 0u, \
     MQTT_OBSERVE_DETAIL_NACK_COMPAT, (route_value), \
     (retain_value), (id)}
#define OBS_SEND_NACK_ROUTE_COMPAT(text, route_value, retain_value, id) \
    {(text), 0u, MQTT_OBSERVE_SEND, 0u, \
     MQTT_OBSERVE_DETAIL_NACK_ROUTE_COMPAT, (route_value), \
     (retain_value), (id)}
#define OBS_TIMER_SET(timer, ticks) \
    {0, (ticks), MQTT_OBSERVE_TIMER_SET, (timer), 0u, 0u, 0u, 0u}
#define OBS_TIMER_CANCEL(timer) \
    {0, 0u, MQTT_OBSERVE_TIMER_CANCEL, (timer), 0u, 0u, 0u, 0u}
#define OBS_INTERNAL_TIMER_SET(timer, ticks) \
    {0, (ticks), MQTT_OBSERVE_TIMER_SET, (timer), \
     MQTT_OBSERVE_DETAIL_INTERNAL, 0u, 0u, 0u}
#define OBS_INTERNAL_TIMER_CANCEL(timer) \
    {0, 0u, MQTT_OBSERVE_TIMER_CANCEL, (timer), \
     MQTT_OBSERVE_DETAIL_INTERNAL, 0u, 0u, 0u}
#define OBS_CLOSE(id) \
    {0, 0u, MQTT_OBSERVE_LINK_CLOSE, 0u, 0u, 0u, 0u, (id)}
#define OBS_SESSION(status) \
    {0, 0u, MQTT_OBSERVE_SESSION, (status), 0u, 0u, 0u, 0u}
#define OBS_SIDE(color_value, sid) \
    {0, (sid), MQTT_OBSERVE_SIDE, (color_value), 0u, 0u, 0u, 0u}
#define OBS_DECISION(control_value, number) \
    {0, (number), MQTT_OBSERVE_DECISION, (control_value), 0u, 0u, 0u, 0u}
#define OBS_GAME(kind_value, result_value, number, text) \
    {(text), (number), MQTT_OBSERVE_GAME, (kind_value), (result_value), \
     0u, 0u, 0u}

#define NO_OBSERVATIONS {{0}}, 0u
#define NO_STATE_CHANGE \
    {{0, 0u, MQTT_OBSERVE_STATE_UNCHANGED, 0u, 0u, 0u, 0u, 0u}}, 1u

#define GUEST_READY_PREFIX \
    {"guest link up", EV_LINK_UP(1u), NO_OBSERVATIONS}, \
    { \
        "retained host selects side", \
        EV_RX("H W 77", SESSION_ROUTE_META, SESSION_RX_RETAINED, 1u), \
        {OBS_SIDE(SESSION_COLOR_BLACK, 77u)}, \
        1u \
    }, \
    { \
        "live host starts claim", \
        EV_RX("H W 77", SESSION_ROUTE_META, SESSION_RX_LIVE, 1u), \
        { \
            OBS_SEND("O B 77", SESSION_ROUTE_PRESENCE, 1u, 1u), \
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS) \
        }, \
        2u \
    }, \
    { \
        "online completion sends join", \
        EV_TX_OK, \
        { \
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD), \
            OBS_SEND("J 77", SESSION_ROUTE_META, 0u, 1u), \
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS) \
        }, \
        3u \
    }, \
    { \
        "join completion makes ready", \
        EV_TX_OK, \
        { \
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD), \
            OBS_SESSION(SESSION_CHANGED_READY), \
            OBS_TIMER_SET(SESSION_TIMER_LIVENESS, 250u), \
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 250u) \
        }, \
        4u \
    }

#define GUEST_ACTIVE_PREFIX \
    GUEST_READY_PREFIX, \
    { \
        "live host start sends ack before activation", \
        EV_RX("GAME START", SESSION_ROUTE_GAME, SESSION_RX_LIVE, 1u), \
        { \
            OBS_TIMER_CANCEL(SESSION_TIMER_LIVENESS), \
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_CONTROL), \
            OBS_SEND("ACK GAME START", SESSION_ROUTE_CONTROL, 0u, 1u), \
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS) \
        }, \
        4u \
    }, \
    { \
        "start ack completion rearms liveness", \
        EV_TX_OK, \
        { \
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD), \
            OBS_SESSION(SESSION_CHANGED_STARTED), \
            OBS_TIMER_SET(SESSION_TIMER_LIVENESS, 250u) \
        }, \
        3u \
    }

#define PROMOTION_CYCLE(ply_number, ply_text, move_text) \
    { \
        "local promotion sends", \
        EV_LOCAL(SESSION_REQUEST_MOVE, 0u, (move_text), SESSION_PHASE_ACTIVE), \
        { \
            OBS_TIMER_CANCEL(SESSION_TIMER_LIVENESS), \
            OBS_SEND("MOVE " ply_text " " move_text, \
                     SESSION_ROUTE_GAME, 0u, 1u), \
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS) \
        }, \
        3u \
    }, \
    { \
        "promotion tx completion arms reply", \
        EV_TX_OK, \
        { \
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD), \
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 125u) \
        }, \
        2u \
    }, \
    { \
        "promotion app ack applies move", \
        EV_RX("ACK " ply_text, SESSION_ROUTE_ACK, SESSION_RX_LIVE, 1u), \
        { \
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_CONTROL), \
            OBS_GAME(SESSION_DELIVER_LOCAL_MOVE, 0u, \
                     (ply_number), (move_text)), \
            OBS_GAME(SESSION_DELIVER_CONTROL_RESULT, \
                     SESSION_CONTROL_ACCEPTED, \
                     SESSION_REQUEST_MOVE, 0), \
            OBS_TIMER_SET(SESSION_TIMER_LIVENESS, 250u) \
        }, \
        4u \
    }

#define GUEST_ACTIVE_ONE_PLY_PREFIX_WITH_TIMERS(set_control, cancel_control, \
                                                set_liveness) \
    GUEST_ACTIVE_PREFIX, \
    { \
        "one-ply setup sends move", \
        EV_LOCAL(SESSION_REQUEST_MOVE, 0u, "e2e4", SESSION_PHASE_ACTIVE), \
        { \
            OBS_TIMER_CANCEL(SESSION_TIMER_LIVENESS), \
            OBS_SEND("MOVE 1 e2e4", SESSION_ROUTE_GAME, 0u, 1u), \
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS) \
        }, \
        3u \
    }, \
    { \
        "one-ply move handoff", \
        EV_TX_OK, \
        { \
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD), \
            set_control(SESSION_TIMER_CONTROL, 125u) \
        }, \
        2u \
    }, \
    { \
        "one-ply move accepted", \
        EV_RX("ACK 1 e4", SESSION_ROUTE_ACK, SESSION_RX_LIVE, 1u), \
        { \
            cancel_control(SESSION_TIMER_CONTROL), \
            OBS_GAME(SESSION_DELIVER_LOCAL_MOVE, 0u, 1u, "e2e4"), \
            OBS_GAME(SESSION_DELIVER_CONTROL_RESULT, \
                     SESSION_CONTROL_ACCEPTED, SESSION_REQUEST_MOVE, "e4"), \
            set_liveness(SESSION_TIMER_LIVENESS, 250u) \
        }, \
        4u \
    }

#define GUEST_ACTIVE_ONE_PLY_PREFIX \
    GUEST_ACTIVE_ONE_PLY_PREFIX_WITH_TIMERS(OBS_TIMER_SET, OBS_TIMER_CANCEL, \
                                            OBS_TIMER_SET)

#define GUEST_ACTIVE_ONE_PLY_PRIVATE_PREFIX \
    GUEST_ACTIVE_ONE_PLY_PREFIX_WITH_TIMERS(OBS_INTERNAL_TIMER_SET, \
                                            OBS_INTERNAL_TIMER_CANCEL, \
                                            OBS_INTERNAL_TIMER_SET)

#define GUEST_ACTIVE_REMOTE_ONE_PLY_PREFIX \
    GUEST_ACTIVE_PREFIX, \
    { \
        "one-ply setup receives remote move", \
        EV_RX("MOVE 1 e2e4 e4", SESSION_ROUTE_GAME, SESSION_RX_LIVE, 1u), \
        { \
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_LIVENESS), \
            OBS_GAME(SESSION_DELIVER_REMOTE_MOVE, 1u, 1u, "e2e4"), \
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 125u) \
        }, \
        3u \
    }, \
    { \
        "one-ply remote move accepted", \
        EV_GAME_RESULT(SESSION_GAME_ACCEPTED, 1u, 0), \
        { \
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_LIVENESS), \
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_CONTROL), \
            OBS_SEND("ACK 1", SESSION_ROUTE_ACK, 0u, 1u), \
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS) \
        }, \
        4u \
    }, \
    { \
        "one-ply remote ack handoff", \
        EV_TX_OK, \
        { \
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD), \
            OBS_TIMER_SET(SESSION_TIMER_LIVENESS, 250u) \
        }, \
        2u \
    }

static const MqttTranscriptStep seat_filter_acquire_steps[] = {
    {
        "broker link up",
        EV_LINK_UP(1u),
        NO_OBSERVATIONS
    },
    {
        "retained host selects probe only",
        EV_RX("H W 77", SESSION_ROUTE_META, SESSION_RX_RETAINED, 1u),
        {OBS_SIDE(SESSION_COLOR_BLACK, 77u)},
        1u
    },
    {
        "duplicate retained host is idempotent",
        EV_RX("H W 77", SESSION_ROUTE_META, SESSION_RX_RETAINED, 1u),
        NO_OBSERVATIONS
    },
    {
        "own live online echo is not busy",
        EV_RX("O B 77", SESSION_ROUTE_PRESENCE, SESSION_RX_LIVE, 1u),
        NO_OBSERVATIONS
    },
    {
        "retained online wrong session is not busy",
        EV_RX("O B 78", SESSION_ROUTE_PRESENCE, SESSION_RX_RETAINED, 1u),
        NO_OBSERVATIONS
    },
    {
        "live host starts serialized seat claim",
        EV_RX("H W 77", SESSION_ROUTE_META, SESSION_RX_LIVE, 1u),
        {
            OBS_SEND("O B 77", SESSION_ROUTE_PRESENCE, 1u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        2u
    },
    {
        "online handoff sends live join",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_SEND("J 77", SESSION_ROUTE_META, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "join handoff makes guest ready",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_SESSION(SESSION_CHANGED_READY),
            OBS_TIMER_SET(SESSION_TIMER_LIVENESS, 250u),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 250u)
        },
        4u
    },
    {
        "duplicate live host is liveness-inert",
        EV_RX("H W 77", SESSION_ROUTE_META, SESSION_RX_LIVE, 1u),
        NO_OBSERVATIONS
    },
    {
        "duplicate peer online is liveness-inert",
        EV_RX("O W 77", SESSION_ROUTE_PRESENCE, SESSION_RX_LIVE, 1u),
        NO_OBSERVATIONS
    }
};

static const MqttTranscriptStep seat_busy_steps[] = {
    {"broker link up", EV_LINK_UP(1u), NO_OBSERVATIONS},
    {
        "retained host selects probe",
        EV_RX("H W 77", SESSION_ROUTE_META, SESSION_RX_RETAINED, 1u),
        {OBS_SIDE(SESSION_COLOR_BLACK, 77u)},
        1u
    },
    {
        "exact retained own seat is busy and terminal",
        EV_RX("O B 77", SESSION_ROUTE_PRESENCE, SESSION_RX_RETAINED, 1u),
        {
            OBS_SESSION(SESSION_CHANGED_BUSY),
            OBS_CLOSE(1u),
            OBS_SESSION(SESSION_CHANGED_ENDED)
        },
        3u
    }
};

static const MqttTranscriptStep seat_tx_fail_before_claim_steps[] = {
    {"broker link up", EV_LINK_UP(1u), NO_OBSERVATIONS},
    {
        "live host starts claim without retained probe",
        EV_RX("H W 77", SESSION_ROUTE_META, SESSION_RX_LIVE, 1u),
        {
            OBS_SIDE(SESSION_COLOR_BLACK, 77u),
            OBS_SEND("O B 77", SESSION_ROUTE_PRESENCE, 1u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "failed online handoff ends without offline cleanup",
        EV_TX_FAILED,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_CLOSE(1u),
            OBS_SESSION(SESSION_CHANGED_ENDED)
        },
        3u
    }
};

static const MqttTranscriptStep seat_tx_fail_after_claim_steps[] = {
    {"broker link up", EV_LINK_UP(1u), NO_OBSERVATIONS},
    {
        "live host starts claim",
        EV_RX("H W 77", SESSION_ROUTE_META, SESSION_RX_LIVE, 1u),
        {
            OBS_SIDE(SESSION_COLOR_BLACK, 77u),
            OBS_SEND("O B 77", SESSION_ROUTE_PRESENCE, 1u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "online handoff sends join",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_SEND("J 77", SESSION_ROUTE_META, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "failed join publishes retained offline cleanup",
        EV_TX_FAILED,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_SEND("F B 77", SESSION_ROUTE_PRESENCE, 1u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "offline cleanup handoff ends session",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_CLOSE(1u),
            OBS_SESSION(SESSION_CHANGED_ENDED)
        },
        3u
    }
};

static const MqttTranscriptStep host_join_duplicate_steps[] = {
    {
        "host link publishes retained online",
        EV_LINK_UP(1u),
        {
            OBS_SEND("O W 77", SESSION_ROUTE_PRESENCE, 1u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        2u
    },
    {
        "online handoff publishes retained host",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_SEND("H W 77", SESSION_ROUTE_META, 1u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "host handoff arms setup announce",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 250u)
        },
        2u
    },
    {
        "own live host echo is ignored",
        EV_RX("H W 77", SESSION_ROUTE_META, SESSION_RX_LIVE, 1u),
        NO_OBSERVATIONS
    },
    {
        "second host session cannot become peer",
        EV_RX("H B 78", SESSION_ROUTE_META, SESSION_RX_LIVE, 1u),
        NO_OBSERVATIONS
    },
    {
        "retained join is inert",
        EV_RX("J 77", SESSION_ROUTE_META, SESSION_RX_RETAINED, 1u),
        NO_OBSERVATIONS
    },
    {
        "live join gets live host acknowledgement",
        EV_RX("J 77", SESSION_ROUTE_META, SESSION_RX_LIVE, 1u),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_CONTROL),
            OBS_SEND("H W 77", SESSION_ROUTE_META, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "host acknowledgement handoff makes host ready",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_SESSION(SESSION_CHANGED_READY),
            OBS_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        3u
    },
    {
        "ready host ignores conflicting host session",
        EV_RX("H B 78", SESSION_ROUTE_META, SESSION_RX_LIVE, 1u),
        NO_OBSERVATIONS
    },
    {
        "duplicate join is acknowledged without liveness credit",
        EV_RX("J 77", SESSION_ROUTE_META, SESSION_RX_LIVE, 1u),
        {
            OBS_SEND("H W 77", SESSION_ROUTE_META, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        2u
    },
    {
        "duplicate acknowledgement is liveness-inert",
        EV_TX_OK,
        {OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD)},
        1u
    },
    {
        "duplicate peer online is liveness-inert",
        EV_RX("O B 77", SESSION_ROUTE_PRESENCE, SESSION_RX_LIVE, 1u),
        NO_OBSERVATIONS
    }
};

static const MqttTranscriptStep bootstrap_stale_presence_steps[] = {
    {"broker link up", EV_LINK_UP(1u), NO_OBSERVATIONS},
    {
        "retained host selects probe",
        EV_RX("H W 77", SESSION_ROUTE_META, SESSION_RX_RETAINED, 1u),
        {OBS_SIDE(SESSION_COLOR_BLACK, 77u)},
        1u
    },
    {
        "retained peer online is soft presence",
        EV_RX("O W 77", SESSION_ROUTE_PRESENCE, SESSION_RX_RETAINED, 1u),
        NO_OBSERVATIONS
    },
    {
        "retained peer offline is stale",
        EV_RX("F W 77", SESSION_ROUTE_PRESENCE, SESSION_RX_RETAINED, 1u),
        NO_OBSERVATIONS
    },
    {
        "idless live peer offline is ignored",
        EV_RX("F W", SESSION_ROUTE_PRESENCE, SESSION_RX_LIVE, 1u),
        NO_OBSERVATIONS
    },
    {
        "wrong-session live peer offline is ignored",
        EV_RX("F W 78", SESSION_ROUTE_PRESENCE, SESSION_RX_LIVE, 1u),
        NO_OBSERVATIONS
    },
    {
        "empty retained payload is ignored",
        EV_RX("", SESSION_ROUTE_CONTROL, SESSION_RX_RETAINED, 1u),
        NO_OBSERVATIONS
    },
    {
        "live host starts seat claim",
        EV_RX("H W 77", SESSION_ROUTE_META, SESSION_RX_LIVE, 1u),
        {
            OBS_SEND("O B 77", SESSION_ROUTE_PRESENCE, 1u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        2u
    },
    {
        "online handoff sends join",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_SEND("J 77", SESSION_ROUTE_META, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "join handoff makes ready",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_SESSION(SESSION_CHANGED_READY),
            OBS_TIMER_SET(SESSION_TIMER_LIVENESS, 250u),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 250u)
        },
        4u
    },
    {
        "fresh live host replaces ready bootstrap session",
        EV_RX("H W 78", SESSION_ROUTE_META, SESSION_RX_LIVE, 1u),
        {
            OBS_SIDE(SESSION_COLOR_BLACK, 78u),
            OBS_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SEND("O B 78", SESSION_ROUTE_PRESENCE, 1u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        4u
    },
    {
        "replacement online handoff sends fresh join",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_SEND("J 78", SESSION_ROUTE_META, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "replacement join handoff restores ready",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_TIMER_SET(SESSION_TIMER_LIVENESS, 250u),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 250u)
        },
        3u
    },
    {
        "stale live online cannot refresh ready session",
        EV_RX("O W 77", SESSION_ROUTE_PRESENCE, SESSION_RX_LIVE, 1u),
        NO_OBSERVATIONS
    },
    {
        "retained exact offline cannot end ready session",
        EV_RX("F W 78", SESSION_ROUTE_PRESENCE, SESSION_RX_RETAINED, 1u),
        NO_OBSERVATIONS
    },
    {
        "live own offline repairs retained online",
        EV_RX("F B 78", SESSION_ROUTE_PRESENCE, SESSION_RX_LIVE, 1u),
        {
            OBS_SEND("O B 78", SESSION_ROUTE_PRESENCE, 1u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        2u
    },
    {
        "online repair completion keeps existing liveness",
        EV_TX_OK,
        {OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD)},
        1u
    },
    {
        "live exact peer offline ends session",
        EV_RX("F W 78", SESSION_ROUTE_PRESENCE, SESSION_RX_LIVE, 1u),
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_CONTROL),
            OBS_SESSION(SESSION_CHANGED_ENDED)
        },
        3u
    },
    {"same broker link begins fresh session", EV_LINK_UP(1u),
     NO_OBSERVATIONS},
    {
        "fresh retained host selects new session",
        EV_RX("H B 88", SESSION_ROUTE_META, SESSION_RX_RETAINED, 1u),
        {OBS_SIDE(SESSION_COLOR_WHITE, 88u)},
        1u
    }
};

static const MqttTranscriptStep bootstrap_host_reannounce_steps[] = {
    {
        "host link publishes online",
        EV_LINK_UP(1u),
        {
            OBS_SEND("O W 77", SESSION_ROUTE_PRESENCE, 1u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        2u
    },
    {
        "online completion publishes retained host",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_SEND("H W 77", SESSION_ROUTE_META, 1u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "host completion arms setup timer",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 250u)
        },
        2u
    },
    {
        "setup timeout republishes retained host",
        EV_TIMEOUT(SESSION_TIMER_CONTROL),
        {
            OBS_SEND("H W 77", SESSION_ROUTE_META, 1u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        2u
    },
    {
        "reannounce completion rearms setup timer",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 250u)
        },
        2u
    },
    {
        "empty retained meta is ignored",
        EV_RX("", SESSION_ROUTE_CONTROL, SESSION_RX_RETAINED, 1u),
        NO_OBSERVATIONS
    }
};

static const MqttTranscriptStep bootstrap_guest_reannounce_steps[] = {
    GUEST_READY_PREFIX,
    {
        "setup timeout republishes live join",
        EV_TIMEOUT(SESSION_TIMER_CONTROL),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SEND("J 77", SESSION_ROUTE_META, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "reannounce completion rearms setup timer",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 250u),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 250u)
        },
        3u
    }
};

#define HOST_READY_PREFIX \
    { \
        "host link publishes online", \
        EV_LINK_UP(1u), \
        { \
            OBS_SEND("O W 77", SESSION_ROUTE_PRESENCE, 1u, 1u), \
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS) \
        }, \
        2u \
    }, \
    { \
        "online completion publishes host", \
        EV_TX_OK, \
        { \
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD), \
            OBS_SEND("H W 77", SESSION_ROUTE_META, 1u, 1u), \
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS) \
        }, \
        3u \
    }, \
    { \
        "host completion arms setup", \
        EV_TX_OK, \
        { \
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD), \
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 250u) \
        }, \
        2u \
    }, \
    { \
        "join receives live host", \
        EV_RX("J 77", SESSION_ROUTE_META, SESSION_RX_LIVE, 1u), \
        { \
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_CONTROL), \
            OBS_SEND("H W 77", SESSION_ROUTE_META, 0u, 1u), \
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS) \
        }, \
        3u \
    }, \
    { \
        "live host completion makes ready", \
        EV_TX_OK, \
        { \
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD), \
            OBS_SESSION(SESSION_CHANGED_READY), \
            OBS_TIMER_SET(SESSION_TIMER_LIVENESS, 250u) \
        }, \
        3u \
    }

#define HOST_ACTIVE_PREFIX \
    HOST_READY_PREFIX, \
    { \
        "ready host sends canonical start", \
        EV_LOCAL(SESSION_REQUEST_START, 0u, 0, SESSION_PHASE_READY), \
        { \
            OBS_TIMER_CANCEL(SESSION_TIMER_LIVENESS), \
            OBS_SEND("GAME START", SESSION_ROUTE_CONTROL, 0u, 1u), \
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS) \
        }, \
        3u \
    }, \
    { \
        "start tx completion only arms application reply", \
        EV_TX_OK, \
        { \
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD), \
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 125u) \
        }, \
        2u \
    }, \
    { \
        "duplicate local start while awaiting application ack is ignored", \
        EV_LOCAL(SESSION_REQUEST_START, 0u, 0, SESSION_PHASE_READY), \
        NO_OBSERVATIONS \
    }, \
    { \
        "retained application ack is ignored", \
        EV_RX("ACK GAME START", SESSION_ROUTE_CONTROL, \
              SESSION_RX_RETAINED, 1u), \
        NO_OBSERVATIONS \
    }, \
    { \
        "live application ack starts host", \
        EV_RX("ACK GAME START", SESSION_ROUTE_CONTROL, SESSION_RX_LIVE, 1u), \
        { \
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_CONTROL), \
            OBS_SESSION(SESSION_CHANGED_STARTED), \
            OBS_TIMER_SET(SESSION_TIMER_LIVENESS, 250u) \
        }, \
        3u \
    }

static const MqttTranscriptStep start_host_ack_steps[] = {
    HOST_ACTIVE_PREFIX,
    {
        "duplicate start ack credits liveness without restarting",
        EV_RX("ACK GAME START", SESSION_ROUTE_CONTROL, SESSION_RX_LIVE, 1u),
        {OBS_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)},
        1u
    },
    {
        "local start while active is ignored",
        EV_LOCAL(SESSION_REQUEST_START, 0u, 0, SESSION_PHASE_ACTIVE),
        NO_OBSERVATIONS
    }
};

#define START_RETRY_STEPS \
    { \
        "start reply timeout retries", \
        EV_TIMEOUT(SESSION_TIMER_CONTROL), \
        { \
            OBS_SEND("GAME START", SESSION_ROUTE_CONTROL, 0u, 1u), \
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, \
                          SESSION_TX_GUARD_TICKS) \
        }, \
        2u \
    }, \
    { \
        "start retry handoff rearms reply timer", \
        EV_TX_OK, \
        { \
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD), \
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 125u) \
        }, \
        2u \
    }

static const MqttTranscriptStep start_host_retry_limit_steps[] = {
    HOST_READY_PREFIX,
    {
        "ready host sends start",
        EV_LOCAL(SESSION_REQUEST_START, 0u, 0, SESSION_PHASE_READY),
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SEND("GAME START", SESSION_ROUTE_CONTROL, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD,
                          SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "initial start handoff arms reply timer",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 125u)
        },
        2u
    },
    START_RETRY_STEPS,
    START_RETRY_STEPS,
    START_RETRY_STEPS,
    START_RETRY_STEPS,
    START_RETRY_STEPS,
    {
        "start retry exhaustion releases local seat",
        EV_TIMEOUT(SESSION_TIMER_CONTROL),
        {
            OBS_SEND("F W 77", SESSION_ROUTE_PRESENCE, 1u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD,
                          SESSION_TX_GUARD_TICKS)
        },
        2u
    },
    {
        "seat release handoff clears retained metadata",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_SEND("", SESSION_ROUTE_META, 1u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD,
                          SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "metadata clear closes failed start",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_CLOSE(1u),
            OBS_SESSION(SESSION_CHANGED_ENDED)
        },
        3u
    }
};

static const MqttTranscriptStep start_host_nack_steps[] = {
    {
        "host link publishes online",
        EV_LINK_UP(1u),
        {
            OBS_SEND("O B 77", SESSION_ROUTE_PRESENCE, 1u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        2u
    },
    {
        "online completion publishes host",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_SEND("H B 77", SESSION_ROUTE_META, 1u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "host completion arms setup",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 250u)
        },
        2u
    },
    {
        "join receives live host",
        EV_RX("J 77", SESSION_ROUTE_META, SESSION_RX_LIVE, 1u),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_CONTROL),
            OBS_SEND("H B 77", SESSION_ROUTE_META, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "live host completion makes ready",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_SESSION(SESSION_CHANGED_READY),
            OBS_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        3u
    },
    {
        "ready host sends start",
        EV_LOCAL(SESSION_REQUEST_START, 0u, 0, SESSION_PHASE_READY),
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SEND("GAME START", SESSION_ROUTE_CONTROL, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "start tx completion arms reply",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 125u)
        },
        2u
    },
    {
        "live nack reports typed rejected start",
        EV_RX("NACK GAME START BUSY", SESSION_ROUTE_CONTROL,
              SESSION_RX_LIVE, 1u),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_CONTROL),
            OBS_GAME(SESSION_DELIVER_CONTROL_RESULT,
                     SESSION_CONTROL_REJECTED,
                     SESSION_REQUEST_START,
                     "BUSY"),
            OBS_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        3u
    }
};

static const MqttTranscriptStep start_guest_steps[] = {
    {"guest broker link up", EV_LINK_UP(1u), NO_OBSERVATIONS},
    {
        "retained host selects side",
        EV_RX("H W 77", SESSION_ROUTE_META, SESSION_RX_RETAINED, 1u),
        {OBS_SIDE(SESSION_COLOR_BLACK, 77u)},
        1u
    },
    {
        "live host starts claim",
        EV_RX("H W 77", SESSION_ROUTE_META, SESSION_RX_LIVE, 1u),
        {
            OBS_SEND("O B 77", SESSION_ROUTE_PRESENCE, 1u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        2u
    },
    {
        "online completion sends join",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_SEND("J 77", SESSION_ROUTE_META, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "join completion makes ready",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_SESSION(SESSION_CHANGED_READY),
            OBS_TIMER_SET(SESSION_TIMER_LIVENESS, 250u),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 250u)
        },
        4u
    },
    {
        "guest local start is ignored",
        EV_LOCAL(SESSION_REQUEST_START, 0u, 0, SESSION_PHASE_READY),
        NO_OBSERVATIONS
    },
    {
        "retained game start is ignored",
        EV_RX("GAME START", SESSION_ROUTE_CONTROL, SESSION_RX_RETAINED, 1u),
        NO_OBSERVATIONS
    },
    {
        "live game start with detail sends ack before activation",
        EV_RX("GAME START FUTURE", SESSION_ROUTE_CONTROL,
              SESSION_RX_LIVE, 1u),
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_CONTROL),
            OBS_SEND("ACK GAME START", SESSION_ROUTE_CONTROL, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        4u
    },
    {
        "start ack completion rearms liveness",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_SESSION(SESSION_CHANGED_STARTED),
            OBS_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        3u
    },
    {
        "duplicate live start is reacked only",
        EV_RX("GAME START", SESSION_ROUTE_CONTROL, SESSION_RX_LIVE, 1u),
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SEND("ACK GAME START", SESSION_ROUTE_CONTROL, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "duplicate ack completion rearms liveness",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        2u
    }
};

static const MqttTranscriptStep start_role_guards_steps[] = {
    {"guest broker link up", EV_LINK_UP(1u), NO_OBSERVATIONS},
    {
        "guest local start before ready is ignored",
        EV_LOCAL(SESSION_REQUEST_START, 0u, 0, SESSION_PHASE_HANDSHAKE),
        NO_OBSERVATIONS
    },
    {
        "guest remote start before live host is ignored",
        EV_RX("GAME START", SESSION_ROUTE_CONTROL, SESSION_RX_LIVE, 1u),
        NO_OBSERVATIONS
    }
};

static const MqttTranscriptStep move_local_ack_steps[] = {
    GUEST_ACTIVE_PREFIX,
    {
        "local move sends next ply",
        EV_LOCAL(SESSION_REQUEST_MOVE, 0u, "e2e4", SESSION_PHASE_ACTIVE),
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SEND("MOVE 1 e2e4", SESSION_ROUTE_GAME, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "move tx completion only arms reply",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 125u)
        },
        2u
    },
    {
        "move reply timeout retransmits same payload",
        EV_TIMEOUT(SESSION_TIMER_CONTROL),
        {
            OBS_SEND("MOVE 1 e2e4", SESSION_ROUTE_GAME, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        2u
    },
    {
        "move retry tx completion rearms reply",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 125u)
        },
        2u
    },
    {
        "wrong-ply ack is ignored",
        EV_RX("ACK 2", SESSION_ROUTE_ACK, SESSION_RX_LIVE, 1u),
        NO_OBSERVATIONS
    },
    {
        "retained matching ack is ignored",
        EV_RX("ACK 1 e4", SESSION_ROUTE_ACK, SESSION_RX_RETAINED, 1u),
        NO_OBSERVATIONS
    },
    {
        "live matching ack applies local move and result",
        EV_RX("ACK 1 e4", SESSION_ROUTE_CONTROL, SESSION_RX_LIVE, 1u),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_CONTROL),
            OBS_GAME(SESSION_DELIVER_LOCAL_MOVE, 0u, 1u, "e2e4"),
            OBS_GAME(SESSION_DELIVER_CONTROL_RESULT,
                     SESSION_CONTROL_ACCEPTED,
                     SESSION_REQUEST_MOVE,
                     "e4"),
            OBS_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        4u
    }
};

static const MqttTranscriptStep move_local_nack_steps[] = {
    GUEST_ACTIVE_PREFIX,
    {
        "local move sends",
        EV_LOCAL(SESSION_REQUEST_MOVE, 0u, "e2e4", SESSION_PHASE_ACTIVE),
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SEND("MOVE 1 e2e4", SESSION_ROUTE_GAME, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "move tx completion arms reply",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 125u)
        },
        2u
    },
    {
        "live matching nack reports rejection",
        EV_RX("NACK 1 ILLEGAL", SESSION_ROUTE_GAME, SESSION_RX_LIVE, 1u),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_CONTROL),
            OBS_GAME(SESSION_DELIVER_CONTROL_RESULT,
                     SESSION_CONTROL_REJECTED,
                     SESSION_REQUEST_MOVE,
                     "NACK 1 ILLEGAL"),
            OBS_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        3u
    }
};

static const MqttTranscriptStep move_remote_accept_steps[] = {
    GUEST_ACTIVE_PREFIX,
    {
        "retained remote move is ignored",
        EV_RX("MOVE 1 e2e4 e4", SESSION_ROUTE_GAME, SESSION_RX_RETAINED, 1u),
        NO_STATE_CHANGE
    },
    {
        "cross-topic meta move is inert",
        EV_RX("MOVE 1 e2e4 e4", SESSION_ROUTE_META, SESSION_RX_LIVE, 1u),
        NO_STATE_CHANGE
    },
    {
        "lateral remote move is delivered before ack",
        EV_RX("MOVE 1 e2e4 e4", SESSION_ROUTE_GAME, SESSION_RX_LIVE, 1u),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_GAME(SESSION_DELIVER_REMOTE_MOVE, 1u, 1u, "e2e4"),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 125u)
        },
        3u
    },
    {
        "accepted domain result sends app ack",
        EV_GAME_RESULT(SESSION_GAME_ACCEPTED, 1u, 0),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_CONTROL),
            OBS_SEND("ACK 1", SESSION_ROUTE_ACK, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        4u
    },
    {
        "ack tx completion rearms liveness",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        2u
    },
    {
        "accepted duplicate is reacked",
        EV_RX("MOVE 1 e2e4 e4", SESSION_ROUTE_GAME, SESSION_RX_LIVE, 1u),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SEND("ACK 1", SESSION_ROUTE_ACK, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "duplicate ack completion rearms liveness",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        2u
    }
};

static const MqttTranscriptStep move_remote_reject_steps[] = {
    GUEST_ACTIVE_PREFIX,
    {
        "live remote move is delivered",
        EV_RX("MOVE 1 e7e5", SESSION_ROUTE_GAME, SESSION_RX_LIVE, 1u),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_GAME(SESSION_DELIVER_REMOTE_MOVE, 1u, 1u, "e7e5"),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 125u)
        },
        3u
    },
    {
        "rejected domain result sends nack",
        EV_GAME_RESULT(SESSION_GAME_REJECTED, 1u, "ILLEGAL"),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_CONTROL),
            OBS_SEND_NACK_COMPAT("NACK 1", SESSION_ROUTE_ACK, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        4u
    },
    {
        "nack tx completion rearms liveness",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        2u
    },
    {
        "rejected duplicate is renacked",
        EV_RX("MOVE 1 e7e5", SESSION_ROUTE_GAME, SESSION_RX_LIVE, 1u),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SEND_NACK_COMPAT("NACK 1", SESSION_ROUTE_ACK, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "duplicate nack completion rearms liveness",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        2u
    }
};

static const MqttTranscriptStep move_sync_and_tx_fail_steps[] = {
    GUEST_ACTIVE_PREFIX,
    {
        "invalid local move is ignored",
        EV_LOCAL(SESSION_REQUEST_MOVE, 0u, "bad", SESSION_PHASE_ACTIVE),
        NO_STATE_CHANGE
    },
    {
        "out-of-sequence remote move is nacked",
        EV_RX("MOVE 2 e7e5", SESSION_ROUTE_GAME, SESSION_RX_LIVE, 1u),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SEND_NACK_ROUTE_COMPAT("NACK 2 SYNC",
                                       SESSION_ROUTE_ACK, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "sync nack completion rearms liveness",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        2u
    },
    {
        "local move sends after sync rejection",
        EV_LOCAL(SESSION_REQUEST_MOVE, 0u, "e2e4", SESSION_PHASE_ACTIVE),
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SEND("MOVE 1 e2e4", SESSION_ROUTE_GAME, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "failed move handoff sends retained offline cleanup",
        EV_TX_FAILED,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_SEND("F B 77", SESSION_ROUTE_PRESENCE, 1u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "offline cleanup completion ends failed move session",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_CLOSE(1u),
            OBS_SESSION(SESSION_CHANGED_ENDED)
        },
        3u
    }
};

static const MqttTranscriptStep move_promotion_steps[] = {
    GUEST_ACTIVE_PREFIX,
    PROMOTION_CYCLE(1u, "1", "e7e8q"),
    PROMOTION_CYCLE(2u, "2", "e2e1r"),
    PROMOTION_CYCLE(3u, "3", "e7e8b"),
    PROMOTION_CYCLE(4u, "4", "e2e1n")
};

#define RESTORE_CHUNK0 "uazam4iIiIgAAAAAAAAAAAAAAAAAAA"
#define RESTORE_CHUNK0_OVER "qqzam4iIiIgAAAAAAAAAAAAAAAAAAA"
#define RESTORE_CHUNK1_READY "AAEREREUI1YyR8_wAAAAEAAAAAOwG1"
#define RESTORE_CHUNK1_ACTIVE "AAEREREUI1YyR8_wIAAQEAAAAAOwF2"
#define RESTORE_CHUNK1_OVER "AAEREREUI1YyR8_wQAAwEAAAAAOwGX"
#define RESTORE_READY RESTORE_CHUNK0 RESTORE_CHUNK1_READY
#define RESTORE_ACTIVE RESTORE_CHUNK0 RESTORE_CHUNK1_ACTIVE
#define RESTORE_OVER RESTORE_CHUNK0_OVER RESTORE_CHUNK1_OVER
#define RESTORE_RS00 "RS00 " RESTORE_CHUNK0
#define RESTORE_RS00_OVER "RS00 " RESTORE_CHUNK0_OVER
#define RESTORE_RS01_READY "RS01 " RESTORE_CHUNK1_READY
#define RESTORE_RS01_ACTIVE "RS01 " RESTORE_CHUNK1_ACTIVE
#define RESTORE_RS01_OVER "RS01 " RESTORE_CHUNK1_OVER

static const char restore_phase_ready[] = {SESSION_PHASE_READY, '\0'};
static const char restore_phase_over[] = {SESSION_PHASE_OVER, '\0'};

static const MqttTranscriptStep restore_pre_peer_steps[] = {
    {"guest link up", EV_LINK_UP(1u), NO_OBSERVATIONS},
    {
        "pre-peer restore request is inert",
        EV_RX("RQ", SESSION_ROUTE_GAME, SESSION_RX_LIVE, 1u),
        NO_STATE_CHANGE
    }
};

static const MqttTranscriptStep restore_local_active_steps[] = {
    HOST_ACTIVE_PREFIX,
    {
        "local restore requests permission",
        EV_LOCAL(SESSION_REQUEST_RESTORE, 2u, RESTORE_ACTIVE,
                 SESSION_PHASE_ACTIVE),
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SEND("RQ", SESSION_ROUTE_GAME, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD,
                          SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "restore request completion arms reply",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 125u)
        },
        2u
    },
    {
        "restore permission sends first half",
        EV_RX("RY", SESSION_ROUTE_GAME, SESSION_RX_LIVE, 1u),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_CONTROL),
            OBS_SEND(RESTORE_RS00, SESSION_ROUTE_GAME, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD,
                          SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "first restore half completion sends second half",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_SEND(RESTORE_RS01_ACTIVE, SESSION_ROUTE_GAME, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD,
                          SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "second restore half completion arms acknowledgement reply",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 125u)
        },
        2u
    },
    {
        "restore acknowledgement applies active snapshot",
        EV_RX("RA", SESSION_ROUTE_GAME, SESSION_RX_LIVE, 1u),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_CONTROL),
            OBS_GAME(SESSION_DELIVER_RESTORE, 0u, 2u, RESTORE_ACTIVE),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        3u
    },
    {
        "restored ply continues with next move",
        EV_LOCAL(SESSION_REQUEST_MOVE, 0u, "d2d4", SESSION_PHASE_ACTIVE),
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SEND("MOVE 3 d2d4", SESSION_ROUTE_GAME, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD,
                          SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "post-restore move completion arms reply",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 125u)
        },
        2u
    },
    {
        "post-restore move ack applies next ply",
        EV_RX("ACK 3", SESSION_ROUTE_ACK, SESSION_RX_LIVE, 1u),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_CONTROL),
            OBS_GAME(SESSION_DELIVER_LOCAL_MOVE, 0u, 3u, "d2d4"),
            OBS_GAME(SESSION_DELIVER_CONTROL_RESULT,
                     SESSION_CONTROL_ACCEPTED,
                     SESSION_REQUEST_MOVE, 0),
            OBS_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        4u
    }
};

static const MqttTranscriptStep restore_remote_fresh_steps[] = {
    GUEST_ACTIVE_PREFIX,
    {
        "remote restore request asks application",
        EV_RX("RQ", SESSION_ROUTE_GAME, SESSION_RX_LIVE, 1u),
        {OBS_DECISION(SESSION_REQUEST_RESTORE, 0u)},
        1u
    },
    {
        "accepted restore request sends permission",
        EV_DECISION(SESSION_CONTROL_ACCEPTED),
        {
            OBS_SEND("RY", SESSION_ROUTE_GAME, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD,
                          SESSION_TX_GUARD_TICKS)
        },
        2u
    },
    {
        "restore permission completion starts receive",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 125u)
        },
        3u
    },
    {
        "first restore half is cached",
        EV_RX(RESTORE_RS00, SESSION_ROUTE_GAME, SESSION_RX_LIVE, 1u),
        {OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 125u)},
        1u
    },
    {
        "second restore half delivers ready snapshot",
        EV_RX(RESTORE_RS01_READY, SESSION_ROUTE_GAME, SESSION_RX_LIVE, 1u),
        {
            OBS_GAME(SESSION_DELIVER_RESTORE, 2u, 0u, RESTORE_READY),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 125u)
        },
        2u
    },
    {
        "successful restore apply sends acknowledgement",
        EV_GAME_RESULT(SESSION_CONTROL_ACCEPTED, 1u, restore_phase_ready),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_CONTROL),
            OBS_SEND("RA", SESSION_ROUTE_GAME, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD,
                          SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "restore acknowledgement completion rearms liveness",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        2u
    },
    {
        "duplicate final half repeats acknowledgement",
        EV_RX(RESTORE_RS01_READY, SESSION_ROUTE_GAME, SESSION_RX_LIVE, 1u),
        {
            OBS_SEND("RA", SESSION_ROUTE_GAME, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD,
                          SESSION_TX_GUARD_TICKS)
        },
        2u
    },
    {
        "duplicate acknowledgement completion rearms liveness",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        2u
    },
    {
        "over restore request asks application",
        EV_RX("RQ", SESSION_ROUTE_GAME, SESSION_RX_LIVE, 1u),
        {OBS_DECISION(SESSION_REQUEST_RESTORE, 0u)},
        1u
    },
    {
        "accepted over restore sends permission",
        EV_DECISION(SESSION_CONTROL_ACCEPTED),
        {
            OBS_SEND("RY", SESSION_ROUTE_GAME, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD,
                          SESSION_TX_GUARD_TICKS)
        },
        2u
    },
    {
        "over restore permission completion starts receive",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 125u)
        },
        3u
    },
    {
        "over restore first half is cached",
        EV_RX(RESTORE_RS00_OVER, SESSION_ROUTE_GAME, SESSION_RX_LIVE, 1u),
        {OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 125u)},
        1u
    },
    {
        "over restore second half delivers snapshot",
        EV_RX(RESTORE_RS01_OVER, SESSION_ROUTE_GAME, SESSION_RX_LIVE, 1u),
        {
            OBS_GAME(SESSION_DELIVER_RESTORE, 4u, 0u, RESTORE_OVER),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 125u)
        },
        2u
    },
    {
        "successful over restore apply sends acknowledgement",
        EV_GAME_RESULT(SESSION_CONTROL_ACCEPTED, 4u, restore_phase_over),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_CONTROL),
            OBS_SEND("RA", SESSION_ROUTE_GAME, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD,
                          SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "over restore acknowledgement rearms liveness",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        2u
    },
    {
        "restored over phase rejects draw",
        EV_RX("DRAW", SESSION_ROUTE_CONTROL, SESSION_RX_LIVE, 1u),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SEND_NACK_ROUTE_COMPAT("NACK DRAW",
                                       SESSION_ROUTE_CONTROL, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD,
                          SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "over draw refusal completion rearms liveness",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        2u
    },
    {
        "idle over guest accepts a fresh start",
        EV_RX("GAME START", SESSION_ROUTE_GAME, SESSION_RX_LIVE, 1u),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SEND("ACK GAME START", SESSION_ROUTE_CONTROL, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD,
                          SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "over start acknowledgement starts a fresh game",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_SESSION(SESSION_CHANGED_STARTED),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        3u
    }
};

static const MqttTranscriptStep restore_cancel_early_steps[] = {
    HOST_ACTIVE_PREFIX,
    {
        "local restore requests permission",
        EV_LOCAL(SESSION_REQUEST_RESTORE, 2u, RESTORE_ACTIVE,
                 SESSION_PHASE_ACTIVE),
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SEND("RQ", SESSION_ROUTE_GAME, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD,
                          SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "restore request completion arms reply",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 125u)
        },
        2u
    },
    {
        "early local cancellation sends refusal",
        EV_LOCAL(SESSION_REQUEST_RESTORE, 0u, 0, SESSION_PHASE_ACTIVE),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_CONTROL),
            OBS_SEND("RN", SESSION_ROUTE_GAME, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD,
                          SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "cancellation completion reports rejection",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_GAME(SESSION_DELIVER_CONTROL_RESULT,
                     SESSION_CONTROL_REJECTED,
                     SESSION_REQUEST_RESTORE, "RN"),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        3u
    },
    {
        "late permission after cancellation is inert",
        EV_RX("RY", SESSION_ROUTE_GAME, SESSION_RX_LIVE, 1u),
        NO_OBSERVATIONS
    }
};

#define RESTORE_RQ_RETRY \
    { \
        "restore permission timeout retries request", \
        EV_TIMEOUT(SESSION_TIMER_CONTROL), \
        { \
            OBS_SEND("RQ", SESSION_ROUTE_GAME, 0u, 1u), \
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, \
                          SESSION_TX_GUARD_TICKS) \
        }, \
        2u \
    }, \
    { \
        "restore request retry rearms reply timer", \
        EV_TX_OK, \
        { \
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD), \
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 125u) \
        }, \
        2u \
    }

static const MqttTranscriptStep restore_wait_ry_retry_limit_steps[] = {
    HOST_ACTIVE_PREFIX,
    {
        "local restore requests permission",
        EV_LOCAL(SESSION_REQUEST_RESTORE, 2u, RESTORE_ACTIVE,
                 SESSION_PHASE_ACTIVE),
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SEND("RQ", SESSION_ROUTE_GAME, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD,
                          SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "restore request completion arms reply",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 125u)
        },
        2u
    },
    RESTORE_RQ_RETRY,
    RESTORE_RQ_RETRY,
    RESTORE_RQ_RETRY,
    RESTORE_RQ_RETRY,
    RESTORE_RQ_RETRY,
    {
        "restore permission exhaustion cancels without disconnecting",
        EV_TIMEOUT(SESSION_TIMER_CONTROL),
        {
            OBS_SEND("RN", SESSION_ROUTE_GAME, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD,
                          SESSION_TX_GUARD_TICKS)
        },
        2u
    },
    {
        "restore cancellation completion keeps session live",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_GAME(SESSION_DELIVER_CONTROL_RESULT,
                     SESSION_CONTROL_REJECTED,
                     SESSION_REQUEST_RESTORE, "RN"),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        3u
    }
};

static const MqttTranscriptStep restore_host_reject_steps[] = {
    HOST_ACTIVE_PREFIX,
    {
        "host rejects remote restore request",
        EV_RX("RQ", SESSION_ROUTE_GAME, SESSION_RX_LIVE, 1u),
        {
            OBS_SEND("RN", SESSION_ROUTE_GAME, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD,
                          SESSION_TX_GUARD_TICKS)
        },
        2u
    },
    {
        "host refusal completion rearms liveness",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        2u
    }
};

#define GUEST_READY_RESTORE_REJECT_FAILED_PREFIX \
    GUEST_READY_PREFIX, \
    { \
        "remote restore request asks application", \
        EV_RX("RQ", SESSION_ROUTE_GAME, SESSION_RX_LIVE, 1u), \
        {OBS_DECISION(SESSION_REQUEST_RESTORE, 0u)}, \
        1u \
    }, \
    { \
        "rejected restore request sends refusal", \
        EV_DECISION(SESSION_CONTROL_REJECTED), \
        { \
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_LIVENESS), \
            OBS_SEND("RN", SESSION_ROUTE_GAME, 0u, 1u), \
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, \
                          SESSION_TX_GUARD_TICKS) \
        }, \
        3u \
    }, \
    { \
        "failed refusal publishes offline cleanup", \
        EV_TX_FAILED, \
        { \
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD), \
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_LIVENESS), \
            OBS_SEND("F B 77", SESSION_ROUTE_PRESENCE, 1u, 1u), \
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, \
                          SESSION_TX_GUARD_TICKS) \
        }, \
        4u \
    }

#define GUEST_READY_RESTORE_REJECT_CLOSED(result) \
    { \
        "offline cleanup closes failed refusal", \
        result, \
        { \
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD), \
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_CONTROL), \
            OBS_CLOSE(1u), \
            OBS_SESSION(SESSION_CHANGED_ENDED) \
        }, \
        4u \
    }

static const MqttTranscriptStep restore_reject_offline_ok_steps[] = {
    GUEST_READY_RESTORE_REJECT_FAILED_PREFIX,
    GUEST_READY_RESTORE_REJECT_CLOSED(EV_TX_OK)
};

static const MqttTranscriptStep restore_reject_offline_failed_steps[] = {
    GUEST_READY_RESTORE_REJECT_FAILED_PREFIX,
    GUEST_READY_RESTORE_REJECT_CLOSED(EV_TX_FAILED)
};

static const MqttTranscriptStep control_chat_steps[] = {
    GUEST_ACTIVE_PREFIX,
    {
        "local chat sends",
        EV_LOCAL(SESSION_REQUEST_CHAT, 0u, "hello", SESSION_PHASE_ACTIVE),
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SEND("CHAT hello", SESSION_ROUTE_GAME, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "remote chat may arrive during local tx",
        EV_RX("CHAT peer", SESSION_ROUTE_GAME, SESSION_RX_LIVE, 1u),
        {OBS_GAME(SESSION_DELIVER_CHAT, 0u, SESSION_CHAT_REMOTE, "peer")},
        1u
    },
    {
        "chat handoff displays local text",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_GAME(SESSION_DELIVER_CHAT, 0u, SESSION_CHAT_LOCAL, "hello"),
            OBS_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        3u
    },
    {
        "retained chat is ignored",
        EV_RX("CHAT stale", SESSION_ROUTE_GAME, SESSION_RX_RETAINED, 1u),
        NO_OBSERVATIONS
    },
    {
        "43-byte chat body is rejected atomically",
        EV_RX("CHAT " CHAT_MAX_SAMPLE "X",
              SESSION_ROUTE_GAME, SESSION_RX_LIVE, 1u),
        NO_STATE_CHANGE
    },
    {
        "42-byte chat body is delivered intact",
        EV_RX("CHAT " CHAT_MAX_SAMPLE,
              SESSION_ROUTE_GAME, SESSION_RX_LIVE, 1u),
        {
            OBS_GAME(SESSION_DELIVER_CHAT, 0u,
                     SESSION_CHAT_REMOTE, CHAT_MAX_SAMPLE),
            OBS_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        2u
    }
};

static const MqttTranscriptStep control_local_reset_steps[] = {
    GUEST_ACTIVE_PREFIX,
    {
        "local reset sends",
        EV_LOCAL(SESSION_REQUEST_RESET, 0u, 0, SESSION_PHASE_ACTIVE),
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SEND("RESET", SESSION_ROUTE_GAME, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "reset handoff arms reply",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 125u)
        },
        2u
    },
    {
        "reset timeout retransmits",
        EV_TIMEOUT(SESSION_TIMER_CONTROL),
        {
            OBS_SEND("RESET", SESSION_ROUTE_GAME, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        2u
    },
    {
        "reset retry handoff rearms reply",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 125u)
        },
        2u
    },
    {
        "reset nack is typed",
        EV_RX("NACK RESET DECLINED", SESSION_ROUTE_GAME,
              SESSION_RX_LIVE, 1u),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_CONTROL),
            OBS_GAME(SESSION_DELIVER_CONTROL_RESULT,
                     SESSION_CONTROL_REJECTED,
                     SESSION_REQUEST_RESET,
                     "NACK RESET DECLINED"),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        3u
    },
    {
        "second local reset sends",
        EV_LOCAL(SESSION_REQUEST_RESET, 0u, 0, SESSION_PHASE_ACTIVE),
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SEND("RESET", SESSION_ROUTE_GAME, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "second reset handoff arms reply",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 125u)
        },
        2u
    },
    {
        "reset ack starts fresh board",
        EV_RX("ACK RESET", SESSION_ROUTE_ACK, SESSION_RX_LIVE, 1u),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_CONTROL),
            OBS_GAME(SESSION_DELIVER_CONTROL_RESULT,
                     SESSION_CONTROL_ACCEPTED,
                     SESSION_REQUEST_RESET, 0),
            OBS_SESSION(SESSION_CHANGED_STARTED),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        4u
    }
};

static const MqttTranscriptStep control_remote_reset_steps[] = {
    GUEST_ACTIVE_PREFIX,
    {
        "retained reset is ignored",
        EV_RX("RESET", SESSION_ROUTE_CONTROL, SESSION_RX_RETAINED, 1u),
        NO_OBSERVATIONS
    },
    {
        "remote reset asks once",
        EV_RX("RESET", SESSION_ROUTE_CONTROL, SESSION_RX_LIVE, 1u),
        {
            OBS_DECISION(SESSION_REQUEST_RESET, 0u),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        2u
    },
    {
        "duplicate reset while prompt open is ignored",
        EV_RX("RESET", SESSION_ROUTE_CONTROL, SESSION_RX_LIVE, 1u),
        {OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)},
        1u
    },
    {
        "rejected reset sends nack",
        EV_DECISION(SESSION_DECISION_REJECT),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SEND("NACK RESET", SESSION_ROUTE_GAME, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "reset nack handoff clears latch",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        2u
    },
    {
        "rejected reset prompts again",
        EV_RX("RESET", SESSION_ROUTE_CONTROL, SESSION_RX_LIVE, 1u),
        {
            OBS_DECISION(SESSION_REQUEST_RESET, 0u),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        2u
    },
    {
        "accepted reset sends ack",
        EV_DECISION(SESSION_DECISION_ACCEPT),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SEND("ACK RESET", SESSION_ROUTE_ACK, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "reset ack handoff applies remote control",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_GAME(SESSION_DELIVER_CONTROL, 0u, SESSION_REQUEST_RESET, 0),
            OBS_SESSION(SESSION_CHANGED_STARTED),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        4u
    },
    {
        "accepted reset does not retain latch",
        EV_RX("RESET", SESSION_ROUTE_CONTROL, SESSION_RX_LIVE, 1u),
        {
            OBS_DECISION(SESSION_REQUEST_RESET, 0u),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        2u
    }
};

static const MqttTranscriptStep control_local_draw_crossed_steps[] = {
    GUEST_ACTIVE_PREFIX,
    {
        "local draw sends",
        EV_LOCAL(SESSION_REQUEST_DRAW, 0u, 0, SESSION_PHASE_ACTIVE),
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SEND("DRAW", SESSION_ROUTE_GAME, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "draw handoff arms reply",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 125u)
        },
        2u
    },
    {
        "crossed draw is acked",
        EV_RX("DRAW", SESSION_ROUTE_CONTROL, SESSION_RX_LIVE, 1u),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_CONTROL),
            OBS_SEND("ACK DRAW", SESSION_ROUTE_ACK, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "crossed draw handoff advances to reset",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_GAME(SESSION_DELIVER_CONTROL_RESULT,
                     SESSION_CONTROL_ACCEPTED,
                     SESSION_REQUEST_DRAW, 0),
            OBS_SEND("RESET", SESSION_ROUTE_GAME, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        4u
    },
    {
        "crossed draw reset handoff",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 125u),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        3u
    },
    {
        "crossed reset is acked after draw",
        EV_RX("RESET", SESSION_ROUTE_CONTROL, SESSION_RX_LIVE, 1u),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_CONTROL),
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SEND("ACK RESET", SESSION_ROUTE_ACK, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        4u
    },
    {
        "crossed reset handoff starts board",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_GAME(SESSION_DELIVER_CONTROL_RESULT,
                     SESSION_CONTROL_ACCEPTED,
                     SESSION_REQUEST_RESET, 0),
            OBS_SESSION(SESSION_CHANGED_STARTED),
            OBS_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        4u
    },
    {
        "local draw can be rejected",
        EV_LOCAL(SESSION_REQUEST_DRAW, 0u, 0, SESSION_PHASE_ACTIVE),
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SEND("DRAW", SESSION_ROUTE_GAME, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "rejected draw handoff",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 125u)
        },
        2u
    },
    {
        "draw nack is typed",
        EV_RX("NACK DRAW", SESSION_ROUTE_GAME, SESSION_RX_LIVE, 1u),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_CONTROL),
            OBS_GAME(SESSION_DELIVER_CONTROL_RESULT,
                     SESSION_CONTROL_REJECTED,
                     SESSION_REQUEST_DRAW, "NACK DRAW"),
            OBS_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        3u
    }
};

static const MqttTranscriptStep control_remote_draw_steps[] = {
    GUEST_ACTIVE_PREFIX,
    {
        "remote draw asks once",
        EV_RX("DRAW", SESSION_ROUTE_CONTROL, SESSION_RX_LIVE, 1u),
        {
            OBS_DECISION(SESSION_REQUEST_DRAW, 0u),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        2u
    },
    {
        "duplicate draw while prompt open is ignored",
        EV_RX("DRAW", SESSION_ROUTE_CONTROL, SESSION_RX_LIVE, 1u),
        {OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)},
        1u
    },
    {
        "rejected draw sends nack",
        EV_DECISION(SESSION_DECISION_REJECT),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SEND("NACK DRAW", SESSION_ROUTE_GAME, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "draw nack handoff clears latch",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        2u
    },
    {
        "rejected draw prompts again",
        EV_RX("DRAW", SESSION_ROUTE_CONTROL, SESSION_RX_LIVE, 1u),
        {
            OBS_DECISION(SESSION_REQUEST_DRAW, 0u),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        2u
    },
    {
        "accepted draw sends ack",
        EV_DECISION(SESSION_DECISION_ACCEPT),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SEND("ACK DRAW", SESSION_ROUTE_ACK, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "draw ack handoff enters rematch reset",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_GAME(SESSION_DELIVER_CONTROL, 0u, SESSION_REQUEST_DRAW, 0),
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 125u)
        },
        4u
    },
    {
        "accepted draw duplicate is reacked",
        EV_RX("DRAW", SESSION_ROUTE_CONTROL, SESSION_RX_LIVE, 1u),
        {
            OBS_SEND("ACK DRAW", SESSION_ROUTE_ACK, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        2u
    },
    {
        "duplicate draw ack preserves reset wait",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        2u
    },
    {
        "peer reset completes accepted draw",
        EV_RX("RESET", SESSION_ROUTE_CONTROL, SESSION_RX_LIVE, 1u),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_CONTROL),
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SEND("ACK RESET", SESSION_ROUTE_ACK, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        4u
    },
    {
        "rematch reset handoff starts board",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_GAME(SESSION_DELIVER_CONTROL, 0u, SESSION_REQUEST_RESET, 0),
            OBS_SESSION(SESSION_CHANGED_STARTED),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        4u
    }
};

static const MqttTranscriptStep control_local_resign_steps[] = {
    GUEST_ACTIVE_PREFIX,
    {
        "local resign sends",
        EV_LOCAL(SESSION_REQUEST_RESIGN, 0u, 0, SESSION_PHASE_ACTIVE),
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SEND("RESIGN", SESSION_ROUTE_GAME, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "resign handoff ends local game and arms reply",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_GAME(SESSION_DELIVER_CONTROL, 0u, SESSION_REQUEST_RESIGN, 0),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 125u)
        },
        3u
    },
    {
        "chat remains available while resign is pending",
        EV_LOCAL(SESSION_REQUEST_CHAT, 0u, "hello", SESSION_PHASE_OVER),
        {
            OBS_SEND("CHAT hello", SESSION_ROUTE_GAME, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        2u
    },
    {
        "chat handoff preserves pending resign",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_GAME(SESSION_DELIVER_CHAT, 0u, SESSION_CHAT_LOCAL, "hello")
        },
        2u
    },
    {
        "resign timeout retransmits",
        EV_TIMEOUT(SESSION_TIMER_CONTROL),
        {
            OBS_SEND("RESIGN", SESSION_ROUTE_GAME, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        2u
    },
    {
        "resign retry handoff rearms reply",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 125u)
        },
        2u
    },
    {
        "resign app ack starts automatic reset",
        EV_RX("ACK RESIGN", SESSION_ROUTE_ACK, SESSION_RX_LIVE, 1u),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_CONTROL),
            OBS_GAME(SESSION_DELIVER_CONTROL_RESULT,
                     SESSION_CONTROL_ACCEPTED,
                     SESSION_REQUEST_RESIGN, 0),
            OBS_SEND("RESET", SESSION_ROUTE_GAME, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        4u
    },
    {
        "automatic reset handoff arms reply",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 125u),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        3u
    },
    {
        "automatic reset ack starts new game",
        EV_RX("ACK RESET", SESSION_ROUTE_ACK, SESSION_RX_LIVE, 1u),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_CONTROL),
            OBS_GAME(SESSION_DELIVER_CONTROL_RESULT,
                     SESSION_CONTROL_ACCEPTED,
                     SESSION_REQUEST_RESET, 0),
            OBS_SESSION(SESSION_CHANGED_STARTED),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        4u
    }
};

static const MqttTranscriptStep control_remote_resign_steps[] = {
    GUEST_ACTIVE_PREFIX,
    {
        "remote resign is acked before apply",
        EV_RX("RESIGN", SESSION_ROUTE_CONTROL, SESSION_RX_LIVE, 1u),
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SEND("ACK RESIGN", SESSION_ROUTE_ACK, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "remote resign handoff applies once",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 250u),
            OBS_GAME(SESSION_DELIVER_CONTROL, 0u, SESSION_REQUEST_RESIGN, 0),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        4u
    },
    {
        "remote resign duplicate is reacked",
        EV_RX("RESIGN", SESSION_ROUTE_CONTROL, SESSION_RX_LIVE, 1u),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SEND("ACK RESIGN", SESSION_ROUTE_ACK, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "duplicate resign handoff does not reapply",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        2u
    },
    {
        "post-resign reset is accepted without a decision",
        EV_RX("RESET", SESSION_ROUTE_CONTROL, SESSION_RX_LIVE, 1u),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SEND("ACK RESET", SESSION_ROUTE_ACK, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "automatic reset ack handoff starts board",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_GAME(SESSION_DELIVER_CONTROL, 0u, SESSION_REQUEST_RESET, 0),
            OBS_SESSION(SESSION_CHANGED_STARTED),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        4u
    }
};

static const MqttTranscriptStep control_crossed_resign_steps[] = {
    GUEST_ACTIVE_PREFIX,
    {
        "crossed local resign sends",
        EV_LOCAL(SESSION_REQUEST_RESIGN, 0u, 0, SESSION_PHASE_ACTIVE),
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SEND("RESIGN", SESSION_ROUTE_GAME, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "crossed local resign handoff",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_GAME(SESSION_DELIVER_CONTROL, 0u, SESSION_REQUEST_RESIGN, 0),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 125u)
        },
        3u
    },
    {
        "peer resign clears local retry",
        EV_RX("RESIGN", SESSION_ROUTE_CONTROL, SESSION_RX_LIVE, 1u),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_CONTROL),
            OBS_SEND("ACK RESIGN", SESSION_ROUTE_ACK, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "crossed resign guest waits for host reset",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_GAME(SESSION_DELIVER_CONTROL_RESULT,
                     SESSION_CONTROL_ACCEPTED,
                     SESSION_REQUEST_RESIGN, 0),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        3u
    },
    {
        "crossed guest accepts host reset without a decision",
        EV_RX("RESET", SESSION_ROUTE_CONTROL, SESSION_RX_LIVE, 1u),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SEND("ACK RESET", SESSION_ROUTE_ACK, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "crossed reset ack handoff starts guest board",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_GAME(SESSION_DELIVER_CONTROL, 0u, SESSION_REQUEST_RESET, 0),
            OBS_SESSION(SESSION_CHANGED_STARTED),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        4u
    }
};

static const MqttTranscriptStep control_crossed_resign_host_steps[] = {
    HOST_ACTIVE_PREFIX,
    {
        "crossed host resign sends",
        EV_LOCAL(SESSION_REQUEST_RESIGN, 0u, 0, SESSION_PHASE_ACTIVE),
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SEND("RESIGN", SESSION_ROUTE_GAME, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "crossed host resign handoff",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_GAME(SESSION_DELIVER_CONTROL, 0u, SESSION_REQUEST_RESIGN, 0),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 125u)
        },
        3u
    },
    {
        "peer resign clears host retry",
        EV_RX("RESIGN", SESSION_ROUTE_CONTROL, SESSION_RX_LIVE, 1u),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_CONTROL),
            OBS_SEND("ACK RESIGN", SESSION_ROUTE_ACK, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "crossed resign host starts automatic reset",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_GAME(SESSION_DELIVER_CONTROL_RESULT,
                     SESSION_CONTROL_ACCEPTED,
                     SESSION_REQUEST_RESIGN, 0),
            OBS_SEND("RESET", SESSION_ROUTE_GAME, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        4u
    },
    {
        "crossed host reset handoff arms reply",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 125u),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        3u
    },
    {
        "crossed host reset ack starts new game",
        EV_RX("ACK RESET", SESSION_ROUTE_ACK, SESSION_RX_LIVE, 1u),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_CONTROL),
            OBS_GAME(SESSION_DELIVER_CONTROL_RESULT,
                     SESSION_CONTROL_ACCEPTED,
                     SESSION_REQUEST_RESET, 0),
            OBS_SESSION(SESSION_CHANGED_STARTED),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        4u
    }
};

static const MqttTranscriptStep control_local_takeback_steps[] = {
    GUEST_ACTIVE_ONE_PLY_PRIVATE_PREFIX,
    {
        "local takeback sends current ply",
        EV_LOCAL(SESSION_REQUEST_TAKEBACK, 1u, 0, SESSION_PHASE_ACTIVE),
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SEND("TAKEBACK 1", SESSION_ROUTE_GAME, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "takeback handoff arms reply",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 125u)
        },
        2u
    },
    {
        "takeback prompt expiry retransmits request",
        EV_TIMEOUT(SESSION_TIMER_CONTROL),
        {
            OBS_SEND("TAKEBACK 1", SESSION_ROUTE_GAME, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        2u
    },
    {
        "takeback retry handoff rearms reply",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 125u)
        },
        2u
    },
    {
        "takeback nack is typed",
        EV_RX("NACK 1 NO", SESSION_ROUTE_ACK, SESSION_RX_LIVE, 1u),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_CONTROL),
            OBS_GAME(SESSION_DELIVER_CONTROL_RESULT,
                     SESSION_CONTROL_REJECTED,
                     SESSION_REQUEST_TAKEBACK, "NACK 1 NO"),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        3u
    },
    {
        "second local takeback sends",
        EV_LOCAL(SESSION_REQUEST_TAKEBACK, 1u, 0, SESSION_PHASE_ACTIVE),
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SEND("TAKEBACK 1", SESSION_ROUTE_GAME, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "second takeback handoff arms reply",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 125u)
        },
        2u
    },
    {
        "takeback ack requests local apply",
        EV_RX("ACK 1", SESSION_ROUTE_ACK, SESSION_RX_LIVE, 1u),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_CONTROL),
            OBS_GAME(SESSION_DELIVER_TAKEBACK, 1u, 1u, 0),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 250u),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 125u)
        },
        4u
    },
    {
        "wrong-value takeback result is ignored",
        EV_GAME_RESULT(SESSION_GAME_ACCEPTED, 2u, 0),
        NO_STATE_CHANGE
    },
    {
        "local takeback applies after domain result",
        EV_GAME_RESULT(SESSION_GAME_ACCEPTED, 1u, 0),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_CONTROL),
            OBS_GAME(SESSION_DELIVER_CONTROL_RESULT,
                     SESSION_CONTROL_ACCEPTED,
                     SESSION_REQUEST_TAKEBACK, 0),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        3u
    }
};

static const MqttTranscriptStep control_remote_takeback_steps[] = {
    GUEST_ACTIVE_REMOTE_ONE_PLY_PREFIX,
    {
        "wrong-ply takeback is bare nacked",
        EV_RX("TAKEBACK 2", SESSION_ROUTE_CONTROL, SESSION_RX_LIVE, 1u),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SEND_NACK_ROUTE_COMPAT("NACK 2", SESSION_ROUTE_ACK, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "stale nack handoff result is ignored",
        EV_TX_OK_ID(0xffu),
        NO_STATE_CHANGE
    },
    {
        "wrong-ply nack handoff",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        2u
    },
    {
        "remote takeback asks once",
        EV_RX("TAKEBACK 1", SESSION_ROUTE_CONTROL, SESSION_RX_LIVE, 1u),
        {
            OBS_DECISION(SESSION_REQUEST_TAKEBACK, 1u),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        2u
    },
    {
        "duplicate takeback while prompt open is ignored",
        EV_RX("TAKEBACK 1", SESSION_ROUTE_CONTROL, SESSION_RX_LIVE, 1u),
        {OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)},
        1u
    },
    {
        "user rejection sends bare nack",
        EV_DECISION(SESSION_DECISION_REJECT),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SEND_NACK_ROUTE_COMPAT("NACK 1", SESSION_ROUTE_ACK, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "rejected takeback handoff clears latch",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        2u
    },
    {
        "rejected takeback prompts again",
        EV_RX("TAKEBACK 1", SESSION_ROUTE_CONTROL, SESSION_RX_LIVE, 1u),
        {
            OBS_DECISION(SESSION_REQUEST_TAKEBACK, 1u),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        2u
    },
    {
        "stale takeback decision is ignored",
        EV_DECISION_ID(SESSION_DECISION_ACCEPT, 0xffu),
        NO_STATE_CHANGE
    },
    {
        "accepted decision requests domain apply",
        EV_DECISION(SESSION_DECISION_ACCEPT),
        {
            OBS_GAME(SESSION_DELIVER_TAKEBACK, 3u, 1u, 0),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 125u)
        },
        2u
    },
    {
        "stale takeback domain result is ignored",
        EV_GAME_RESULT_ID(SESSION_GAME_ACCEPTED, 1u, 0, 0xffu),
        NO_STATE_CHANGE
    },
    {
        "accepted domain apply sends ack",
        EV_GAME_RESULT(SESSION_GAME_ACCEPTED, 1u, 0),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_CONTROL),
            OBS_SEND("ACK 1", SESSION_ROUTE_ACK, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        4u
    },
    {
        "takeback ack handoff rearms liveness",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        2u
    },
    {
        "accepted takeback duplicate is reacked",
        EV_RX("TAKEBACK 1", SESSION_ROUTE_CONTROL, SESSION_RX_LIVE, 1u),
        {
            OBS_SEND("ACK 1", SESSION_ROUTE_ACK, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        2u
    },
    {
        "duplicate takeback ack handoff",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        2u
    },
    {
        "different ply under accepted latch is nacked",
        EV_RX("TAKEBACK 2", SESSION_ROUTE_CONTROL, SESSION_RX_LIVE, 1u),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SEND_NACK_ROUTE_COMPAT("NACK 2", SESSION_ROUTE_ACK, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    }
};

static const MqttTranscriptStep control_busy_crossing_steps[] = {
    GUEST_ACTIVE_PREFIX,
    {
        "pending move sends",
        EV_LOCAL(SESSION_REQUEST_MOVE, 0u, "e2e4", SESSION_PHASE_ACTIVE),
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SEND("MOVE 1 e2e4", SESSION_ROUTE_GAME, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "pending move handoff arms reply",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 125u)
        },
        2u
    },
    {
        "reset cannot overwrite pending move",
        EV_RX("RESET", SESSION_ROUTE_CONTROL, SESSION_RX_LIVE, 1u),
        {
            OBS_SEND_NACK_ROUTE_COMPAT("NACK RESET BUSY",
                                       SESSION_ROUTE_CONTROL, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        2u
    },
    {
        "busy reset handoff preserves move",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        2u
    },
    {
        "draw cannot overwrite pending move",
        EV_RX("DRAW", SESSION_ROUTE_CONTROL, SESSION_RX_LIVE, 1u),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SEND_NACK_ROUTE_COMPAT("NACK DRAW",
                                       SESSION_ROUTE_CONTROL, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "busy draw handoff preserves move",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        2u
    },
    {
        "takeback cannot overwrite pending move",
        EV_RX("TAKEBACK 1", SESSION_ROUTE_CONTROL, SESSION_RX_LIVE, 1u),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SEND_NACK_ROUTE_COMPAT("NACK 1",
                                       SESSION_ROUTE_ACK, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "busy takeback handoff preserves move",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        2u
    },
    {
        "local resign preempts pending move",
        EV_LOCAL(SESSION_REQUEST_RESIGN, 0u, 0, SESSION_PHASE_ACTIVE),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_CONTROL),
            OBS_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SEND("RESIGN", SESSION_ROUTE_GAME, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        4u
    },
    {
        "resign handoff ends local game",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_GAME(SESSION_DELIVER_CONTROL, 0u, SESSION_REQUEST_RESIGN, 0),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 125u)
        },
        3u
    },
    {
        "preempted move ack is inert",
        EV_RX("ACK 1", SESSION_ROUTE_ACK, SESSION_RX_LIVE, 1u),
        NO_STATE_CHANGE
    },
    {
        "preempted move nack is inert",
        EV_RX("NACK 1 STALE", SESSION_ROUTE_ACK, SESSION_RX_LIVE, 1u),
        NO_STATE_CHANGE
    },
    {
        "resign ack starts reset after move preemption",
        EV_RX("ACK RESIGN", SESSION_ROUTE_ACK, SESSION_RX_LIVE, 1u),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_CONTROL),
            OBS_GAME(SESSION_DELIVER_CONTROL_RESULT,
                     SESSION_CONTROL_ACCEPTED,
                     SESSION_REQUEST_RESIGN, 0),
            OBS_SEND("RESET", SESSION_ROUTE_GAME, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        4u
    },
    {
        "preempted resign reset handoff arms reply",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 125u),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        3u
    },
    {
        "preempted resign reset ack starts game",
        EV_RX("ACK RESET", SESSION_ROUTE_ACK, SESSION_RX_LIVE, 1u),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_CONTROL),
            OBS_GAME(SESSION_DELIVER_CONTROL_RESULT,
                     SESSION_CONTROL_ACCEPTED,
                     SESSION_REQUEST_RESET, 0),
            OBS_SESSION(SESSION_CHANGED_STARTED),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        4u
    }
};

static const MqttTranscriptStep liveness_idle_ack_steps[] = {
    GUEST_ACTIVE_PREFIX,
    {
        "idle timeout sends app ping",
        EV_TIMEOUT(SESSION_TIMER_LIVENESS),
        {
            OBS_SEND("PING", SESSION_ROUTE_CONTROL, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        2u
    },
    {
        "ping handoff arms remaining peer deadline",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 350u)
        },
        2u
    },
    {
        "retained ack ping is ignored",
        EV_RX("ACK PING", SESSION_ROUTE_ACK, SESSION_RX_RETAINED, 1u),
        NO_OBSERVATIONS
    },
    {
        "broker pingresp token is not peer liveness",
        EV_RX("PINGRESP", SESSION_ROUTE_DEFAULT, SESSION_RX_LIVE, 1u),
        NO_STATE_CHANGE
    },
    {
        "live ack ping clears outstanding probe",
        EV_RX("ACK PING", SESSION_ROUTE_GAME, SESSION_RX_LIVE, 1u),
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        2u
    },
    {
        "stale live ack ping is ignored",
        EV_RX("ACK PING", SESSION_ROUTE_ACK, SESSION_RX_LIVE, 1u),
        NO_OBSERVATIONS
    },
    {
        "next idle interval sends next ping",
        EV_TIMEOUT(SESSION_TIMER_LIVENESS),
        {
            OBS_SEND("PING", SESSION_ROUTE_CONTROL, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        2u
    }
};

static const MqttTranscriptStep liveness_peer_timeout_steps[] = {
    GUEST_ACTIVE_PREFIX,
    {
        "idle timeout sends ping",
        EV_TIMEOUT(SESSION_TIMER_LIVENESS),
        {
            OBS_SEND("PING", SESSION_ROUTE_CONTROL, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        2u
    },
    {
        "ping handoff arms peer deadline",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_TIMER_SET(SESSION_TIMER_LIVENESS, 350u)
        },
        2u
    },
    {
        "peer deadline ends session without broker close",
        EV_TIMEOUT(SESSION_TIMER_LIVENESS),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SESSION(SESSION_CHANGED_ENDED)
        },
        2u
    }
};

static const MqttTranscriptStep liveness_host_peer_timeout_steps[] = {
    HOST_ACTIVE_PREFIX,
    {
        "host idle timeout sends ping",
        EV_TIMEOUT(SESSION_TIMER_LIVENESS),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SEND("PING", SESSION_ROUTE_CONTROL, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "host ping handoff arms peer deadline",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 350u)
        },
        2u
    },
    {
        "host peer deadline releases retained peer seat",
        EV_TIMEOUT(SESSION_TIMER_LIVENESS),
        {
            OBS_SEND("F B 77", SESSION_ROUTE_PRESENCE_PEER, 1u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        2u
    },
    {
        "peer release handoff ends logical session",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_SESSION(SESSION_CHANGED_ENDED)
        },
        2u
    }
};

static const MqttTranscriptStep liveness_host_peer_release_fail_steps[] = {
    HOST_ACTIVE_PREFIX,
    {
        "host idle timeout sends ping",
        EV_TIMEOUT(SESSION_TIMER_LIVENESS),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SEND("PING", SESSION_ROUTE_CONTROL, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "host ping handoff arms peer deadline",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 350u)
        },
        2u
    },
    {
        "host peer deadline attempts retained peer release",
        EV_TIMEOUT(SESSION_TIMER_LIVENESS),
        {
            OBS_SEND("F B 77", SESSION_ROUTE_PRESENCE_PEER, 1u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        2u
    },
    {
        "failed peer release clears own retained seat",
        EV_TX_FAILED,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_SEND("F W 77", SESSION_ROUTE_PRESENCE, 1u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "own release completion clears retained metadata",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_SEND("", SESSION_ROUTE_META, 1u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD,
                          SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "metadata clear closes failed recovery",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_CLOSE(1u),
            OBS_SESSION(SESSION_CHANGED_ENDED)
        },
        3u
    }
};

static const MqttTranscriptStep liveness_ping_during_control_steps[] = {
    GUEST_ACTIVE_PREFIX,
    {
        "local move starts control wait",
        EV_LOCAL(SESSION_REQUEST_MOVE, 0u, "e2e4", SESSION_PHASE_ACTIVE),
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SEND("MOVE 1 e2e4", SESSION_ROUTE_GAME, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "move handoff arms control timer",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 125u)
        },
        2u
    },
    {
        "ping during control wait is acked",
        EV_RX("PING", SESSION_ROUTE_CONTROL, SESSION_RX_LIVE, 1u),
        {
            OBS_SEND("ACK PING", SESSION_ROUTE_ACK, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        2u
    },
    {
        "ping ack handoff preserves control wait",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        2u
    },
    {
        "original move still accepts",
        EV_RX("ACK 1", SESSION_ROUTE_ACK, SESSION_RX_LIVE, 1u),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_CONTROL),
            OBS_GAME(SESSION_DELIVER_LOCAL_MOVE, 0u, 1u, "e2e4"),
            OBS_GAME(SESSION_DELIVER_CONTROL_RESULT,
                     SESSION_CONTROL_ACCEPTED, SESSION_REQUEST_MOVE, 0),
            OBS_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        4u
    },
    {
        "retained ping is ignored",
        EV_RX("PING", SESSION_ROUTE_CONTROL, SESSION_RX_RETAINED, 1u),
        NO_OBSERVATIONS
    },
    {
        "wrong-route ping is acked",
        EV_RX("PING", SESSION_ROUTE_GAME, SESSION_RX_LIVE, 1u),
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SEND("ACK PING", SESSION_ROUTE_ACK, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "idle ping ack handoff rearms idle",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        2u
    }
};

static const MqttTranscriptStep liveness_activity_steps[] = {
    GUEST_ACTIVE_PREFIX,
    {
        "idle timeout sends ping",
        EV_TIMEOUT(SESSION_TIMER_LIVENESS),
        {
            OBS_SEND("PING", SESSION_ROUTE_CONTROL, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        2u
    },
    {
        "ping handoff arms peer deadline",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_TIMER_SET(SESSION_TIMER_LIVENESS, 350u)
        },
        2u
    },
    {
        "live chat clears probe and restarts idle",
        EV_RX("CHAT active", SESSION_ROUTE_GAME, SESSION_RX_LIVE, 1u),
        {
            OBS_GAME(SESSION_DELIVER_CHAT, 0u, SESSION_CHAT_REMOTE, "active"),
            OBS_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        2u
    },
    {
        "activity-reset idle sends a fresh ping",
        EV_TIMEOUT(SESSION_TIMER_LIVENESS),
        {
            OBS_SEND("PING", SESSION_ROUTE_CONTROL, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        2u
    }
};

static const MqttTranscriptStep liveness_tx_guard_steps[] = {
    GUEST_ACTIVE_PREFIX,
    {
        "idle timeout sends ping",
        EV_TIMEOUT(SESSION_TIMER_LIVENESS),
        {
            OBS_SEND("PING", SESSION_ROUTE_CONTROL, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        2u
    },
    {
        "ping tx guard expiry publishes offline cleanup",
        EV_TIMEOUT(SESSION_TIMER_TX_GUARD),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_SEND("F B 77", SESSION_ROUTE_PRESENCE, 1u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "offline cleanup handoff closes failed session",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_CLOSE(1u),
            OBS_SESSION(SESSION_CHANGED_ENDED)
        },
        3u
    }
};

static const MqttTranscriptStep liveness_tx_failed_steps[] = {
    GUEST_ACTIVE_PREFIX,
    {
        "idle timeout sends ping before immediate failure",
        EV_TIMEOUT(SESSION_TIMER_LIVENESS),
        {
            OBS_SEND("PING", SESSION_ROUTE_CONTROL, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        2u
    },
    {
        "immediate ping failure publishes offline cleanup",
        EV_TX_FAILED,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_SEND("F B 77", SESSION_ROUTE_PRESENCE, 1u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "offline cleanup handoff closes failed session",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_CLOSE(1u),
            OBS_SESSION(SESSION_CHANGED_ENDED)
        },
        3u
    }
};

static const MqttTranscriptStep link_loss_pending_tx_fresh_steps[] = {
    GUEST_ACTIVE_ONE_PLY_PRIVATE_PREFIX,
    {
        "second old-game move owns tx",
        EV_LOCAL(SESSION_REQUEST_MOVE, 0u, "a7a6", SESSION_PHASE_ACTIVE),
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SEND("MOVE 2 a7a6", SESSION_ROUTE_GAME, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "wrong link loss is neutral",
        EV_LINK_DOWN(2u),
        NO_STATE_CHANGE
    },
    {
        "active link loss cancels tx without close",
        EV_LINK_DOWN(1u),
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_SESSION(SESSION_CHANGED_ENDED)
        },
        2u
    },
    {
        "late old tx result is inert",
        EV_TX_OK,
        NO_OBSERVATIONS
    },
    {
        "old traffic before new link is inert",
        EV_RX("H W 77", SESSION_ROUTE_META, SESSION_RX_LIVE, 1u),
        NO_OBSERVATIONS
    },
    {
        "new broker link is explicit",
        EV_LINK_UP(2u),
        NO_OBSERVATIONS
    },
    {
        "old retained seat cannot restore",
        EV_RX("O B 77", SESSION_ROUTE_PRESENCE, SESSION_RX_RETAINED, 2u),
        NO_OBSERVATIONS
    },
    {
        "new retained host selects fresh session",
        EV_RX("H B 88", SESSION_ROUTE_META, SESSION_RX_RETAINED, 2u),
        {OBS_SIDE(SESSION_COLOR_WHITE, 88u)},
        1u
    },
    {
        "new live host starts fresh claim",
        EV_RX("H B 88", SESSION_ROUTE_META, SESSION_RX_LIVE, 2u),
        {
            OBS_SEND("O W 88", SESSION_ROUTE_PRESENCE, 1u, 2u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        2u
    },
    {
        "fresh online handoff sends fresh join",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_SEND("J 88", SESSION_ROUTE_META, 0u, 2u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "fresh join handoff makes ready",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_SESSION(SESSION_CHANGED_READY),
            OBS_TIMER_SET(SESSION_TIMER_LIVENESS, 250u),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 250u)
        },
        4u
    },
    {
        "fresh game start sends ack before activation",
        EV_RX("GAME START", SESSION_ROUTE_CONTROL, SESSION_RX_LIVE, 2u),
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_CONTROL),
            OBS_SEND("ACK GAME START", SESSION_ROUTE_CONTROL, 0u, 2u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        4u
    },
    {
        "fresh start ack rearms liveness",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_SESSION(SESSION_CHANGED_STARTED),
            OBS_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        3u
    },
    {
        "fresh board restarts at ply one",
        EV_LOCAL(SESSION_REQUEST_MOVE, 0u, "a2a3", SESSION_PHASE_ACTIVE),
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SEND("MOVE 1 a2a3", SESSION_ROUTE_GAME, 0u, 2u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    }
};

static const MqttTranscriptStep link_loss_pending_decision_steps[] = {
    GUEST_ACTIVE_PREFIX,
    {
        "remote reset opens user decision",
        EV_RX("RESET", SESSION_ROUTE_CONTROL, SESSION_RX_LIVE, 1u),
        {
            OBS_DECISION(SESSION_REQUEST_RESET, 0u),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        2u
    },
    {
        "candidate link loss preserves decision",
        EV_LINK_DOWN(2u),
        NO_OBSERVATIONS
    },
    {
        "active loss cancels pending decision",
        EV_LINK_DOWN(1u),
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SESSION(SESSION_CHANGED_ENDED)
        },
        2u
    },
    {
        "late user decision is inert",
        EV_DECISION(SESSION_DECISION_ACCEPT),
        NO_STATE_CHANGE
    }
};

static const MqttTranscriptStep link_loss_duplicate_fresh_steps[] = {
    GUEST_ACTIVE_PREFIX,
    {
        "old remote move enters domain",
        EV_RX("MOVE 1 e2e4", SESSION_ROUTE_GAME, SESSION_RX_LIVE, 1u),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_GAME(SESSION_DELIVER_REMOTE_MOVE, 1u, 1u, "e2e4"),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 125u)
        },
        3u
    },
    {
        "old domain acceptance records duplicate latch",
        EV_GAME_RESULT(SESSION_GAME_ACCEPTED, 1u, 0),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_CONTROL),
            OBS_SEND("ACK 1", SESSION_ROUTE_ACK, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        4u
    },
    {
        "old ack handoff rearms liveness",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        2u
    },
    {
        "loss discards old ply and duplicate latch",
        EV_LINK_DOWN(1u),
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SESSION(SESSION_CHANGED_ENDED)
        },
        2u
    },
    {"fresh link for duplicate proof", EV_LINK_UP(2u),
     NO_OBSERVATIONS},
    {
        "fresh retained host selects session",
        EV_RX("H W 88", SESSION_ROUTE_META, SESSION_RX_RETAINED, 2u),
        {OBS_SIDE(SESSION_COLOR_BLACK, 88u)},
        1u
    },
    {
        "fresh live host claims seat",
        EV_RX("H W 88", SESSION_ROUTE_META, SESSION_RX_LIVE, 2u),
        {
            OBS_SEND("O B 88", SESSION_ROUTE_PRESENCE, 1u, 2u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        2u
    },
    {
        "fresh claim sends join",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_SEND("J 88", SESSION_ROUTE_META, 0u, 2u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "fresh join makes ready",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_SESSION(SESSION_CHANGED_READY),
            OBS_TIMER_SET(SESSION_TIMER_LIVENESS, 250u),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 250u)
        },
        4u
    },
    {
        "fresh start sends ack before activation",
        EV_RX("GAME START", SESSION_ROUTE_CONTROL, SESSION_RX_LIVE, 2u),
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_CONTROL),
            OBS_SEND("ACK GAME START", SESSION_ROUTE_CONTROL, 0u, 2u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        4u
    },
    {
        "fresh start ack rearms liveness",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_SESSION(SESSION_CHANGED_STARTED),
            OBS_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        3u
    },
    {
        "same wire move is new in fresh game",
        EV_RX("MOVE 1 e2e4", SESSION_ROUTE_GAME, SESSION_RX_LIVE, 2u),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_GAME(SESSION_DELIVER_REMOTE_MOVE, 1u, 1u, "e2e4"),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 125u)
        },
        3u
    },
    {
        "fresh domain acceptance records new latch",
        EV_GAME_RESULT(SESSION_GAME_ACCEPTED, 1u, 0),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_CONTROL),
            OBS_SEND("ACK 1", SESSION_ROUTE_ACK, 0u, 2u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        4u
    },
    {
        "fresh ack handoff rearms liveness",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        2u
    }
};

static const MqttTranscriptStep bye_local_handshake_steps[] = {
    {"guest link up", EV_LINK_UP(1u), NO_OBSERVATIONS},
    {
        "retained host selects handshake",
        EV_RX("H W 77", SESSION_ROUTE_META, SESSION_RX_RETAINED, 1u),
        {OBS_SIDE(SESSION_COLOR_BLACK, 77u)},
        1u
    },
    {
        "local bye may preempt before peer ready",
        EV_LOCAL(SESSION_REQUEST_BYE, 0u, 0, SESSION_PHASE_HANDSHAKE),
        {
            OBS_SEND("BYE", SESSION_ROUTE_CONTROL, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        2u
    },
    {
        "pre-peer bye handoff closes directly",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_CLOSE(1u),
            OBS_SESSION(SESSION_CHANGED_ENDED)
        },
        3u
    }
};

static const MqttTranscriptStep bye_local_success_steps[] = {
    GUEST_ACTIVE_PREFIX,
    {
        "local reset reaches peer reply wait",
        EV_LOCAL(SESSION_REQUEST_RESET, 0u, 0, SESSION_PHASE_ACTIVE),
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SEND("RESET", SESSION_ROUTE_GAME, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "reset handoff arms reply",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 125u)
        },
        2u
    },
    {
        "local bye preempts pending control",
        EV_LOCAL(SESSION_REQUEST_BYE, 0u, 0, SESSION_PHASE_ACTIVE),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_CONTROL),
            OBS_SEND("BYE", SESSION_ROUTE_CONTROL, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "bye handoff serializes retained offline",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_SEND("F B 77", SESSION_ROUTE_PRESENCE, 1u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "offline handoff closes local bye",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_CLOSE(1u),
            OBS_SESSION(SESSION_CHANGED_ENDED)
        },
        3u
    },
    {
        "late reset ack cannot revive bye session",
        EV_RX("ACK RESET", SESSION_ROUTE_ACK, SESSION_RX_LIVE, 1u),
        NO_OBSERVATIONS
    }
};

static const MqttTranscriptStep bye_local_host_success_steps[] = {
    HOST_ACTIVE_PREFIX,
    {
        "host local bye sends before teardown",
        EV_LOCAL(SESSION_REQUEST_BYE, 0u, 0, SESSION_PHASE_ACTIVE),
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SEND("BYE", SESSION_ROUTE_CONTROL, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "host bye handoff serializes retained offline",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_SEND("F W 77", SESSION_ROUTE_PRESENCE, 1u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "host offline handoff clears retained metadata",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_SEND("", SESSION_ROUTE_META, 1u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "host metadata clear handoff closes local bye",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_CLOSE(1u),
            OBS_SESSION(SESSION_CHANGED_ENDED)
        },
        3u
    }
};

static const MqttTranscriptStep bye_local_failed_steps[] = {
    GUEST_ACTIVE_PREFIX,
    {
        "local bye sends before teardown",
        EV_LOCAL(SESSION_REQUEST_BYE, 0u, 0, SESSION_PHASE_ACTIVE),
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SEND("BYE", SESSION_ROUTE_CONTROL, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "failed bye handoff still clears retained seat",
        EV_TX_FAILED,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_SEND("F B 77", SESSION_ROUTE_PRESENCE, 1u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "failed offline cleanup still ends logically",
        EV_TX_FAILED,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_CLOSE(1u),
            OBS_SESSION(SESSION_CHANGED_ENDED)
        },
        3u
    }
};

static const MqttTranscriptStep bye_remote_steps[] = {
    GUEST_ACTIVE_PREFIX,
    {
        "retained bye is inert",
        EV_RX("BYE", SESSION_ROUTE_CONTROL, SESSION_RX_RETAINED, 1u),
        NO_STATE_CHANGE
    },
    {
        "remote reset opens decision before bye",
        EV_RX("RESET", SESSION_ROUTE_CONTROL, SESSION_RX_LIVE, 1u),
        {
            OBS_DECISION(SESSION_REQUEST_RESET, 0u),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        2u
    },
    {
        "wrong-route peer bye ends without reply",
        EV_RX("BYE", SESSION_ROUTE_GAME, SESSION_RX_LIVE, 1u),
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SESSION(SESSION_CHANGED_ENDED)
        },
        2u
    },
    {
        "late decision after peer bye is inert",
        EV_DECISION(SESSION_DECISION_ACCEPT),
        NO_OBSERVATIONS
    },
    {
        "pre-peer bye cannot kill retained broker link",
        EV_RX("BYE", SESSION_ROUTE_CONTROL, SESSION_RX_LIVE, 1u),
        NO_OBSERVATIONS
    }
};

static const MqttTranscriptStep bye_remote_host_release_steps[] = {
    HOST_ACTIVE_PREFIX,
    {
        "host bye releases retained peer seat",
        EV_RX("BYE", SESSION_ROUTE_CONTROL, SESSION_RX_LIVE, 1u),
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SEND("F B 77", SESSION_ROUTE_PRESENCE_PEER, 1u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "peer release handoff waits on broker link",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_SESSION(SESSION_CHANGED_ENDED),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 250u)
        },
        3u
    },
    {
        "waiting host republishes retained metadata",
        EV_TIMEOUT(SESSION_TIMER_CONTROL),
        {
            OBS_SEND("H W 77", SESSION_ROUTE_META, 1u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        2u
    },
    {
        "waiting host reannounce rearms setup",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 250u)
        },
        2u
    },
    {
        "replacement join receives live host",
        EV_RX("J 77", SESSION_ROUTE_META, SESSION_RX_LIVE, 1u),
        {
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_CONTROL),
            OBS_SEND("H W 77", SESSION_ROUTE_META, 0u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "replacement host completion makes ready",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_SESSION(SESSION_CHANGED_READY),
            OBS_TIMER_SET(SESSION_TIMER_LIVENESS, 250u)
        },
        3u
    }
};

static const MqttTranscriptStep bye_remote_host_release_fail_steps[] = {
    HOST_ACTIVE_PREFIX,
    {
        "host bye attempts retained peer release",
        EV_RX("BYE", SESSION_ROUTE_CONTROL, SESSION_RX_LIVE, 1u),
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_LIVENESS),
            OBS_SEND("F B 77", SESSION_ROUTE_PRESENCE_PEER, 1u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "failed bye release clears own retained seat",
        EV_TX_FAILED,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_SEND("F W 77", SESSION_ROUTE_PRESENCE, 1u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "own release completion clears retained metadata",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_SEND("", SESSION_ROUTE_META, 1u, 1u),
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD,
                          SESSION_TX_GUARD_TICKS)
        },
        3u
    },
    {
        "metadata clear closes failed bye recovery",
        EV_TX_OK,
        {
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD),
            OBS_CLOSE(1u),
            OBS_SESSION(SESSION_CHANGED_ENDED)
        },
        3u
    }
};

#define CONTROL_CANCEL_RETRY(text) \
    { \
        "control retry sends", \
        EV_TIMEOUT(SESSION_TIMER_CONTROL), \
        { \
            OBS_SEND((text), SESSION_ROUTE_GAME, 0u, 1u), \
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS) \
        }, \
        2u \
    }, \
    { \
        "control retry handoff", \
        EV_TX_OK, \
        { \
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD), \
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 125u) \
        }, \
        2u \
    }

#define CONTROL_CANCEL_LOCAL_STEPS(prefix, request, text, cancel, nack) \
    prefix, \
    { \
        "local control starts", \
        EV_LOCAL((request), 0u, 0, SESSION_PHASE_ACTIVE), \
        { \
            OBS_TIMER_CANCEL(SESSION_TIMER_LIVENESS), \
            OBS_SEND((text), SESSION_ROUTE_GAME, 0u, 1u), \
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS) \
        }, \
        3u \
    }, \
    { \
        "initial control handoff", \
        EV_TX_OK, \
        { \
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD), \
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 125u) \
        }, \
        2u \
    }, \
    { \
        "chat remains available while control is pending", \
        EV_LOCAL(SESSION_REQUEST_CHAT, 0u, "hello", SESSION_PHASE_ACTIVE), \
        { \
            OBS_SEND("CHAT hello", SESSION_ROUTE_GAME, 0u, 1u), \
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS) \
        }, \
        2u \
    }, \
    { \
        "chat handoff preserves pending control", \
        EV_TX_OK, \
        { \
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD), \
            OBS_GAME(SESSION_DELIVER_CHAT, 0u, SESSION_CHAT_LOCAL, "hello") \
        }, \
        2u \
    }, \
    { \
        "second control remains blocked while first is pending", \
        EV_LOCAL(SESSION_REQUEST_RESIGN, 0u, 0, SESSION_PHASE_ACTIVE), \
        NO_STATE_CHANGE \
    }, \
    CONTROL_CANCEL_RETRY(text), \
    CONTROL_CANCEL_RETRY(text), \
    CONTROL_CANCEL_RETRY(text), \
    CONTROL_CANCEL_RETRY(text), \
    CONTROL_CANCEL_RETRY(text), \
    { \
        "retry ladder opens five minute grace", \
        EV_TIMEOUT(SESSION_TIMER_CONTROL), \
        { \
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, \
                                   SESSION_CONTROL_CANCEL_TICKS), \
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 250u) \
        }, \
        2u \
    }, \
    { \
        "grace expiry sends cancellation", \
        EV_TIMEOUT(SESSION_TIMER_CONTROL), \
        { \
            OBS_SEND((cancel), SESSION_ROUTE_GAME, 0u, 1u), \
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS) \
        }, \
        2u \
    }, \
    { \
        "cancellation handoff awaits confirmation", \
        EV_TX_OK, \
        { \
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD), \
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 125u) \
        }, \
        2u \
    }, \
    CONTROL_CANCEL_RETRY(cancel), \
    CONTROL_CANCEL_RETRY(cancel), \
    CONTROL_CANCEL_RETRY(cancel), \
    CONTROL_CANCEL_RETRY(cancel), \
    CONTROL_CANCEL_RETRY(cancel), \
    { \
        "cancellation retry ladder returns to grace", \
        EV_TIMEOUT(SESSION_TIMER_CONTROL), \
        { \
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, \
                                   SESSION_CONTROL_CANCEL_TICKS), \
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 250u) \
        }, \
        2u \
    }, \
    { \
        "second grace expiry resends cancellation", \
        EV_TIMEOUT(SESSION_TIMER_CONTROL), \
        { \
            OBS_SEND((cancel), SESSION_ROUTE_GAME, 0u, 1u), \
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS) \
        }, \
        2u \
    }, \
    { \
        "second cancellation handoff awaits confirmation", \
        EV_TX_OK, \
        { \
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD), \
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_CONTROL, 125u) \
        }, \
        2u \
    }, \
    { \
        "nack confirms cancellation without ending session", \
        EV_RX((nack), SESSION_ROUTE_GAME, SESSION_RX_LIVE, 1u), \
        { \
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_CONTROL), \
            OBS_GAME(SESSION_DELIVER_CONTROL_RESULT, \
                     SESSION_CONTROL_CANCELLED, (request), (nack)), \
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 250u) \
        }, \
        3u \
    }

static const MqttTranscriptStep control_cancel_local_reset_steps[] = {
    CONTROL_CANCEL_LOCAL_STEPS(GUEST_ACTIVE_PREFIX,
                               SESSION_REQUEST_RESET,
                               "RESET", "CANCEL RESET", "NACK RESET")
};

static const MqttTranscriptStep control_cancel_local_draw_steps[] = {
    CONTROL_CANCEL_LOCAL_STEPS(HOST_ACTIVE_PREFIX,
                               SESSION_REQUEST_DRAW,
                               "DRAW", "CANCEL DRAW", "NACK DRAW")
};

#define CONTROL_CANCEL_REMOTE_STEPS(prefix, request, text, cancel, nack) \
    prefix, \
    { \
        "remote control opens decision", \
        EV_RX((text), SESSION_ROUTE_CONTROL, SESSION_RX_LIVE, 1u), \
        { \
            OBS_DECISION((request), 0u), \
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 250u) \
        }, \
        2u \
    }, \
    { \
        "remote cancellation invalidates decision", \
        EV_RX((cancel), SESSION_ROUTE_CONTROL, SESSION_RX_LIVE, 1u), \
        { \
            OBS_INTERNAL_TIMER_CANCEL(SESSION_TIMER_LIVENESS), \
            OBS_SEND((nack), SESSION_ROUTE_GAME, 0u, 1u), \
            OBS_TIMER_SET(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS) \
        }, \
        3u \
    }, \
    { \
        "nack handoff reports expired request", \
        EV_TX_OK, \
        { \
            OBS_TIMER_CANCEL(SESSION_TIMER_TX_GUARD), \
            OBS_GAME(SESSION_DELIVER_CONTROL_RESULT, \
                     SESSION_CONTROL_EXPIRED, (request), 0), \
            OBS_INTERNAL_TIMER_SET(SESSION_TIMER_LIVENESS, 250u) \
        }, \
        3u \
    }, \
    { \
        "stale modal decision is inert", \
        EV_DECISION_ID(SESSION_DECISION_ACCEPT, 1u), \
        NO_STATE_CHANGE \
    }

static const MqttTranscriptStep control_cancel_remote_draw_steps[] = {
    CONTROL_CANCEL_REMOTE_STEPS(GUEST_ACTIVE_PREFIX,
                                SESSION_REQUEST_DRAW,
                                "DRAW", "CANCEL DRAW", "NACK DRAW")
};

static const MqttTranscriptStep control_cancel_remote_reset_steps[] = {
    CONTROL_CANCEL_REMOTE_STEPS(HOST_ACTIVE_PREFIX,
                                SESSION_REQUEST_RESET,
                                "RESET", "CANCEL RESET", "NACK RESET")
};

const MqttTranscript mqtt_session_transcripts[] = {
    {
        "mqtt-seat-acquire-retained-vs-live",
        seat_filter_acquire_steps,
        0u,
        SESSION_ROLE_GUEST,
        SESSION_COLOR_UNKNOWN,
        (uint8_t)(sizeof(seat_filter_acquire_steps) /
                  sizeof(seat_filter_acquire_steps[0]))
    },
    {
        "mqtt-seat-acquire-exact-retained-busy",
        seat_busy_steps,
        0u,
        SESSION_ROLE_GUEST,
        SESSION_COLOR_UNKNOWN,
        (uint8_t)(sizeof(seat_busy_steps) / sizeof(seat_busy_steps[0]))
    },
    {
        "mqtt-seat-acquire-online-tx-fail",
        seat_tx_fail_before_claim_steps,
        0u,
        SESSION_ROLE_GUEST,
        SESSION_COLOR_UNKNOWN,
        (uint8_t)(sizeof(seat_tx_fail_before_claim_steps) /
                  sizeof(seat_tx_fail_before_claim_steps[0]))
    },
    {
        "mqtt-seat-acquire-join-tx-fail-cleanup",
        seat_tx_fail_after_claim_steps,
        0u,
        SESSION_ROLE_GUEST,
        SESSION_COLOR_UNKNOWN,
        (uint8_t)(sizeof(seat_tx_fail_after_claim_steps) /
                  sizeof(seat_tx_fail_after_claim_steps[0]))
    },
    {
        "mqtt-seat-host-join-duplicates-and-conflict",
        host_join_duplicate_steps,
        77u,
        SESSION_ROLE_HOST,
        SESSION_COLOR_WHITE,
        (uint8_t)(sizeof(host_join_duplicate_steps) /
                  sizeof(host_join_duplicate_steps[0]))
    },
    {
        "mqtt-bootstrap-presence-session-stale",
        bootstrap_stale_presence_steps,
        0u,
        SESSION_ROLE_GUEST,
        SESSION_COLOR_UNKNOWN,
        (uint8_t)(sizeof(bootstrap_stale_presence_steps) /
                  sizeof(bootstrap_stale_presence_steps[0]))
    },
    {
        "mqtt-bootstrap-host-reannounce",
        bootstrap_host_reannounce_steps,
        77u,
        SESSION_ROLE_HOST,
        SESSION_COLOR_WHITE,
        (uint8_t)(sizeof(bootstrap_host_reannounce_steps) /
                   sizeof(bootstrap_host_reannounce_steps[0]))
    },
    {
        "mqtt-bootstrap-guest-reannounce",
        bootstrap_guest_reannounce_steps,
        0u,
        SESSION_ROLE_GUEST,
        SESSION_COLOR_UNKNOWN,
        (uint8_t)(sizeof(bootstrap_guest_reannounce_steps) /
                  sizeof(bootstrap_guest_reannounce_steps[0]))
    },
    {
        "mqtt-start-host-app-ack",
        start_host_ack_steps,
        77u,
        SESSION_ROLE_HOST,
        SESSION_COLOR_WHITE,
        (uint8_t)(sizeof(start_host_ack_steps) /
                  sizeof(start_host_ack_steps[0]))
    },
    {
        "mqtt-start-host-retry-limit",
        start_host_retry_limit_steps,
        77u,
        SESSION_ROLE_HOST,
        SESSION_COLOR_WHITE,
        (uint8_t)(sizeof(start_host_retry_limit_steps) /
                  sizeof(start_host_retry_limit_steps[0]))
    },
    {
        "mqtt-start-host-app-nack",
        start_host_nack_steps,
        77u,
        SESSION_ROLE_HOST,
        SESSION_COLOR_BLACK,
        (uint8_t)(sizeof(start_host_nack_steps) /
                  sizeof(start_host_nack_steps[0]))
    },
    {
        "mqtt-start-guest-live-and-duplicate",
        start_guest_steps,
        0u,
        SESSION_ROLE_GUEST,
        SESSION_COLOR_UNKNOWN,
        (uint8_t)(sizeof(start_guest_steps) /
                  sizeof(start_guest_steps[0]))
    },
    {
        "mqtt-start-role-readiness-guards",
        start_role_guards_steps,
        0u,
        SESSION_ROLE_GUEST,
        SESSION_COLOR_UNKNOWN,
        (uint8_t)(sizeof(start_role_guards_steps) /
                  sizeof(start_role_guards_steps[0]))
    },
    {
        "mqtt-move-local-app-ack",
        move_local_ack_steps,
        0u,
        SESSION_ROLE_GUEST,
        SESSION_COLOR_UNKNOWN,
        (uint8_t)(sizeof(move_local_ack_steps) /
                  sizeof(move_local_ack_steps[0]))
    },
    {
        "mqtt-move-local-app-nack",
        move_local_nack_steps,
        0u,
        SESSION_ROLE_GUEST,
        SESSION_COLOR_UNKNOWN,
        (uint8_t)(sizeof(move_local_nack_steps) /
                  sizeof(move_local_nack_steps[0]))
    },
    {
        "mqtt-move-remote-accepted-duplicate",
        move_remote_accept_steps,
        0u,
        SESSION_ROLE_GUEST,
        SESSION_COLOR_UNKNOWN,
        (uint8_t)(sizeof(move_remote_accept_steps) /
                  sizeof(move_remote_accept_steps[0]))
    },
    {
        "mqtt-move-remote-rejected-duplicate",
        move_remote_reject_steps,
        0u,
        SESSION_ROLE_GUEST,
        SESSION_COLOR_UNKNOWN,
        (uint8_t)(sizeof(move_remote_reject_steps) /
                  sizeof(move_remote_reject_steps[0]))
    },
    {
        "mqtt-move-sync-and-tx-fail",
        move_sync_and_tx_fail_steps,
        0u,
        SESSION_ROLE_GUEST,
        SESSION_COLOR_UNKNOWN,
        (uint8_t)(sizeof(move_sync_and_tx_fail_steps) /
                  sizeof(move_sync_and_tx_fail_steps[0]))
    },
    {
        "mqtt-move-promotion-qrbn",
        move_promotion_steps,
        0u,
        SESSION_ROLE_GUEST,
        SESSION_COLOR_UNKNOWN,
        (uint8_t)(sizeof(move_promotion_steps) /
                  sizeof(move_promotion_steps[0]))
    },
    {
        "mqtt-restore-pre-peer-inert",
        restore_pre_peer_steps,
        0u,
        SESSION_ROLE_GUEST,
        SESSION_COLOR_UNKNOWN,
        (uint8_t)(sizeof(restore_pre_peer_steps) /
                  sizeof(restore_pre_peer_steps[0]))
    },
    {
        "mqtt-restore-local-active",
        restore_local_active_steps,
        77u,
        SESSION_ROLE_HOST,
        SESSION_COLOR_WHITE,
        (uint8_t)(sizeof(restore_local_active_steps) /
                  sizeof(restore_local_active_steps[0]))
    },
    {
        "mqtt-restore-remote-fresh",
        restore_remote_fresh_steps,
        0u,
        SESSION_ROLE_GUEST,
        SESSION_COLOR_UNKNOWN,
        (uint8_t)(sizeof(restore_remote_fresh_steps) /
                  sizeof(restore_remote_fresh_steps[0]))
    },
    {
        "mqtt-restore-cancel-early",
        restore_cancel_early_steps,
        77u,
        SESSION_ROLE_HOST,
        SESSION_COLOR_WHITE,
        (uint8_t)(sizeof(restore_cancel_early_steps) /
                  sizeof(restore_cancel_early_steps[0]))
    },
    {
        "mqtt-restore-wait-ry-retry-limit",
        restore_wait_ry_retry_limit_steps,
        77u,
        SESSION_ROLE_HOST,
        SESSION_COLOR_WHITE,
        (uint8_t)(sizeof(restore_wait_ry_retry_limit_steps) /
                  sizeof(restore_wait_ry_retry_limit_steps[0]))
    },
    {
        "mqtt-restore-host-reject",
        restore_host_reject_steps,
        77u,
        SESSION_ROLE_HOST,
        SESSION_COLOR_WHITE,
        (uint8_t)(sizeof(restore_host_reject_steps) /
                  sizeof(restore_host_reject_steps[0]))
    },
    {
        "mqtt-restore-reject-offline-ok",
        restore_reject_offline_ok_steps,
        0u,
        SESSION_ROLE_GUEST,
        SESSION_COLOR_UNKNOWN,
        (uint8_t)(sizeof(restore_reject_offline_ok_steps) /
                  sizeof(restore_reject_offline_ok_steps[0]))
    },
    {
        "mqtt-restore-reject-offline-failed",
        restore_reject_offline_failed_steps,
        0u,
        SESSION_ROLE_GUEST,
        SESSION_COLOR_UNKNOWN,
        (uint8_t)(sizeof(restore_reject_offline_failed_steps) /
                  sizeof(restore_reject_offline_failed_steps[0]))
    },
    {
        "mqtt-control-chat",
        control_chat_steps,
        0u,
        SESSION_ROLE_GUEST,
        SESSION_COLOR_UNKNOWN,
        (uint8_t)(sizeof(control_chat_steps) /
                  sizeof(control_chat_steps[0]))
    },
    {
        "mqtt-control-local-reset",
        control_local_reset_steps,
        0u,
        SESSION_ROLE_GUEST,
        SESSION_COLOR_UNKNOWN,
        (uint8_t)(sizeof(control_local_reset_steps) /
                  sizeof(control_local_reset_steps[0]))
    },
    {
        "mqtt-control-remote-reset",
        control_remote_reset_steps,
        0u,
        SESSION_ROLE_GUEST,
        SESSION_COLOR_UNKNOWN,
        (uint8_t)(sizeof(control_remote_reset_steps) /
                  sizeof(control_remote_reset_steps[0]))
    },
    {
        "mqtt-control-local-draw-crossed",
        control_local_draw_crossed_steps,
        0u,
        SESSION_ROLE_GUEST,
        SESSION_COLOR_UNKNOWN,
        (uint8_t)(sizeof(control_local_draw_crossed_steps) /
                  sizeof(control_local_draw_crossed_steps[0]))
    },
    {
        "mqtt-control-remote-draw",
        control_remote_draw_steps,
        0u,
        SESSION_ROLE_GUEST,
        SESSION_COLOR_UNKNOWN,
        (uint8_t)(sizeof(control_remote_draw_steps) /
                  sizeof(control_remote_draw_steps[0]))
    },
    {
        "mqtt-control-local-resign",
        control_local_resign_steps,
        0u,
        SESSION_ROLE_GUEST,
        SESSION_COLOR_UNKNOWN,
        (uint8_t)(sizeof(control_local_resign_steps) /
                  sizeof(control_local_resign_steps[0]))
    },
    {
        "mqtt-control-remote-resign",
        control_remote_resign_steps,
        0u,
        SESSION_ROLE_GUEST,
        SESSION_COLOR_UNKNOWN,
        (uint8_t)(sizeof(control_remote_resign_steps) /
                  sizeof(control_remote_resign_steps[0]))
    },
    {
        "mqtt-control-crossed-resign",
        control_crossed_resign_steps,
        0u,
        SESSION_ROLE_GUEST,
        SESSION_COLOR_UNKNOWN,
        (uint8_t)(sizeof(control_crossed_resign_steps) /
                   sizeof(control_crossed_resign_steps[0]))
    },
    {
        "mqtt-control-crossed-resign-host",
        control_crossed_resign_host_steps,
        77u,
        SESSION_ROLE_HOST,
        SESSION_COLOR_WHITE,
        (uint8_t)(sizeof(control_crossed_resign_host_steps) /
                  sizeof(control_crossed_resign_host_steps[0]))
    },
    {
        "mqtt-control-local-takeback",
        control_local_takeback_steps,
        0u,
        SESSION_ROLE_GUEST,
        SESSION_COLOR_UNKNOWN,
        (uint8_t)(sizeof(control_local_takeback_steps) /
                  sizeof(control_local_takeback_steps[0]))
    },
    {
        "mqtt-control-remote-takeback",
        control_remote_takeback_steps,
        0u,
        SESSION_ROLE_GUEST,
        SESSION_COLOR_UNKNOWN,
        (uint8_t)(sizeof(control_remote_takeback_steps) /
                  sizeof(control_remote_takeback_steps[0]))
    },
    {
        "mqtt-control-busy-crossing",
        control_busy_crossing_steps,
        0u,
        SESSION_ROLE_GUEST,
        SESSION_COLOR_UNKNOWN,
        (uint8_t)(sizeof(control_busy_crossing_steps) /
                  sizeof(control_busy_crossing_steps[0]))
    },
    {
        "mqtt-liveness-idle-ack",
        liveness_idle_ack_steps,
        0u,
        SESSION_ROLE_GUEST,
        SESSION_COLOR_UNKNOWN,
        (uint8_t)(sizeof(liveness_idle_ack_steps) /
                  sizeof(liveness_idle_ack_steps[0]))
    },
    {
        "mqtt-liveness-peer-timeout",
        liveness_peer_timeout_steps,
        0u,
        SESSION_ROLE_GUEST,
        SESSION_COLOR_UNKNOWN,
        (uint8_t)(sizeof(liveness_peer_timeout_steps) /
                  sizeof(liveness_peer_timeout_steps[0]))
    },
    {
        "mqtt-liveness-host-peer-timeout",
        liveness_host_peer_timeout_steps,
        77u,
        SESSION_ROLE_HOST,
        SESSION_COLOR_WHITE,
        (uint8_t)(sizeof(liveness_host_peer_timeout_steps) /
                  sizeof(liveness_host_peer_timeout_steps[0]))
    },
    {
        "mqtt-liveness-host-peer-release-fail",
        liveness_host_peer_release_fail_steps,
        77u,
        SESSION_ROLE_HOST,
        SESSION_COLOR_WHITE,
        (uint8_t)(sizeof(liveness_host_peer_release_fail_steps) /
                  sizeof(liveness_host_peer_release_fail_steps[0]))
    },
    {
        "mqtt-liveness-ping-during-control",
        liveness_ping_during_control_steps,
        0u,
        SESSION_ROLE_GUEST,
        SESSION_COLOR_UNKNOWN,
        (uint8_t)(sizeof(liveness_ping_during_control_steps) /
                  sizeof(liveness_ping_during_control_steps[0]))
    },
    {
        "mqtt-liveness-live-activity",
        liveness_activity_steps,
        0u,
        SESSION_ROLE_GUEST,
        SESSION_COLOR_UNKNOWN,
        (uint8_t)(sizeof(liveness_activity_steps) /
                  sizeof(liveness_activity_steps[0]))
    },
    {
        "mqtt-liveness-tx-guard-cleanup",
        liveness_tx_guard_steps,
        0u,
        SESSION_ROLE_GUEST,
        SESSION_COLOR_UNKNOWN,
        (uint8_t)(sizeof(liveness_tx_guard_steps) /
                  sizeof(liveness_tx_guard_steps[0]))
    },
    {
        "mqtt-liveness-ping-tx-fail-cleanup",
        liveness_tx_failed_steps,
        0u,
        SESSION_ROLE_GUEST,
        SESSION_COLOR_UNKNOWN,
        (uint8_t)(sizeof(liveness_tx_failed_steps) /
                  sizeof(liveness_tx_failed_steps[0]))
    },
    {
        "mqtt-link-loss-pending-tx-fresh-session",
        link_loss_pending_tx_fresh_steps,
        0u,
        SESSION_ROLE_GUEST,
        SESSION_COLOR_UNKNOWN,
        (uint8_t)(sizeof(link_loss_pending_tx_fresh_steps) /
                  sizeof(link_loss_pending_tx_fresh_steps[0]))
    },
    {
        "mqtt-link-loss-pending-decision",
        link_loss_pending_decision_steps,
        0u,
        SESSION_ROLE_GUEST,
        SESSION_COLOR_UNKNOWN,
        (uint8_t)(sizeof(link_loss_pending_decision_steps) /
                  sizeof(link_loss_pending_decision_steps[0]))
    },
    {
        "mqtt-link-loss-duplicate-latch-fresh-session",
        link_loss_duplicate_fresh_steps,
        0u,
        SESSION_ROLE_GUEST,
        SESSION_COLOR_UNKNOWN,
        (uint8_t)(sizeof(link_loss_duplicate_fresh_steps) /
                  sizeof(link_loss_duplicate_fresh_steps[0]))
    },
    {
        "mqtt-bye-local-handshake-preemption",
        bye_local_handshake_steps,
        0u,
        SESSION_ROLE_GUEST,
        SESSION_COLOR_UNKNOWN,
        (uint8_t)(sizeof(bye_local_handshake_steps) /
                  sizeof(bye_local_handshake_steps[0]))
    },
    {
        "mqtt-bye-local-success",
        bye_local_success_steps,
        0u,
        SESSION_ROLE_GUEST,
        SESSION_COLOR_UNKNOWN,
        (uint8_t)(sizeof(bye_local_success_steps) /
                  sizeof(bye_local_success_steps[0]))
    },
    {
        "mqtt-bye-local-host-success",
        bye_local_host_success_steps,
        77u,
        SESSION_ROLE_HOST,
        SESSION_COLOR_WHITE,
        (uint8_t)(sizeof(bye_local_host_success_steps) /
                  sizeof(bye_local_host_success_steps[0]))
    },
    {
        "mqtt-bye-local-failed-handoff",
        bye_local_failed_steps,
        0u,
        SESSION_ROLE_GUEST,
        SESSION_COLOR_UNKNOWN,
        (uint8_t)(sizeof(bye_local_failed_steps) /
                  sizeof(bye_local_failed_steps[0]))
    },
    {
        "mqtt-bye-remote-guards-and-preemption",
        bye_remote_steps,
        0u,
        SESSION_ROLE_GUEST,
        SESSION_COLOR_UNKNOWN,
        (uint8_t)(sizeof(bye_remote_steps) /
                   sizeof(bye_remote_steps[0]))
    },
    {
        "mqtt-bye-remote-host-releases-peer",
        bye_remote_host_release_steps,
        77u,
        SESSION_ROLE_HOST,
        SESSION_COLOR_WHITE,
        (uint8_t)(sizeof(bye_remote_host_release_steps) /
                  sizeof(bye_remote_host_release_steps[0]))
    },
    {
        "mqtt-bye-remote-host-release-failure",
        bye_remote_host_release_fail_steps,
        77u,
        SESSION_ROLE_HOST,
        SESSION_COLOR_WHITE,
        (uint8_t)(sizeof(bye_remote_host_release_fail_steps) /
                  sizeof(bye_remote_host_release_fail_steps[0]))
    },
    {
        "mqtt-control-cancel-local-reset-guest",
        control_cancel_local_reset_steps,
        0u,
        SESSION_ROLE_GUEST,
        SESSION_COLOR_UNKNOWN,
        (uint8_t)(sizeof(control_cancel_local_reset_steps) /
                  sizeof(control_cancel_local_reset_steps[0]))
    },
    {
        "mqtt-control-cancel-local-draw-host",
        control_cancel_local_draw_steps,
        77u,
        SESSION_ROLE_HOST,
        SESSION_COLOR_WHITE,
        (uint8_t)(sizeof(control_cancel_local_draw_steps) /
                  sizeof(control_cancel_local_draw_steps[0]))
    },
    {
        "mqtt-control-cancel-remote-draw-guest",
        control_cancel_remote_draw_steps,
        0u,
        SESSION_ROLE_GUEST,
        SESSION_COLOR_UNKNOWN,
        (uint8_t)(sizeof(control_cancel_remote_draw_steps) /
                  sizeof(control_cancel_remote_draw_steps[0]))
    },
    {
        "mqtt-control-cancel-remote-reset-host",
        control_cancel_remote_reset_steps,
        77u,
        SESSION_ROLE_HOST,
        SESSION_COLOR_WHITE,
        (uint8_t)(sizeof(control_cancel_remote_reset_steps) /
                  sizeof(control_cancel_remote_reset_steps[0]))
    }
};

const uint8_t mqtt_session_transcript_count =
    (uint8_t)(sizeof(mqtt_session_transcripts) /
              sizeof(mqtt_session_transcripts[0]));
