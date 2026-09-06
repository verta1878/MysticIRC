{$MODE OBJFPC}
{$H+}
unit m_pdpcboard;
{ PabloDraw Pascal — PCBoard / Ctrl-A format loader
  PCBoard BBS uses Ctrl-A (0x01) as color escape.
  Format: ^A<attr> where attr is a 2-char hex attribute. }

interface

uses Classes, SysUtils, m_pdtypes;

const
  { PCBoard foreground color codes }
  PCB_FG: String = 'KBGCRMYWkbgcrmyw';
  { PCBoard background color codes }
  PCB_BG: String = '04261537';

procedure LoadPCBoard(S: TStream; Canvas: TPDCanvas);
procedure LoadAtX(S: TStream; Canvas: TPDCanvas);
procedure SaveAtX(S: TStream; Canvas: TPDCanvas);

implementation

function PCBColorToAttr(Ch: Char; IsFG: Boolean): Integer;
var I: Integer;
begin
  Result := 7;
  if IsFG then begin
    I := Pos(Ch, PCB_FG);
    if I > 0 then Result := I - 1;
  end else begin
    I := Pos(Ch, PCB_BG);
    if I > 0 then Result := I - 1;
  end;
end;

procedure LoadPCBoard(S: TStream; Canvas: TPDCanvas);
var
  B, B2: Byte;
  X, Y: Integer;
  E: TPDCanvasElement;
  Attr: TPDAttribute;
begin
  X := 0; Y := 0;
  Attr.Init(7);
  
  while S.Read(B, 1) = 1 do begin
    case B of
      1: begin { Ctrl-A — color escape }
        if S.Read(B2, 1) <> 1 then Break;
        case Chr(B2) of
          'K','B','G','C','R','M','Y','W',
          'k','b','g','c','r','m','y','w':
            Attr.SetForeground(PCBColorToAttr(Chr(B2), True));
          '0'..'7':
            Attr.SetBackground(PCBColorToAttr(Chr(B2), False));
        end;
      end;
      10: begin X := 0; Inc(Y); end;
      13: ;
    else
      E.Ch.Ch := B;
      E.Attr := Attr;
      if (X < Canvas.Width) and (Y < Canvas.Height) then
        Canvas[X, Y] := E;
      Inc(X);
      if X >= Canvas.Width then begin X := 0; Inc(Y); end;
    end;
  end;
end;

function HexVal(Ch: Char): Byte;
begin
  case Ch of
    '0'..'9': Result := Ord(Ch) - Ord('0');
    'A'..'F': Result := 10 + Ord(Ch) - Ord('A');
    'a'..'f': Result := 10 + Ord(Ch) - Ord('a');
  else Result := 0;
  end;
end;

procedure LoadAtX(S: TStream; Canvas: TPDCanvas);
{ @X format: @X<bg_hex><fg_hex> — PCBoard 15.x }
var
  B: Byte;
  X, Y: Integer;
  E: TPDCanvasElement;
  Attr: TPDAttribute;
  Ch1, Ch2: Byte;
begin
  X := 0; Y := 0;
  Attr.Init(7);

  while S.Read(B, 1) = 1 do begin
    if (B = Ord('@')) then begin
      { Peek at next char }
      if S.Read(Ch1, 1) <> 1 then Break;
      if Chr(Ch1) = 'X' then begin
        { Read two hex digits: BG then FG }
        if S.Read(Ch1, 1) <> 1 then Break;
        if S.Read(Ch2, 1) <> 1 then Break;
        Attr.Init((HexVal(Chr(Ch1)) shl 4) or HexVal(Chr(Ch2)));
        Continue;
      end else begin
        { Not @X — output @ and the peeked char }
        E.Ch.Ch := Ord('@');
        E.Attr := Attr;
        if (X < Canvas.Width) and (Y < Canvas.Height) then
          Canvas[X, Y] := E;
        Inc(X);
        if X >= Canvas.Width then begin X := 0; Inc(Y); end;
        B := Ch1;  { Fall through to output this char }
      end;
    end;
    case B of
      10: begin X := 0; Inc(Y); end;
      13: ;
    else
      E.Ch.Ch := B;
      E.Attr := Attr;
      if (X < Canvas.Width) and (Y < Canvas.Height) then
        Canvas[X, Y] := E;
      Inc(X);
      if X >= Canvas.Width then begin X := 0; Inc(Y); end;
    end;
  end;
end;

procedure SaveAtX(S: TStream; Canvas: TPDCanvas);
{ Save canvas as @X format — PCBoard 15.x color codes }
const
  HexChars: String = '0123456789ABCDEF';
var
  X, Y: Integer;
  E: TPDCanvasElement;
  LastAttr: Byte;
  AtXCode: String[4];
  CRLF: String[2];
  LineLen: Integer;
begin
  LastAttr := 255;  { Force first color output }
  CRLF := #13#10;

  for Y := 0 to Canvas.Height - 1 do begin
    { Find actual line length (trim trailing spaces with default attr) }
    LineLen := Canvas.Width;
    while (LineLen > 0) do begin
      E := Canvas[LineLen - 1, Y];
      if (E.Ch.Ch <> Ord(' ')) or (E.Attr.ToByte <> 7) then Break;
      Dec(LineLen);
    end;

    for X := 0 to LineLen - 1 do begin
      E := Canvas[X, Y];
      if E.Attr.ToByte <> LastAttr then begin
        LastAttr := E.Attr.ToByte;
        AtXCode := '@X' + HexChars[((LastAttr shr 4) and $0F) + 1]
                        + HexChars[(LastAttr and $0F) + 1];
        S.Write(AtXCode[1], Length(AtXCode));
      end;
      S.Write(E.Ch.Ch, 1);
    end;
    S.Write(CRLF[1], 2);
  end;
end;

end.
