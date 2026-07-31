
/*
 * COPYRIGHT 1992 SAMUEL H. SMITH
 * ALL RIGHTS RESERVED
 *
 * THIS DOCUMENT CONTAINS CONFIDENTIAL INFORMATION AND TRADE SECRETS
 * PROPRIETARY TO SAMUEL H. SMITH DBA THE TOOL SHOP.
 *
 */

/*
 * hspriv.h - HS/Link, private declarations (not visible in HDK)
 *
 */

/* -------------------------------------------------------------------- */
/* ---------- prerequisite headers ------------------------------------ */
/* -------------------------------------------------------------------- */

#include <sys\types.h>
#include <sys\timeb.h>

#ifndef SH_DENYNONE
#define SH_DENYNONE _SH_DENYNO
#endif

#include <hdktypes.h>
#include "\hdk\hsbuf.h"


/* -------------------------------------------------------------------- */
/* ---------- special constants --------------------------------------- */
/* -------------------------------------------------------------------- */

#define MAX_BLOCK_SIZE 4096     /* max size of all data blocks */

#define MAX_PENDING (WS.Option.EffSpeed/16)
                                /* max chars pending for transmit before
                                   a new file data block may be enqued */

#define ACK_TIMEOUT 20000       /* milisec before ACK/FLOW timeout */

#define MAX_TIMEOUT 4           /* number of ACK timeouts to cancel link */

#define RCV_TIMEOUT_N 22000     /* idle ms before rx timeout, no packet */
#define RCV_TIMEOUT_P 11000     /* idle ms before rx timeout, partial packet */

#define READY_TIMEOUT 120000    /* milisec before ready handshake timeout */

#define ENQ_TIMEOUT 5000        /* milisec before sending another ready/
                                   enquire packet */

#define VERIFY_TIMEOUT 60000    /* additional milisec before verify/resume timeout */

#define TERMINATE_TIMEOUT 500   /* modem idle time before exiting when
                                   terminating a link and ^X is not
                                   received */

#define SLOW_TIMEOUT 110        /* milisec delay after flow hold in -hs mode */

#define SLOW_FAILURE 3000       /* milisec delay after -hs failure assumed */

#define KEYBOARD_POLL_TIME 110  /* milisec delay between keyboard polls */

#define CHAT_TIMEOUT 2000       /* milisec delay between outgoing chat blocks */

#define CHAT_CLOSE   30000      /* milisec of idle time before chat closes */

#define DEF_CRC_SIZE 3          /* default to 24 bit crcs */

#define CANCEL_COUNT 4          /* number of CAN's needed to cancel */

#define MAX_OVERRUN 4           /* number of overrun errors to trigger
                                   automatic -HS */

#define MAX_FRAMING 50          /* number of framing errors to abort
                                   link (i.e. wrong -B setting) */


/*
 * characters that have a special meaning at the character level
 *
 */

enum special_characters {
        START_PACKET_CHR    = 0x02,     /* packet leadin */

        XON_CHR             = 0x11,     /* flow control */
        XOFF_CHR            = 0x13,

        CAN_CHR             = 0x18,     /* CONTROL X */

        END_PACKET_CHR      = 0x1b,     /* packet end marker (must be >
                                           other specials except DLE) */

        DLE_CHR             = 0x1e,     /* packet data "escape" prefix */
};


/*
 * values of ready_pending
 *
 */
enum ready_pending_codes {
        READY_INITIAL           = 1,
        READY_FINAL             = 2,
        READY_SEND_VERIFY       = 3,
        READY_SEND_FILE         = 4,
};


/*
 * message type codes,
 *
 */

enum message_types {
        PACK_ACK_BLOCK          = 'A',  /* ... sequence_packet */
        PACK_CLOSE_FILE         = 'C',  /* ... */
        PACK_DATA_BLOCK_SMD     = 'D',  /* ... sequence+mapping+data */
        PACK_DATA_BLOCK_MD      = 'E',  /* ... mapping+data */
        PACK_DATA_BLOCK_D       = 'F',  /* ... data */
        PACK_CHAT_BLOCK         = 'H',  /* ... text */
        PACK_SKIP_FILE          = 'K',  /* ... */
        PACK_EXTNAK_BLOCK       = 'M',  /* ... extnak_packet */
        PACK_NAK_BLOCK          = 'N',  /* ... sequence_packet */
        PACK_OPEN_FILE          = 'O',  /* ... file_header_packet */
        PACK_RESET_FILE         = 'P',  /* ... */
        PACK_READY_RECV         = 'Q',  /* ... */
        PACK_READY              = 'R',  /* ... */
        PACK_SEEK_BLOCK         = 'S',  /* ... block_spec_packet */
        PACK_VERIFY_BLOCK       = 'V',  /* ... ResumeVerify_packet */
        PACK_TRANSMIT_DONE      = 'Z',  /* ... */
};


/* -------------------------------------------------------------------- */
/* ---------- private data types -------------------------------------- */
/* -------------------------------------------------------------------- */


typedef unsigned char file_number;      /* current file number */

typedef unsigned long CRC_type;         /* data CRCs */


/*
 * protocol ready packet structure
 *
 */

typedef struct {
        char sender[16];        /* sending program identification */

        CRC_type text_CRC;      /* actual CRC of sender's text segment */

        int MaxWind;            /* -w */
        int BlockSize;          /* -s */
        user_number userid;     /* our user number, if registered */

        CRC_type proper_CRC;    /* proper CRC of sender's text segment */

        int Priority:1;         /* -! */
        int DisableAck:1;       /* -a */
        int XonHandshake:1;     /* -hx */
        int ResumeVerify:1;     /* -r */

        int open_handshake:1;   /* -r is this an open handshake packet? */
        int open_verify:1;      /* -r send verification blocks? */

        int MinimalBlocks:1;    /* -nm */

        int final_ready:1;      /* flags no more ready packets expected */

        int partial_blocks:1;   /* -np extended nak capable */

        int alternate_dle:1;    /* use 0x40 instead of 0x80 in dle sequences */

        int spare12:1;          /* spare flag bits */
        int spare13:1;
        int spare14:1;
        int spare15:1;
        int spare16:1;
        int spare17:1;

        char spare3[3];         /* spare bytes */

        unsigned trans_files;   /* number of files to transmit */
        long trans_bytes;       /* number of bytes to transmit */

} ready_packet;



/*
 * file header packet structure
 *
 */

typedef struct {
        char name[13];          /* full filename */
        long size;              /* size of file in bytes */
        block_number blocks;    /* size of file in blocks */
        int BlockSize;          /* data block size used during transfer */
#ifdef __TURBOC__
        struct ftime time;      /* file modification time/data */
#else
        struct _timeb time;     /* file modification time/data */
#endif
        file_number batch;      /* current file number in batch */
        char spare[20];
} file_header_packet;


/*
 * size of data a data block in file
 * returns BlockSize for all but last record
 * returns remainder of file size for last record
 *
 */

#define FINAL_BLOCK_SIZE(FHDR) (FHDR.size%FHDR.BlockSize? (FHDR.size%FHDR.BlockSize) : FHDR.BlockSize)

#define BLOCK_SIZE(FHDR,BLOCK) ((BLOCK)==FHDR.blocks? FINAL_BLOCK_SIZE(FHDR) : FHDR.BlockSize)


/*
 * total bytes of file up to and including specified block number
 *
 */

#define BLOCK_BYTES(FHDR,BLOCK) ((long)FHDR.BlockSize*(long)(BLOCK-1L) + BLOCK_SIZE(FHDR,BLOCK))


/*
 * sequence number packet structure
 *
 */

typedef struct {
        file_number batch;              /* current file number in batch */
        block_number block;             /* current block within file */
} sequence_packet;


/*
 * control character mapping structure
 *
 */

typedef struct {
        uchar xon_map;                   /* mapped code for XON codes */
        uchar xoff_map;                  /* mapped code for XOFF codes */
        uchar dle_map;                   /* mapped code for DLE codes */
        uchar start_map;                 /* mapped code for START codes */
        uchar end_map;                   /* mapped code for END codes */
} control_mapping;


/*
 * full data packet structure
 *
 */

typedef struct {
        sequence_packet seq;            /* current file and block numbers */
        control_mapping map;            /* control code mappings */
        uchar data[MAX_BLOCK_SIZE];     /* the data content of the packet */
} data_packet;


/*
 * data block types
 *
 */
enum data_block_parts {
        SEQ_BLOCK=1,     /* data_packet has sequence number */
        MAP_BLOCK=2,     /* data_packet has control_mapping block */
        DATA_BLOCK=0     /* data_packet has data block */
};

/*
 * extended NAK packet
 *
 */

#define EXTNAK_COUNT 8

typedef struct {
        sequence_packet seq;            /* location or error */
        uchar nak_reason;               /* reason block was nak'd */
        uchar errlsr;                   /* LSR bits at time of error */
        long errcsip;                   /* CS:IP at time of error */
        CRC_type check[EXTNAK_COUNT];   /* crcs of partial blocks */
} extnak_packet;


/*
 * resume verification packet
 *
 */

#define MAX_VERIFY_COUNT 100

typedef struct {
        block_number base_block;
        int count;
        CRC_type check[MAX_VERIFY_COUNT];
} resume_verify_packet;


/*
 * receive buffering packet - must hold the largest possible packet
 *                            including all overhead bytes
 */

#define MAX_BUFFER (sizeof(data_packet)+1000)

typedef struct {
        int nextin;             /* next byte to put into the buffer */
        int nextout;            /* next byte to take out of buffer */
        uchar data[MAX_BUFFER];
} buffering_packet;


/*
 * pre-buffering packet - used to minimize calls ComRead
 *
 */

#define MAX_PREBUF 95

typedef struct {
        int count;              /* count of bytes in the buffer */
        int next;               /* next byte to access in buffer */
        uchar data[MAX_PREBUF+1];
} prebuf_packet;


/* -------------------------------------------------------------------- */
/* ---------- private working storage --------------------------------- */
/* -------------------------------------------------------------------- */

typedef struct {

        block_number ack_pending;       /* flags from received messages */
        block_number nak_pending;
        block_number seek_pending;
        int ready_pending;
        int reset_file_pending;
        int skip_file_pending;
        int transmit_done_pending;      /* no more files to send */

        int can_count;
        uchar rcv_pc;

        int prev_error_code;
        uchar prev_error_count;

        long block_time;                /* expected time per block in ms */

        unsigned max_pending;           /* max chars pending for transmit
                                           before a new block may be enqued */

        ready_packet remote_ready;      /* current ready packet from remote */
        file_header_packet send_file;   /* current file being sent */
        buffering_packet rxbuf;         /* current receive buffering packet */
        prebuf_packet prerx;            /* pre-receive buffering */
        prebuf_packet pretx;            /* pre-transmit buffering */

        extnak_packet extnak;
        buffered_file recv_fd;          /* current receive file */
        char exe_path[65];              /* usually argv[0] */

/* hsrecv private data */

        file_header_packet recv_file;
        data_packet recv_pack;           /* current receive data packet */

        block_number highest_valid;      /* highest valid block we've seen */
        block_number repeat_expected;    /* rejected block we are waiting for */
        block_number last_received;      /* the latest block no received */
        block_number prior_received;     /* the block prior to last_received */
        block_number last_naked;         /* most recent NAK sent */
        block_number last_rxack;         /* most recent ACK sent */
        block_number last_seek;          /* most recent SEEK sent */

        clock_t rx_idle_timeout;         /* clock when last received data */

        clock_t chat_timeout;            /* controls sending next chat block */
        clock_t chat_close_timeout;      /* controls closure of chat mode */

        int verify_completed;
        int last_receive_size;

        #define MAX_RECEIVE_AHEAD 500
        block_number receive_ahead_table[MAX_RECEIVE_AHEAD];

/* hstrans private data */

        data_packet send_pack;
        buffered_file send_fd;

        int txbatch;
        block_number prev_block;


/* hstrans::transmit_file static variables */

        int curwindow;
        block_number last_sent;
        block_number last_txack;
        block_number next_verify;
        clock_t idle_timeout;
        int ptx_pending;
        char logcode;
        int verify_active;
        int verify_requested;
        long ack_timeout;
        int timeout_count;

/* hstop static variables */

        int transmit_context;           /* hstop context variables */
        int ready_context;
        int finish_context;
        int terminate_context;

        clock_t enquire_timeout;
        clock_t ready_timeout;
        clock_t term_timeout;

        char spare[62];          /* spare bytes in private workspace */

} private_ws;


/* all references to workspace variables must occur through the
   PRIVATE.item macro.  This allows later redefinition of how workspaces
   are allocated and accessed without major source changes. */

#define PRIVATE WS.private


/* shorthand names for some common data structures */

#define RECV_FILE PRIVATE.recv_file
#define SEND_FILE PRIVATE.send_file
#define LAST_SENT PRIVATE.last_sent
#define RA_TABLE PRIVATE.receive_ahead_table
#define REMOTE_READY PRIVATE.remote_ready
#define PRERX PRIVATE.prerx
#define PRETX PRIVATE.pretx

/* read next character using prebuffer */
#define PRE_READ \
   ((PRERX.next < PRERX.count) ?                      \
      PRERX.data[PRERX.next++] :                      \
      (PRERX.count=ComReadStr(PRERX.data,MAX_PREBUF), \
       PRERX.next=1,                                  \
       PRERX.data[0]) )

/* see if the previous call to PRE_READ worked or not */
#define PRE_READ_OK (PRERX.next <= PRERX.count)

/* write next character using prebuffer */
#define PRE_WRITE(SRC) \
   {  PRETX.data[PRETX.count++] = SRC;        \
      if (PRETX.count >= MAX_PREBUF) {        \
         ComWriteStr(PRETX.data,PRETX.count); \
         PRETX.count = 0;                     \
      }                                       \
   }

/* flush contents of write prebuffer */
#define PRE_WRITE_FLUSH \
   {  if (PRETX.count) {                      \
         ComWriteStr(PRETX.data,PRETX.count); \
         PRETX.count = 0;                     \
      }                                       \
   }


/* -------------------------------------------------------------------- */
/* ---------- library identification variables ------------------------ */
/* -------------------------------------------------------------------- */

extern char sender_name[40];
extern char hdk_copyright[];
extern char hdk_license[];
extern char hdk_compdate[];
extern char hdk_target[];

extern CRC_type proper_CRC;             /* result of setcrc.exe */
extern CRC_type text_CRC;               /* actual crc of exe file */


/* -------------------------------------------------------------------- */
/* ---------- private procedure prototypes ---------------------------- */
/* -------------------------------------------------------------------- */

void pascal transmit_message(enum message_types message_type,
                      uchar *data,
                      int data_size);
        /* defined in hstrans.c */

void pascal close_active_file( int who );
        /* defined in hsrecv.c */

void pascal send_ready( int final );
        /* defined in hsrecv.c */


/* -------------------------------------------------------------------- */
/* ---------- other "private" headers --------------------------------- */
/* -------------------------------------------------------------------- */

#include "\hdk\debug.h"
#include "\hdk\hsmisc.h"
#include "\hdk\hscrc.h"

