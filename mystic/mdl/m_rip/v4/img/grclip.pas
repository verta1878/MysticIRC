(* grclip.pas -- Non-Rectangular Clipping Paths
   Copyright (C) 2026 fpc264irc contributors. License: GPLv3

   Polygon-based clip regions for the RIP renderer. All drawing
   primitives test against the active clip path before writing pixels.
   Supports even-odd and winding fill rules. Clip stack for push/pop.
*)

{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit grclip;

interface

const
  CLIP_MAX_POINTS = 1024;
  CLIP_MAX_STACK = 8;

type
  TClipFillRule = (cfrEvenOdd, cfrWinding);

  TClipPoint = record
    X, Y: SmallInt;
  end;

  TClipRegion = record
    Points: array[0..CLIP_MAX_POINTS - 1] of TClipPoint;
    NumPoints: Integer;
    FillRule: TClipFillRule;
    BoundsX1, BoundsY1, BoundsX2, BoundsY2: SmallInt;
    Active: Boolean;
  end;

  TClipStack = record
    Regions: array[0..CLIP_MAX_STACK - 1] of TClipRegion;
    Depth: Integer;
    Current: TClipRegion;
  end;

{ Initialize clip stack }
procedure ClipInit(var CS: TClipStack);

{ Begin a new clip path }
procedure ClipBeginPath(var CS: TClipStack);

{ Add point to current path }
procedure ClipAddPoint(var CS: TClipStack; X, Y: SmallInt);

{ Add rectangle to current path }
procedure ClipAddRect(var CS: TClipStack; X1, Y1, X2, Y2: SmallInt);

{ Add circle approximation (N-gon) }
procedure ClipAddCircle(var CS: TClipStack; CX, CY, R: SmallInt; Segments: Integer);

{ Close and activate the path }
procedure ClipEndPath(var CS: TClipStack; Rule: TClipFillRule);

{ Push current clip onto stack }
procedure ClipPush(var CS: TClipStack);

{ Pop clip from stack }
procedure ClipPop(var CS: TClipStack);

{ Reset to no clipping }
procedure ClipReset(var CS: TClipStack);

{ Test if a pixel is inside the active clip region }
function ClipTestPoint(var CS: TClipStack; X, Y: SmallInt): Boolean;

{ Test and set pixel on framebuffer (only if inside clip) }
procedure ClipSetPixel(var CS: TClipStack; Pixels: PByte;
  Width, Height: Word; X, Y: SmallInt; R, G, B: Byte);

{ Get scanline intersections for a row (for filled rendering) }
function ClipScanline(var CS: TClipStack; Y: SmallInt;
  var XIntersects: array of SmallInt): Integer;

implementation

procedure UpdateBounds(var R: TClipRegion);
var
  I: Integer;
begin
  if R.NumPoints = 0 then Exit;
  R.BoundsX1 := R.Points[0].X; R.BoundsY1 := R.Points[0].Y;
  R.BoundsX2 := R.Points[0].X; R.BoundsY2 := R.Points[0].Y;
  for I := 1 to R.NumPoints - 1 do
  begin
    if R.Points[I].X < R.BoundsX1 then R.BoundsX1 := R.Points[I].X;
    if R.Points[I].Y < R.BoundsY1 then R.BoundsY1 := R.Points[I].Y;
    if R.Points[I].X > R.BoundsX2 then R.BoundsX2 := R.Points[I].X;
    if R.Points[I].Y > R.BoundsY2 then R.BoundsY2 := R.Points[I].Y;
  end;
end;

procedure ClipInit(var CS: TClipStack);
begin
  FillChar(CS, SizeOf(CS), 0);
end;

procedure ClipBeginPath(var CS: TClipStack);
begin
  CS.Current.NumPoints := 0;
  CS.Current.Active := False;
end;

procedure ClipAddPoint(var CS: TClipStack; X, Y: SmallInt);
begin
  if CS.Current.NumPoints >= CLIP_MAX_POINTS then Exit;
  CS.Current.Points[CS.Current.NumPoints].X := X;
  CS.Current.Points[CS.Current.NumPoints].Y := Y;
  Inc(CS.Current.NumPoints);
end;

procedure ClipAddRect(var CS: TClipStack; X1, Y1, X2, Y2: SmallInt);
begin
  ClipAddPoint(CS, X1, Y1);
  ClipAddPoint(CS, X2, Y1);
  ClipAddPoint(CS, X2, Y2);
  ClipAddPoint(CS, X1, Y2);
end;

procedure ClipAddCircle(var CS: TClipStack; CX, CY, R: SmallInt; Segments: Integer);
var
  I: Integer;
  Angle: Double;
begin
  if Segments < 8 then Segments := 8;
  if Segments > CLIP_MAX_POINTS then Segments := CLIP_MAX_POINTS;
  for I := 0 to Segments - 1 do
  begin
    Angle := (I * 2 * 3.14159265) / Segments;
    ClipAddPoint(CS, CX + Round(R * Cos(Angle)), CY + Round(R * Sin(Angle)));
  end;
end;

procedure ClipEndPath(var CS: TClipStack; Rule: TClipFillRule);
begin
  CS.Current.FillRule := Rule;
  CS.Current.Active := CS.Current.NumPoints >= 3;
  UpdateBounds(CS.Current);
end;

procedure ClipPush(var CS: TClipStack);
begin
  if CS.Depth >= CLIP_MAX_STACK then Exit;
  CS.Regions[CS.Depth] := CS.Current;
  Inc(CS.Depth);
end;

procedure ClipPop(var CS: TClipStack);
begin
  if CS.Depth <= 0 then begin ClipReset(CS); Exit; end;
  Dec(CS.Depth);
  CS.Current := CS.Regions[CS.Depth];
end;

procedure ClipReset(var CS: TClipStack);
begin
  CS.Current.Active := False;
  CS.Current.NumPoints := 0;
  CS.Depth := 0;
end;

function ClipTestPoint(var CS: TClipStack; X, Y: SmallInt): Boolean;
var
  I, J, Crossings: Integer;
  X1, Y1, X2, Y2: SmallInt;
  Winding: Integer;
begin
  if not CS.Current.Active then begin Result := True; Exit; end;
  if (X < CS.Current.BoundsX1) or (X > CS.Current.BoundsX2) or
     (Y < CS.Current.BoundsY1) or (Y > CS.Current.BoundsY2) then
  begin Result := False; Exit; end;

  Crossings := 0;
  Winding := 0;
  J := CS.Current.NumPoints - 1;

  for I := 0 to CS.Current.NumPoints - 1 do
  begin
    X1 := CS.Current.Points[J].X; Y1 := CS.Current.Points[J].Y;
    X2 := CS.Current.Points[I].X; Y2 := CS.Current.Points[I].Y;

    if ((Y1 <= Y) and (Y2 > Y)) or ((Y2 <= Y) and (Y1 > Y)) then
    begin
      if X < X1 + LongInt(Y - Y1) * (X2 - X1) div (Y2 - Y1) then
      begin
        Inc(Crossings);
        if Y2 > Y1 then Inc(Winding) else Dec(Winding);
      end;
    end;
    J := I;
  end;

  case CS.Current.FillRule of
    cfrEvenOdd: Result := (Crossings and 1) = 1;
    cfrWinding: Result := Winding <> 0;
  else Result := False;
  end;
end;

procedure ClipSetPixel(var CS: TClipStack; Pixels: PByte;
  Width, Height: Word; X, Y: SmallInt; R, G, B: Byte);
var
  Offset: LongInt;
begin
  if (X < 0) or (X >= Width) or (Y < 0) or (Y >= Height) then Exit;
  if not ClipTestPoint(CS, X, Y) then Exit;
  Offset := (LongInt(Y) * Width + X) * 3;
  Pixels[Offset] := R;
  Pixels[Offset + 1] := G;
  Pixels[Offset + 2] := B;
end;

function ClipScanline(var CS: TClipStack; Y: SmallInt;
  var XIntersects: array of SmallInt): Integer;
var
  I, J: Integer;
  X1, Y1, X2, Y2: SmallInt;
  IX: SmallInt;
  Tmp: SmallInt;
begin
  Result := 0;
  if not CS.Current.Active then Exit;
  J := CS.Current.NumPoints - 1;
  for I := 0 to CS.Current.NumPoints - 1 do
  begin
    Y1 := CS.Current.Points[J].Y; Y2 := CS.Current.Points[I].Y;
    X1 := CS.Current.Points[J].X; X2 := CS.Current.Points[I].X;
    if ((Y1 <= Y) and (Y2 > Y)) or ((Y2 <= Y) and (Y1 > Y)) then
    begin
      IX := X1 + SmallInt(LongInt(Y - Y1) * (X2 - X1) div (Y2 - Y1));
      if Result <= High(XIntersects) then
      begin
        XIntersects[Result] := IX;
        Inc(Result);
      end;
    end;
    J := I;
  end;
  { Sort intersections }
  for I := 0 to Result - 2 do
    for J := I + 1 to Result - 1 do
      if XIntersects[J] < XIntersects[I] then
      begin
        Tmp := XIntersects[I]; XIntersects[I] := XIntersects[J]; XIntersects[J] := Tmp;
      end;
end;

end.
