{$MODE OBJFPC}
{$H+}
{$MODESWITCH ADVANCEDRECORDS}
unit m_pdansi;
{ PabloDraw Pascal — ANSI Escape Sequence Parser
  Converted from PabloDraw C# (Ansi.load.cs)
  Original: MIT License
  
  Parses ANSI X3.64 / ECMA-48 escape sequences:
  CSI = ESC [ (0x1B 0x5B)
  SGR (m) — colors, bold, blink
  CUP (H/f) — cursor position
  CUU/CUD/CUF/CUB (A/B/C/D) — cursor movement
  ED (J) — erase display
  EL (K) — erase line
  SCP/RCP (s/u) — save/restore cursor
  SM/RM (h/l) — set/reset mode (ICE colors, line wrap) }

interface

uses Classes, SysUtils, m_pdtypes;

const
  DEFAULT_WIDTH  = 80;
  DEFAULT_HEIGHT = 25;
  MAX_HEIGHT     = 65535;

  { ANSI SGR → DOS color mapping }
  ColourMap: array[0..7] of Byte = (0, 4, 2, 6, 1, 5, 3, 7);

type
  TAnsiParser = class
  private
    FCurX, FCurY:   Integer;
    FSaveX, FSaveY: Integer;
    FAttr:          TPDAttribute;
    FCanvas:        TPDCanvas;
    FClipLeft, FClipTop, FClipRight, FClipBottom: Integer;
    FLineWrap:      Boolean;
    FICEColors:     Boolean;
    FICEDetected:   Boolean;
    FLastLineData:  Boolean;
    FClearE:       TPDCanvasElement;
    
    procedure PutChar(Ch: Byte);
    procedure ProcessByte(B: Byte);
    procedure ProcessEscape(S: TStream);
    procedure ProcessSGR(const Args: array of Integer; ArgCount: Integer);
    function  ParseInt(const S: String; Default: Integer): Integer;
    procedure ClampCursor;
  public
    constructor Create;
    
    procedure LoadFromStream(S: TStream; ACanvas: TPDCanvas);
    procedure LoadFromFile(const FileName: String; ACanvas: TPDCanvas);
    
    function  GetFinalY: Integer;
    
    property  LineWrap: Boolean read FLineWrap write FLineWrap;
    property  ICEColors: Boolean read FICEColors;
    property  ICEDetected: Boolean read FICEDetected;
  end;

implementation

constructor TAnsiParser.Create;
begin
  inherited;
  FLineWrap := True;
  FICEColors := False;
  FICEDetected := False;
end;

function TAnsiParser.ParseInt(const S: String; Default: Integer): Integer;
var Code: Integer;
begin
  Val(S, Result, Code);
  if Code <> 0 then Result := Default;
  if Result = 0 then Result := Default;
end;

procedure TAnsiParser.ClampCursor;
begin
  if FCurX < FClipLeft then FCurX := FClipLeft;
  if FCurX > FClipRight then FCurX := FClipRight;
  if FCurY < FClipTop then FCurY := FClipTop;
  if FCurY > FClipBottom then FCurY := FClipBottom;
end;

procedure TAnsiParser.PutChar(Ch: Byte);
var E: TPDCanvasElement;
begin
  if (FCurX >= FClipLeft) and (FCurX <= FClipRight) then begin
    E.Ch.Ch := Ch;
    E.Attr := FAttr;
    FCanvas[FCurX, FCurY] := E;
  end;
  Inc(FCurX);
  FLastLineData := True;
  
  if FCurX > FClipRight then begin
    if FLineWrap then begin
      FCurX := FClipLeft;
      Inc(FCurY);
      FLastLineData := False;
      if FCurY > FClipBottom then begin
        FCanvas.ScrollUp(1);
        FCurY := FClipBottom;
      end;
    end else
      FCurX := FClipRight;
  end;
end;

procedure TAnsiParser.ProcessSGR(const Args: array of Integer; ArgCount: Integer);
var I, V, J: Integer;
begin
  if ArgCount = 0 then begin
    FAttr.Init(7);
    Exit;
  end;
  
  for I := 0 to ArgCount - 1 do begin
    V := Args[I];
    case V of
      0: FAttr.Init(7);
      1: FAttr.Bold := True;
      2, 22: FAttr.Bold := False;
      5: FAttr.Blink := True;
      25: FAttr.Blink := False;
      7, 27: begin
        J := FAttr.GetForegroundOnly;
        FAttr.SetForeground((FAttr.GetBackgroundOnly) or (FAttr.GetForeground and $08));
        FAttr.SetBackground(J or (FAttr.GetBackground and $08));
      end;
      30..37: begin
        FAttr.SetForeground((FAttr.GetForeground and $08) or ColourMap[V - 30]);
      end;
      40..47: begin
        FAttr.SetBackground((FAttr.GetBackground and $08) or ColourMap[V - 40]);
      end;
    end;
  end;
end;

procedure TAnsiParser.ProcessEscape(S: TStream);
var
  ParamStr: String;
  Ch: Byte;
  Args: array[0..15] of Integer;
  ArgStrs: array[0..15] of String;
  ArgCount, I, V: Integer;
  P, Start: Integer;
begin
  ParamStr := '';
  
  { Read parameter bytes until we hit a letter }
  repeat
    if S.Read(Ch, 1) <> 1 then Exit;
    if (Ch >= Ord('A')) and (Ch <= Ord('z')) then Break;
    ParamStr := ParamStr + Chr(Ch);
  until False;
  
  { Split parameters by ';' }
  ArgCount := 0;
  if ParamStr <> '' then begin
    Start := 1;
    for P := 1 to Length(ParamStr) + 1 do begin
      if (P > Length(ParamStr)) or (ParamStr[P] = ';') then begin
        if ArgCount < 16 then begin
          ArgStrs[ArgCount] := Copy(ParamStr, Start, P - Start);
          Val(ArgStrs[ArgCount], Args[ArgCount], I);
          if I <> 0 then Args[ArgCount] := 0;
          Inc(ArgCount);
        end;
        Start := P + 1;
      end;
    end;
  end;
  
  case Chr(Ch) of
    'A': begin { Cursor Up }
      V := 1; if ArgCount > 0 then V := ParseInt(ArgStrs[0], 1);
      Dec(FCurY, V);
      if FCurY < FClipTop then FCurY := FClipTop;
    end;
    
    'B': begin { Cursor Down }
      V := 1; if ArgCount > 0 then V := ParseInt(ArgStrs[0], 1);
      Inc(FCurY, V);
      if FCurY > FClipBottom then FCurY := FClipBottom;
    end;
    
    'C': begin { Cursor Forward }
      V := 1; if ArgCount > 0 then V := ParseInt(ArgStrs[0], 1);
      Inc(FCurX, V);
      if FCurX > FClipRight then FCurX := FClipRight;
    end;
    
    'D': begin { Cursor Back }
      V := 1; if ArgCount > 0 then V := ParseInt(ArgStrs[0], 1);
      Dec(FCurX, V);
      if FCurX < FClipLeft then FCurX := FClipLeft;
    end;
    
    'E': begin { Cursor Next Line }
      FCurX := FClipLeft;
      V := 1; if ArgCount > 0 then V := ParseInt(ArgStrs[0], 1);
      Inc(FCurY, V);
      while FCurY > FClipBottom do begin
        FCanvas.ScrollUp(1); Dec(FCurY);
      end;
    end;
    
    'F': begin { Cursor Previous Line }
      FCurX := FClipLeft;
      V := 1; if ArgCount > 0 then V := ParseInt(ArgStrs[0], 1);
      Dec(FCurY, V);
      if FCurY < FClipTop then FCurY := FClipTop;
    end;
    
    'G': begin { Cursor Horizontal Absolute }
      V := 1; if ArgCount > 0 then V := ParseInt(ArgStrs[0], 1);
      FCurX := FClipLeft + V - 1;
      ClampCursor;
    end;
    
    'H', 'f': begin { Cursor Position }
      if (ArgCount > 0) and (ArgStrs[0] <> '') then
        FCurY := FClipTop + ParseInt(ArgStrs[0], 1) - 1
      else
        FCurY := FClipTop;
      if (ArgCount > 1) and (ArgStrs[1] <> '') then
        FCurX := FClipLeft + ParseInt(ArgStrs[1], 1) - 1
      else
        FCurX := FClipLeft;
      ClampCursor;
    end;
    
    'J': begin { Erase in Display }
      V := 0; if ArgCount > 0 then Val(ArgStrs[0], V, I);
      case V of
        0: FCanvas.Fill(32, 7); { erase below — simplified }
        1: ; { erase above }
        2: begin { erase all }
          FAttr.Init(7);
          FCanvas.Clear;
          FCurX := FClipLeft;
          FCurY := FClipTop;
        end;
      end;
    end;
    
    'K': begin { Erase in Line }
      V := 0; if ArgCount > 0 then Val(ArgStrs[0], V, I);
      { Simplified — clear from cursor to end of line }
      begin
        FClearE.Ch.Ch := 32;
        FClearE.Attr.Init(7);
        for I := FCurX to FClipRight do
          FCanvas[I, FCurY] := FClearE;
      end;
    end;
    
    'S': begin { Scroll Up }
      V := 1; if ArgCount > 0 then V := ParseInt(ArgStrs[0], 1);
      FCanvas.ScrollUp(V);
    end;
    
    'h': begin { Set Mode }
      for I := 0 to ArgCount - 1 do begin
        if ArgStrs[I] = '?33' then begin
          FICEColors := True;
          FICEDetected := True;
        end;
        if ArgStrs[I] = '?7' then FLineWrap := True;
      end;
    end;
    
    'l': begin { Reset Mode }
      for I := 0 to ArgCount - 1 do begin
        if ArgStrs[I] = '?33' then begin
          FICEColors := False;
          FICEDetected := True;
        end;
        if ArgStrs[I] = '?7' then FLineWrap := False;
      end;
    end;
    
    'm': ProcessSGR(Args, ArgCount);
    
    's': begin { Save Cursor Position }
      if ArgCount = 0 then begin FSaveX := FCurX; FSaveY := FCurY; end;
    end;
    
    'u': begin { Restore Cursor Position }
      if ArgCount = 0 then begin FCurX := FSaveX; FCurY := FSaveY; end;
    end;
  end;
end;

procedure TAnsiParser.ProcessByte(B: Byte);
begin
  case B of
    10: begin { Line Feed }
      Inc(FCurY);
      FLastLineData := False;
      if FCurY > FClipBottom then begin
        FCanvas.ScrollUp(1);
        FCurY := FClipBottom;
      end;
      FCurX := FClipLeft;
    end;
    13, 26: ; { CR, EOF — ignore }
  else
    PutChar(B);
  end;
end;

procedure TAnsiParser.LoadFromStream(S: TStream; ACanvas: TPDCanvas);
var
  B, B2: Byte;
  DataSize: Int64;
  SavePos: Int64;
  ID: array[0..4] of Byte;
begin
  FCanvas := ACanvas;
  FClipLeft := 0;
  FClipTop := 0;
  FClipRight := ACanvas.Width - 1;
  FClipBottom := ACanvas.Height - 1;
  FAttr.Init(7);
  FCurX := 0;
  FCurY := 0;
  FSaveX := 0;
  FSaveY := 0;
  FLastLineData := False;
  
  DataSize := S.Size;
  { Check for SAUCE — don't parse it as ANSI }
  if DataSize > 128 then begin
    SavePos := S.Position;
    S.Seek(S.Size - 128, soFromBeginning);
    S.Read(ID, 5);
    if (Chr(ID[0])='S') and (Chr(ID[1])='A') and (Chr(ID[2])='U') and
       (Chr(ID[3])='C') and (Chr(ID[4])='E') then
      DataSize := S.Size - 128 - 1; { exclude SAUCE + EOF }
    S.Seek(SavePos, soFromBeginning);
  end;
  
  while S.Position < DataSize do begin
    if S.Read(B, 1) <> 1 then Break;
    
    if B = 27 then begin { ESC }
      if S.Read(B2, 1) <> 1 then Break;
      if B2 = Ord('[') then
        ProcessEscape(S)
      else begin
        ProcessByte(27);
        ProcessByte(B2);
      end;
    end else
      ProcessByte(B);
  end;
end;

procedure TAnsiParser.LoadFromFile(const FileName: String; ACanvas: TPDCanvas);
var F: TFileStream;
begin
  F := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
  try
    LoadFromStream(F, ACanvas);
  finally
    F.Free;
  end;
end;

function TAnsiParser.GetFinalY: Integer;
begin
  if FLastLineData then Result := FCurY + 1 else Result := FCurY;
end;

end.
