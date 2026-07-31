
/*
 * COPYRIGHT 1992 SAMUEL H. SMITH
 * ALL RIGHTS RESERVED
 *
 * THIS DOCUMENT CONTAINS CONFIDENTIAL INFORMATION AND TRADE SECRETS
 * PROPRIETARY TO SAMUEL H. SMITH DBA THE TOOL SHOP.
 *
 */


/*
 * hsopt.h - HS/Link, command line option definitions and defaults
 *
 */

#define DEFAULT_BANG    FALSE                   /* Option.Priority */
#define DEFAULT_A       FALSE                   /* Option.DisableAck */
#define DEFAULT_B       0                       /* Option.ComSpeed */
#define DEFAULT_C       TRUE                    /* Option.RequireCarrier */
#define DEFAULT_CB      (BLACK*16)+LIGHTGRAY    /* Option.BorderAttr */
#define DEFAULT_CG      (BLACK*16)+YELLOW       /* Option.GraphAttr */
#define DEFAULT_CM      (GREEN*16)+WHITE        /* Option.MainAttr */
#define DEFAULT_CP      2                       /* Option.DispPos */
#define DEFAULT_CT      (RED*16)+WHITE          /* Option.TitleAttr */
#define DEFAULT_CW      (BLUE*16)+WHITE         /* Option.WindowAttr */
#define DEFAULT_D       FALSE                   /* Option.Debug */
#define DEFAULT_E       0                       /* Option.EffSpeed */
#define DEFAULT_FC      FALSE                   /* Option.ForceCts */
#define DEFAULT_FT      4                       /* Option.FifoThresh */
#define DEFAULT_HC      TRUE                    /* Option.CtsHandshake */
#define DEFAULT_HR      TRUE                    /* Option.RtsHandshake */
#define DEFAULT_HS      FALSE                   /* Option.SlowHandshake */
#define DEFAULT_HX      TRUE                    /* Option.XonHandshake */
#define DEFAULT_I       0                       /* Option.IdleMethod */
#define DEFAULT_K       FALSE                   /* Option.KeepAborted */
#define DEFAULT_LF      NULLSTR                 /* Option.StatusLogFile */
#define DEFAULT_N5      FALSE                   /* Option.Disable16550 */
#define DEFAULT_NA      TRUE                    /* Option.AlternateDle */
#define DEFAULT_NB      TRUE                    /* Option.FileBuffering */
#define DEFAULT_NC      TRUE                    /* Option.CodeSubstitution */
#define DEFAULT_NE      20                      /* Option.MaxError */
#define DEFAULT_NF      TRUE                    /* Option.FullDisplay */
#define DEFAULT_NG      FALSE                   /* Option.DisableCtlG */
#define DEFAULT_NM      FALSE                   /* Option.MinimalBlocks */
#define DEFAULT_NO      NULLSTR                 /* Option.DupeChecklist */
#define DEFAULT_NP      TRUE                    /* Option.DisablePartialBlocks */
#define DEFAULT_NT      TRUE                    /* Option.StampTime */
#define DEFAULT_NU      FALSE                   /* Option.BlockUpload */
#define DEFAULT_NV      TRUE                    /* Option.DirectVideo */
#define DEFAULT_O       FALSE                   /* Option.AllowOverwrite */
#define DEFAULT_P       1                       /* Option.ComPort */
#define DEFAULT_PB      0                       /* Option.ComBase */
#define DEFAULT_PI      0                       /* Option.ComIrq */
#define DEFAULT_R       FALSE                   /* Option.ResumeVerify */
#define DEFAULT_S       1024                    /* Option.BlockSize */
#define DEFAULT_T       FALSE                   /* Option.TermMode */
#define DEFAULT_U       NULLSTR                 /* Option.ReceiveDir */
#define DEFAULT_W       8                       /* Option.MaxWind */
#define DEFAULT_CRCSZ   3 /* DO NOT CHANGE! */  /* Option.CrcSize */

/* disable rest of this file when making options.i for hsconfig */
#ifndef IN_OPTIONS

/* define the pascal builtin constants */
#define TRUE 1
#define FALSE 0
#define NULLSTR ""

typedef struct {
        /* option flags */
        uchar AllowOverwrite;           /* allow incoming files to overwrite
                                           existing files */
        uchar BlockUpload;              /* block all incoming files */
        uchar CodeSubstitution;         /* enable code substitution logic */
        uchar Debug;                    /* enable debugging logic */
        uchar DirectVideo;              /* direct video status display */
        uchar Disable16550;             /* disable 16550 buffering logic */
        uchar AlternateDle;             /* use DLE of 0x40 instead of 0x80? */
        uchar FifoThresh;               /* 16550 fifo threshold */
        uchar DisableAck;               /* disable ACK request for each block */
        uchar DisableCtlG;              /* disable BELL codes in CHAT mode */
        uchar DisablePartialBlocks;     /* disable partial block logic */
        uchar FileBuffering;            /* enable file buffering */
        uchar FullDisplay;              /* enable full screen status display */
        uchar KeepAborted;              /* keep aborted transfers */
        uchar MinimalBlocks;            /* enable minimal blocks logic */
        uchar Priority;                 /* force remote to use local settings */
        uchar RequireCarrier;           /* require carrier detect signal */
        uchar ResumeVerify;             /* attempt to resume aborted xfers */
        uchar StampTime;                /* stamp time on incoming files */
        uchar TermMode;                 /* mini terminal mode */

        char StatusLogFile[65];         /* status logging file */
        char DupeChecklist[65];         /* filename for duplicate checklist */
        char ReceiveDir[65];            /* incoming files directory */
        int BlockSize;                  /* transfer block size */
        int CrcSize;                    /* data CRC size */
        uchar IdleMethod;               /* how to discard idle time */
        int MaxWind;                    /* maximum ACK window */
        int MaxError;                   /* maximum repeated errors */

        /* display color definition */
        int BorderAttr;                 /* color of screen border */
        int GraphAttr;                  /* color of bargraphs */
        int MainAttr;                   /* color of main display */
        int TitleAttr;                  /* color of titles */
        int WindowAttr;                 /* color of windows */
        int DispPos;                    /* display position rel to screen */

        /* handshake options */
        uchar CtsHandshake;              /* enable CTS hardware handshake */
        uchar ForceCts;                  /* force CTS even if not initially on */
        uchar RtsHandshake;              /* enable RTS hardware handshake */
        uchar SlowHandshake;             /* enable "slow" handshake mode */
        uchar XonHandshake;              /* enable XON/XOFF software handshake */

        /* com port settings */
        int ComPort;                    /* standard com port number */
        int ComBase;                    /* non-standard com port base address */
        int ComIrq;                     /* non-standard com IRQ number */
        long ComSpeed;                  /* actual com port speed */
        long EffSpeed;                  /* effective com port speed */
} Options;


void pascal set_defaults(void);
int pascal process_options(int argc, char **argv);
int pascal process_command_option(char *arg);
int pascal load_config_file(char *fname);
int pascal load_default_config(void);

void pascal process_filespecs(int argc, char **argv);
void pascal queue_transmit(char *spec);

#endif

