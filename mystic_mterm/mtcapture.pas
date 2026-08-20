{ This file is part of mterm — Mystic Terminal.
  Copyright (C) 2026 FPC264IRC Contributors.
  License: GNU General Public License v3.0.
  Credits: verta1878, sysop/0, evga, kiddo, wrench. }
{$MODE OBJFPC}
{$H+}
unit mtcapture;
{ Session capture — log to file }

interface

type
  TCapture = class
  private
    FFile: File;
    FActive: Boolean;
    FFileName: String;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Start(const AFileName: String);
    procedure Stop;
    procedure WriteByte(B: Byte);
    procedure WriteStr(const S: String);
    property Active: Boolean read FActive;
    property FileName: String read FFileName;
  end;

implementation

uses SysUtils;

constructor TCapture.Create;
begin
  inherited;
  FActive := False;
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
  Rewrite(FFile, 1);
  FActive := True;
end;

procedure TCapture.Stop;
begin
  if FActive then begin
    Close(FFile);
    FActive := False;
  end;
end;

procedure TCapture.WriteByte(B: Byte);
begin
  if FActive then
    BlockWrite(FFile, B, 1);
end;

procedure TCapture.WriteStr(const S: String);
begin
  if FActive and (Length(S) > 0) then
    BlockWrite(FFile, S[1], Length(S));
end;

end.
