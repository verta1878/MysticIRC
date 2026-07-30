unit p_BinkP;

//
// binkp 3.0 Rev 6.1
//

interface

uses xMisc, xBase, xDES, Windows, SysUtils, InfoZip, MlrThr, PJSysInfo;

function CreateBinkPProtocol(CP: Pointer; const prec: TProtocolRecord): Pointer;

type
  TBinkPState = (
    bdNone,
    bdInit,
    bdSync,
    bdInfo,
    bdStartWaitFirstMsg,
    bdWaitFirstMsg,
    bdStartWaitPwd,
    bdWaitPwd,
    bdGetInKey,
    bdStartWaitOK,
    bdWaitOK,
    bdWaitDoneOK,
    bdSendPwd,
    bdSendOKPwd,
    bdSendBadPwd,
    bdWaitAnything,
    bdDoneAnything,
    bdAllAkasBusy,

    bdStartTransfer,
    bdTransfer,
    bdUnrec,
    bdGotErr,
    bdFinishFail,
    bdStartDrain,
    bdDrain,
    bdFinishOK,
    bd_Done,
    bdDone
  );

  TBinkPPktRx = (
    bdprxNone,
    bdprxHdrHi,
    bdprxHdrLo,
    bdprxData
  );

  TBinkPtx = (
    bdtxInit,
    bdtxGetNextFile,
    bdtxStartFile,
    bdtxWaitPos,
    bdtxGotM_GET,
    bdtxReadNextBlock,
    bdtxReadBlock,
    bdtxTransmit,
    bdtxWait_M_GOT,
    bdtxSendEOB,
    bdtxSendSecondEOB,
    bdtxInitX,
    bdtxDone
  );

  TBinkPrx = (
    bdrxInit,
    bdrxStartWaitFile,
    bdrxWaitFile,
    bdrxStartFile,
    bdrxStartReceData,
    bdrxStartWaitFileSync,
    bdrxWaitFileSync,
    bdrxGotFileSync,
    bdrx_ReceData,
    bdrxReceData,
    bdrxGot_M_EOB,
    bdrxWaitEOB,
    bdrx_Done,
    bdrxDone
  );

const
 
  MaxSndBlkSz   = $1000;      // 4096 Bytes max blocksize 
  StartSndBlkSz = $400;       // 1024 Bytes start blocksize
  DuplexBlkSz   = $1000;      // 4096 Bytes Duplex blocksize
  SubBlkSz      = $800;       // 2048 Bytes Sub blocksize

type
  TBinkPArray = array[0..2 * bdK32 - 1] of Char;
  TBinkPOutA  = array[0..MaxSndBlkSz - 1] of Char;

  TGetCharFunc = function(var C: Byte): Boolean of object;
  TWriteProc = procedure(const Buf; const i: DWORD; const Calc: boolean = False) of object;
  TPutCharProc = procedure(const C: Byte) of object;
  TCharReadyFunc = function: Boolean of object;

  TBinkP = class(TBiDirProtocol)
    function GetStateStr: string;                               override;
    constructor Create(ACP: TPort; const prec: TProtocolRecord);
    procedure ReportTraf(txMail, txFiles: Longint);             override;
    destructor Destroy;                                         override;
    function TimeoutValue: DWORD;                               override;
    procedure Cancel;                                           override;
    function NextStep: boolean;                                 override;
    procedure Start({RX}AAcceptFile: TAcceptFile;
                        AFinishRece: TFinishRece;
                    {TX}AGetNextFile: TGetNextFile;
                        AFinishSend: TFinishSend;
                    {CH}AChangeOrder: TChangeOrder
                     ); override;
    function CanChat: boolean; override;
    procedure StartBatch; override;
  private
    CRAM: Boolean;
    secondeob: Boolean;
    secondtime: Boolean;
    count: integer;
    ChallengePtr: PByteArray;
    ChallengeSize: Integer;
    SendDummies, AddrGot, PwdGot,
    OptGot, SupEncDesCBC: boolean;
    DesOutPos, DesOuts, DesInCollectPos, DesInGivePos: DWORD;
    DesInBuf, DesOutBuf: TDesBlock;
    ivIn, ivOut, DesKey: TDesBlock;
    DesKeySchedule: TdesKeySchedule;
    GetCharFunc: TGetCharFunc;
    WriteProc: TWriteProc;
    CharReadyFunc: TCharReadyFunc;
    PutCharProc: TPutCharProc;
    Timeout: EventTimer;
    OutMsgsColl,
    M_SKIP_Coll,
    M_GOT_Coll,
    M_GET_Coll: TStringColl;
    ReceSyncStr, ReceFileStr: string;
    InMsg: string;
     aOut: TBinkPOutA;
      aIn: TBinkPArray;
    aTmpS: TBinkPArray;
    aTmpR: TBinkPArray;
    CmpCnt: DWORD;
    CmpPos: DWORD;
    CmpOut: TBinkPArray;
    CmpGet: TBinkPArray;
    TmpPos: DWORD;
    CmpTmp: TBinkPArray;
    InHdrHi,
    InHdrLo: Byte;
    InCur, InRep: DWORD;
    OnceAgain,
    ZyRion: Boolean;
    InData: Boolean;
    InPZIP: boolean;
    SdPZIP: boolean;
    InGZIP: boolean;
    OutGZIP: boolean;
    OldState, OldOldState, OldOldOldState,
    State: TBinkPState;
    tx: TBinkPtx;
    rx: TBinkPrx;
    PktRx: TBinkPPktRx;
    CurPkt: DWORD;
    TxBlkSize, TxBlkPos,
    TxBlkRead: DWORD;
    OutMsgsLocked: Boolean;
    keysin,
    keysout: tkeys;
    LogFName: string;
    SZIPEnabled: boolean;
    UTF8Enabled: boolean;
    ChatEnabled: boolean;
    CrypEnabled: boolean;
    CrypStarted: boolean;
    ZIPReported: boolean;
    RemoteCanCrypt: boolean;
    RemoteCanTRS: boolean;
    RemoteCanUTF: boolean;
    RemoteCanPos: boolean;
    infile: string;
    function MakePwdStr(const AStr: string): string;
    procedure FreeChallenge;
    function RxPktKnown: Boolean;
    procedure LogPortErrors;
    procedure SetDesOut;
    procedure SetDesIn;
    function GetRxPktName: string;
    procedure SendMsg(Id: Byte; const Msg: string; const Flush: boolean = True);
    procedure SendId(Id: Byte);
    procedure SendDataHdr(Sz: DWORD);
    function CanSend: boolean;
    procedure DoChat;
    procedure DoTx;
    procedure DoRx;
    procedure DoStep;
    function RxPkt: DWORD;
    procedure FlushPkt;
    procedure FlushOutMsgs;
    procedure LogNul;
    procedure CheckOpt;
    procedure ChkPwd;
    procedure GetAdr;
    procedure SetTimeout;
    procedure LogBuf(var b; const i: integer; const d: string);
    function GetCharPlain(var C: Byte): Boolean;
    function GetCharDES(var C: Byte): Boolean;
    function GetCharCRY(var C: Byte): Boolean;
    function GetCharCMP(var C: Byte): Boolean;
    procedure WritePlain(const Buf; const i: DWORD; const Calc: boolean = False);
    procedure WriteDES(const Buf; const i: DWORD; const Calc: boolean = False);
    procedure WriteCRY(const Buf; const i: DWORD; const Calc: boolean = False);
    procedure WriteCMP(const Buf; const i: DWORD; const Calc: boolean = False);
    procedure PutCharPlain(const c: Byte);
    procedure PutCharDES(const c: Byte);
    procedure PutCharCRY(const c: Byte);
    procedure PutCharCMP(const c: Byte);
    function CharReadyPlain: Boolean;
    function CharReadyDES: Boolean;
    function CharReadyCRY: Boolean;
    function CharReadyCMP: Boolean;
    procedure GetOctetDES;
    procedure SendDummy;
    function KeySum: Word;
    procedure SetChallengeStr(const AStr: string);
    procedure InitCrypt;
    procedure InitCompr;
    function StringToUTF8(const s: string): string;
    function UTF8ToString(const s: string): string;
  public
    freqprocessed: boolean;
  end;

  TZIPStream = class(TDOSStream)
    aOut: TBinkPOutA;
    aPos: integer;
    Put_ZStream: z_stream;
    constructor Create(AHandle: DWORD);
    function Read(var Buffer; Count: Longint): Longint; override;
    destructor Destroy; override;
  end;

implementation

  uses xFido, Wizard, RadIni, Forms;

const
  M_Names : array[0..10] of string = (
     'M_NUL', 'M_ADR', 'M_PWD', 'M_FILE', 'M_OK', 'M_EOB',
     'M_GOT', 'M_ERR', 'M_BSY', 'M_GET', 'M_SKIP'
  );

  BinkPStateMsg : array[TBinkPState] of string = (
     'None',
     'Init',
     'Sync',
     'Info',
     'StartWaitFirstMsg',
     'WaitFirstMsg',
     'StartWaitPwd',
     'WaitPwd',
     'GetInKey',
     'StartWaitOK',
     'WaitOK',
     'WaitDoneOK',
     'SendPwd',
     'SendOKPwd',
     'SendBadPwd',
     'WaitAnything',
     'DoneAnything',
     'AllAKAsBusy',
     'StartTransfer',
     'Transfer',
     'Unrec',
     'GotErr',
     'FinishFail',
     'StartDrain',
     'Drain',
     'FinishOK',
     'PreDone',
     'Done'
  );

  BinkPPktRxMsg : array[TBinkPPktRx] of string = (
     'None',
     'HdrHi',
     'HdrLo',
     'Data'
  );

  BinkPtxMsg : array[TBinkPtx] of string = (
     'Init',
     'GetNextFile',
     'StartFile',
     'WaitPos',
     'GotM_GET',
     'ReadNextBlock',
     'ReadBlock',
     'Transmit',
     'Wait_M_GOT',
     'SendEOB',
     'SendSecondEOB',
     'bdtxInitX',
     'Done'
  );

  BinkPrxMsg : array[TBinkPrx] of string = (
     'Init',
     'StartWaitFile',
     'WaitFile',
     'StartFile',
     'StartReceData',
     'StartWaitFileSync',
     'WaitFileSync',
     'GotFileSync',
     '_ReceData',
     'ReceData',
     'Got_M_EOB',
     'WaitEOB',
     '_Done',
     'Done'
  );

  pktData    = $FFFFFFFF;
  pktNone    = $FFFFFFFE;

  pktDCD     = $FFFFFFFD;
  pktAbort   = $FFFFFFFC;
  pktTimeout = $FFFFFFFB;

  MinErr     = pktTimeout;
  MaxErr     = pktDCD;

function isWow64: Boolean;

Begin
isWow64 := TPJOSInfo.IsWow64;
End;

function Is64Bit: Boolean;

Begin
Is64Bit := TPJComputerInfo.Is64Bit;
End;

function IsServer: Boolean;

Begin
IsServer := TPJOSInfo.IsWindowsServer;
End;

function FileStrEx(B: TBatch; NeedOfs, NR: Boolean; InvalidTime: boolean; const InvalidTImeStr: string): string;
begin
  if not invalidtime then
    with B.D do
    if NeedOfs then begin
       if NR then begin
          Result := Format('%s %d %d %d', [StrQuote(FName), FSize, FTime, -1]);
       end else
          Result := Format('%s %d %d %d', [StrQuote(FName), FSize, FTime, FOfs])
    end else
       Result := Format('%s %d %d', [StrQuote(FName), FSize, FTime])
  else
    with B.D do
    if NeedOfs then Result := Format('%s %d %s %d', [StrQuote(FName), FSize, InvalidTimeStr, FOfs]) else
                    Result := Format('%s %d %s', [StrQuote(FName), FSize, InvalidTimeStr]);
end;

function FileStr(B: TBatch; NeedOfs, NR, GZip: Boolean): string;
begin
  result := filestrex(b, needofs, NR, false, '');
  if GZIP then Result := Result + ' GZ';
end;

{ TZIPStream }

constructor TZIPStream.Create(AHandle: DWORD);
begin
   inherited;
end;

destructor TZIPStream.Destroy;
begin
   inherited;
end;

function TZIPStream.Read(var Buffer; Count: Longint): Longint;
begin
   Result := inherited Read(aOut[aPos], Count);
   Tag := Result;
   if Tag = 0 then exit;
   Put_ZStream.next_in := @aOut;
   Put_ZStream.avail_in := Tag;
   Put_ZStream.next_out := @Buffer;
   Put_ZStream.avail_out := Tag + 24;
   Put_ZStream.total_out := 0;
   if deflate_(Put_ZStream, 1) < 0 then begin
      Result := 0;
      exit;
   end;
   Tag := Put_ZStream.total_out;
end;

procedure TBinkP.SetTimeout;
begin
  NewTimerSecs(Timeout, BinkPTimeout);
end;

destructor TBinkP.Destroy;
begin
  if Chat <> nil then begin
     PostMessage(MainWinHandle, WM_CLOSECHAT, Integer(Chat), Integer(Chat));
  end;
  Application.ProcessMessages;
  FreeObject(M_SKIP_Coll);
  FreeObject(M_GOT_Coll);
  FreeObject(M_GET_Coll);
  FreeObject(OutMsgsColl);
  FreeChallenge;
  inherited Destroy;
end;

procedure TBinkP.SendDummy;
var
   s: string;
   i: DWORD;
begin
   if not SendDummies then Exit;
   i := xRandom(4) + 5;
   s := '| ';
   while i > 0 do begin s := s + Char(xRandom(126 - 32) + 33); Dec(i) end;
   OutMsgsColl.Add(FormatBinkPMsg(M_NUL, s));
end;

procedure TBinkP.LogPortErrors;
var
   Coll: TStringColl;
   i, j: Integer;
begin
   Coll := CP.GetErrorStrColl;
   j := CollMax(Coll);
   if j < 0 then Exit;
   for i := 0 to j do begin
      CustomInfo := Coll[i];
      FLogFile(Self, lfBinkPNiaE);
   end;
   Coll.FreeAll;
end;

function TBinkP.RxPkt: DWORD;
var
  C: Byte;

  procedure Acc;
  var
     I: Integer;
    CC: Byte;
  begin
    InMsg := '';
    if InRep > 1 then
    begin
      for i := 1 to InRep - 1 do
      begin
        CC := Byte(aIn[I]);
        if CC = 0 then Break;
        InMsg := InMsg + Char(CC);
      end;
      if RemoteCanUTF then InMsg := UTF8ToString(InMsg);
     end;
  end;

  procedure GotSomth;
  begin
    InCur := 0;
    PktRx := bdprxHdrHi;
    if InData then Result := pktData else begin
      Acc;
      Result := DWORD(aIn[0]);
    end;
  end;

begin
  Result := CurPkt;
  if CancelRequested then Result := pktAbort else
  if TimerExpired(Timeout) then Result := pktTimeout else
  if CP.DCD <> CP.Carrier then begin
     CP.Carrier := not CP.Carrier;
     Result := pktDCD;
  end else
  if not CP.Carrier then begin
     Result := pktDCD;
  end;
  if Result <> pktNone then Exit;
  if (State = bdWaitAnything) then begin
     if CP.CharReady then State := bdDoneAnything;
     exit;
  end;
  if CharReadyFunc then begin
   OnceAgain := True;
    SetTimeout;
    while GetCharFunc(C) do begin
      case PktRx of
        bdprxHdrHi:
          begin
            InHdrHi := C;
            PktRx := bdprxHdrLo;
          end;
        bdprxHdrLo:
          begin
            InCur := 0;
            InPZIP := False;
            InHdrLo := C;
            InData := InHdrHi < $80;
            if RemoteCanPZIP then begin
               InPZIP := InHdrHi and $40 > 0;
               if InPZIP then begin
                  InHdrHi := InHdrHi and $3F;
               end;
            end;
            InRep := ((Word(InHdrHi) shl 8) + Word(InHdrLo)) and (bdK32 - 1);
            R.D.BlkLen := InRep;
            if InRep >= bdK32 then
            begin
              State := bdUnrec;
              Break;
            end;
            PktRx := bdprxData;
            if InCur = InRep then
            begin
              GotSomth;
              Break;
            end;
          end;
        bdprxData:
          begin
            if (InCur = bdK32) or (InCur = InRep) then GlobalFail('bdprxData InCur=%d InRep=%d', [InCur, InRep]);
            aIn[InCur] := Chr(C);
            Inc(InCur);
            if InCur = InRep then
            begin
              GotSomth;
              Break;
            end;
          end;
      end;
    end;
  end;
  CurPkt := Result;
  LogPortErrors;
end;

procedure TBinkP.FlushPkt;
begin
   CurPkt := pktNone;
end;

procedure TBinkP.FlushOutMsgs;
var
   i: integer;
   s: string;
begin
   if OutMsgsLocked then Exit;
   if State = bdWaitOK then Exit;
   s := '';
   for i := 0 to CollMax(OutMsgsColl) do begin
      s := s + OutMsgsColl[i];
   end;
   if s <> '' then begin
      WriteProc(s[1], Length(s));
      CP.Flsh;
   end;
   OutMsgsColl.FreeAll;
end;

constructor TBinkP.Create(ACP: TPort; const prec: TProtocolRecord);
begin
   inherited Create(ACP);
   FreqProcessed := false;
   M_GOT_Coll := TStringColl.Create;
   M_GET_Coll := TStringColl.Create;
   M_SKIP_Coll := TStringColl.Create;
   OutMsgsColl := TStringColl.Create;
   GetCharFunc := GetCharPlain;
   WriteProc := WritePlain;
   PutCharProc := PutCharPlain;
   CharReadyFunc := CharReadyPlain;
   secondeob := false;
   secondtime := false;
   count := 1;
   FiAddr    := prec.Addr;
   FiSysop   := prec.Sysop;
   FiStation := prec.Station;
   LogFName  := prec.LogFName;
   ChatEnabled := prec.ChatEnabled;
   CrypEnabled := prec.CrypEnabled;
end;

function TBinkP.TimeoutValue: DWORD;
begin
   Result := MultiTimeout([Timeout]);
   if DesKey <> 0 then Result := MinD(Result, 1000); // sleep no more than a second if ecrypted
end;

procedure TBinkP.Cancel;
begin
   FreeObject(CP);
end;

procedure TBinkP.SetChallengeStr(const AStr: string);
var
  sl: Integer;
   d: DWORD;
begin
  sl := Length(AStr);
  if (sl = 0) or Odd(sl) then begin
     State := bdFinishFail;
     SendMsg(M_ERR, Format('Invalid length of challenge string (%d chars)', [sl]));
     Exit;
  end;
  ChallengeSize := sl div 2;
  GetMem(ChallengePtr, ChallengeSize);
  for sl := 0 to ChallengeSize - 1 do begin
     d := VlH(Copy(AStr, sl * 2 + 1, 2));
     if (d = INVALID_VALUE) or (d > $FF) then begin
        State := bdFinishFail;
        SendMsg(M_ERR, Format('Invalid challenge string (%s)', [AStr]));
        Exit;
     end;
     ChallengePtr^[sl] := Byte(d);
  end;
end;

procedure TBinkP.CheckOpt;
var
  s,
  z,
  k: string;
begin
  s := InMsg;
  GetWrd(s, z, ' ');
  CustomInfo := InMsg;
  FLogFile(Self, lfBinkPNul);
  if UpperCase(z) <> 'OPT' then Exit;
  OptGot := True;
  while s <> '' do begin
     GetWrd(s, z, ' ');
     GetWrd(z, k, '-');
     k := UpperCase(k);
     if k = 'CRAM' then begin
        GetWrd(z, k, '-');
        if Pos('MD5', k) > 0 then begin
           RemoteCanCram := True;
           GetWrd(z, k, '-');
           if not CramDisabled then SetChallengeStr(k);
        end;
     end else begin
        if k = 'ENC' then begin
           GetWrd(z, k, '-');
           if k = 'DES' then begin
              GetWrd(z, k, '-');
              if k = 'CBC' then SupEncDesCBC := True;
           end;
        end else
        if k = 'CHT' then begin
           RemoteCanChat := True;
           FLogFile(self, lfChat);
        end else
        if k = 'LST' then begin
           RemoteCanList := True;
           ListBuf.Add('LIST');
        end else
        if k = 'HLZ' then begin
           RemoteCanHZIP := ZLIBLoaded and SZIPEnabled;
           if RemoteCanHZIP then begin
              RemoteCanPZIP := False;
           end;
        end else
        if k = 'PLZ' then begin
           if not RemoteCanHZIP then begin
              RemoteCanPZIP := ZLIBLoaded;
              if ZLIBLoaded then FLogFile(self, lfPZIP);
           end;
        end else
        if k = 'MBT' then begin
           RemoteCanDYNA := True;
           RemoteCan2eob := True;
           FLogFile(Self, lfDYNA);
           SendMsg(M_NUL, 'OPT MBT');
        end else
        if k = 'BRK' then begin
           if not RemoteCanBrek then FLogFile(Self, lfBrek);
           RemoteCanBrek := True;
           SendMsg(M_NUL, 'OPT BRK');
        end else
        if k = 'CRYPT' then begin
           RemoteCanCryp := IniFile.RequestCRYPT or CrypEnabled;
           RemoteCanCrypt := True;
        end else
        if k = 'TRS' then begin
           RemoteCanTRS := True;
        end else
        if k = 'UTF' then begin
           RemoteCanUTF := True;
        end else
        if k = 'GZ' then begin
           if not RemoteCanHZIP and ZLIBLoaded then begin
             RemoteCanGZIP := True;
             SendMsg(M_NUL, 'OPT EXTCMD');
           end;  
        end;
     end;
  end;
end;

procedure TBinkP.LogNul;
var
   i: integer;
   s: string;
begin
  if UpperCase(copy(InMsg, 1, 3)) = 'CHT' then begin
     s := copy(InMsg, 5, Length(InMsg) - 4);
     if ChatOpened and (UpperCase(s) = 'BYE') then begin
        ChatOpened := False;
        Chat.RemoteVisible := False;
        Chat.Visible := False;
     end else begin
        if UpperCase(s) <> 'BYE' then begin
           CustomInfo := InMsg;
           StartChat(LogFName, false, ChatBell);
           Chat.AddMsg(s);
        end;
     end;
  end else
  if UpperCase(copy(InMsg, 1, 3)) = 'TRS' then begin
     if UpperCase(copy(InMsg, 1, 7)) = 'TRS ASK' then begin
        CustomInfo := ExtractWord(3, InMsg, [' ']);
        FLogFile(Self, lfTRSASK);
        if CustomInfo = 'NAK' then begin
           SendTRSMsg(ExtractWord(3, InMsg, [' ']), 'NAK');
        end;
     end else
     if ExtractWord(3, InMsg, [' ']) = 'NAK' then begin
        for i := 0 to CollMax(TRSList) do begin
           s := TRSList[i];
           if ExtractWord(1, s, [' ']) = ExtractWord(2, InMsg, [' ']) then begin
              s := ExtractWord(1, s, [' ']) + ' NAK';
              TRSList[i] := s;
           end;
        end;
     end else
     if ExtractWord(3, InMsg, [' ']) = 'ACK' then begin
        for i := 0 to CollMax(TRSList) do begin
           s := TRSList[i];
           if ExtractWord(1, s, [' ']) = ExtractWord(2, InMsg, [' ']) then begin
              s := ExtractWord(1, s, [' ']) + ' ACK';
              TRSList[i] := s;
           end;
        end;
     end;
  end else
  if UpperCase(copy(InMsg, 1, 4)) = 'LIST' then begin
     RemoteUseList := True;
     SendFList;
  end else
  if UpperCase(copy(InMsg, 1, 3)) = 'LST' then begin
     ProcessLST(InMsg);
  end else begin
     if UpperCase(copy(InMsg, 1, 3)) = 'SYS' then begin
        fiStation := InMsg;
        delete(FiStation, 1, 4);
     end else
     if UpperCase(copy(InMsg, 1, 3)) = 'ZYZ' then begin
        fiSysop := InMsg;
        delete(FiSysop, 1, 4);
     end else
     if UpperCase(copy(InMsg, 1, 3)) = 'VER' then begin
        if pos('/1.1', InMsg) > 0 then begin
           RemoteCanDYNA := True;
           RemoteCan2eob := True;
           RemoteCanBrek := True;
           if IniFile.NRMode then RemoteCanPos  := True;
        end;
     end;
     CheckOpt;
     CustomInfo := InMsg;
  end;
  FlushPkt;
end;

procedure TBinkP.GetAdr;
begin
  CustomInfo := InMsg;
  ParseAddress(ExtractWord(1, InMsg, [' ']), FiAddr);
  FLogFile(Self, lfBinkPAddr);
  if CustomInfo <> '' then begin
     State := bdFinishFail;
     if Length(CustomInfo) = 1 then
     case CustomInfo[1] of
     #1: SendMsg(M_ERR, 'Invalid addrs: ' + InMsg);
     #3: State := bdSendBadPwd;
     #4: State := bdAllAkasBusy;
     end;
  end;
  FlushPkt;
end;

procedure TBinkP.ChkPwd;
begin
   CustomInfo := UniqStr + ' ' + InMsg;
   Finalize(UniqStr);
   FLogFile(Self, lfBinkPPwd);
   FlushPkt;
   if CustomInfo = cBadPwd then State := bdSendBadPwd else
   if CustomInfo = #4 then State := bdAllAkasBusy else
   if CustomInfo = 'CRYPT' then begin
      if RemoteCanCrypt then begin
         if not RemoteCanCryp then begin
            RemoteCanCryp := True;
            SendMsg(M_NUL, 'OPT CRYPT');
            FlushPkt;
         end;
      end;
   end;
end;

procedure TBinkP.ReportTraf(txMail, txFiles: Longint);
begin
  if txMail + txFiles > 0 then begin
     SendMsg(M_NUL, Format('TRF %d %d', [txMail, txFiles]));
  end;
end;

function TBinkP.GetRxPktName: string;
begin
  case CurPkt of
    0..10: Result := M_Names[CurPkt];
    else Result := Hex8(CurPkt)
  end;
end;

function TBinkP.KeySum: Word;
var
  k: TDesBlockI;
begin
  k[0] := $61C74D21;
  k[1] := $D06AB18C;
  xdes_ecb_encrypt_block(@k, SizeOf(k), DesKey, True);
  Result := xdes_md5_crc16(@k, 8);
end;

procedure TBinkP.DoStep;

procedure DoTransfer;
var
  ctx: TBinkPtx;
  crx: TBinkPrx;
  cnt: integer;
begin
  cnt := 0;
  repeat
    DoChat;
    ctx := tx;
    DoTx;
    crx := rx;
    DoRx;
    if State <> bdTransfer then break;
    inc(cnt);
    if cnt = 50 then break;
  until (ctx = tx) and (crx = rx);
  if cnt = 1 then Sleep(1);
  if (tx = bdtxDone) and (rx = bdrxDone) then begin
    State := bdStartDrain;
    OutFlow := True;
  end;
end;

function CanZIP: string;
begin
   SZIPEnabled := True;
   if ZLIBLoaded then Result := ' HLZ PLZ GZ'
                 else Result := '';
end;

function CanCht: string;
begin
   if ChatEnabled then Result := ' CHT'
                  else Result := '';
end;

function CanLst: string;
begin
   if IniFile.ibnRequestList then Result := ' LST'
                             else Result := '';
end;

function CanUTF: string;
begin
   UTF8Enabled := True;
   if UTF8Enabled then Result := ' UTF'
                  else Result := '';
end;

function AskCRYPT: string;
begin
   Result := '';
   if (IniFile.RequestCRYPT or CrypEnabled) and not CramDisabled then Result := ' CRYPT';
end;

function CanTRS: string;
begin
   if IniFile.RequestTRS then Result := ' TRS'
                         else Result := '';
end;

procedure SendAddr;
begin
   FLogFile(Self, lfBinkPgAddr);
   SendMsg(M_ADR, CustomInfo);
end;

procedure ParseOK_M_ERR;
var
  s,
  z: string;
begin
  State := bdGotErr;
  if DesKey = 0 then Exit;
  s := InMsg;
  GetWrd(s, z, ' ');
  if z <> 'ENC' then Exit;
  GetWrd(s, z, ' ');
  if z <> 'OK' then Exit;
  SetDesIn;
  State := bdStartWaitOK;
end;

procedure ParsePwd_M_ERR;
var
  s, z: string;
  i, j: DWORD;
begin
  State := bdGotErr;
  if not AddrGot then Exit;
  s := InMsg;
  GetWrd(s, z, ' ');
  if z <> 'ENC' then Exit;
  GetWrd(s, z, ' ');
  if z <> 'DES/CBC' then Exit;
  GetWrd(s, z, ' ');
  i := Vl(z);
  if i = INVALID_VALUE then Exit;
  if (i > $FFFF) then Exit;
  j := KeySum;
  if i <> j then begin
     CustomInfo := Format('%d %d', [i, j]);
     FLogFile(Self, lfBinkPBadKey);
     Exit;
  end;
  State := bdStartWaitPwd;
  SendMsg(M_ERR, 'ENC OK');
  CP.Flsh;
  SetDesIn;
  SetDesOut;
  xdes_set_key(DesKey, DesKeySchedule);
  SendDummy;
  SendAddr;
end;

function GetCramStr: string;
begin
  if CramDisabled then Result := '' else Result := ' CRAM-MD5-' + GetUniqStr;
end;

begin
  case State of
    bdInit:
      begin
        CustomInfo := CanZIP + CanCHT + CanLST + CanTRS + CanUTF + AskCRYPT;
        if CustomInfo <> '' then begin
           SendMsg(M_NUL, 'OPT' + CustomInfo);
        end;
        State := bdSync;
      end;
    bdSync:
      begin
         case RxPkt of
           pktNone : ;
           MinErr..MaxErr : ;
           Integer(M_ADR) : begin
                               if AddrGot then State := bdUnrec else begin AddrGot := True; State := bdGetInKey; GetAdr end;
                            end;
           Integer(M_ERR) : begin State := bdInfo; ParseOK_M_ERR; FlushPkt end;
           Integer(M_NUL) : begin State := bdInfo; LogNul; end;
           Integer(M_BSY) : begin State := bdFinishFail; end;
           else State := bdInfo;
         end;
      end;
    bdInfo:
      begin
        if RemoteCanHZip then InitCompr;

        { Data block what we will send to the remote }

        if not Originator then begin
        SendMsg(M_NUL, 'OPT' + GetCramStr, False);
        end;

        SendMsg(M_NUL, 'SYS ' + Station.Station, False);
        SendMsg(M_NUL, 'ZYZ ' + Station.Sysop, False);
        SendMsg(M_NUL, 'LOC ' + Station.Location, False);
        SendMsg(M_NUL, 'PHN ' + Station.Phone, False);
        SendMsg(M_NUL, 'NDL ' + Station.Flags, False);
        SendMsg(M_NUL, 'TIME '+ RFCDateStr, False);

        If NOT isServer then begin
        if Is64Bit then SendMsg(M_NUL, 'VER ' + ProductName + '/' + ProductVersion + '/' + ProductPlatform64 + ' binkp/1.1', False);
        if IsWow64 then SendMsg(M_NUL, 'VER ' + ProductName + '/' + ProductVersion + '/' + ProductPlatformWow + ' binkp/1.1', False)
        Else SendMsg(M_NUL, 'VER ' + ProductName + '/' + ProductVersion + '/' + ProductPlatform32 + ' binkp/1.1', False);
        End;

        If isServer then begin
        if Is64Bit then SendMsg(M_NUL, 'VER ' + ProductName + '/' + ProductVersion + '/' + ProductPlatform64 + ' ' + CPServer + ' binkp/1.1', False);
        if IsWow64 then SendMsg(M_NUL, 'VER ' + ProductName + '/' + ProductVersion + '/' + ProductPlatformWow + ' ' + CPServer + ' binkp/1.1', False)
        Else SendMsg(M_NUL, 'VER ' + ProductName + '/' + ProductVersion + '/' + ProductPlatform32 + ' ' + CPServer + ' binkp/1.1', False);
        end; { End from main start if enabled }
        
        { Complete Block ends here }

        if Originator then begin
           SendAddr;
           State := bdStartWaitFirstMsg;
        end else begin
           State := bdStartWaitPwd;
           FlushOutMsgs;
        end;
      end;
    bdStartWaitFirstMsg:
      State := bdWaitFirstMsg;
    bdWaitFirstMsg:
      case RxPkt of
        pktNone : ;
        MinErr..MaxErr : ;
        Integer(M_ADR) : if AddrGot then State := bdUnrec else begin AddrGot := True; State := bdStartWaitFirstMsg; GetAdr end;
        Integer(M_ERR) : begin ParseOK_M_ERR; FlushPkt end;
        Integer(M_NUL) : begin State := bdStartWaitFirstMsg; LogNul; if State = bdStartWaitFirstMsg then State := bdSendPwd end;
        else if RxPktKnown then State := bdUnrec else begin FlushPkt; State := bdStartWaitFirstMsg end;
      end;
    bdStartWaitPwd:
      State := bdWaitPwd;
    bdWaitPwd:
      case RxPkt of
        pktNone : ;
        MinErr..MaxErr : ;
        Integer(M_ADR) : if AddrGot then State := bdUnrec else begin AddrGot := True; State := bdGetInKey; GetAdr end;
        Integer(M_PWD) :
          if PwdGot then
            State := bdUnrec
          else
            begin
              PwdGot := True;
              State := bdSendOkPwd;
              ChkPwd
            end;
        Integer(M_ERR) : begin ParsePwd_M_ERR; FlushPkt end;
        Integer(M_NUL) : begin LogNul; State := bdStartWaitPwd end;
        else if RxPktKnown then State := bdUnrec else begin FlushPkt; State := bdStartWaitPwd end;
      end;
    bdGetInKey:
      begin
        State := bdStartWaitPwd;
        FLogFile(Self, lfBinkPgInKey);
        Move(CustomInfo[1], DesKey, 8);
        if DesKey = 0 then SendAddr else begin
           if PwdGot then State := bdUnrec;
        end;
      end;
    bdSendPwd:
      begin
        FLogFile(Self, lfBinkPgOutKey);
        Move(CustomInfo[1], DesKey, 8);
        if DesKey <> 0 then begin
           SendMsg(M_ERR, Format('ENC DES/CBC %d (This link is setup as encrypted)', [KeySum]));
           CP.Flsh;
           SetDesOut;
           xdes_set_key(DesKey, DesKeySchedule);
           SendDummy;
        end;
        FLogFile(Self, lfBinkPgPwd);
        if CustomInfo[1] <> ' ' then SendMsg(M_NUL, 'FREQ');
        DelFC(CustomInfo);
        SendMsg(M_PWD, MakePwdStr(CustomInfo));
        fiPassword := CustomInfo;
        if CRAM then FLogFile(Self, lfBinkPCRAM);
        SendDummy;
        State := bdWaitOK;
      end;
    bdStartWaitOK :
      State := bdWaitOK;
    bdWaitOK :
      case RxPkt of
      pktNone : ;
      MinErr..MaxErr : ;
      Integer(M_ADR) : if AddrGot then State := bdUnrec else begin AddrGot := True; if Originator then begin State := bdStartWaitOK; GetAdr end else State := bdUnrec end;
      Integer(M_OK)  :
         begin
            CP.Flsh;
            State := bdWaitDoneOK;
            if InMsg <> 'non-secure' then begin
               if InMsg = '' then begin
                  CustomInfo := 'Blank M_OK message';
                  FLogFile(Self, lfDebug);
               end;
               InitCrypt;
            end else begin
               CustomInfo := 'Remote submitted insecure session';
               FLogFile(Self, lfLog);
               if RemoteCanCryp then begin
                  RemoteCanCryp := False;
                  CustomInfo := 'CRYPT option disabled by remote for insecure link';
                  FLogFile(Self, lfLog);
               end;
            end;
            InitCompr;
         end;
      Integer(M_ERR) : begin ParseOK_M_ERR; FlushPkt  end;
      Integer(M_NUL) : begin LogNul; State := bdStartWaitOK end;
      else if RxPktKnown then State := bdUnrec else begin FlushPkt; State := bdStartWaitOK end;
      end;
    bdWaitDoneOK :
      begin
        FlushPkt;
        State := bdStartTransfer;
      end;
    bdSendOKPwd :
      begin
        CustomInfo := 'non-secure';
        if (FiPassword <> '') and (FiPassword <> '-') then CustomInfo := 'secure';
        if CustomInfo = '' then SendId(M_OK)
        Else SendMsg(M_OK, CustomInfo);
        State := bdStartTransfer;
        if CustomInfo = 'secure' then begin
           if RemoteCanHZIP then begin
              State := bdWaitAnything;
              tx := bdtxInit;
              rx := bdrxInit;
              CP.Flsh;
              exit;
           end;
           InitCrypt;
        end;
        InitCompr;
       end;
    bdWaitAnything:
      begin
        DoTransfer;
      end;
    bdDoneAnything:
      begin
        InitCrypt;
        InitCompr;
        State := bdTransfer;
      end;
    bdAllAkasBusy:
      begin
        SendMsg(M_ERR, 'All AKAs are busy');
        State := bdFinishFail;
      end;
    bdSendBadPwd :
      begin
        SendMsg(M_ERR, 'Bad password');
        State := bdFinishFail;
      end;
    bdGotErr :
      begin
        CustomInfo := InMsg;
        FLogFile(Self, lfBinkPErr);
        State := bdFinishFail;
      end;
    bdUnrec :
      begin
        if InData then CustomInfo := 'Data Block' else begin
           CustomInfo := M_Names[CurPkt];
           if InMsg <> '' then CustomInfo := Format('%s "%s" st=%s tx=%s rx=%s blk=%s', [CustomInfo, InMsg, BinkPStateMsg[OldOldState], BinkPtxMsg[tx], BinkPrxMsg[rx], BinkPPktRxMsg[PktRx]]);
        end;
        SendMsg(M_ERR, 'Unrecognized packet ' + CustomInfo);
        FLogFile(Self, lfBinkPUnrec);
        State := bdFinishFail;
      end;
    bdStartDrain: State := bdDrain;
    bdDrain:
      if (CP.OutUsed = 0) then State := bdFinishOK else
      case RxPkt of
        pktNone: {Sleep(100)};
        MinErr..MaxErr : ;
      else
        begin
          FlushPkt;
          State := bdStartDrain;
        end;
      end;
    bdFinishOK :
      begin
        State := bd_Done;
      end;
    bdFinishFail :
      begin
        if ProtocolError = ecOK then ProtocolError := ecTooManyErrors;
        State := bd_Done;
      end;
    bdStartTransfer :
      begin
        tx := bdtxInit;
        rx := bdrxInit;
        State := bdTransfer;
      end;
    bdTransfer:
      DoTransfer;
    bd_Done:
      begin
        Sleep(100);
        State := bdDone;
      end;
    bdDone: ;
   end;
end;

function TBinkP.CanSend: Boolean;
begin
   if T.D.BlkLen = 0 then T.D.BlkLen := 1024;
   Result := (CP.OutUsed < T.D.BlkLen * 2);
   if Result then SetTimeout;
end;

procedure TBinkP.DoChat;
var
   i: integer;
   s: string;
begin
   if State = bdWaitAnything then exit;
   if (ChatBuf <> '') and RemoteCanChat and CanSend then begin
      SendMsg(M_NUL, 'CHT ' + ChatBuf, False);
      ChatBuf := '';
   end;
   if Chat <> nil then begin
      if ChatBuf = '' then begin
         ChatBuf := Chat.ChatBuf;
      end;
      if not Chat.Visible and ChatOpened then begin
         ChatBuf := 'BYE';
         ChatOpened := False;
      end;
   end;
   while ListBuf.Count > 0 do begin
      CustomInfo := ListBuf[0];
      SendMsg(M_NUL, CustomInfo, False);
      FLogFile(Self, lfLog);
      ListBuf.AtFree(0);
   end;
   if IniFile.RequestTRS and RemoteCanTRS then begin
      TRSList.Enter;
      try
        for i := CollMax(TRSList) downto 0 do begin
           s := TRSList[i];
           if WordCount(s, [' ']) = 1 then begin
             CustomInfo := 'Requesting transit to: ' + s;
              FLogFile(Self, lfLog);
              SendMsg(M_NUL, 'TRS ASK ' + s, False);
              s := s + ' ASK';
              TRSList[i] := s;
           end else
           if ExtractWord(2, s, [' ']) = 'ACK' then begin
              CustomInfo := 'Transit request for: ' + ExtractWord(1, s, [' ']) + ' succeeded';
              FLogFile(Self, lfLog);
              TRSList.AtFree(i);
           end else
           if ExtractWord(2, s, [' ']) = 'NAK' then begin
              CustomInfo := 'Transit request for: ' + ExtractWord(1, s, [' ']) + ' failed';
              FLogFile(Self, lfLog);
              TRSList.AtFree(i);
           end;
        end;
      finally
        TRSList.Leave;
      end;
   end else begin
      TRSList.FreeAll;
   end;
   FlushOutMsgs;
end;

procedure TBinkP.DoTx;

function GotM_GET: Boolean;
 var
  s1,
  s2,
  z1,
  z2: string;
  jd: DWORD;
begin
  if M_GET_Coll.Count = 0 then Result := False else begin
    Result := True;
    s1 := M_GET_COll[0];
    s2 := FileStr(T, False, False, inGZIP);
    z1 := ''; z2 := '';
    for jd := 0 to 3 do begin
      if UpperCase(z1) <> UpperCase(z2) then begin
        SendMsg(M_ERR, Format('File names mismatch: %s / %s', [z1, z2]));
        State := bdFinishFail;
        Exit;
      end;
      GetWrd(s1, z1, ' ');
      GetWrd(s2, z2, ' ');
    end;
    jd := Vl(z1);
    if (jd = INVALID_VALUE) or (jd >= DWORD(MaxInt)) then begin
       SendMsg(M_ERR, Format('Invalid file position value: %s', [z1]));
       State := bdFinishFail;
       Exit
    end;

    T.D.FPos := jd;
    T.D.FOfs := jd;
    FLogFile(Self, lfSendSync);

    if T.Stream.Seek(T.D.FPos, FILE_BEGIN) = INVALID_FILE_SIZE then begin
       FFinishSend(Self, aaSysError);
       State := bdFinishFail;
       Exit
    end;

    M_GET_COll.AtFree(0);
    tx := bdTxGotM_GET;
    if pos('NZ', UpperCase(s1)) > 0 then begin
       RemoteCanPZIP := False;
       RemoteCanHZIP := False;
       RemoteCanGZIP := False;
       FLogFile(Self, lfNZIP);
    end;
  end;
end;

procedure Got__(Coll: TStringColl; Action: TTransferFileAction);
begin
   if UpperCase(Coll[0]) <> UpperCase(FileStr(T, False, False, inGZIP)) then
      State := bdFinishFail else begin
      Coll.AtFree(0);
      FFinishSend(Self, Action);
      tx := bdtxGetNextFile;
   end;
end;

var
  i: DWORD;
  l: longint;
  e: integer;
  z: integer;
begin
  if State = bdWaitAnything then exit;
  case tx of
    bdtxDone : ;
    bdtxInitX :
      begin
        if count > 2 then begin
          tx := bdtxInit;
        end;
        inc(count);
      end;
    bdtxInit :
      tx := bdtxGetNextFile;
    bdtxGetNextFile :
      begin
        if secondtime then secondeob := true;
        secondtime := true;
        OutFlow := True;
        T.ClearFileInfo;
        FGetNextFile(Self);
        if T.D.FName = '' then begin
           tx := bdtxSendEOB;
           if RemoteUseList then begin
              SendMsg(M_NUL, 'LST CLR');
           end;
        end else begin
           tx := bdtxStartFile;
        end;
      end;
    bdtxStartFile:
      begin
        SendMsg(M_FILE, FileStr(T, True, RemoteCanPos, RemoteCanGZIP));
        if RemoteCanGZIP then begin
           outGZIP := True;
           deflateend_(Put_ZStream);
           deflateini_(Put_ZStream, 9, PChar(ZLIB_Version), SizeOf(z_stream));
        end;
        ActuallySent := 0;
        VisuallySent := 0;
        tx := bdtxReadBlock;
        T.D.BlkLen := StartSndBlkSz;
        if RemoteCanPos then begin
        tx := bdtxWaitPos;
        end;
      end;
    bdtxWaitPos:
      GotM_GET;
    bdTxGotM_GET:
      begin
        if T.D.FOfs = T.D.FSize then begin
          FFinishSend(Self, aaRefuse);
          tx := bdtxGetNextFile;
        end else begin
          SendMsg(M_FILE, FileStr(T, True, False, RemoteCanGZIP));
          if rx = bdrxDone then i := MaxSndBlkSz else i := DuplexBlkSz;
          if i = 0 then i := SubBlkSz;
          T.D.BlkLen := i;
          tx := bdtxReadBlock;
          ActuallySent := 0;
          VisuallySent := 0;
        end;
      end;
    bdTxReadNextBlock:
      begin
        if rx = bdrxDone then i := MaxSndBlkSz else i := DuplexBlkSz;
        T.D.BlkLen := MinD(i, MaxD(T.D.BlkLen * 2, bdK32 - 1));
        tx := bdtxReadBlock;
      end;
    bdtxReadBlock:
      if not GotM_GET then
      if M_GOT_Coll.Count > 0 then Got__(M_GOT_Coll, aaRefuse) else
      if M_SKIP_Coll.Count > 0 then Got__(M_SKIP_Coll, aaAcceptLater) else begin
        i := MinD(T.D.BlkLen, T.D.FSize - T.D.FPos);
        SetLastError(0);
        if (T.Stream.Read(aOut, i) <> i) or (GetLastError <> 0) then begin
        FFinishSend(Self, aaSysError);
          State := bdFinishFail;
        end else begin
          TxBlkSize := i;
          TxBlkRead := i;
          TxBlkPos  := 0;
          SdPZIP := False;
          tx := bdtxTransmit;
          if RemoteCanPZIP then begin
             l := SizeOf(aTmpS);
             VisuallySent := VisuallySent + dword(i);
             e := Compress(@aTmpS, l, @aOut, i);
             if e < 0 then begin
               CustomInfo := 'Compress error: ' + IntToStr(e);
               FLogFile(Self, lfDebug);
               State := bdFinishFail;
               exit;
             end;
             if (dword(l) < i) then begin
                TxBlkSize := l;
                SdPZIP := RemoteCanPZIP;
                move(aTmpS, aOut, l);
                ActuallySent := ActuallySent + dword(l);
             end else begin
                ActuallySent := ActuallySent + dword(i);
             end;
             end else
             if outGZIP then begin
             l := SizeOf(aTmpS);
             VisuallySent := VisuallySent + dword(i);
             Put_ZStream.next_in := @aOut;
             Put_ZStream.avail_in := i;
             Put_ZStream.next_out := @aTmpS;
             Put_ZStream.avail_out := SizeOf(aTmpS);
             Put_ZStream.total_out := 0;
             z := 1;
             if T.d.FPos + i = T.d.FSize then z := 4;
             if deflate_(Put_ZStream, z) < 0 then begin
                CustomInfo := 'Deflate error: ' + Put_ZStream.msg;
                SendMsg(M_ERR, CustomInfo);
                FLogFile(Self, lfDebug);
                State := bdFinishFail;
                exit;
             end;
             l := Put_ZStream.total_out;
             TxBlkSize := l;
             move(aTmpS, aOut, l);
             ActuallySent := ActuallySent + dword(l);
             end;
          end;
        end;
     bdtxTransmit:
      if CanSend and not GotM_GET then begin
        if TxBlkPos = 0 then begin
          OutMsgsLocked := True;
          SendDataHdr(TxBlkSize);
        end;
        i := MinD(TxBlkSize - TxBlkPos, SubBlkSz);
        WriteProc(aOut[TxBlkPos], i, True);
        if TxBlkPos + i = TxBlkSize then begin
           Inc(T.D.FPos, TxBlkRead);
        end;
        if T.D.FPos = T.D.FSize then begin
          SendDataHdr(0);
          OutMsgsLocked := False;
          SendDummy;
          FlushOutMsgs;
          OutFlow := False;
          tx := bdtxWait_M_GOT;
        end else begin
          Inc(TxBlkPos, i);
          if TxBlkPos = TxBlkSize then begin
            tx := bdTxReadNextBlock;
            OutMsgsLocked := False;
            FlushOutMsgs;
          end;
        end;
      end;
    bdtxWait_M_GOT :
      if not GotM_GET then
      if M_GOT_Coll.Count > 0 then Got__(M_GOT_Coll, aaOK) else
      if M_SKIP_Coll.Count > 0 then Got__(M_SKIP_Coll, aaAcceptLater);
    bdtxSendEOB :
      begin
        if freqprocessed or Originator then begin
          if secondeob then begin
            OutFlow := False;
            FLogFile(Self, lfBatchSendEnd);
            SendId(M_EOB);
            tx := bdtxDone;
            if RemoteCan2eob then tx := bdtxSendSecondEOB;
          end else
            tx := bdtxInitX;
        end;
      end;
    bdtxSendSecondEOB:
      begin
        if TimerExpired(Timeout) then begin
           ProtocolError := ecTimeout;
           exit;
         end;
         if RemoteCanTRS and (CollMax(TRSList) > -1) then begin
            FlushPkt;
            if CP.Carrier <> CP.DCD then begin
               TRSList.FreeAll;
            end;
         end else
         if rx in [bdrxGot_M_EOB, bdrxWaitEOB, bdrxDone] then begin
            SendId(M_EOB);
            tx := bdtxDone;
         end;
      end;
    else
      GlobalFail('%s', ['bdtx']);
  end;
end;

procedure TBinkP.DoRx;
var
  invalidtime: boolean;
  invalidtimestr: string;
  l: longint;

function ParseFileData(AStr: String): Boolean;
var
  s: string;

procedure DoGet;
begin
  GetWrd(AStr, s, ' ')
end;

var
  i: DWORD;
begin
  Result := False;
  invalidtime := false;
  ActuallyRece  := 0;
  VisuallyRece  := 0;
  DoGet;
  if not StrDeQuote(s) then Exit;
  R.D.FName := s;
  DoGet;
  i := Vl(s); if i = INVALID_VALUE then Exit;
  R.D.FSize := i;
  DoGet;
  i := Vl(s);
  if i = INVALID_VALUE then begin
     invalidtime := true;
     invalidtimestr := s;
     i := uGetSystemTime;
  end;
  R.D.FTime := i;
  DoGet;
  if (s = '') then Exit;
  i := Vl(s); if i = INVALID_VALUE then Exit;
  R.D.FOfs := i;
  Result := True;
  InGZIP := False;
  while AStr <> '' do begin
     DoGet;
     if s = 'GZ' then begin
        inGZIP := True;
     end;
  end;
end;

procedure Add_M_GOT;
begin
  M_GOT_Coll.Add(InMsg);
  FlushPkt;
end;

procedure Add_M_GET;
begin
  M_GET_Coll.Add(InMsg);
  FlushPkt;
end;

procedure Add_M_SKIP;
begin
  M_SKIP_Coll.Add(InMsg);
  FlushPkt;
end;

function Skip: Boolean;

procedure Snd(C: Byte);
begin
  SendMsg(C, FileStr(R, False, False, False));
end;

begin
  Result := FileRefuse or FileSkip;
  if not Result then Exit;
  if FileSkip then begin
    Snd(M_SKIP);
    FFinishRece(Self, aaAcceptLater);
  end else
  if FileRefuse then begin
    Snd(M_GOT);
    FFinishRece(Self, aaRefuse);
  end;
  rx := bdrxWaitFile;
end;

var
   e: integer;

begin
  case rx of
    bdrxInit :
      rx := bdrxStartWaitFile;
    bdrxStartWaitFile:
      rx := bdrxWaitFile;
    bdrxWaitFile :
      case RxPkt of
        pktNone : ;
        pktData : begin FlushPkt; rx := bdrxStartWaitFile end;
        MinErr..MaxErr : ;
        Integer(M_ERR) : State := bdGotErr;
        Integer(M_GOT) : begin Add_M_GOT; rx := bdrxStartWaitFile end;
        Integer(M_GET) : begin Add_M_GET; rx := bdrxStartWaitFile end;
        Integer(M_SKIP): begin Add_M_SKIP; rx := bdrxStartWaitFile end;
        Integer(M_NUL) : begin LogNul; rx := bdrxStartWaitFile end;
        Integer(M_EOB) : rx := bdrxGot_M_EOB;
        Integer(M_FILE): begin R.ClearFileInfo; rx := bdrxStartFile end;
        else if RxPktKnown then State := bdUnrec else begin FlushPkt; rx := bdrxStartWaitFile end;
      end;
    bdrxStartFile:
      if not ParseFileData(InMsg) then begin
         if Extractword(4, InMsg, [' ']) = '-1' then begin
            ReceSyncStr := FileStr(R, True, False, inGZIP);
            SendMsg(M_GET, ReceSyncStr);
            FlushPkt;
            rx := bdrxWaitFile;
            exit;
         end;
         State := bdUnrec;
      end
      else begin
        ReceFileStr := FileStrEx(R, False, False, InvalidTime, InvalidTimeStr);
        case FAcceptFile(Self) of
          aaOK : rx := bdrxStartReceData;
          aaRefuse :
            begin
              SendMsg(M_GOT, ReceFileStr);
              rx := bdrxWaitFile;
            end;
          aaAcceptLater :
            begin
              SendMsg(M_SKIP, ReceFileStr);
              rx := bdrxWaitFile;
            end;
          aaAbort :
          State := bdFinishFail;
        end;
        FlushPkt;
      end;
    bdrxStartReceData:
      if R.D.FOfs = 0 then rx := bdrxReceData else begin
        ReceSyncStr := FileStr(R, True, False, inGZIP);
        SendMsg(M_GET, ReceSyncStr);
        rx := bdrxStartWaitFileSync;
      end;
    bdrxStartWaitFileSync:
      rx := bdrxWaitFileSync;
    bdrxWaitFileSync:
      case RxPkt of
        pktNone : ;
        pktData : begin FlushPkt; rx := bdrxStartWaitFileSync; end;
        MinErr..MaxErr  : ;
        Integer(M_ERR)  : State := bdGotErr;
        Integer(M_GOT)  : begin Add_M_GOT; rx := bdrxStartWaitFileSync; end;
        Integer(M_GET)  : begin Add_M_GET; rx := bdrxStartWaitFileSync; end;
        Integer(M_SKIP) : begin Add_M_SKIP; rx := bdrxStartWaitFileSync; end;
        Integer(M_NUL)  : begin LogNul; rx := bdrxStartWaitFileSync; end;
        Integer(M_FILE) : rx := bdrxGotFileSync;
      else
        if RxPktKnown then State := bdUnrec else begin FlushPkt; rx := bdrxStartWaitFileSync; end;
      end;
    bdrxGotFileSync:
      begin
        if UpperCase(InMsg) = UpperCase(ReceSyncStr) then rx := bdrxReceData
          else State := bdUnrec;
        FlushPkt;
      end;
    bdrx_ReceData:
      begin
        rx := bdrxReceData;
      end;
    bdrxReceData:
      if not Skip then
      case RxPkt of
        pktNone : ;
        pktData :
          begin
            rx := bdrx_ReceData;
            SetLastError(0);
            if InPZIP then begin
               l := SizeOf(aTmpR);
               ActuallyRece := ActuallyRece + InRep;
               e := uncompress(@aTmpR, l, @aIn, InRep);
               if (e < 0) or (l = SizeOf(aTmpR)) then begin
                  l := e;
                  R.D.fOfs := R.D.fPos;
                  ReceSyncStr := FileStr(R, True, False, False);
                  SendMsg(M_GET, ReceSyncStr + ' NZ');
                  rx := bdrxWaitFileSync;
                  exit;
               end;
               VisuallyRece := VisuallyRece + dword(l);
               InRep := l;
               move(aTmpR, aIn, l);
            end else
            if InGZIP then begin
               ActuallyRece := ActuallyRece + InRep;
               Get_ZStream.avail_in := InRep;
               InRep := 0;
               Get_ZStream.total_in := 0;
               Get_ZStream.next_in := @aIn[Get_ZStream.total_in];
               Get_ZStream.avail_out := SizeOf(aTmpR);
               Get_ZStream.next_out := @aTmpR;
               Get_ZStream.total_out := 0;
               if inflate_(Get_ZStream, 0) < 0 then begin
                  CustomInfo := 'Inflate error: ' + Get_ZStream.msg;
                  SendMsg(M_ERR, CustomInfo);
                  SendMsg(M_GET, ReceSyncStr + ' NZ');
                  FLogFile(Self, lfDebug);
                  State := bdFinishFail;
                  exit;
               end;
               l := Cardinal(Get_ZStream.total_out);
               VisuallyRece := VisuallyRece + DWORD(l);
               InRep := InRep + DWORD(l);
               move(aTmpR, aIn, l);
               if Get_ZStream.avail_in > 0 then begin
                  CustomInfo := 'Buffer overflow';
                  SendMsg(M_ERR, CustomInfo);
                  SendMsg(M_GET, ReceSyncStr + ' NZ');
                  FLogFile(Self, lfDebug);
                  State := bdFinishFail;
                  exit;
               end;
            end else
            if RemoteCanPZIP then begin
               ActuallyRece := ActuallyRece + InRep;
               VisuallyRece := VisuallyRece + InRep;
            end;
              if (R.Stream.Write(aIn, InRep) <> InRep) or (GetLastError <> 0) then begin
              FFinishRece(Self, aaSysError);
              State := bdFinishFail;
            end else begin
              Inc(R.D.FPos, InRep);
              if R.D.FPos > R.D.FSize then begin
                // Received data after eof
                State := bdFinishFail;
              end else
              if R.D.FPos = R.D.FSize then begin
                FFinishRece(Self, aaOK);
                SendMsg(M_GOT, ReceFileStr);
                rx := bdrxWaitFile;
                if inGZIP then begin
                   inflateend_(Get_ZStream);
                   inflateini_(Get_ZStream, PChar(ZLIB_Version), SizeOf(z_stream));
                end;
//                tx := bdtxInit;
              end;
            end;
            FlushPkt;
          end;
        MinErr..MaxErr : ;
        Integer(M_ERR) : State := bdGotErr;
        Integer(M_GOT) : begin Add_M_GOT; rx := bdrx_ReceData end;
        Integer(M_GET) : begin Add_M_GET; rx := bdrx_ReceData end;
        Integer(M_SKIP): begin Add_M_SKIP; rx := bdrx_ReceData end;
        Integer(M_NUL) : begin LogNul; rx := bdrx_ReceData end;
        Integer(M_FILE): begin FFinishRece(Self, aaOK); R.ClearFileInfo; rx := bdrxStartFile; end;
        else if RxPktKnown then State := bdUnrec else begin FlushPkt; rx := bdrx_ReceData end;
      end;
    bdrxGot_M_EOB:
      begin
        FLogFile(Self, lfBatchReceEnd);
        FlushPkt;
        rx := bdrxDone;
        if RemoteCan2eob then rx := bdrxWaitEOB;
      end;
    bdrxWaitEOB:
      case RxPkt of
        pktDCD,
        integer(M_EOB) : begin rx := bdrxDone; end;
        Integer(M_GOT) : begin Add_M_GOT; end;
        Integer(M_SKIP): begin Add_M_SKIP; end;
        Integer(M_GET) : begin Add_M_GET; end;
        Integer(M_FILE): begin R.ClearFileInfo; rx := bdrxStartFile; end;
        Integer(M_NUL) : begin LogNul; end;
      else
        if RxPktKnown then State := bdUnrec;
      end;
    bdrx_Done:
      rx := bdrxDone;
    bdrxDone :
      case RxPkt of
        pktNone : ;
        MinErr..MaxErr : ;
        Integer(M_ERR) : State := bdGotErr;
        Integer(M_GOT) : begin Add_M_GOT; rx := bdrx_Done end;
        Integer(M_GET) : begin Add_M_GET; rx := bdrx_Done end;
        Integer(M_SKIP): begin Add_M_SKIP; rx := bdrx_Done end;
        Integer(M_NUL) : begin LogNul; rx := bdrx_Done end;
        Integer(M_EOB) : begin rx := bdrxDone; end;
        Integer(M_FILE): begin R.ClearFileInfo; rx := bdrxStartFile; end;
      else
        if RxPktKnown then State := bdUnrec else begin FlushPkt; rx := bdrx_Done end;
      end;
  end;
end;

function TBinkP.NextStep: boolean;
begin
   repeat
      repeat
         OnceAgain := False;
         OldOldOldState := OldOldState;
         OldOldState := OldState;
         OldState := State;
         DoStep;
      until (OldState = State) and (not OnceAgain);
      FlushOutMsgs;
      Result := (ProtocolError <> ecOK) or (State = bdDone);
      if not Result then
      case RxPkt of
      pktNone: Break;
      pktDCD:
         begin
            if (rx <> bdrxDone) or (tx <> bdtxDone) then ProtocolError := ecAbortNoCarrier;
            Result := True;
         end;
      pktAbort:
         begin
            ProtocolError := ecAbortByLocal;
            Result := True;
         end;
      pktTimeout:
         begin
            ProtocolError := ecTimeout;
            Result := True;
         end;
      end;
      if Result then begin
         if not RxClosed then begin
            FFinishRece(Self, aaAbort);
         end;
         if not TxClosed then begin
            FFinishSend(Self, aaAbort);
         end;
      end;
      Sleep(50);
   until Result;
   if (R <> nil) and (rx <> bdrxWaitFileSync) then R.D.Part := InCur else R.D.Part := 0;
end;

procedure TBinkP.Start({RX}AAcceptFile: TAcceptFile; AFinishRece: TFinishRece;
                       {TX}AGetNextFile: TGetNextFile; AFinishSend: TFinishSend;
                       {CH}AChangeOrder: TChangeOrder);
begin
   inherited Start(AAcceptFile, AFinishRece, AGetNextFile, AFinishSend, AChangeOrder);
   State := bdInit;
   PktRx := bdprxHdrHi;
   CurPkt := pktNone;
   InCur := 0;
   T.D.BlkLen := 0;
   R.D.BlkLen := 0;
   M_GOT_Coll.FreeAll;
   M_GET_Coll.FreeAll;
   M_SKIP_Coll.FreeAll;
   OutMsgsColl.FreeAll;
   OutMsgsLocked := False;
   SetTimeout;
end;

procedure TBinkP.SendId(Id: Byte);
var
   s: string;
begin
   s := #$80#$01 + Char(Id);
   OutMsgsColl.Add(s);
   SendDummy;
   FlushOutMsgs;
end;

procedure TBinkP.SendMsg(Id: Byte; const Msg: string; const Flush: boolean = True);
begin
   OutMsgsColl.Add(FormatBinkPMsg(Id, StringToUTF8(Msg)));
   SendDummy;
   if Flush then FlushOutMsgs;
end;

procedure TBinkP.SendDataHdr(Sz: DWORD);
var
   b: byte;
begin
   b := Hi(Sz);
   if SdPZIP then begin
      b := b or $40;
   end;
   PutCharProc(b);
   PutCharProc(Lo(Sz));
end;

function TBinkP.GetStateStr: string;
begin
   Result := Format('%s st=%s/%s/%s/%s tx=%s rx=%s blk=%s', [GetRxPktName, BinkPStateMsg[OldOldOldState], BinkPStateMsg[OldOldState], BinkPStateMsg[OldState], BinkPStateMsg[State], BinkPtxMsg[tx], BinkPrxMsg[rx], BinkPPktRxMsg[PktRx]]);
end;

function TBinkP.GetCharPlain(var C: Byte): Boolean;
begin
   Result := CP.GetChar(C);
end;

procedure TBinkP.GetOctetDES;
var
   B: Byte;
   P: PByteArray;
begin
   P := @DesInBuf;
   while (DesInCollectPos < 8) do begin
      if not CP.GetChar(B) then Break;
      P^[DesInCollectPos] := B;
      Inc(DesInCollectPos);
   end;
   if DesInCollectPos = 8 then begin
      xdes_cbc_encrypt(DesInBuf, DesKeySchedule, ivIn, False);
      DesInCollectPos := 9;
      DesInGivePos := 0;
   end;
end;

function TBinkP.GetCharDES(var C: Byte): Boolean;
var
   P: PByteArray;
begin
   Result := False;
   GetOctetDES;
   if DesInCollectPos = 9 then begin
      Result := True;
      P := @DesInBuf;
      C := P^[DesInGivePos];
      Inc(DesInGivePos);
      if DesInGivePos = 8 then DesInCollectPos := 0;
   end;
end;

function TBinkP.GetCharCRY(var C: Byte): Boolean;
begin
   Result := CP.GetChar(C);
   if Result then decrypt_buf(C, 1, keysin);
end;

function TBinkP.GetCharCMP(var C: Byte): Boolean;
begin
   Result := CmpCnt > 0;
   if not Result then begin
      Result := CharReadyFunc;
      if not Result then exit;
   end;
   C := Byte(CmpOut[CmpPos]);
   Inc(CmpPos);
   if CmpPos = CmpCnt then begin
      CmpPos := 0;
      CmpCnt := 0;
   end;
end;

procedure TBinkP.WritePlain(const Buf; const i: DWORD; const Calc: boolean = False);
var
   p: PByteArray;
   c: DWORD;
begin
   if i = 0 then Exit;
   p := @Buf;
   for c := 0 to i - 1 do CP.PutChar(p^[c]);
end;

procedure TBinkP.WriteCRY(const Buf; const i: DWORD; const Calc: boolean = False);
var
   p: PByteArray;
   c: DWORD;
begin
   if i = 0 then Exit;
   p := @Buf;
   for c := 0 to i - 1 do PutCharCRY(p^[c]);
end;

procedure TBinkP.LogBuf;
var
   f: file;
begin
   exit;
   if infile = '' then infile := IntToStr(Integer(Originator));
   assignfile(f, 'e:\' + d + '.' + infile);
   {$I-}
   reset(f, 1);
   seek(f, filesize(f));
   {$I+}
   if ioresult <> 0 then rewrite(f, 1);
   blockwrite(f, b, i);
   closefile(f);
end;

procedure TBinkP.WriteCMP(const Buf; const i: DWORD; const Calc: boolean = False);
var
   p:^TBinkPArray;
   o:^TBinkPArray;
   c: DWORD;
//   e: integer;
begin
   if i + TmpPos = 0 then Exit;
   GetMem(p, TmpPos + i);
   GetMem(o, TmpPos + i + 24);
   try
     if TmpPos > 0 then begin
        move(CmpTmp, p^, TmpPos);
     end;
     move(Buf, p^[TmpPos], i);

  //   Put_BStream.next_in := p;
  //   Put_BStream.avail_in := TmpPos + i;
  //   Put_BStream.next_out := o;
  //   Put_BStream.avail_out := TmpPos + i + 12;
  //   e := bzdeflate_(Put_BStream, 1);
  //   if e < 0 then begin
  //      CustomInfo := 'Deflate error: ' + 'bzip(' + IntToStr(e) + ')';
  //      SendMsg(M_ERR, CustomInfo);
  //      FLogFile(Self, lfDebug);
  //      State := bdFinishFail;
  //   end;

     if Calc then VisuallySent := VisuallySent + TmpPos + i;
     Put_ZStream.next_in := p;
     Put_ZStream.avail_in := TmpPos + i;
     Put_ZStream.next_out := o;
     Put_ZStream.avail_out := TmpPos + i + 24;
     Put_ZStream.total_out := 0;
     if deflate_(Put_ZStream, 1) < 0 then begin
        CustomInfo := 'Deflate error: ' + Put_ZStream.msg;
        SendMsg(M_ERR, CustomInfo);
        FLogFile(Self, lfDebug);
        State := bdFinishFail;
        exit;
     end;
     if Calc then ActuallySent := ActuallySent + Cardinal(Put_ZStream.total_out);
     for c := 0 to Put_ZStream.total_out - 1 do begin
        if CrypStarted then PutCharCRY(Byte(o^[c])) else CP.PutChar(Byte(o^[c]));
     end;
     logbuf(o^, Put_ZStream.total_out, 'out');
   finally
     FreeMem(p, TmpPos + i);
     FreeMem(o, TmpPos + i + 24);
   end;
   TmpPos := 0;
end;

procedure TBinkP.WriteDES(const Buf; const i: DWORD; const Calc: boolean = False);
var
   c: Integer;
begin
   if i > 0 then begin
      for c := 0 to i - 1 do PutCharDES(PxByteArray(@Buf)^[c]);
   end;
end;

procedure TBinkP.PutCharPlain(const c: Byte);
begin
   CP.PutChar(c);
end;

procedure TBinkP.PutCharCRY(const c: Byte);
var
   b: byte;
begin
   b := c;
   encrypt_buf(b, 1, keysout);
   CP.PutChar(b);
end;

procedure TBinkP.PutCharCMP(const c: Byte);
begin
   CmpTmp[TmpPos] := Char(c);
   Inc(TmpPos);
end;

procedure TBinkP.PutCharDES(const c: Byte);
var
  j: Integer;
  P: PByteArray;
begin
  P := @DesOutBuf;
  P^[DesOutPos] := c;
  Inc(DesOutPos);
  if DesOutPos = 8 then begin
    xdes_cbc_encrypt(DesOutBuf, DesKeySchedule, ivOut, True);
    for j := 0 to 7 do CP.PutChar(P^[j]);
    Inc(DesOuts);
    if DesOuts > 32 then begin
      CP.Flsh;
      DesOuts := 0;
    end;
    DesOutPos := 0;
  end;
end;

function TBinkP.CharReadyPlain: Boolean;
begin
   Result := CP.CharReady;
end;

function TBinkP.CharReadyCRY: Boolean;
begin
   Result := CP.CharReady;
end;

function TBinkP.CharReadyCMP: Boolean;
var
   C: Byte;
   i: integer;
   p1,
   p2: pointer;
   ff: file of byte;
begin
   Result := CmpCnt > 0;
   if Result then exit;

{   if originator then begin
      getmem(p1, 999);
      getmem(p2, 200000);
         assignfile(ff, 'e:\in.0');
         reset(ff);
         blockread(ff, p1^, 999);
         closefile(ff);
      Get_ZStream.avail_in := 999;
      Get_ZStream.next_in := p1;
      Get_ZStream.avail_out := 200000;
      Get_ZStream.next_out := p2;
      Get_ZStream.total_out := 0;
      inflate_(Get_ZStream, 1);
      assignfile(ff, 'e:\test.out');
      rewrite(ff);
      blockwrite(ff, p2^, Get_ZStream.total_out);
      closefile(ff);
   end;}

   if Get_ZStream.avail_in > 0 then begin
      Result := True;
      Get_ZStream.next_in := @CmpGet[Get_ZStream.total_in];
      Get_ZStream.avail_out := SizeOf(CmpOut);
      Get_ZStream.next_out := @CmpOut;
      Get_ZStream.total_out := 0;
      if inflate_(Get_ZStream, 1) < 0 then begin
         Result := False;
         CustomInfo := 'Inflate error: ' + Get_ZStream.msg;
         SendMsg(M_ERR, CustomInfo);
         FLogFile(Self, lfDebug);
         State := bdFinishFail;
         exit;
      end;
      VisuallyRece := VisuallyRece + Cardinal(Get_ZStream.total_out);
      CmpCnt := CmpCnt + DWORD(Get_ZStream.total_out);
      exit;
   end;
   Result := CP.CharReady;
   if Result then begin
      i := 0;
      While CP.CharReady and (i < SizeOf(CmpOut) div 2) do begin
         CP.GetChar(C);
         if CrypStarted then decrypt_buf(C, 1, keysin);
         CmpGet[i] := Char(c);
         inc(i);
      end;
      logbuf(CmpGet, i, 'in');
      ActuallyRece := ActuallyRece + Cardinal(i);
      Get_ZStream.next_in := @CmpGet;
      Get_ZStream.avail_in := i;
      Get_ZStream.total_in := 0;
      Get_ZStream.next_out := @CmpOut;
      Get_ZStream.avail_out := SizeOf(CmpOut);
      Get_ZStream.total_out := 0;
      if inflate_(Get_ZStream, 1) < 0 then begin
         CustomInfo := 'Inflate error: ' + Get_ZStream.msg;
         SendMsg(M_ERR, CustomInfo);
         FLogFile(Self, lfDebug);
         State := bdFinishFail;
         exit;
      end;
      VisuallyRece := VisuallyRece + Cardinal(Get_ZStream.total_out);
      CmpCnt := CmpCnt + DWORD(Get_ZStream.total_out);
   end;
end;

function TBinkP.CharReadyDES: Boolean;
begin
   Result := DesInCollectPos = 9;
   if (not Result) and (CP.CharReady) then begin
      GetOctetDES;
      Result := CharReadyDES;
   end;
end;

procedure TBinkP.SetDesOut;
begin
   SendDummies := True;
   WriteProc := WriteDES;
   PutCharProc := PutCharDES;
   DesOutPos := 0;
end;

procedure TBinkP.SetDesIn;
begin
   GetCharFunc := GetCharDES;
   CharReadyFunc := CharReadyDES;
   DesInCollectPos := 0
end;

function TBinkP.RxPktKnown: Boolean;
begin
  case RxPkt of
    M_NUL,
    M_ADR,
    M_PWD,
    M_FILE,
    M_OK,
    M_EOB,
    M_GOT,
    M_ERR,
    M_BSY,
    M_GET,
    M_SKIP:
      Result := True
  else
      Result := False;
  end;
end;

procedure TBinkP.FreeChallenge;
begin
   if ChallengePtr = nil then Exit;
   FreeMem(ChallengePtr, ChallengeSize);
   ChallengePtr := nil;
end;

function TBinkP.MakePwdStr(const AStr: string): string;
begin
   if ChallengePtr = nil then begin Result := AStr; Exit end;
   Result := 'CRAM-MD5-' + KeyedMD5(AStr[1], Length(AStr), ChallengePtr^, ChallengeSize);
   CRAM := True;
   FreeChallenge;
end;

function TBinkP.CanChat;
begin
   Result := RemoteCanChat and ChatEnabled;
end;

procedure TBinkP.StartBatch;
begin
   if RemoteUseList then begin
      SendFList;
   end;
   if remoteCanDYNA and ((tx = bdtxDone) or (tx = bdtxSendSecondEOB)) then tx := bdtxGetNextFile else
   if remoteCanBREK then begin
      if Assigned(FChangeOrder) and FChangeOrder(self) then begin
         tx := bdtxGetNextFile;
      end;
   end;
end;

procedure TBinkP.InitCrypt;
var
   i: integer;
begin
   RemoteCanCryp :=  RemoteCanCryp and (FiPassword <> '-') and (RemoteCanCRAM or Originator);
   if not RemoteCanCryp then exit;
   FLogFile(Self, lfCRYP);
   if Originator then begin
      init_keys(keysout, FiPassword);
      init_keys(keysin, '-');
      for i := 1 to length(FiPassword) do begin
         update_keys(keysin, ord(FiPassword[i]));
      end;
   end else begin
      init_keys(keysin, FiPassword);
      init_keys(keysout, '-');
      for i := 1 to length(FiPassword) do begin
         update_keys(keysout, ord(FiPassword[i]));
      end;
   end;
   CP.Flsh;
   CrypStarted := True;
   if RemoteCanHZIP then exit;
   GetCharFunc := GetCharCRY;
   WriteProc := WriteCRY;
   PutCharProc := PutCharCRY;
   CharReadyFunc := CharReadyCRY;
end;

procedure TBinkP.InitCompr;
begin
   if RemoteCanHZIP then begin
      if not ZIPReported then begin
         FLogFile(self, lfSZIP);
         CP.Flsh;
      end;
      GetCharFunc := GetCharCMP;
      WriteProc := WriteCMP;
      PutCharProc := PutCharCMP;
      CharReadyFunc := CharReadyCMP;
      ZIPReported := True;
   end;
end;

function CreateBinkPProtocol(CP: Pointer; const prec: TProtocolRecord): Pointer;
begin
  Result := TBinkP.Create(CP, Prec);
end;

function TBinkP.StringToUTF8(const s: string): string;
var
   t: PWideChar;
   i: integer;
   c: integer;
begin
   if RemoteCanUTF then begin
      GetMem(t, Length(s) * 2 + 2);
      try
         FillChar(t^, Length(s) * 2 + 2, 0);
         c := GetACP;
         MultibyteToWideChar(c, MB_PRECOMPOSED, PChar(s), Length(s), t, Length(s) * 2 + 2);
         SetLength(Result, Length(s) * 3 + 2);
         i := WideCharToMultiByte(CP_UTF8, 0, t, -1, PChar(Result), Length(s) * 3 + 2, Nil, Nil);
         SetLength(Result, i - 1);
      finally
         FreeMem(t, Length(s) * 2 + 2);
      end;
   end else begin
      Result := s;
   end;
end;

function TBinkP.UTF8ToString(const s: string): string;
var
   t: PWideChar;
   i: integer;
   c: integer;
begin
   if RemoteCanUTF then begin
      GetMem(t, Length(s) * 2 + 2);
      try
         FillChar(t^, Length(s) * 2 + 2, 0);
         MultibyteToWideChar(CP_UTF8, 0, PChar(s), Length(s), t, Length(s) * 2 + 2);
         SetLength(Result, Length(s) * 3 + 2);
         c := GetACP;
         i := WideCharToMultiByte(c, 0, t, -1, PChar(Result), Length(s) * 3 + 2, Nil, Nil);
         SetLength(Result, i - 1);
      finally
         FreeMem(t, Length(s) * 2 + 2);
      end;
   end else begin
      Result := s;
   end;
end;

end.


