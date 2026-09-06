{
  This file is part of the Mystic BBS IRC Fork.

  Copyright (C) 2026 Mystic BBS IRC Fork Contributors

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <https://www.gnu.org/licenses/>.
}
{ JPEG Decoder Wrapper — Decodes JPEG to raw pixel buffer
  Uses FPC's built-in pasjpeg package. Pure Pascal, no libjpeg.

  Usage:
    var Pixels: PByte; W, H: Integer;
    begin
      if JPEGLoadFile('photo.jpg', Pixels, W, H) then
      begin
        // Pixels^ is W*H*3 bytes (RGB, top-down)
        // Use with customdrawn canvas, RIPscript engine, etc.
        FreeMem(Pixels);
      end;
    end;
}
unit JPEGDec;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TJPEGPixelFormat = (jpfRGB, jpfGrayscale);

  TJPEGInfo = record
    Width: Integer;
    Height: Integer;
    PixelFormat: TJPEGPixelFormat;
    BitsPerPixel: Integer;
  end;

{ Decode JPEG from file to raw pixel buffer (RGB or Grayscale) }
function JPEGLoadFile(const FileName: string;
  out Pixels: PByte; out Width, Height: Integer): Boolean;

{ Decode JPEG from stream to raw pixel buffer }
function JPEGLoadStream(AStream: TStream;
  out Pixels: PByte; out Width, Height: Integer): Boolean;

{ Decode JPEG from memory buffer }
function JPEGLoadMem(InBuf: PByte; InSize: Cardinal;
  out Pixels: PByte; out Width, Height: Integer): Boolean;

{ Get JPEG info without decoding }
function JPEGGetInfo(const FileName: string;
  out Info: TJPEGInfo): Boolean;

type
  TJPEGStreamState = (
    jssAccumulating,   // collecting data, haven't decoded yet
    jssHeaderRead,     // header parsed, dimensions known
    jssPartialDecode,  // have a partial image
    jssComplete,       // fully decoded
    jssError
  );

  TJPEGStream = record
    Buffer: PByte;        // accumulated JPEG data
    BufSize: LongWord;    // current data size
    BufCap: LongWord;     // allocated capacity
    Pixels: PByte;        // latest decoded image (RGB)
    Width: Integer;
    Height: Integer;
    State: TJPEGStreamState;
    HasImage: Boolean;    // true if Pixels contains a valid image
    ScanCount: Integer;   // number of scans decoded so far
  end;

{ Initialize streaming decoder }
procedure JPEGStreamInit(out Strm: TJPEGStream);

{ Feed chunk of data — attempts decode after each feed }
function JPEGStreamFeed(var Strm: TJPEGStream;
  Data: PByte; Size: LongWord): Boolean;

{ Get current partial/complete image (nil if not yet available) }
function JPEGStreamGetPixels(var Strm: TJPEGStream;
  out Pixels: PByte; out W, H: Integer): Boolean;

{ Check if complete }
function JPEGStreamComplete(const Strm: TJPEGStream): Boolean;

{ Free streaming decoder }
procedure JPEGStreamFree(var Strm: TJPEGStream);

implementation

uses
  jmorecfg, jpeglib, jerror, jdeferr, jdapimin, jdapistd,
  jdatasrc, jdmarker, jdmaster;

type
  TMemSourceMgr = record
    pub: jpeg_source_mgr;
    buffer: PByte;
    bufsize: Cardinal;
    start_of_data: Boolean;
  end;
  PMemSourceMgr = ^TMemSourceMgr;

procedure mem_init_source(cinfo: j_decompress_ptr); far;
begin
  PMemSourceMgr(cinfo^.src)^.start_of_data := True;
end;

function mem_fill_input_buffer(cinfo: j_decompress_ptr): Boolean; far;
var
  src: PMemSourceMgr;
begin
  src := PMemSourceMgr(cinfo^.src);
  if src^.start_of_data then
  begin
    src^.pub.next_input_byte := src^.buffer;
    src^.pub.bytes_in_buffer := src^.bufsize;
    src^.start_of_data := False;
  end
  else
  begin
    { No more data — shouldn't happen with memory source }
    src^.pub.bytes_in_buffer := 0;
  end;
  Result := True;
end;

procedure mem_skip_input_data(cinfo: j_decompress_ptr; num_bytes: LongInt); far;
var
  src: PMemSourceMgr;
begin
  src := PMemSourceMgr(cinfo^.src);
  if num_bytes > 0 then
  begin
    while num_bytes > LongInt(src^.pub.bytes_in_buffer) do
    begin
      Dec(num_bytes, src^.pub.bytes_in_buffer);
      mem_fill_input_buffer(cinfo);
    end;
    Inc(src^.pub.next_input_byte, num_bytes);
    Dec(src^.pub.bytes_in_buffer, num_bytes);
  end;
end;

procedure mem_term_source(cinfo: j_decompress_ptr); far;
begin
  { nothing to clean up for memory source }
end;

function JPEGLoadMem(InBuf: PByte; InSize: Cardinal;
  out Pixels: PByte; out Width, Height: Integer): Boolean;
var
  cinfo: jpeg_decompress_struct;
  jerr: jpeg_error_mgr;
  memsrc: TMemSourceMgr;
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

  cinfo.err := @jerr; jpeg_std_error(jerr);
  jpeg_create_decompress(@cinfo);

  try
    { Set up memory source }
    FillChar(memsrc, SizeOf(memsrc), 0);
    memsrc.buffer := InBuf;
    memsrc.bufsize := InSize;
    memsrc.pub.init_source := @mem_init_source;
    memsrc.pub.fill_input_buffer := @mem_fill_input_buffer;
    memsrc.pub.skip_input_data := @mem_skip_input_data;
    memsrc.pub.resync_to_restart := @jpeg_resync_to_restart;
    memsrc.pub.term_source := @mem_term_source;
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
    Result := True;
  except
    on E: Exception do
    begin
      if Pixels <> nil then
      begin
        FreeMem(Pixels);
        Pixels := nil;
      end;
      Width := 0;
      Height := 0;
    end;
  end;

  jpeg_destroy_decompress(@cinfo);
end;

function JPEGLoadStream(AStream: TStream;
  out Pixels: PByte; out Width, Height: Integer): Boolean;
var
  Buf: PByte;
  Size: Cardinal;
begin
  Size := AStream.Size - AStream.Position;
  GetMem(Buf, Size);
  try
    AStream.ReadBuffer(Buf^, Size);
    Result := JPEGLoadMem(Buf, Size, Pixels, Width, Height);
  finally
    FreeMem(Buf);
  end;
end;

function JPEGLoadFile(const FileName: string;
  out Pixels: PByte; out Width, Height: Integer): Boolean;
var
  F: TFileStream;
begin
  Result := False;
  if not FileExists(FileName) then Exit;
  F := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
  try
    Result := JPEGLoadStream(F, Pixels, Width, Height);
  finally
    F.Free;
  end;
end;

function JPEGGetInfo(const FileName: string;
  out Info: TJPEGInfo): Boolean;
var
  F: TFileStream;
  Buf: PByte;
  Size: Cardinal;
  cinfo: jpeg_decompress_struct;
  jerr: jpeg_error_mgr;
  memsrc: TMemSourceMgr;
begin
  Result := False;
  FillChar(Info, SizeOf(Info), 0);
  if not FileExists(FileName) then Exit;

  F := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
  try
    Size := F.Size;
    GetMem(Buf, Size);
    try
      F.ReadBuffer(Buf^, Size);

      FillChar(cinfo, SizeOf(cinfo), 0);
      cinfo.err := @jerr; jpeg_std_error(jerr);
      jpeg_create_decompress(@cinfo);
      try
        FillChar(memsrc, SizeOf(memsrc), 0);
        memsrc.buffer := Buf;
        memsrc.bufsize := Size;
        memsrc.pub.init_source := @mem_init_source;
        memsrc.pub.fill_input_buffer := @mem_fill_input_buffer;
        memsrc.pub.skip_input_data := @mem_skip_input_data;
        memsrc.pub.resync_to_restart := @jpeg_resync_to_restart;
        memsrc.pub.term_source := @mem_term_source;
        cinfo.src := @memsrc.pub;

        jpeg_read_header(@cinfo, True);

        Info.Width := cinfo.image_width;
        Info.Height := cinfo.image_height;
        if cinfo.num_components = 1 then
        begin
          Info.PixelFormat := jpfGrayscale;
          Info.BitsPerPixel := 8;
        end
        else
        begin
          Info.PixelFormat := jpfRGB;
          Info.BitsPerPixel := 24;
        end;
        Result := True;
      finally
        jpeg_destroy_decompress(@cinfo);
      end;
    finally
      FreeMem(Buf);
    end;
  finally
    F.Free;
  end;
end;


{ TJPEGStream }

procedure JPEGStreamInit(out Strm: TJPEGStream);
begin
  FillChar(Strm, SizeOf(Strm), 0);
  Strm.BufCap := 16384;
  GetMem(Strm.Buffer, Strm.BufCap);
  Strm.State := jssAccumulating;
end;

function JPEGStreamFeed(var Strm: TJPEGStream;
  Data: PByte; Size: LongWord): Boolean;
var
  NewCap: LongWord;
  NewBuf: PByte;
  TempPixels: PByte;
  TempW, TempH: Integer;
begin
  Result := False;
  if Strm.State = jssError then Exit;
  if Strm.State = jssComplete then begin Result := True; Exit; end;

  // Grow buffer if needed
  if Strm.BufSize + Size > Strm.BufCap then
  begin
    NewCap := Strm.BufCap;
    while NewCap < Strm.BufSize + Size do
      NewCap := NewCap * 2;
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

  // Try to decode with what we have
  // JPEG needs at minimum SOI (FFD8) + some data
  if Strm.BufSize < 128 then Exit;

  // Check JPEG signature
  if (Strm.Buffer[0] <> $FF) or (Strm.Buffer[1] <> $D8) then
  begin
    Strm.State := jssError;
    Exit;
  end;

  // Attempt full decode — if JPEG is incomplete, it will fail
  // gracefully and we try again next feed
  TempPixels := nil;
  if JPEGLoadMem(Strm.Buffer, Strm.BufSize, TempPixels, TempW, TempH) then
  begin
    // Successful decode — update image
    if Strm.Pixels <> nil then
      FreeMem(Strm.Pixels);
    Strm.Pixels := TempPixels;
    Strm.Width := TempW;
    Strm.Height := TempH;
    Strm.HasImage := True;
    Inc(Strm.ScanCount);

    // Check if we have the EOI marker (FFD9) = complete
    if (Strm.Buffer[Strm.BufSize - 2] = $FF) and
       (Strm.Buffer[Strm.BufSize - 1] = $D9) then
      Strm.State := jssComplete
    else
      Strm.State := jssPartialDecode;

    Result := True;
  end
  else
  begin
    // Decode failed — not enough data yet, keep accumulating
    if Strm.State = jssAccumulating then
    begin
      // Try to at least read dimensions from SOF marker
      if Strm.BufSize > 256 then
        Strm.State := jssHeaderRead;
    end;
  end;
end;

function JPEGStreamGetPixels(var Strm: TJPEGStream;
  out Pixels: PByte; out W, H: Integer): Boolean;
begin
  if Strm.HasImage then
  begin
    Pixels := Strm.Pixels;
    W := Strm.Width;
    H := Strm.Height;
    Result := True;
  end
  else
  begin
    Pixels := nil;
    W := 0;
    H := 0;
    Result := False;
  end;
end;

function JPEGStreamComplete(const Strm: TJPEGStream): Boolean;
begin
  Result := Strm.State = jssComplete;
end;

procedure JPEGStreamFree(var Strm: TJPEGStream);
begin
  if Strm.Buffer <> nil then
  begin
    FreeMem(Strm.Buffer);
    Strm.Buffer := nil;
  end;
  if Strm.Pixels <> nil then
  begin
    FreeMem(Strm.Pixels);
    Strm.Pixels := nil;
  end;
  Strm.State := jssError;
  Strm.HasImage := False;
end;

end.
