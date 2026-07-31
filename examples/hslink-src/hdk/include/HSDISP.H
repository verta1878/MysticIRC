
/*
 * COPYRIGHT 1992 SAMUEL H. SMITH
 * ALL RIGHTS RESERVED
 *
 * THIS DOCUMENT CONTAINS CONFIDENTIAL INFORMATION AND TRADE SECRETS
 * PROPRIETARY TO SAMUEL H. SMITH DBA THE TOOL SHOP.
 *
 */


/*********************************************************************
        * DISPLAY MANAGEMENT SERVICES PROVIDED BY APPLICATION *
 *********************************************************************/

/* macros used to display to the major windows */
#define POPTION   select_option(),  disp_message
#define PRECV     select_recv(),    disp_message
#define PSEND     select_send(),    disp_message
#define PVERSION  select_version(), disp_message

/* macros used to display to the major windows with error logging */
#define EOPTION   select_option(),  disp_error
#define ERECV     select_recv(),    disp_error
#define ESEND     select_send(),    disp_error
#define EVERSION  select_version(), disp_error

/* overall display management */
void pascal prepare_display(void);
void pascal select_option(void);
void pascal select_recv(void);
void pascal select_send(void);
void pascal select_version(void);
void pascal newline(void);
void pascal close_display(void);
void disp_message(char *fmt, ...);

/* chat window management */
void pascal display_chatin(char *s);
void pascal display_chatout(register char c);

/* initial status and information display preparation */
void pascal display_settings(void);

/* file progress displays */
void pascal display_incoming_files(void);
void pascal display_outgoing_files(void);
void pascal display_file_banner(char *mode,
                                char *fname,
                                unsigned blocks,
                                long bytes);
void pascal file_bargraph(long current, long total, unsigned cps);
void pascal report_combined(void);

/* report error messages */
void disp_error(char *fmt, ...);
void log_error(char *fmt, ...);
void pascal report_rx_error( char *what );
void pascal report_tx_error( char *what, block_number block );
void pascal display_warning( char *what );

/* usage messages */
void pascal usage(char *why, char *par);
void pascal usage_license(void);

/* filter/display incoming blocks */
void pascal filter_rx_block( char *fname, long offset, unsigned size, char *data );

