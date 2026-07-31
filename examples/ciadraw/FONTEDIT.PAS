Unit FontEdit;

Interface
 Procedure EditFont;
Implementation

Uses Dos,Crt,Extense,FontUnit;

Const AsciiCode : Array[1..16,1..14] of Byte =
 ((218,191,192,217,196,179,195,180,193,194,201,187,200,188),
  (205,186,204,185,202,203,213,184,212,190,205,179,198,181),
  (207,209,214,183,211,189,196,186,199,182,208,210,197,206),
  (216,215,232,233,155,156,153,239,176,177,178,219,223,220),
  (221,222,254,250,001,002,003,004,005,006,240,127,014,015),
  (024,025,030,031,016,017,018,029,020,021,174,175,242,243),
  (169,170,253,246,171,172,227,241,244,245,234,157,228,248),
  (251,252,224,225,226,229,230,231,235,236,237,238,128,135),
  (165,164,152,159,247,249,173,168,131,132,133,160,166,134),
  (142,143,145,146,136,137,138,130,144,140,139,141,161,158),
  (147,148,149,162,167,150,129,151,163,154,065,066,067,068),
  (069,070,071,072,073,074,075,076,077,078,079,080,081,082),
  (083,084,085,086,087,088,089,090,097,098,099,100,101,102),
  (103,104,105,106,107,108,109,110,111,112,113,114,115,116),
  (117,118,119,120,121,122,048,049,050,051,052,053,054,055),
  (056,057,000,000,000,000,000,000,000,000,000,000,000,000));

Var
  FontXPos,
  FontYPos : Byte;
  Mode     : Byte;
  Ascii    : Byte;
  C1,C2    : Char;

Function GetBitA(var a;Bit:Word):Boolean;assembler;
Const Bits:array[0..7] of Byte = ($1,$2,$4,$8,$10,$20,$40,$80);
asm
  Les di,a
  Mov si,bit
  Mov bx,si
  And si,07h
  Shr bx,03h
  Mov al,Byte(Bits[si])
  And al,es:[di+bx]
end;

Procedure InvertBitA(var a;Bit:Word);assembler;
Const Bits:array[0..7] of Byte = ($1,$2,$4,$8,$10,$20,$40,$80);
asm
  Les di,a
  Mov si,bit
  Mov bx,si
  And si,07h
  Shr bx,03h
  Mov al,Byte(Bits[si])
  Xor es:[di+bx],al
end;

Procedure ShowFont(Character : Byte);
Var X,Y : Byte;
Begin
 GetImageChar(Character,CharSet);
 GotoXy(1,1);
 For X := 1 to 16 do
  For Y := 0 to 7 do
     If (GetbitA(Charset[0].Data[X],Y)) then Qwrite(32-(7+(Y*3)),X+3,'ллл',15,0,80)
                                           else Qwrite(32-(7+(Y*3)),X+3,'ллл',8,0,80);
End;

Procedure ShowFont2(Character : Byte);
Var X,Y : Byte;
Begin
 GotoXy(1,1);
 For X := 1 to 16 do
  For Y := 0 to 7 do
     If (GetbitA(DefaultCharset[Character].Data[X],Y)) then Qwrite(82-(7+(Y*3)),X+3,'ллл',15,0,80)
                                            else Qwrite(82-(7+(Y*3)),X+3,'ллл',8,0,80);
End;

Function FileExist(FileName : String) : Boolean; ASSEMBLER;
Asm
  PUSH DS          {Save DS                         }
  LDS  SI,Filename {DS:SI => Filename               }
  XOR  BX,BX       {Clear BX                        }
  MOV  BL,[SI]     {BX = Length(Filename)           }
  INC  SI          {DS:SI => Filename[1]            }
  MOV  DX,SI       {DS:DX => Filename[1]            }
  MOV  [SI+BX],BH  {Append Ascii 0 to Filename      }
  MOV  AX,4300h    {Get Attribute Function Code     }
  INT  21h         {Get File Attributes             }
  MOV  AL,BH       {Default Result = FALSE          }
  ADC  CL,CL       {Attribute * 2 + Carry Flag      }
  AND  CL,31h      {Directory or VolumeID or Failed }
  JNZ  @@Done      {Yes - Exit                      }
  INC  AL          {No - Change Result to TRUE      }
@@Done:
  POP  DS          {Restore DS                      }
End; {FileExists}


Procedure Fontscrn;External;{$L FONTSCRN.OBJ}

Var Active : Byte; { Active Char }
    CH : Char;

Procedure Display;
Var X,Y : Byte;
Begin
 For Y := 1 to 16 do
  For X := 1 to 14 do
   Begin
    If Active = X+(Y*14-14) then Begin
                                  WaitRetrace;
                                  Ascii := AsciiCode[Y,X];
                                  ShowFont(Ascii);
                                  Qwrite((1+(FontXPos*3)),FontYPos+3,'ллл',7,0,80);
                                  ShowFont2(AsciiCOde[Y,X]);
                                  Qwrite(33+X,3+Y,Chr(AsciiCode[Y,X]),15,1,80);
                                 End
                            else Qwrite(33+X,3+Y,Chr(AsciiCode[Y,X]),15,7,80);
   End;
End;

Procedure SelectChar;
Begin
  Case C2 of
   #72 : If Active > 14 then Dec(Active,14);
   #80 : If Active < 199 then Inc(Active,14);
   #75 : If Active > 1 then Dec(Active);
   #77 : If Active < 212 then Inc(Active);
  End;
End;

Procedure SelectPos;
Begin
 Case C2 of
   #72 : If FontYPos > 1 then Dec(FontYPos);
   #80 : If FontYPos < 16 then Inc(FontYPos);
   #75 : If FontXPos > 1 then Dec(FontXPos);
   #77 : If FontXPos < 8 then Inc(FontXPos);
 End;
 Case C1 of
   #32 : Begin
          InvertBitA(CharSet[0].Data[FontYPos],8-FontXPos);
          SetImageChar(Ascii,CharSet);
          If FontXPos < 8 then Inc(FontXPos);
         End;
 End;
End;

Var X,Y : Byte;
 Temp : String;
 FontFile : File;
Procedure EditFont;
Begin
ClrScr;
Nocursor;
move(@FontScrn^,mem[$b800:0000],4000);
Active := 1;
FontXPos := 1;FontYPos := 1;
Mode := 1;
C1 := #0;C2 := #0;
While C1 <> #27 do
Begin
 Display;
 C1 := #0;C2 := #0;
 C1 := Readkey;If C1 = #0 then C2 := Readkey;
 If C1 In[^I,^M] then Begin
                  Beep(300,100);
                  If Mode = 1 then Mode := 2 else Mode := 1;
                 End;
 If C2 = #19 then Begin
                   For X := 1 to 16 do Charset[0].Data[X] := DefaultCharSet[Ascii].Data[X];
                   SetImageChar(Ascii,Charset);
                  End;
 If C2 = #22 then Begin {Alt-U .. Move Font Up }
                   For X := 2 to 16 do Charset[0].Data[X-1] := CharSet[0].Data[X];
                   CharSet[0].Data[16] := 0;
                   SetImageChar(Ascii,Charset);
                  End;
 If C2 = #33 then Begin {Alt-F .. Rotate Font Left}
                   For X := 1 to 16 do Charset[0].Data[X] := (Charset[0].Data[X] shl 1);
                   SetImageChar(Ascii,Charset);
                  End;
 If C2 = #46 then Begin {Alt-C .. Clear Bit Values}
                   For X := 1 to 16 do Charset[0].Data[X] := 0;
                   SetimageChar(Ascii,CharSet);
                  End;
 If C2 = #21 then Begin {Alt-Y .. Load System Font}
                   asm
                    mov ax,3
                    int 10h
                   end;
                   For X := 0 to 255 do GetImageChar(X,DefaultCharSet[X]);
                   move(@FontScrn^,mem[$b800:0000],4000);
                   Nocursor;
                  End;
 If C2 = #34 then Begin {Alt-G .. Rotate Font Right}
                   For X := 1 to 16 do Charset[0].Data[X] := (Charset[0].Data[X] shr 1);
                   SetImageChar(Ascii,Charset);
                  End;
 If C2 = #20 then Begin {Alt-T .. Copy to CLipboard}
                   SavetoClipboard(Ascii);
                  End;
 If C2 = #25 then Begin
                   PasteFromClipboard(Ascii);
                  End;
 If C2 = #23 then Begin
                   For X := 1 to 16 do
                     For Y := 0 to 7 do
                      InvertBitA(CharSet[0].Data[X],7-Y);
                   SetImageChar(Ascii,Charset);
                  End;
 If C2 = #31 then Begin
                   Beep(1000,100);
                   Textattr := 7;
                   GotoXy(1,22);ClrEol;
                   Window(1,22,80,25);ClrScr;Window(1,1,80,25);
                   GotoXy(1,22);
                   Write('Enter Filename to Save As : ');
                   Textattr := $1F;Inputln(Temp,12,True,True);
                   Textattr := 7;
                   If (Length(Temp) > 1) and (Temp <> 'Aborted') then
                    Begin
                     Assign(FontFile,Temp);
                     Rewrite(FontFile,1);
                     For X := 0 to 255 do GetImageChar(X,CharSet[X]);
                     BlockWrite(FontFile,CharSet,SizeOf(CharSet));
                     Close(FontFile);
                    End;
                   move(@FontScrn^,mem[$b800:0000],4000);
                  End;
 If C2 = #38 then Begin {Alt-L .. Load Font File}
                   Beep(1000,100);
                   Textattr := 7;
                   Window(1,22,80,25);ClrScr;Window(1,1,80,25);
                   GotoXy(1,22);
                   Write('Enter Filename to Load : ');
                   Textattr := $1F;Inputln(Temp,12,True,True);
                   Textattr := 7;
                   If (Fileexist(Temp)) and (Length(Temp) > 1) and (Temp <> 'Aborted') then
                    Begin
                     Assign(FontFile,Temp);
                     Reset(FontFile,1);
                     BlockRead(FontFile,Charset,sizeof(Charset));
                     For X := 0 to 255 do SetImageChar(X,Charset[X]);
                     Close(FontFIle);
                    End;
                   WaitRetrace;
                   move(@FontScrn^,mem[$b800:0000],4000);
                  End;
 If Mode = 1 then SelectChar;
 If Mode = 2 then SelectPos;
End;
Yescursor;
End;
End.