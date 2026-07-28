/*

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

	Please note, I am NOT a "C" programmer by any stretch of the
	imagination. The structures as follows are based on a series
	of "best guesses" and does produce the correct result using
	BORLAND C++ Version 3.1.
	Since I'm not aware of the standards used by "C" programmers
	A quick explanation is included.

	A boolean is false ONLY if the ordinal value of the char=0

	A Turbo Pascal string is an array of char where the ordinal
	value of the first character is the length of the string. These
	strings may or may not be null terminiated (don't count on it).

	The "WORD" type below "may" need to be defined as an unsigned int
	as opposed to unsigned short int (as below) with some compilers.
*/
typedef unsigned char boolean;      /* Turbo Pascal "boolean" */
typedef unsigned char byte;         /* Turbo Pascal "byte" */
typedef signed short int integer;   /* Turbo Pascal "integer" */
typedef signed long int longint;    /* Turbo Pascal "longint" */
typedef unsigned char string;       /* Turbo Pascal "string" */
typedef unsigned short int word;    /* Turbo Pascal "word" */

typedef struct
   {
   boolean FILE_SFX;
   boolean FILE_EXISTS;
   string FILE_FULL[61];
   string FILE_PATH[61];
   string FILE_DRIVE[3];
   string FILE_NAME[9];
   string FILE_EXT[4];
   string FILE_TYPE[4];
   longint FILE_DT;
   longint FILE_SIZE;
   } TESTINFO_FILE_REC;  /*individual file information record*/



typedef struct
   {
   boolean Processed;
   boolean VND_present;
   boolean DESC_imp_req;
   boolean ADD_rec;
   boolean F_conv;
   boolean Ansi_detected;
   boolean Avatar_detected;
   boolean CD_detected;
   boolean BBS_Processed;
   boolean RES_bool_one;
   boolean RES_bool_two;
   boolean RES_bool_thr;
   boolean RES_bool_fou;
   boolean RES_bool_fiv;
   boolean RES_bool_six;
   boolean RES_bool_sev;
   boolean RES_bool_eig;
   byte Check_count;
   byte BBS_type;
   byte COM_port;
   byte EXIT_level;
   byte TESTINFO_REV;
   byte RES_byte_one;
   byte RES_byte_two;
   byte RES_byte_thr;
   byte RES_byte_fou;
   byte RES_byte_fiv;
   byte RES_byte_six;
   byte RES_byte_sev;
   byte RES_byte_eig;
   byte RES_byte_nin;
   longint TEST_DT;
   longint RES_li_one;
   longint RES_li_two;
   longint RES_li_thr;
   longint RES_li_fou;
   longint RES_li_fiv;
   longint RES_li_six;
   longint RES_li_sev;
   longint RES_li_eig;
   longint RES_li_nin;
   longint RES_li_ten;
   string CMD_options[61];
   string BBS_data_dir[61];
   string Creator[61];
   string Log_path[61];
   string RES_str60_one[61];
   string RES_str60_two[61];
   string RES_str60_thr[61];
   string Ver_major[3];
   string Ver_minor[3];
   string VAR_ext[4];
   string Desc_filename[13];
   string RES_str12_one[13];
   string RES_str12_two[13];
   string RES_str12_thr[13];
   TESTINFO_FILE_REC ORIGINAL_F_info;
   TESTINFO_FILE_REC FINISHED_F_info;
   integer RES_int_one;
   integer RES_int_two;
   integer RES_int_thr;
   integer RES_int_fou;
   integer RES_int_fiv;
   integer Descr_Length;
   char DIZ_Description[1500];
   } TESTINFO_REC;  /*format of TESTINFO.DAT individual records*/

/*
		     *********************************
		     **  EACH RECORD IS 2380 BYTES  **
		     *********************************

    This format is Copyright 1994 - 1995 PainSoft and is freely usable but may
not be modified. Persons wishing to add or change fields should contact David
Muir at 1:259/423.0 (fidonet) to discuss suggestions for changes.

     This file is an "include" file for use with C++. It defines the
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
11  - Wildcat v4.xx (NOT supported by THDPLUS)
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
*/
