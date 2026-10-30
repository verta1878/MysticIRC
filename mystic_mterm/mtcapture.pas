{ This file is part of mterm — Mystic Terminal.
  Copyright (C) 2026 FPC264IRC Contributors.
  License: GNU General Public License v3.0.
  Credits: verta1878, sysop/0, evga, kiddo, wrench. }
{$MODE OBJFPC}
{$H+}
unit mtcapture;
{ Session capture — log received data to file.
  Toggle on/off, append mode, error-safe, flush on write.
  Matches RIPterm v1.54 capture toggle (CAPTURE.C).
  v1.1: byte count, pause mode, filename validation. }

interface

type
  TCapture = class
  private
    FFile: Text;
    FActive: Boolean;
    FPaused: Boolean;
    FFileName: String;
    FByteCount: Int64;
    function ValidateFileName(const AName: String): Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Start(const AFileName: String);
    procedure Stop;
    procedure Toggle(const AFileName: String);
    procedure Pause;
    procedure Resume;
    procedure TogglePause;
    procedure WriteByte(B: Byte);
    procedure WriteStr(const S: String);
    procedure WriteBuf(const Buf; Len: Integer);
    property Active: Boolean read FActive;
    property Paused: Boolean read FPaused;
    property FileName: String read FFileName;
    property ByteCount: Int64 read FByteCount;
  end;

implementation

uses SysUtils;

const
  { Characters not allowed in capture filenames.
    Matches RIPterm's validation — no path separators,
    no shell metacharacters, no control chars. }
  InvalidChars = ['/', '\', ':', '*', '?', '"', '<', '>', '|',
                  #0..#31];

constructor TCapture.Create;
begin
  inherited;
  FActive := False;
  FPaused := False;
  FFileName := '';
  FByteCount := 0;
end;

destructor TCapture.Destroy;
begin
  if FActive then Stop;
  inherited;
end;

function TCapture.ValidateFileName(const AName: String): Boolean;
var
  I: Integer;
begin
  Result := False;
  if (Length(AName) = 0) or (Length(AName) > 255) then Exit;
  for I := 1 to Length(AName) do
    if AName[I] in InvalidChars then Exit;
  { reject pure dots (., ..) }
  if (AName = '.') or (AName = '..') then Exit;
  Result := True;
end;

procedure TCapture.Start(const AFileName: String);
begin
  if FActive then Stop;
  if not ValidateFileName(ExtractFileName(AFileName)) then Exit;
  FFileName := AFileName;
  Assign(FFile, FFileName);
  if FileExists(FFileName) then
    {$I-} System.Append(FFile) {$I+}
  else
    {$I-} Rewrite(FFile) {$I+};
  if IOResult = 0 then begin
    FActive := True;
    FPaused := False;
    FByteCount := 0;
  end else begin
    FActive := False;
    FPaused := False;
    FFileName := '';
    FByteCount := 0;
  end;
end;

procedure TCapture.Stop;
begin
  if FActive then begin
    {$I-} Close(FFile); {$I+}
    if IOResult <> 0 then ; { ignore }
    FActive := False;
    FPaused := False;
  end;
end;

procedure TCapture.Toggle(const AFileName: String);
begin
  if FActive then Stop else Start(AFileName);
end;

procedure TCapture.Pause;
begin
  if FActive and (not FPaused) then
    FPaused := True;
end;

procedure TCapture.Resume;
begin
  if FActive and FPaused then
    FPaused := False;
end;

procedure TCapture.TogglePause;
begin
  if not FActive then Exit;
  FPaused := not FPaused;
end;

procedure TCapture.WriteByte(B: Byte);
begin
  if (not FActive) or FPaused then Exit;
  {$I-} Write(FFile, Chr(B)); {$I+}
  if IOResult <> 0 then Stop
  else Inc(FByteCount);
end;

procedure TCapture.WriteStr(const S: String);
var I: Integer;
begin
  if (not FActive) or FPaused then Exit;
  for I := 1 to Length(S) do begin
    {$I-} Write(FFile, S[I]); {$I+}
    if IOResult <> 0 then begin Stop; Exit; end;
    Inc(FByteCount);
  end;
  {$I-} System.Flush(FFile); {$I+}
  if IOResult <> 0 then Stop;
end;

procedure TCapture.WriteBuf(const Buf; Len: Integer);
var
  P: PByte;
  I: Integer;
begin
  if (not FActive) or FPaused then Exit;
  P := @Buf;
  for I := 0 to Len - 1 do begin
    {$I-} Write(FFile, Chr(P[I])); {$I+}
    if IOResult <> 0 then begin Stop; Exit; end;
    Inc(FByteCount);
  end;
  {$I-} System.Flush(FFile); {$I+}
  if IOResult <> 0 then Stop;
end;

end.
