Unit FileLst;

Interface
 Function File2Load : String;
Implementation

Uses Dos,Crt,Extense;

Type str12 = String[12];

Var Filelist : Array[1..1000] of Str12;
    X        : Integer;
    Highest  : Integer;
    Dirinfo  : Searchrec;
    Top      : Integer;
    Active   : Integer;
    Mask     : String;
    CH       : Char;
    F,B      : Byte;

Procedure Load_Directories;
Begin
 X := 0;
 Findfirst('*.*',Directory,Dirinfo);
 While Doserror = 0 do
 Begin
  If (((Dirinfo.Attr and Directory) <> 0) and (Dirinfo.Name <> '.')) then
   Begin
    Inc(X);
    Filelist[X] := Dirinfo.Name;
   End;
  Findnext(dirinfo);
 End;
Highest := X+1;
End;

Procedure Load_files;
Begin
 X := Highest;
 FindFirst(Mask,Archive,Dirinfo);
 While Doserror = 0 do
  Begin
   Filelist[X] := Dirinfo.Name;
   Inc(X);
   Findnext(dirinfo);
  End;
 Highest := X-1;
End;

Procedure LoadPic;External;{$L LOADPIC.OBJ}

Procedure DisplayFiles;
Var X : Byte;
Begin
   For X := 1 to 35 do
    Begin
     If X > Highest then Break;
     If X = Active then Begin
                         F := 15;B := 2;
                        End
                   else Begin
                         F := 15;B := 0;
                        End;
     Case X of
       1..7   : Qwrite(5,15+X,Padstring(Filelist[X+Top-1],12),F,B,80);
       8..14  : Qwrite(20,15+X-7,Padstring(Filelist[X+Top-1],12),F,B,80);
       15..21 : Qwrite(35,15+X-14,Padstring(Filelist[X+Top-1],12),F,B,80);
       22..28 : Qwrite(50,15+X-21,Padstring(Filelist[X+Top-1],12),F,B,80);
       29..35 : Qwrite(65,15+X-28,Padstring(Filelist[X+Top-1],12),F,B,80);
      End;
    End;
End;

Function DirExist(StDir : String): Boolean;
Var
  WoFattr : Word;
  FiTemp  : File;
Begin
 Assign(fiTemp, (stDir + '.'));
 Getfattr(fiTemp, woFattr);
 if (doserror <> 0) then DirExist := false
                    else DirExist := ((woFattr and directory) <> 0)
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


Function File2Load : String;
Var StartingDir,Direct,InputString : String;
    TempF : File;
Attribute : Word;
 Inputcount : Byte;
 X,Y,Z : Word;
Label Return;
Begin
 GetDir(0,StartingDir);
 For X := 1 to 1000 do Filelist[X] := '';
 Top := 1;Active := 1;Mask := '*.*';CH := #0;
 asm mov ax,3;int 10h; end;
 Nocursor;
 Load_Directories;
 Load_Files;
 Move(@Loadpic^,Mem[$b800:0000],4000);
 InputString := '';
 InputCount := 0;
Return:
 While (CH <> #27) do
  Begin
  Yescursor;
  DisplayFiles;
  GetDir(0,Direct);
  Qwrite(40-(Length(Direct) div 2)-4,14,'²ßþ, ',8,0,80);
  Qwrite(40-(Length(Direct) div 2)+1,14,Direct,7,0,80);
  Qwrite(40+(Length(Direct) div 2)+2,14,' ,þß²',8,0,80);
  QWrite(6,24,Padstring(InputString,50),7,0,80);
  GotoXy(6+Length(InputString),24);
  InputCount := Length(InputString);
  If Keypressed then Begin
  CH := Readkey;If CH = #0 then CH := Readkey;
  Case CH of
    #8  : Begin
           If InputCount > 0 then Begin
                              Delete(InputString,Length(InputString),1);
                              Dec(InputCount);
                             End;
          End;
    #72 : Begin
          If Active > 1 then Dec(Active)
                        else If Top > 1 then Begin
                                              Dec(Top,7);
                                              Active := 7;
                                             End;
          InputString := Filelist[Active+Top-1];
          End;
    #77 : Begin
           If Active < 29 then Inc(Active,7) else If Top+35 <= Highest then Inc(Top,7);
           If Top+Active > Highest then Active := Highest-Top+1;
           InputString := Filelist[Active+Top-1];
          End;
    #75 : Begin
           If Active > 7 then Dec(Active,7) else If Top > 1 then Dec(Top,7);
           InputString := Filelist[Active+Top-1];
          End;
    #80 : Begin
           If (Active+Top-1 < Highest) and (Active < 35) then Inc(Active)
             else If (Active+top-1 < Highest) then Begin
                                                    Inc(Top,7);
                                                    Active := 29;
                                                   End;
           InputString := Filelist[Active+Top-1];
          End;
    #13 : Begin
           Assign(TempF,InputString);
           GetFattr(TempF,Attribute);
           If ((DirExist(InputString)) or ((Attribute and Directory) <> 0)) then
            Begin
             Chdir(InputString);
             For X := 1 to 1000 do Filelist[X] := '';
             Top := 1;Active := 1;Mask := '*.*';CH := #0;
             Move(@Loadpic^,Mem[$b800:0000],4000);
             Load_Directories;
             Load_Files;
             Goto Return;
            End
            else If FileExist(InputString) then Begin
                                                 File2Load := Fexpand(InputString);
                                                 ChDir(StartingDir);
                                                 Yescursor;
                                                 Blinking(False);
                                                 Exit;
                                                End
              else Begin
                    Mask := InputString;
                    For X := 1 to 1000 do Filelist[X] := '';
                    Top := 1;Active := 1;CH := #0;
                    Move(@Loadpic^,Mem[$b800:0000],4000);
                    Load_Directories;
                    Load_Files;
                    Goto Return;
                   End;

{           Assign(TempF,Filelist[Active+Top-1]);
           GetFattr(TempF,Attribute);
           If (Attribute and Directory) <> 0 then
            Begin
             Chdir(Filelist[Active+Top-1]);
             For X := 1 to 1000 do Filelist[X] := '';
             Top := 1;Active := 1;Mask := '*.*';CH := #0;
             Move(@Loadpic^,Mem[$b800:0000],4000);
             Load_Directories;
             Load_Files;
             Goto Return;
            End;
           File2Load := FExpand(Filelist[Active+Top-1]);
           ChDir(StartingDir);
           Yescursor;
           Blinking(False);
           Exit;}
          End;
    #27 : Begin
           GotoXy(1,25);ClrEol;
           File2Load := 'Aborted';
           Blinking(False);
           Chdir(Startingdir);
           Exit;
          End;
 'a'..'z','A'..'Z','0'..'9',':','\','*','.','!','#','$','%' :
          Begin
           If InputCount < 50 then Begin
                                    Inc(InputCount);
                                    InputString := InputString + CH;
                                   End;
          End;
    End; {Case}
   End; {Keypressed}
  End; {While}
Yescursor;
GotoXy(1,25);ClrEol;
ChDir(StartingDir);
End;
End.