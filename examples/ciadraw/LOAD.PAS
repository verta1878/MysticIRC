Unit Load;

Interface
Procedure LoadFile(FileN:string; Mem:pointer; NumL:word; var MaxLine:word);
Implementation

uses Crt;

Const
   BuffLines=1000;
   BuffSize=BuffLines*160;

Type
   SegOfs = record           {structure of a pointer}
             Ofst, Segm : Word;
            end;

Var
   LngInt   : LongInt;
   TmpPtr   : Pointer;
   NumLines : Word;
   Pall2    : Array[0..255,1..3] of Byte;
   FindaSig : Boolean;
   OldTextAttr : Word;

procedure FillWord(var x; count:integer; w:word);
Begin
 Inline($c4/$be/x/$8b/$86/w/$8b/$8e/count/$fc/$f2/$ab);
End;

Function Normalized(P : Pointer) : pointer; inline
   ($58/$5A/$89/$C3/$B1/$04/$D3/$EB/$01/$DA/$25/$0F/$00);

Function Linear(P : Pointer) : LongInt;
Begin
 With SegOfs(P) do Linear := (LongInt(Segm) shl 4)+LongInt(Ofst);
End;

Function LinearToPointer(L : LongInt) : Pointer;
Begin
 LinearToPointer := Ptr(Word(L shr 4), Word(L and $0000000F));
End;

Function PtrDiff(P1, P2 : Pointer) : LongInt;
Begin
 PtrDiff := Abs(Linear(P1)-Linear(P2));
End;


Procedure LoadFile(FileN:string; Mem:pointer; NumL:word; var MaxLine:word);
   var
      Fore,Back : Byte;
      CurLine :word;
      Tmp2    :byte;
      TFileIn:file;
      AbsPtr:longint;
      TmpPtr:longint;
      TmpStr:array[1..8192] of char;
      Actual:word;
      Tmp:word;
      TmpBuf:pointer;
      Attr:byte; X,Y,SX,SY:word;
      AnsiLevel:byte;
      ParamCnt:byte;
      Params:array[1..10] of byte;

procedure PutCh(Ch:char);
begin
      case Ch of
         #8: begin
             if x>1 then
                begin
                dec(X);
                TmpPtr:=AbsPtr+((longint(Y)-1)*160)+((X-1)*2);
                char(LinearToPointer(TmpPtr)^):=' ';
                byte(LinearToPointer(TmpPtr+1)^):=TextAttr;
                end;
              end;
         #10: begin
              if Y < (NumL-1) then inc(Y);
              end;
         #13: begin
              X:=1;
              end;
         #1..#7,#11,#14..#255:
              begin
              TmpPtr:=AbsPtr+((longint(Y)-1)*160)+((X-1)*2);
              char(LinearToPointer(TmpPtr)^):=Ch;
              byte(LinearToPointer(TmpPtr+1)^):=TextAttr;
              inc(x); if X > 80 then begin X:=1; inc(Y); if y > (NumL-1) then dec(y) end;
              end;
         end;
      end;
   procedure SetColors;
      var
         Cntr : byte;
      begin
      for Cntr := 1 to ParamCnt do
         begin
          If Findasig then Textattr := OldTextattr;
         case Params[Cntr] of
         0 :  TextAttr := 7;
         1 :  TextAttr := TextAttr or $08;{asm or Attr, 08h end;}
         5 :  TextAttr := TextAttr or $80;{asm or Attr, 80h end;}
         7 :  asm
               mov  ax, word ptr TextAttr
               mov  bx, ax
               and  ax, 0707h
               xchg ah, al
               and  bx, 80h
               add  ax, bx
               mov  word ptr TextAttr, bx
              end;
         25 : TextAttr := (TextAttr AND (NOT $80)); {blink off}
         30 : TextAttr := (TextAttr AND $F8) + black;
         31 : TextAttr := (TextAttr AND $f8) + red;
         32 : TextAttr := (TextAttr AND $f8) + green;
         33 : TextAttr := (TextAttr AND $f8) + brown;
         34 : TextAttr := (TextAttr AND $f8) + blue;
         35 : TextAttr := (TextAttr AND $f8) + magenta;
         36 : TextAttr := (TextAttr AND $f8) + cyan;
         37 : TextAttr := (TextAttr AND $f8) + Lightgray;
         40 : TextAttr := (TextAttr AND $8F) + (black shl 4);
         41 : TextAttr := (TextAttr AND $8F) + (red shl 4);
         42 : TextAttr := (TextAttr AND $8F) + (green shl 4);
         43 : TextAttr := (TextAttr AND $8F) + (brown shl 4);
         44 : TextAttr := (TextAttr AND $8F) + (blue shl 4);
         45 : TextAttr := (TextAttr AND $8F) + (magenta shl 4);
         46 : TextAttr := (TextAttr AND $8F) + (cyan shl 4);
         47 : TextAttr := (TextAttr AND $8F) + (lightgray shl 4);
         end;
    If FindASig Then
       Begin
       {If (Lo(Textattr) = 0) and (Hi(TextAttr) = 0) then TextAttr := 15;}
        Fore := TextAttr And $0F;
        Back := (TextAttr Shr 4) And $08;
        OldTextattr := Textattr;
        If Fore=Back Then TextAttr := 15;
       End;
      end;
      end;
   begin
   Assign(TFileIn,FileN);
   Reset(TFileIn,1);
   AbsPtr:=Linear(Mem);
   for CurLine:=0 to NumL-1 do
      begin
       FillWord(LinearToPointer(AbsPtr+(longint(CurLine)*160))^,80,$0720);
      end;
   CurLine:=0;
   TextAttr:=$07;
   X:=1; Y:=1; AnsiLevel:=0; MaxLine:=1;
   repeat
      BlockRead(TFileIn, TmpStr, 4096, Actual);
      for Tmp:=1 to Actual do
         begin
            if TmpStr[Tmp]=#26 then break;
            case ANSILevel of
               0: begin
                  case TmpStr[Tmp] of
                     #27: ANSILevel := 1;
                     #9: if X < 80-8 then X:=( (X div 8) + 1 ) * 8;
                  else
                     PutCh(TmpStr[Tmp]);
                     end;
                  end;
               1: begin
                  if TmpStr[Tmp] = '[' then
                     begin
                     ANSILevel := 2;
                     ParamCnt := 1;
                     Params[1] := 0;
                     end
                  else
                     begin
                     {Write(#27+StIn[Cntr]);}
                     PutCH(TmpStr[Tmp]);
                     ANSILevel := 0;
                     end;
                  end;
               2: begin
                  case TmpStr[Tmp] of
                     '0'..'9': Params[ParamCnt]:=(Params[ParamCnt]*10)+(byte(TmpStr[Tmp])-48);
                     ';': begin
                          inc(ParamCnt);
                          Params[ParamCnt] := 0;
                          end;
                     'H',
                     'f': begin
                          if Params[2] > 80 then x:=80 else x:=Params[2];
                          if Params[1] > (NumL-1) then y:=NumL-1 else y:=Params[1];
                          ANSILevel := 0;
                          end;
                     'A': begin
                          if Params[1] = 0 then Params[1] := 1;
                          if (Y - Params[1]) < 1 then Y:=1 else Y:=Y - Params[1];
                          ANSILevel := 0;
                          end;
                     'B': begin
                          if Params[1] = 0 then Params[1] := 1;
                          if (Y + Params[1]) > (NumL-1) then Y:=NumL-1 else Y:=Y+Params[1];
                          ANSILevel := 0;
                          end;
                     'D': begin
                          if Params[1] = 0 then Params[1] := 1;
                          if (X - Params[1]) < 1 then X:=1 else X:=X - Params[1];
                          ANSILevel := 0;
                          end;
                     'C': begin
                          if Params[1] = 0 then Params[1] := 1;
                          if (X + Params[1]) > 80 then X:=80 else X:=X+Params[1];
                          ANSILevel := 0;
                          end;
                     'J': begin
                          case Params[1] of
                             0: for Tmp2:=X to 80 do
                                   begin
                                   TmpPtr:=AbsPtr+((longint(Y)-1)*160)+((Tmp2-1)*2);
                                   char(LinearToPointer(TmpPtr)^):=' ';
                                   byte(LinearToPointer(TmpPtr+1)^):=TextAttr;
                                   end;
                             1, {I just didn't bother today.}
                             2: begin
                                for CurLine:=0 to NumL-1 do
                                   FillWord(LinearToPointer(AbsPtr+(longint(CurLine)*160))^,80,$0720);
                                x:=1; y:=1;
                                end;
                             end;
                          ANSILevel := 0;
                          end;
                     'K': begin
                          for Tmp2:=X to 80 do
                             begin
                             TmpPtr:=AbsPtr+((longint(Y)-1)*160)+((X-1)*2);
                             char(LinearToPointer(TmpPtr)^):=' ';
                             byte(LinearToPointer(TmpPtr+1)^):=TextAttr;
                             end;
                          ANSILevel := 0;
                          end;
                     'm': begin
                          SetColors;
                          ANSILevel := 0;
                          end;
                     's': begin
                          SX:=X; SY:=Y;
                          ANSILevel := 0;
                          end;
                     'u': begin
                          X:=SX; Y:=SY;
                          ANSILevel := 0;
                          end;
                     end;
                  end;
               end;
            end;
      if y>MaxLine then MaxLine:=y;
   until eof(TFileIn) or (actual<4096);
   Close(TFileIn);
   end;
End.