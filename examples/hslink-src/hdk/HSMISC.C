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
 * hsmisc.c - HS/Link, misc services
 *
 */

#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <io.h>
#include <conio.h>
#include <fcntl.h>
#include <share.h>
#include <dos.h>

#ifdef __TURBOC__
#include <dir.h>
#include <time.h>
#endif

#include <ctype.h>

#include "hdktext.h"
#include "hspriv.h"
#include <hdk.h>

#ifndef MAXPATH
        #define MAXPATH 80
        #define MAXDRIVE 2
        #define MAXDIR 65
        #define MAXFILE 16
        #define MAXEXT 5
#endif

/* -------------------------------------------------------------------- */

clock_t pascal timer_ticks( clock_t start_time )
{
        clock_t elapsed;
        elapsed = (bios_clock() - start_time);
        if (elapsed < 0L)
                elapsed += 6L*60L*24L*182L;
        return elapsed;
}


/* -------------------------------------------------------------------- */

unsigned pascal calculate_cps( clock_t start_time, long size )
{
        long cps;
        clock_t elapsed;

        elapsed = timer_ticks(start_time);

        if (elapsed > 18L)
                if (size > 11000000L)
                        cps = ((size / 10L) * 182L) / elapsed;
                else
                        cps = (182L*size) / ((elapsed)*10L);
        else
                cps = 9999;

        return (unsigned)cps;
}


/* -------------------------------------------------------------------- */

/* make an entry in DSZLOG using provided information */

void pascal update_status_log(
                char logcode,
                long size,
                long EffSpeed,
                unsigned cps,
                unsigned error_count,
                unsigned flow_holds,
                unsigned last_blocksize,
                char *path)
{
        char *dszlog;
        int fd;
        char line[150];
        char temp[128];
        int i,j;
        long eofp;

        sprintf(line,"%c %6ld %5ld bps %4u cps %3u errors %5u %4u %s %u",
                logcode,
                size,
                EffSpeed,
                cps,
                error_count,
                flow_holds,
                last_blocksize,
                path,
                WS.remote_userid);

        if (WS.hacked_remote)
            strcat(line,"*");

        if (WS.cancel_link)
        {
                sprintf(temp," %d",WS.cancel_link);
                strcat(line,temp);
        }

        strcat(line,"\r\n");

        ComIoStart(21);

        dszlog = WS.Option.StatusLogFile;
        if (*dszlog == 0)
                dszlog = getenv("DSZLOG");
        if (dszlog == 0)
                dszlog = "";

        if (dszlog[0] != 0)
        {
                if (access(dszlog,0))
                        fd = _creat(dszlog,0);
                else
                        fd = _open(dszlog,O_RDWR);

                if (fd > 0)
                {
                        /* skip over any EOF markers */
                        eofp = lseek(fd,0,SEEK_END);
                        if (eofp > sizeof(temp))
                                eofp -= sizeof(temp);
                        else
                                eofp = 0;
                        lseek(fd,eofp,SEEK_SET);
                        i = _read(fd,temp,sizeof(temp));
                        for (j=0; j<i; j++, eofp++)
                                if (temp[j] == 26)
                                        break;
                        lseek(fd,eofp,SEEK_SET);

                        /* write the log entry */
                        i = _write(fd,line,strlen(line));
                        _close(fd);
                }
        }

        log_error("Log %s: %s",dszlog,line);

        ComIoEnd(22);
}


/* -------------------------------------------------------------------- */

/* return drive:\path\ from full filespec */

char* pascal path_only(char *filespec)
{
        char split_path[MAXPATH+1];
        char split_drive[MAXDRIVE+1];
        char split_dir[MAXDIR+1];
        char split_file[MAXFILE+1];
        char split_ext[MAXEXT+1];

        (void)fnsplit(filespec,split_drive,split_dir,split_file,split_ext);
        strcpy(split_path,split_drive);
        strcat(split_path,split_dir);

        return split_path;
}


/* -------------------------------------------------------------------- */

/* return name.exe from full filespec */

char* pascal name_only(char *filespec)
{
        char split_path[MAXPATH+1];
        char split_drive[MAXDRIVE+1];
        char split_dir[MAXDIR+1];
        char split_file[MAXFILE+1];
        char split_ext[MAXEXT+1];

        (void)fnsplit(filespec,split_drive,split_dir,split_file,split_ext);
        strcpy(split_path,split_file);
        strcat(split_path,split_ext);

        return split_path;
}


/* -------------------------------------------------------------------- */

/* return path+name */

char* pascal path_name(char *path, char *name)
{
        char split_path[MAXPATH+1];

        strcpy(split_path,path);
        strcat(split_path,name);

        return split_path;
}


/* -------------------------------------------------------------------- */

/* determine if specified file is a duplicate of existing files */
/*      return: NULL=not duplicate, (char *)=duplicate path/name */

char* pascal duplicate_file(char *fname,char *basename)
{
        char atfname[MAXPATH+1];
        int dupe;
        char *s,*name;

        // is it ok to duplicate existing files?
        if (WS.Option.AllowOverwrite)
                return NULL;

        // does the file exist?
        if (!access(fname, 0))
                return fname;

        // are we going to use a duplication checklist?
        if (*WS.Option.DupeChecklist == 0)
                return NULL;

        bopen(&PRIVATE.recv_fd, WS.Option.DupeChecklist, WS.buffer_sizes, 1, O_RDONLY | SH_DENYNONE);
        if (PRIVATE.recv_fd.berr)
        {
                ERECV(TX_BADDUPELST,WS.Option.DupeChecklist);
                return NULL;
        }

        /* check each directory or filename in the dupelist */
        dupe = 0;
        while (!dupe && !bgetline(atfname,sizeof(atfname)-1,&PRIVATE.recv_fd))
        {

                if (atfname[2] == '/')
                {
                        /* skip directory headers used by prodoor's BLDLIST */
                }
                else
                if ((atfname[0] == '\\') || (atfname[1] == ':'))
                {
                        /* check for the file inside a dir */
                        if (LAST_CHAR(atfname) != '\\')
                                strcat(atfname,"\\");

                        /* strip trailing spaces */
                        s = atfname;
                        while (*s)
                                if (*s <= ' ')  *s = 0;
                                else            ++s;

                        strcat(atfname,basename);
                        if (!access(atfname,0))
                                dupe = 1;
                }
                else {
                        /* check matching filenames (ignore trailing space) */
                        s = atfname;
                        name = basename;
                        while (*s == *name)
                        {
                                if (*name == 0)
                                {
                                        if (*s <= ' ')
                                                dupe = 1;
                                        break;
                                }
                                ++s;
                                ++name;
                        }
                }
        }

        bclose(&PRIVATE.recv_fd);

        if (dupe)
                return atfname;
        else
                return NULL;
}


/* -------------------------------------------------------------------- */

/* return true if filespec refers to a valid directory */

int pascal isadir(char *filespec)
{
#ifdef __TURBOC__
        struct ffblk ffblk;
        #define FFATTR ffblk.ff_attrib
#else
        struct _find_t ffblk;
        #define findfirst(SPEC,BLK,ATTR) _dos_findfirst(SPEC,ATTR,BLK)
        #define FFATTR ffblk.attrib
        #define FA_DIREC _A_SUBDIR
#endif

        if (*filespec == 0)
                return 1;       /* blank filespec is current directory */

        if (!strcmp(filespec+1,":\\") ||
            !strcmp(filespec,"\\") ||
            (LAST_CHAR(filespec) == ':'))
                return 1;       /* root directory */

        if (LAST_CHAR(filespec) == '\\')
                LAST_CHAR(filespec) = 0;

        if (findfirst(filespec,&ffblk,FA_DIREC))
                return 0;       /* does not exist, not a directory */

        return (FFATTR & FA_DIREC);
}


/* -------------------------------------------------------------------- */

/* convert ascii hex or decimal to an unsigned integer */
/* accepts the form:
        01234   ;decimal
        $aaaa   ;hex
        0xaaaa  ;hex
        a000    ;hex with a-f first digit
*/

unsigned pascal ahtoi(char *hex)
{
        int val;
        int radix;
        int digit;
        val = 0;
        radix = 10;
        for (val=0, radix=10; *hex; ++hex)
        {
                digit = toupper(*hex);
                switch (digit)
                {
                case '$':
                case 'X':
                        radix = 16;
                        break;

                case 'A':
                case 'B':
                case 'C':
                case 'D':
                case 'E':
                case 'F':
                        radix = 16;
                        digit -= 7;
                        /* fall through */

                case '0':
                case '1':
                case '2':
                case '3':
                case '4':
                case '5':
                case '6':
                case '7':
                case '8':
                case '9':
                        val = val*radix + digit - '0';
                }
        }

        return val;
}


/* -------------------------------------------------------------------- */

/* convert seconds to "xx.x minutes" */

char* pascal sectomin(unsigned sec)
{
        static char buf[30];
        unsigned hours,mins;

        hours = sec / (60*60);
        sec -= hours * (60*60);

        mins = sec / 60;
        sec -= mins * 60;

        if (hours)
                sprintf(buf,TX_MIN,hours,mins,sec);
        else
        if (mins)
                sprintf(buf,TX_MINUTES,mins,sec);
        else
                sprintf(buf,TX_SECONDS,sec);

        return buf;
}

/* -------------------------------------------------------------------- */

/* limit repeated errors - cancel link when the same error repeats */

void pascal limit_errors(int error)
{
#ifdef DEBUG
        log_error("Limit errors: err=%d perr=%d count=%d\r\n",
                error,
                PRIVATE.prev_error_code,
                PRIVATE.prev_error_count);
#endif

        if (error > 0)
        {
                if (error == PRIVATE.prev_error_code)
                {
                        ++PRIVATE.prev_error_count;
                        if (PRIVATE.prev_error_count == WS.Option.MaxError)
                        {
                                char msg[80];
                                sprintf(msg,TX_EXCESSERR,error);
                                display_warning(msg);
                                set_cancel_link(CANCEL_EXCESS_ERRORS);
                        }
                }
                else {
                        PRIVATE.prev_error_count = 1;
                }
        }

        PRIVATE.prev_error_code = error;
}


