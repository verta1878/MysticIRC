
//
// hdktext.h - definition of visible text in HS/LinkDK Protocol Engine
//             (part of hdk\hstop.c)
//
// Copyright 1993 Samuel H. Smith; All rights reserved
//

#include "\hdk\language.h"

#ifdef extern
  #define DTEXT(IDENT,VALUE) char IDENT[] = VALUE
#else
  #define DTEXT(IDENT,VALUE) extern char IDENT[]
#endif

#ifdef LANG_ENGLISH
// hsmisc text
DTEXT(TX_BADDUPELST,    "Can't open dupelist '%s'\r\n");
DTEXT(TX_MIN,           "%d:%02d:%02d min");
DTEXT(TX_MINUTES,       "%02d:%02d minutes");
DTEXT(TX_SECONDS,       "%d seconds");
DTEXT(TX_EXCESSERR,     "Excessive repeated errors! (%d)");

// hsopt text
DTEXT(TX_BADFILELIST,   "Can't open filelist '%s'\r\n");
DTEXT(TX_NOMATCH,       "Warning: No files matching '%s'\r\n");

// hsopt2 text
DTEXT(TX_BADOPTION,     "Bad option: %s\r\n");
DTEXT(TX_LOADING,       "Loading %s ...\r\n");

// hsrecv text
DTEXT(TX_RXTO,          "Receive timeout");
DTEXT(TX_RXBUFOV,       "RxBuf Overflow! n=%d m=%d c=%d\r\n");
DTEXT(TX_BADMSGCODE,    "Bad message code '%d'\r\n");
DTEXT(TX_BADACKCRC,     "Bad ACK CRC (%u)\r\n");
DTEXT(TX_BADACKBAT,     "Bad ACK batch %u %u (%u)\r\n");
DTEXT(TX_BADNAKCRC,     "Bad NAK CRC (%u)\r\n");
DTEXT(TX_BADNAKBAT,     "Bad NAK batch %u %u (%u)\r\n");
DTEXT(TX_BADSEEKCRC,    "Bad SEEK CRC (%u)\r\n");
DTEXT(TX_BADSEEKBAT,    "Bad SEEK batch %u %u (%u)\r\n");
DTEXT(TX_BADVERCRC,     "Bad VERIFY CRC\r\n");
DTEXT(TX_VERMULT,       "Verify blocks %u to %u");
DTEXT(TX_VERSINGLE,     "Verify block %u");
DTEXT(TX_RECOVERY,      "\rCrash recovery at block %u\r\n");
DTEXT(TX_IDENTICAL,     "\rFiles are identical!\r\n");
DTEXT(TX_BADREADY,      "Bad ready packet CRC\r\n");
DTEXT(TX_TXDONE,        "%d %s received.\r\n");
DTEXT(TX_TXDONEPLURAL,  "files");
DTEXT(TX_TXDONESINGLE,  "file");
DTEXT(TX_BADFILEHDR,    "Bad file header CRC\r\n");
DTEXT(TX_UPLOADBLOCK,   "Upload request blocked: %s\r\n");
DTEXT(TX_OVERWRITE,     "Not allowed to overwrite existing file\r\n   '%s'\r\n");
DTEXT(TX_USEOR,         "Please use -O option with -R.\r\n");
DTEXT(TX_CANTOPRX,      "Can't open receive file '%s'\r\n");
DTEXT(TX_RECEIVING,     "Receiving");
DTEXT(TX_RESTARTING,    "Restarting file (%d)\r\n");
DTEXT(TX_DISKWERR,      "Disk write failure! (%u)\r\n");
DTEXT(TX_RXBLOCK,       "Block %u (%ld bytes) %u cps ");
DTEXT(TX_BADDATACRC,    "Bad data CRC");
DTEXT(TX_DROPPEDBYTES,  "Dropped bytes");
DTEXT(TX_NOISEBURST,    "Noise burst");
DTEXT(TX_BADBATCH,      "Bad batch number %u %u\r\n");
DTEXT(TX_OUTOFSEQ,      "Out of sequence %u (%u)\r");
DTEXT(TX_INCOMPLETE,    "%s was incomplete! (%u %u)\r\n");
DTEXT(TX_ABORTED,       "Transfer aborted!\r\n");
DTEXT(TX_RXOK,          "File %d received OK, %u cps, %s.\r\n");

// hstrans text
DTEXT(TX_SKIPREM,       "File skipped by remote! (%u)\r\n");
DTEXT(TX_TXBLOCK,       "Block %u (%ld bytes/w:%d) %u cps\r");
DTEXT(TX_RESENDING,     "Resending block");
DTEXT(TX_TXRECOVERY,    "Crash recovery at block %u\r\n");
DTEXT(TX_SEEKBACK,      "Seek back to");
DTEXT(TX_SEEKFORWARD,   "Seek forward to");
DTEXT(TX_FLOWRELEASE,   "Flow control released ");
DTEXT(TX_CTSLOCK,       "CTS lockup!\r\n");
DTEXT(TX_EXCESSTO,      "Too many timeouts!\r\n");
DTEXT(TX_ACKTO,         "ACK timeout, resend");
DTEXT(TX_TXFILEOK,      "File %d sent OK, %u cps, %s.\r\n");
DTEXT(TX_CANTOPTX,      "Can't open transmit file '%s'\r\n");
DTEXT(TX_TRANSMITTING,  "Transmitting");
DTEXT(TX_READERR,       "Read failure at %u\r\n");

// hstop text
DTEXT(TX_WAITING,       "Waiting for remote.\r\n");
DTEXT(TX_NORESP,        "Remote not responding!\r\n");
DTEXT(hdk_copyright,    "Copyright 1993 Samuel H. Smith");
DTEXT(hdk_license,      "\r\nLicensed Material - Property of Samuel H. Smith - All rights reserved"
                        "\r\nP.O. BOX 4808, PANORAMA CITY CA, 91412"
                        "\r\n(818) 891-4228"
                        "\r\n");
#endif

#ifdef LANG_GERMAN

// hsmisc text
DTEXT(TX_BADDUPELST,    "Kann aufgefÅhrte Liste nicht îffnen '%s'\r\n");
DTEXT(TX_MIN,           "%d:%02d:%02d Min");
DTEXT(TX_MINUTES,       "%02d:%02d Minuten");
DTEXT(TX_SECONDS,       "%d Sekunden");
DTEXT(TX_EXCESSERR,     "Zuviele wiederholte Fehler! (%d)");

// hsopt text
DTEXT(TX_BADFILELIST,   "Fileliste kann nicht geîffnet werden '%s'\r\n");
DTEXT(TX_NOMATCH,       "Warnung: Kann Dateien nicht verbinden '%s'\r\n");

// hsopt2 text
DTEXT(TX_BADOPTION,     "Falsche Option: %s\r\n");
DTEXT(TX_LOADING,       "Lade %s ...\r\n");

// hsrecv text
DTEXT(TX_RXTO,          "Empfangszeit abgelaufen");
DTEXT(TX_RXBUFOV,       "RxBuf öberlauf! n=%d m=%d c=%d\r\n");
DTEXT(TX_BADMSGCODE,    "Falscher MSG Code '%d'\r\n");
DTEXT(TX_BADACKCRC,     "Falscher ACK CRC (%u)\r\n");
DTEXT(TX_BADACKBAT,     "Falscher ACK Batch %u %u (%u)\r\n");
DTEXT(TX_BADNAKCRC,     "Falscher NAK CRC (%u)\r\n");
DTEXT(TX_BADNAKBAT,     "Falscher NAK Batch %u %u (%u)\r\n");
DTEXT(TX_BADSEEKCRC,    "Falscher Such-CRC (%u)\r\n");
DTEXT(TX_BADSEEKBAT,    "Falscher Such-BATCH %u %u (%u)\r\n");
DTEXT(TX_BADVERCRC,     "Falsche öberprÅfung CRC\r\n");
DTEXT(TX_VERMULT,       "öberprÅfe Blîcke %u to %u");
DTEXT(TX_VERSINGLE,     "öberprÅfe Block %u");
DTEXT(TX_RECOVERY,      "\rAngefÅgter Block %u\r\n");
DTEXT(TX_IDENTICAL,     "\rDateien sind Identisch!\r\n");
DTEXT(TX_BADREADY,      "Schlechtes Lesepaket CRC\r\n");
DTEXT(TX_TXDONE,        "%d %s erhalten.\r\n");
DTEXT(TX_TXDONESINGLE,  "Datei");
DTEXT(TX_TXDONEPLURAL,  "Dateien");
DTEXT(TX_BADFILEHDR,    "Falscher File-Kopf CRC\r\n");
DTEXT(TX_UPLOADBLOCK,   "Abgefragter Upload blockiert: %s\r\n");
DTEXT(TX_OVERWRITE,     "Exist. Datei wird nicht Åberschrieben\r\n   '%s'\r\n");
DTEXT(TX_USEOR,         "Bitte verwende -O Option mit -R.\r\n");
DTEXT(TX_CANTOPRX,      "Datei kann nicht geîffnet werden '%s'\r\n");
DTEXT(TX_RECEIVING,     "Erhalte");
DTEXT(TX_RESTARTING,    "Wiederhole Datei (%d)\r\n");
DTEXT(TX_DISKWERR,      "DISKSCHREIBFEHLER! (%u)\r\n");
DTEXT(TX_RXBLOCK,       "Block %u (%ld Bytes) %u cps ");
DTEXT(TX_BADDATACRC,    "Schlechte Daten-CRC");
DTEXT(TX_DROPPEDBYTES,  "Abgespei. Bytes");
DTEXT(TX_NOISEBURST,    "Noise burst");
DTEXT(TX_BADBATCH,      "Schlechte BATCH-Nummer %u %u\r\n");
DTEXT(TX_OUTOFSEQ,      "Ausserhalb der Sequenz %u (%u)\r");
DTEXT(TX_INCOMPLETE,    "%s nicht Komplett! (%u %u)\r\n");
DTEXT(TX_ABORTED,       "öbertragung abgebrochen!\r\n");
DTEXT(TX_RXOK,          "Datei %d erhalten OK, %u cps, %s.\r\n");

// hstrans text
DTEXT(TX_SKIPREM,       "Datei abgebrochen von Gegenstation! (%u)\r\n");
DTEXT(TX_TXBLOCK,       "Block %u (%ld Bytes/w:%d) %u cps\r");
DTEXT(TX_RESENDING,     "Sende Block neu");
DTEXT(TX_TXRECOVERY,    "AngefÅgter Block bei %u\r\n");
DTEXT(TX_SEEKBACK,      "Suche zurÅck zu");
DTEXT(TX_SEEKFORWARD,   "Suche vorwÑrts zu");
DTEXT(TX_FLOWRELEASE,   "Flusskontrolle ausgelîst ");
DTEXT(TX_CTSLOCK,       "CTS verschlossen!\r\n");
DTEXT(TX_EXCESSTO,      "Zuviele Zeitfehler!\r\n");
DTEXT(TX_ACKTO,         "ACK Zeitfehler, sende zurÅck");
DTEXT(TX_TXFILEOK,      "Datei %d gesendet, %u cps, %s.\r\n");
DTEXT(TX_CANTOPTX,      "öbertragungsfile kann nicht geîffnet werden '%s'\r\n");
DTEXT(TX_TRANSMITTING,  "öbermittle");
DTEXT(TX_READERR,       "Lesefehler bei %u\r\n");

// hstop text
DTEXT(TX_WAITING,       "Warte auf Gegenstation.\r\n");
DTEXT(TX_NORESP,        "Gegenstation gibt keine Antwort!\r\n");

DTEXT(hdk_copyright,    "Copyright 1993 Samuel H. Smith");

DTEXT(hdk_license,      "\r\nLizenziertes Material - Eigentum von Samuel H. Smith - Alle Rechte reserviert"
                        "\r\nLicensed Material - Property of Samuel H. Smith - All rights reserved"
                        "\r\nP.O. BOX 4808, PANORAMA CITY CA, 91412"
                        "\r\n(818) 891-4228"
                        "\r\n");
#endif

