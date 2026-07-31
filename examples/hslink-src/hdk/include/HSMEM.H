
/*
 * COPYRIGHT 1992 SAMUEL H. SMITH
 * ALL RIGHTS RESERVED
 *
 * THIS DOCUMENT CONTAINS CONFIDENTIAL INFORMATION AND TRADE SECRETS
 * PROPRIETARY TO SAMUEL H. SMITH DBA THE TOOL SHOP.
 *
 */


/*********************************************************************
         * MEMORY MANAGEMENT SERVICES PROVIDED BY APPLICATION *
 *********************************************************************/

unsigned pascal mem_avail(void);
void* pascal mem_alloc(unsigned size);
void pascal mem_free(void *block);
void pascal mem_clear(void *block, unsigned size);
void pascal mem_copy(uchar *dest, uchar *src, unsigned size);

