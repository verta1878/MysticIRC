
/*
 * COPYRIGHT 1992 SAMUEL H. SMITH
 * ALL RIGHTS RESERVED
 *
 * THIS DOCUMENT CONTAINS CONFIDENTIAL INFORMATION AND TRADE SECRETS
 * PROPRIETARY TO SAMUEL H. SMITH DBA THE TOOL SHOP.
 *
 */

#define LAST_CHAR(string) (string[strlen(string)-1])
        /* return last character in a string */

#define SET_TIMER(ms) (bios_clock() + (long)((((long)(ms))*182L) / 10000L))
        /* return a bios_clock() value the specified number of
           milliseconds in the future */

#define TIMER_UP(timer) (bios_clock() >= (timer))
        /* check to see if a timer returned by SET_TIMER has elapsed */

#define TIMER_SECS(timer)  ((timer_ticks(timer)*10L) / 182L)
        /* report elapsed seconds for a running timer */

clock_t pascal timer_ticks( clock_t start_time );

unsigned pascal calculate_cps( clock_t start_time, long size );

void pascal update_status_log(
                char logcode,
                long size,
                long EffSpeed,
                unsigned cps,
                unsigned error_count,
                unsigned flow_holds,
                unsigned last_blocksize,
                char *path);

char* pascal path_only(char *filespec);
        /* return drive:\path\ from full filespec */

char* pascal name_only(char *filespec);
        /* return name.exe from full filespec */

char* pascal path_name(char *path, char *name);
        /* return path+name */

char* pascal duplicate_file(char *fname,char *basename);
        /* determine if specified file is a duplicate of existing files */

int pascal isadir(char *filespec);
        /* return true if filespec refers to a valid directory */

unsigned pascal ahtoi(char *hex);
        /* convert ascii hex or decimal to an integer */

char* pascal sectomin(unsigned sec);

void pascal limit_errors(int error);
        /* limit repeated errors; >0 indicates error, <0 indicates OK */

