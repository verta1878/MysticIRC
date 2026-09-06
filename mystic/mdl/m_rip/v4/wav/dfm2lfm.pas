{ This file is part of FPC 2.6.4irc.
  Copyright (C) 2026 fpc264irc contributors.

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program. If not, see <https://www.gnu.org/licenses/>.
}
{ DFM to LFM Converter — Standalone command-line tool
  Converts Delphi .dfm files to Lazarus .lfm format.
  Handles both binary and text DFM formats.

  Usage:
    dfm2lfm input.dfm [output.lfm]
    dfm2lfm *.dfm                    (batch convert)

  Uses FPC RTL ObjectBinaryToText for binary DFM parsing.
  Text DFM is nearly identical to LFM — just needs class name
  mapping for Delphi-specific components.
}
program dfm2lfm;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils;

type
  TClassMap = record
    Delphi: string;
    LCL: string;
  end;

const
  { Delphi → LCL class name mappings }
  ClassMapCount = 15;
  ClassMap: array[0..ClassMapCount-1] of TClassMap = (
    (Delphi: 'TForm';           LCL: 'TForm'),
    (Delphi: 'TButton';         LCL: 'TButton'),
    (Delphi: 'TLabel';          LCL: 'TLabel'),
    (Delphi: 'TEdit';           LCL: 'TEdit'),
    (Delphi: 'TMemo';           LCL: 'TMemo'),
    (Delphi: 'TPanel';          LCL: 'TPanel'),
    (Delphi: 'TCheckBox';       LCL: 'TCheckBox'),
    (Delphi: 'TRadioButton';    LCL: 'TRadioButton'),
    (Delphi: 'TComboBox';       LCL: 'TComboBox'),
    (Delphi: 'TListBox';        LCL: 'TListBox'),
    (Delphi: 'TProgressBar';    LCL: 'TProgressBar'),
    (Delphi: 'TStatusBar';      LCL: 'TStatusBar'),
    (Delphi: 'TToolBar';        LCL: 'TToolBar'),
    (Delphi: 'TImage';          LCL: 'TImage'),
    (Delphi: 'TBevel';          LCL: 'TBevel')
  );

  { Properties to remove (Delphi-only, no LCL equivalent) }
  RemoveProps: array[0..7] of string = (
    'Ctl3D',
    'ParentCtl3D',
    'OldCreateOrder',
    'DesignSize',
    'TextHeight',
    'PixelsPerInch',
    'ExplicitWidth',
    'ExplicitHeight'
  );

function IsBinaryDFM(const FileName: string): Boolean;
var
  F: TFileStream;
  Magic: Byte;
begin
  Result := False;
  F := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
  try
    if F.Size > 0 then
    begin
      F.Read(Magic, 1);
      Result := (Magic = $FF); // TPF0 binary marker
    end;
  finally
    F.Free;
  end;
end;

function BinaryDFMToText(const FileName: string): string;
var
  InStream, OutStream: TMemoryStream;
begin
  InStream := TMemoryStream.Create;
  OutStream := TMemoryStream.Create;
  try
    InStream.LoadFromFile(FileName);
    InStream.Position := 0;
    ObjectBinaryToText(InStream, OutStream);
    OutStream.Position := 0;
    SetLength(Result, OutStream.Size);
    OutStream.Read(Result[1], OutStream.Size);
  finally
    InStream.Free;
    OutStream.Free;
  end;
end;

function ShouldRemoveProp(const Line: string): Boolean;
var
  I: Integer;
  Trimmed: string;
begin
  Result := False;
  Trimmed := Trim(Line);
  for I := Low(RemoveProps) to High(RemoveProps) do
    if (Pos(RemoveProps[I] + ' ', Trimmed) = 1) or
       (Pos(RemoveProps[I] + '=', Trimmed) = 1) then
    begin
      Result := True;
      Exit;
    end;
end;

function MapClassName(const Name: string): string;
var
  I: Integer;
begin
  Result := Name;
  for I := 0 to ClassMapCount - 1 do
    if CompareText(Name, ClassMap[I].Delphi) = 0 then
    begin
      Result := ClassMap[I].LCL;
      Exit;
    end;
end;

procedure ConvertTextDFMToLFM(const DFMText: string; Out LFMText: string);
var
  Lines: TStringList;
  I: Integer;
  Line, Trimmed: string;
  ColonPos: Integer;
  ClassName: string;
begin
  Lines := TStringList.Create;
  try
    Lines.Text := DFMText;

    I := 0;
    while I < Lines.Count do
    begin
      Line := Lines[I];
      Trimmed := Trim(Line);

      // Remove Delphi-only properties
      if ShouldRemoveProp(Trimmed) then
      begin
        Lines.Delete(I);
        Continue;
      end;

      // Map class names in 'object Name: TClassName' lines
      if (Pos('object ', Trimmed) = 1) or (Pos('inherited ', Trimmed) = 1) then
      begin
        ColonPos := Pos(':', Line);
        if ColonPos > 0 then
        begin
          ClassName := Trim(Copy(Line, ColonPos + 1, Length(Line)));
          ClassName := MapClassName(ClassName);
          Line := Copy(Line, 1, ColonPos) + ' ' + ClassName;
          Lines[I] := Line;
        end;
      end;

      Inc(I);
    end;

    LFMText := Lines.Text;
  finally
    Lines.Free;
  end;
end;

procedure ConvertFile(const InFile, OutFile: string);
var
  DFMText, LFMText: string;
  F: TFileStream;
begin
  Write('Converting: ', InFile, ' -> ', OutFile, ' ... ');

  // Read DFM (binary or text)
  if IsBinaryDFM(InFile) then
    DFMText := BinaryDFMToText(InFile)
  else
  begin
    with TStringList.Create do
    try
      LoadFromFile(InFile);
      DFMText := Text;
    finally
      Free;
    end;
  end;

  // Convert
  ConvertTextDFMToLFM(DFMText, LFMText);

  // Write LFM
  F := TFileStream.Create(OutFile, fmCreate);
  try
    F.Write(LFMText[1], Length(LFMText));
  finally
    F.Free;
  end;

  WriteLn('OK');
end;

var
  I: Integer;
  InFile, OutFile: string;
begin
  if ParamCount = 0 then
  begin
    WriteLn('dfm2lfm — Delphi DFM to Lazarus LFM converter');
    WriteLn('Part of FPC 2.6.4irc');
    WriteLn;
    WriteLn('Usage: dfm2lfm input.dfm [output.lfm]');
    WriteLn('       dfm2lfm file1.dfm file2.dfm ...');
    Halt(1);
  end;

  if (ParamCount = 2) and not FileExists(ParamStr(2)) then
  begin
    // Single file with explicit output
    ConvertFile(ParamStr(1), ParamStr(2));
  end
  else
  begin
    // Batch mode
    for I := 1 to ParamCount do
    begin
      InFile := ParamStr(I);
      if not FileExists(InFile) then
      begin
        WriteLn('File not found: ', InFile);
        Continue;
      end;
      OutFile := ChangeFileExt(InFile, '.lfm');
      ConvertFile(InFile, OutFile);
    end;
  end;
end.
