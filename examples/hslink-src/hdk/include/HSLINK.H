
/*
 * COPYRIGHT 1992 SAMUEL H. SMITH
 * ALL RIGHTS RESERVED
 *
 * THIS DOCUMENT CONTAINS CONFIDENTIAL INFORMATION AND TRADE SECRETS
 * PROPRIETARY TO SAMUEL H. SMITH DBA THE TOOL SHOP.
 *
 */


/*
 * hslink.h - HS/Link, public shared declarations
 *
 */

/* -------------------------------------------------------------------- */
/* ---------- data types ---------------------------------------------- */
/* -------------------------------------------------------------------- */


/*
 * values of cancal_link
 *
 */
enum cancel_link_codes {
        CANCEL_KEYBOARD         = 1,
        CANCEL_REMOTE           = 2,
        CANCEL_BAD_BETA         = 3,
        CANCEL_NO_FILES         = 4,
        CANCEL_REMOTE_TIMEOUT   = 5,
        CANCEL_FRAMING_ERRORS   = 6,
        CANCEL_BLOCKED_USERID   = 7,
        CANCEL_HACKED_REMOTE    = 8,
        CANCEL_BAD_COMSPEED     = 9,
        CANCEL_CARRIER_LOST     = 10,
        CANCEL_FLOW_LOCKUP      = 11,
        CANCEL_BAD_OPTION       = 12,
        CANCEL_EXCESS_ERRORS    = 13,
};


/*
 * transmit filename linked list
 *
 */
typedef struct pathname_node {
        char *name;
        struct pathname_node *next;
} pathname_node;


/*
 * chat text block packet
 *
 */

#define CHAT_MAX_LENGTH 80

typedef struct {
        char text[CHAT_MAX_LENGTH];
} chat_packet;


/*
 * comm driver status
 *
 */

typedef struct {
        unsigned ReceiveHolds;          /* count of receive flow holds */
        unsigned TransmitHolds;         /* count of transmit flow holds */
        unsigned OverrunErrors;         /* count of overflow errors */
        unsigned FramingErrors;         /* count of framing errors */
        char ErrorMessage[80];          /* last com error message */
} ComStatus;


/* -------------------------------------------------------------------- */
/* ---------- public constants ---------------------------------------- */
/* -------------------------------------------------------------------- */

extern char sender_name[];              /* protocol compatibility check */

/* size of the private workspace varies with memory model */
/* DO NOT CHANGE THESE LINES WITHOUT REGENERATING THE HDK LIBRARY! */

#ifndef STATIC_WORKSPACE
        #ifdef __SMALL__
                #define PRIVATE_WSSIZE 15092
        #endif
        #ifdef __LARGE__
                #define PRIVATE_WSSIZE 15096
        #endif
        #ifdef __HUGE__
                #define PRIVATE_WSSIZE 15096
        #endif

        #ifndef PRIVATE_WSSIZE
                #define PRIVATE_WSSIZE 15092
        #endif

        #ifndef PRIVATE
                typedef struct {
                        uchar hidden[PRIVATE_WSSIZE];
                } private_ws;
        #endif
#endif

/* -------------------------------------------------------------------- */
/* ---------- public working storage ---------------------------------- */
/* -------------------------------------------------------------------- */

typedef struct {

        ComStatus Comstat;               /* Comm port status */

        Options Option;                  /* option settings */

        int IoLevel;                     /* level of i/o nesting in -hs mode */

        unsigned buffer_sizes;           /* size of send and/or receive buffers */

        user_number remote_userid;       /* remote user number, if registered */
        char remote_version[8];          /* remote version */

        int files_received;              /* actual files received */
        long recv_bytes;                 /* actual bytes received */
        int receive_expected;            /* expected bytes to receive */

        int files_sent;                  /* actual files sent */
        long send_bytes;                 /* actual bytes sent */
        int send_expected;               /* expected bytes to send */

        pathname_node *first_send;       /* linked list of send filenames */
        pathname_node *last_send;

        long send_total;                 /* bytes sent, previous files */
        long send_current;               /* bytes sent, current file */
        long send_skip;                  /* bytes skipped at start of file */
        long send_skip_total;            /* total bytes skipped */
        int transmit_errors;
        int resend_count;                /* count of blocks retransmitted */

        long recv_total;                 /* bytes sent, previous files */
        long recv_current;               /* bytes received, current file */
        long recv_skip;                  /* bytes skipped at start of file */
        long recv_skip_total;            /* total bytes skipped */
        int receive_errors;
        int nak_count;                   /* count of blocks nak'd */
        int bad_message_codes;           /* count of bad message codes */

        clock_t begin_time;              /* clock when link started */
        clock_t rx_start;                /* clock when receive started */
        clock_t tx_start;                /* clock when transmit started */

        unsigned rx_cps;                 /* current receive cps */
        unsigned tx_cps;                 /* current transmit cps */

        int cancel_link;                 /* reason link is being cancelled */

        int hacked_remote;               /* flag that remote has been hacked */

        int chat_active;                 /* is chat mode active? */
        chat_packet chatout;             /* partial outgoing chatr pack */

        private_ws private;              /* private workspace used
                                            internally by the library */

} hslink_pub_ws;

#ifdef SWS
        #define STATIC_WORKSPACE
#endif

#ifdef STATIC_WORKSPACE
        /* we are compiling for a static workspace */

        extern hslink_pub_ws pub_ws;

        /* all references to public workspace variables must occur
           through the WS.item macro.  This allows later redefinition
           of how workspaces are allocated and accessed without major
           source changes. */

        #define WS pub_ws

#else
        /* we are compiling for dynamic workspaces and multi-threaded apps */

        typedef struct {
                hslink_pub_ws pub_ws;
        } workspace_rec;

        extern workspace_rec *current_hsws;

        /* all references to public workspace variables must occur
           through the WS.item macro.  This allows later redefinition
           of how workspaces are allocated and accessed without major
           source changes. */

        #define WS (current_hsws->pub_ws)
#endif

