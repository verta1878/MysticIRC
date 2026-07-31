Unit FontUnit;

Interface
 Procedure GetImageChar(chrVal : Byte; Var CharInfo);
 Procedure SetImageChar(chrVal : Byte; Var CharInfo);
 Procedure SaveTempFont;
 Procedure RestoreTempFont;
 Procedure SavetoClipBoard(Character : Byte);
 Procedure PasteFromCLipBoard(Character : Byte);

Type CharRec = Record
                  Data : Array[1..16] of Byte;
                 End;

Var CharSet        : Array[0..255] of CharRec;
    DefaultCharSet : Array[0..255] of CharRec;
    TempFont       : Array[0..255] of CharRec;
    ClipBoard      : CharRec;

Implementation

Procedure SavetoClipBoard(Character : Byte);
Begin
 GetImageChar(Character,ClipBoard);
End;

Procedure PasteFromCLipBoard(Character : Byte);
Begin
 SetImageChar(Character,Clipboard);
End;

Procedure SaveTempFont;
Var X : Byte;
Begin
 For X := 0 to 255 do GetImageChar(X,TempFont[X]);
End;

Procedure RestoreTempFont;
Var X : Byte;
Begin
 For X := 0 to 255 do SetImageChar(X,TempFont[X]);
End;


Procedure GetImageChar(chrVal : Byte; Var CharInfo);
Var
 Offset : Word;
begin
  offset := chrVal * 32;
  Inline($FA);
  PortW[$3C4] := $0402;
  PortW[$3C4] := $0704;
  PortW[$3CE] := $0204;
  PortW[$3CE] := $0005;
  PortW[$3CE] := $0006;
  Move(Ptr($A000, offset)^, CharInfo, 16);
  PortW[$3C4] := $0302;
  PortW[$3C4] := $0304;
  PortW[$3CE] := $0004;
  PortW[$3CE] := $1005;
  PortW[$3CE] := $0E06;
  Inline($FB);
end;

Procedure SetImageChar(chrVal : Byte; Var CharInfo);
Var
 Offset : Word;
begin
  offset := chrVal * 32;
  Inline($FA);
  PortW[$3C4] := $0402;
  PortW[$3C4] := $0704;
  PortW[$3CE] := $0204;
  PortW[$3CE] := $0005;
  PortW[$3CE] := $0006;
  Move(CharInfo, Ptr($A000, offset)^, 16);
  PortW[$3C4] := $0302;
  PortW[$3C4] := $0304;
  PortW[$3CE] := $0004;
  PortW[$3CE] := $1005;
  PortW[$3CE] := $0E06;
  Inline($FB);
end;
{GetImageChar(65, CharSet[65]);}
{SetImageChar(65, CharSet[65]);}
End.