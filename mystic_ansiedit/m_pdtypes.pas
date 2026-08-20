{$MODE OBJFPC}
{$H+}
unit m_pdtypes;
{$MODESWITCH ADVANCEDRECORDS}
{ PabloDraw Pascal — Core Types
  Converted from PabloDraw C# by cwensley
  Original: MIT License }

interface

type
  { Character cell — one position on screen }
  TPDCharacter = packed record
    Ch: SmallInt;  { character code (CP437 or Unicode) }
  end;

  { Text attribute — foreground + background color }
  TPDAttribute = packed record
    FForeground: Byte;
    FBackground: Byte;
    procedure Init(AByte: Byte);
    procedure InitColors(AFg, ABg: Integer);
    procedure InitFull(AFg, ABg: Byte; ABold, ABlink: Boolean);
    function  ToByte: Byte;
    function  GetForeground: Integer;
    procedure SetForeground(Value: Integer);
    function  GetBackground: Integer;
    procedure SetBackground(Value: Integer);
    function  GetForegroundOnly: Integer;
    function  GetBackgroundOnly: Integer;
    function  GetBold: Boolean;
    procedure SetBold(Value: Boolean);
    function  GetBlink: Boolean;
    procedure SetBlink(Value: Boolean);
    function  Equals(const Other: TPDAttribute): Boolean;
    property  Foreground: Integer read GetForeground write SetForeground;
    property  Background: Integer read GetBackground write SetBackground;
    property  Bold: Boolean read GetBold write SetBold;
    property  Blink: Boolean read GetBlink write SetBlink;
  end;

  { Canvas element — character + attribute pair }
  TPDCanvasElement = packed record
    Ch:   TPDCharacter;
    Attr: TPDAttribute;
  end;

  { Canvas — 2D grid of character cells }
  PPDCanvasElement = ^TPDCanvasElement;
  
  TPDCanvas = {$IFDEF CPU16}object{$ELSE}class{$ENDIF}
    FWidth: Integer;
    FHeight: Integer;
    FData: array of TPDCanvasElement;
    function GetElement(X, Y: Integer): TPDCanvasElement;
    procedure SetElement(X, Y: Integer; const Value: TPDCanvasElement);
    constructor Create(AWidth, AHeight: Integer);
    procedure Resize(AWidth, AHeight: Integer);
    procedure Clear;
    procedure Fill(ACh: SmallInt; AAttr: Byte);
    procedure ScrollUp(Lines: Integer);
    procedure TrimHeight(NewHeight: Integer);
    property Width: Integer read FWidth;
    property Height: Integer read FHeight;
    property Elements[X, Y: Integer]: TPDCanvasElement read GetElement write SetElement; default;
  end;

  { SAUCE metadata }
  TSauceInfo = packed record
    ID:        array[0..4] of Char;   { 'SAUCE' }
    Version:   array[0..1] of Char;   { '00' }
    Title:     array[0..34] of Char;
    Author:    array[0..19] of Char;
    Group:     array[0..19] of Char;
    Date:      array[0..7] of Char;
    FileSize:  LongInt;
    DataType:  Byte;
    FileType:  Byte;
    TInfo1:    Word;
    TInfo2:    Word;
    TInfo3:    Word;
    TInfo4:    Word;
    Comments:  Byte;
    TFlags:    Byte;
    TInfoS:    array[0..21] of Char;
  end;
  PSauceInfo = ^TSauceInfo;

  { EGA palette — 16 RGB colors }
  TPDColor = packed record
    R, G, B: Byte;
  end;
  TPDPalette = array[0..255] of TPDColor;

const
  { Standard EGA/VGA 16-color palette }
  DefaultPalette: array[0..15] of TPDColor = (
    (R:   0; G:   0; B:   0),  { 0  Black }
    (R:   0; G:   0; B: 170),  { 1  Blue }
    (R:   0; G: 170; B:   0),  { 2  Green }
    (R:   0; G: 170; B: 170),  { 3  Cyan }
    (R: 170; G:   0; B:   0),  { 4  Red }
    (R: 170; G:   0; B: 170),  { 5  Magenta }
    (R: 170; G:  85; B:   0),  { 6  Brown }
    (R: 170; G: 170; B: 170),  { 7  Light Gray }
    (R:  85; G:  85; B:  85),  { 8  Dark Gray }
    (R:  85; G:  85; B: 255),  { 9  Light Blue }
    (R:  85; G: 255; B:  85),  { 10 Light Green }
    (R:  85; G: 255; B: 255),  { 11 Light Cyan }
    (R: 255; G:  85; B:  85),  { 12 Light Red }
    (R: 255; G:  85; B: 255),  { 13 Light Magenta }
    (R: 255; G: 255; B:  85),  { 14 Yellow }
    (R: 255; G: 255; B: 255)   { 15 White }
  );

implementation

{ ---- TPDAttribute ---- }

procedure TPDAttribute.Init(AByte: Byte);
begin
  FForeground := AByte and $0F;
  FBackground := (AByte shr 4) and $0F;
end;

procedure TPDAttribute.InitColors(AFg, ABg: Integer);
begin
  FForeground := Byte(AFg);
  FBackground := Byte(ABg);
end;

procedure TPDAttribute.InitFull(AFg, ABg: Byte; ABold, ABlink: Boolean);
begin
  FForeground := AFg and $07;
  FBackground := ABg and $07;
  if ABold then FForeground := FForeground or $08;
  if ABlink then FBackground := FBackground or $08;
end;

function TPDAttribute.ToByte: Byte;
begin
  Result := (FForeground and $0F) or ((FBackground and $0F) shl 4);
end;

function TPDAttribute.GetForeground: Integer; begin Result := FForeground; end;
procedure TPDAttribute.SetForeground(Value: Integer); begin FForeground := Byte(Value); end;
function TPDAttribute.GetBackground: Integer; begin Result := FBackground; end;
procedure TPDAttribute.SetBackground(Value: Integer); begin FBackground := Byte(Value); end;

function TPDAttribute.GetForegroundOnly: Integer;
begin if FForeground < 16 then Result := FForeground and $07 else Result := FForeground; end;

function TPDAttribute.GetBackgroundOnly: Integer;
begin if FBackground < 16 then Result := FBackground and $07 else Result := FBackground; end;

function TPDAttribute.GetBold: Boolean;
begin Result := (FForeground < 16) and ((FForeground and $08) <> 0); end;

procedure TPDAttribute.SetBold(Value: Boolean);
begin
  if FForeground < 16 then begin
    FForeground := FForeground and $0F;
    if Value then FForeground := FForeground or $08
    else FForeground := FForeground and $07;
  end;
end;

function TPDAttribute.GetBlink: Boolean;
begin Result := (FBackground < 16) and ((FBackground and $08) <> 0); end;

procedure TPDAttribute.SetBlink(Value: Boolean);
begin
  if FBackground < 16 then begin
    FBackground := FBackground and $0F;
    if Value then FBackground := FBackground or $08
    else FBackground := FBackground and $07;
  end;
end;

function TPDAttribute.Equals(const Other: TPDAttribute): Boolean;
begin Result := (FForeground = Other.FForeground) and (FBackground = Other.FBackground); end;

{ ---- TPDCanvas ---- }

{$IFDEF CPU16}procedure{$ELSE}constructor{$ENDIF} TPDCanvas.Create(AWidth, AHeight: Integer);
begin
  inherited Create;
  Resize(AWidth, AHeight);
end;

procedure TPDCanvas.Resize(AWidth, AHeight: Integer);
begin
  FWidth := AWidth;
  FHeight := AHeight;
  {$IFNDEF CPU16}SetLength(FData, FWidth * FHeight);{$ENDIF}
  Clear;
end;

procedure TPDCanvas.Clear;
var I: Integer;
begin
  for I := 0 to Length(FData) - 1 do begin
    FData[I].Ch.Ch := 32;
    FData[I].Attr.Init(7);
  end;
end;

procedure TPDCanvas.Fill(ACh: SmallInt; AAttr: Byte);
var I: Integer;
begin
  for I := 0 to Length(FData) - 1 do begin
    FData[I].Ch.Ch := ACh;
    FData[I].Attr.Init(AAttr);
  end;
end;

procedure TPDCanvas.ScrollUp(Lines: Integer);
var I: Integer;
begin
  if Lines >= FHeight then begin Clear; Exit; end;
  for I := 0 to (FHeight - Lines) * FWidth - 1 do
    FData[I] := FData[I + Lines * FWidth];
  for I := (FHeight - Lines) * FWidth to FHeight * FWidth - 1 do begin
    FData[I].Ch.Ch := 32;
    FData[I].Attr.Init(7);
  end;
end;

procedure TPDCanvas.TrimHeight(NewHeight: Integer);
begin
  if NewHeight < 1 then NewHeight := 1;
  if NewHeight < FHeight then begin
    FHeight := NewHeight;
    {$IFNDEF CPU16}SetLength(FData, FWidth * FHeight);{$ENDIF}
  end;
end;

function TPDCanvas.GetElement(X, Y: Integer): TPDCanvasElement;
begin
  if (X >= 0) and (X < FWidth) and (Y >= 0) and (Y < FHeight) then
    Result := FData[Y * FWidth + X]
  else begin
    Result.Ch.Ch := 32;
    Result.Attr.Init(0);
  end;
end;

procedure TPDCanvas.SetElement(X, Y: Integer; const Value: TPDCanvasElement);
begin
  if (X >= 0) and (X < FWidth) and (Y >= 0) and (Y < FHeight) then
    FData[Y * FWidth + X] := Value;
end;

end.
