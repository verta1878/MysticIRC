{$MODE OBJFPC}
{$H+}
program m_pdmain;
{ PabloDraw Pascal — CLI viewer
  Loads ANSI, ASCII, Binary, Avatar, XBin, RIP files.
  Outputs: terminal dump, BMP render, or SAUCE info.
  
  Usage:
    pdview <file>              — dump to terminal
    pdview <file> -bmp out.bmp — render to BMP
    pdview <file> -sauce       — show SAUCE metadata
    pdview <file> -info        — show format info }

uses SysUtils, Classes, m_pdtypes, m_pdsauce, m_pdansi, m_pdascii, 
     m_pdbinary, m_pdavatar, m_pdxbin, m_pdbitfont, m_pdrip, m_pdtundra,
     m_pdpcboard, m_pdidf;

var
  FileName, OutFile, Mode: String;
  Ext: String;
  Canvas: TPDCanvas;
  Sauce: TSauceRecord;
  Ansi: TAnsiParser;
  Avatar: TAvatarParser;
  Rip: TRipParser;
  Font: TBitFont;
  Buffer: TPixelBuffer;
  Palette: TPDPalette;
  FontData: array[0..8191] of Byte;
  FontSize: Byte;
  HasPal, HasFont: Boolean;
  X, Y, I: Integer;
  E: TPDCanvasElement;
  F: TFileStream;
  Width: Integer;

procedure ShowUsage;
begin
  WriteLn('PabloDraw Pascal Viewer v0.1');
  WriteLn('Usage: pdview <file> [options]');
  WriteLn('');
  WriteLn('Options:');
  WriteLn('  -bmp <out.bmp>  Render to BMP file');
  WriteLn('  -sauce          Show SAUCE metadata');
  WriteLn('  -info           Show format info');
  WriteLn('  -w <width>      Set canvas width (default 80)');
  WriteLn('  -h <height>     Set canvas height (default 25)');
  WriteLn('');
  WriteLn('Supported formats:');
  WriteLn('  .ans .ansi      ANSI escape sequences');
  WriteLn('  .txt .asc .nfo  Plain ASCII text');
  WriteLn('  .bin            Binary (char+attr pairs)');
  WriteLn('  .avt            AVATAR terminal codes');
  WriteLn('  .xb .xbin       XBin (embedded font+palette)');
  WriteLn('  .rip            RIPscrip v1.54 vector graphics');
  WriteLn('  .tnd            Tundra Draw (24-bit color)');
  WriteLn('  .msg            PCBoard Ctrl-A color codes');
  WriteLn('  .idf            iCE Draw Format');
  WriteLn('  .diz            BBS file_id.diz');
  Halt(1);
end;

procedure ShowSauce;
begin
  Sauce := TSauceRecord.Create;
  try
    if Sauce.LoadFromFile(FileName) then begin
      WriteLn('SAUCE Record:');
      WriteLn('  Title:    ', Sauce.Title);
      WriteLn('  Author:   ', Sauce.Author);
      WriteLn('  Group:    ', Sauce.Group);
      WriteLn('  Date:     ', Sauce.DateStr);
      WriteLn('  DataType: ', Sauce.DataType);
      WriteLn('  FileType: ', Sauce.FileType);
      WriteLn('  TInfo1:   ', Sauce.TInfo1, ' (width)');
      WriteLn('  TInfo2:   ', Sauce.TInfo2, ' (height)');
      WriteLn('  Flags:    $', IntToHex(Sauce.Flags, 2));
      if Sauce.GetICEColors then WriteLn('  ICE Colors: Yes');
      if Sauce.GetFontName <> '' then WriteLn('  Font:     ', Sauce.GetFontName);
      WriteLn('  FileSize: ', Sauce.FileSize);
      if Sauce.Comments.Count > 0 then begin
        WriteLn('  Comments:');
        for I := 0 to Sauce.Comments.Count - 1 do
          WriteLn('    ', Sauce.Comments[I]);
      end;
    end else
      WriteLn('No SAUCE record found.');
  finally
    Sauce.Free;
  end;
end;

procedure DumpToTerminal;
var LastAttr: Byte;
begin
  LastAttr := 7;
  for Y := 0 to Canvas.Height - 1 do begin
    for X := 0 to Canvas.Width - 1 do begin
      E := Canvas[X, Y];
      { ANSI color output }
      if E.Attr.ToByte <> LastAttr then begin
        Write(#27'[0');
        if E.Attr.GetBold then Write(';1');
        if E.Attr.GetBlink then Write(';5');
        Write(';3', E.Attr.GetForegroundOnly);
        Write(';4', E.Attr.GetBackgroundOnly);
        Write('m');
        LastAttr := E.Attr.ToByte;
      end;
      if (E.Ch.Ch >= 32) and (E.Ch.Ch < 127) then
        Write(Chr(E.Ch.Ch))
      else if E.Ch.Ch = 0 then
        Write(' ')
      else
        Write('.');
    end;
    WriteLn;
  end;
  Write(#27'[0m'); { reset }
end;

procedure RenderToBMP;
begin
  Font := TBitFont.Create;
  try
    Font.LoadDefault;
    Buffer := TPixelBuffer.Create(Canvas.Width * FONT_WIDTH,
                                   Canvas.Height * Font.FontHeight);
    try
      RenderCanvas(Canvas, Font, Palette, Buffer);
      Buffer.SaveToBMP(OutFile);
      WriteLn('Rendered to ', OutFile, ' (',
        Canvas.Width * FONT_WIDTH, 'x',
        Canvas.Height * Font.FontHeight, ')');
    finally
      Buffer.Free;
    end;
  finally
    Font.Free;
  end;
end;

begin
  if ParamCount < 1 then ShowUsage;
  
  FileName := ParamStr(1);
  Mode := 'dump';
  OutFile := '';
  Width := 80;
  
  I := 2;
  while I <= ParamCount do begin
    if ParamStr(I) = '-bmp' then begin
      Mode := 'bmp';
      if I < ParamCount then begin Inc(I); OutFile := ParamStr(I); end
      else begin WriteLn('Error: -bmp requires output filename'); Halt(1); end;
    end
    else if ParamStr(I) = '-sauce' then Mode := 'sauce'
    else if ParamStr(I) = '-info' then Mode := 'info'
    else if ParamStr(I) = '-w' then begin
      if I < ParamCount then begin Inc(I); Val(ParamStr(I), Width, X); end;
    end;
    Inc(I);
  end;
  
  if not FileExists(FileName) then begin
    WriteLn('Error: file not found: ', FileName);
    Halt(1);
  end;
  
  if Mode = 'sauce' then begin ShowSauce; Halt(0); end;
  
  Ext := LowerCase(ExtractFileExt(FileName));
  
  { Initialize default palette }
  for I := 0 to 15 do Palette[I] := DefaultPalette[I];
  
  { RIP files — separate pipeline (pixel buffer, not text canvas) }
  if Ext = '.rip' then begin
    Rip := TRipParser.Create;
    try
      Rip.LoadFromFile(FileName);
      if Mode = 'bmp' then begin
        if OutFile = '' then OutFile := ChangeFileExt(FileName, '.bmp');
        Rip.SaveToBMP(OutFile);
        WriteLn('RIP rendered to ', OutFile, ' (640x350)');
      end else
        WriteLn('RIP file loaded. Use -bmp to render.');
    finally
      Rip.Free;
    end;
    Halt(0);
  end;
  
  { Text-based formats }
  Canvas := TPDCanvas.Create(Width, 500);
  try
    { Check SAUCE for dimensions }
    Sauce := TSauceRecord.Create;
    try
      if Sauce.LoadFromFile(FileName) then begin
        if Sauce.GetWidth > 0 then
          Canvas.Resize(Sauce.GetWidth, 500);
      end;
    finally
      Sauce.Free;
    end;
    
    F := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
    try
      if (Ext = '.ans') or (Ext = '.ansi') or (Ext = '.diz') or
         (Ext = '.ice') or (Ext = '.cia') then begin
        Ansi := TAnsiParser.Create;
        try
          Ansi.LoadFromStream(F, Canvas);
          Canvas.TrimHeight(Ansi.GetFinalY);
          if Mode = 'info' then begin
            WriteLn('ANSI file: ', ExtractFileName(FileName));
            WriteLn('  Size: ', Canvas.Width, 'x', Ansi.GetFinalY);
            if Ansi.ICEDetected then
              WriteLn('  ICE Colors: ', Ansi.ICEColors);
          end;
        finally
          Ansi.Free;
        end;
      end
      else if (Ext = '.txt') or (Ext = '.asc') or (Ext = '.nfo') then
        LoadASCII(F, Canvas)
      else if Ext = '.bin' then
        LoadBinary(F, Canvas, Width)
      else if Ext = '.avt' then begin
        Avatar := TAvatarParser.Create;
        try Avatar.LoadFromStream(F, Canvas);
        finally Avatar.Free; end;
      end
      else if (Ext = '.xb') or (Ext = '.xbin') then
        LoadXBin(F, Canvas, Palette, FontData, FontSize, HasPal, HasFont)
      else if Ext = '.tnd' then
        LoadTundra(F, Canvas, Palette)
      else if Ext = '.msg' then
        LoadPCBoard(F, Canvas)
      else if Ext = '.idf' then
        LoadIDF(F, Canvas, Palette)
      else begin
        { Default: try ANSI }
        Ansi := TAnsiParser.Create;
        try
          Ansi.LoadFromStream(F, Canvas);
          Canvas.TrimHeight(Ansi.GetFinalY);
        finally Ansi.Free; end;
      end;
    finally
      F.Free;
    end;
    
    if Mode = 'bmp' then begin
      if OutFile = '' then OutFile := ChangeFileExt(FileName, '.bmp');
      RenderToBMP;
    end
    else if Mode = 'dump' then
      DumpToTerminal;
      
  finally
    Canvas.Free;
  end;
end.
