Unit Pallette;

Interface
Const Dacs : Array[0..15] of Byte = (0,1,2,3,4,5,20,7,56,57,58,59,60,61,62,63);

Var
  Pall           : Array[0..255,1..3] of Byte;
  OrigPal        : Array[0..255,1..3] of Byte;
  GreyPallette   : Array[0..255,1..3] of Byte;
  TempPallette   : Array[0..255,1..3] of Byte;

 Procedure SaveTempPal;
 Procedure RestoreTempPal;
 Procedure GrabPallette;
 Procedure RestorePallette;
 Procedure GrabOrigPallette;
 Procedure RestoreOrigPallette;
 Procedure SetPallette(ColorNo : Byte; R,G,B : Byte);
 Procedure GetPallette(Col : Byte; Var R,G,B : Byte);
 Procedure FadeUp;
 Procedure FadeDown;
 Procedure InitGreyScale;
 Procedure InstantGreyscale;

Implementation
Procedure SaveTempPal;
Begin
 Move(Pall,TempPallette,768);
End;

Procedure RestoreTempPal;
Begin
 Move(TempPallette,Pall,768);
End;

Procedure SetPallette(ColorNo : Byte; R,G,B : Byte);Assembler;
asm
 mov dx,$3c8
 xor ax,ax
 mov al,ColorNo;out dx,al
 mov dx,$3c9
 mov al,r;out dx,al
 mov al,g;out dx,al
 mov al,b;out dx,al
end;

Procedure GrabPallette;
Var X : Integer;
Begin
  For X := 0 to 255 do Getpallette(X,pall[X,1],pall[X,2],pall[X,3]);
End;

Procedure GrabOrigPallette;
Var X : Integer;
Begin
  For X := 0 to 255 do Getpallette(X,Origpal[X,1],Origpal[X,2],Origpal[X,3]);
End;

Procedure Fadeup;
Var loop1,loop2 : Integer;
    Tmp         : Array [1..3] of Byte;
Begin
  For loop1:=1 to 64 do BEGIN
    For loop2:=0 to 255 do BEGIN
      Getpallette(loop2,Tmp[1],Tmp[2],Tmp[3]);
      If Tmp[1]<Pall[loop2,1] then inc(Tmp[1]);
      If Tmp[2]<Pall[loop2,2] then inc(Tmp[2]);
      If Tmp[3]<Pall[loop2,3] then inc(Tmp[3]);
      SetPallette (loop2,Tmp[1],Tmp[2],Tmp[3]);
    End;
  End;
End;

Procedure FadeDown;
VAR loop1,loop2:integer;
    Tmp : Array [1..3] of byte;
BEGIN
  For loop1:=1 to 64 do BEGIN
    For loop2:=0 to 255 do BEGIN
      Getpallette (loop2,Tmp[1],Tmp[2],Tmp[3]);
      If Tmp[1]>0 then dec(Tmp[1]);
      If Tmp[2]>0 then dec(Tmp[2]);
      If Tmp[3]>0 then dec(Tmp[3]);
      SetPallette (loop2,Tmp[1],Tmp[2],Tmp[3]);
    END;
  END;
END;

Procedure RestorePallette;
Var loop1 : Integer;
Begin
  For loop1 := 0 to 255 do setpallette(loop1,Pall[loop1,1],Pall[loop1,2],Pall[loop1,3]);
End;

Procedure RestoreOrigPallette;
Var loop1 : Integer;
Begin
  For loop1 := 0 to 255 do
   setpallette(loop1,OrigPal[loop1,1],OrigPal[loop1,2],OrigPal[loop1,3]);
End;

Procedure GetPallette(Col : Byte; Var R,G,B : Byte);
Var rr,gg,bb : Byte;
Begin
   asm
      mov    dx,3c7h
      mov    al,col
      out    dx,al
      add    dx,2
      in     al,dx
      mov    [rr],al
      in     al,dx
      mov    [gg],al
      in     al,dx
      mov    [bb],al
   end;
   r := rr;g := gg;b := bb;
end;

Procedure InitGreyScale;
Var X : Byte;
    RedReal,GreenReal,BlueReal : Real;
    R,G,B : Byte;
    Grey : Integer;
Begin
For X := 0 to 255 do
                  Begin
                   GetPallette(X,R,G,B);
                   RedReal := R;
                   GreenReal := G;
                   BlueReal := B;
                   Grey := Round((RedReal * 0.30)+(GreenReal * 0.59)+(BlueReal * 0.11));
                   GreyPallette[X,1] := Grey;
                   GreyPallette[X,2] := Grey;
                   GreyPallette[X,3] := Grey;
                  End;
End;

Procedure InstantGreyscale;
Var X : Integer;
Begin
 For X := 1 to 255 do setPallette(X,GreyPallette[X,1],GreyPallette[X,2],GreyPallette[X,3]);
End;

End.