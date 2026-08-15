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

end.
