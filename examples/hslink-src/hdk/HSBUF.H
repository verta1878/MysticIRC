
/*
 * COPYRIGHT 1992 SAMUEL H. SMITH
 * ALL RIGHTS RESERVED
 *
 * THIS DOCUMENT CONTAINS CONFIDENTIAL INFORMATION AND TRADE SECRETS
 * PROPRIETARY TO SAMUEL H. SMITH DBA THE TOOL SHOP.
 *
 */


/*
 * hsbuf - HS/Link Buffered File I/O Unit
 *
 */

typedef struct buffered_file {	/* buffered file description record */
	char pathname[65];	/* full name of the file */
	int handle;		/* handle for dos calls */
	unsigned maxrec;	/* maximum number of records */
	unsigned recsiz;	/* record size */
	unsigned bufsiz;	/* size of the data buffer */
        unsigned filerecs;      /* count of records in existing files */
        uchar *buffer;          /* the data buffer */
	unsigned fptr;		/* base record in file for buffer */
	unsigned fnext;		/* next record position in buffer (0=first) */
	unsigned fcount;	/* count of records in buffer */
        uchar dirty;            /* unsaved changes in buffer? */
        uchar berr;             /* error flag - true if read/write failure */
} buffered_file;

void pascal bcreate(char *name);       /* create an empty file; use with
                                        * bopen to open output files */

void pascal bprepare(buffered_file *bfd,
                     int fd,
                     unsigned maxbufm,
                     unsigned recsize); /* enable buffering on an already
					 * open dos handle */

void pascal bopen(buffered_file *bfd,
                  char *name,
                  unsigned maxbufm,
                  unsigned recsize,
                  int openmode);        /* open a buffered file -
                                         * sets 'berr' if not ok */

void pascal bflush(buffered_file *bfd);  /* write buffer, force re-read on
					 * next access */

void pascal bseek(buffered_file *bfd,
                  unsigned recn);      /* set position of buffered file */

void pascal bseekeof(buffered_file *bfd);
                                        /* set position of buffered file to
					 * end-of-file */

unsigned pascal btell(buffered_file *bfd);
                                        /* tell current record number in
					 * buffered file */

char pascal beof(buffered_file *bfd);   /* check for eof on buffered file */

void pascal bread(buffered_file *bfd,
                  uchar *dest);         /* buffered read */

void pascal bwrite(buffered_file *bfd,
                   uchar *src);         /* buffered write */

void pascal bclose(buffered_file *bfd); /* close a buffered file */

void pascal bclose_set(buffered_file *bfd,
                       long filesize,
                       struct ftime *time);
                                        /* close a buffered file, set exact
					 * file size and time stamp */

int pascal bgetline(char *buf, int size, buffered_file *fd);

