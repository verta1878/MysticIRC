
/*
 * COPYRIGHT 1992 SAMUEL H. SMITH
 * ALL RIGHTS RESERVED
 *
 * THIS DOCUMENT CONTAINS CONFIDENTIAL INFORMATION AND TRADE SECRETS
 * PROPRIETARY TO SAMUEL H. SMITH DBA THE TOOL SHOP.
 *
 */


/*
 * hstop.c - Top level driver for HS/LINK protocol.
 *             
 */

#include <stdlib.h>
#include <stdio.h>
#include <io.h>
#include <conio.h>
#include <ctype.h>
#include <dos.h>

#ifdef __TURBOC__
#include <dir.h>
#include <alloc.h>
#endif

#include <string.h>
#include <fcntl.h>

#define extern
#include "hdktext.h"
#include "hspriv.h"
#include <hdk.h>
#undef extern

/* -------------------------------------------------------------- */

char sender_name[] =    "HS/LinkDK 1.22";

char hdk_compdate[] =   "HDK Compiled "
                        __DATE__
                        " "
                        __TIME__
                        "\r\n";

char hdk_target[] =    "Target: "

#ifdef __TINY__
                        "TINY "
#endif
#ifdef __SMALL__
                        "SMALL "
#endif
#ifdef __MEDIUM__
                        "MEDIUM "
#endif
#ifdef __COMPACT__
                        "COMPACT "
#endif
#ifdef __LARGE__
                        "LARGE "
#endif
#ifdef __HUGE__
                        "HUGE "
#endif
#ifdef __MULTI_THREAD__
                        "MULTI_THREAD "
#endif
#ifdef __SINGLE_THREAD__
                        "SINGLE_THREAD "
#endif
#ifdef __DLL__
                        "DLL "
	#define cprintf printf
#endif
#ifdef __OS2__
                        "OS2 "
#endif
#ifdef __MSDOS__
                        "MSDOS "
#endif
#ifdef __TURBOC__
                        "TURBOC "
#endif
#ifdef __TCPLUSPLUS__
                        "TCPLUSPLUS "
#endif
#ifdef __OVERLAY__
                        "OVERLAY "
#endif
#ifdef __DLLSMALL__
                        "DLLSMALL "
#endif
#ifdef __BORLANDC__
                        "BORLANDC "
#endif
#ifdef __BCOPT__
                        "BCOPT "
#endif
#ifdef __BCPLUSPLUS__
                        "BCPLUSPLUS "
#endif
#ifdef __TEMPLATES__
                        "TEMPLATES "
#endif
#ifdef __PASCAL__
                        "PASCAL "
#endif
#ifdef __FASTCALL__
                        "FASTCALL "
#endif
#ifdef __CDECL__
                        "CDECL "
#endif

#ifdef STATIC_WORKSPACE
                        "STATIC "
#else
                        "DYNAMIC "
#endif

#ifdef LANG_ENGLISH
                        "ENGLISH "
#endif
#ifdef LANG_GERMAN
                        "GERMAN "
#endif

                        "\r\n";


/* -------------------------------------------------------------- */

/* initialize top level variables - returns non-0 on failure */

int pascal top_init(void)
{
#ifndef __DLL__
        directvideo = 0;        /* disable directvideo until cmdline parsed */
#endif

#ifndef STATIC_WORKSPACE
        #ifdef __TURBOC__
                #if (sizeof(private_ws) != PRIVATE_WSSIZE)
                        cprintf("RECOMPILE HDK WITH PRIVATE_WSSIZE=%u\r\n",sizeof(private_ws));
                        return 1;
                #endif

        #else
                if (sizeof(private_ws) != PRIVATE_WSSIZE)
                {
                        cprintf("RECOMPILE HDK WITH PRIVATE_WSSIZE=%u\r\n",sizeof(private_ws));
                        return 1;
                }
        #endif

        if (current_hsws == 0)
        {
                cprintf("HDK: no workspace!\r\n");
                return 1;
        }
#endif

        WS.IoLevel = 1;         /* disable SlowHandshake until we're ready */

        PRIVATE.transmit_context = 0;
        PRIVATE.ready_context = 0;
        PRIVATE.finish_context = 0;
        PRIVATE.terminate_context = 0;
        return 0;
}


/* -------------------------------------------------------------- */

/* wait for the remote to indicate it is ready to receive a file */

int pascal wait_for_ready()
{
        switch (PRIVATE.ready_context)
        {
        case 0:
                PRIVATE.ready_timeout = SET_TIMER(READY_TIMEOUT);
                PRIVATE.enquire_timeout = SET_TIMER(ENQ_TIMEOUT);
                send_ready(READY_INITIAL);

                return PRIVATE.ready_context = 1;

        case 1:
                if (ComCarrierLost())
                        return PRIVATE.ready_context = 2;

                if (TIMER_UP(PRIVATE.enquire_timeout))
                {
                        clreol();
                        send_ready(READY_INITIAL);
                        ComFlush(1);   /* cancel xoff while flushing */
                        PRIVATE.enquire_timeout = SET_TIMER(ENQ_TIMEOUT);
                        PRECV(TX_WAITING);
                }

                if (TIMER_UP(PRIVATE.ready_timeout))
                {
                        ERECV(TX_NORESP);
                        set_cancel_link(CANCEL_REMOTE_TIMEOUT);
                }

                if (PRIVATE.ready_pending)
                {
                        if (!PRIVATE.remote_ready.final_ready)
                        {
                                send_ready(READY_FINAL);
                                PRIVATE.enquire_timeout = SET_TIMER(ENQ_TIMEOUT);
                        }

                        PRIVATE.ready_pending = 0;

                        if (PRIVATE.remote_ready.final_ready)
                                return PRIVATE.ready_context = 2;
                }

                if (PRIVATE.skip_file_pending || WS.cancel_link || PRIVATE.transmit_done_pending)
                        return PRIVATE.ready_context = 2;

                if (PRIVATE.recv_fd.handle > 1)
                        return PRIVATE.ready_context = 2;

                return PRIVATE.ready_context = 1;


        case 2:
                display_settings();

                if (PRIVATE.remote_ready.final_ready)
                        send_ready(READY_FINAL);

                /* use a single large buffer for unidirectional mode, or
                   split memory into two buffers for bidirectional mode */

                if (WS.send_expected && WS.receive_expected)
                        WS.buffer_sizes /= 2;

                return PRIVATE.ready_context = 0;
        }

        return PRIVATE.ready_context = 0;
}


/* -------------------------------------------------------------- */

/* wait for remaining receive activity to terminate */
/* must be called repeatedly until 0 is returned */

int pascal finish_receive(void)
{
        switch (PRIVATE.finish_context)
        {
        case 0:
                if (WS.cancel_link == CANCEL_KEYBOARD)
                        return PRIVATE.finish_context = 2;

                /* indicate end-of-transmit-session */
                transmit_message(PACK_TRANSMIT_DONE, NULL, 0);
                return PRIVATE.finish_context = 1;

        case 1:
                if (!ComWritePending())
                        send_chat_block();

                if (ComCarrierLost())
                        return PRIVATE.finish_context = 2;

                if (WS.cancel_link)
                        return PRIVATE.finish_context = 2;

                if (PRIVATE.transmit_done_pending)
                        if (!WS.chat_active ||
                            TIMER_UP(PRIVATE.chat_close_timeout))
                                return PRIVATE.finish_context = 2;

                if (PRIVATE.ready_pending)
                {
                        if (!PRIVATE.remote_ready.final_ready)
                                send_ready(READY_FINAL);
                        PRIVATE.ready_pending = 0;
                }

                return PRIVATE.finish_context = 1;

        case 2:
                if (PRIVATE.transmit_done_pending)
                        if (WS.cancel_link != CANCEL_KEYBOARD)
                                WS.cancel_link = 0;

                return PRIVATE.finish_context = 0;
        }

        return PRIVATE.finish_context = 0;
}


/* -------------------------------------------------------------- */

/* close down and prepare for exit */

int pascal terminate_link(void)
{
        static uchar c,pc;
        static uchar cancels[] = {CAN_CHR, CAN_CHR, CAN_CHR, CAN_CHR, CAN_CHR, CAN_CHR};

        switch (PRIVATE.terminate_context)
        {
        case 0:
                close_active_file(3);
                ComWriteStr(cancels,sizeof(cancels));
                PRIVATE.term_timeout = SET_TIMER(TERMINATE_TIMEOUT);
                return PRIVATE.terminate_context = 1;

        case 1:
                pc = c;
                c = PRE_READ;
                if (PRE_READ_OK)
                {
                        if ((c == CAN_CHR) ||
                            ((c == '\n') && (pc == '\r')) ||
                            (PRIVATE.can_count > CANCEL_COUNT+2))
                                return PRIVATE.terminate_context = 2;

                        PRIVATE.term_timeout = SET_TIMER(TERMINATE_TIMEOUT);
                }

                return PRIVATE.terminate_context =
                        TIMER_UP(PRIVATE.term_timeout)? 2:1;

        case 2:
                if (PRIVATE.transmit_done_pending && (WS.cancel_link == CANCEL_REMOTE))
                        WS.cancel_link = 0;
                return PRIVATE.terminate_context = 0;
        }

        return PRIVATE.terminate_context = 0;
}

/* -------------------------------------------------------------------- */

/* set cancel_link code */
void pascal set_cancel_link(int code)
{
        if (WS.cancel_link < code)
                WS.cancel_link = code;

        /* release pending flow control under serious error conditions */
        switch (code)
        {
        case CANCEL_REMOTE_TIMEOUT:
        case CANCEL_FLOW_LOCKUP:
        case CANCEL_EXCESS_ERRORS:
        case CANCEL_KEYBOARD:
                WS.Option.CtsHandshake = 0;     // disable CTS handshake
                ComSetHandshake();              // notify comm driver
                break;
        }
}


