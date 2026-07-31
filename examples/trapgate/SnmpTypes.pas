unit SnmpTypes;

interface

uses
  Windows;

const
  SNMPAPI_NOERROR                 = INTEGER(TRUE);
  SNMPAPI_ERROR                   = INTEGER(FALSE);
  SNMP_MEM_ALLOC_ERROR            = 1;
  SNMP_BERAPI_INVALID_LENGTH      = 10;
  SNMP_BERAPI_INVALID_TAG         = 11;
  SNMP_BERAPI_OVERFLOW            = 12;
  SNMP_BERAPI_SHORT_BUFFER        = 13;
  SNMP_BERAPI_INVALID_OBJELEM     = 14;
  SNMP_PDUAPI_UNRECOGNIZED_PDU    = 20;
  SNMP_PDUAPI_INVALID_ES          = 21;
  SNMP_PDUAPI_INVALID_GT          = 22;
  SNMP_AUTHAPI_INVALID_VERSION    = 30;
  SNMP_AUTHAPI_INVALID_MSG_TYPE   = 31;
  SNMP_AUTHAPI_TRIV_AUTH_FAILED   = 32;
  SNMP_ERRORSTATUS_NOERROR        = 0;
  SNMP_ERRORSTATUS_TOOBIG         = 1;
  SNMP_ERRORSTATUS_NOSUCHNAME     = 2;
  SNMP_ERRORSTATUS_BADVALUE       = 3;
  SNMP_ERRORSTATUS_READONLY       = 4;
  SNMP_ERRORSTATUS_GENERR         = 5;
  SNMP_GENERICTRAP_COLDSTART      = 0;
  SNMP_GENERICTRAP_WARMSTART      = 1;
  SNMP_GENERICTRAP_LINKDOWN       = 2;
  SNMP_GENERICTRAP_LINKUP         = 3;
  SNMP_GENERICTRAP_AUTHFAILURE    = 4;
  SNMP_GENERICTRAP_EGPNEIGHLOSS   = 5;
  SNMP_GENERICTRAP_ENTERSPECIFIC  = 6;
  SNMP_NAME_LENGTH                = 10;
  ASN_UNIVERSAL                   = $00;
  ASN_APPLICATION                 = $40;
  ASN_CONTEXTSPECIFIC             = $80;
  ASN_PRIMITIVE                   = $00;
  ASN_CONSTRUCTOR                 = $20;
  ASN_INTEGER                = (ASN_UNIVERSAL or ASN_PRIMITIVE or $02);
  ASN_NULL                   = (ASN_UNIVERSAL or ASN_PRIMITIVE or $05);
  ASN_RFC1155_IPADDRESS      = (ASN_APPLICATION or ASN_PRIMITIVE or $00);
  ASN_RFC1157_GETNEXTREQUEST = (ASN_CONTEXTSPECIFIC or ASN_CONSTRUCTOR or $01);

  SNMP_LIB_NAME              = 'inetmib1.dll';
  SNMP_INITPROC_NAME         = 'SnmpExtensionInit';
  SNMP_QUERYPROC_NAME        = 'SnmpExtensionQuery';


type
  PAsnOctetString = ^TAsnOctetString;
  TAsnOctetString = packed record
    stream  : PBYTE;
    length  : CARDINAL;
    dynamic : BOOL;
  end;

  PAsnObjectIdentifier = ^TAsnObjectIdentifier;
  TAsnObjectIdentifier = packed record
    idLength : CARDINAL;
    ids      : ^CARDINAL;
  end;

  TListID               = array[1..SNMP_NAME_LENGTH] of Integer;

  TAsnInteger          = LONGINT;
  TAsnCounter          = LONGINT;
  TAsnGauge            = LONGINT;
  TAsnTimeticks        = LONGINT;
  TAsnSequence         = TAsnOctetString;
  TAsnImplicitSequence = TAsnSequence;
  TAsnIPAddress        = TAsnOctetString;
  TAsnDisplayString    = TAsnOctetString;
  TAsnOpaque           = TAsnOctetString;
  TAsnObjectName       = TAsnObjectIdentifier;

  TAsnAny = packed record
    asnType        : Byte;
    estidetabarnak : array[0..2] of Byte;
    case Integer of
      0: (number: TAsnInteger);
      1: (asnstring: TAsnOctetString);
      2: (asnobject: TAsnObjectIdentifier);
      3: (sequence: TAsnSequence);
      4: (address: TAsnIPAddress);
      5: (counter: TAsnCounter);
      6: (gauge: TAsnGauge);
      7: (ticks: TAsnTimeticks);
      8: (arbitrary: TAsnOpaque);
  end;

  TAsnObjectSyntax = TAsnAny;

  PRFC1157VarBind = ^TRFC1157VarBind;
  TRFC1157VarBind = packed record
    name : TAsnObjectName;
    value : TAsnObjectSyntax;
  end;

  PRFC1157VarBindList = ^TRFC1157VarBindList;
  TRFC1157VarBindList = packed record
    list : PRFC1157VarBind;
    len  : CARDINAL;
  end;

  TSnmpInitProc = function(dwTimeZeroReference   : DWORD;
                           Var hPollForTrapEvent : THandle;
                           Var SupportedView     : TAsnObjectIdentifier) : BOOL; stdcall;

  TSnmpQueryProc = function(RequestType          : Byte;
                            Var VariableVindings : TRFC1157VarBindList;
                            Var ErrorStatus      : TAsnInteger;
                            Var ErrorIndex       : TAsnInteger         ) : BOOL; stdcall;


const
  Closed       = 1;
  Listen       = 2;
  Syn_Sent     = 3;
  Syn_Received = 4;
  Established  = 5;
  Close_Wait   = 6;
  Fin_Wait_1   = 7;
  Closing      = 8;
  Last_Ack     = 9;
  Fin_Wait_2   = 10;
  Time_Wait    = 11;
  Tcb_Discard  = 12;

  NextRequest  = ASN_RFC1157_GETNEXTREQUEST;

  TcpList : TListID = (1, 3, 6, 1, 2, 1, 6, 13, 1, 1);
  UdpList : TListID = (1, 3, 6, 1, 2, 1, 7, 5, 1, 1);

implementation


end.

