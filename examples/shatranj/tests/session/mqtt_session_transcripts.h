#ifndef NETCHESSZX_TEST_MQTT_SESSION_TRANSCRIPTS_H
#define NETCHESSZX_TEST_MQTT_SESSION_TRANSCRIPTS_H

#include <stdint.h>

#define MQTT_TRANSCRIPT_LINK_UP 1u
#define MQTT_TRANSCRIPT_LINK_DOWN 2u
#define MQTT_TRANSCRIPT_RX 3u
#define MQTT_TRANSCRIPT_TX_OK 4u
#define MQTT_TRANSCRIPT_TX_FAILED 5u
#define MQTT_TRANSCRIPT_LOCAL 6u
#define MQTT_TRANSCRIPT_DECISION 7u
#define MQTT_TRANSCRIPT_GAME_RESULT 8u
#define MQTT_TRANSCRIPT_TIMEOUT 9u
#define MQTT_OBSERVE_SEND 1u
#define MQTT_OBSERVE_TIMER_SET 2u
#define MQTT_OBSERVE_TIMER_CANCEL 3u
#define MQTT_OBSERVE_LINK_CLOSE 4u
#define MQTT_OBSERVE_DECISION 5u
#define MQTT_OBSERVE_GAME 6u
#define MQTT_OBSERVE_SESSION 7u
#define MQTT_OBSERVE_SIDE 8u
#define MQTT_OBSERVE_STATE_UNCHANGED 9u

#define MQTT_OBSERVE_DETAIL_INTERNAL 1u
#define MQTT_OBSERVE_DETAIL_NACK_COMPAT 2u
#define MQTT_OBSERVE_DETAIL_NACK_ROUTE_COMPAT 3u

#define MQTT_TRANSCRIPT_OBSERVATIONS_MAX 4u

typedef struct MqttTranscriptEvent {
    const char *payload;
    uint16_t value;
    uint8_t type;
    uint8_t code;
    uint8_t route;
    uint8_t flags;
    uint8_t link_id;
    uint8_t phase;
} MqttTranscriptEvent;

typedef struct MqttTranscriptObservation {
    const char *payload;
    uint16_t value;
    uint8_t type;
    uint8_t code;
    uint8_t detail;
    uint8_t route;
    uint8_t retained;
    uint8_t link_id;
} MqttTranscriptObservation;

typedef struct MqttTranscriptStep {
    const char *label;
    MqttTranscriptEvent event;
    MqttTranscriptObservation expected[MQTT_TRANSCRIPT_OBSERVATIONS_MAX];
    uint8_t expected_count;
} MqttTranscriptStep;

typedef struct MqttTranscript {
    const char *name;
    const MqttTranscriptStep *steps;
    uint16_t session_id;
    uint8_t role;
    uint8_t host_color;
    uint8_t step_count;
} MqttTranscript;

/* Accepted corpus MOVE inputs must be legal in the current board/turn state;
   a rejected vector may deliberately exercise the real rules failure. The
   canonical session reducer is not itself a chess-law oracle. */

extern const MqttTranscript mqtt_session_transcripts[];
extern const uint8_t mqtt_session_transcript_count;

#endif
