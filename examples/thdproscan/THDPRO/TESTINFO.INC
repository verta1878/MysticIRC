
{
                     This file format may be used freely by
                   any utility which might have a use for it.

              If you program a file processor, you might consider
              utilizing the format to simplify the programming of
              external interface  utilities. (Wouldn't it be nice
              if third party  utils could be used to  interface a
              number of  upload testers, thus  allowing the users
              of different BBS  packages an opportunity to switch
              from one tester to another  without having to worry
              about interfacing problems?)

****************************************************************************
**                                                                        **
**    TESTINFO_REC record types as created by THD ProScan Version 10.0    **
**    (or later)                                                          **
**      TESTINFO.DAT is a "file of TESTINFO_REC" which is created by      **
**  THD ProScan when the user has configured a BBSTYPE other than "NONE"  **
**  in THDINSTL.                                                          **
**                                                                        **
****************************************************************************
}

TYPE

TESTINFO_FILE_REC = record {individual file information record}

   FILE_SFX,
   FILE_EXISTS  : boolean;
   FILE_FULL,
   FILE_PATH    : string[60];
   FILE_DRIVE   : string[2];
   FILE_NAME    : string[8];
   FILE_EXT,
   FILE_TYPE    : string[3];
   FILE_DT,
   FILE_SIZE    : longint;
   end;



TESTINFO_REC = Record {format of TESTINFO.DAT individual records}

   Processed,
   VND_present,
   DESC_imp_req,
   ADD_rec,
   F_conv,
   Ansi_detected,
   Avatar_detected,
   CD_detected,
   BBS_Processed,
   RES_bool_one,
   RES_bool_two,
   RES_bool_thr,
   RES_bool_fou,
   RES_bool_fiv,
   RES_bool_six,
   RES_bool_sev,
   RES_bool_eig      : boolean;
   Check_count,
   BBS_type,
   COM_port,
   EXIT_level,
   TESTINFO_REV,
   RES_byte_one,
   RES_byte_two,
   RES_byte_thr,
   RES_byte_fou,
   RES_byte_fiv,
   RES_byte_six,
   RES_byte_sev,
   RES_byte_eig,
   RES_byte_nin      : byte;
   TEST_DT,
   RES_li_one,
   RES_li_two,
   RES_li_thr,
   RES_li_fou,
   RES_li_fiv,
   RES_li_six,
   RES_li_sev,
   RES_li_eig,
   RES_li_nin,
   RES_li_ten        :longint;
   CMD_options,
   BBS_data_dir,
   Creator,
   Log_path,
   RES_str60_one,
   RES_str60_two,
   RES_str60_thr     : string[60];
   Ver_major,
   Ver_minor         : string[2];
   VAR_ext           : string[3];
   Desc_filename,
   RES_str12_one,
   RES_str12_two,
   RES_str12_thr     : string[12];
   ORIGINAL_F_info,
   FINISHED_F_info   : TESTINFO_FILE_REC;
   RES_int_one,
   RES_int_two,
   RES_int_thr,
   RES_int_fou,
   RES_int_fiv,
   Descr_Length      : integer;
   DIZ_Description   : array[1..1500] of char
   end;

{
                     *********************************
                     **  EACH RECORD IS 2380 BYTES  **
                     *********************************

    This format is Copyright 1994 - 1995 PainSoft and is freely usable but may 
not be modified. Persons wishing to add or change fields should contact David 
Muir at 1:259/423.0 (fidonet) to discuss suggestions for changes.

     This file is an "include" file for use with Turbo Pascal. It defines the 
2 "types" used to create the file "TESTINFO.DAT" which is a data file which 
can be used by external programs to update the various file databases of BBS 
types supported to date.
     It includes a great bit of information that could be useful to utility 
programmers wishing to program an interface for an upload processor and any 
number of BBS programs. Much of the information included here could be easily 
determined by programmers. It is included here to simply your efforts (as well 
as my own).
     TESTINFO.DAT has it's own numbering of BBS TYPES and reserves values of 
1-254 for standard definitions. A BBSTYPE of "0" indicates no BBS is involved 
and will not cause this file to be written and should therefore never be 
encountered.
Currently defined BBS types are as follows

0   - No BBS (create no file)
1   - RemoteAccess 2.00 (and compatibles)
2   - Telegard 2.7
3   - Renegade 07-17 (or compatible)
4   - FILES.BBS (standard)
5   - FILES.BBS (SBBS extended format)
6   - Telegard 3.0
7   - RemoteAccess 2.5?
8   - FILES.BBS (" +" extended format)
9   - PCBoard 15.?
10  - T.A.G. (version 2.7)
11  - Wildcat 4.xx (NOT supported by THDPLUS)
12  - FILES.BBS (" |" extended format)
13 - 254 reserved for later definition.
255 - unsupported types. (all types not noted above)

     Any creator of this record should increase the "Check_Count" for each  
record once for each time the TESTINFO.DAT file is accessed. It is recommended 
to delete any record which has a Check_Count of 51 or higher or which is 
marked as having been processed.

Date/Time variables as used in these records are in Packed Time Format.
Turbo Pascal users can simply use "unpacktime".

The Packed Time Format (PTF) is a 32 bit Longint decoded as follows:

- for "C" programmers...
  shr = shift right
  and = bitwise and
  $7F = 7Fh
to the best of my understanding.

var
  Yr    : 0..127;     Years since 1980
  Month : 1..12;      Month number
  Day   : 1..31;      Day of month
  Hour  : 0..23;      Hour of day
  Min   : 0..59;      Minute of hour
  Sc    : 0..29;      Seconds divided by 2
  Year  : Word;
  Sec   : Word;
begin
  Yr    := (PTF shr 25) and $7F ;
  Month := (PTF shr 21) and $0F ;
  Day   := (PTF shr 16) and $1F ;
  Hour  := (PTF shr 11) and $1F ;
  Min   := (PTF shr  5) and $3F ;
  Sc    := (PTF and $1F) ;
  Year  := 1980 + Yr ;
  Sec   := 2 * Sc ;
end;

     It is also my understanding that "C" programmers could read this longint 
as two "words" (the first word being time and the second word being date).

     Outline for TESTINFO_FILE_REC as a type used below

FILE_SFX    - Is this a self extracting archive?
FILE_EXISTS - did this file exist at the time this record was written
FILE_FULL   - fully qualified file path - drive:\path\name.extension
              "drive:" will always be included even if the user did not
              supply a drive letter in the path to the test file. When this
              occurs, THDPRO.EXE inserts the drive specification of the
              current drive in this path. That drive specification may
              differ from the time THD runs and the time an external utility
              runs. Be sure to check the FILE_DRIVE variable to see that
              this drive was supplied and not assumed (network drive specs
              can change depending on the remote system).
              [if length(FILE_DRIVE)=2 then the drive letter was supplied.]
FILE_DRIVE  - Drive Letter of file path (colon is included if a drive letter
              is defined. In cases where a drive letter is not specifically
              supplied, this entry will be empty)
FILE_PATH   - file path (in the format "\WHAT\DIR\" with both beginning and
              trailing backslashes)
FILE_NAME   - file name (name only no "." or extension)
FILE_EXT    - file extension [note that the "." is not included in this
              record]
FILE_TYPE   - file "type" will be one of...
              ARC / ARJ / GIF / HYP / LZH / PAK / RAR /SQZ / TD0 /UC2 / ZIP
              or NON [for un-supported types] (Types reported here may be
              expanded on by third party programmers, but should try to use
              accepted conventions for file types, usually the file
              extension would be suggested.)
FILE_DT     - file date/time - (Turbo Pascal users use "unpacktime")
FILE_SIZE   - file size in bytes


     The outline for the TESTINFO.DAT record for the purpose of allowing 
external manipulation of file data bases or other data which may be of use to 
BBS manipulation.

   Labels beginning with "RES_" (as in "reserved") are currently not used (or 
explained here) but are present to help ensure the future compatibility of 
this file format.

Outline for TESTINFO_REC - (as used to create TESTINFO.DAT)

Processed        - Has this record been processed? [if true the utility which
                   created this record should remove this record on it's next
                   run]. Use this to indicate when the file has been
                   completely processed and will no longer be required. Proper
                   use of this field will help to keep the TESTINFO.DAT file
                   compressed to a reasonable size.
VND_present      - is VENDINFO.DIZ present in file?
DESC_imp_req     - is Description importation requested? If set to false,
                   the user has requested that descriptions not be imported
                   into their file database.
ADD_rec          - does the user wish to Create a new entry in their
                   file database if one is not currently present?
F_conv           - was file successfully converted [true even if file type
                   was not changed during conversion]
Ansi_detected    - was ANSI detected on the remote system.
Avatar_detected  - was Avatar 0+ detected on remote system.
CD_detected      - was carrier detected at last check on remote system?
BBS_Processed    - Used by the BBS to determine if the BBS has processed
                   this record.
Check_count      - Number of times this record has been found but not
                   processed [ Recommended to purge any record checked
                   more than 50 times. as well increment this number by
                   one each time a new record is added. ]
BBS_type         - BBSTYPE as defined above.
COM_port         - Comport used during test [0 if local].
EXIT_level       - Dos Error level expected to be returned by the creator
                   of the record.
TESTINFO_REV     - The revision number of the TESTINFO file. Currently
                   there is only revision "1" (This revision).
TEST_DT          - date/time [ at time of writing this record ]
CMD_options      - Command line options supplied to the creator [The first
                   and last character must always be " " [space]].
Log_path         - This is the full path and filename used as the creator's
                   temporary log file (if any).
Creator          - The name of the Program that created this record.
                   Under all normal circumstances this will be
                   "THD ProScan". Although if other programmers choose to
                   create a record of this type, they should insert their
                   own identification in this area. This is the ONLY place
                   where a string variable will contain lower case.
BBS_data_dir     - Path to BBS data directory [usually main BBS directory]
Ver_major        - Creator's version number (major) [ie. "10"]
Ver_minor        - Creator's version number (minor) [ie. "m" or ".0"]
VAR_ext          - Variable extension number used for this test. (the three
                   number extension used on temp directories and files
                   during this test)
Desc_filename    - Name of the file from which the description included
                   was extracted. [blank if none] This is included if for
                   some reason the third party programmer wishes to
                   re-extract the file from which the description was taken.
                   This file name will always be contained in the main
                   archive, and thus could be extracted from the resulting
                   archive if need be. This may be help for instance where a
                   description is the full 1500 characters and not taken
                   from a VENDINFO.DIZ. The programmer could re-extract the
                   description file and use it in it's entirety (if they
                   wished).
ORIGINAL_F_info  - Original file information [as stored in the type
                   TESTINFO_FILE_REC]. Information on the file prior to
                   the creator making any modifications.
FINISHED_F_info  - Finished file information [as stored in the type
                   TESTINFO_FILE_REC]. Information on the resulting file after
                   the creator has completed it's processing of this file.
                   Changes from the original file "can" occur in any of the
                   fields through archive conversion or other manipulation.
Descr_Length     - Number of characters in the DIZ_Description field
                   [ 0 if no description, maximum 1500 ]
DIZ_Description  - Description containing the full description including
                   any CR/LF (or other control or non ASCII characters) that
                   may have been present in the description file used
                   [maximum 1500 characters]

     ** NOTE **
     All string variables and character variables will be stored as uppercase 
in these records except for the "CREATOR" field which contains the name of the 
creator of the record. There will be absolutely no lowercase information in 
these records anywhere else except in the diz_description field.
     Strings and arrays are NOT necessarily null terminated.
}
