
/*
 * COPYRIGHT 1992 SAMUEL H. SMITH
 * ALL RIGHTS RESERVED
 *
 * THIS DOCUMENT CONTAINS CONFIDENTIAL INFORMATION AND TRADE SECRETS
 * PROPRIETARY TO SAMUEL H. SMITH DBA THE TOOL SHOP.
 *
 */

/*
 * hsopt.c - command line options and config files for HS/LINK protocol.
 *             
 */

#include <stdlib.h>
#include <stdio.h>
#include <io.h>
#include <conio.h>
#include <dos.h>
#ifdef __TURBOC__
#include <dir.h>
#endif
#include <string.h>
#include <fcntl.h>
#include <share.h>
#include <ctype.h>

#include "hdktext.h"
#include "hspriv.h"
#include <hdk.h>

/* -------------------------------------------------------------- */

/* provide color definitions for MSC */
#if !defined(__COLORS)

enum COLORS {
    BLACK,          /* dark colors */
    BLUE,
    GREEN,
    CYAN,
    RED,
    MAGENTA,
    BROWN,
    LIGHTGRAY,
    DARKGRAY,       /* light colors */
    LIGHTBLUE,
    LIGHTGREEN,
    LIGHTCYAN,
    LIGHTRED,
    LIGHTMAGENTA,
    YELLOW,
    WHITE
};
#endif

/* -------------------------------------------------------------- */

/* queue one or more transmit files based on command line filespec,
 * either simple filename, wildcard or @ response list */

void pascal queue_transmit(char *spec)
{
#ifdef __TURBOC__
        struct ffblk ffblk;
        #define FFSIZE ffblk.ff_fsize
        #define FFNAME ffblk.ff_name
#else
        struct _find_t ffblk;
        #define findfirst(SPEC,BLK,ATTR) _dos_findfirst(SPEC,ATTR,BLK)
        #define findnext(BLK) _dos_findnext(BLK)
        #define FFSIZE ffblk.size
        #define FFNAME ffblk.name
#endif
        char atfname[80+1];
        static char prevdir[65];
        int done;

        if ((*spec == 0) || (*spec == '-'))
                return;
        if (WS.cancel_link)
                return;

        /* check for @ indirection to another file for the list
           of filespecs to transmit */

        if (*spec == '@')
        {
                buffered_file atfd;
                spec++;     /* skip the @ */

                bopen(&atfd,spec,256,1,O_RDONLY | SH_DENYNONE);
                if (atfd.berr)
                {
                        ESEND(TX_BADFILELIST,spec);
                        return;
                }

                /* read each filespec from the @file and transmit
                   it to other side */
                for (;;)
                {
                        done = bgetline(atfname,sizeof(atfname)-1,&atfd);
                        if (done || WS.cancel_link) break;

                        queue_transmit(atfname);
                }

                bclose(&atfd);
                return;
        }

        /* default to previous fully specified directory */

        if (*path_only(spec) == 0)
        {
                strcpy(atfname,prevdir);
                strcat(atfname,spec);
                spec = atfname;
        }
        strcpy(prevdir,path_only(spec));

        /* expand wildcards */

        done = findfirst(spec,&ffblk,0);

        if (done)
                ESEND(TX_NOMATCH,spec);

        while (!done)
        {
                pathname_node *node;

                if (WS.cancel_link)
                        return;

                /* count this as file expected to transmit */

                ++WS.send_expected;
                WS.send_bytes += FFSIZE;

                /* splice in the original drive and directory with the
                   wildcard name and ext to form the final pathname
                   to be transmitted */

                strcpy(atfname,path_only(spec));
                strcat(atfname,FFNAME);
                (void)strupr(atfname);

                /* create transmit list entry for the filespec */
                node = (pathname_node *)mem_alloc(sizeof(pathname_node));
                node->next = NULL;
                node->name = (char *)mem_alloc(strlen(atfname)+1);
                strcpy(node->name,atfname);

                /* enter the entry into the linked list */
                if (WS.first_send)
                {   /* append to list */
                    WS.last_send->next = node;
                    WS.last_send = node;
                }
                else {              /* create new list */
                    WS.first_send = node;
                    WS.last_send = node;
                }

                done = findnext(&ffblk);
        }
}


/* -------------------------------------------------------------- */

/* set command line option defaults */

void pascal set_defaults()
{
        WS.Option.Priority              = DEFAULT_BANG;
        WS.Option.DisableAck            = DEFAULT_A;
        WS.Option.ComSpeed              = DEFAULT_B;
        WS.Option.RequireCarrier        = DEFAULT_C;
        WS.Option.BorderAttr            = DEFAULT_CB;
        WS.Option.GraphAttr             = DEFAULT_CG;
        WS.Option.DispPos               = DEFAULT_CP;
        WS.Option.MainAttr              = DEFAULT_CM;
        WS.Option.TitleAttr             = DEFAULT_CT;
        WS.Option.WindowAttr            = DEFAULT_CW;
        WS.Option.Debug                 = DEFAULT_D;
        WS.Option.EffSpeed              = DEFAULT_E;
        WS.Option.ForceCts              = DEFAULT_FC;
        WS.Option.FifoThresh            = DEFAULT_FT;
        WS.Option.CtsHandshake          = DEFAULT_HC;
        WS.Option.RtsHandshake          = DEFAULT_HR;
        WS.Option.SlowHandshake         = DEFAULT_HS;
        WS.Option.XonHandshake          = DEFAULT_HX;
        WS.Option.IdleMethod            = DEFAULT_I;
        WS.Option.KeepAborted           = DEFAULT_K;
        WS.Option.Disable16550          = DEFAULT_N5;
        WS.Option.AlternateDle          = DEFAULT_NA;
        WS.Option.FileBuffering         = DEFAULT_NB;
        WS.Option.CodeSubstitution      = DEFAULT_NC;
        WS.Option.MaxError              = DEFAULT_NE;
        WS.Option.FullDisplay           = DEFAULT_NF;
        WS.Option.DisableCtlG           = DEFAULT_NG;
        WS.Option.MinimalBlocks         = DEFAULT_NM;
        WS.Option.DisablePartialBlocks  = DEFAULT_NP;
        WS.Option.StampTime             = DEFAULT_NT;
        WS.Option.BlockUpload           = DEFAULT_NU;
        WS.Option.DirectVideo           = DEFAULT_NV;
        WS.Option.AllowOverwrite        = DEFAULT_O;
        WS.Option.ComPort               = DEFAULT_P;
        WS.Option.ComBase               = DEFAULT_PB;
        WS.Option.ComIrq                = DEFAULT_PI;
        WS.Option.ResumeVerify          = DEFAULT_R;
        WS.Option.BlockSize             = DEFAULT_S;
        WS.Option.TermMode              = DEFAULT_T;
        WS.Option.MaxWind               = DEFAULT_W;
        WS.Option.CrcSize               = DEFAULT_CRCSZ;

        WS.Option.StatusLogFile[0] = 0;
        WS.Option.DupeChecklist[0] = 0;

        getcwd(WS.Option.ReceiveDir,sizeof(WS.Option.ReceiveDir));
}

