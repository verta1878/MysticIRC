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
 * hstrans.c - HS/Link, transmit side
 *
 */

#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <io.h>
#include <conio.h>
#include <fcntl.h>
#include <share.h>
#include <dos.h>

#include "hdktext.h"
#include "hspriv.h"
#include <hdk.h>

/* -------------------------------------------------------------- */

/* prototypes for private local procedures */

static int pascal send_header_block(char *path);

static int pascal send_data_block(block_number num);

static int pascal send_verify_block(block_number start);

static void pascal reduce_window(void);

static void pascal send_dle_char(uchar c);

static void pascal send_dle_block(uchar *data,
                                  int size);


/* -------------------------------------------------------------------- */

void pascal reduce_window(void)
{
        clock_t timer;
        long delay;

        if (WS.Option.MaxWind > 2)
        {
                --WS.Option.MaxWind;
                display_settings();
        }

        if (WS.tx_cps)
                delay = (1000L * SEND_FILE.BlockSize) / WS.tx_cps;
        else
                delay = PRIVATE.block_time;

        timer = SET_TIMER(delay+1000L);
        while (!TIMER_UP(timer) && !WS.cancel_link)
        {
                ComIdle(601);
                service_receive();
        }
}

/* -------------------------------------------------------------------- */

/* transmit each outgoing file (received files are processed in
   the background, during ACK waits).
   must be called repeatedly with each pathname until a 0 return
   value is seen.  non-0 return value indicates a transmit is in
   progress and that additional transmit_file calls are required to
   complete the transmit. */

int pascal transmit_file(char *path)
{
        switch (PRIVATE.transmit_context)
        {
        case 0:
        case 1:
               if (WS.cancel_link)
                       return 0;

                WS.send_current = 0;
                WS.send_skip = 0;
                WS.transmit_errors = 0;
                WS.resend_count = 0;
                WS.Comstat.TransmitHolds = 0;
                LAST_SENT = 0;
                PRIVATE.last_txack = 0;
                PRIVATE.ptx_pending = 0;
                PRIVATE.timeout_count = 0;
                PRIVATE.verify_requested = 0;
                PRIVATE.next_verify = 1;
                PRIVATE.ack_timeout = ACK_TIMEOUT + PRIVATE.block_time;

                PRIVATE.verify_active = WS.Option.ResumeVerify;
                PRIVATE.logcode = 'h';
                mem_clear(&PRIVATE.send_pack,sizeof(PRIVATE.send_pack));

                /* open file, set fd and blocks and send file header to remote */

                if (send_header_block(path))
                        return PRIVATE.transmit_context = 0;

                /* determine maximum contents in txque to allow another
                   block to be enqueued.  also take effective speed into
                   account for lower speeds to improve response time */
                {
                        long temp = ComWriteMax() -
                                    BLOCK_SIZE(SEND_FILE,1) - 100L;
                        PRIVATE.max_pending = temp > 10? temp:10;
                }

#ifdef DEBUG
                printf("max_pending(1)=%d\n",PRIVATE.max_pending);
#endif
                if (PRIVATE.max_pending > WS.Option.EffSpeed/16)
                        PRIVATE.max_pending = WS.Option.EffSpeed/16;
#ifdef DEBUG
                printf("max_pending(2)=%d\n",PRIVATE.max_pending);
#endif

                WS.tx_start = bios_clock();
                PRIVATE.idle_timeout = SET_TIMER( PRIVATE.ack_timeout );

                if (!PRIVATE.verify_active)
                        file_bargraph(0,SEND_FILE.size,0);

                return PRIVATE.transmit_context = 2;

        case 2:
                /* send each block in the file;
                   reposition at the receiver's request */

                /* link has been cancelled? */
                if (WS.cancel_link)
                {
                        PRIVATE.logcode = 'e';
                        ESEND(TX_ABORTED);
                        return PRIVATE.transmit_context = 3;
                }

                /* carrier lost? */
                if (ComCarrierLost())
                {
                        PRIVATE.logcode = 'l';
                        return PRIVATE.transmit_context = 3;
                }

                /* remote requested to skip file? */
                if (PRIVATE.skip_file_pending)
                {
                        PRIVATE.skip_file_pending = 0;
                        PRIVATE.logcode = 'e';
                        ESEND(TX_SKIPREM,LAST_SENT);
                        return PRIVATE.transmit_context = 3;
                }

                /* remote requested to restart file? */
                if (PRIVATE.reset_file_pending)
                {
                        PRIVATE.reset_file_pending = 0;
                        bclose(&PRIVATE.send_fd);
                        transmit_message(PACK_CLOSE_FILE, NULL, 0);
                        ESEND(TX_RESTARTING,LAST_SENT);
                        return PRIVATE.transmit_context = 1;
                }

                /*
                 * process a ready_pending message if we are expecting
                 * a file handshake
                 *
                 */
                if (PRIVATE.ready_pending == READY_SEND_FILE)
                {
                        PRIVATE.ready_pending = 0;
                        PRIVATE.verify_active = 0;
                }
                else

                if (PRIVATE.ready_pending == READY_SEND_VERIFY)
                {
                        PRIVATE.ready_pending = 0;
                        PRIVATE.next_verify = 1;
                        PRIVATE.verify_requested = 1;
                }

                /*
                 * process any pending ACK messages, setting last_txack to
                 * the highest block number that has been ACKed 
                 */

                if (PRIVATE.ack_pending)
                {
                        long unacked_total;
                        PRIVATE.last_txack = PRIVATE.ack_pending;
                        PRIVATE.ack_pending = 0;

                        unacked_total = (long) BLOCK_BYTES(SEND_FILE,LAST_SENT);
                        WS.send_current = (long) BLOCK_BYTES(SEND_FILE,PRIVATE.last_txack);
                        WS.tx_cps = calculate_cps(WS.tx_start,WS.send_current-WS.send_skip);
                        PRIVATE.curwindow = LAST_SENT - PRIVATE.last_txack;

                        /* update 'w:window' status display */
                        limit_errors(-201);
                        if (WS.Option.Debug != 2)
                        {
                                PSEND(TX_TXBLOCK,
                                        (int) LAST_SENT,
                                        unacked_total,
                                        (int) PRIVATE.curwindow,
                                        (int) WS.tx_cps);
                        }

                        file_bargraph(WS.send_current,SEND_FILE.size,WS.tx_cps);

#ifdef DEBUG
                        if (WS.Option.Debug)
                                printf("<USE ACK %u>\r\n", (int) PRIVATE.last_txack);
#endif

                        PRIVATE.idle_timeout = SET_TIMER( PRIVATE.ack_timeout );
                        PRIVATE.timeout_count = 0;
                        PRIVATE.verify_active = 0;
                }


                /* determine how many blocks have not been ack'd yet */

                PRIVATE.curwindow = (LAST_SENT - PRIVATE.last_txack) + 1;

                /*
                 * Check for nak messages from the receiver.  If we get one,
                 * resend the offending block, but continue where we were
                 * before the nak came in.  This takes advantage of the fact
                 * that the receiver can receive blocks out of order and
                 * will issue additional nak messages for any other bad
                 * blocks.
                 * This is the secret of full-streaming-error-recovery,
                 * which (as far as I know) is not used by any other
                 * communication protocol on the PC.
                 */

                if (PRIVATE.nak_pending)
                {
                        ++WS.resend_count;
                        report_tx_error(TX_RESENDING,PRIVATE.nak_pending);
                        limit_errors(201);

                        if (WS.resend_count > PRIVATE.nak_pending)
                                reduce_window();

                        if (send_data_block(PRIVATE.nak_pending))
                                PRIVATE.reset_file_pending = 1;

                        PRIVATE.nak_pending = 0;

                        /* if we're at eof, try the final block again
                           to prevent an ack timeout */
                        if (LAST_SENT == SEND_FILE.blocks)
                                --LAST_SENT;

                        PRIVATE.timeout_count = 0;
                        PRIVATE.idle_timeout = SET_TIMER( PRIVATE.ack_timeout );
                        PRIVATE.verify_active = 0;
                }

                /* in worst case error conditions we seek back to some
                   other position in the file */

                if (PRIVATE.seek_pending)
                {
                        if (PRIVATE.verify_active)
                        {
                                ESEND(TX_TXRECOVERY,
                                        PRIVATE.seek_pending);
                        }
                        else {
                                report_tx_error(
                                        PRIVATE.seek_pending<LAST_SENT?
                                                TX_SEEKBACK:
                                                TX_SEEKFORWARD,
                                        PRIVATE.seek_pending);

                                /* reduce WS.Option.MaxWind to prevent future errors
                                   in case of flow control failure */
                                if (PRIVATE.seek_pending < LAST_SENT)
                                        reduce_window();
                        }

                        LAST_SENT = PRIVATE.seek_pending-1;
                        PRIVATE.last_txack = LAST_SENT-1;
                        PRIVATE.seek_pending = 0;
                        if (PRIVATE.verify_active)
                        {
                                WS.tx_start = bios_clock();
                                if (LAST_SENT)
                                {
                                        WS.send_skip = BLOCK_BYTES(SEND_FILE,LAST_SENT);
                                        WS.send_skip_total += WS.send_skip;
                                }
                        }
                        PRIVATE.verify_active = 0;
                }

                /*
                 * send verify blocks if we are in recovery mode and
                 * no blocks have been acked by the receiver
                 * receiver responds by sending
                 *
                 */

                if (PRIVATE.verify_active && PRIVATE.next_verify)
                {
                        if (PRIVATE.verify_requested)
                        {
                                if (send_verify_block(PRIVATE.next_verify))
                                        PRIVATE.next_verify = 0;
                                else
                                        PRIVATE.next_verify += MAX_VERIFY_COUNT;
                        }
                        PRIVATE.timeout_count = 0L;
                        PRIVATE.idle_timeout = SET_TIMER( PRIVATE.ack_timeout+VERIFY_TIMEOUT );
                }


                /*
                 * send the next block if there are more to send and
                 * there are not too many pending (un-acked) blocks
                 */

                if ( (LAST_SENT < SEND_FILE.blocks) &&
                     (WS.Option.DisableAck || (PRIVATE.curwindow <= WS.Option.MaxWind)) &&
                     (!PRIVATE.verify_active) &&
                     (ComWritePending() < PRIVATE.max_pending) )
                {
                        long current;
                        ++LAST_SENT;
                        if (WS.Option.DisableAck)
                                WS.tx_cps = calculate_cps(WS.tx_start,
                                        BLOCK_BYTES(SEND_FILE,LAST_SENT-1)-
                                        ComWritePending()-
                                        WS.send_skip);

                        current = BLOCK_BYTES(SEND_FILE,LAST_SENT);
                        limit_errors(-202);
                        PSEND(TX_TXBLOCK,
                                (int) LAST_SENT,
                                (long) current,
                                (int) PRIVATE.curwindow,
                                (int) WS.tx_cps);

                        if (WS.Option.DisableAck)
                        {
                                WS.send_current = current;
                                file_bargraph(WS.send_current,SEND_FILE.size,WS.tx_cps);
                        }

                        if (send_data_block(LAST_SENT>0? LAST_SENT:1))
                                PRIVATE.reset_file_pending = 1;

                        PRIVATE.idle_timeout = SET_TIMER( PRIVATE.ack_timeout );
                }
                else

                /* we can't send a block right now- check for possible
                   timeout conditions */
                {
                        int tx_pending;

                        /* reset timeout if data is still going out */
                        tx_pending = ComWritePending();
                        if (tx_pending != PRIVATE.ptx_pending)
                        {
                                PRIVATE.ptx_pending = tx_pending;
                                PRIVATE.idle_timeout = SET_TIMER( PRIVATE.ack_timeout );

                                /* send a partial chat block if possible */
                                send_chat_block();
                        }

                        /* see if we have been idle long enough */
                        if (TIMER_UP(PRIVATE.idle_timeout))
                        {
                                PRIVATE.idle_timeout = SET_TIMER( PRIVATE.ack_timeout );
                                PRIVATE.verify_active = 0;

                                if (tx_pending)
                                {
                                        limit_errors(202);
                                        ESEND(TX_FLOWRELEASE);
                                        ComReportStatus(1101);
                                        newline();
					ComCancelXoff();
                                }

                                if (++PRIVATE.timeout_count > MAX_TIMEOUT)
                                {
                                        if (!ComGetCts())
                                        {
                                                limit_errors(203);
                                                ESEND(TX_CTSLOCK);
                                                set_cancel_link(CANCEL_FLOW_LOCKUP);
                                        } else {
                                                limit_errors(204);
                                                ESEND(TX_EXCESSTO);
                                                ComReportStatus(1101);
                                                set_cancel_link(CANCEL_REMOTE_TIMEOUT);
                                        }

                                }
                                else {
                                        if (LAST_SENT == 0)
                                                LAST_SENT = 1;

                                        report_tx_error(TX_ACKTO,LAST_SENT);
                                        ComReportStatus(1101);
                                        limit_errors(205);

                                        /* compensate for report_tx_error action */
                                        --WS.transmit_errors;

                                        if (WS.resend_count > PRIVATE.last_txack)
                                                LAST_SENT = PRIVATE.last_txack;
                                        else
                                                --LAST_SENT;
                                        ++WS.resend_count;
                                }

                                ++WS.transmit_errors;
                        }
                }

		/*
		 * continue sending mode until all blocks have been sent,
		 * acked, and no more acks or naks are pending 
		 */

                return PRIVATE.transmit_context =
                        ((LAST_SENT  < SEND_FILE.blocks) ||
                         (PRIVATE.last_txack < SEND_FILE.blocks) ||
                         PRIVATE.ack_pending || PRIVATE.nak_pending) ? 2:3;

        case 3:

                /* calculate transfer rate */

                if (WS.Option.DisableAck)
                        WS.tx_cps = calculate_cps(WS.tx_start,SEND_FILE.size-WS.send_skip);

                file_bargraph(WS.send_current,SEND_FILE.size,WS.tx_cps);
                if (PRIVATE.logcode == 'h')
                {
                        ESEND(TX_TXFILEOK,      (int)SEND_FILE.batch,
                                                (int)WS.tx_cps,
                                                sectomin(TIMER_SECS(WS.tx_start)));
                        ++WS.files_sent;
                }

                /* close file, tell receiver to mark EOF, transaction finished */

                transmit_message(PACK_CLOSE_FILE, NULL, 0);
                bclose(&PRIVATE.send_fd);

                /* make an entry in DSZLOG */

                update_status_log(
                                PRIVATE.logcode,
                                WS.send_current,
                                WS.Option.EffSpeed,
                                WS.tx_cps,
                                WS.resend_count,
                                WS.Comstat.TransmitHolds,
                                FINAL_BLOCK_SIZE(SEND_FILE),
                                                /* conversion loss warning ok */
                                path);

                WS.send_skip_total += (SEND_FILE.size - WS.send_current);
                WS.send_total += SEND_FILE.size;
                WS.send_current = 0;

                return PRIVATE.transmit_context = 0;
        }

        return PRIVATE.transmit_context = 0;
}


/* -------------------------------------------------------------------- */

/* open file, set send_fd and blocks, send file header block to remote.
   returns non-0 if file cannot be sent */

int pascal send_header_block(char *path)
{
        mem_clear(&SEND_FILE,sizeof(SEND_FILE));
        SEND_FILE.batch = ++PRIVATE.txbatch;
        SEND_FILE.BlockSize = WS.Option.BlockSize;

        ComIoStart(41);
        bopen(&PRIVATE.send_fd, path, WS.buffer_sizes, SEND_FILE.BlockSize, O_RDONLY | SH_DENYNONE);
        if (PRIVATE.send_fd.berr)
        {
                ComIoEnd(42);
                ESEND(TX_CANTOPTX, path);
                return 1;
	}

        /* determine file size, timestamp, and number of blocks to send */

        getftime(PRIVATE.send_fd.handle, &SEND_FILE.time);

        SEND_FILE.size = filelength(PRIVATE.send_fd.handle);
        ComIoEnd(43);

        SEND_FILE.blocks = (SEND_FILE.size / (long)SEND_FILE.BlockSize);
        if ((SEND_FILE.size % (long)SEND_FILE.BlockSize) != 0L)
                SEND_FILE.blocks++;

        /* remove pathname drive:\path, and copy to destination */

        strncpy(SEND_FILE.name, name_only(path), sizeof(SEND_FILE.name));

        /* finish the packet and transmit it */

        transmit_message(PACK_OPEN_FILE,(uchar *)&SEND_FILE,sizeof(SEND_FILE));

        select_send();
        display_file_banner(TX_TRANSMITTING,path,SEND_FILE.blocks,SEND_FILE.size);

        return 0;
}


/* -------------------------------------------------------------------- */

/* send a block from the specified file */

int pascal send_data_block(block_number num)
{
        int n;
        uchar *s;
        long rsize;
        unsigned counts[256];
        int send_seq;
        int send_map;

        /* locate the specified part of the file */

        rsize = BLOCK_SIZE(SEND_FILE,num);

        /* read it into the data area of the packet */

        bseek(&PRIVATE.send_fd, num-1);
        bread(&PRIVATE.send_fd, PRIVATE.send_pack.data);

        if (PRIVATE.send_fd.berr)
        {
                ESEND(TX_READERR, (int) num);
                return 1;
	}

        /* format the packet headers */

        PRIVATE.send_pack.seq.batch = SEND_FILE.batch;
        PRIVATE.send_pack.seq.block = num;

        send_seq = (PRIVATE.send_pack.seq.block != PRIVATE.prev_block);

        /* perform Dynamic Code Substitution, if requested */

        if (WS.Option.CodeSubstitution)
        {

                /* determine frequency of each code in this block */

                mem_clear(counts,sizeof(counts));
                for (n=0; n<(int)rsize; n++)
                        ++counts[PRIVATE.send_pack.data[n]];

                /* determine amount of overhead from current mapping */

                #define SMAP PRIVATE.send_pack.map

                n = counts[SMAP.xoff_map] +
                    counts[SMAP.xon_map] +
                    counts[SMAP.dle_map] +
                    counts[SMAP.start_map] +
                    counts[SMAP.end_map];

                /* calculate new mapping if needed */

                send_map = (n > sizeof(control_mapping));
                if (send_map || send_seq)
                {
                        /* prevent mapping of guarded character codes */

                        #define BLOCK_MAPPING(code) counts[code] = 0xFFFF
                        BLOCK_MAPPING(XON_CHR);
                        BLOCK_MAPPING(XOFF_CHR);
                        BLOCK_MAPPING(DLE_CHR);
                        BLOCK_MAPPING(START_PACKET_CHR);
                        BLOCK_MAPPING(END_PACKET_CHR);

                        /* map special characters to least frequently used codes */

                        #define FIND_BEST_MAPPING(MM,code)              \
                                SMAP.MM=0x80^code;                      \
                                   for (n=0; n<256; ++n)                \
                                        if (counts[n]<counts[SMAP.MM])  \
                                                SMAP.MM=n;              \
                                counts[SMAP.MM]=0xFFFF;

                        FIND_BEST_MAPPING(dle_map,   DLE_CHR);
                        FIND_BEST_MAPPING(start_map, START_PACKET_CHR);
                        FIND_BEST_MAPPING(end_map,   END_PACKET_CHR);
                        FIND_BEST_MAPPING(xon_map,   XON_CHR);
                        FIND_BEST_MAPPING(xoff_map,  XOFF_CHR);
                }
        }
        else {
                /* dynamic code substitution is disabled */

                SMAP.xoff_map  = 0x40 ^ XOFF_CHR;
                SMAP.xon_map   = 0x40 ^ XON_CHR;
                SMAP.dle_map   = 0x40 ^ DLE_CHR;
                SMAP.start_map = 0x40 ^ START_PACKET_CHR;
                SMAP.end_map   = 0x40 ^ END_PACKET_CHR;
                send_map = 0;
        }

        /* install any active mapping */

        for (s=PRIVATE.send_pack.data,n=0; n<(int)rsize; ++n,++s)
        {
                if (*s == XOFF_CHR)              *s = SMAP.xoff_map;
                else if (*s == XON_CHR)          *s = SMAP.xon_map;
                else if (*s == DLE_CHR)          *s = SMAP.dle_map;
                else if (*s == START_PACKET_CHR) *s = SMAP.start_map;
                else if (*s == END_PACKET_CHR)   *s = SMAP.end_map;
                else if (*s == SMAP.xoff_map)    *s = XOFF_CHR;
                else if (*s == SMAP.xon_map)     *s = XON_CHR;
                else if (*s == SMAP.dle_map)     *s = DLE_CHR;
                else if (*s == SMAP.start_map)   *s = START_PACKET_CHR;
                else if (*s == SMAP.end_map)     *s = END_PACKET_CHR;
        }

#ifdef DEBUG
        if (WS.Option.Debug)
                printf("<sending %s%sDATA block %u>",
                        send_seq?"SEQ+":"",
                        send_map?"MAP+":"",
                        num);
#endif

        if (num == 1)
                WS.tx_start = bios_clock();

        /* enque the packet for transmission */

        if (send_seq || !WS.Option.MinimalBlocks)
        {
                transmit_message(PACK_DATA_BLOCK_SMD,(uchar *)&PRIVATE.send_pack,
                                        sizeof(sequence_packet)+
                                        sizeof(control_mapping)+ rsize);
        }
        else if (send_map)
        {
                transmit_message(PACK_DATA_BLOCK_MD,(uchar *)&PRIVATE.send_pack.map,
                                        sizeof(control_mapping)+ rsize);
        }
        else
                transmit_message(PACK_DATA_BLOCK_D,(uchar *)PRIVATE.send_pack.data,rsize);

        PRIVATE.prev_block = PRIVATE.send_pack.seq.block+1;
        return 0;
}


/* -------------------------------------------------------------------- */

/*
 * send a block of verification CRC values
 * returns non-0 when no more verification blocks are needed
 *
 */

int pascal send_verify_block(block_number start)
{
        resume_verify_packet pack;
        int i;
        int count;

        if (start > SEND_FILE.blocks)
                return 1;

        count = SEND_FILE.blocks-start+1;
        if (count > MAX_VERIFY_COUNT)
                count = MAX_VERIFY_COUNT;

        PSEND((count > 1)?
                TX_VERMULT:TX_VERSINGLE,
                        (int)start,
                        (int)start+count-1);

        mem_clear(&pack,sizeof(pack));
        pack.base_block = start;
        pack.count = 0;

        bseek(&PRIVATE.send_fd,start-1);
        for (i=0; i<count; i++)
        {
                if ((i&7) == 7)
                        disp_message(".");

                bread(&PRIVATE.send_fd,PRIVATE.send_pack.data);
                if (PRIVATE.send_fd.berr)
                        break;

                pack.check[i] = calculate_CRC(PRIVATE.send_pack.data,SEND_FILE.BlockSize);
                ++pack.count;
        }

        disp_message("\r");

        transmit_message(PACK_VERIFY_BLOCK, (uchar *)&pack,
                sizeof(pack)-((MAX_VERIFY_COUNT-pack.count)*sizeof(CRC_type)));

        /* ComFlush(0); */  /* do not disable handshake */

        return (pack.count < MAX_VERIFY_COUNT);
}


/* -------------------------------------------------------------------- */

/*
 * transmit a single character with a DLE prefix
 *
 */
static void pascal send_dle_char(uchar c)
{
        PRE_WRITE(DLE_CHR);
        if (WS.Option.AlternateDle)
                c ^= 0x40;
        else
                c ^= 0x80;
        PRE_WRITE(c);
}


/* -------------------------------------------------------------------- */

/*
 * transmit each byte in a block, escape special-looking data
 * characters with DLE, otherwise send unchanged
 */

static void pascal send_dle_block(uchar *data,
                                  int size)
{
        register uchar c;
        register uchar pc;

        // use quickest escapes if possible
        if (WS.Option.MinimalBlocks &&
            !WS.Option.XonHandshake &&
            REMOTE_READY.final_ready)
        {
              pc = 0;
              while (size)
              {
                      --size;
                      c = *data++;

                      switch (c)
                      {
                      case START_PACKET_CHR:
                      case END_PACKET_CHR:
                      case DLE_CHR:
                              send_dle_char(c);
                              break;

                      case CAN_CHR:   /* check for two consecutive CAN codes */
                              if (pc == c)
                                      send_dle_char(c);
                              else
                                      PRE_WRITE(c);
                              break;

                      default:
                              PRE_WRITE(c);
                              break;
                      }
                      pc = c;
              }
              return;
        }

        // use more conservative escapes if xon/xoff is active,
        // if minimal blocks is disabled, and always if final ready
        // status has not been negotiated.
        pc = 0;
        while (size)
        {
                --size;
                c = *data++;

                switch (c)
                {
                case XON_CHR+0x80:
                case XOFF_CHR+0x80:
                        if (WS.Option.AlternateDle)
                                send_dle_char(c);
                        else
                                PRE_WRITE(c);
                        break;

                case XON_CHR:
                case XOFF_CHR:
                case START_PACKET_CHR:
                case END_PACKET_CHR:
                case DLE_CHR:
                        send_dle_char(c);
                        break;

                                
                case CAN_CHR:   /* check for two consecutive CAN codes */
                        if (pc == c)
                                send_dle_char(c);
                        else
                                PRE_WRITE(c);
                        break;

                case '@'+0x80:
                case '@':
                        if ((pc & 0x7f) == '\r')
                                send_dle_char(c);
                        else
                                PRE_WRITE(c);
                        break;

                case '\r'+0x80:
                case '\r':
                        if ((pc & 0x7f) == '@')
                                send_dle_char(c);
                        else
                                PRE_WRITE(c);
                        break;

                default:
                        PRE_WRITE(c);
                        break;
                }
                pc = c;
        }
}

/* -------------------------------------------------------------------- */

/*
 * transmit the specified message to the remote (enque data, do not wait)
 *
 * All message frames have the same format:
 *      START_PACKET_CHR
 *      message_type
 *      crc(1..CrcSize)        - only if data_size > 0
 *      data(1)                 - only if data_size > 0
 *      ...                     - only if data_size > 0
 *      data(data_size)         - only if data_size > 0
 *      END_PACKET_CHR
 *
 */

void pascal transmit_message(enum message_types message_type,
                       uchar *data,
                       int data_size)
{
        CRC_type lCRC;

        /* quit right away if carrier is not present */

        if (ComCarrierLost())
                return;

        /* terminate any previous packets in case of flow control failure */
        if (WS.transmit_errors)
        {
                if ((message_type != PACK_READY) &&
                    (message_type != PACK_READY_RECV))
                        PRE_WRITE(END_PACKET_CHR);
        }

        /* transmit the message start and packet type codes */

        PRE_WRITE(START_PACKET_CHR);
        PRE_WRITE(message_type);

        /* transmit the block CRC and the block data */

        if (data_size)
        {
                lCRC = calculate_CRC(data,data_size);

                send_dle_block((uchar *)&lCRC,WS.Option.CrcSize);

#ifdef DEBUG
                if (WS.Option.Debug)
                {
                        printf("\nTRANSMIT BLOCK; type=%c size=%d buf=%04x contents=",
                                        message_type,data_size,data);
                        if (WS.Option.Debug>1)
                        {
                                DUMP_BLOCK(data,data_size);
                        }
                }
#endif

                send_dle_block(data,data_size);

        }

        PRE_WRITE(END_PACKET_CHR);
        PRE_WRITE_FLUSH;
}

