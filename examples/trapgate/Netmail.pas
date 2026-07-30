unit Netmail;

interface

uses Windows, xBase, xFido, MClasses;

{$I ftsc.inc}

type

   TNetmailMsg = class
      Addr: TFidoAddress;
      From: TFidoAddress;
      Lock: TFidoAddress;
      Tonm: string;
      Frnm: string;
      Subj: string;
      Pack: string;
      MsId: string;
      Chrs: string;
      Offs: int64;
      bOff: int64;
      Head: PackedMsgHeaderRec;
      Size: int64;
      Addy: integer;
      Body: Pointer;
      Fido: boolean;
      Klug: TStringColl;
      function IChr: string;
      function Date: string;
      destructor Destroy; override;
   end;

   TNetmailPkt = class
      Pack: string;
      Mark: cardinal;
   end;

   TPktColl = class(TColl)
      function  FindName(const n: string): integer;
      function  GetAnItem(i: integer): TNetmailPkt;
      procedure SetItem(i: integer; p: TNetmailPkt);
      property  Items[i: integer]: TNetmailPkt read GetAnItem write SetItem;
   end;

   TLogProcedure = procedure(Tag: TLogTag; const Str: string) of object;

   TNetmail = class
   private
      PktColl: TPktColl;
      MsgColl: TstringColl;
      NetWait: TRTLCriticalSection;
      procedure FreePack(p: TNetmailPkt);
      procedure Scan(const path: string);
      procedure ScanPacket(const pack: string);
      procedure MoveMail(n: TNetmailMsg; const t: TFidoAddress; const a: string);
      procedure PackMail(const a: TFidoAddress; const r, e, p: string);
      procedure DelMail(n: TNetmailMsg);
   public
      NetColl: TColl;
      constructor Create; virtual;
      destructor Destroy; override;
      procedure ScanMail;
      procedure Route(const a: TFidoAddress; Log: TLogProcedure);
      procedure DeleteMail(const Id: string);
      function FindMessage(const Id: string): TNetmailMsg;
   end;

procedure FreeNetmailHolder;

var
   NetmailHolder: TNetmail;
      NetmailLog: string;
   
implementation

uses RadIni, RRegExp, Classes, SysUtils, Wizard,
     Outbound, DateUtils, IniFiles, Forms;

procedure FreeNetmailHolder;
begin
   FreeObject(NetmailHolder);
end;

function TNetmailMsg.IChr;
begin
   if pos('CP', UpperCase(Chrs)) = 1 then begin
      Result := ExtractWord(1, Chrs, [' ']);
   end else
   if Chrs = 'UKR 2' then begin
      Result := 'ibm866';
   end else
   if Chrs = 'IBMPC 2' then begin
      Result := 'ibm866';
   end else
   if Chrs = '+7 FIDO 2' then begin
      Result := 'ibm866';
   end else
   if Chrs = '+7_FIDO 2' then begin
      Result := 'ibm866';
   end else begin
      Result := 'us-ascii';
   end;
end;

function TNetmailMSG.Date;
begin
   Result := copy(Head.DateTime, 1, 19);
end;

destructor TNetmailMsg.Destroy;
begin
   if Body <> nil then begin
      FreeMem(Body, Size);
   end;
   FreeObject(Klug);
   inherited;
end;

{destructor TNetmailMsg.Destroy;
begin
   if Body <> nil then begin
      FreeMem(Body, Size);
   end;
   inherited;
end; }

function TPktColl.FindName;
var i: integer;
begin
   Result := -1;
   for i := 0 to count - 1 do begin
      if UpperCase(n) = Items[i].Pack then begin
         Result := i;
         exit;
      end;
   end;
end;

function TPktColl.GetAnItem;
begin
   Result := self[i];
end;

procedure TPktColl.SetItem;
begin
   self[i] := p;
end;

constructor TNetmail.Create;
begin
   inherited Create;
   PktColl := TPktColl.Create('PktColl');
   MsgColl := TStringColl.Create('MsgColl');
   InitializeCriticalSection(NetWait);
end;

destructor TNetmail.Destroy;
begin
   FreeObject(NetColl);
   FreeObject(MsgColl);
   FreeObject(PktColl);
   PurgeCS(NetWait);
   inherited;
end;

procedure TNetmail.FreePack;
var i: integer;
    m: TNetmailMsg;
begin
   NetColl.Enter;
   for i := NetColl.Count - 1 downto 0 do begin
      m := NetColl[i];
      if m.Pack = p.Pack then begin
        NetColl.AtFree(i);
      end;
   end;
   NetColl.Leave;
   PktColl.Delete(p);
   FreeObject(p);
end;

procedure TNetMail.ScanMail;
var
    p: string;
    e: string;
   SR: tuFindData;
begin
   EnterCS(NetWait);
   FreeObject(NetColl);
   NetColl := TColl.Create('NetColl');
   p := ExtractFilePath(ExtractDir(inifile.Outbound));
   if uFindFirst(p + '*.*', SR) then begin
      repeat
         if SR.FName[1] = '.' then continue;
         if SR.Info.Attr and FILE_ATTRIBUTE_DIRECTORY <> 0 then begin
            e := ExtractFileExt(SR.FName);
            Delete(e, 1, 1);
            if (VlH(e) > 0) or (e = '') then begin
               if IniFile.D5Out then begin
                  Scan(p + SR.FName);
               end else
               if Pos(UpperCase(IniFile.Outbound), UpperCase(p + SR.FName)) > 0 then begin
                  Scan(p + SR.FName);
               end;
            end;
         end;
      until not uFindNext(SR);
      uFindClose(SR);
   end;
   LeaveCS(NetWait);
end;

procedure TNetmail.Scan;
var SR: tuFindData;
    RE: TPCRE;
    BN: string;
    BF: TBusyFlag;
    CC: integer;
begin
   if uFindFirst(path + '\*.*', SR) then begin
//      RE := GetRegExpr('^[0-9a-f]{8}\.[icdnoh]{1}ut$');
//      RE.PattOptions := [poCaseless];
      RE := GetRegExpr('^[0-9a-fA-F]{8}\.[IiCcDdNnOoHh][Uu][Tt]$');
      repeat
         if SR.FName = '.'  then continue;
         if SR.FName = '..' then continue;
         if SR.Info.Attr and FILE_ATTRIBUTE_DIRECTORY <> 0 then begin
            if VlH(ExtractFileName(SR.FName)) > 0 then begin
               RE.Unlock;
               scan(path + '\' + SR.FName);
               RE.Lock;
            end;
         end else begin
            if RE.Match(SR.FName) > 0 then begin
               PktColl.Enter;
               CC := PktColl.FindName(path + '\' + SR.FName);
               if (CC = -1) or (
                  (CC > -1) and (PktColl.Items[CC].Mark <> SR.Info.Time)) then begin
                  if CC > - 1 then FreePack(PktColl.Items[CC]);
                  BN := ChangeFileExt(path + '\' + SR.FName, '.bsy');
                  CC := 0;
                  while ExistFile(BN) do begin
                     Sleep(100);
                     Application.ProcessMessages;
                     inc(CC);
                     if CC = 50 then break;
                  end;
                  if not ExistFile(BN) then begin
                     BF := TBusyFlag.Create(BN, False);
                     ScanPacket(path + '\' + SR.FName);
                     BF.Finish;
                     BF.Free;
                  end;
               end;
               PktColl.Leave;
            end;
         end;
      until not uFindNext(SR);
      RE.Unlock;
      uFindClose(SR);
   end;
end;

procedure TNetmail.ScanPacket;
var
   n: TMemoryStream;
   h: PktHeaderRec;
   m: PackedMsgHeaderRec;
   b: byte;
   l: TNetmailMsg;
   c: integer;
   i: integer;
   j: integer;
   p: pbytearray;
   u: string;
   t: string;
   z: string;
   a,
   e: integer;
   s: int64;

   procedure SetValue(var a: integer; const b: integer);
   begin
      if a = 0 then begin
         a := b;
      end;
   end;

begin
   if not ExistFile(pack) then exit;
   NetColl.Enter;
   n := TMemoryStream.Create;
   if n <> nil then begin
      try
         n.LoadFromFile(pack);
      except
         n.Free;
         NetColl.Leave;
         exit;
      end;
      if n.Size > SizeOf(h) then begin
      u := #1'Via ' + Addr2Str(inifile.MainAddr) + ' Trapgate ' + CProductVersionA + '/W32 ' + RFCDateStr + #13#0;
      s := n.Size + 80;
      GetMem(p, s);
      n.Read(h, sizeof(h));
      while n.Position < n.Size - sizeof(m) + 3 do begin
         l := TNetmailMsg.Create;
         l.Offs := n.Position;
         n.Read(m, sizeof(m));
         l.Head := m;
         c := 0;
         i := 0;
         a := 0;
         e := 0;
         repeat
            t := '';
            repeat
               n.Read(b, 1);
               p[i] := b;
               inc(i);
               if b = 1 then t := '';
               t := t + chr(b);
               if b = 13 then begin
                  if copy(t, 2, 5) = 'TOPT ' then begin
                     a := StrToInt(ExtractWord(1, ExtractWord(2, t, [' ']), [#13]));
                  end else
                  if copy(t, 2, 5) = 'FMPT ' then begin
                     e := StrToInt(ExtractWord(1, ExtractWord(2, t, [' ']), [#13]));
                  end else
                  if copy(t, 2, 5) = 'INTL ' then begin
                     ParseAddress(ExtractWord(1, ExtractWord(2, t, [' ']), [#13]), l.Addr);
                     ParseAddress(ExtractWord(1, ExtractWord(3, t, [' ']), [#13]), l.From);
                  end else
                  if copy(t, 3, 5) = 'SGID:' then begin
                     GetWrd(t, z, ' ');
                     GetWrd(t, z, #13);
                     for j := 1 to Length(z) do begin
                        if z[j] = ' ' then z[j] := '.';
                     end;
                     l.MsId := z;
                  end else
                  if copy(t, 2, 5) = 'CHRS:' then begin
                     GetWrd(t, z, ' ');
                     GetWrd(t, z, #13);
                     l.Chrs := z;
                  end;
               end;
            until (b = 0) or (i >= s);
            if c = 0 then begin
               l.Tonm := copy(t, 1, Length(t) - 1);
            end else
            if c = 1 then begin
               l.Frnm := copy(t, 1, Length(t) - 1);
            end else
            if c = 2 then begin
               l.Subj := copy(t, 1, Length(t) - 1);
               l.bOff := n.Position;
            end;
            inc(c);
         until (c = 4) or (i >= s);
         if pos('Via ' + Addr2Str(inifile.MainAddr) + ' Trapgate ', t) = 0 then begin
            move(u[1], p[i - 1], length(u));
            i := i + length(u) - 1;
            l.Addy := length(u) - 1;
         end;
         SetValue(l.From.Zone, h.OrigZone);
         SetValue(l.From.Net, m.OrigNet);
         SetValue(l.From.Node, m.OrigNode);
         SetValue(l.From.Point, e);
         l.From.Domain := FindFTNDOM(l.From);
         SetValue(l.Addr.Zone, h.DestZone);
         SetValue(l.Addr.Net, m.DestNet);
         SetValue(l.Addr.Node, m.DestNode);
         SetValue(l.Addr.Point, a);
         l.Addr.Domain := FindFTNDOM(l.Addr);
         l.Lock.Zone   := h.DestZone;
         l.Lock.Net    := h.DestNet;
         l.Lock.Node   := h.DestNode;
         l.Lock.Point  := h.DestPoint;
         l.Lock.Domain := FindFTNDOM(l.Lock);
         l.Pack        := pack;
         l.Size        := i;
         GetMem(l.Body, l.Size);
         move(p^, l.Body^, l.Size);
         NetColl.Add(l);
         Application.ProcessMessages;
      end;
      FreeMem(p, s);
      end;
      n.Free;
   end;
   NetColl.Leave;
end;

procedure TNetmail.MoveMail(n: TNetmailMsg; const t: TFidoAddress; const a: string);
var
   s: string;
   w: string;
   i: TFileStream;
   h: PktHeaderRec;
   b: byte;
begin
   s := GetOutFileName(t, osNone);
   if pos(UpperCase(s), UpperCase(n.Pack)) > 0 then exit;
   MsgColl.Add('Routing ' + Addr2Str(n.From) + ' -> ' + Addr2Str(n.Addr) + ' via ' + Addr2Str(t));
   s := s + '.cut';
   b := 0;
   if not ExistFile(s) then begin
      fillchar(h, sizeof(h), 0);
      h.OrigNode  := inifile.MainAddr.Node;
      h.DestNode  := t.Node;
      h.Year      := CurrentYear;
      h.Month     := MonthOf(Date);
      h.Day       := DayOf(Date);
      h.Hour      := HourOf(Time);
      h.Minute    := MinuteOf(Time);
      h.Second    := SecondOf(Time);
      h.Baud      := 300;
      h.PktType   := 2;
      h.OrigNet   := inifile.MainAddr.Net;
      h.DestNet   := t.Net;
      h.ProdCode  := $FF;
      h.SerialNo  := $FF;
      h.OrigZone  := inifile.MainAddr.Zone;
      h.DestZone  := t.Zone;
      h.OrigPoint := inifile.MainAddr.Point;
      h.DestPoint := t.Point;
      w           := UpperCase(a);
      move(w[1], h.Password, length(a));
      i := TFileStream.Create(s, fmCreate);
      i.Write(h, sizeof(h));
      i.Write(b, 1);
      i.Write(b, 1);
      i.Free;
   end;
   try
      i := TFileStream.Create(s, fmOpenWrite);
   except
      MsgColl.Add('Failed to open ' + s);
      exit;
   end;
   i.Seek(-2, soFromEnd);
   i.Write(n.Head, sizeof(n.Head));
   i.Write(n.Body^, n.Size);
   i.Write(b, 1);
   i.Write(b, 1);
   i.Free;
   DelMail(n);
end;

procedure TNetmail.PackMail;
var i: integer;
    m: TNetmailMsg;

begin
   NetColl.Enter;
   for i := 0 to CollMax(NetColl) do begin
      m := NetColl[i];
      if MatchMaskAddress(m.Addr, r) and not MatchMaskAddressListSingle(m.Addr, e) then begin
         MoveMail(m, a, p);
      end;
   end;
   for i := CollMax(NetColl) downto 0 do begin
      m := NetColl[i];
      if (m.Body = nil) or not FileExists(m.Pack) then begin
         NetColl.AtFree(i);
      end;
   end;
   NetColl.Leave;
end;

procedure TNetmail.Route;
var i: integer;
    o: string;
    s: string;
    t: string;
    p: string;
    e: string;
    b: string;
    n: integer;
begin
  EnterCS(NetWait);
  if IniFile.DynamicRouting then
  if FidoOut.Lock(a, osBusy, True) then begin
     for i := 0 to IniFile.NetmailAddrTo.Count - 1 do
     begin
        o := IniFile.NetmailAddrTo[i];
        if MatchMaskAddress(a, o) then
        begin
           s := IniFile.NetmailAddrFrom[i];
           e := '';
           repeat
              GetWrd(s, t, ' ');
              if (t <> '') and (t[1] = '!') then begin
                 Delete(t, 1, 1);
                 e := e + ' ' + t;
              end;
           until s = '';
           b := '';
           s := IniFile.NetmailAddrFrom[i];
           for n := 1 to WordCount(s, [' ']) do begin
              t := ExtractWord(n, s, [' ']);
              if t[1] <> '!' then b := b + ' ' + t;
           end;
           s := b;
           p := IniFile.NetmailPwd[i];
           repeat
              GetWrd(s, t, ' ');
              if (o = t) then begin
                 PackMail(a, Addr2Str(a), '', p);
              end else begin
                 PackMail(a, t, e, p);
              end;
              while MsgColl.Count > 0 do begin
                 Log(ltInfo, MsgColl[0]);
                 MsgColl.AtFree(0);
              end;
           until s = '';
           break;
        end;
     end;
     FidoOut.Unlock(a, osBusy);
  end;
  LeaveCS(NetWait);
end;

procedure TNetmail.DeleteMail;
var
   i: integer;
   m: TNetmailMsg;
begin
  EnterCS(NetWait);
  for i := 0 to CollMax(NetColl) do begin
     m := NetColl[i];
     if m.MsId = Id then begin
        DelMail(m);
     end;
  end;
  LeaveCS(NetWait);
end;

procedure TNetmail.DelMail;
var
   i: TFileStream;
   z: int64;
   p: pointer;
   g: integer;
   e: TNetmailMsg;
begin
   NetColl.Enter;
   FreeMem(n.Body, n.Size);
   n.Body := nil;
   if ExistFile(n.Pack) then begin
      try
         FidoOut.Lock(n.Lock, osBusy, True);
         i := TFileStream.Create(n.Pack, fmOpenReadWrite);
         i.Seek(n.Offs + sizeof(n.Head) + n.Size - n.Addy, soFromBeginning);
         z := i.Size - i.Position;
         GetMem(p,  z);
         i.Read(p^, z);
         i.Seek(n.Offs, soFromBeginning);
         i.Write(p^, z);
         FreeMem(p,  z);
         SetEndOfFile(i.Handle);
         z := i.Size;
         i.Free;
         if z = 60 then begin
            DeleteFile(n.Pack);
         end;
      finally
         FidoOut.Unlock(n.Lock, osBusy);
      end;
      for g := 0 to CollMax(NetColl) do begin
         e := NetColl[g];
         if (e.Pack = n.Pack) and (e <> n) and (e.Offs > n.Offs) then begin
            e.Offs := e.Offs - sizeof(n.Head) - n.Size + n.Addy;
         end;
      end;
   end else begin
      for g := 0 to CollMax(NetColl) do begin
         e := NetColl[g];
         if (e.Pack = n.Pack) then begin
            FreeMem(e.Body, e.Size);
            e.Body := nil;
            FillChar(e.Addr, sizeof(e.Addr), 0);
         end;
      end;
   end;
   FillChar(n.Addr, sizeof(n.Addr), 0);
   NetColl.Leave;
end;

function TNetmail.FindMessage;
var
   i: integer;
   m: TNetmailMsg;
begin
   NetColl.Enter;
   Result := nil;
   for i := 0 to CollMax(NetColl) do begin
      m := NetColl[i];
      if m.MsId = Id then begin
         Result := m;
         break;
      end;
   end;
   NetColl.Leave;
end;

initialization

NetmailHolder := nil;

end.
