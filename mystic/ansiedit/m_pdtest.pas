{$MODE OBJFPC}
{$H+}
program m_pdtest;
{ PabloDraw Pascal — Test Suite
  Tests all format parsers and round-trip ANSI write. }

uses SysUtils, Classes, m_pdtypes, m_pdsauce, m_pdansi, m_pdansiw,
     m_pdascii, m_pdbinary, m_pdavatar, m_pdxbin, m_pdbitfont, m_pdrip;

var
  Canvas: TPDCanvas;
  Ansi: TAnsiParser;
  Avatar: TAvatarParser;
  Rip: TRipParser;
  Sauce: TSauceRecord;
  Font: TBitFont;
  Buffer: TPixelBuffer;
  Palette: TPDPalette;
  FontData: array[0..8191] of Byte;
  FontSize: Byte;
  HasPal, HasFont: Boolean;
  MS: TMemoryStream;
  E: TPDCanvasElement;
  I, Pass, Fail: Integer;

procedure Check(const Name: String; Cond: Boolean);
begin
  if Cond then begin Inc(Pass); Write('.'); end
  else begin Inc(Fail); WriteLn('FAIL: ', Name); end;
end;

procedure TestTypes;
var A: TPDAttribute;
begin
  A.Init(7);
  Check('Attr.Init(7) fg', A.GetForeground = 7);
  Check('Attr.Init(7) bg', A.GetBackground = 0);
  A.Init($1F);
  Check('Attr $1F fg', A.GetForeground = 15);
  Check('Attr $1F bg', A.GetBackground = 1);
  A.Bold := True;
  Check('Attr bold', A.GetBold);
  A.Blink := True;
  Check('Attr blink', A.GetBlink);
  Check('Attr byte', A.ToByte = (A.GetForeground and $0F) or ((A.GetBackground and $0F) shl 4));
end;

procedure TestCanvas;
begin
  Canvas := TPDCanvas.Create(80, 25);
  Check('Canvas create', Canvas.Width = 80);
  Check('Canvas height', Canvas.Height = 25);
  E.Ch.Ch := 65; E.Attr.Init($0F);
  Canvas[0, 0] := E;
  Check('Canvas set/get', Canvas[0, 0].Ch.Ch = 65);
  Check('Canvas attr', Canvas[0, 0].Attr.ToByte = $0F);
  Canvas.ScrollUp(1);
  Check('Canvas scroll', Canvas[0, 0].Ch.Ch = 32);
  Canvas.Free;
end;

procedure TestSauce;
begin
  Sauce := TSauceRecord.Create;
  MS := TMemoryStream.Create;
  { Write a dummy file + SAUCE }
  for I := 0 to 99 do MS.Write(I, 1);
  Sauce.Title := 'Test Art';
  Sauce.Author := 'm_pdtest';
  Sauce.Group := 'FPC264IRC';
  Sauce.DataType := 1;
  Sauce.FileType := 1;
  Sauce.TInfo1 := 80;
  Sauce.TInfo2 := 25;
  Sauce.SaveToStream(MS);
  { Read back }
  MS.Position := 0;
  Check('SAUCE has', TSauceRecord.HasSauce(MS));
  Sauce.Free;
  Sauce := TSauceRecord.Create;
  Check('SAUCE load', Sauce.LoadFromStream(MS));
  Check('SAUCE title', Sauce.Title = 'Test Art');
  Check('SAUCE author', Sauce.Author = 'm_pdtest');
  Check('SAUCE width', Sauce.GetWidth = 80);
  Sauce.Free;
  MS.Free;
end;

procedure TestAnsi;
begin
  Canvas := TPDCanvas.Create(80, 25);
  MS := TMemoryStream.Create;
  { Write ANSI with escape sequences }
  MS.Write(PChar(#27'[1;31mHello'#27'[0m World'#13#10)^, 24);
  MS.Position := 0;
  Ansi := TAnsiParser.Create;
  Ansi.LoadFromStream(MS, Canvas);
  Check('ANSI H', Canvas[0, 0].Ch.Ch = Ord('H'));
  Check('ANSI bold red', Canvas[0, 0].Attr.GetBold);
  Check('ANSI space', Canvas[5, 0].Ch.Ch = 32);
  Check('ANSI W', Canvas[6, 0].Ch.Ch = Ord('W'));
  Ansi.Free;
  MS.Free;
  Canvas.Free;
end;

procedure TestAnsiRoundTrip;
var
  MS2: TMemoryStream;
  Canvas2: TPDCanvas;
begin
  Canvas := TPDCanvas.Create(80, 5);
  E.Ch.Ch := Ord('X'); E.Attr.Init($1E); { yellow on blue }
  Canvas[0, 0] := E;
  E.Ch.Ch := Ord('Y'); E.Attr.Init($0F);
  Canvas[1, 0] := E;
  MS := TMemoryStream.Create;
  SaveANSI(MS, Canvas, 1);
  Check('ANSI write size', MS.Size > 0);
  { Read back }
  MS.Position := 0;
  Canvas2 := TPDCanvas.Create(80, 25);
  Ansi := TAnsiParser.Create;
  Ansi.LoadFromStream(MS, Canvas2);
  Check('ANSI rt X', Canvas2[0, 0].Ch.Ch = Ord('X'));
  Check('ANSI rt Y', Canvas2[1, 0].Ch.Ch = Ord('Y'));
  Ansi.Free;
  Canvas2.Free;
  MS.Free;
  Canvas.Free;
end;

procedure TestBinary;
begin
  Canvas := TPDCanvas.Create(80, 25);
  MS := TMemoryStream.Create;
  E.Ch.Ch := Ord('A'); E.Attr.Init($07);
  MS.Write(E.Ch.Ch, 1); I := E.Attr.ToByte; MS.Write(I, 1);
  E.Ch.Ch := Ord('B'); E.Attr.Init($1F);
  MS.Write(E.Ch.Ch, 1); I := E.Attr.ToByte; MS.Write(I, 1);
  MS.Position := 0;
  LoadBinary(MS, Canvas, 80);
  Check('BIN A', Canvas[0, 0].Ch.Ch = Ord('A'));
  Check('BIN B', Canvas[1, 0].Ch.Ch = Ord('B'));
  Check('BIN attr', Canvas[1, 0].Attr.ToByte = $1F);
  MS.Free;
  Canvas.Free;
end;

procedure TestFont;
begin
  Font := TBitFont.Create;
  Font.LoadDefault;
  Check('Font height', Font.FontHeight = 16);
  Check('Font A glyph', Font.GetGlyph(Ord('A'), 3) <> 0);
  Check('Font space', Font.GetGlyph(32, 0) = 0);
  Check('Font block', Font.GetGlyph($DB, 0) = $FF);
  Font.Free;
end;

procedure TestRender;
begin
  Canvas := TPDCanvas.Create(4, 2);
  E.Ch.Ch := Ord('A'); E.Attr.Init($0F);
  Canvas[0, 0] := E;
  E.Ch.Ch := $DB; E.Attr.Init($04); { red block }
  Canvas[1, 0] := E;
  Font := TBitFont.Create;
  Font.LoadDefault;
  for I := 0 to 15 do Palette[I] := DefaultPalette[I];
  Buffer := TPixelBuffer.Create(4 * 8, 2 * 16);
  RenderCanvas(Canvas, Font, Palette, Buffer);
  Check('Render pixel', (Buffer.GetPixel(0, 0).R = 0)); { bg of A = black }
  Check('Render block', (Buffer.GetPixel(8, 0).R = 170)); { red block }
  Buffer.Free; Font.Free; Canvas.Free;
end;

begin
  Pass := 0; Fail := 0;
  WriteLn('PabloDraw Pascal Test Suite');
  WriteLn('==========================');
  Write('Types:     '); TestTypes; WriteLn;
  Write('Canvas:    '); TestCanvas; WriteLn;
  Write('SAUCE:     '); TestSauce; WriteLn;
  Write('ANSI:      '); TestAnsi; WriteLn;
  Write('ANSI R/T:  '); TestAnsiRoundTrip; WriteLn;
  Write('Binary:    '); TestBinary; WriteLn;
  Write('Font:      '); TestFont; WriteLn;
  Write('Render:    '); TestRender; WriteLn;
  WriteLn;
  WriteLn(Pass, ' passed, ', Fail, ' failed');
  if Fail = 0 then WriteLn('ALL TESTS PASSED')
  else Halt(1);
end.
