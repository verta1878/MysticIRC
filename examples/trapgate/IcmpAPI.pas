// --------------------------------------------------------------------------
//                        IcmpApi.pas
// --------------------------------------------------------------------------
//
// This file is a translation of the Microsoft files icmpapi.h and ipexport.h
// into Delphi / Pascal code...
//
// The translation is done by Martin Djernæs..
// e-mail : djernaes@metronet.de
// web    : http://einstein.ot.dk/~djernaes
//
// --------------------------------------------------------------------------

unit IcmpApi;

(* - Microsoft ReadMe.txt -
 *
 * [DISCLAIMER]
 *
 * We have had requests in the past to expose the functions exported from
 * icmp.dll.  The files in this directory are provided for your convenience
 * in building applications which make use of ICMPSendEcho().
 *
 * Notice that the functions in icmp.dll are not considered part of the
 * Win32 API and will not be supported in future releases.  Once we have
 * a more complete solution in the operating system, this DLL, and the
 * functions it exports, will be dropped.
 *
 *
 * [DOCUMENTATION]
 *
 * The ICMPSendEcho() function sends an ICMP echo request to the specified
 * destination IP address and returns any replies received within the timeout
 * specified. The API is synchronous, requiring the process to spawn a thread
 * before calling the API to avoid blocking. An open IcmpHandle is required
 * for the request to complete. IcmpCreateFile() and IcmpCloseHandle() functions
 * are used to create and destroy the context handle.
 *)

(* - Microsoft's head in icmpapi.h -
 * ++
 *
 * Copyright (c) 1991-1996  Microsoft Corporation
 *
 * Module Name:
 *
 *     icmpapi.h
 *
 * Abstract:
 *
 *     Declarations for the Win32 ICMP Echo request API.
 *
 * Author:
 *
 *     Portable Systems Group 30-December-1993
 *
 * Revision History:
 *
 *
 * Notes:
 *
 * --
*)

interface

Uses
  Windows;

Type
  TIPAddr = Integer;          // IP Address
  PIPOptionInformation = ^TIPOptionInformation;
  TIPOptionInformation = Record
    Ttl         : Byte;       // Time To Live
    Tos         : Byte;       // Type of Service
    Flags       : Byte;       // IP Header Flags
    OptionsSize : Byte;       // Size In bytes of options data
    OptionsData : ^Byte;      // Pointer to options data
  end;

  TIcmpEchoReply = record
    Address       : TIPAddr;              // Replying address
    Status        : ULONG;                // Reply IP_STATUS
    RoundTripTime : ULONG;                // RTT in milliseconds
    DataSize      : ULONG;                // Reply data size in bytes
    Reserved      : ULONG;                // Reserved for system use
    Data          : Pointer;              // Pointer to the reply data
    Options       : PIPOptionInformation; // Reply options
  end;

Const
  IP_STATUS_BASE              = 11000;

  IP_SUCCESS                  = 0;
  IP_BUF_TOO_SMALL            = (IP_STATUS_BASE + 1);
  IP_DEST_NET_UNREACHABLE     = (IP_STATUS_BASE + 2);
  IP_DEST_HOST_UNREACHABLE    = (IP_STATUS_BASE + 3);
  IP_DEST_PROT_UNREACHABLE    = (IP_STATUS_BASE + 4);
  IP_DEST_PORT_UNREACHABLE    = (IP_STATUS_BASE + 5);
  IP_NO_RESOURCES             = (IP_STATUS_BASE + 6);
  IP_BAD_OPTION               = (IP_STATUS_BASE + 7);
  IP_HW_ERROR                 = (IP_STATUS_BASE + 8);
  IP_PACKET_TOO_BIG           = (IP_STATUS_BASE + 9);
  IP_REQ_TIMED_OUT            = (IP_STATUS_BASE + 10);
  IP_BAD_REQ                  = (IP_STATUS_BASE + 11);
  IP_BAD_ROUTE                = (IP_STATUS_BASE + 12);
  IP_TTL_EXPIRED_TRANSIT      = (IP_STATUS_BASE + 13);
  IP_TTL_EXPIRED_REASSEM      = (IP_STATUS_BASE + 14);
  IP_PARAM_PROBLEM            = (IP_STATUS_BASE + 15);
  IP_SOURCE_QUENCH            = (IP_STATUS_BASE + 16);
  IP_OPTION_TOO_BIG           = (IP_STATUS_BASE + 17);
  IP_BAD_DESTINATION          = (IP_STATUS_BASE + 18);


//
// The next group are status codes passed up on status indications to
// transport layer protocols.
//
  IP_ADDR_DELETED             = (IP_STATUS_BASE + 19);
  IP_SPEC_MTU_CHANGE          = (IP_STATUS_BASE + 20);
  IP_MTU_CHANGE               = (IP_STATUS_BASE + 21);
  IP_UNLOAD                   = (IP_STATUS_BASE + 22);
  IP_ADDR_ADDED               = (IP_STATUS_BASE + 23);

  IP_GENERAL_FAILURE          = (IP_STATUS_BASE + 50);
  MAX_IP_STATUS               = IP_GENERAL_FAILURE;
  IP_PENDING                  = (IP_STATUS_BASE + 255);


//
// Values used in the IP header Flags field.
//
  IP_FLAG_DF      = $02;         // Don't fragment this packet.

//
// Supported IP Option Types.
//
// These types define the options which may be used in the OptionsData field
// of the ip_option_information structure.  See RFC 791 for a complete
// description of each.
//
  IP_OPT_EOL      = 0;          // End of list option
  IP_OPT_NOP      = 1;          // No operation
  IP_OPT_SECURITY = $82;        // Security option
  IP_OPT_LSRR     = $83;        // Loose source route
  IP_OPT_SSRR     = $89;        // Strict source route
  IP_OPT_RR       = $07;        // Record route
  IP_OPT_TS       = $44;        // Timestamp
  IP_OPT_SID      = $88;        // Stream ID (obsolete)

  MAX_OPT_SIZE    = 40;         // Maximum length of IP options in bytes


//++
//
// Routine Name:
//
//     IcmpCreateFile
//
// Routine Description:
//
//     Opens a handle on which ICMP Echo Requests can be issued.
//
// Arguments:
//
//     None.
//
// Return Value:
//
//     An open file handle or INVALID_HANDLE_VALUE. Extended error information
//     is available by calling GetLastError().
//
//--
Function IcmpCreateFile : THandle; StdCall;

//++
//
// Routine Name:
//
//     IcmpCloseHandle
//
// Routine Description:
//
//     Closes a handle opened by ICMPOpenFile.
//
// Arguments:
//
//     IcmpHandle  - The handle to close.
//
// Return Value:
//
//     TRUE if the handle was closed successfully, otherwise FALSE. Extended
//     error information is available by calling GetLastError().
//
//--
Function IcmpCloseHandle(IcmpHandle : THandle) : BOOL; StdCall;

//++
//
// Routine Name:
//
//     IcmpSendEcho
//
// Routine Description:
//
//     Sends an ICMP Echo request and returns any replies. The
//     call returns when the timeout has expired or the reply buffer
//     is filled.
//
// Arguments:
//
//     IcmpHandle           - An open handle returned by ICMPCreateFile.
//
//     DestinationAddress   - The destination of the echo request.
//
//     RequestData          - A buffer containing the data to send in the
//                            request.
//
//     RequestSize          - The number of bytes in the request data buffer.
//
//     RequestOptions       - Pointer to the IP header options for the request.
//                            May be NULL.
//
//     ReplyBuffer          - A buffer to hold any replies to the request.
//                            On return, the buffer will contain an array of
//                            ICMP_ECHO_REPLY structures followed by the
//                            options and data for the replies. The buffer
//                            should be large enough to hold at least one
//                            ICMP_ECHO_REPLY structure plus
//                            MAX(RequestSize, 8) bytes of data since an ICMP
//                            error message contains 8 bytes of data.
//
//     ReplySize            - The size in bytes of the reply buffer.
//
//     Timeout              - The time in milliseconds to wait for replies.
//
// Return Value:
//
//     Returns the number of ICMP_ECHO_REPLY structures stored in ReplyBuffer.
//     The status of each reply is contained in the structure. If the return
//     value is zero, extended error information is available via
//     GetLastError().
//
//--
Function IcmpSendEcho(IcmpHandle         : THandle;
                      DestinationAddress : TIPAddr;
                      RequestData        : Pointer;
                      RequestSize        : Word;
                      RequestOptions : PIPOptionInformation;
                      ReplyBuffer        : Pointer;
                      ReplySize          : DWord;
                      Timeout            : DWord) : DWord; StdCall;

implementation

Const
  IcmpDll = 'Icmp.dll';

Function IcmpCreateFile; External IcmpDll Name 'IcmpCreateFile';
Function IcmpCloseHandle; External IcmpDll Name 'IcmpCloseHandle';
Function IcmpSendEcho; External IcmpDll Name 'IcmpSendEcho';

end.
