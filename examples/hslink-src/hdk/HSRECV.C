#undef DEBUG
/*
 * COPYRIGHT 1992 SAMUEL H. SMITH
 * ALL RIGHTS RESERVED
 *
 * THIS DOCUMENT CONTAINS CONFIDENTIAL INFORMATION AND TRADE SECRETS
 * PROPRIETARY TO SAMUEL H. SMITH DBA THE TOOL SHOP.
 *
 */

/*
 * hsrecv.c - HS/Link, receive handler
 *
 * This module decodes all receive packets and performs the proper
 * action for each packet type.  This forms the "receive side" of
 * all transfers.
 *
 * All calls to 'service_receive()' are required to
 * quickly return, allowing the caller to do other things (sending
 * files in the other direction, for instance)
 *
 */

#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <io.h>
#include <dos.h>
#include <conio.h>
#include <fcntl.h>
#include <share.h>
#include <sys\types.h>
#include <sys\stat.h>

#include "hdktext.h"
#include "hspriv.h"
#include <hdk.h>


/* -------------------------------------------------------------------- */

/* prototypes for private procedures */

static void pascal process_packets(void);

static void pascal process_ready(void);

static void pascal process_open_file(void);
static void pascal process_close_file(void);

static void pascal process_chat_block(void);

static void pascal process_ack_block(void);
static void pascal process_nak_block( int extended );
static void pascal process_seek_block(void);

static void pascal process_verify_block(void);

static void pascal process_data_block( int btype );

static void pascal process_skip_file(void);
static void pascal process_reset_file(void);
static void pascal process_transmit_done(void);

static void pascal send_SKIP( block_number block, int reason );
static void pascal send_RESET( int who );
static void pascal send_ACK( block_number block, int who );
static void pascal send_NAK( block_number block, int reason );
static void pascal send_SEEK( block_number block,int who );

static void pascal mark_block_received( block_number block );
static int pascal block_already_received( block_number block );

static int pascal receive_block(uchar *buf,
                         int size);


#define RXBUF PRIVATE.rxbuf
        /* receive buffer shorthand */

#define RXCHAR  (RXBUF.data[RXBUF.nextout++])
        /* return next byte from buffering packet */


/* -------------------------------------------------------------------- */
/* process receive channel, does received files in the
   background, sets ack_pending, nak_pending */

/*
 * All calls to 'service_receive()' are required to
 * quickly return, allowing the caller to do other things (sending
 * files in the other direction, for instance)
 *
 */

static int svc_rx_recur = 0;

void pascal service_receive()
{
        int c;

        if (svc_rx_recur)
                return;
        ++svc_rx_recur;

        /*
         * read characters, checking for possible timeout condition
         *
         */
        c = PRE_READ;

        if (!PRE_READ_OK)
        {

                if (PRIVATE.recv_fd.handle <= 0)
                {
                        svc_rx_recur--;
                        return;
                }

                /* reset idle timeout if needed */
                if (PRIVATE.rx_idle_timeout == 0)
                        PRIVATE.rx_idle_timeout = SET_TIMER(RCV_TIMEOUT_N);

                if (TIMER_UP(PRIVATE.rx_idle_timeout))
                {
#ifdef DEBUG
                        if (WS.Option.Debug)
                        {
                                int i;
                                printf("svrx: timeout, nextin=%d RXBUF=",RXBUF.nextin);
                                for (i=0; i<RXBUF.nextin; i++)
                                        printf("%02x ",RXBUF.data[i]);
                                printf("\n");
                        }
#endif
                        PRIVATE.rx_idle_timeout = 0;

                        /* if receiving, re-ack the last block, otherwise
                           tell the other side we're ready */

                        if (PRIVATE.last_received)
                        {
                                send_ACK(PRIVATE.last_received,21);
                                send_SEEK /*NAK*/ (PRIVATE.last_received+1, 1);
                        }

                        report_rx_error(TX_RXTO);
                        ComCancelXoff();
                        limit_errors(101);
                }

                svc_rx_recur--;
                return;
        }

        /*
         * move characters from rxque into rxbuf until we have
         * found a full packet.
         *
         */

        if (RXBUF.nextin >= 10)
                PRIVATE.rx_idle_timeout = SET_TIMER(RCV_TIMEOUT_P);

        while (PRE_READ_OK)
        {
#ifdef DEBUG
                if (WS.Option.Debug) printf("svrx: c=%02x nextin=%d\n",c,RXBUF.nextin);
#endif
                if ((RXBUF.nextin != 0) || (c == START_PACKET_CHR))
                {

                        /* add the character to the rxbuf */
                        if (RXBUF.nextin >= MAX_BUFFER-1)
                        {
                                ERECV(TX_RXBUFOV,RXBUF.nextin,MAX_BUFFER,c);
                                /*--RXBUF.nextin;*/ /*D6*/
                                RXBUF.nextin = 0;       /*???*/
                        }

#ifdef DEBUG
                        if ((RXBUF.nextin > 0) && (c == START_PACKET_CHR))
                        {
                                printf("[MISSING END CODE, nextin=%d]\n",RXBUF.nextin);
                                RXBUF.data[RXBUF.nextin++] = END_PACKET_CHR;
                                process_packets();
                        }
#endif
                        // filter false flow control characters
                        if (!WS.Option.XonHandshake)
                                RXBUF.data[RXBUF.nextin++] = c;
                        else

                        switch (c)
                        {
                        case XON_CHR+0x80:
                        case XOFF_CHR+0x80:
                                if (WS.Option.AlternateDle)
                                        break;

                                RXBUF.data[RXBUF.nextin++] = c;
                                break;

                        case XON_CHR:
                        case XOFF_CHR:
                                break;

                        default:
                                RXBUF.data[RXBUF.nextin++] = c;
                                break;
                        }
                }

                /* check for cancel sequence */
                if (c == CAN_CHR)
                {
                        if (PRIVATE.rcv_pc != CAN_CHR)
                                PRIVATE.can_count = 1;
                        else
                        if (++PRIVATE.can_count >= CANCEL_COUNT)
                                set_cancel_link(CANCEL_REMOTE);
                }
                else

                /* process completed packets */
                if (c == END_PACKET_CHR)
                {
                        if (RXBUF.nextin > 0)
                                process_packets();
                        PRIVATE.rx_idle_timeout = SET_TIMER(RCV_TIMEOUT_N);
                }

                PRIVATE.rcv_pc = c;
                c = PRE_READ;
        }

        svc_rx_recur--;
}

/* -------------------------------------------------------------------- */

/*
 * process a receive message contained in rxbuf.
 *
 */

void pascal process_packets()
{
        enum message_types message_type;

        /* act upon the message based on the message_type */

        /* find first byte following START_PACKET byte */
        do
                message_type = RXCHAR;
        while (message_type == START_PACKET_CHR);

#ifdef DEBUG
        if (WS.Option.Debug)
                printf("\n{RX TYPE %c} ",message_type);
#endif

        switch (message_type)
        {
        case END_PACKET_CHR:
                break;

        case PACK_READY:
                WS.receive_expected = 1;
                /* fall through */

        case PACK_READY_RECV:
                process_ready();
                break;

        case PACK_OPEN_FILE:
                process_open_file();
                break;

        case PACK_CLOSE_FILE:
                process_close_file();
                break;

        case PACK_DATA_BLOCK_SMD:
                process_data_block(SEQ_BLOCK|MAP_BLOCK|DATA_BLOCK);
                break;

        case PACK_DATA_BLOCK_MD:
                process_data_block(MAP_BLOCK|DATA_BLOCK);
                break;

        case PACK_DATA_BLOCK_D:
                process_data_block(DATA_BLOCK);
                break;

        case PACK_CHAT_BLOCK:
                process_chat_block();
                break;

        case PACK_ACK_BLOCK:
                process_ack_block();
                break;

        case PACK_EXTNAK_BLOCK:
                process_nak_block(1);
                break;

        case PACK_NAK_BLOCK:
                process_nak_block(0);
                break;

        case PACK_SEEK_BLOCK:
                process_seek_block();
                break;

        case PACK_VERIFY_BLOCK:
                process_verify_block();
                break;

        case PACK_SKIP_FILE:
                process_skip_file();
                break;

        case PACK_RESET_FILE:
                process_reset_file();
                break;

        case PACK_TRANSMIT_DONE:
                process_transmit_done();
                break;

        default:
                ERECV(TX_BADMSGCODE,message_type);
                ++WS.bad_message_codes;
                limit_errors(103);
        }

        /* reset framing error count after valid packet */
        WS.Comstat.FramingErrors = 0;

        /* reset receiver buffering */
        RXBUF.nextout = 0;
        RXBUF.nextin = 0;
        /* mem_clear(RXBUF.data,sizeof(RXBUF.data)); */
}



/* -------------------------------------------------------------------- */

/*
 * process an ACK_BLOCK message and set the ack_pending variable
 *
 */

void pascal process_ack_block()
{
        sequence_packet acknak;

        if (receive_block((uchar *) &acknak, sizeof(acknak)))
        {
                ERECV(TX_BADACKCRC,(int) acknak.block);
                limit_errors(104);
        }
	else

        if (acknak.batch != SEND_FILE.batch)
        {
                if (acknak.batch > SEND_FILE.batch)
                {
                        ERECV(TX_BADACKBAT,
                                (int)acknak.batch,
                                (int)SEND_FILE.batch,
                                (int)acknak.block);

                        limit_errors(105);
                        send_RESET(1);
                }
        }
        else

        if (acknak.block > SEND_FILE.blocks)
        {
                /* bad ack block number */
        }
        else

        if (!PRIVATE.ack_pending || (acknak.block > PRIVATE.ack_pending))
                PRIVATE.ack_pending = acknak.block;

#ifdef DEBUG
        if (WS.Option.Debug)
                printf("<GOT ACK %u>\n", PRIVATE.ack_pending);
#endif
}


/* -------------------------------------------------------------------- */
/*
 * process a NAK_BLOCK message and set the nak_pending variable
 *
 */

void pascal process_nak_block( int extended )
{
        sequence_packet acknak;
        int err;

        /* disable minimalblocks mode if any errors are detected */
        WS.Option.MinimalBlocks = 0;

        if (extended)
        {
            err = receive_block((uchar *) &PRIVATE.extnak, sizeof(PRIVATE.extnak));
            acknak = PRIVATE.extnak.seq;
        }
        else
            err = receive_block((uchar *) &acknak, sizeof(acknak));

        if (err)
        {
                ERECV(TX_BADNAKCRC,(int) acknak.block);
                limit_errors(106);
        }
	else

        if (acknak.batch != SEND_FILE.batch)
        {
                if (acknak.batch > SEND_FILE.batch)
                {
                        ERECV(TX_BADNAKBAT,
                                (int)acknak.batch,
                                (int)SEND_FILE.batch,
                                (int)acknak.block);

                        limit_errors(107);
                        send_RESET(2);
                }
        }
        else

        if (acknak.block > SEND_FILE.blocks)
        {
                /* bad nak block number */
        }
        else

        if (!PRIVATE.nak_pending || (acknak.block < PRIVATE.nak_pending))
                PRIVATE.nak_pending = acknak.block;

#ifdef DEBUG
        if (WS.Option.Debug)
                printf("<GOT NAK %u %d>\n", PRIVATE.nak_pending, extended);
#endif
}


/* -------------------------------------------------------------------- */

/*
 * process a SEEK_BLOCK message and set the seek_pending variable
 *
 */

void pascal process_seek_block()
{
        sequence_packet acknak;

        if (receive_block((uchar *) &acknak, sizeof(acknak)))
        {
                ERECV(TX_BADSEEKCRC,(int) acknak.block);
                limit_errors(108);
        }
	else

        if (acknak.batch != SEND_FILE.batch)
        {
                if (acknak.batch > SEND_FILE.batch)
                {
                        ERECV(TX_BADSEEKBAT,
                                (int)acknak.batch,
                                (int)SEND_FILE.batch,
                                (int)acknak.block);

                        limit_errors(109);
                        send_RESET(3);
                }
        }
        else

        if (acknak.block > SEND_FILE.blocks)
        {
                /* bad seek block number */
        }
        else

        if (!PRIVATE.seek_pending || (acknak.block < PRIVATE.seek_pending))
                PRIVATE.seek_pending = acknak.block;

#ifdef DEBUG
        if (WS.Option.Debug)
                printf("<GOT SEEK %u>\n", PRIVATE.seek_pending);
#endif
}


/* -------------------------------------------------------------------- */

/*
 * process a VERIFY packet, and send_SEEK for first non-matching block
 * ignore further VERIFY packets once a mismatch is detected.
 *
 */

void pascal process_verify_block()
{
        resume_verify_packet pack;
        int i;
        CRC_type crc;
        block_number resume_block;
        block_number last_verified;

        if (receive_block((uchar *)&pack, sizeof(pack)))
        {
                ERECV(TX_BADVERCRC);
                limit_errors(110);
                send_ready(READY_SEND_VERIFY);
                return;
        }

        if (PRIVATE.recv_fd.handle <= 0)
        {
                receive_block(NULL, 0);
                if (RECV_FILE.batch == 0)
                        send_RESET(4);
                return;
        }

        if ((PRIVATE.repeat_expected) &&
            (PRIVATE.last_received-PRIVATE.repeat_expected >= MAX_RECEIVE_AHEAD))
                return;

        ComIoStart(31);

        PRECV((pack.count > 1)?
                        TX_VERMULT:TX_VERSINGLE,
                                pack.base_block,
                                pack.base_block+pack.count-1);

        resume_block = 0;
        last_verified = 0;
        bseek(&PRIVATE.recv_fd,pack.base_block-1);

        for (i=0; i<pack.count; i++)
        {
                if ((i&7) == 7)
                        disp_message(".");

                if (PRIVATE.verify_completed)
                {
                        if (PRIVATE.repeat_expected)
                                if (pack.base_block+i-PRIVATE.repeat_expected >= MAX_RECEIVE_AHEAD)
                                        break;
                                else
                                if (pack.base_block+i-PRIVATE.last_received >= MAX_RECEIVE_AHEAD)
                                        break;
                }

                bread(&PRIVATE.recv_fd,PRIVATE.recv_pack.data);
                crc = calculate_CRC(PRIVATE.recv_pack.data,RECV_FILE.BlockSize);

                if (PRIVATE.recv_fd.berr || (crc != pack.check[i]))
                {
                        if (!PRIVATE.verify_completed)
                        {
                                PRIVATE.verify_completed = 1;
                                resume_block = pack.base_block+i;
                        }
                }
                else {
                        last_verified = pack.base_block+i;
                        mark_block_received( last_verified );
                        if (last_verified == PRIVATE.highest_valid+1)
                                ++PRIVATE.highest_valid;
                }
        }

        disp_message("\r");
        if (WS.Option.Debug>1)
                newline();

        ComIoEnd(32);

        /* if this is the last verify block, we must have a matching
           file, so we resume at the last block */
        if (!PRIVATE.verify_completed)
                if (last_verified == RECV_FILE.blocks)
                        resume_block = last_verified+1;

        if (resume_block)
        {
                PRIVATE.last_received = resume_block-1;
                PRIVATE.highest_valid = PRIVATE.last_received;

                if (resume_block <= RECV_FILE.blocks)
                {
                        ERECV(TX_RECOVERY,resume_block);

                        send_SEEK(resume_block,3);
                        --WS.nak_count;            /* correct for send_seek action */

                        WS.recv_skip = BLOCK_BYTES(RECV_FILE,resume_block-1);
                        WS.recv_skip_total += WS.recv_skip;
                }
                else {
                        ERECV(TX_IDENTICAL);
                        send_SKIP(1,1);
                }

                WS.rx_start = bios_clock();
        }
}


/* -------------------------------------------------------------------- */

/* display a received chat block */

void pascal process_chat_block()
{
        chat_packet chat;
        if (receive_block((uchar *)chat.text, sizeof(chat)))
                strcpy(chat.text,"???");
        display_chatin(chat.text);
        PRIVATE.chat_close_timeout = SET_TIMER(CHAT_CLOSE);
}

/* send a chat block */

void pascal send_chat_block()
{
        int len;
        if (!REMOTE_READY.final_ready)
                return;
        if (ComWritePending() && !TIMER_UP(PRIVATE.chat_timeout))
                return;
        len = strlen(WS.chatout.text);
        if (!len)
                return;
        PRIVATE.chat_timeout = SET_TIMER(CHAT_TIMEOUT);
        PRIVATE.chat_close_timeout = SET_TIMER(CHAT_CLOSE);
        transmit_message(PACK_CHAT_BLOCK, (uchar *)&WS.chatout, len+1);
        WS.chatout.text[0] = 0;
}


/* -------------------------------------------------------------------- */

/* process an initiate-link "READY" message */

void pascal process_ready()
{
        char *s;
        ready_packet ready;

        mem_clear(&ready,sizeof(ready));
        if (receive_block((uchar *)&ready, sizeof(ready)))
        {
                if (WS.Option.AlternateDle != ready.alternate_dle)
                        WS.Option.AlternateDle = ready.alternate_dle;
                else
                        ERECV(TX_BADREADY);
                limit_errors(111);
                send_ready(READY_INITIAL);
                return;
        }

        REMOTE_READY = ready;
        WS.Option.AlternateDle = REMOTE_READY.alternate_dle;


        /* is this packet handshaking an open file request? */

        if (REMOTE_READY.open_handshake)
        {
                if (REMOTE_READY.open_verify)
                        PRIVATE.ready_pending = READY_SEND_VERIFY;
                else
                        PRIVATE.ready_pending = READY_SEND_FILE;
                return;
        }


        /* encrypt remote text_crc to match remote proper_crc */
        REMOTE_READY.text_CRC =
                calculate_CRC((uchar *)&REMOTE_READY.text_CRC,
                                sizeof(CRC_type));

         if (REMOTE_READY.text_CRC != REMOTE_READY.proper_CRC)
                 ++WS.hacked_remote;

/*****************
        if (WS.Option.Debug>1)
                printf("[%08lx %08lx]",
                        REMOTE_READY.text_CRC,
                        REMOTE_READY.proper_CRC);
*****************/

        /* get remote userid, check for blocked userids */

        WS.remote_userid = REMOTE_READY.userid;
        if (blocked_userid(&WS.remote_userid))
                ++WS.hacked_remote;

        if (WS.hacked_remote)
                set_cancel_link(CANCEL_BLOCKED_USERID);

        /* give registered copies priority over unregistered copies if
           both are using the -! option.  if both copies are registered,
           the priority is given to the lower registration number. */

        if (local_userid() && REMOTE_READY.Priority && WS.Option.Priority)
        {
                if (!WS.remote_userid || (local_userid() < WS.remote_userid))
                        REMOTE_READY.Priority = 0;
        }

        /* if other side wants to take priority, we use provided values
           for window, block size and xon/xoff handshake */

        if (REMOTE_READY.Priority)
        {
                WS.Option.BlockSize    = REMOTE_READY.BlockSize;
                WS.Option.XonHandshake = REMOTE_READY.XonHandshake;
                WS.Option.MaxWind      = REMOTE_READY.MaxWind & 0x7fff;
                WS.Option.DisableAck   = REMOTE_READY.DisableAck;
                WS.Option.ResumeVerify = REMOTE_READY.ResumeVerify;
                WS.Option.MinimalBlocks= REMOTE_READY.MinimalBlocks;
        }
        else

        if (!WS.Option.Priority)
        {
                /* both sides will honor -a */
                WS.Option.DisableAck |= REMOTE_READY.DisableAck;

                /* both sides will honor -R */
                WS.Option.ResumeVerify |= REMOTE_READY.ResumeVerify;

                /* if either side wants xon/xoff, the other side
                   must also use it */
                WS.Option.XonHandshake |= REMOTE_READY.XonHandshake;

                /* use remote's block size unless we're bidirectional */
                if (!WS.receive_expected)
                {
                        WS.Option.BlockSize = REMOTE_READY.BlockSize;
                        WS.Option.MaxWind = REMOTE_READY.MaxWind & 0x7fff;
                }
        }

        /* both sides must allow partial_blocks */
        if (!REMOTE_READY.partial_blocks)
                WS.Option.DisablePartialBlocks = 1;

        /* get receive transfer estimates */
        WS.receive_expected = REMOTE_READY.trans_files;
        WS.recv_bytes = REMOTE_READY.trans_bytes;

        /* get remote version */
        s = REMOTE_READY.sender;
        while (*s > ' ')
                s++;
        s++;
        strncpy(WS.remote_version,s,sizeof(WS.remote_version));

        /* calculate estimated ms per block */
        PRIVATE.block_time = 4L * ( ( ((long)WS.Option.BlockSize) * 10000L ) /
                                    ( (long)WS.Option.EffSpeed             ) );

        /* set ready_pending to 2 when the other side no longer expects
           to get a ready packet from us */

        if (REMOTE_READY.final_ready)
                PRIVATE.ready_pending = READY_FINAL;
        else
                PRIVATE.ready_pending = READY_INITIAL;

        ComSetHandshake();
}

/* -------------------------------------------------------------------- */

/* send an initiate-link message */

void pascal send_ready( int final )
{
        ready_packet ready;

        mem_clear(&ready,sizeof(ready));

        strcpy(ready.sender, sender_name);
        ready.proper_CRC        = proper_CRC;
        ready.userid            = local_userid();
        ready.text_CRC          = text_CRC;

        ready.trans_files       = WS.send_expected;
        ready.trans_bytes       = WS.send_bytes;
        ready.Priority          = WS.Option.Priority;
        ready.MaxWind           = WS.Option.MaxWind;
        ready.BlockSize         = WS.Option.BlockSize;
        ready.DisableAck        = WS.Option.DisableAck;
        ready.MinimalBlocks     = WS.Option.MinimalBlocks;
        ready.partial_blocks    = !WS.Option.DisablePartialBlocks;
        ready.XonHandshake      = WS.Option.XonHandshake;
        ready.ResumeVerify      = WS.Option.ResumeVerify;
        ready.alternate_dle     = 1; /*WS.Option.XonHandshake*/

        ready.final_ready       = (final != READY_INITIAL);

        if (final == READY_SEND_VERIFY)
        {
                ready.open_handshake = 1;
                ready.open_verify = 1;
        }
        else
        if (final == READY_SEND_FILE)
        {
                ready.open_handshake = 1;
                ready.open_verify = 0;
        }
        else
                ready.open_handshake = 0;

        if (final == READY_INITIAL)
                ComWriteStr((uchar *)"\rHS*",4);

        transmit_message(WS.send_expected? PACK_READY:PACK_READY_RECV,
                                        (uchar *)&ready, sizeof(ready));
        ComWriteChar('\r');

#ifdef DEBUG
        if (WS.Option.Debug)
                printf("<send ready packet, final=%d>\n",final);
#endif
}


/* -------------------------------------------------------------------- */

/* process a skip file; set skip_file_pending to non-zero */

void pascal process_skip_file()
{
        receive_block(NULL, 0);
	PRIVATE.skip_file_pending = 1;
}


/* -------------------------------------------------------------------- */

/* process a restart-current-file; set reset_file_pending to non-zero */

void pascal process_reset_file()
{
        receive_block(NULL, 0);
        PRIVATE.reset_file_pending = 1;
}


/* -------------------------------------------------------------------- */

/* process a terminate-link message; set transmit_done_pending to non-zero */

void pascal process_transmit_done()
{
        receive_block(NULL, 0);
	PRIVATE.transmit_done_pending = 1;
        PRECV(TX_TXDONE,
                WS.files_received,
                WS.files_received==1? TX_TXDONESINGLE:TX_TXDONEPLURAL);
}


/* -------------------------------------------------------------------- */

/*
 * process a file_header message - initiate processing of next file
 *
 */
void pascal process_open_file()
{
        static file_header_packet open_pack;     /* static ok here */
        char *dupefn;
        char fname[66];

        /* get the file header packet */

        if (receive_block((uchar *) &open_pack, sizeof(open_pack)))
        {
                ERECV(TX_BADFILEHDR);
                limit_errors(112);
                send_RESET(5);
		return;
	}

        /* report receive batch estimate */

        if (open_pack.batch == 1)
                display_incoming_files();

        /* finish up the previous file, if any */

        close_active_file(1);

        /* truncate invalid filenames, if needed */
        open_pack.name[12] = 0;
        RECV_FILE.size = open_pack.size;

        if (WS.Option.BlockUpload)
        {
                ERECV(TX_UPLOADBLOCK,open_pack.name);
                send_SKIP(1,2);
                return;
        }

        ComIoStart(33);

        /* if this appears to be a directory, prefix the receive filename
           with the directory, otherwise use this as the destination filename */

        strcpy(fname,WS.Option.ReceiveDir);
        if (isadir(fname))
        {
                if (*fname && (LAST_CHAR(fname) != '\\'))
                        strcat(fname,"\\");
                strcat(fname,open_pack.name);
        }

        WS.rx_start = bios_clock();

        dupefn = duplicate_file(fname,open_pack.name);
        if (dupefn)
        {
                ComIoEnd(34);
                ERECV(TX_OVERWRITE,dupefn);
                if (WS.Option.ResumeVerify && (fname == dupefn))
                        disp_message(TX_USEOR);
                send_SKIP(1,3);
                return;
        }

        /* create the file, if needed, and signal remote to send verify
           blocks when file already exists */

        if (access(fname, 0))
        {
                bcreate(fname);
                if (WS.Option.ResumeVerify)
                        send_ready(READY_SEND_FILE);
        }
        else {
                if (WS.Option.ResumeVerify)
                        send_ready(READY_SEND_VERIFY);
        }

        bopen(&PRIVATE.recv_fd, fname, WS.buffer_sizes, open_pack.BlockSize, O_RDWR | SH_DENYNONE);

        ComIoEnd(35);

        if (PRIVATE.recv_fd.berr)
        {
                ERECV(TX_CANTOPRX, fname);
                send_SKIP(1,4);
                return;
        }

        /* store information about the current receive file */

        RECV_FILE = open_pack;

        select_recv();
        display_file_banner(TX_RECEIVING,fname,
                        RECV_FILE.blocks,
                        RECV_FILE.size);

        if (!WS.Option.ResumeVerify)
                file_bargraph(0,RECV_FILE.size,0);

        /* clear the receive_ahead_table in preparation for a new file */

        mem_clear(RA_TABLE,sizeof(RA_TABLE));
        PRIVATE.last_received = 0;
        PRIVATE.prior_received = 0;
        PRIVATE.last_naked = 0;
        PRIVATE.last_rxack = 0;
        PRIVATE.last_seek = 0;
        PRIVATE.repeat_expected = 0;
        PRIVATE.highest_valid = 0;
        WS.nak_count = 0;
        WS.Comstat.ReceiveHolds = 0;
        PRIVATE.verify_completed = 0;
        WS.receive_errors = 0;
        WS.recv_current = 0;
        WS.recv_skip = 0;
        PRIVATE.transmit_done_pending = 0;
}


/* -------------------------------------------------------------------- */

/*
 * The receive_ahead_table is a table of recent block numbers that have
 * been received without error.  If we have a pending nak and we get out
 * of sequence blocks beyond the nak, this table records which of them
 * were accurate so that they can be acked following recovery of the
 * current error.
 * This table forms the basis of full-streaming-error-recovery, which
 * is unique to hs/link.
 */

/* mark a block number is being correctly received */

void pascal mark_block_received( block_number block )
{
        RA_TABLE[block % MAX_RECEIVE_AHEAD] = block;
}

/* determine if a block has been recently marked as valid */

int pascal block_already_received( block_number block )
{
        return RA_TABLE[block % MAX_RECEIVE_AHEAD] == block;
}


/* -------------------------------------------------------------------- */

/* send a SKIP_FILE packet (blocks xfrd before skip) */

#pragma argsused
static void pascal send_SKIP( block_number block, int reason )
{
        transmit_message(PACK_SKIP_FILE, NULL, 0);

        WS.recv_skip = RECV_FILE.size;
        if (PRIVATE.recv_fd.handle <= 0)
                WS.recv_total += RECV_FILE.size;
        else
        if (block > 1)
                WS.recv_skip -= BLOCK_BYTES(RECV_FILE,block);

        WS.recv_skip_total += WS.recv_skip;
        report_combined();
}


/* -------------------------------------------------------------------- */

/* send a RESET_FILE packet */

void pascal send_RESET( int who )
{
        transmit_message(PACK_RESET_FILE, NULL, 0);
        ERECV(TX_RESTARTING,who);
}

/* -------------------------------------------------------------------- */

/* send an ACK packet */

#pragma argsused
void pascal send_ACK( block_number block, int who )
{
        sequence_packet acknak;
        if (block > RECV_FILE.blocks)
                block = RECV_FILE.blocks;

        if (PRIVATE.repeat_expected && (block == RECV_FILE.blocks))
                return;

        if (block == PRIVATE.last_rxack)
                return;

        PRIVATE.last_rxack = block;
        acknak.block = block;
        acknak.batch = RECV_FILE.batch;
        transmit_message(PACK_ACK_BLOCK,
                        (uchar *)&acknak,sizeof(acknak));

#ifdef DEBUG
        if (WS.Option.Debug)
                printf("<SENT ACK %u %d>\n",block,who);
#endif
}

/* send a NAK packet */

#pragma argsused
void pascal send_NAK( block_number block, int reason )
{
        sequence_packet acknak;
        if (block > RECV_FILE.blocks)
                block = RECV_FILE.blocks;

        PRIVATE.last_naked = block;
        acknak.block = block;
        acknak.batch = RECV_FILE.batch;
        PRIVATE.extnak.seq = acknak;
        PRIVATE.extnak.nak_reason = reason;

        transmit_message(PACK_NAK_BLOCK,
                        (uchar *)&acknak,sizeof(acknak));
        ++WS.nak_count;
#ifdef DEBUG
        if (WS.Option.Debug)
                printf("<SENT NAK %u %d>\n",block,reason);
#endif
}

/* send a SEEK packet */

#pragma argsused
void pascal send_SEEK( block_number block, int who )
{
        sequence_packet acknak;
        if (block > RECV_FILE.blocks)
                block = RECV_FILE.blocks;

        PRIVATE.last_seek = block;
        acknak.block = block;
        acknak.batch = RECV_FILE.batch;
        transmit_message(PACK_SEEK_BLOCK,
                        (uchar *)&acknak,sizeof(acknak));
        ++WS.nak_count;
#ifdef DEBUG
        if (WS.Option.Debug)
                printf("<SENT SEEK %u %d>\n",block,who);
#endif
}


/* -------------------------------------------------------------------- */

/*
 * a data block was found to be valid - reverse mapping and write it
 * to the receive file.
 *
 */

void pascal write_valid_data_block(void)
{
        int n;
        uchar *s;
        long wsize;

        wsize = BLOCK_SIZE(RECV_FILE,PRIVATE.recv_pack.seq.block);

        /* reverse any active mapping */

        #define RMAP PRIVATE.recv_pack.map

        for (s=PRIVATE.recv_pack.data,n=0; n<(int)wsize; ++n,++s)
        {
                if (*s == RMAP.xoff_map)          *s = XOFF_CHR;
                else if (*s == RMAP.xon_map)      *s = XON_CHR;
                else if (*s == RMAP.dle_map)      *s = DLE_CHR;
                else if (*s == RMAP.start_map)    *s = START_PACKET_CHR;
                else if (*s == RMAP.end_map)      *s = END_PACKET_CHR;
                else if (*s == XOFF_CHR)          *s = RMAP.xoff_map;
                else if (*s == XON_CHR)           *s = RMAP.xon_map;
                else if (*s == DLE_CHR)           *s = RMAP.dle_map;
                else if (*s == START_PACKET_CHR)  *s = RMAP.start_map;
                else if (*s == END_PACKET_CHR)    *s = RMAP.end_map;
        }

        /* allow HDK clients to preview data */

        filter_rx_block(PRIVATE.recv_fd.pathname,
                        (long)RECV_FILE.BlockSize*(long)(PRIVATE.recv_pack.seq.block-1),
                        BLOCK_SIZE(RECV_FILE,PRIVATE.recv_pack.seq.block),
                        PRIVATE.recv_pack.data);

        /* write the data to disk */

        bseek(&PRIVATE.recv_fd, PRIVATE.recv_pack.seq.block-1);
        bwrite(&PRIVATE.recv_fd, PRIVATE.recv_pack.data);

        if (PRIVATE.recv_fd.berr)
        {
                ERECV(TX_DISKWERR,(int) PRIVATE.recv_pack.seq.block);
                send_SKIP(PRIVATE.recv_pack.seq.block,5);
                return;
        }

        WS.recv_current = BLOCK_BYTES(RECV_FILE,PRIVATE.recv_pack.seq.block);
        WS.rx_cps = calculate_cps(WS.rx_start,WS.recv_current-WS.recv_skip);
        PRECV(TX_RXBLOCK,(int) PRIVATE.recv_pack.seq.block,
                         (long) WS.recv_current,
                         (int) WS.rx_cps);
        limit_errors(-101);

        if (block_already_received(PRIVATE.recv_pack.seq.block))
        {
                disp_message("R");
                send_ACK( PRIVATE.recv_pack.seq.block,4 );
        }

        if (PRIVATE.repeat_expected)
                disp_message("E%u",(int)PRIVATE.repeat_expected);

        disp_message("\r");

        if (WS.Option.Debug>1)
                newline();
        else
                file_bargraph(WS.recv_current,RECV_FILE.size,WS.rx_cps);
}


/* -------------------------------------------------------------------- */

/*
 * process a data_packet message - this entry drives the file receiver
 *
 */
void pascal process_data_block( int btype )
{
        uchar error;
        int bsize;

        PRIVATE.last_rxack = 0;
        
        /* continuation blocks are sequential and do not contain block
           numbers and may not contain mapping information */

        if (btype & SEQ_BLOCK)
        {
                bsize = sizeof(PRIVATE.recv_pack);
                error = receive_block((uchar *) &PRIVATE.recv_pack.seq, bsize);
        }
        else
        if (btype & MAP_BLOCK)
        {
                bsize = sizeof(PRIVATE.recv_pack.map)+ sizeof(PRIVATE.recv_pack.data);
                error = receive_block((uchar *) &PRIVATE.recv_pack.map, bsize);
                ++PRIVATE.recv_pack.seq.block;
        }
        else {
                bsize = sizeof(PRIVATE.recv_pack.data);
                error = receive_block((uchar *) &PRIVATE.recv_pack.data, bsize);
                ++PRIVATE.recv_pack.seq.block;
        }


        /* reset the file if there is not yet an active receive file */

        if (PRIVATE.recv_fd.handle <= 0)
        {
/**********
                if (WS.Option.BlockUpload)
                        return;
                if ((RECV_FILE.batch == 0) || (PRIVATE.recv_pack.seq.block > 8))
                        send_RESET(6);
                if (WS.Option.Debug)
                        printf("No active file! (%u)\n",
                                (int) PRIVATE.recv_pack.seq.block);
************/
                return;
        }

#ifdef DEBUG
        if (WS.Option.Debug)
                printf("<GOT BLOCK %u e=%u lr=%u dup=%d> ",
                        PRIVATE.recv_pack.seq.block,error,
                        PRIVATE.last_received,
                        block_already_received(PRIVATE.recv_pack.seq.block));
#endif

        /* nak the block if it has a crc error */
        if (error)
        {

                /* attempt to use the bad block's block number if it
                   does not appear to be garbled */

                if ((PRIVATE.recv_pack.seq.block > 0) &&
                    (PRIVATE.recv_pack.seq.block <= RECV_FILE.blocks) &&
                    !block_already_received(PRIVATE.recv_pack.seq.block))
                        PRIVATE.last_received = PRIVATE.recv_pack.seq.block;
                else
                if (PRIVATE.last_received < RECV_FILE.blocks)
                        ++PRIVATE.last_received;

                /* determine expected size of block */

                bsize = bsize - sizeof(PRIVATE.recv_pack.data) +
                                BLOCK_SIZE(RECV_FILE,PRIVATE.last_received);
                                /* conversion loss warning ok */

                /* if the block hasn't been received already, send a nak
                   to request a resend.  this usually works, but might
                   need other attention later on if the guessed block
                   number turnes out to be wrong. */

                if (!block_already_received(PRIVATE.last_received))
                {
                        char *reason;
                        char nak_reason;
                        char message[80];

                        if (!PRIVATE.repeat_expected)
                                PRIVATE.repeat_expected = PRIVATE.last_received;

                        if (bsize == PRIVATE.last_receive_size)
                        {
                                nak_reason = 1;
                                reason = TX_BADDATACRC;
                        }
                        else if (PRIVATE.last_receive_size < bsize)
                        {
                                nak_reason = 2;
                                reason = TX_DROPPEDBYTES;
                        }
                        else {
                                nak_reason = 3;
                                reason = TX_NOISEBURST;
                        }

                        sprintf(message,"%s %d %s",
                                        reason,
                                        PRIVATE.last_receive_size-bsize,
                                        //PRIVATE.last_received,
                                        WS.Comstat.ErrorMessage+5);

                        WS.Comstat.ErrorMessage[0] = 0;
                        WS.Comstat.ErrorMessage[5] = 0;

                        report_rx_error(message);
                        limit_errors(102);

                        send_NAK(PRIVATE.last_received,2+nak_reason);

/******
DBPF("BAD DATA BLOCK:");
DUMP_BLOCK(PRIVATE.recv_pack.data,
           BLOCK_SIZE(RECV_FILE,PRIVATE.last_received));
DBNL;
*******/
                }

                return;
	}

        /* reset the file if it is from the wrong file */

        if (PRIVATE.recv_pack.seq.batch != RECV_FILE.batch)
        {
                ERECV(TX_BADBATCH,
                        (int)PRIVATE.recv_pack.seq.batch,
                        (int)RECV_FILE.batch);

                limit_errors(114);
                if (PRIVATE.recv_pack.seq.batch > RECV_FILE.batch)
                        send_RESET(7);
                return;
	}


        /* the block is valid and NEW, mark it as valid, write it
         * to the file and ACK it */

        write_valid_data_block();       /* ACKS DUPES */

        PRIVATE.prior_received = PRIVATE.last_received;
        PRIVATE.last_received = PRIVATE.recv_pack.seq.block;

        mark_block_received( PRIVATE.last_received );


        /* if we are in error recovery and this block is the one
         * we're waiting for, see if there are any other repeats
         * in the window. */

        if (PRIVATE.last_received == PRIVATE.repeat_expected)
        {

                /* see if any other blocks need repeating */
                while (block_already_received(PRIVATE.repeat_expected))
                        PRIVATE.repeat_expected++;

#ifdef DEBUG
        if (WS.Option.Debug)
                printf("<NEXT REPEAT %d> ",PRIVATE.repeat_expected);
#endif

                /* tell transmitter to advance over received blocks */
                if (PRIVATE.repeat_expected >= PRIVATE.last_received+1)
                        send_ACK( PRIVATE.last_received,10 );
                else

                if (PRIVATE.repeat_expected <= PRIVATE.highest_valid)
                        send_NAK(PRIVATE.repeat_expected,8);
                else
                        send_ACK(PRIVATE.repeat_expected-1,9);


                /* end of error recovery if no missing blocks */
                if (PRIVATE.repeat_expected >= PRIVATE.highest_valid)
                        PRIVATE.repeat_expected = 0;

                return; /* stub? */
        }

        /* if we reach EOF without recovering expected blocks,
           or if we are about to lose a record of a lost block by
           overflowing the read-ahead table, we need to repeat the
           NAK to continue */

        if ((PRIVATE.repeat_expected) && (PRIVATE.repeat_expected != PRIVATE.last_received))
        {
                long waiting;
                waiting = PRIVATE.last_received;
                waiting -= PRIVATE.repeat_expected;  /* prevent unsigned overflow */

#ifdef DEBUG
                if (WS.Option.Debug)
                        printf("<WAIT %ld> ",waiting);
#endif

                /* seek if we are at EOF */
                if (PRIVATE.last_received >= RECV_FILE.blocks)
                {
                        if (PRIVATE.last_seek == PRIVATE.repeat_expected)
                                PRIVATE.last_seek = 0;
                        else
                                send_SEEK(PRIVATE.repeat_expected,6);
                }
                else

                /* repeat a nak well before trouble begins */
                switch (waiting)
                {

                case 10:
                case 20:
                case 30:
                case 40:
                case 50:
#ifdef DEBUG
                        if (WS.Option.Debug)
                                printf("<TROUBLE %d %d %ld>",
                                        PRIVATE.last_received,PRIVATE.repeat_expected,waiting);
#endif
                        PRIVATE.last_naked = 0;
                        send_NAK(PRIVATE.repeat_expected,7);
                        break;

                default:
                        if (waiting < 60)
                                break;

                        /* seek if we lost recovery totally */
                        if (PRIVATE.repeat_expected == PRIVATE.last_seek)
                                PRIVATE.last_seek = 0;
                        else
                        if (PRIVATE.repeat_expected > PRIVATE.prior_received+1)
                                send_SEEK(PRIVATE.repeat_expected,17);
                }
        }

        /* check for hacked remote */
/*************************************************************
        if (PRIVATE.last_received >= 11)
                if (REMOTE_READY.text_CRC != REMOTE_READY.proper_CRC)
                {
                        ++WS.hacked_remote;
                        send_SKIP(1,6);
                }
**************************************************************/

        /* if the block is in sequence, we're done */

        if (PRIVATE.last_received == PRIVATE.highest_valid+1)
        {
                ++PRIVATE.highest_valid;

                /* if we reach EOF without recovering expected blocks,
                 * we need to repeat the NAK to continue */

                if (PRIVATE.repeat_expected && (PRIVATE.last_received == RECV_FILE.blocks))
                {
                        send_SEEK(PRIVATE.repeat_expected,11);
                        return;
                }

                if (WS.Option.DisableAck && (PRIVATE.last_received < RECV_FILE.blocks))
                        return;

                send_ACK(PRIVATE.last_received,12);
                return;
        }


        /* if one or more blocks are skipped we may have missed out
         * on a block and need to request a resend. */

        if (PRIVATE.last_received > PRIVATE.highest_valid+1)
        {

                /* if the hole appears during error recovery we don't
                   need to nak yet, since it will be taken care of by
                   the normal recovery logic.  Otherwise we have a
                   missed block, which we will nak and flag as needing
                   a repeat. */

                if (PRIVATE.repeat_expected)
                {
                        send_ACK(PRIVATE.last_received,16);
                }

                else {
                        PRIVATE.repeat_expected = PRIVATE.highest_valid+1;
                        while (block_already_received(PRIVATE.repeat_expected))
                                PRIVATE.repeat_expected++;

                        if (PRIVATE.repeat_expected > RECV_FILE.blocks)
                        {
                                PRIVATE.repeat_expected = 0;
                                send_ACK(PRIVATE.last_received,28);
                        }
                        else

                        if (PRIVATE.last_naked == PRIVATE.repeat_expected)
                                send_ACK(PRIVATE.last_received,18);
                        else {
                                send_NAK(PRIVATE.repeat_expected,13);

                                ERECV(TX_OUTOFSEQ,
                                        (int) PRIVATE.recv_pack.seq.block,
                                        (int) PRIVATE.repeat_expected);
                                limit_errors(115);
                                if (WS.Option.Debug>1)
                                    newline();
                        }
                }

                PRIVATE.highest_valid = PRIVATE.last_received;
        }

        /* block is out of sequence, but part of error recovery */
        else {
                block_number temp = PRIVATE.last_received;
                int skip;

                while (block_already_received(temp))
                        ++temp;

                --temp;
                skip = temp-PRIVATE.last_received;
                if ((skip > 4) &&
                    (temp != PRIVATE.last_seek) &&
                    (temp > PRIVATE.prior_received+1))
                        send_SEEK(temp,14);
                else {
                        if (temp == PRIVATE.last_seek)
                                PRIVATE.last_seek = 0;
                        send_ACK(PRIVATE.last_received,15);
                }
        }
}


/* -------------------------------------------------------------------- */

/*
 * close the current receive file, if it is active
 *
 */

#pragma argsused
void pascal close_active_file( int who )
{
        char logcode;
        block_number blocks;

        if (PRIVATE.recv_fd.handle <= 0)
                return;

        /* calculate transfer rate */

        if (!WS.rx_cps)
                WS.rx_cps = calculate_cps(WS.rx_start,RECV_FILE.size-WS.recv_skip);


        /* write final buffer of file to check for disk error */

        bflush(&PRIVATE.recv_fd);

        if (PRIVATE.recv_fd.berr || !block_already_received(RECV_FILE.blocks) || PRIVATE.repeat_expected)
        {

                ComIoStart(36);
                bclose(&PRIVATE.recv_fd);
                if (!WS.Option.KeepAborted)
                        unlink(PRIVATE.recv_fd.pathname);
                ComIoEnd(37);

                ERECV(TX_INCOMPLETE,
                        RECV_FILE.name,
                        (int)PRIVATE.last_received,
                        (int)PRIVATE.repeat_expected);

                if (PRIVATE.repeat_expected)
                        blocks = PRIVATE.repeat_expected-1;
                else
                        blocks = PRIVATE.last_received;
                PRIVATE.last_received = 0;

                /* report reason for error if file was incomplete */

                logcode = 'E';
                /* WS.rx_cps = 0; */

                if (WS.cancel_link)
                {
                        ERECV(TX_ABORTED);
                }

                if (ComCarrierLost())
                {
                        logcode = 'L';
                }
        }
        else {
                blocks = RECV_FILE.blocks;
                logcode = 'H';

                if (WS.recv_skip != RECV_FILE.size)
                {
                        ERECV(TX_RXOK,
                                        (int)RECV_FILE.batch,
                                        (int)WS.rx_cps,
                                        sectomin(TIMER_SECS(WS.rx_start)));
                                /* conversion loss warning ok */
                }

                ++WS.files_received;

                /* close the file and set time stamp */

                bclose_set(&PRIVATE.recv_fd, RECV_FILE.size, &RECV_FILE.time);
                PRIVATE.last_received = 0;
        }

        /* make an entry in DSZLOG */

        WS.recv_current = BLOCK_BYTES(RECV_FILE,blocks);

        update_status_log(
                        logcode,
                        WS.recv_current,
                        WS.Option.EffSpeed,
                        WS.rx_cps,
                        WS.nak_count,
                        WS.Comstat.ReceiveHolds,
                        FINAL_BLOCK_SIZE(RECV_FILE),
                                /* conversion loss warning ok */
                        PRIVATE.recv_fd.pathname);

        WS.recv_skip_total += (RECV_FILE.size - WS.recv_current);
        WS.recv_total += RECV_FILE.size;
        WS.recv_current = 0;
        /* WS.rx_cps = 0; */

        report_combined();
}


/* -------------------------------------------------------------------- */

/*
 * process a close_file message
 *
 */

void pascal process_close_file()
{
        receive_block(NULL, 0);
        close_active_file(2);
}


/* -------------------------------------------------------------------- */

/* receive a block with DLE escape processing */
/* returns number of bytes received */

int pascal receive_dle_block(uchar *buf,
                      int size,
                      int *end_seen)
{
        register int c;
        register int count = 0;
        *end_seen = 0;

        while (count < size)
        {
                c = RXCHAR;
                switch (c)
                {

                case END_PACKET_CHR:
                        *end_seen = 1;
                        return count;

                case DLE_CHR:
                        c = RXCHAR;
                        if (WS.Option.AlternateDle)
                                *buf++ = c ^ 0x40;
                        else
                                *buf++ = c ^ 0x80;
                        break;

                default:
                        *buf++ = c;
                }

                ++count;
        }

        return count;
}


/* -------------------------------------------------------------------- */

/*
 * receive_block - deque receive data into the specified buffer,
 *                 process DLE escapes in the process.
 *                 Consumes the END_PACKET marker if found.
 *                 Verifies CRC if size > 0.
 *                 Returns 0 for valid block, non-0 if error.
 */

int pascal receive_block(uchar *buf,
                  int size)
{
        CRC_type rCRC,lCRC;
        int count;
        int end;
        int fail=0;

        if (size)
        {
                /* receive the remote's block CRC */
                count = receive_dle_block((uchar *)&rCRC, WS.Option.CrcSize, &end);
                if (end || (count != WS.Option.CrcSize))
                {
#ifdef DEBUG
                        if (WS.Option.Debug)
                                printf("Missing CRC, size=%d end=%d\n",size,end);
#endif
                        return 1;
                }

                /* receive the actual block and calculate CRC */
                count = receive_dle_block(buf, size, &end);
                PRIVATE.last_receive_size = count;
                lCRC = calculate_CRC(buf, count);
                fail = memcmp(&lCRC, &rCRC, WS.Option.CrcSize);

#ifdef DEBUG
                if (fail)
                {
                        printf("\nBAD BLOCK; size=%d count=%d buf=%04x contents=",size,count,buf);
                        DUMP_BLOCK(buf,count);
                }
                else
                        printf("\nGOOD BLOCK; size=%d count=%d buf=%04x\n",size,count,buf);
#endif

        }

        return fail;
}


