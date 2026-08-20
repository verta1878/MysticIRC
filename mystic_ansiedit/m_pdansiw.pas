{$MODE OBJFPC}
{$H+}
{$MODESWITCH ADVANCEDRECORDS}
unit m_pdansiw;
{ PabloDraw Pascal — ANSI Writer
  Saves TPDCanvas back to .ANS with optimized escape sequences.
  Minimizes output by tracking attribute changes and skipping
  trailing spaces. }

interface

uses Classes, SysUtils, m_pdtypes;

procedure SaveANSI(S: TStream; Canvas: TPDCanvas; Height: Integer);
procedure SaveANSIFile(const FileName: String; Canvas: TPDCanvas; Height: Integer);

implementation

const
  { ANSI SGR ← DOS color mapping (reverse of ColourMap) }
  FGMap: array[0..15] of String = (
    '30','34','32','36','31','35','33','37',     { 0-7 normal }
    '1;30','1;34','1;32','1;36','1;31','1;35','1;33','1;37'  { 8-15 bold }
  );
  BGMap: array[0..7] of String = (
    '40','44','42','46','41','45','43','47'
  );

procedure WriteStr(S: TStream; const Str: String);
begin
  if Length(Str) > 0 then
    S.Write(Str[1], Length(Str));
end;

procedure SaveANSI(S: TStream; Canvas: TPDCanvas; Height: Integer);
var
  X, Y, LastX, EndX: Integer;
  E: TPDCanvasElement;
  CurFG, CurBG, NewFG, NewBG: Integer;
  CurBold, CurBlink: Boolean;
  NeedReset: Boolean;
  ESC: String;
begin
  if Height > Canvas.Height then Height := Canvas.Height;
  if Height <= 0 then Height := Canvas.Height;
  
  CurFG := 7; CurBG := 0;
  CurBold := False; CurBlink := False;
  
  for Y := 0 to Height - 1 do begin
    { Find last non-space character on this line }
    EndX := Canvas.Width - 1;
    while (EndX >= 0) do begin
      E := Canvas[EndX, Y];
      if (E.Ch.Ch <> 32) or (E.Attr.ToByte <> 7) then Break;
      Dec(EndX);
    end;
    
    for X := 0 to EndX do begin
      E := Canvas[X, Y];
      NewFG := E.Attr.GetForeground;
      NewBG := E.Attr.GetBackground;
      
      { Check if attribute changed }
      if (NewFG <> CurFG) or (NewBG <> CurBG) then begin
        NeedReset := False;
        
        { Bold changed? }
        if (NewFG < 8) and CurBold then NeedReset := True;
        if (NewBG < 8) and CurBlink then NeedReset := True;
        
        if NeedReset or ((NewFG = 7) and (NewBG = 0)) then begin
          { Full reset }
          ESC := #27'[0';
          CurBold := False;
          CurBlink := False;
          CurFG := 7;
          CurBG := 0;
        end else
          ESC := #27'[';
        
        { Add bold if needed }
        if (NewFG >= 8) and not CurBold then begin
          if ESC[Length(ESC)] <> '[' then ESC := ESC + ';';
          ESC := ESC + '1';
          CurBold := True;
        end;
        
        { Add blink if needed }
        if (NewBG >= 8) and not CurBlink then begin
          if ESC[Length(ESC)] <> '[' then ESC := ESC + ';';
          ESC := ESC + '5';
          CurBlink := True;
        end;
        
        { Add foreground if changed }
        if (NewFG and 7) <> (CurFG and 7) then begin
          if ESC[Length(ESC)] <> '[' then ESC := ESC + ';';
          ESC := ESC + BGMap[0][1]; { 3 }
          ESC[Length(ESC)] := Chr(Ord('0') + (NewFG and 7));
          { Actually use the map properly: }
          case NewFG and 7 of
            0: ESC := ESC + '0'; 1: ESC := ESC + '4';
            2: ESC := ESC + '2'; 3: ESC := ESC + '6';
            4: ESC := ESC + '1'; 5: ESC := ESC + '5';
            6: ESC := ESC + '3'; 7: ESC := ESC + '7';
          end;
          { Fix: just use lookup }
        end;
        
        { Simplified: emit full SGR for each change }
        ESC := #27'[0';
        if NewFG >= 8 then ESC := ESC + ';1';
        if NewBG >= 8 then ESC := ESC + ';5';
        { FG: DOS→ANSI mapping }
        ESC := ESC + ';3';
        case NewFG and 7 of
          0: ESC := ESC + '0'; 1: ESC := ESC + '4';
          2: ESC := ESC + '2'; 3: ESC := ESC + '6';
          4: ESC := ESC + '1'; 5: ESC := ESC + '5';
          6: ESC := ESC + '3'; 7: ESC := ESC + '7';
        end;
        { BG: }
        ESC := ESC + ';4';
        case NewBG and 7 of
          0: ESC := ESC + '0'; 1: ESC := ESC + '4';
          2: ESC := ESC + '2'; 3: ESC := ESC + '6';
          4: ESC := ESC + '1'; 5: ESC := ESC + '5';
          6: ESC := ESC + '3'; 7: ESC := ESC + '7';
        end;
        ESC := ESC + 'm';
        
        WriteStr(S, ESC);
        CurFG := NewFG;
        CurBG := NewBG;
        CurBold := NewFG >= 8;
        CurBlink := NewBG >= 8;
      end;
      
      { Write character }
      if (E.Ch.Ch >= 32) and (E.Ch.Ch <= 255) then
        S.Write(E.Ch.Ch, 1)
      else begin
        LastX := 32;
        S.Write(LastX, 1);
      end;
    end;
    
    { End of line }
    if Y < Height - 1 then
      WriteStr(S, #13#10);
  end;
  
  { Reset at end }
  WriteStr(S, #27'[0m');
end;

procedure SaveANSIFile(const FileName: String; Canvas: TPDCanvas; Height: Integer);
var F: TFileStream;
begin
  F := TFileStream.Create(FileName, fmCreate);
  try SaveANSI(F, Canvas, Height);
  finally F.Free; end;
end;

end.
