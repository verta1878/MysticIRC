
/*
 * COPYRIGHT 1992 SAMUEL H. SMITH
 * ALL RIGHTS RESERVED
 *
 * THIS DOCUMENT CONTAINS CONFIDENTIAL INFORMATION AND TRADE SECRETS
 * PROPRIETARY TO SAMUEL H. SMITH DBA THE TOOL SHOP.
 *
 */


/*
 * hstop.h - HS/Link, top level driver functions
 *
 */

int pascal top_init(void);
int pascal wait_for_ready(void);
int pascal finish_receive(void);
int pascal terminate_link(void);

void pascal set_cancel_link(int code);
