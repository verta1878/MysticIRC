{$MODE OBJFPC}
{$H+}
unit mtrip;
{ mterm RIP Graphics — RIPscrip v1.54 command dispatcher
  Parses RIP commands and draws on terminal canvas.

  Copyright (C) 2026 FPC264IRC Contributors
  License: GPLv3 }

interface

uses mtterm, mtripgfx;

type
  TRIPState = record
    Active: Boolean;
    Viewport: record X1, Y1, X2, Y2: Integer; end;
    FGColor: Byte;
    BGColor: Byte;
    FillStyle: Byte;
    FillColor: Byte;
    LineStyle: Byte;
    WriteMode: Byte;
    FontStyle: Byte;
    FontSize: Byte;
  end;

  TRIPParser = class
  private
    FState: TRIPState;
    FCanvas: TRIPCanvas;
    FBuf: String;
    function ParseMegaNum(const S: String; Pos: Integer): Integer;
    procedure ExecCommand(const Cmd: String);
    { RIP commands }
    procedure CmdTextWindow(const P: String);
    procedure CmdViewport(const P: String);
    procedure CmdResetWindows;
    procedure CmdEraseWindow;
    procedure CmdEraseEOL;
    procedure CmdColor(const P: String);
    procedure CmdFillStyle(const P: String);
    procedure CmdLineStyle(const P: String);
    procedure CmdWriteMode(const P: String);
    procedure CmdFontStyle(const P: String);
    procedure CmdPixel(const P: String);
    procedure CmdLine(const P: String);
    procedure CmdRectangle(const P: String);
    procedure CmdBar(const P: String);
    procedure CmdCircle(const P: String);
    procedure CmdOval(const P: String);
    procedure CmdFilledOval(const P: String);
    procedure CmdArc(const P: String);
    procedure CmdPieSlice(const P: String);
    procedure CmdFill(const P: String);
    procedure CmdGotoXY(const P: String);
    procedure CmdHome;
    procedure CmdOutText(const P: String);
    procedure CmdOutTextXY(const P: String);
    procedure CmdMove(const P: String);
    procedure CmdButton(const P: String);
    procedure CmdMouseField(const P: String);
    procedure CmdKillMouseFields;
    procedure CmdBeginText(const P: String);
    procedure CmdGetImage(const P: String);
    procedure CmdPutImage(const P: String);
    procedure CmdPolyLine(const P: String);
    procedure CmdFilledPolygon(const P: String);
    procedure CmdBezier(const P: String);
    procedure CmdQuery(const P: String);
    procedure CmdCopyRegion(const P: String);
    procedure CmdLoadIcon(const P: String);
  public
    constructor Create;
    procedure ProcessCommand(const RIPLine: String);
    procedure Reset;
    property State: TRIPState read FState;
    property Canvas: TRIPCanvas read FCanvas;
    destructor Destroy; override;
  end;

implementation

uses SysUtils;

constructor TRIPParser.Create;
begin
  inherited;
  FCanvas := TRIPCanvas.Create;
  Reset;
end;

destructor TRIPParser.Destroy;
begin FCanvas.Free; inherited; end;

procedure TRIPParser.Reset;
begin
  FState.Active := True;
  FState.Viewport.X1 := 0;
  FState.Viewport.Y1 := 0;
  FState.Viewport.X2 := 639;
  FState.Viewport.Y2 := 349;
  FState.FGColor := 15;
  FState.BGColor := 0;
  FState.FillStyle := 1;
  FState.FillColor := 0;
  FState.LineStyle := 0;
  FState.WriteMode := 0;
  FState.FontStyle := 0;
  FState.FontSize := 1;
end;

function TRIPParser.ParseMegaNum(const S: String; Pos: Integer): Integer;
var Ch: Char; V: Integer;
begin
  Result := 0;
  if Pos > Length(S) then Exit;
  Ch := S[Pos];
  if (Ch >= '0') and (Ch <= '9') then V := Ord(Ch) - Ord('0')
  else if (Ch >= 'A') and (Ch <= 'Z') then V := Ord(Ch) - Ord('A') + 10
  else V := 0;
  Result := V;
  if Pos + 1 <= Length(S) then begin
    Ch := S[Pos + 1];
    if (Ch >= '0') and (Ch <= '9') then Result := Result * 36 + Ord(Ch) - Ord('0')
    else if (Ch >= 'A') and (Ch <= 'Z') then Result := Result * 36 + Ord(Ch) - Ord('A') + 10;
  end;
end;

procedure TRIPParser.ProcessCommand(const RIPLine: String);
var Cmd: String;
begin
  { RIPLine starts after '!|' }
  if Length(RIPLine) < 3 then Exit;
  Cmd := Copy(RIPLine, 3, Length(RIPLine) - 2); { skip '!|' }
  ExecCommand(Cmd);
end;

procedure TRIPParser.ExecCommand(const Cmd: String);
var Op: Char; Params: String;
begin
  if Length(Cmd) = 0 then Exit;
  Op := Cmd[1];
  Params := Copy(Cmd, 2, Length(Cmd) - 1);

  case Op of
    '*': CmdResetWindows;
    'w': CmdTextWindow(Params);
    'v': CmdViewport(Params);
    'e': CmdEraseWindow;
    'K': CmdEraseEOL;
    'c': CmdColor(Params);
    'S': CmdFillStyle(Params);
    'l': CmdLineStyle(Params);
    '=': CmdWriteMode(Params);
    'Y': CmdFontStyle(Params);
    'X': CmdPixel(Params);
    'L': CmdLine(Params);
    'R': CmdRectangle(Params);
    'B': CmdBar(Params);
    'C': CmdCircle(Params);
    'O': CmdOval(Params);
    'o': CmdFilledOval(Params);
    'A': CmdArc(Params);
    'I': CmdPieSlice(Params);
    'F': CmdFill(Params);
    'G': CmdGotoXY(Params);
    'H': CmdHome;
    'T': CmdOutText(Params);
    '@': CmdOutTextXY(Params);
    'M': CmdMove(Params);
    'U': CmdButton(Params);
    'm': CmdMouseField(Params);
    'P': CmdPolyLine(Params);
    'p': CmdFilledPolygon(Params);
    'Z': CmdBezier(Params);
    'Q': CmdQuery(Params);
    { 'G' CopyRegion handled via 1G below }
    'i': CmdLoadIcon(Params);
    '1': begin { Two-char commands }
      if Length(Params) > 0 then case Params[1] of
        'K': CmdKillMouseFields;
        'T': CmdBeginText(Copy(Params, 2, Length(Params) - 1));
        'G': CmdGetImage(Copy(Params, 2, Length(Params) - 1));
        'P': CmdPutImage(Copy(Params, 2, Length(Params) - 1));
        'C': CmdCopyRegion(Copy(Params, 2, Length(Params) - 1));
      end;
    end;
  end;
end;

{ RIP command implementations — store state, rendering done by terminal view }

procedure TRIPParser.CmdResetWindows;
begin Reset; FCanvas.Clear(0); end;

procedure TRIPParser.CmdTextWindow(const P: String);
begin { x0 y0 x1 y1 wrap size } end;

procedure TRIPParser.CmdViewport(const P: String);
begin
  if Length(P) >= 8 then begin
    FState.Viewport.X1 := ParseMegaNum(P, 1);
    FState.Viewport.Y1 := ParseMegaNum(P, 3);
    FState.Viewport.X2 := ParseMegaNum(P, 5);
    FState.Viewport.Y2 := ParseMegaNum(P, 7);
  end;
end;

procedure TRIPParser.CmdEraseWindow; begin FCanvas.Clear(FState.BGColor); end;
procedure TRIPParser.CmdEraseEOL; begin end;

procedure TRIPParser.CmdColor(const P: String);
begin if Length(P) >= 2 then begin FState.FGColor := ParseMegaNum(P, 1); FCanvas.SetColor(FState.FGColor); end; end;

procedure TRIPParser.CmdFillStyle(const P: String);
begin
  if Length(P) >= 4 then begin
    FState.FillStyle := ParseMegaNum(P, 1);
    FState.FillColor := ParseMegaNum(P, 3);
    FCanvas.SetFillStyle(FState.FillStyle, FState.FillColor);
  end;
end;

procedure TRIPParser.CmdLineStyle(const P: String);
begin if Length(P) >= 2 then FState.LineStyle := ParseMegaNum(P, 1); end;

procedure TRIPParser.CmdWriteMode(const P: String);
begin if Length(P) >= 2 then FState.WriteMode := ParseMegaNum(P, 1); end;

procedure TRIPParser.CmdFontStyle(const P: String);
begin
  if Length(P) >= 4 then begin
    FState.FontStyle := ParseMegaNum(P, 1);
    FState.FontSize := ParseMegaNum(P, 5);
  end;
end;

procedure TRIPParser.CmdPixel(const P: String); begin if Length(P)>=4 then FCanvas.PutPixel(ParseMegaNum(P,1), ParseMegaNum(P,3), FState.FGColor); end;
procedure TRIPParser.CmdLine(const P: String); begin if Length(P)>=8 then FCanvas.Line(ParseMegaNum(P,1), ParseMegaNum(P,3), ParseMegaNum(P,5), ParseMegaNum(P,7)); end;
procedure TRIPParser.CmdRectangle(const P: String); begin if Length(P)>=8 then FCanvas.Rectangle(ParseMegaNum(P,1), ParseMegaNum(P,3), ParseMegaNum(P,5), ParseMegaNum(P,7)); end;
procedure TRIPParser.CmdBar(const P: String); begin if Length(P)>=8 then FCanvas.Bar(ParseMegaNum(P,1), ParseMegaNum(P,3), ParseMegaNum(P,5), ParseMegaNum(P,7)); end;
procedure TRIPParser.CmdCircle(const P: String); begin if Length(P)>=6 then FCanvas.Circle(ParseMegaNum(P,1), ParseMegaNum(P,3), ParseMegaNum(P,5)); end;
procedure TRIPParser.CmdOval(const P: String); begin if Length(P)>=8 then FCanvas.Ellipse(ParseMegaNum(P,1), ParseMegaNum(P,3), ParseMegaNum(P,5), ParseMegaNum(P,7)); end;
procedure TRIPParser.CmdFilledOval(const P: String); begin if Length(P)>=8 then FCanvas.FilledEllipse(ParseMegaNum(P,1), ParseMegaNum(P,3), ParseMegaNum(P,5), ParseMegaNum(P,7)); end;
procedure TRIPParser.CmdArc(const P: String); begin end;
procedure TRIPParser.CmdPieSlice(const P: String); begin end;
procedure TRIPParser.CmdFill(const P: String); begin if Length(P)>=6 then FCanvas.FloodFill(ParseMegaNum(P,1), ParseMegaNum(P,3), ParseMegaNum(P,5)); end;
procedure TRIPParser.CmdGotoXY(const P: String); begin end;
procedure TRIPParser.CmdHome; begin end;
procedure TRIPParser.CmdOutText(const P: String); begin end;
procedure TRIPParser.CmdOutTextXY(const P: String); begin end;
procedure TRIPParser.CmdMove(const P: String); begin end;
procedure TRIPParser.CmdButton(const P: String); begin end;
procedure TRIPParser.CmdMouseField(const P: String); begin end;
procedure TRIPParser.CmdKillMouseFields; begin end;
procedure TRIPParser.CmdBeginText(const P: String); begin end;
procedure TRIPParser.CmdGetImage(const P: String); begin end;
procedure TRIPParser.CmdPutImage(const P: String); begin end;
procedure TRIPParser.CmdPolyLine(const P: String); begin end;
procedure TRIPParser.CmdFilledPolygon(const P: String); begin end;
procedure TRIPParser.CmdBezier(const P: String); begin end;
procedure TRIPParser.CmdQuery(const P: String); begin end;
procedure TRIPParser.CmdCopyRegion(const P: String); begin end;
procedure TRIPParser.CmdLoadIcon(const P: String); begin end;

end.
