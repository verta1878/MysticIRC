(* htmltree.pas -- HTML 1.0 DOM-Lite Tree
   Copyright (C) 2026 Mystic BBS IRC Fork Contributors
   Licensed under GNU General Public License v3.

   Builds a lightweight document tree from htmlpars tokens.
   Parent/child/sibling structure. No full DOM — just enough
   for layout and rendering.

   Usage:
     HTMLTreeParse(Tree, '<html><body><p>Hello</p></body></html>');
     Node := Tree.Root;
     While Node <> Nil Do ...
     HTMLTreeFree(Tree);
*)
{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit htmltree;

interface

Uses htmlpars;

Const
  HTML_MAX_NODES = 128;    // max nodes in document tree
  HTML_MAX_DEPTH = 32;     // max nesting depth

Type
  PHTMLNode = ^THTMLNode;

  THTMLNodeKind = (
    hnkElement,   // tag element (<P>, <H1>, etc)
    hnkText,      // text content
    hnkComment,   // <!-- comment -->
    hnkDocType    // <!DOCTYPE>
  );

  THTMLNode = record
    Kind       : THTMLNodeKind;
    TagID      : THTMLTagID;
    TagName    : String[HTML_MAX_TAGLEN];
    Text       : String[80];   // truncated for stack safety
    Attrs      : Array[0..3] of THTMLAttr;  // max 4 attrs per node
    AttrCount  : Integer;
    Parent     : PHTMLNode;
    FirstChild : PHTMLNode;
    LastChild  : PHTMLNode;
    NextSib    : PHTMLNode;
    Index      : Integer;    // node index in pool
  end;

  THTMLTree = record
    Nodes     : Array[0..HTML_MAX_NODES-1] of THTMLNode;
    NodeCount : Integer;
    Root      : PHTMLNode;  // points to <HTML> or first element
  end;

// Parse HTML source into a tree
procedure HTMLTreeParse(var Tree: THTMLTree; Source: PChar; Len: LongInt);

// Free tree (resets node count)
procedure HTMLTreeFree(var Tree: THTMLTree);

// Allocate a new node in the tree pool
function HTMLTreeNewNode(var Tree: THTMLTree): PHTMLNode;

// Find first node with given tag ID (depth-first)
function HTMLTreeFindTag(var Tree: THTMLTree; ID: THTMLTagID): PHTMLNode;

// Get attribute value from a node
function HTMLNodeGetAttr(Node: PHTMLNode; const Name: String): String;

// Count children of a node
function HTMLNodeChildCount(Node: PHTMLNode): Integer;

implementation

function HTMLTreeNewNode(var Tree: THTMLTree): PHTMLNode;
Begin
  Result := Nil;
  If Tree.NodeCount >= HTML_MAX_NODES Then Exit;
  Result := @Tree.Nodes[Tree.NodeCount];
  FillChar(Result^, SizeOf(THTMLNode), 0);
  Result^.Kind       := hnkElement;
  Result^.TagID      := htUnknown;
  Result^.Parent     := Nil;
  Result^.FirstChild := Nil;
  Result^.LastChild  := Nil;
  Result^.NextSib    := Nil;
  Result^.AttrCount  := 0;
  Result^.Index      := Tree.NodeCount;
  Inc(Tree.NodeCount);
End;

procedure AppendChild(Parent, Child: PHTMLNode);
Begin
  If (Parent = Nil) or (Child = Nil) Then Exit;
  Child^.Parent  := Parent;
  Child^.NextSib := Nil;
  If Parent^.FirstChild = Nil Then Begin
    Parent^.FirstChild := Child;
    Parent^.LastChild  := Child;
  End Else Begin
    Parent^.LastChild^.NextSib := Child;
    Parent^.LastChild := Child;
  End;
End;

function IsAutoCloseTag(ID: THTMLTagID): Boolean;
// Tags that auto-close when a sibling of the same type opens
// e.g. <LI> closes previous <LI>, <P> closes previous <P>
Begin
  Result := ID in [htP, htLI, htDT, htDD, htTR, htTD, htTH, htOPTION];
End;

procedure HTMLTreeParse(var Tree: THTMLTree; Source: PChar; Len: LongInt);
Var
  P       : THTMLParser;
  Tok     : THTMLToken;
  Node    : PHTMLNode;
  Current : PHTMLNode;
  Stack   : Array[0..HTML_MAX_DEPTH-1] of PHTMLNode;
  Depth   : Integer;
  I       : Integer;
Begin
  Tree.NodeCount := 0;
  Tree.Root      := Nil;
  Depth          := 0;
  Current        := Nil;

  HTMLParserInit(P, Source, Len);

  While HTMLNextToken(P, Tok) Do Begin
    Case Tok.Kind of
      htkText: Begin
        // Skip whitespace-only text
        If Length(Tok.Text) > 0 Then Begin
          Node := HTMLTreeNewNode(Tree);
          If Node = Nil Then Exit; // pool full
          Node^.Kind := hnkText;
          Node^.Text := Tok.Text;
          If Current <> Nil Then
            AppendChild(Current, Node)
          Else If Tree.Root = Nil Then
            Tree.Root := Node;
        End;
      End;

      htkComment: Begin
        Node := HTMLTreeNewNode(Tree);
        If Node = Nil Then Exit;
        Node^.Kind := hnkComment;
        Node^.Text := Tok.Text;
        If Current <> Nil Then
          AppendChild(Current, Node);
      End;

      htkDocType: Begin
        Node := HTMLTreeNewNode(Tree);
        If Node = Nil Then Exit;
        Node^.Kind := hnkDocType;
        Node^.Text := Tok.Text;
        // DOCTYPE is always at root level
      End;

      htkOpenTag: Begin
        // Auto-close check: if same tag type opens, close previous
        If (Current <> Nil) and IsAutoCloseTag(Tok.TagID) and
           (Current^.TagID = Tok.TagID) Then Begin
          If Depth > 0 Then Begin
            Dec(Depth);
            Current := Stack[Depth];
          End;
        End;

        Node := HTMLTreeNewNode(Tree);
        If Node = Nil Then Exit;
        Node^.Kind      := hnkElement;
        Node^.TagID     := Tok.TagID;
        Node^.TagName   := Tok.TagName;
        If Tok.AttrCount > 4 Then Node^.AttrCount := 4 Else Node^.AttrCount := Tok.AttrCount;
        For I := 0 to Node^.AttrCount - 1 Do
          Node^.Attrs[I] := Tok.Attrs[I];

        If Current <> Nil Then
          AppendChild(Current, Node)
        Else If Tree.Root = Nil Then
          Tree.Root := Node;

        // Push onto stack for nesting
        If Depth < HTML_MAX_DEPTH Then Begin
          Stack[Depth] := Current;
          Inc(Depth);
        End;
        Current := Node;
      End;

      htkSelfClose: Begin
        Node := HTMLTreeNewNode(Tree);
        If Node = Nil Then Exit;
        Node^.Kind      := hnkElement;
        Node^.TagID     := Tok.TagID;
        Node^.TagName   := Tok.TagName;
        If Tok.AttrCount > 4 Then Node^.AttrCount := 4 Else Node^.AttrCount := Tok.AttrCount;
        For I := 0 to Node^.AttrCount - 1 Do
          Node^.Attrs[I] := Tok.Attrs[I];

        If Current <> Nil Then
          AppendChild(Current, Node)
        Else If Tree.Root = Nil Then
          Tree.Root := Node;
        // Self-close — don't push onto stack
      End;

      htkCloseTag: Begin
        // Walk up stack to find matching open tag
        If (Current <> Nil) and (Current^.TagID = Tok.TagID) Then Begin
          // Direct match — pop
          If Depth > 0 Then Begin
            Dec(Depth);
            Current := Stack[Depth];
          End Else
            Current := Nil;
        End Else Begin
          // Search up for matching tag
          I := Depth - 1;
          While I >= 0 Do Begin
            If (Stack[I] <> Nil) and (Stack[I]^.TagID = Tok.TagID) Then Begin
              Depth := I;
              Current := Stack[Depth];
              Break;
            End;
            Dec(I);
          End;
        End;
      End;
    End; // case
  End; // while
End;

procedure HTMLTreeFree(var Tree: THTMLTree);
Begin
  Tree.NodeCount := 0;
  Tree.Root      := Nil;
End;

function HTMLTreeFindTag(var Tree: THTMLTree; ID: THTMLTagID): PHTMLNode;
Var I : Integer;
Begin
  Result := Nil;
  For I := 0 to Tree.NodeCount - 1 Do
    If (Tree.Nodes[I].Kind = hnkElement) and (Tree.Nodes[I].TagID = ID) Then Begin
      Result := @Tree.Nodes[I];
      Exit;
    End;
End;

function HTMLNodeGetAttr(Node: PHTMLNode; const Name: String): String;
Var
  I  : Integer;
  Up : String;
Begin
  Result := '';
  If Node = Nil Then Exit;
  Up := Name;
  // Inline upcase
  For I := 1 to Length(Up) Do
    If (Up[I] >= 'a') and (Up[I] <= 'z') Then
      Up[I] := Chr(Ord(Up[I]) - 32);

  For I := 0 to Node^.AttrCount - 1 Do Begin
    If Node^.Attrs[I].Name = Up Then Begin
      Result := Node^.Attrs[I].Value;
      Exit;
    End;
  End;
End;

function HTMLNodeChildCount(Node: PHTMLNode): Integer;
Var Child : PHTMLNode;
Begin
  Result := 0;
  If Node = Nil Then Exit;
  Child := Node^.FirstChild;
  While Child <> Nil Do Begin
    Inc(Result);
    Child := Child^.NextSib;
  End;
End;

end.
