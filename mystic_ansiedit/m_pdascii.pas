{$MODE OBJFPC}
{$H+}
unit m_pdascii;
{ PabloDraw Pascal — ASCII (plain text) loader }

interface

uses Classes, SysUtils, m_pdtypes;

procedure LoadASCII(S: TStream; Canvas: TPDCanvas);
procedure LoadASCIIFile(const FileName: String; Canvas: TPDCanvas);

implementation

procedure LoadASCII(S: TStream; Canvas: TPDCanvas);
var
  B: Byte;
  X, Y: Integer;
  E: TPDCanvasElement;
begin
  X := 0; Y := 0;
  E.Attr.Init(7);
  
  while S.Read(B, 1) = 1 do begin
    case B of
      10: begin { LF }
        X := 0; Inc(Y);
        if Y >= Canvas.Height then begin
          Canvas.ScrollUp(1); Dec(Y);
        end;
      end;
      13: ; { CR — ignore }
      26: Break; { EOF }
    else
      E.Ch.Ch := B;
      if (X < Canvas.Width) and (Y < Canvas.Height) then
        Canvas[X, Y] := E;
      Inc(X);
      if X >= Canvas.Width then begin
        X := 0; Inc(Y);
        if Y >= Canvas.Height then begin
          Canvas.ScrollUp(1); Dec(Y);
        end;
      end;
    end;
  end;
end;

procedure LoadASCIIFile(const FileName: String; Canvas: TPDCanvas);
var F: TFileStream;
begin
  F := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
  try LoadASCII(F, Canvas);
  finally F.Free; end;
end;

end.
