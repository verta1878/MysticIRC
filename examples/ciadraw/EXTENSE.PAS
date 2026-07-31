Unit Extense;

Interface

Var Screen : Array[0..$b800] of byte absolute $b800:0000;

Procedure InputNums(var Lne : String;Chars : Byte);
Function  VGACard : Boolean;
Procedure WaitRetrace;
Procedure SetTypeRate(Kdelay, Krate:Byte);
Procedure InputLn(var Lne : String ; Chars : Byte ; Caps : Boolean ; Allcaps : Boolean);
Procedure GetKeys(Var C1 : Char;Var C2 : Char);
Function  ScrollLock : Boolean;
Function  CapsLock   : Boolean;
Function  InsKey     : Boolean;
Procedure Clear_Keyboard_Buffer;
Procedure ChangeMode(Mode : Word);
Function  Uppercase(Str : String) : String;
Procedure Clear_Column(Column : Byte);
Procedure Blinking(State : Boolean);
Function  Yesno : Boolean;
Procedure Beep(Freq,Dely : Word);
Procedure Yescursor;
Procedure Setcursorshape(shape : word);
Procedure Nocursor;
Procedure Uncrunch(var Addr1,Addr2; BlkLen:Integer);
Function  Padstring(Outp : String;Number : Byte): String;
Procedure PipeWrite(S : String);
Procedure qwrite(x,y:byte;s:string;f,b:byte;CharsperRow:Word);
Procedure FastMove(VAR source;VAR dest;numToMove : WORD);
Function  LeadingZero(w : Word) : String;
procedure mousesensetivity(x,y:word);
Procedure Column_Clear;
Procedure Row_Clear;
Procedure Close_Horizontal;
Procedure RollUp;
Procedure Close_Vertical;

Implementation
Uses dos,crt;

Var Kb : Byte Absolute $0040:$0017;

Function LeadingZero(W : Word) : String;
Var S : String;
Begin
 Str(w:0,S);
 If Length(s) = 1 then S := '0'+S;
 LeadingZero := S;
End;

Function Uppercase(Str : String) : String;
Var X : Byte;
Begin
 For X := 1 to Length(Str) do Str[X] := Upcase(Str[X]);
 Uppercase := Str;
End;

Procedure Mousesensetivity(x,y:word); Assembler;
Asm
 mov ax,1ah;
 mov bx,x;
 mov cx,y;
 xor dx,dx;
 int 33h
end;

Procedure ChangeMode(Mode : Word);Assembler;
Asm
 mov ax,mode
 int 10h
End;

Procedure Setcursorshape(Shape : word);Assembler;
Asm
 mov ah,1;
 mov cx,shape;
 int 10h;
End;

Function CapsLock : Boolean;
Begin
 if (Kb and $40) = $40 then Capslock := True else Capslock := False;
End;

Function ScrollLock : Boolean;
Begin
 If (Kb and $10) = $10 then ScrollLock := True Else ScrollLock := False;
End;

Function Inskey : Boolean;
Function ShiftState: Byte;
Var Regs: Registers;
Begin
  Regs.Ah:=2;
  Intr($16, Regs);
  ShiftState:=Regs.Al;
End;
Begin
 InsKey :=(ShiftState and 128)<>0;
End;

Procedure SetTypeRate(Kdelay, Krate:Byte);Assembler;
asm
 Mov AX,$0305;
 Mov BH, Kdelay;
 Mov BL, Krate;
 Int $16;
End;

Procedure Blinking(State : Boolean);Assembler;
Asm
 MOV AX,1003h
 MOV BH,0
 MOV BL,State
 INT 10h
End;

Procedure GetKeys(Var C1 : Char;Var C2 : Char);
Begin
 C1 := #0;C2 := #0;
 C1 := Readkey;If C1 = #0 then C2 := Readkey;
End;

Function Padstring(Outp : String;Number : Byte): String;
Var X : Byte;
Begin
 For X := 1 to (Number - Length(Outp)) do Outp := Outp + ' ';
 Padstring := Outp;
End;

Procedure Clear_Keyboard_Buffer;
Begin
 MemW[$0000:$041C] := MemW[$0000:$041A];
End;

Function VGACard : Boolean;
Var VideoCard : Byte;
  Begin
   Asm
    MOV AX,1A00h
    INT 10h
    CMP AL,08h
    JNZ @VGA
    MOV VideoCard,0
    JMP @DONE
   @VGA:
    MOV VideoCard,1
   @DONE:
   End;
  If VideoCard = 1 then VGACard := True Else VGACard := False;
End;

Procedure NoCursor;Assembler;
Asm
 mov ah,$01
 mov cx,$2000
 Int $10
End;

Procedure YesCursor;  Assembler;
asm
 mov      ah,$01
 mov      ch,$06
 mov      cl,$07
 int      $10
end;

Procedure InputNums(var Lne : String;Chars : Byte);
Var StartedX,X,Y,Counter : Byte;
    CH       : Char;
    P        : String;
    Done     : Boolean;
Begin
YesCursor;
P := '';
Counter := 0;
StartedX := WhereX;
For X := 1 to Chars do Write(' ');
GotoXy(StartedX,WhereY);
Done := False;
Repeat
 X := WhereX;
 Y := WhereY;
 Clear_Keyboard_Buffer;
 CH := Readkey;
 Case CH of
    #8 : If Counter > 0 then
         Begin
          GotoXy(X-1,Y);Write(' ');
          GotoXy(X-1,Y);Delete(P,Length(P),1);
          Dec(Counter);
         End;
   #13 : Done := True;
   #27 : Begin
          P := 'Aborted';
          Done := True;
         End;
 #48..#57 : If Counter < Chars then
             Begin
              Inc(Counter);
              P := P+(CH);
              Write(CH);
             End;
  End; {Case}
 Until (Done = True);
 Lne := P;
 GotoXy(StartedX,WhereY);
 For X := 1 to Chars do Write(' ');
 If Lne <> 'Aborted' then
  Begin
   GotoXy(StartedX,WhereY);
   Write(Lne);
  End;
 Nocursor;
End;

Procedure PipeWrite(S : String);
Var X,Code : Byte;
    Error  : Integer;
Begin
For X := 1 to Length(S) do
 Begin
  If S[X] <> '|' then Write(S[X])
   Else Begin
         Val(Copy(S,X + 1,2),Code,Error);
         If Error>0 then Write(S[X])
                     Else Begin
                            If Code<16 then Textcolor(Code)
                             Else Textbackground(Code-16);
                            If X + 2 > Length(S) then Inc(X,1) else Inc(X,2);
                           End;
        End;
 End;
End;

Procedure Uncrunch(var Addr1,Addr2; BlkLen:Integer);
Begin
  inline (
    $1E/$C5/$B6/ADDR1/$C4/$BE/ADDR2/$8B/$8E/BLKLEN/$E3/$5B/$8B/$D7/
    $33/$C0/$FC/$AC/$3C/$20/$72/$05/$AB/$E2/$F8/$EB/$4C/$3C/$10/
    $73/$07/$80/$E4/$F0/$0A/$E0/$EB/$F1/$3C/$18/$74/$13/$73/$19/
    $2C/$10/$02/$C0/$02/$C0/$02/$C0/$02/$C0/$80/$E4/$8F/$0A/$E0/
    $EB/$DA/$81/$C2/$A0/$00/$8B/$FA/$EB/$D2/$3C/$1B/$72/$07/$75/$CC/
    $80/$F4/$80/$EB/$C7/$3C/$19/$8B/$D9/$AC/$8A/$C8/$B0/$20/$74/$02/
    $AC/$4B/$32/$ED/$41/$F3/$AB/$8B/$CB/$49/$E0/$AA/$1F);
End;

Procedure InputLn(var Lne : String;Chars:Byte;Caps:Boolean;Allcaps:Boolean);
Var
 StartedX,X,Y,Counter,OldAttr : Byte;
 CH   : Char;
 P    : String;
 Done : boolean;
Begin
 OldAttr  := Textattr;
 StartedX := WhereX;
 P        := '';
 Counter  := 0;
 Yescursor;
 Done := False;
 For X := 1 to Chars do Write(' ');GotoXy(StartedX,WhereY);
Repeat
 X := WhereX;
 Y := WhereY;
 Clear_Keyboard_Buffer;
 CH := Readkey;If CH = #0 then CH := Readkey;
 Case CH of
  #8 : If Counter > 0 then
        Begin
         GotoXy(X-1,Y);Write(' ');
         GotoXy(X-1,Y);Delete(P,Length(P),1);
         Dec(Counter);
        End;
 #13 : Done := True;
 #27 : Begin
        P := 'Aborted';
        Done := True;
       End;
 #32..#126 : If Counter < Chars then
              Begin
               Inc(Counter);
               If Caps then If (P[Counter-1]=#0) or (P[Counter-1]=#32) or (P[Counter-1]=',') then
                CH := Upcase(CH);
               If Allcaps then CH := Upcase(CH);
               P := P + (CH);
               Write(CH);
              End;
     End;
 Until Done = True;
 Lne := P;
 GotoXy(StartedX,WhereY);
 Textattr := 7;For X := 1 to Chars do Write(' ');
 If Lne <> 'Aborted' then Begin
                            GotoXy(StartedX,WhereY);
                            Write(Lne);
                          End;
 Nocursor;
 Textattr := OldAttr;
End;

Procedure WaitRetrace; assembler;
asm
 mov dx,3DAh
 @l1: in al,dx;and al,08h;jnz @l1
 @l2: in al,dx;and al,08h;jz  @l2
end;

Procedure FastMove(VAR source;VAR dest;numToMove : WORD);
Begin
 Inline($8C/$DA/$C5/$B6/>SOURCE/$C4/$BE/>DEST/$8B/$8E/>NUMTOMOVE);
 Inline($39/$FE/$72/$08/$FC/$D1/$E9/$73/$11/$A4/$EB/$0E/$FD/$01/$CE);
 Inline($4E/$01/$CF/$4F/$D1/$E9/$73/$01/$A4/$4E/$4F/$F2/$A5/$8E/$DA);
End;

Procedure qwrite(x, y : byte; s : string; f, b : byte;CharsperRow : Word);
Var
  Cnter,Attrib  : Word;
  VidPtr : ^Word;
Begin
  attrib := swap((b shl 4) + f);
  vidptr := ptr($B800, 2 * (CharsPerRow * pred(y) + pred(x)));
  If lastmode = 7 then dec(longint(vidptr), $08000000);
  For cnter := 1 to length(s) do
  Begin
   vidptr^ := attrib or byte (s[cnter]);
   inc(vidptr);
  End;
End;

Procedure Beep(Freq,Dely : Word);
Begin
 Sound(Freq);
 Delay(Dely);
 Nosound;
End;

Function Yesno : Boolean;
Var X,Y : Byte;
    CH : Char;
    Yes : Boolean;
Label GetaKey,Ending;
Begin
X := WhereX;
Y := WhereY;
GotoXy(X,Y);PipeWrite('|15|17 Yes |16|07 No ');
Yes := True;
While not (CH in['Y','N',#13]) do
Begin
 CH := Readkey;If CH = #0 then CH := Readkey;CH := Upcase(CH);
 If CH in[#75,'Y'] then Yes := True;
 If CH in[#77,'N'] then Yes := False;
 GotoXy(X,Y);
 If Yes then Begin
              Textattr := $1F;Write(' Yes ');
              Textattr := $7;Write(' No ');
             End
        else Begin
              Textattr := $7;Write(' Yes ');
              Textattr := $1F;Write(' No ');
             End;
End;
Textcolor(7);Textbackground(0);
Yesno := Yes;
End;

Procedure Row_Clear;
Const Lines : Array[1..25] of Byte =
(1,3,5,7,9,11,13,15,17,19,21,23,25,24,22,20,18,16,14,12,10,8,6,4,2);
Var X : Byte;
Begin
 For X := 1 to 25 do Begin
                      GotoXy(1,Lines[X]);
                      ClrEol;
                      Delay(50);
                     End;
End;

Procedure RollUp;
Var X,Y : Integer;
Begin
 For X := 1 to 40 do
 For Y := 0 to 25 do
 Begin
  Move(Mem[$B800:((Y*160)+ 82)],Mem[$B800:((Y*160)+80)],80);
  Move(Mem[$B800:((Y*160))],Mem[$B800:((Y*160)+2)],80);
  Mem[$b800:(Y*160)+1] := 0;
  Mem[$b800:(Y*160)+158] := 0;
  Delay(1);
 End;
End;

Procedure Clear_Column(Column : Byte);
Var X : Byte;
Begin
 For X := 1 to 25 do
   Begin
    GotoXy(Column,X);
    If Column < 80 then Write(#0);
   End;
End;

Procedure Column_Clear;
Const Column : Array[1..80] of Byte =
 (1,3,5,7,9,11,13,15,17,19,21,23,25,27,29,31,33,35,37,39,41,43,45,47,49,51,
  53,55,57,59,61,63,65,67,69,71,73,75,77,79,80,78,76,74,72,70,68,66,64,62,
  60,58,56,54,52,50,48,46,44,42,40,38,36,34,32,30,28,26,24,22,20,18,16,14,
  12,10,8,6,4,2);
var P : Byte;
Begin
 For P := 1 to 160 do
 Begin
  Clear_Column(Column[P]);
  Delay(5);
 End;
End;

Procedure Close_Vertical;
Const Column : Array[1..80] of Byte =
 (1,80,2,79,3,78,4,77,5,76,6,75,7,74,8,73,9,72,10,71,11,70,12,69,13,
 68,14,67,15,66,16,65,17,64,18,63,19,62,20,61,21,60,22,59,23,58,24,57,
 25,56,26,55,27,54,28,53,29,52,30,51,31,50,32,49,33,48,34,47,35,46,36,
 45,37,44,38,43,39,42,40,41);
Var X : Byte;
Begin
 For X := 1 to 80 do Begin
                      Clear_Column(Column[X]);
                      Delay(5);
                     End;
End;

Procedure Close_Horizontal;
Const Row : Array[1..25] of Byte =
 (1,25,2,24,3,23,4,22,5,21,6,20,7,19,8,18,9,17,10,16,11,15,12,14,13);
Var P : Byte;
Begin
For P := 1 to 25 do Begin
                     GotoXy(1,Row[P]);
                     ClrEol;
                     Delay(10);
                    End;
End;
End.