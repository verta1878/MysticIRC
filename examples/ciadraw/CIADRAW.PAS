Program CiA_Draw;
{$F+}

Uses Dos,         { Turbo Pascal's DOS Unit              }
     Crt,         { Turbo Pascal's CRT Unit              }
     Extense,     { Extended Pascal Unit                 }
     Exec,        { Memory Efficient EXEC Unit           }
     Runtime,     { Critical Error Handler               }
     Load,        { Unit to Load an Ansi into the Buffer }
     FileLst,     { File Listing/Selection Lightbars     }
     Pallette,    { Pallette Manipulation Routines       }
     FontEdit,FontUnit;

Const
 Modez : Array[1..4] of Word = (80,80,132,132);
 AltA = 30; AltI = 23; AltQ = 16; AltY   =  21; AltF6  = 109; CtrlF4  = 97;
 AltB = 48; AltJ = 36; AltR = 19; AltZ   =  44; AltF7  = 110; CtrlF5  = 98;
 AltC = 46; AltK = 37; AltS = 31; AltMin = 130; AltF8  = 111; CtrlF6  = 99;
 AltD = 32; AltL = 38; AltT = 20; AltF1  = 104; AltF9  = 112; CtrlF7  = 100;
 AltE = 18; AltM = 50; AltU = 22; AltF2  = 105; AltF10 = 113; CtrlF8  = 101;
 AltF = 33; AltN = 49; AltV = 47; AltF3  = 106; CtrlF1 =  94; CtrlF9  = 102;
 AltG = 34; AltO = 24; AltW = 17; AltF4  = 107; CtrlF2 =  95; CtrlF10 = 103;
 AltH = 35; AltP = 25; AltX = 45; AltF5  = 108; CtrlF3 =  96; HomeKey = 71;
 Left = 75; EndKey=89; Up   = 72; Escape = 27;  PUp    = 73;  Insert  = 82;
 Right= 77; Enter =13; Down = 80; Tab    = 9;   PDn    = 81;  Del     = 83;
 BkSp = 8;

Type
 Buffer  = Array[0..$FFFE] of Byte;
 Buffer2 = Array[1..8000] of Byte;

Var
 Buff        : ^Buffer; { Binary Buffer for Ansi }
 ScrBuffer   : Buffer2; { Screen Restore Buffer  }
 Top,                   { Top Line on the Screen }
 Xres,Yres,             { XMax and YMax-1 of the Screen }
 Highest     : Word;    { Highest Used Line      }
 C1,C2       : Char;    { Characters             }
 SetNumber,             { Function Key Set       }
 XPos,                  { X Position on Screen   }
 YPos        : Word;    { Y Position on Screen   }
 Foreground,            { Current Foreground     }
 Background,            { Current Background     }
 VideoMode,             { Current Video Mode     }
 Page        : Byte;    { Current Page           }
 AttribMode,            { Attribute Mode?        }
 Ruler       : Boolean; { Ruler On?              }
 Grey        : Boolean; { Is the Picture Grey?   }
 Temp        : String;  { Temporary String       }
 OldMouseX,OldMouseY : Word;
 W,X,Y,Result: Integer; { Misc. Loop Counters    }

Label Loop1,Loop2,Back;

Procedure Cialogo;External;{$L CIALOGO.OBJ}
Procedure Cialogo2;External;{$L CIALOGO2.OBJ}
Procedure Cialogo3;External;{$L CIALOGO3.OBJ}

Procedure Set8X16;assembler;
Asm
  mov     dx,03c4h
  mov     ax,0100h
  out     dx,ax
  mov     dx,03c4h
  mov     ax,0301h
  out     dx,ax
  mov     dx,03c2h
  mov     al,063h
  out     dx,al
  mov     dx,03c4h
  mov     ax,0300h
  out     dx,ax
  mov     dx,03d4h
  mov     ax,4f09h
  out     dx,ax
End;


{----------- This routine handles all Screen Related Opperations ------------}
Procedure ScreenOp(Mode : Byte);
{ 0 = Initialize Text Mode    }
{ 1 = Save Current Screen     }
{ 2 = Restore Saved Screen    }
{ 3 = Update Drawing Area     }
{ 4 = Clear the Buffer        }
Var X,X2,Y : Word;
Begin
 Case Mode of
   0 : Asm mov ax,3;int 10; end;
   1 : FastMove(Mem[$b800:0000],ScrBuffer,Yres*160);
   2 : FastMove(ScrBuffer,Mem[$b800:0000],Yres*160);
   3 : Begin
        X := 0;x2 := 0;
        While X2 < Yres do
        Begin
         Fastmove(Buff^[(Top)*160+(X2*160)],Screen[X*Xres*2],160);
         Inc(X);Inc(X2);
        End;
       End;
   4 : Begin
        For Y := 0 to 300 do For X := 0 to 80 do
        Begin
         Buff^[(Y*160)+(X*2)] := 32;
         Buff^[(Y*160)+(X*2)+1] := 7;
        End;
        Top := 1;Xpos := 1;Ypos := 1;
       End;
   5 : Begin
        If Grey then Begin
                      RestoreOrigPallette;
                      Grey := False;
                      GrabPallette;
                     End
                else Begin
                      Grey := True;
                      InstantGreyScale;
                      GrabPallette;
                     End;
      End;
  End; {Case}
End; {Procedure}
{--------- This Routine Displays the Set Number on the Status Line --------}
Procedure ShowSet(Setnumber : Byte);
Const SetData : Array[1..15] of String =
(' 1:⁄ 2:ø 3:¿ 4:Ÿ 5:ƒ 6:≥ 7:√ 8:¥ 9:¡ 10:¬ ',' 1:… 2:ª 3:» 4:º 5:Õ 6:∫ 7:Ã 8:π 9:  10:À ',
 ' 1:’ 2:∏ 3:‘ 4:æ 5:Õ 6:≥ 7:∆ 8:µ 9:œ 10:— ',' 1:÷ 2:∑ 3:” 4:Ω 5:ƒ 6:∫ 7:« 8:∂ 9:– 10:“ ',
 ' 1:≈ 2:Œ 3:ÿ 4:◊ 5:Ë 6:È 7:õ 8:ú 9:ô 10:Ô ',' 1:∞ 2:± 3:≤ 4:€ 5:ﬂ 6:‹ 7:› 8:ﬁ 9:˛ 10:˙ ',
 ' 1: 2: 3: 4: 5: 6: 7: 8: 9: 10: ',' 1: 2: 3: 4: 5: 6: 7: 8: 9: 10: ',
 ' 1:Æ 2:Ø 3:Ú 4:Û 5:© 6:™ 7:˝ 8:ˆ 9:´ 10:¨ ',' 1:„ 2:Ò 3:Ù 4:ı 5:Í 6:ù 7:‰ 8:¯ 9:˚ 10:¸ ',
 ' 1:‡ 2:· 3:‚ 4:Â 5:Ê 6:Á 7:Î 8:Ï 9:Ì 10:Ó ',' 1:Ä 2:á 3:• 4:§ 5:ò 6:ü 7:˜ 8:˘ 9:≠ 10:® ',
 ' 1:É 2:Ñ 3:Ö 4:† 5:¶ 6:Ü 7:é 8:è 9:ë 10:í ',' 1:à 2:â 3:ä 4:Ç 5:ê 6:å 7:ã 8:ç 9:° 10:û ',
 ' 1:ì 2:î 3:ï 4:¢ 5:ß 6:ñ 7:Å 8:ó 9:£ 10:ö ');
Begin
 GotoXy(36,Yres+1);
 Textattr := 7;Write('›');
 Textcolor(35);Write(SetData[SetNumber]);
 Textattr := 7;Write('ﬁ');
End;
{-------- This Routine Displays the Entire Status Line at the Bottom --------}
Procedure WriteStatusLine;
Var Attr    : Byte;
    Thing   : String;
Begin
 Textattr := 7;
 WaitRetrace;
 ShowSet(Setnumber);
 GotoXy(1,Yres+1);
 Textattr := 8;Write('(');
 Textattr := 3;Write(LeadingZero(Xpos));
 Textattr := 8;Write(', ');
 Textattr := 3;Write(LeadingZero(Ypos+Top-1));
 Textattr := 8;Write(') ');
 Qwrite(11,Yres+1,'Color',Foreground,Background,Modez[VideoMode]);
 If Attribmode then Qwrite(17,Yres+1,'Atr',foreground,Background,Modez[VideoMode]) else
 Qwrite(17,Yres+1,'≤±∞',foreground,Background,Modez[VideoMode]);
End;
{-This Routine Updates the bottom of the screen & sets the new X,Y Positions-}
Procedure Update;
Begin
If Ruler then
 Qwrite(1,YRes+1,'---------1---------2---------3---------4---------5---------6---------7----------',15,7,Modez[VideoMode])
  else WriteStatusLine;
 GotoXy(Xpos,YPos);
 C1 := #0;C2 := #0;
End;
{-This Routine Draws a Hollow Box on the Screen where you Choose/ Color/etc.-}
Procedure Box(X1,Y1,X2,Y2,Color : Byte);
Var X,Y : Byte;
Begin
 Textattr := Color;
 Gotoxy(X1,Y1);
 Write('÷');For X := 1 to (X2-X1) do Write('ƒ');Write('∑');
 For Y := 1 to (Y2-Y1) do Qwrite(X1,Y1+Y,'∫',Color,0,80);
 For Y := 1 to (Y2-Y1) do Qwrite(X2+1,Y1+Y,'∫',Color,0,80);
 For Y := 1 to (Y2-Y1) do
  Begin
   GotoXy(X1+1,Y+Y1);
   For X := 1 to (X2-X1) do Write(' ');
  End;
 GotoXy(X1,Y2);Write('”');For X := 1 to (X2-X1) do Write('ƒ');Write('Ω');
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


Procedure Pallette_Editor;
Var CH            : Char;
    Color_Editing : Byte;
    RGB_Color     : Byte;
    RedValue      : Byte;
    GreenValue    : Byte;
    BlueValue     : Byte;
    Dac           : Byte;
    X,Y           : Word;
    FFile         : File;
Label Reload;

Procedure ShowBottom;
Begin
Qwrite(1,Yres-2,'ƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒ',7,0,Modez[VideoMode]);
GotoXy(1,Yres-1);
PipeWrite(
' |08[|15Up|08/|15Down|08] |07Arrow to Select Color, |08[|15Left|08/|15Right|08]|07 Arrows to Select Component       ');
PipeWrite(
' |08[|15ALT-G|08] |07Greyscale Pallette |08[|15ALT-D|08] |07Default Pallette   |08[|15Enter|08] |07Return to Drawing');
PipeWrite(
' |08[|15ALT-S|08] |07Save Pallette      |08[|15ALT-L|08] |07Load Pallette      |08[|15ESC|08]   |07Abort Changes   ');
End;

Begin
Nocursor;
WaitRetrace;
Box(48,Yres-20,79,Yres-3,8);
For X := 1 to 15 do Qwrite(51,X+Yres-19,'€€€€€€€€€€€€€€€',X,0,Modez[VideoMode]);
ShowBottom;
Reload:
For X := 0 to 15 do
Begin
 GetPallette(Dacs[X],RedValue,GreenValue,BlueValue);
 Qwrite(68,X+(Yres-19),LeadingZero(RedValue)+'  '+LeadingZero(GreenValue)+'  '+Leadingzero(BlueValue),7,0,Modez[VideoMode]);
End;
Color_Editing := 0;
RGB_Color     := 1;
Getpallette(Dacs[Color_Editing],RedValue,BlueValue,GreenValue);
Clear_Keyboard_Buffer;
CH := #0;
While CH <> #27 do
 Begin
  WaitRetrace;
  SetPallette(Dacs[Color_Editing],Redvalue,GreenValue,Bluevalue);
  GetPallette(Dacs[Color_Editing],Redvalue,GreenValue,BlueValue);
  If RGB_Color = 1 then Qwrite(68,Color_Editing+(Yres-19),LeadingZero(RedValue),15,7,Modez[VideoMode])
                   else Qwrite(68,Color_Editing+(Yres-19),LeadingZero(RedValue),7,0,Modez[VideoMode]);
  If RGB_Color = 2 then Qwrite(72,Color_Editing+(Yres-19),LeadingZero(GreenValue),15,7,Modez[VideoMode])
                   else Qwrite(72,Color_Editing+(Yres-19),LeadingZero(GreenValue),7,0,Modez[VideoMode]);
  If RGB_Color = 3 then Qwrite(76,Color_Editing+(Yres-19),LeadingZero(BlueValue),15,7,Modez[VideoMode])
                   else Qwrite(76,Color_Editing+(Yres-19),LeadingZero(BlueValue),7,0,Modez[VideoMode]);
  Clear_keyboard_buffer;
  CH := Readkey;
  Case CH of
   #31 : Begin {Alt-S}
          Beep(1000,100);
          Textattr := 7;
          For X := Yres-1 to Yres+1 do Begin
                                        GotoXy(1,X);ClrEol;
                                       End;
          GotoXy(1,23);
          PipeWrite('|15E|07nter |15Fi|07lename to Save Pallette As : ');
          Textattr := $1F;
          Inputln(Temp,12,True,True);
          Textattr := 7;
          If (Temp <> 'Aborted') and (Length(Temp) > 1) then
          Begin
           If FileExist(Temp) then
            Begin
             Beep(1000,100);
             GotoXy(1,23);ClrEol;
             Write('Would you like to Overwrite the Existing File? ');
             If Yesno then Begin
                            Assign(FFile,Temp);
                            Rewrite(FFile,1);
                            GrabPallette;
                            Blockwrite(FFile,Pall,SizeoF(Pall));
                            Close(FFile);
                            ShowBottom;
                            Goto Reload;
                           End else Begin ShowBottom;Goto Reload; End;
            End else
            Begin
             Assign(FFile,Temp);
             Rewrite(FFile,1);
             GrabPallette;
             Blockwrite(FFile,Pall,SizeoF(Pall));
             Close(FFile);
             ShowBottom;
             Goto Reload;
            End;
            End;
          ShowBottom;
         End;
   #38 : Begin
          Textattr := 7;
          For X := Yres-1 to Yres+1 do Begin
                                        GotoXy(1,X);ClrEol;
                                       End;
          Beep(1000,100);
          GotoXy(1,23);
          PipeWrite('|15E|07nter |15Fi|07lename to Load : ');
          Textattr := $1F;
          Inputln(Temp,12,True,True);
          Textattr := 7;
          If (Temp <> 'Aborted') and (Length(Temp) > 1) and (FileExist(TemP)) then
           Begin
            Assign(FFile,Temp);
            Reset(FFile,1);
            BlockRead(FFile,Pall,Sizeof(Pall));
            RestorePallette;
            Close(FFile);
            ShowBottom;
            Goto Reload;
           End;
          ShowBottom;
         End;
   #34: Begin {ALT-G}
          ScreenOp(5);
          Goto Reload;
         End;
   #32: Begin {ALT-D}
         RestoreOrigPallette;
         GrabPallette;
         Grey := False;
         Goto Reload;
        End;
   #80 : Begin
           If Color_Editing < 15 then
           Begin
Qwrite(68,Color_Editing+(Yres-19),
     LeadingZero(RedValue)+'  '+LeadingZero(GreenValue)+'  '+Leadingzero(BlueValue),7,0,Modez[VideoMode]);
            Inc(Color_Editing);
            GetPallette(Dacs[Color_Editing],Redvalue,GreenValue,BlueValue);
           End;
          End;
   #72 : Begin
          If Color_editing > 0 then
           Begin
Qwrite(68,Color_Editing+(Yres-19),
LeadingZero(RedValue)+'  '+LeadingZero(GreenValue)+'  '+Leadingzero(BlueValue),7,0,Modez[VideoMode]);
           Dec(Color_Editing);
           GetPallette(Dacs[Color_Editing],Redvalue,GreenValue,BlueValue);
          End;
         End;
   #75 : If RGB_Color > 1 then Dec(RGB_Color);
   #77 : If RGB_Color < 3 then Inc(RGB_Color);
   '+','=' : Begin
          If RGB_Color = 1 then If RedValue < 63 then Inc(Redvalue);
          If RGB_Color = 2 then If GreenValue < 63 then Inc(GreenValue);
          If RGB_Color = 3 then If BlueValue < 63 then Inc(BlueValue);
         End;
   '-' : Begin
          If RGB_Color = 1 then If RedValue > 0 then Dec(Redvalue);
          If RGB_Color = 2 then If GreenValue > 0 then Dec(GreenValue);
          If RGB_Color = 3 then If BlueValue > 0 then Dec(BlueValue);
         End;
   End;{Case}
 End;{While}
Yescursor;
Waitretrace;
ScreenOp(3);
GotoXy(1,Yres+1);ClrEol;
Update;
End;


Procedure ChangeMode;
Begin
 YesCursor;
 Inc(VideoMode);
 If VideoMode = 5 then VideoMode := 1;
 Case VideoMode of
  1 : Begin
       asm mov ax,3;int 10h;end;
       set8x16;
       Xres := 80;Yres := 24;
      End;
  2 : Begin
       Textmode(CO80+Font8x8);
       Xres := 80;Yres := 49;
      End;
  3 : Begin { 132x25 Mode }
       asm
        mov ax,4f02h
        mov bx,109h
        int 10h
       end;
       Xres := 132;Yres := 24;
      End;
  4 : Begin { 132x43 Mode }
       asm
        mov ax,4f02h
        mov bx,10Ah
        int 10h
       end;
       Xres := 132;Yres := 42;
       SetCursorShape($10);
     End;
  End;
 Xpos := 1;YPos := 1;Top := 1;
 Blinking(False);
End;

Procedure Putpixel(X,Y : Word;Color : Byte);Assembler;
Asm
 MOV ax,$a000
 MOV es,ax
 MOV ah,byte ptr y
 MOV bx,x
 ADD bx,ax
 SHR ax,2
 ADD bx,ax
 MOV al,color
 MOV es:[bx],al
End;

Function IsZero(Line : Array of Byte) : Boolean;
Var Zero : Boolean;
    X : Byte;
Begin
 Zero := True;
 For X := 0 to 78 do
  Begin
   If (not(Line[X*2] = 32)) and (not(Line[X*2+1] = 7))
   then Begin
         Zero := False;
         Break;
        End;
  End;
IsZero := Zero;
End;

Procedure ViewVGA;
Var Attrib : Byte;
    X : Word;
  Templine : Array[0..160] of Byte;
  Character : Byte;
Begin
 For X := 300 downto 1 do
    Begin
     fastmove(Buff^[X*(160)],TempLine,(160));
     If not IsZero(Templine) then Begin
                                   Highest := X;
                                   Break;
                                  End;
   End;
 asm mov ax,13h;int 10h end;
 For Y := 0 to Highest do
  Begin
  For X := 0 to 80 do
   Begin
    Character := Buff^[(Y*160)+(X*2)];
    Attrib    := Buff^[(Y*160)+(X*2)+1];
    Foreground := Attrib and $0f;
    If Character = 32 then Putpixel(X,Y,0) else Putpixel(X,Y,(Foreground*3)+(Background*3));
   End;
  End;
Beep(1000,100);
Repeat until Keypressed;
Clear_Keyboard_Buffer;
End;

Procedure Write_From_Set(SetNum,FNum : Byte);
Const SetData : Array[1..15] of String =
('⁄ø¿Ÿƒ≥√¥¡¬','…ª»ºÕ∫Ãπ À','’∏‘æÕ≥∆µœ—','÷∑”Ωƒ∫«∂–“','≈Œÿ◊ËÈõúôÔ','∞±≤€ﬂ‹›ﬁ˛˙',
 '','','ÆØÚÛ©™˝ˆ´¨','„ÒÙıÍù‰¯˚¸','‡·‚ÂÊÁÎÏÌÓ','Äá•§òü˜˘≠®',
 'ÉÑÖ†¶Üéèëí','àâäÇêåãç°û','ìîï¢ßñÅó£ö');
Var Code : String;
Begin
 If InsKey then
 If Buff^[(Ypos+Top-1)*(160)+(80*2)-2] in[0,32] then
 fastmove(Buff^[(Ypos+Top-1)*(160)+(Xpos*2)-2],Buff^[(Ypos+Top-1)*(160)+(Xpos*2)],(160)-Xpos*2);
 Buff^[(YPos+Top-1)*(160)+(Xpos*2)-2] := Ord(SetData[Setnum,Fnum]);
 Buff^[(Ypos+Top-1)*(160)+(XPos*2)-1] := (Background shl 4)+Foreground;
 If Xpos < 80 then Inc(Xpos);
 Str(Ord(SetData[SetNum,FNum]),Code);
 Update;
End;

Procedure Insert_Row(Row : Word);
Begin
 For X := 0 to 80 do
  Begin
   Buff^[(300*160)+(X*2)] := 32;
   Buff^[(300*160)+(X*2)-1] := 7;
  End;
  fastmove(Buff^[(Ypos+Top-1)*160],Buff^[((Ypos+Top)*160)],(300-(Ypos+Top-1))*160);
 For X := 0 to 80 do
  Begin
   Buff^[((Ypos+Top-1)*160)+(X*2)] := 32;
   Buff^[((Ypos+top-1)*160)+(X*2)-1] := 7;
  End;
End;

Procedure QuickPallette;
Begin
 ScreenOp(1);
 Nocursor;
 Textattr := 7;
 GotoXy(1,YRes+1);If Ruler then ClrEol;
 WriteStatusline;
 Textattr := 7;
 GotoXy(1,Yres-9);
 WaitRetrace;
 ClrEol;PipeWrite('|12⁄|04ƒ|08ÕÕƒ_- - ˙ CiA|07Dra|08w Qu|07ic|08k |07Pal|08lette'#10#13);
 ClrEol;PipeWrite('|04≥'#10#13);
 ClrEol;PipeWrite('|08.     |12⁄|04ƒ|08ÕÕƒ_- - ˙ |07Foreground:                |08˙     |12⁄|04ƒ|08Õ˙ |07Background:'#10#13);
 ClrEol;PipeWrite('|08˙     |04≥                                      ≥     ≥                     ≥'#10#13);
 ClrEol;
PipeWrite('  |08    ˙                            ˙ - - |04ƒ|08ÕÕ|04ƒ|12Ÿ     |08˙           ˙ - - |04ƒ|08ÕÕ|04ƒ|12Ÿ     |08˙');
 ClrEol;PipeWrite('         |08< > |15Bl|07inking   |08< > |15Hi|07gh |15Ba|07ckground   |08< > |15Gre|07yscale '+
           '  |08< > |15Sa|07uce'#10#13);
 ClrEol;PipeWrite('                                                                             |04  ≥');
 ClrEol;PipeWrite('                                                                     |08˙ - - |04ƒ|08ÕÕ|04ƒ|12Ÿ');
 While (C1 <> #13) and (C1 <> #27) do
  Begin
   Textattr := 7;
   C1 := #0;C2 := #0;
   WaitRetrace;
   GotoXy(11,Yres-6);PipeWrite('|16|07≤≤|01€€|02€€|03€€|04€€|05€€|06€€|07€€|08€€|09€€|10€€|11€€|12€€|13€€|14€€|15€€');
   GotoXy(55,Yres-6);PipeWrite('|16|07≤≤|01€€|02€€|03€€|04€€|05€€|06€€|07€€');
   Textattr := 15;
   GotoXy(11+Foreground*2,YRes-6);Write('˛˛');
   GotoXy(55+Background*2,Yres-6);Write('˛˛');
   If Grey then Qwrite(48,Yres-4,'˚',15,0,Modez[VideoMode]) Else Qwrite(48,Yres-4,' ',15,0,Modez[VideoMode]);
   WriteStatusLine;
   Clear_Keyboard_Buffer;
   Getkeys(C1,C2);
    Case C2 of
     #75 : If Foreground > 0 then Dec(Foreground) else Foreground := 15;
     #77 : If Foreground < 15 then Inc(Foreground) Else Foreground := 0;
     #72 : If Background < 7 then Inc(Background) Else Background := 0;
     #80 : If Background > 0 then Dec(Background) Else Background := 7;
     #34 : ScreenOp(5);
    End;
  End;
 ScreenOp(2);
 Textattr := $7;
 Update;
 Clear_Keyboard_Buffer;
 YesCursor;
End;

Procedure SystemOp(Mode : Byte);
Var StartingDir : String;
Begin
 Case Mode of
   1 : Begin                 { Initialize }
        SetTyperate(0,0);
        Getmem(Buff,65535);
        ScreenOp(4);
        Blinking(False);
        Page := 1;W := 1;Top := 1;XPos := 1;Ypos := 1;Setnumber:= 1;
        Foreground := 7; Background := 0;
       End;
   2 : Begin                  { Shut Down }
        NoCursor;
        GotoXy(1,Yres);
        Textattr := 3;
        Beep(1000,100);
        PipeWrite('|15Ar|07e yo|08u sure you want to Quit? ');
        If Yesno then Begin
                       Freemem(Buff,65535);
                       asm
                        mov ax,3
                        int 10h;
                       end;
                       RestoreOrigPallette;
                       YesCursor;
                       Blinking(True);
                       Halt(0);
                      End;
         YesCursor;
         Textattr := $7;
         Update;
       End;
   3 : Begin                  { Jump to Dos }
        GetDir(0,StartingDir);
        Textattr := $7;
        asm mov ax,3;int 10h end;
        ClrScr;
        GrabPallette;
        SaveTempPal;
        RestoreOrigPallette;
        PipeWrite('|08˛ |07Type |08''|15EXIT|08'' |07to Return to CiADraw'#10#13);
        SwapVectors;
        Execute(GETENV('COMSPEC'),'');
        SwapVectors;
        Blinking(False);
        Clear_Keyboard_Buffer;
        C1 := #0;C2 := #0;
        Dec(VideoMode);
        ChangeMode;
        ScreenOp(3);
        Chdir(StartingDir);
        Update;
        RestoreTempPal;
       End;
 End;
End;


Procedure Insert_Column(Column : Word);
Begin
  For Y := 1 to 300 do
   Begin
    Buff^[(Y*160+(160)-2)] := 32;
    Buff^[(Y*160+(160)-1)] := 7;
   End;
 For Y := 1 to 300 do
  fastmove(Buff^[(Y*(160)+(Column*2)-2)],Buff^[(Y*(160)+(Column*2))],(160)-Column*2);
 For Y := 1 to 300 do
  Begin
   Buff^[(Y*160+(Column*2)-2)] := 32;
   Buff^[(Y*160+(Column*2)-1)] := 7;
  End;
End;

Procedure Delete_Column(Column : Word);
begin
 For Y := 1 to 300 do
  Begin
   fastmove(Buff^[(Y*(160)+(Column*2))],Buff^[(Y*(160)+(Column*2)-2)],(160)-Column*2);
  End;
  For Y := 1 to 300 do
   Begin
    Buff^[(Y*160+(160)-2)] := 32;
    Buff^[(Y*160+(160)-1)] := 7;
   End;
end;

Procedure CursorOp(Mode : Byte);
Var Templine : Array[1..160] of Byte;
Begin
 Case Mode of
{End}   1 : Xpos := 80;
{Down}  2 : If Ypos+Top-1 < 300 then If Ypos < Yres then Inc(YPos) else Inc(Top);
{PgDwn} 3 : If Top+(Yres+Yres+1) <= 300 then Inc(Top,Yres) else Top := 300-Yres+1;
{Left}  4 : If XPos > 1 then Dec(Xpos);
{Right} 6 : If XPos < 80 then Inc(XPos);
{Home}  7 : Xpos := 1;
{Up}    8 : If Ypos+Top-1 > 1 then If Ypos > 1 then Dec(Ypos) else Dec(Top);
{PgUp}  9 : If Top > Yres then Dec(Top,24) else Top := 1;
{Tab}  10 : If XPos+5 < 81 then Inc(XPos,5) else XPos := 80;
{MegaH}11 : Begin
             Xpos := 1;Ypos := 1;Top := 1;
            End;
{CR}   13 : Begin
             XPos := 1;
             If YPos < Yres then Inc(YPos) else If Top+Yres-1 < 300 then Inc(Top);
            End;
       14 : Begin
             fastmove(Buff^[(Ypos+Top-1)*160+(Xpos*2)],Buff^[(Ypos+Top-1)*(160)+(Xpos*2)-2],(160)-Xpos*2);
             Buff^[(YPos+Top-1)*(160)+(160)-2] := 0;
             Buff^[(YPos+Top-1)*(160)+(160)-1] := 7;
             ScreenOp(3);
            End;
       15 : Begin
             If Xpos < 2 then Exit;
             Buff^[(Ypos+Top-1)*(160)+(Xpos*2)-4] := 0;
             Buff^[(Ypos+Top-1)*(160)+(Xpos*2)-3] := 7;
             If Xpos > 1 then Dec(XPos,1);
            End;
{EOF}  16 : Begin
             For X := 300 downto 1 do
              Begin
               fastmove(Buff^[X*(160)],TempLine,(160));
               If not IsZero(Templine) then Begin
                                             Highest := X;
                                             Break;
                                            End;
              End;
              If Top > Yres then Top := Highest-Yres-1 else Top := 1;
              Xpos := 1;Ypos := 1;
            End;

{DelRow}17 : Begin
              fastmove(Buff^[(Ypos+Top)*160],Buff^[((Ypos+Top-1)*160)],(300-(Ypos+Top-1))*160);
              For X := 0 to 80 do
               Begin
                Buff^[(300*160)+(X*2)] := 32;
                Buff^[(300*160)+(X*2)-1] := 7;
               End;
              End;
{InsRow}18 : Begin
               For X := 0 to 80 do
                Begin
                 Buff^[(300*160)+(X*2)] := 32;
                 Buff^[(300*160)+(X*2)-1] := 7;
                End;
               fastmove(Buff^[(Ypos+Top-1)*160],Buff^[((Ypos+Top)*160)],(300-(Ypos+Top-1))*160);
               For X := 0 to 80 do
                Begin
                 Buff^[((Ypos+Top-1)*160)+(X*2)] := 32;
                 Buff^[((Ypos+top-1)*160)+(X*2)-1] := 7;
                End;
              End;
 End;
Update;
End;

Procedure Dialog_Box(X,Y : Byte);
{$I DIALOG.INC}
Begin
 Uncrunch(dialog,Screen[(X*2)+(Y*(160)-162)],dialog_Length);
End;

Procedure SaveFile;
Var Method        : String;
    Temp          : String;
    BinFile       : File;
    AsciiFile     : Text;
    AnsiFile      : Text;
    Templine      : Array[0..320] of Byte;
    TemporaryLine : Array[0..320] of Byte;
    Counter       : Word;
    Z             : Byte;
    CurrentAttr,LastAttr : Byte;
    Code : String;
Label Loop2;
Begin

 ScreenOp(1);
 Nocursor;
 Dialog_Box(17,8);
 GotoXy(28,11);
 Pipewrite('|23|08(|15A|08)nsi  Asci(|15I|08)  (|15B|08)inary');
 Textattr := 7;
Loop2:
 Getkeys(C1,C2);
 If Upcase(C1) = 'A' then Method := 'Ansi' else
 If Upcase(C1) = 'I' then Method := 'Ascii' else
 If Upcase(C1) = 'B' then Method := 'Binary' else
 If Upcase(C1) = #27 then Begin
                           YesCursor;
                           Exit
                          End else goto Loop2;
 Dialog_Box(17,8);
 GotoXy(26,11);Pipewrite('|23|15'+Method+' |08- |15File|08name : ');
 InputLn(Temp,12,True,True);
 If (Temp <> 'Aborted') and (Length(Temp) > 2) then
  Begin
    Counter := 0;
    For X := 300 downto 1 do
     Begin
      fastmove(Buff^[X*(160)],TempLine,160);
      If not IsZero(Templine) then Begin
                                    Highest := X;
                                    Break;
                                   End;
     End;
  If Method = 'Ansi' then
   Begin
    Dialog_Box(17,8);
    GotoXy(29,11);Pipewrite('|23|15File has not been Saved!');
    Delay(1000);
   End;
  If Method = 'Ascii' then
    Begin
     Assign(AsciiFile,Temp);
     Rewrite(AsciiFile);
     For X := 1 to Highest do
      Begin
       fastmove(Buff^[X*160],TemporaryLine,160);
       For Z := 1 to 80 do Write(AsciiFile,Chr(TemporaryLine[Z*2-2]));
       Writeln(AsciiFile,'');
      End;
     Close(AsciiFile);
     Dialog_Box(17,8);
     GotoXy(30,11);Pipewrite('|23|15File has been Saved!');
     Delay(1000);
    End;
   If Method = 'Binary' then
    Begin
     Assign(BinFile,Temp);
     Rewrite(BinFile,1);
     For X := 1 to Highest do BlockWrite(Binfile,Buff^[X*(160)],160);
     Close(Binfile);
     Dialog_Box(17,8);
     GotoXy(30,11);Pipewrite('|23|15File has been Saved!');
     Delay(1000);
    End;
  End;
 YesCursor;
 ScreenOp(2);
 Textattr := $7;
 C1 := #0;C2 := #0;
 Clear_Keyboard_Buffer;

End;

Procedure PickColor;
Var OldX,OldY,OldTop : Byte;
    Temp : String;
    TempInteger : Integer;
Label ExitProcedure;
Begin
 if videomode > 1 then asm mov ax,3;int 10h;end;
 Textattr := 7;
 ClrScr;
 OldX := Xpos;OldY := YPos;OldTop := Top;
 GotoXy(25,5);
 PipeWrite('|08ƒ|04ƒÕ|12ƒ  |07Select Screen Colors |12ƒ|04Õƒ|08ƒ');
 GotoXy(15,7);
 PipeWrite('|07Foreground> |23|000|16|01 1 |022 |033 |044 |055 |066 |077 |088 |099 |1010 |1111 |1212 |1313 |1414 |1515');
 GotoXy(15,8);
 PipeWrite('|07Background> |23|000|16|01 1 |022 |033 |044 |055 |066 |077');
 GotoXy(2,12);PipeWrite('|15Sel|07ect |08a |15Fo|07re|08ground Color |07(|150..15|07): ');
 InputNums(Temp,2);
 If Temp = 'Aborted' then goto ExitProcedure;
 Val(Temp,TempInteger,Result);
 If (Result <> 0) or (TempInteger < 0) or (Tempinteger > 15) then goto ExitProcedure;
 Foreground := TempInteger;
 GotoXy(2,13);PipeWrite('|15Sel|07ect a|08 |15Ba|07ck|08ground Color |07(|150..7|07): ');
 InputNums(Temp,2);
 If Temp = 'Aborted' then goto ExitProcedure;
 Val(Temp,TempInteger,Result);
 If (Result <> 0) or (TempInteger < 0) or (Tempinteger > 7) then goto ExitProcedure;
 Background := TempInteger;
 ExitProcedure:
 Dec(VideoMode);
 ChangeMode;
 Top := OldTop;
 XPos := OldX;
 YPos := OldY;
 ScreenOp(3);
 Update;
End;



Procedure LoadIt;
Var Binfile : File;
    Size    : LongInt;
    Temp    : String;
    D : DirStr;N : NameStr;E : ExtStr;
Begin
 grabPallette;
 SaveTempPal;
 RestoreOrigPallette;
 Temp := File2Load;      { Get Filename }
 If Temp = 'Aborted' then Begin
                           YesCursor;
                           Dec(VideoMode);
                           RestoreTempPal;
                           ChangeMode;
                           RestorePallette;
                           Exit;
                          End;
 ScreenOp(4);   { Zero de Buffah }
 Dec(VideoMode);
 ChangeMode;
 Xpos := 1;Ypos := 1;Top := 1;
 If Temp <> '' then Begin
                     Fsplit(Temp,D,N,E);
                     If E = '.BIN' then Begin
                                         Assign(Binfile,Temp);
                                         Reset(Binfile,1);
                                         Size := Filesize(Binfile);
                                         BlockRead(Binfile,Buff^[(160)*1],Size);
                                         Close(Binfile);
                                         End
                                    else LoadFile(temp,Buff,300,Highest);
                      Xpos := 1;Ypos := 1;Top := 1;
                      Update;
                     End;
 Dec(VideoMode);
 ChangeMode;
 RestoreTempPal;
 RestorePallette;
 Update;
 YesCursor;
End;

Begin
 If not VGACard then Begin
                      Writeln('VGA Card Not Detected, Cannot Execute.');
                      Halt(255);
                     End;
 asm mov ax,3;int 10h; end;
 Set8x16;
 For X := 0 to 255 do GetImageChar(X,DefaultCharSet[X]);
 Grey := False;
 GrabPallette;
 GrabOrigPallette;
 InitGreyScale;
 Nocursor;
 Textattr := 7;
 ClrScr;
 Ruler := False;
 Attribmode := False;
 randomize;
 X := Random(27);
 Case X of
  0..9   : fastmove(@cialogo^,mem[$b800:0000],4000);
  10..18 : fastmove(@cialogo2^,mem[$b800:0000],4000);
  19..27 : fastmove(@cialogo3^,mem[$b800:0000],4000);
 End;
 Delay(2000);
 Clear_Keyboard_Buffer;
 Textattr  := 7;
 Highest   := 0;
 Videomode := 1;
 Xres := 80;Yres := 24;
 ScreenOp(0);
 SystemOp(1);
 Update;
 YesCursor;
While (W = 1) do
 Begin
  If AttribMode then Buff^[(Ypos+Top-1)*(160)+(XPos*2)-1] := (Background shl 4) + Foreground;
  ScreenOp(3);
  If not ruler then
   Begin
    If InsKey then QWrite(21,Yres+1,'Ins',9,0,Modez[VideoMode]) else QWrite(21,Yres+1,'Ovr',9,0,Modez[VideoMode]);
    If CapsLock then QWrite(25,Yres+1,'Cap',9,0,Modez[VideoMode]) else QWrite(25,Yres+1,'   ',9,0,Modez[VideoMode]);
    If ScrollLock then Qwrite(29,Yres+1,'Scroll',9,0,Modez[VideoMode]) else Qwrite(29,Yres+1,'      ',9,0,Modez[VideoMode]);
   End;
If Keypressed then
 Begin
  C1 := #0;C2 := #0;
  Getkeys(C1,C2);
  Clear_Keyboard_Buffer;
  Case Ord(C1) of
   Tab     : CursorOp(10);
   BkSp    : CursorOp(15);
   Escape  : Begin
              Clear_Keyboard_Buffer;
              C1 := #0;C2 := #0;
              QuickPallette;
             End;
   Enter : CursorOp(13);
   31..254 : Begin
              If InsKey then
               If Buff^[(Ypos+Top-1)*(160)+(80*2)-2] in[0,32] then
                 fastmove(Buff^[(Ypos+Top-1)*(160)+(Xpos*2)-2],Buff^[(Ypos+Top-1)*(160)+(Xpos*2)],(160)-Xpos*2);
                 Buff^[(YPos+Top-1)*(160)+(Xpos*2)-2] := Ord(C1);
                 Buff^[(Ypos+Top-1)*(160)+(XPos*2)-1] := (Background shl 4) + Foreground;
                 If Xpos < 80 then Inc(Xpos) else CursorOp(13);
             End; {Writeing Charactor}
   End;
   Case Ord(C2) of
   AltP : Begin
            Textattr := Buff^[(Ypos+Top-1)*(160)+(XPos*2)-1];
            Foreground := TextAttr and $0f;
            Background := (TextAttr and $f0) shr 4;
           End;
   AltF : Begin
           If VideoMode = 1 then
           Begin
           GrabPallette;
           SaveTempPal;
           Textattr := 7;
           ClrScr;
           RestoreOrigPallette;
           EditFont;
           Blinking(False);
           If Videomode = 1 then Set8X16;
           Textattr := 7;
           ClrScr;
           RestoreTempPal;
           RestorePallette;
           ScreenOp(3);
           Update;
           End;
          End;
   AltR : Begin
           GotoXy(1,Yres+1);ClrEol;
           If Ruler then Ruler := False else Ruler := True;
          End;
   AltC  : ScreenOp(4);
   AltJ  : SystemOp(3);
   AltL  : Begin
            SaveTempFont;
            Textattr := 7;
            ClrScr;
            Loadit;
            RestoreTempFont;
            Update;
           End;
 59..68  : Write_From_Set(Setnumber,Ord(C2)-58);
104..113 : Begin Setnumber := Ord(C2)-103;ShowSet(Setnumber);End;
 94..98  : Begin Setnumber := Ord(C2)-83;ShowSet(Setnumber);End;
     15  : If XPos > 5 then Dec(Xpos,5) else Xpos := 1;
    115 : Delete_Column(Xpos);
    116 : Insert_Column(Xpos);
    Del : CursorOp(14);
   AltI : CursorOp(18);
   AltA : Begin
           GrabPallette;
           SaveTempPal;
           PickColor;
           RestoreTEmpPal;
           RestorePallette;
          End;
   AltM : Begin
           GrabPallette;
           SaveTempPal;
           if VideoMode in[1,3] then SaveTempFont;
           ChangeMode;
           RestoreTempPal;
           RestorePallette;
           if VideoMode in[1,3] then RestoreTempFont;
           Update;
          End;
   AltS : SaveFile;
 AltMin : If AttribMode then AttribMode := False else AttribMode := True;
   AltE : Pallette_Editor;
   AltX : SystemOp(2);
   AltV : Begin
           ViewVGA;
           Dec(VideoMode);
           ChangeMode;
          End;
    119 : CursorOp(11);
     32 : CursorOp(17);
   AltG : ScreenOp(5);
    117 : CursorOp(16);
     71 : CursorOp(7);
     Up : Begin
           If (ScrollLock = True) and (Top > 1) then
            Begin
             Dec(Top);
             ScreenOp(3);
             Update;
            End;
           If Not ScrollLock then CursorOp(8);
          End;
    Pup : CursorOp(9);
   Left : CursorOp(4);
  Right : CursorOp(6);
     79 : CursorOp(1);
   Down : Begin
           If (ScrollLock = True) and (Top < 300-25) then
            Begin
             Inc(Top);
             ScreenOp(3);
             Update;
            End;
           If not ScrollLock then CursorOp(2);
          End;
    PDn : CursorOp(3);
   End;
   Update;
    End;{Keypressed}
 End;{WhileLoop}
End.{Program}