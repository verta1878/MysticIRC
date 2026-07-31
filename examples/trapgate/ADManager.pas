unit ADManager;

interface

{ For external use, core call is default for Trapgate }

Function GetMac: String;
function  ADM(Path : String): Boolean;
Procedure MacInit(Path: String);
Function Core: Boolean;
Function Gethome(Ftc: String): String;
Procedure Initreg(Go: Boolean);
Function getkeyinfo: string;
Function Braindead: Boolean;
Function echo(ADP_IP: string): Boolean;

implementation

uses  FastShareMem,
           Windows,
          SysUtils,
           Classes,
           Dialogs,
  ethernet_address,
              UStr,
             xBase,
          Executer,
           RasThrd,
              Recs,
          OutBound,
           OdbcLog,
            Wizard,
          CfgFiles,
              Plus,
             Crypt,
             xTAPI,
             xMisc,
         PJSysInfo,
          raw_ping,
           Wcrypt2,
            RadIni;

Const
      ReleaseSpecs = 'Version 2.00 Beta 1';

function MD5(Value: string): string;
var
  hCryptProvider: HCRYPTPROV;
  hHash: HCRYPTHASH;
  bHash: array[0..$7F] of Byte;
  dwHashLen: dWord;
  i: Integer;
begin
  dwHashLen := 16;
  if (Value = '') then
  begin
    Result := 'd41d8cd98f00b204e9800998ecf8427e';
    exit;
  end
  else
    Result := '';

  {get context for crypt default provider}
  if CryptAcquireContext(@hCryptProvider, nil, nil, PROV_RSA_FULL, CRYPT_VERIFYCONTEXT or CRYPT_MACHINE_KEYSET) then
  begin
    {create hash-object MD5}
    if CryptCreateHash(hCryptProvider, CALG_MD5, 0, 0, @hHash) then
    begin
      {get hash from password}
      if CryptHashData(hHash, @Value[1], Length(Value), 0) then
      begin
        if CryptGetHashParam(hHash, HP_HASHVAL, @bHash[0], @dwHashLen, 0) then
        begin
          for i := 0 to dwHashLen-1 do
            Result := Result + IntToHex(bHash[i], 2);
        end;
      end;
      {destroy hash-object}
      CryptDestroyHash(hHash);
    end;
    {release the context for crypt default provider}
    CryptReleaseContext(hCryptProvider, 0);
  end;
  Result := AnsiLowerCase(Result);
end;

Procedure Initreg(Go: Boolean);

{ Initialize registration module }

Var
  TgMake,
  Resultex: String;

Begin
      {$IFDEF REGISTER}
      If Go then begin
      TgMake:= ExtractFileDir(Paramstr(0)) + '\Registration.exe';
      if (FileExists(TgMake)) then begin
      Resultex :='' { Reset };
      Resultex := DeCom(TgMake,'BLUEFIRE');
     End;
 end;
 {$ENDIF}
end;

Function echo(ADP_IP: string): Boolean;

begin
 if Ping(ADP_IP) then echo := True
 else echo := False;
end;

Function Gethome(Ftc: String): String;

Begin
  If Ftc = '' Then GetHome := PChar(MakeNormName(JustPathname(paramstr(0)), ''));
  If Ftc <> '' then GetHome := PChar(MakeNormName(JustPathname(paramstr(0)), 'trapgate.exe'));
end;

Function Getstatus: String;

Begin

End;

Function GetMac: String;

var

oSL     : TStringlist;
sBuffer : String;

begin
oSL     := Get_EthernetAddresses;
sBuffer := Stringreplace(oSL.Text,Char(13)+Char(10),',',[rfReplaceAll]);
GetMac  := sBuffer + 'Trapgate';

oSL.Free;

End;

function GetFullFileVersion: string;
var
  j, w: Cardinal;
  s: shortstring;
  buf: pointer;
  buf2: pointer;
  q: DWORD;
  vsinfo: ^VS_FIXEDFILEINFO;
  mVer,
  lVer,
  rVer,
  bVer,
  flag: DWORD;
begin
  s := ParamStr(0) + #0;
  j := GetFileVersionInfoSize(@s[1], w);
  if j = 0 then
    Exit;
  buf := Ptr(GlobalAlloc(GMEM_FIXED, j));
  GetFileVersionInfo(@s[1], 0, j, buf);
  VerQueryValue(buf, '\', buf2, q);
  vsinfo := buf2;
  mVer := vsInfo^.dwProductVersionMS div $FFFF;
  lVer := vsInfo^.dwProductVersionMS mod $10000;
  rVer := vsInfo^.dwProductVersionLS div $FFFF;
  bVer := vsInfo^.dwProductVersionLS mod $10000;
  flag := vsInfo^.dwFileFlags;
  s := IntToStr(mVer) + '.' +
    IntToStr(lVer) + '.' +
    IntToStr(rVer) + '.' +
    IntToStr(bVer);
  if (flag and VS_FF_DEBUG) > 0 then
    s := s + '/Debug';
  if (flag and VS_FF_PRERELEASE) > 0 then
    s := s + '/PreRelease';
  if (flag and VS_FF_PRIVATEBUILD) > 0 then
    s := s + '/Private';
  if (flag and VS_FF_SPECIALBUILD) > 0 then
    s := s + '/Special';
  Result := s;
  GlobalFree(Cardinal(buf));
end;

Function getkeyinfo: string;    // Snap in for other units

Var
   Path: String;
   f      : TextFile;
   buffer : string;

Begin
{$IFDEF REGISTER}
Path := Gethome('');
If (FileExists(Path +'Trapgate.key')) then begin
AssignFile(f, Path +'Trapgate.key');
Reset(f) ;
ReadLn(f, buffer) ;
getkeyinfo := DecodeB64(buffer);
CloseFile(f) ;
End;
{$ENDIF}
End;

Procedure MakeMD5;

Var
      Path : String;
   runfile : String;
        MD : String;

Begin
path := Gethome('');
runfile := path + 'Trapgate.md5';
MD := MD5(ReleaseSpecs);
with TStringList.Create do
 try
  Add(MD);
  SaveToFile(runfile);
 finally
  Free;
 end;
end;

Procedure MacInit(Path: String);

Var
    Mac: String;
   EMac: String;
    Ftc: String;

Begin
if path = '' then path := Gethome('');
Mac := GetMac;
Ftc := Gethome('trapgatehomecheck');
EMac := EncodeB64(Mac + GetFullFileVersion + Ftc + TPJOSInfo.ProductID + TPJComputerInfo.ProcessorName);
with TStringList.Create do
 try
  Add(EMac);
  SaveToFile(path + 'Trapgate.run');
 finally
  Free;
 end;
end;

function  ADM(Path : String): Boolean;

 var
   I       : Integer;
   TgMD    : Boolean;
   Changed : Boolean;
   BrandX  : Boolean;
   Runnow  : Boolean;
   f       : TextFile;
   RunFile : string;
   MD      : string;
   Regname : string;
   buffer  : string;
   Ftc2    : string;

begin
   if path = '' then path := Gethome('');
   Ftc2 := Gethome('trapgatehomecheck');

   BrandX  := False;
   Changed := True;
   Runnow  := False;
   ADM     := True;

   If FileExists(Path + 'Trapgate.run') then BrandX := True;

   If NOT BrandX then begin
   {$IFDEF REGISTER}
   If (FileExists(Path +'Trapgate.key')) then Initreg(False)
   else Initreg(True);
   {$ENDIF}
   MacInit(''); { First run }
   BrandX := True;
   End;

   If BrandX then begin
   TgMD := False;  // Assume not found
   for i := 1 to ParamCount do begin
   if LowerCase(ParamStr(i)) = '7855brzl' then makeMD5;
   end;

   MD := MD5(ReleaseSpecs);  // Get MD5 from ReleaseSpecs
   If (FileExists(Path +'Trapgate.md5')) then TgMD := True;        // Overide we did found the MD5 file

   If NOT TgMD then Begin
   Showmessage('Fatal error ' + Path +'Trapgate.md5 NOT found, Trapgate will not RUN - HALT!');
   Halt(10);
   end;

   If TgMD then begin
   AssignFile(f, Path +'Trapgate.md5');
   Reset(f) ;
   ReadLn(f, buffer) ;
   If buffer = MD then changed := False;
   CloseFile(f) ;
   end;

   If changed then begin
   Showmessage('Fatal error ' + Path +'Trapgate.md5, you using another version, re-install a new version might solve this problem, Trapgate will not RUN - HALT!');
   Halt(10);
   end;

   If NOT changed then begin
   AssignFile(f, Path +'Trapgate.run');
   Reset(f) ;
   ReadLn(f, buffer) ;
   If DecodeB64(buffer) = GetMac + GetFullFileVersion + Ftc2 + TPJOSInfo.ProductID + TPJComputerInfo.ProcessorName then Runnow := True;
   CloseFile(f) ;
   End;

   {$IFDEF REGISTER}
   If BrandX and (FileExists(Path +'Trapgate.key')) then begin
   AssignFile(f, Path +'Trapgate.key');
   Reset(f) ;
   ReadLn(f, buffer) ;
   RegName := DecodeB64(buffer);
   CloseFile(f) ;
   End;
   {$ENDIF}

   If NOT Runnow then Begin
   ShowMessageFmt('%s', ['Hardware and/or Software Configuration changed, for Computer ' + TPJComputerInfo.ComputerName + ', if you see this error again contact dsgrid@ziggo.nl']);
   if FileExists(Path + 'Trapgate.run') then DeleteFile(Path +'Trapgate.run');
   ADM := False;
   end;
 end;
end;

Function Braindead: Boolean;

Begin
  Braindead := True;
  ApplicationDone := True;
End;

Function Core: Boolean;

Begin { Check for Trapgate.run, If found check data }
 If ADM('') then Core := True
 Else Core := False;
 End { return to loader };
end.












