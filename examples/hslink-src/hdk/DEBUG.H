
/*
 * COPYRIGHT 1992 SAMUEL H. SMITH
 * ALL RIGHTS RESERVED
 *
 * THIS DOCUMENT CONTAINS CONFIDENTIAL INFORMATION AND TRADE SECRETS
 * PROPRIETARY TO SAMUEL H. SMITH DBA THE TOOL SHOP.
 *
 */


#define DBPF printf
#define DBPC putchar
#define DBNL DBPC('\n')

#define DUMP_BLOCK(BUF,COUNT)                                           \
{                                                                       \
        int i,cnt;                                                      \
        ComIoStart(9998);                                               \
        cnt=(((COUNT)+15)&0xFFF0);                                      \
        for (i=0; i<= cnt; i++) {                                       \
                if ((i==cnt)||((i%16)==0)) {                            \
                        if (i) {                                        \
                                int j,c;                                \
                                DBPF("  [");                            \
                                for (j=0; j<=15; j++) {                 \
                                        c = ((char*)BUF)[i-16+j];       \
                                        if ((i-16+j) < (COUNT)) {       \
                                                if (c < ' ')            \
                                                        DBPC('.');      \
                                                else                    \
                                                        DBPC(c);        \
                                         }                              \
                                }                                       \
                                DBPF("]");                              \
                        }                                               \
                        if (i < cnt)                                    \
                                DBPF("\n%04x:",i);                      \
                }                                                       \
                if (i < (COUNT))                                        \
                        DBPF(" %02x",((int)((char*)BUF)[i])&0xff);      \
                else                                                    \
                        DBPF(" __");                                    \
        }                                                               \
        DBPF("<END>\n");                                                \
        ComIoEnd(9999);                                                 \
}

