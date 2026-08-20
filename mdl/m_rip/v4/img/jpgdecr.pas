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
{ JPEG Decoder — Raw File I/O version (short string mode compatible)
  No Classes unit, no TStream. Uses BlockRead/BlockWrite.
  Wraps pasjpeg with a memory-buffer source manager.

  Usage:
    var Pixels: PByte; W, H: Integer;
    begin
      if JPEGLoadFileRaw('photo.jpg', Pixels, W, H) then
      begin
        // Pixels = W*H*3 bytes RGB
        FreeMem(Pixels);
      end;
    end;
}
unit jpgdecr;

{$H-}
{$mode objfpc}

interface

{ Load JPEG from file — raw file I/O, no Classes unit }
function JPEGLoadFileRaw(const FileName: string;
  out Pixels: PByte; out Width, Height: Integer): Boolean;

{ Load JPEG from memory buffer }
function JPEGLoadMemRaw(InBuf: PByte; InSize: LongWord;
  out Pixels: PByte; out Width, Height: Integer): Boolean;

{ Detect if file is JPEG (checks FF D8 signature) }
function IsJPEGFile(const FileName: string): Boolean;

type
  TJPEGStreamRaw = record
    Buffer: PByte;
    BufSize: LongWord;
    BufCap: LongWord;
    Pixels: PByte;        // latest decoded image (RGB, W*H*3)
    Width: Integer;
    Height: Integer;
    HasImage: Boolean;
    Complete: Boolean;
    ScanCount: Integer;
  end;

{ Server-side JPEG streaming — feed chunks, render partial }
procedure JPEGStreamInitRaw(out Strm: TJPEGStreamRaw);
function JPEGStreamFeedRaw(var Strm: TJPEGStreamRaw;
  Data: PByte; Size: LongWord): Boolean;
procedure JPEGStreamFreeRaw(var Strm: TJPEGStreamRaw);

implementation

uses
  jmorecfg, jpeglib, jerror, jdeferr, jdapimin, jdapistd,
  jdatasrc, jdmarker, jdmaster;

type
  PMemSrc = ^TMemSrc;
  TMemSrc = record
    pub: jpeg_source_mgr;
    buffer: PByte;
    bufsize: LongWord;
    started: Boolean;
  end;

procedure mem_init(cinfo: j_decompress_ptr); far;
begin
  PMemSrc(cinfo^.src)^.started := True;
end;

function mem_fill(cinfo: j_decompress_ptr): Boolean; far;
var
  src: PMemSrc;
begin
  src := PMemSrc(cinfo^.src);
  if src^.started then
  begin
    src^.pub.next_input_byte := src^.buffer;
    src^.pub.bytes_in_buffer := src^.bufsize;
    src^.started := False;
  end
  else
    src^.pub.bytes_in_buffer := 0;
  Result := True;
end;

procedure mem_skip(cinfo: j_decompress_ptr; num_bytes: LongInt); far;
var
  src: PMemSrc;
begin
  src := PMemSrc(cinfo^.src);
  if num_bytes > 0 then
  begin
    while num_bytes > LongInt(src^.pub.bytes_in_buffer) do
    begin
      Dec(num_bytes, src^.pub.bytes_in_buffer);
      mem_fill(cinfo);
    end;
    Inc(src^.pub.next_input_byte, num_bytes);
    Dec(src^.pub.bytes_in_buffer, num_bytes);
  end;
end;

procedure mem_term(cinfo: j_decompress_ptr); far;
begin
end;

function JPEGLoadMemRaw(InBuf: PByte; InSize: LongWord;
  out Pixels: PByte; out Width, Height: Integer): Boolean;
var
  cinfo: jpeg_decompress_struct;
  jerr: jpeg_error_mgr;
  memsrc: TMemSrc;
  row: JSAMPROW;
  rowbytes: Integer;
  outpos: Integer;
begin
  Result := False;
  Pixels := nil;
  Width := 0;
  Height := 0;

  if (InBuf = nil) or (InSize = 0) then Exit;

  FillChar(cinfo, SizeOf(cinfo), 0);
  FillChar(jerr, SizeOf(jerr), 0);

  cinfo.err := @jerr;
  jpeg_std_error(jerr);
  jpeg_create_decompress(@cinfo);

  FillChar(memsrc, SizeOf(memsrc), 0);
  memsrc.buffer := InBuf;
  memsrc.bufsize := InSize;
  memsrc.pub.init_source := @mem_init;
  memsrc.pub.fill_input_buffer := @mem_fill;
  memsrc.pub.skip_input_data := @mem_skip;
  memsrc.pub.resync_to_restart := @jpeg_resync_to_restart;
  memsrc.pub.term_source := @mem_term;
  memsrc.pub.bytes_in_buffer := 0;
  memsrc.pub.next_input_byte := nil;
  cinfo.src := @memsrc.pub;

  jpeg_read_header(@cinfo, True);
  cinfo.out_color_space := JCS_RGB;
  jpeg_start_decompress(@cinfo);

  Width := cinfo.output_width;
  Height := cinfo.output_height;
  rowbytes := Width * cinfo.output_components;

  GetMem(Pixels, rowbytes * Height);
  outpos := 0;

  while cinfo.output_scanline < cinfo.output_height do
  begin
    row := @Pixels[outpos];
    jpeg_read_scanlines(@cinfo, @row, 1);
    Inc(outpos, rowbytes);
  end;

  jpeg_finish_decompress(@cinfo);
  jpeg_destroy_decompress(@cinfo);
  Result := True;
end;

function JPEGLoadFileRaw(const FileName: string;
  out Pixels: PByte; out Width, Height: Integer): Boolean;
var
  F: File;
  Buf: PByte;
  Size: LongWord;
  BytesRead: LongWord;
begin
  Result := False;
  Pixels := nil;
  Width := 0;
  Height := 0;

  {$I-}
  Assign(F, FileName);
  Reset(F, 1);
  if IOResult <> 0 then Exit;
  {$I+}

  Size := FileSize(F);
  if Size < 4 then
  begin
    Close(F);
    Exit;
  end;

  GetMem(Buf, Size);
  BlockRead(F, Buf^, Size, BytesRead);
  Close(F);

  if BytesRead <> Size then
  begin
    FreeMem(Buf);
    Exit;
  end;

  Result := JPEGLoadMemRaw(Buf, Size, Pixels, Width, Height);
  FreeMem(Buf);
end;

function IsJPEGFile(const FileName: string): Boolean;
var
  F: File;
  Sig: array[0..1] of Byte;
  BytesRead: LongWord;
begin
  Result := False;
  {$I-}
  Assign(F, FileName);
  Reset(F, 1);
  if IOResult <> 0 then Exit;
  {$I+}
  BlockRead(F, Sig, 2, BytesRead);
  Close(F);
  Result := (BytesRead = 2) and (Sig[0] = $FF) and (Sig[1] = $D8);
end;


procedure JPEGStreamInitRaw(out Strm: TJPEGStreamRaw);
begin
  FillChar(Strm, SizeOf(Strm), 0);
  Strm.BufCap := 16384;
  GetMem(Strm.Buffer, Strm.BufCap);
end;

function JPEGStreamFeedRaw(var Strm: TJPEGStreamRaw;
  Data: PByte; Size: LongWord): Boolean;
var
  NewCap: LongWord;
  NewBuf, TempPixels: PByte;
  TempW, TempH: Integer;
begin
  Result := False;
  if Strm.Complete then begin Result := True; Exit; end;

  // Grow buffer if needed
  if Strm.BufSize + Size > Strm.BufCap then
  begin
    NewCap := Strm.BufCap;
    while NewCap < Strm.BufSize + Size do NewCap := NewCap * 2;
    GetMem(NewBuf, NewCap);
    if Strm.BufSize > 0 then
      Move(Strm.Buffer^, NewBuf^, Strm.BufSize);
    FreeMem(Strm.Buffer);
    Strm.Buffer := NewBuf;
    Strm.BufCap := NewCap;
  end;

  // Append new data
  Move(Data^, Strm.Buffer[Strm.BufSize], Size);
  Inc(Strm.BufSize, Size);

  // Need at least SOI + some data
  if Strm.BufSize < 128 then Exit;
  if (Strm.Buffer[0] <> $FF) or (Strm.Buffer[1] <> $D8) then Exit;

  // Attempt decode with accumulated data
  TempPixels := nil;
  if JPEGLoadMemRaw(Strm.Buffer, Strm.BufSize, TempPixels, TempW, TempH) then
  begin
    if Strm.Pixels <> nil then FreeMem(Strm.Pixels);
    Strm.Pixels := TempPixels;
    Strm.Width := TempW;
    Strm.Height := TempH;
    Strm.HasImage := True;
    Inc(Strm.ScanCount);

    // Check for EOI marker (FF D9)
    if (Strm.Buffer[Strm.BufSize - 2] = $FF) and
       (Strm.Buffer[Strm.BufSize - 1] = $D9) then
      Strm.Complete := True;

    Result := True;
  end;
end;

procedure JPEGStreamFreeRaw(var Strm: TJPEGStreamRaw);
begin
  if Strm.Buffer <> nil then begin FreeMem(Strm.Buffer); Strm.Buffer := nil; end;
  if Strm.Pixels <> nil then begin FreeMem(Strm.Pixels); Strm.Pixels := nil; end;
  Strm.HasImage := False;
  Strm.Complete := False;
end;

end.
