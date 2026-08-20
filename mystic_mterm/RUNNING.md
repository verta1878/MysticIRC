# Running OpenOLMS as a door

The BBS launches `OLMS.EXE` as a door when a caller enters the mail door. It
reads a dropfile (DORINFO1.DEF or DOOR.SYS) from the node directory plus the
command-line switches.

## Command line

These match the switches the original OLMS accepts.

    /D  /U          auto download / upload new mail
    /DA /UA         ... without waits
    /DL /UL         ... with logoff after
    /DQ /UQ         ... with ask-to-logoff
    (add R)         return to OLMS instead of the BBS, e.g. /DAR
    /L              interactive with fewer prompts
    /V              pack ALL users' vacation mail (run during an event)
    /M              vacation mail interface for the user
    /MD /MDA /MDQ /MDL   vacation interface + download (like /D, /DA, ...)
    /NT             do not deduct the user's time in the door
    /RG  /RG=n      reset pointers in all areas (=n resets back n messages)
    /RS  /RS=n      reset pointers in user-selected areas
    /P=user_name    load the user from USERS.BBS (place first), e.g.
                        OLMS /P=pete_rocca /DA
    --dir <path>    work in <path> instead of the current directory
    --version       print version
    /?              this help (DOS)   --help also works

With no switches, OLMS runs in standard interactive mode.

## Exit codes
    0  success (or nothing to do)
    1  failure (e.g. archiver missing, packet write failed)
Batch files can test ERRORLEVEL to react.

## What a download does
1. Reads the dropfile to identify the caller.
2. Scans every active message area in OLMS.CFG (JAM or Hudson), gathering
   messages newer than the caller's read pointer, after twit/keyword/filter
   rules and the size/count limits.
3. Writes a QWK packet and compresses it to `<BoardID>.QWK` with the configured
   archiver.
4. Advances the caller's read pointers and logs to OLMS.LOG.

## What an upload does
Looks for `<BoardID>.REP`, extracts it with the configured archiver, and reads
the caller's replies (ready to be filed into the message base).

## RemoteAccess (type-7 door) example
    C:\RA\OLMS\OLMS.EXE /DA
Give the door node access to its own directory and a dropfile. Ensure the
archiver (PKZIP/PKUNZIP) is on the PATH.

## Files the door uses
    OLMS.CFG        configuration (from CONFIG.EXE)
    OLMS.LOG        activity log
    POINTERS.DAT    per-user read pointers
    FILTER.CFG      optional twit/keyword/filter rules
    <BoardID>.QWK   outbound mail packet
    <BoardID>.REP   inbound reply packet
