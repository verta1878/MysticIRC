
/*
 * COPYRIGHT 1992 SAMUEL H. SMITH
 * ALL RIGHTS RESERVED
 *
 * THIS DOCUMENT CONTAINS CONFIDENTIAL INFORMATION AND TRADE SECRETS
 * PROPRIETARY TO SAMUEL H. SMITH DBA THE TOOL SHOP.
 *
 */


CRC_type pascal calculate_CRC(uchar *data,
                       int size);

#define CRCOF(IDENT) calculate_CRC((uchar*)&IDENT,sizeof(IDENT))

