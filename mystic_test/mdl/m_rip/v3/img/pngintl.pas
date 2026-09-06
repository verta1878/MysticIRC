(* pngintl.pas -- Interlaced PNG Streaming Decoder
   Copyright (C) 2026 fpc264irc contributors. License: GPLv3

   Decodes Adam7 interlaced PNG pass-by-pass. Each of 7 passes
   fills in more pixels. Callback fires after each pass.
*)
{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit pngintl;

interface

type
  TPNGPassCallback = procedure(Pixels: PByte; Width, Height: Word;
    PassNum: Integer; IsFinal: Boolean; UserData: Pointer);

  TPNGInterlaceState = record
    Width, Height: Word;
    Pixels: PByte;
    BPP: Byte;
    CurrentPass: Integer;
    OnPass: TPNGPassCallback;
    UserData: Pointer;
    Complete: Boolean;
  end;

{ Adam7 starting offsets and steps }
const
  Adam7XStart: array[0..6] of Byte = (0, 4, 0, 2, 0, 1, 0);
  Adam7YStart: array[0..6] of Byte = (0, 0, 4, 0, 2, 0, 1);
  Adam7XStep:  array[0..6] of Byte = (8, 8, 4, 4, 2, 2, 1);
  Adam7YStep:  array[0..6] of Byte = (8, 8, 8, 4, 4, 2, 2);

procedure PNGInterlaceInit(var S: TPNGInterlaceState;
  Width, Height: Word; BPP: Byte;
  PassCB: TPNGPassCallback; UserData: Pointer);

{ Feed decoded pass data — pixels for this pass only }
procedure PNGInterlaceFeedPass(var S: TPNGInterlaceState;
  PassNum: Integer; PassPixels: PByte;
  PassWidth, PassHeight: Word);

{ Expand pass pixels into full image using Adam7 grid }
procedure PNGInterlaceExpand(var S: TPNGInterlaceState;
  PassNum: Integer; PassPixels: PByte;
  PassWidth, PassHeight: Word);

procedure PNGInterlaceFree(var S: TPNGInterlaceState);

implementation

procedure PNGInterlaceInit(var S: TPNGInterlaceState;
  Width, Height: Word; BPP: Byte;
  PassCB: TPNGPassCallback; UserData: Pointer);
begin
  FillChar(S, SizeOf(S), 0);
  S.Width := Width;
  S.Height := Height;
  S.BPP := BPP;
  S.OnPass := PassCB;
  S.UserData := UserData;
  GetMem(S.Pixels, LongWord(Width) * Height * BPP);
  FillChar(S.Pixels^, LongWord(Width) * Height * BPP, 0);
end;

procedure PNGInterlaceExpand(var S: TPNGInterlaceState;
  PassNum: Integer; PassPixels: PByte;
  PassWidth, PassHeight: Word);
var
  X, Y, DstX, DstY: Integer;
  SrcOff, DstOff: LongInt;
  XS, YS, XSt, YSt: Integer;
  FillX, FillY, FX, FY: Integer;
begin
  if (PassNum < 0) or (PassNum > 6) then Exit;

  XS := Adam7XStart[PassNum];
  YS := Adam7YStart[PassNum];
  XSt := Adam7XStep[PassNum];
  YSt := Adam7YStep[PassNum];

  for Y := 0 to PassHeight - 1 do
  begin
    DstY := YS + Y * YSt;
    if DstY >= S.Height then Continue;

    for X := 0 to PassWidth - 1 do
    begin
      DstX := XS + X * XSt;
      if DstX >= S.Width then Continue;

      SrcOff := (LongInt(Y) * PassWidth + X) * S.BPP;
      DstOff := (LongInt(DstY) * S.Width + DstX) * S.BPP;
      Move(PassPixels[SrcOff], S.Pixels[DstOff], S.BPP);

      { Fill surrounding pixels for progressive preview }
      FillX := XSt; FillY := YSt;
      if PassNum >= 6 then begin FillX := 1; FillY := 1; end;
      for FY := 0 to FillY - 1 do
        for FX := 0 to FillX - 1 do
        begin
          if (FY = 0) and (FX = 0) then Continue;
          if (DstY + FY >= S.Height) or (DstX + FX >= S.Width) then Continue;
          DstOff := (LongInt(DstY + FY) * S.Width + DstX + FX) * S.BPP;
          Move(PassPixels[SrcOff], S.Pixels[DstOff], S.BPP);
        end;
    end;
  end;
end;

procedure PNGInterlaceFeedPass(var S: TPNGInterlaceState;
  PassNum: Integer; PassPixels: PByte;
  PassWidth, PassHeight: Word);
begin
  PNGInterlaceExpand(S, PassNum, PassPixels, PassWidth, PassHeight);
  S.CurrentPass := PassNum;
  S.Complete := (PassNum >= 6);

  if Assigned(S.OnPass) then
    S.OnPass(S.Pixels, S.Width, S.Height,
      PassNum, S.Complete, S.UserData);
end;

procedure PNGInterlaceFree(var S: TPNGInterlaceState);
begin
  if S.Pixels <> nil then begin FreeMem(S.Pixels); S.Pixels := nil; end;
end;

end.
