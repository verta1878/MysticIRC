{ This file is part of mterm — Mystic Terminal.
  Copyright (C) 2026 FPC264IRC Contributors.
  License: GNU General Public License v3.0.
  Credits: verta1878, sysop/0, evga, kiddo, wrench. }
{$MODE OBJFPC}
{$H+}
unit mtcapture;
{ Session capture — log received data to file.
  Toggle on/off, append mode, error-safe, flush on write.
  Matches RIPterm v1.54 capture toggle (CAPTURE.C). }

interface

type
  TCapture = class
  private
    FFile: Text;
    FActive: Boolean;
    FFileName: String;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Start(const AFileName: String);
    procedure Stop;
    procedure Toggle(const AFileName: String);
    procedure WriteByte(B: Byte);
    procedure WriteStr(const S: String);
    procedure WriteBuf(const Buf; Len: Integer);
    property Active: Boolean read FActive;
    property FileName: String read FFileName;
  end;

implementation

uses SysUtils;

constructor TCapture.Create;
begin
  inherited;
  FActive := False;
  FFileName := '';
end;

destructor TCapture.Destroy;
begin
  if FActive then Stop;
  inherited;
end;

procedure TCapture.Start(const AFileName: String);
begin
  if FActive then Stop;
  FFileName := AFileName;
  Assign(FFile, FFileName);
  if FileExists(FFileName) then
    {$I-} System.Append(FFile) {$I+}
  else
    {$I-} Rewrite(FFile) {$I+};
  if IOResult = 0 then
    FActive := True
  else begin
    FActive := False;
    FFileName := '';
  end;
end;

procedure TCapture.Stop;
begin
  if FActive then begin
    {$I-} Close(FFile); {$I+}
    if IOResult <> 0 then ; { ignore }
    FActive := False;
  end;
end;

procedure TCapture.Toggle(const AFileName: String);
begin
  if FActive then Stop else Start(AFileName);
end;

procedure TCapture.WriteByte(B: Byte);
begin
  if not FActive then Exit;
  {$I-} Write(FFile, Chr(B)); {$I+}
  if IOResult <> 0 then Stop;
end;

procedure TCapture.WriteStr(const S: String);
var I: Integer;
begin
  if not FActive then Exit;
  for I := 1 to Length(S) do begin
    {$I-} Write(FFile, S[I]); {$I+}
    if IOResult <> 0 then begin Stop; Exit; end;
  end;
  {$I-} System.Flush(FFile); {$I+}
  if IOResult <> 0 then Stop;
end;

procedure TCapture.WriteBuf(const Buf; Len: Integer);
var
  P: PByte;
  I: Integer;
begin
  if not FActive then Exit;
  P := @Buf;
  for I := 0 to Len - 1 do begin
    {$I-} Write(FFile, Chr(P[I])); {$I+}
    if IOResult <> 0 then begin Stop; Exit; end;
  end;
  {$I-} System.Flush(FFile); {$I+}
  if IOResult <> 0 then Stop;
end;

end.
