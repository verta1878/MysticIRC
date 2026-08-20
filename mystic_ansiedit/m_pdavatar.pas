{$MODE OBJFPC}
{$H+}
unit m_pdavatar;
{ PabloDraw Pascal — AVATAR (AVT) terminal code parser
  AVATAR/0+ protocol used by some BBS systems.
  Superset of ANSI with additional codes. }

interface

uses Classes, SysUtils, m_pdtypes;

type
  TAvatarParser = class
  private
    FCurX, FCurY: Integer;
    FAttr: TPDAttribute;
    FCanvas: TPDCanvas;
  public
    procedure LoadFromStream(S: TStream; ACanvas: TPDCanvas);
  end;

implementation

procedure TAvatarParser.LoadFromStream(S: TStream; ACanvas: TPDCanvas);
var
  B, B2, B3: Byte;
  E: TPDCanvasElement;
  Count, I: Integer;
begin
  FCanvas := ACanvas;
  FCurX := 0; FCurY := 0;
  FAttr.Init(7);
  
  while S.Read(B, 1) = 1 do begin
    case B of
      10: begin { LF }
        FCurX := 0; Inc(FCurY);
        if FCurY >= FCanvas.Height then begin
          FCanvas.ScrollUp(1); Dec(FCurY);
        end;
      end;
      12: begin { FF — clear screen }
        FCanvas.Clear;
        FCurX := 0; FCurY := 0;
      end;
      13: ; { CR }
      22: begin { AVT/0 — set attribute }
        if S.Read(B2, 1) <> 1 then Break;
        FAttr.Init(B2);
      end;
      25: begin { AVT/0 — repeat character }
        if S.Read(B2, 1) <> 1 then Break;
        if S.Read(B3, 1) <> 1 then Break;
        E.Ch.Ch := B2;
        E.Attr := FAttr;
        for I := 1 to B3 do begin
          if (FCurX < FCanvas.Width) and (FCurY < FCanvas.Height) then
            FCanvas[FCurX, FCurY] := E;
          Inc(FCurX);
          if FCurX >= FCanvas.Width then begin
            FCurX := 0; Inc(FCurY);
            if FCurY >= FCanvas.Height then begin
              FCanvas.ScrollUp(1); Dec(FCurY);
            end;
          end;
        end;
      end;
    else
      E.Ch.Ch := B;
      E.Attr := FAttr;
      if (FCurX < FCanvas.Width) and (FCurY < FCanvas.Height) then
        FCanvas[FCurX, FCurY] := E;
      Inc(FCurX);
      if FCurX >= FCanvas.Width then begin
        FCurX := 0; Inc(FCurY);
        if FCurY >= FCanvas.Height then begin
          FCanvas.ScrollUp(1); Dec(FCurY);
        end;
      end;
    end;
  end;
end;

end.
