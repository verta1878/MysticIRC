
/*
 * demo program for HS/LINK DEVELOPER KIT 1.1
 *
 * link with SMALL, SINGLE-THREAD HDK library
 *
 */

#include <hdk.h>

/* if the library does not have a static workspace, we will allocate a
   single workspace record and tell the library to use it.  */

#ifndef STATIC_WORKSPACE
        workspace_rec static_workspace;
#endif


/* -------------------------------------------------------------- */

/* trap user break to prevent dangling interrupt handlers */

int control_c(void)
{
	return 1;       /* continue program */
}

/* -------------------------------------------------------------- */

int main(int argc, char *argv[])
{
        pathname_node *node;

#ifndef STATIC_WORKSPACE
        /* tell the library to use our local static workspace */
        current_hsws = &static_workspace;
#endif

        if (top_init())
                exit(1);

        set_defaults();

        if (argc == 1)
        {
                usage("No command line given\r\n","");
                exit(1);
        }

        if (process_options(argc,argv))
                exit(1);

        ComOpen();

        WS.Option.ComSpeed = ComGetSpeed();
        if (!WS.Option.EffSpeed)
                WS.Option.EffSpeed = WS.Option.ComSpeed;

        ctrlbrk(control_c);

        /* we're now ready for SlowHandshake to work */
        WS.IoLevel = 0;

        /* allocate most of remaining memory to file buffers */
        WS.buffer_sizes = mem_avail()-1000;

        /* display opening screen */
        prepare_display();
        process_filespecs(argc,argv);

        /* verify hardware handshake status */
        if (!ComGetCts() && !WS.Option.ForceCts)
        {
                cprintf("CTS signal missing!  Please use -HC or -FC option.\r\n");
                WS.Option.CtsHandshake = 0;
        }

        /* wait for ready handshake with remote */
        while (wait_for_ready())
        {
                ComIdle(301);
                service_receive();
        }


        /*
	 * transmit each outgoing file (received files are processed in the
	 * background, during ACK waits) 
	 */
        if (WS.send_expected)
                display_outgoing_files();

        node = WS.first_send;
        while (node)
        {
                while (transmit_file(node->name))
                {
                        ComIdle(201);
                        service_receive();
                }

                node = node->next;      /* select next file in batch */
        }

        /* wait for remaining receive activity to terminate */

        PSEND("%d file%s transmitted.\r\n",WS.files_sent,
                                           WS.files_sent==1?"":"s");

        while (finish_receive())
        {
                ComIdle(302);
                service_receive();
        }

        /* close down link */

        while (terminate_link())
        {
                ComIdle(303);
        }

        /* process exit codes */
        if (ComCarrierLost())
                set_cancel_link(CANCEL_CARRIER_LOST);
        if ((WS.files_received+WS.files_sent) ==0)
                set_cancel_link(CANCEL_NO_FILES);

        ComClose();
        close_display();
        cprintf("HS/Link finished! (t:%d r:%d)",WS.files_sent,WS.files_received);
        cprintf("  Exit code = %d",(int)WS.cancel_link);

        if (WS.cancel_link)
                delay(3000);
        newline();

        /* exit with errorlevel */
        return WS.cancel_link;
}


