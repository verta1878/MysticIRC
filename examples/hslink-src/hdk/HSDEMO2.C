
/*
 * demo program for HS/LINK DEVELOPER KIT 1.1
 *
 * link with HUGE, MULTIPLE-THREAD HDK library
 *
 */

#include <stdlib.h>
#include <stdio.h>
#include <io.h>
#include <conio.h>
#include <ctype.h>
#include <dos.h>
#include <dir.h>
#include <string.h>
#include <fcntl.h>

#include <hdk.h>

/* dummy declarations to simulate a MAJOR BBS-like environment */

int usrnum;

typedef struct {
        int substt;             /* substate for each user */
        workspace_rec *appws;   /* hslink workspace pointer for each user */
        pathname_node *curnode; /* current file in batch for each user */
} user_data_rec;

user_data_rec udata[255];       /* user data for 255 users */

/* -------------------------------------------------------------- */

/* prototype for the main driver function for hslink transfers */

int hslink_input(user_data_rec *udta,           /* current user data record */
                 int argc,                      /* argument count */
                 char *argv[]);                 /* argument values */

/* -------------------------------------------------------------- */

/* this main() provides an example of how the demo hslink_input is meant
   to be called.  Substitute actual application calls to hslink_input in
   your real program */

int main(int argc, char *argv[])
{
        int i;
        int hsargc;
        char *hsargv[10];

        /* clear the user data table */
        for (i=0; i<255; i++)
        {
                udata[i].substt = 0;
                udata[i].appws = 0;
                udata[i].curnode = 0;
        }

        /* specify a dummy user number */
        usrnum = 33;

        /* specify dummy list of files to be transferred for this user */
        hsargc = 3;
        hsargv[1] = "C:\\DL1\\FILE1.ZIP";
        hsargv[2] = "C:\\DL7\\GTZ*.ZIP";
        /* hsargv[0] (third arg) normally points to our EXE filespec,
           but is not really needed in this context */
        
        /* set substate to 0 and iterate the input function to perform
           the file transfer.  in an environment like major bbs this
           would be done by the executive on all applicable user numbers */

        udata[usrnum].substt = 0;
        while (hslink_input(&udata[usrnum],hsargc,hsargv))
        {
                /* idle */
        }

        /* once hslink_input returns 0 we are finished */
        exit(0);
}

/* -------------------------------------------------------------- */

/*
 * this function is called repeatedly to perform hslink transfers.
 * initial entry is with substt = 0, which causes a user-specific
 * workspace to be allocated.  subsequent values of substt are application
 * defined during file transfer.  on completion of transfer, workspace is
 * de-allocated and substt is returned to 0.
 *
 * return value is non-0 when transfer is running and 0 when no further
 * calls are expected, except to initiate the next transfer.
 *
 */

int hslink_input(user_data_rec *udta,           /* current user data record */
                 int argc,                      /* argument count */
                 char *argv[])                  /* argument values */
{
        /* allocate application workspace if needed */
        if (udta->substt == 0)
        {
                udta->appws = (workspace_rec*)mem_alloc(sizeof(workspace_rec));
                if (udta->appws == 0)
                {
                        cprintf("Cannot allocate workspace for user %d!\r\n",usrnum);
                        return 0;
                }
        }

        /* current workspace to application workspace for this user */
        current_hsws = udta->appws;

        /* process current substate */
        switch (udta->substt)
        {
        case 0:
                if (top_init())
                {
                        udta->substt = 0;
                        break;
                }

                set_defaults();

                if (argc == 1)
                {
                        usage("No command line given\r\n","");
                        udta->substt = 0;
                        break;
                }

                if (process_options(argc,argv))
                {
                        usage("No command line given\r\n","");
                        udta->substt = 0;
                        break;
                }

                ComOpen();

                WS.Option.ComSpeed = ComGetSpeed();
                if (!WS.Option.EffSpeed)
                        WS.Option.EffSpeed = WS.Option.ComSpeed;

                /* we're now ready for SlowHandshake to work */
                WS.IoLevel = 0;

                /* allocate up to 10k for file buffers, but no more */
                WS.buffer_sizes = mem_avail()-1000>10240: 10240:mem_avail()-1000;

                /* display opening screen */
                prepare_display();
                process_filespecs(argc,argv);

                /* verify hardware handshake status */
                if (!ComGetCts() && !WS.Option.ForceCts)
                {
                        cprintf("CTS signal missing!  Please use -HC or -FC option.\r\n");
                        WS.Option.CtsHandshake = 0;
                }

                udta->substt = 1;
                break;

        case 1:
                /* wait for ready handshake with remote */
                service_receive();
                udta->substt = wait_for_ready()? 1:2;
                break;

        case 2:
                /* select first file in batch and begin transmit */
                udta->curnode = WS.first_send;
                udta->substt = 3;
                break;

        case 3:
                /* end of batch? change to state 4 */
                if (udta->curnode == NULL)
                {
                        udta->substt = 4;
                        PSEND("%d file%s transmitted.\r\n",WS.files_sent,
                                                           WS.files_sent==1?"":"s");
                        break;
                }

                service_receive();
                if (transmit_file(udta->curnode->name))
                        break;          /* remain in state 3 */

                /* advance to next file in the batch */
                udta->curnode = udta->curnode->next;
                break;

        case 4:
                /* wait for remaining receive activity to terminate */
                service_receive();
                udta->substt = finish_receive()? 4:5;
                break;

        case 5:
                /* close down link */
                udta->substt = terminate_link()? 5:6;
                break;

        case 6:
                /* process exit codes */
                if (ComCarrierLost())
                        set_cancel_link(CANCEL_CARRIER_LOST);
                if ((WS.files_received+WS.files_sent) ==0)
                        set_cancel_link(CANCEL_NO_FILES);

                ComClose();
                close_display();
                cprintf("HS/Link finished! (t:%d r:%d)",WS.files_sent,WS.files_received);
                cprintf("  Exit code = %d\r\n",(int)WS.cancel_link);
                udta->substt = 0;
                break;
        }

        /* if substt is 0 we are done and need to free the workspace */
        if (udta->substt == 0)
        {
                current_hsws = 0;
                mem_free(udta->appws);
                udta->appws = 0;
        }

        /* otherwise we need more calls- return non 0 */
        return udta->substt;
}


