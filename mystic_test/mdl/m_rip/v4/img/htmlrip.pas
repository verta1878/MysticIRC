(* htmlrip.pas -- HTML 1.0 to RIP Command Translator
   Copyright (C) 2026 Mystic BBS IRC Fork Contributors
   Licensed under GNU General Public License v3.

   Translates an HTML DOM tree into RIP command strings.
   The output is a sequence of RIP pipe commands that, when
   processed by TRIPEngine.ProcessLine, reproduce the HTML
   page on the RIP canvas.

   This is the same approach TeleGrafix's RIPweb used — HTML
   documents converted to RIPscrip for display in RIPterm.

   Usage:
     HTMLTreeParse(Tree, Source, Len);
     HTMLLayoutCompute(Layout, Tree, 640, 350);
     HTMLToRIP(Tree, Layout, RIPLines);
     For I := 0 to RIPLines.Count - 1 Do
       Engine.ProcessLine(RIPLines.Lines[I]);
*)
{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit htmlrip;

interface

Uses htmlpars, htmltree, htmllayo, meganum;

Const
  HTML_MAX_RIP_LINES = 256;

Type
  TRIPLineBuffer = record
    Lines : Array[0..HTML_MAX_RIP_LINES-1] of String;
    Count : Integer;
  end;

// Convert laid-out HTML tree to RIP command lines
procedure HTMLToRIP(var Tree: THTMLTree; var Layout: THTMLLayout;
                    var Buf: TRIPLineBuffer);

// Reset line buffer
procedure RIPBufReset(var Buf: TRIPLineBuffer);

// Add a RIP command line to buffer
procedure RIPBufAdd(var Buf: TRIPLineBuffer; const Line: String);

implementation

procedure RIPBufReset(var Buf: TRIPLineBuffer);
Begin
  Buf.Count := 0;
End;

procedure RIPBufAdd(var Buf: TRIPLineBuffer; const Line: String);
Begin
  If Buf.Count >= HTML_MAX_RIP_LINES Then Exit;
  Buf.Lines[Buf.Count] := Line;
  Inc(Buf.Count);
End;

function IntToHex2(V: Byte): String;
Const Hex : Array[0..15] of Char = '0123456789ABCDEF';
Begin
  Result := Hex[V SHR 4] + Hex[V AND $0F];
End;

function IntToStr(V: Integer): String;
Var S : String;
Begin
  Str(V, S);
  Result := S;
End;


// Map font size to RIP text size command parameter
function FontSizeToRIPSize(Size: Byte): Byte;
Begin
  If Size >= 28 Then Result := 4
  Else If Size >= 24 Then Result := 3
  Else If Size >= 20 Then Result := 2
  Else If Size >= 16 Then Result := 1
  Else Result := 0;
End;

// Generate RIP color command from RGB
function RIPColorCmd(R, G, B: Byte): String;
// v1.54 SetColor: |c followed by 2-digit MegaNum color index
// For RGB we use nearest EGA color (0-15)
Var Idx : Byte;
Begin
  // Simple luminance-based EGA mapping
  Idx := ((R DIV 85) SHL 2) or ((G DIV 85) SHL 1) or (B DIV 85);
  If Idx > 15 Then Idx := 15;
  Result := '|c' + MegaNumEncode(Idx, 2);
End;

// Generate RIP text at position
function RIPTextAt(X, Y: SmallInt; const Text: String): String;
// v1.54 TextXY: |T followed by 4-digit MegaNum coords + text
Begin
  If X < 0 Then X := 0;
  If Y < 0 Then Y := 0;
  Result := '|T' + MegaNumEncode(X, 4) + MegaNumEncode(Y, 4) + Text;
End;

// Generate RIP line (for HR, underline)
function RIPLine(X1, Y1, X2, Y2: SmallInt): String;
// v1.54 Line: |L followed by 4x4-digit MegaNum coords
Begin
  If X1 < 0 Then X1 := 0;
  If Y1 < 0 Then Y1 := 0;
  If X2 < 0 Then X2 := 0;
  If Y2 < 0 Then Y2 := 0;
  Result := '|L' + MegaNumEncode(X1, 4) + MegaNumEncode(Y1, 4) +
            MegaNumEncode(X2, 4) + MegaNumEncode(Y2, 4);
End;

// Generate RIP filled bar (for backgrounds, table cells)
function RIPBar(X1, Y1, X2, Y2: SmallInt): String;
Begin
  Result := '|B' + IntToStr(X1) + ',' + IntToStr(Y1) + ',' +
            IntToStr(X2) + ',' + IntToStr(Y2);
End;

procedure EmitBox(var Buf: TRIPLineBuffer; var Box: THTMLBox);
Var
  Node : PHTMLNode;
  Href : String;
Begin
  Node := Box.Node;
  If Node = Nil Then Exit;

  // Text node — emit text at position
  If Node^.Kind = hnkText Then Begin
    // Set color
    RIPBufAdd(Buf, RIPColorCmd(Box.Font.ColorR, Box.Font.ColorG, Box.Font.ColorB));
    // Emit text
    RIPBufAdd(Buf, RIPTextAt(Box.X, Box.Y, Node^.Text));
    Exit;
  End;

  If Node^.Kind <> hnkElement Then Exit;

  Case Node^.TagID of
    htHR: Begin
      // Horizontal rule — gray line
      RIPBufAdd(Buf, RIPColorCmd(128, 128, 128));
      RIPBufAdd(Buf, RIPLine(Box.X, Box.Y, Box.X + Box.W, Box.Y));
    End;

    htIMG: Begin
      // Image — emit LoadImage command
      // |1I followed by filename,x,y
      Href := HTMLNodeGetAttr(Node, 'SRC');
      If Length(Href) > 0 Then
        RIPBufAdd(Buf, '|1I' + Href + ',' + IntToStr(Box.X) + ',' + IntToStr(Box.Y));
    End;

    htA: Begin
      // Hyperlink — emit mouse field for click area
      Href := HTMLNodeGetAttr(Node, 'HREF');
      If Length(Href) > 0 Then
        RIPBufAdd(Buf, '|1U' + IntToStr(Box.X) + ',' + IntToStr(Box.Y) + ',' +
                  IntToStr(Box.X + Box.W) + ',' + IntToStr(Box.Y + Box.H) + ',' + Href);
    End;

    htLI: Begin
      // List item — emit bullet or number
      If Box.ListIndex > 0 Then
        // Ordered: number + dot
        RIPBufAdd(Buf, RIPTextAt(Box.X - 16, Box.Y, IntToStr(Box.ListIndex) + '.'))
      Else
        // Unordered: bullet character (CP437 #7)
        RIPBufAdd(Buf, RIPTextAt(Box.X - 12, Box.Y, Chr(7)));
    End;
  End;
End;

procedure HTMLToRIP(var Tree: THTMLTree; var Layout: THTMLLayout;
                    var Buf: TRIPLineBuffer);
Var
  I         : Integer;
  BodyNode  : PHTMLNode;
  BgColor   : String;
Begin
  RIPBufReset(Buf);

  // Clear screen
  RIPBufAdd(Buf, '|*');

  // Check BODY bgcolor attribute
  BodyNode := HTMLTreeFindTag(Tree, htBODY);
  If BodyNode <> Nil Then Begin
    BgColor := HTMLNodeGetAttr(BodyNode, 'BGCOLOR');
    // TODO: parse #RRGGBB bgcolor and emit fill
  End;

  // Set default text color (light gray on dark — BBS style)
  RIPBufAdd(Buf, RIPColorCmd(192, 192, 192));

  // Emit each layout box
  For I := 0 to Layout.BoxCount - 1 Do
    EmitBox(Buf, Layout.Boxes[I]);
End;

end.
