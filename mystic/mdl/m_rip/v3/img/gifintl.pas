(* gifintl.pas -- Interlaced GIF Streaming Decoder
   Copyright (C) 2026 fpc264irc contributors. License: GPLv3

   Decodes interlaced GIF pass-by-pass (4-pass Adam7-like).
   GIF interlace: Pass 1=rows 0,8,16... Pass 2=rows 4,12,20...
   Pass 3=rows 2,6,10... Pass 4=rows 1,3,5...
*)
{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit gifintl;

interface

type
  TGIFPassCallback = procedure(Pixels: PByte; Width, Height: Word;
    PassNum: Integer; IsFinal: Boolean; UserData: Pointer);

  TGIFInterlaceState = record
    Width, Height: Word;
    Pixels: PByte;
    CurrentPass: Integer;
    OnPass: TGIFPassCallback;
    UserData: Pointer;
    Complete: Boolean;
  end;

const
  GIFPassStart: array[0..3] of Integer = (0, 4, 2, 1);
  GIFPassStep:  array[0..3] of Integer = (8, 8, 4, 2);

procedure GIFInterlaceInit(var S: TGIFInterlaceState;
  Width, Height: Word;
  PassCB: TGIFPassCallback; UserData: Pointer);

{ Feed a complete row for the current pass }
procedure GIFInterlaceFeedRow(var S: TGIFInterlaceState;
  PassNum: Integer; RowInPass: Integer; RowPixels: PByte);

{ Mark pass complete }
procedure GIFInterlaceEndPass(var S: TGIFInterlaceState; PassNum: Integer);

procedure GIFInterlaceFree(var S: TGIFInterlaceState);

{ Deinterlace a complete buffer in-place }
procedure GIFDeinterlace(Pixels: PByte; Width, Height: Word);

implementation

procedure GIFInterlaceInit(var S: TGIFInterlaceState;
  Width, Height: Word;
  PassCB: TGIFPassCallback; UserData: Pointer);
begin
  FillChar(S, SizeOf(S), 0);
  S.Width := Width;
  S.Height := Height;
  S.OnPass := PassCB;
  S.UserData := UserData;
  GetMem(S.Pixels, LongWord(Width) * Height * 3);
  FillChar(S.Pixels^, LongWord(Width) * Height * 3, 0);
end;

procedure GIFInterlaceFeedRow(var S: TGIFInterlaceState;
  PassNum: Integer; RowInPass: Integer; RowPixels: PByte);
var
  DstRow: Integer;
  DstOff: LongInt;
  FillRows, FR: Integer;
begin
  if (PassNum < 0) or (PassNum > 3) then Exit;
  DstRow := GIFPassStart[PassNum] + RowInPass * GIFPassStep[PassNum];
  if DstRow >= S.Height then Exit;

  DstOff := LongInt(DstRow) * S.Width * 3;
  Move(RowPixels^, S.Pixels[DstOff], S.Width * 3);

  { Fill following rows for progressive preview }
  FillRows := GIFPassStep[PassNum];
  for FR := 1 to FillRows - 1 do
  begin
    if DstRow + FR >= S.Height then Break;
    DstOff := LongInt(DstRow + FR) * S.Width * 3;
    Move(RowPixels^, S.Pixels[DstOff], S.Width * 3);
  end;
end;

procedure GIFInterlaceEndPass(var S: TGIFInterlaceState; PassNum: Integer);
begin
  S.CurrentPass := PassNum;
  S.Complete := (PassNum >= 3);
  if Assigned(S.OnPass) then
    S.OnPass(S.Pixels, S.Width, S.Height, PassNum, S.Complete, S.UserData);
end;

procedure GIFInterlaceFree(var S: TGIFInterlaceState);
begin
  if S.Pixels <> nil then begin FreeMem(S.Pixels); S.Pixels := nil; end;
end;

procedure GIFDeinterlace(Pixels: PByte; Width, Height: Word);
var
  Tmp: PByte;
  BufSize: LongInt;
  SrcRow, DstRow: Integer;
  Pass: Integer;
begin
  BufSize := LongInt(Width) * Height * 3;
  GetMem(Tmp, BufSize);
  Move(Pixels^, Tmp^, BufSize);

  SrcRow := 0;
  for Pass := 0 to 3 do
  begin
    DstRow := GIFPassStart[Pass];
    while DstRow < Height do
    begin
      if SrcRow < Height then
        Move(Tmp[LongInt(SrcRow) * Width * 3],
             Pixels[LongInt(DstRow) * Width * 3], Width * 3);
      Inc(SrcRow);
      Inc(DstRow, GIFPassStep[Pass]);
    end;
  end;

  FreeMem(Tmp);
end;

end.
