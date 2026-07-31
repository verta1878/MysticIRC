#undef DEBUG
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
 * This unit provides both read and write buffering on block oriented
 * random-access files.  It is optimized for sequential reads or writes,
 * but will function properly with fully random files.
 *
 */

#include <io.h>
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <share.h>
#include <dos.h>
#include <conio.h>
#include <string.h>

#include "hspriv.h"
#include <hdk.h>



/* -------------------------------------------------------- */

/* create an empty file */

void pascal bcreate(char *name)
{
        int fd;
        fd = _creat(name, 0);
        if (fd > 0)
                _close(fd);
}


/* -------------------------------------------------------- */

 /* enable buffering on an already open dos handle */

void pascal bprepare(
        buffered_file *bfd,
        int fd,
        unsigned maxbufm,        /* memory for buffering */
        unsigned recsize)        /* record size of file */
{
        unsigned avail;

        bfd->handle = fd;
        bfd->fnext = 0;
        bfd->fcount = 0;

        if (bfd->handle <= 0) {
                bfd->berr = 1;
                return;
        }

        bfd->berr = 0;
        bfd->recsiz = recsize;

        avail = mem_avail();
        if (avail < maxbufm)
                maxbufm = avail;
        bfd->maxrec = maxbufm / recsize;

        if (bfd->maxrec < 1)
                WS.Option.FileBuffering = 0;
        if (!WS.Option.FileBuffering)
                bfd->maxrec = 0;

        bfd->bufsiz = bfd->maxrec * recsize;
        if (bfd->bufsiz)
                bfd->buffer = (uchar *) mem_alloc(bfd->bufsiz);

        bfd->filerecs = lseek(bfd->handle, 0, SEEK_END) / (long) (bfd->recsiz);
        lseek(bfd->handle, 0, SEEK_SET);

#ifdef DEBUG
        printf("bprepare: maxbufm=%u maxrec=%u recsize=%u buffer=%04x bufsiz=%u core=%u path=%s\n",
                maxbufm,
                bfd->maxrec,
                recsize,
                bfd->buffer,
                bfd->bufsiz,
                mem_avail(),
                bfd->pathname);
#endif
}


/* -------------------------------------------------------- */

 /* open a buffered file */

void pascal bopen(
        buffered_file *bfd,
        char *name,
        unsigned maxbufm,
        unsigned recsize,
        int openmode)
{
        mem_clear(bfd,sizeof(buffered_file));

        /* open the file and allocate a buffer for it */
        ComIoStart(10);

        /* remove share modes on dos 2.x */
        if (_osmajor < 3)
                openmode &= 0x0F;

        bfd->handle = _open(name, openmode);

        /* revert to non-shared modes if SHARE is not loaded */
        if ((bfd->handle < 1) && (openmode > 0x0F))
        {
                openmode &= 0x0F;
                bfd->handle = _open(name, openmode);
        }

        /* reject character devices as valid filenames */
        if ((bfd->handle > 0) && isatty(bfd->handle))
        {
                _close(bfd->handle);
                bfd->handle = -1;
        }

        strcpy(bfd->pathname, name);
        bprepare(bfd, bfd->handle, maxbufm, recsize);

        /* pre-read first buffer full of input data */
        if (!bfd->berr)
                beof(bfd);

        ComIoEnd(11);

#ifdef DEBUG
        printf("bopen: name=%s handle=%d buffer=%04x err=%d\n",
                name,
                bfd->handle,
                bfd->buffer,
                bfd->berr);
#endif
}


/* -------------------------------------------------------- */

 /* save changes in buffer, force re-read on next access */

void pascal bflush(buffered_file *bfd)
{
	unsigned w, n;

	/* if file has been written, write buffer contents */
        if (bfd->dirty)
        {
                ComIoStart(12);
                lseek(bfd->handle, (long) bfd->fptr * (long) bfd->recsiz, SEEK_SET);
		w = bfd->recsiz * bfd->fcount;
                n = write(bfd->handle, bfd->buffer, w);
#ifdef DEBUG
                if (WS.Option.Debug)
                {
                        DBPF("\ndos write: w=%u ",w);
                        DUMP_BLOCK(bfd->buffer,w);
                }
#endif
                ComIoEnd(13);
                bfd->berr = (n != w);
		bfd->dirty = 0;
	}
	else
                bfd->berr = 0;

	/* adjust physical position in file and empty the buffer */
	bfd->fptr += bfd->fnext;
	bfd->fnext = 0;
	bfd->fcount = 0;
        lseek(bfd->handle, (long) bfd->fptr * (long) bfd->recsiz, SEEK_SET);
}


/* -------------------------------------------------------- */

 /* set position of buffered file */

void pascal bseek(buffered_file *bfd,
                  unsigned recn)
{
        /* reposition within buffer, if possible */
	if ((recn >= bfd->fptr) && (recn <= bfd->fptr + bfd->fcount))
		 bfd->fnext = recn - bfd->fptr;
	else {
		/* save changes, if any */
		if (bfd->dirty)
			bflush(bfd);

		/* perform the physical seek */
		bfd->fptr = recn;
		bfd->fnext = 0;
		bfd->fcount = 0;
                lseek(bfd->handle, (long) recn * (long) bfd->recsiz, SEEK_SET);
	}
}


/* -------------------------------------------------------- */

 /* set position of buffered file to end-of-file */

void pascal bseekeof(buffered_file *bfd)
{
	/* save changes, if any */
        if (bfd->dirty)
                 bflush(bfd);

        bseek( bfd, bfd->filerecs );
}


/* -------------------------------------------------------- */

 /* tell current record number in buffered file */

unsigned pascal btell(buffered_file *bfd)
{
	 return bfd->fptr + bfd->fnext;
}


/* -------------------------------------------------------- */

 /* check for eof on buffered file */

char pascal beof(buffered_file *bfd)
{
        unsigned r;

        /* check record count on unbuffered files */
        if (bfd->buffer == NULL)
                return (bfd->fptr >= bfd->filerecs);


	/* read next block if buffer is empty or exhausted */
        if (bfd->fnext >= bfd->fcount)
        {

		/* save changes if buffer has been written */
		if (bfd->dirty)
			 bflush(bfd);

                bfd->fptr += bfd->fcount;
		bfd->fnext = 0;

                ComIoStart(14);

                r = read(bfd->handle, bfd->buffer, bfd->bufsiz);

#ifdef DEBUG
                if (WS.Option.Debug)
                        printf("bufio: _read, fd=%d buf=%04x r=%u siz=%u fn=%s\n",
                                bfd->handle,bfd->buffer,r,bfd->bufsiz,bfd->pathname);
#endif

                ComIoEnd(15);

                /* consider final partial block as a full block and
                   zero past last byte */
                if (bfd->recsiz > 1)
                        while (r % bfd->recsiz)
                                bfd->buffer[r++] = 0;

                bfd->fcount = r / bfd->recsiz;
	}

	/* eof if no records left */
	return bfd->fcount == 0;
}


/* -------------------------------------------------------- */

 /* buffered read */

void pascal bread(buffered_file *bfd,
                  uchar *dest)
{
#ifdef DEBUG
        printf("bread: name=%s buffer=%04x dest=%04x recsiz=%u\n",
                bfd->pathname,
                bfd->buffer,
                dest,
                bfd->recsiz);
#endif

        /* perform unbuffered read */
        if (bfd->buffer == NULL)
        {
                ComIoStart(16);
                bfd->berr = (_read(bfd->handle,dest,bfd->recsiz) < 1);
                ComIoEnd(17);
                return;
        }

        /* check for end of file; read next block when needed */
        bfd->berr = beof(bfd);
        if (bfd->berr)
		return;

	/* copy from buffer to user variable */

        mem_copy(dest, &(bfd->buffer[bfd->fnext*bfd->recsiz]), bfd->recsiz);

        (bfd->fnext)++;
}


/* -------------------------------------------------------- */

 /* buffered write (sets berr on error) */

void pascal bwrite(buffered_file *bfd,
                   uchar *src)
{
        /* perform unbuffered write */
        if (bfd->buffer == NULL)
        {
                ComIoStart(18);
                bfd->berr = (_write(bfd->handle,src,bfd->recsiz) != bfd->recsiz);
                ComIoEnd(19);
                return;
        }

        /* save changes if not yet writing or if buffer is full of changes */
        if ((!bfd->dirty) || (bfd->fnext >= bfd->maxrec))
                bflush(bfd);
	else
                bfd->berr = 0;

#ifdef DEBUG
        if (WS.Option.Debug)
        {
                DBPF("\nbwrite: sz=%d ",bfd->recsiz);
                DUMP_BLOCK(src,bfd->recsiz);
        }
#endif

	/* save user variable in buffer and flag it as 'dirty'(unsaved) */
        mem_copy(&(bfd->buffer[bfd->fnext*bfd->recsiz]), src, bfd->recsiz);

        (bfd->fnext)++;
        if (bfd->fcount < bfd->fnext)
                (bfd->fcount)++;
	bfd->dirty = 1;
}


/* -------------------------------------------------------- */

/* close a buffered file */

void pascal bclose(buffered_file *bfd)
{
#ifdef DEBUG
        printf("bclose: name=%s handle=%d buffer=%04x\n",
                bfd->pathname,
                bfd->handle,
                bfd->buffer);
#endif
        if (bfd->handle <= 0)
		 return;

        ComIoStart(20);
        bflush(bfd);
        _close(bfd->handle);    /* low-level file close */
        ComIoEnd(21);

        bfd->handle = 0;

        /* release buffer memory */
        if (bfd->buffer)
                mem_free(bfd->buffer);
        bfd->buffer = NULL;

#ifdef DEBUG
        printf("bclose: core=%u path=%s\n",mem_avail(),bfd->pathname);
#endif
}

/* -------------------------------------------------------- */

/* close a buffered file, set exact file size and time stamp */

void pascal bclose_set(buffered_file *bfd,
                       long filesize,
                       struct ftime * time)
{
        if (bfd->handle <= 0)
		 return;

        ComIoStart(22);
        bflush(bfd);

        /* tell dos to truncate file at specified position */
        if (filesize)
        {
                lseek(bfd->handle, filesize, SEEK_SET);
                _write(bfd->handle, NULL, 0);
        }

        if (WS.Option.StampTime)
                setftime(bfd->handle, time);

        _close(bfd->handle);    /* low-level file close */
        ComIoEnd(23);

        bfd->handle = 0;

        /* release buffer memory */
        if (bfd->buffer)
                mem_free(bfd->buffer);
        bfd->buffer = NULL;

#ifdef DEBUG
        printf("bclose_set: core=%u path=%s\n",mem_avail(),bfd->pathname);
#endif
}

/* -------------------------------------------------------------- */
/*
 * get a line from a stream, stripping off \r and \n
 * returns 0 normally, 1 at EOF
 * I wrote this because of strangeness surrounding the standard fgets call!
 */

int pascal bgetline(char *buf, int size, buffered_file *fd)
{
        char c;
        int count;
        char *s;
        count = 0;

#ifdef DEBUG
        printf("bgetline: buf=%04x size=%d fcount=%d fnext=%d\n",
                buf,
                size,
                fd->fcount,
                fd->fnext);
#endif

        /* do a quick block move if buffer is large */
        if ((fd->fcount - fd->fnext) >= size)
        {
                fd->berr = 0;
                s = (char *)&(fd->buffer[fd->fnext]);
#ifdef DEBUG
        printf("bgetline(fast): s=%04x\n",s);
#endif
                for (;;)
                {
                        ++(fd->fnext);
                        switch (*s)
                        {
                        case '\r':
                                break;

                        case 26:
                        case '\n':
                                *buf = 0;
                                return 0;

                        default:
                                ++count;
                                *buf++ = *s;
                                if (count < size)
                                        break;
                                *buf = 0;
                                return 0;
                        }
                        ++s;
                }
        }

#ifdef DEBUG
        printf("bgetline(slow): count=%d size=%d\n",count,size);
#endif

        /* if nearing end of buffer, use the slower higher level calls */
        while (count < size)
        {
                bread(fd,(uchar *)&c);
                if (fd->berr || (c == 26))
                {
                        if (count) break;
                        *buf = 0;
                        return 1;
                }
                if (c == '\n')
                        break;
                if (c != '\r')
                {
                        *buf++ = c;
                        ++count;
                }
        }

        *buf = 0;
        return 0;
}


