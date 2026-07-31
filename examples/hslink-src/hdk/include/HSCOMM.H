
/*
 * COPYRIGHT 1992 SAMUEL H. SMITH
 * ALL RIGHTS RESERVED
 *
 * THIS DOCUMENT CONTAINS CONFIDENTIAL INFORMATION AND TRADE SECRETS
 * PROPRIETARY TO SAMUEL H. SMITH DBA THE TOOL SHOP.
 *
 */


/*
 * hscomm.h - HS/Link com port library
 *
 */


/*********************************************************************
               * COMM SERVICES PROVIDED BY APPLICATION *
 *********************************************************************/

void pascal ComOpen(void);
void pascal ComClose(void);

void pascal ComSetHandshake(void);

long pascal ComGetSpeed(void);
int pascal ComGetCts(void);
int pascal ComCarrierLost(void);

int pascal ComReadPending(void);
int pascal ComReadChar(void);
unsigned pascal ComReadStr(uchar *dest, unsigned bufsiz);

void pascal ComWriteChar(uchar c);
void pascal ComWriteStr(uchar *src, unsigned count);
int pascal ComWritePending(void);
int pascal ComWriteMax(void);

void pascal  ComCancelXoff(void);

void pascal ComFlush(int cancel);

void pascal ComIoStart(int where);
void pascal ComIoEnd(int where);

void pascal ComReportErrors(void);
void pascal ComReportStatus(int where);

void pascal ComIdle(int where);

