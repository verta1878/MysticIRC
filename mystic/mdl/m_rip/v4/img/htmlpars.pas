(* htmlpars.pas -- HTML 1.0 Tokenizer/Parser
   Copyright (C) 2026 Mystic BBS IRC Fork Contributors
   Licensed under GNU General Public License v3.

   Tokenizes HTML 1.0 (RFC 1866 / HTML 2.0 baseline) into a stream
   of tokens: tags (open/close), attributes, text, entities, comments.
   ~40 tag types supported. No CSS, no JavaScript.

   Usage:
     HTMLParserInit(P, '<html><body><h1>Hello</h1></body></html>');
     While HTMLNextToken(P, Tok) Do
       Case Tok.Kind of
         htkOpenTag:  WriteLn('Open: ', Tok.TagName);
         htkCloseTag: WriteLn('Close: ', Tok.TagName);
         htkText:     WriteLn('Text: ', Tok.Text);
       End;
*)
{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit htmlpars;

interface

Const
  HTML_MAX_ATTRS    = 16;   // max attributes per tag
  HTML_MAX_ATTRLEN  = 127;  // max attribute name/value length
  HTML_MAX_TEXTLEN  = 255;  // max text token length
  HTML_MAX_TAGLEN   = 12;   // max tag name length

Type
  THTMLTokenKind = (
    htkNone,        // no token / end of input
    htkOpenTag,     // <TAG>
    htkCloseTag,    // </TAG>
    htkSelfClose,   // <BR> <HR> <IMG> (void elements)
    htkText,        // plain text between tags
    htkComment,     // <!-- comment -->
    htkDocType      // <!DOCTYPE ...>
  );

  THTMLTagID = (
    htUnknown,
    // Document
    htHTML, htHEAD, htTITLE, htBODY, htMETA,
    // Block text
    htH1, htH2, htH3, htH4, htH5, htH6,
    htP, htBR, htHR, htPRE, htBLOCKQUOTE, htCENTER, htDIV,
    // Inline text
    htB, htI, htU, htTT, htEM, htSTRONG, htSMALL,
    htSUB, htSUP, htFONT,
    // Lists
    htUL, htOL, htLI, htDL, htDT, htDD,
    // Links/images
    htA, htIMG,
    // Tables
    htTABLE, htTR, htTD, htTH, htCAPTION,
    // Forms
    htFORM, htINPUT, htSELECT, htOPTION, htTEXTAREA
  );

  THTMLAttr = record
    Name  : String[HTML_MAX_ATTRLEN];
    Value : String[HTML_MAX_ATTRLEN];
  end;

  THTMLToken = record
    Kind      : THTMLTokenKind;
    TagID     : THTMLTagID;
    TagName   : String[HTML_MAX_TAGLEN];
    Text      : String[HTML_MAX_TEXTLEN];
    Attrs     : Array[0..HTML_MAX_ATTRS-1] of THTMLAttr;
    AttrCount : Integer;
  end;

  THTMLParser = record
    Src    : PChar;       // pointer to source HTML
    SrcLen : LongInt;     // total length
    Pos    : LongInt;     // current position (0-based)
  end;

// Initialize parser with HTML source string
procedure HTMLParserInit(var P: THTMLParser; Source: PChar; Len: LongInt);

// Get next token. Returns False when no more tokens.
function HTMLNextToken(var P: THTMLParser; var Tok: THTMLToken): Boolean;

// Look up tag name → THTMLTagID
function HTMLTagNameToID(const Name: String): THTMLTagID;

// Decode a single HTML entity (&amp; → &). Returns decoded char.
function HTMLDecodeEntity(const Entity: String): Char;

// Get attribute value by name. Returns '' if not found.
function HTMLGetAttr(var Tok: THTMLToken; const Name: String): String;

// Is this tag a void element (self-closing: BR, HR, IMG, INPUT, META)?
function HTMLIsVoidTag(ID: THTMLTagID): Boolean;

implementation

// ====================================================================
// Tag name lookup table
// ====================================================================

Type
  TTagEntry = record
    Name : String[12];
    ID   : THTMLTagID;
  end;

Const
  TAG_COUNT = 44;
  TagTable : Array[0..TAG_COUNT-1] of TTagEntry = (
    (Name: 'HTML';       ID: htHTML),
    (Name: 'HEAD';       ID: htHEAD),
    (Name: 'TITLE';      ID: htTITLE),
    (Name: 'BODY';       ID: htBODY),
    (Name: 'META';       ID: htMETA),
    (Name: 'H1';         ID: htH1),
    (Name: 'H2';         ID: htH2),
    (Name: 'H3';         ID: htH3),
    (Name: 'H4';         ID: htH4),
    (Name: 'H5';         ID: htH5),
    (Name: 'H6';         ID: htH6),
    (Name: 'P';          ID: htP),
    (Name: 'BR';         ID: htBR),
    (Name: 'HR';         ID: htHR),
    (Name: 'PRE';        ID: htPRE),
    (Name: 'BLOCKQUOTE'; ID: htBLOCKQUOTE),
    (Name: 'CENTER';     ID: htCENTER),
    (Name: 'DIV';        ID: htDIV),
    (Name: 'B';          ID: htB),
    (Name: 'I';          ID: htI),
    (Name: 'U';          ID: htU),
    (Name: 'TT';         ID: htTT),
    (Name: 'EM';         ID: htEM),
    (Name: 'STRONG';     ID: htSTRONG),
    (Name: 'SMALL';      ID: htSMALL),
    (Name: 'SUB';        ID: htSUB),
    (Name: 'SUP';        ID: htSUP),
    (Name: 'FONT';       ID: htFONT),
    (Name: 'UL';         ID: htUL),
    (Name: 'OL';         ID: htOL),
    (Name: 'LI';         ID: htLI),
    (Name: 'DL';         ID: htDL),
    (Name: 'DT';         ID: htDT),
    (Name: 'DD';         ID: htDD),
    (Name: 'A';          ID: htA),
    (Name: 'IMG';        ID: htIMG),
    (Name: 'TABLE';      ID: htTABLE),
    (Name: 'TR';         ID: htTR),
    (Name: 'TD';         ID: htTD),
    (Name: 'TH';         ID: htTH),
    (Name: 'CAPTION';    ID: htCAPTION),
    (Name: 'FORM';       ID: htFORM),
    (Name: 'INPUT';      ID: htINPUT),
    (Name: 'SELECT';     ID: htSELECT)
  );

// ====================================================================
// Utility
// ====================================================================

function UpCaseChar(C: Char): Char;
Begin
  If (C >= 'a') and (C <= 'z') Then
    Result := Chr(Ord(C) - 32)
  Else
    Result := C;
End;

function UpCaseStr(const S: String): String;
Var I : Integer;
Begin
  Result := S;
  For I := 1 to Length(Result) Do
    Result[I] := UpCaseChar(Result[I]);
End;

function IsAlpha(C: Char): Boolean;
Begin
  Result := ((C >= 'A') and (C <= 'Z')) or ((C >= 'a') and (C <= 'z'));
End;

function IsAlphaNum(C: Char): Boolean;
Begin
  Result := IsAlpha(C) or ((C >= '0') and (C <= '9'));
End;

function IsWhitespace(C: Char): Boolean;
Begin
  Result := (C = ' ') or (C = #9) or (C = #10) or (C = #13);
End;

function PeekChar(var P: THTMLParser): Char;
Begin
  If P.Pos < P.SrcLen Then
    Result := P.Src[P.Pos]
  Else
    Result := #0;
End;

function ReadChar(var P: THTMLParser): Char;
Begin
  If P.Pos < P.SrcLen Then Begin
    Result := P.Src[P.Pos];
    Inc(P.Pos);
  End Else
    Result := #0;
End;

procedure SkipWhitespace(var P: THTMLParser);
Begin
  While (P.Pos < P.SrcLen) and IsWhitespace(P.Src[P.Pos]) Do
    Inc(P.Pos);
End;

// ====================================================================
// Public functions
// ====================================================================

procedure HTMLParserInit(var P: THTMLParser; Source: PChar; Len: LongInt);
Begin
  P.Src    := Source;
  P.SrcLen := Len;
  P.Pos    := 0;
End;

function HTMLTagNameToID(const Name: String): THTMLTagID;
Var
  I  : Integer;
  Up : String;
Begin
  Result := htUnknown;
  Up := UpCaseStr(Name);
  For I := 0 to TAG_COUNT - 1 Do
    If TagTable[I].Name = Up Then Begin
      Result := TagTable[I].ID;
      Exit;
    End;
End;

function HTMLIsVoidTag(ID: THTMLTagID): Boolean;
Begin
  Result := ID in [htBR, htHR, htIMG, htINPUT, htMETA];
End;

function HTMLDecodeEntity(const Entity: String): Char;
// Decode &name; or &#num; to a CP437 character
Var
  Up  : String;
  Num : Integer;
  Code: Integer;
Begin
  Result := '?';
  If Length(Entity) = 0 Then Exit;

  // Numeric entity: &#123; or &#x7B;
  If Entity[1] = '#' Then Begin
    If (Length(Entity) > 1) and ((Entity[2] = 'x') or (Entity[2] = 'X')) Then Begin
      Val('$' + Copy(Entity, 3, Length(Entity) - 2), Num, Code);
    End Else Begin
      Val(Copy(Entity, 2, Length(Entity) - 1), Num, Code);
    End;
    If (Code = 0) and (Num >= 0) and (Num <= 255) Then
      Result := Chr(Num)
    Else If (Code = 0) and (Num > 255) Then
      Result := '?';  // out of CP437 range
    Exit;
  End;

  // Named entities → CP437
  Up := UpCaseStr(Entity);
  If Up = 'AMP'    Then Result := '&'
  Else If Up = 'LT'     Then Result := '<'
  Else If Up = 'GT'     Then Result := '>'
  Else If Up = 'QUOT'   Then Result := '"'
  Else If Up = 'APOS'   Then Result := ''''
  Else If Up = 'NBSP'   Then Result := Chr(255)
  Else If Up = 'COPY'   Then Result := Chr(184)
  Else If Up = 'REG'    Then Result := Chr(169)
  Else If Up = 'BULL'   Then Result := Chr(7)
  Else If Up = 'MDASH'  Then Result := Chr(196)
  Else If Up = 'NDASH'  Then Result := Chr(196)
  Else If Up = 'LAQUO'  Then Result := Chr(174)
  Else If Up = 'RAQUO'  Then Result := Chr(175)
  Else If Up = 'MIDDOT' Then Result := Chr(250)
  Else If Up = 'PARA'   Then Result := Chr(20)
  Else If Up = 'SECT'   Then Result := Chr(21)
  Else If Up = 'DEG'    Then Result := Chr(248)
  Else If Up = 'PLUSMN' Then Result := Chr(241)
  Else If Up = 'FRAC12' Then Result := Chr(171)
  Else If Up = 'FRAC14' Then Result := Chr(172)
  Else Result := '?';
End;

function HTMLGetAttr(var Tok: THTMLToken; const Name: String): String;
Var
  I  : Integer;
  Up : String;
Begin
  Result := '';
  Up := UpCaseStr(Name);
  For I := 0 to Tok.AttrCount - 1 Do
    If UpCaseStr(Tok.Attrs[I].Name) = Up Then Begin
      Result := Tok.Attrs[I].Value;
      Exit;
    End;
End;

// ====================================================================
// Tokenizer internals
// ====================================================================

function ReadTagName(var P: THTMLParser): String;
// Read a tag name (letters + digits, up to HTML_MAX_TAGLEN)
Var C : Char;
Begin
  Result := '';
  While P.Pos < P.SrcLen Do Begin
    C := P.Src[P.Pos];
    If IsAlphaNum(C) Then Begin
      If Length(Result) < HTML_MAX_TAGLEN Then
        Result := Result + C;
      Inc(P.Pos);
    End Else
      Break;
  End;
End;

function ReadAttrName(var P: THTMLParser): String;
Var C : Char;
Begin
  Result := '';
  While P.Pos < P.SrcLen Do Begin
    C := P.Src[P.Pos];
    If IsAlphaNum(C) or (C = '-') or (C = '_') Then Begin
      If Length(Result) < HTML_MAX_ATTRLEN Then
        Result := Result + C;
      Inc(P.Pos);
    End Else
      Break;
  End;
End;

function ReadAttrValue(var P: THTMLParser): String;
// Read attribute value: quoted ("val" or 'val') or unquoted (word)
Var
  Quote : Char;
  C     : Char;
Begin
  Result := '';
  SkipWhitespace(P);
  If P.Pos >= P.SrcLen Then Exit;

  C := P.Src[P.Pos];
  If (C = '"') or (C = '''') Then Begin
    // Quoted value
    Quote := C;
    Inc(P.Pos);
    While P.Pos < P.SrcLen Do Begin
      C := P.Src[P.Pos];
      Inc(P.Pos);
      If C = Quote Then Break;
      If Length(Result) < HTML_MAX_ATTRLEN Then
        Result := Result + C;
    End;
  End Else Begin
    // Unquoted value — read until whitespace or >
    While P.Pos < P.SrcLen Do Begin
      C := P.Src[P.Pos];
      If IsWhitespace(C) or (C = '>') Then Break;
      If Length(Result) < HTML_MAX_ATTRLEN Then
        Result := Result + C;
      Inc(P.Pos);
    End;
  End;
End;

procedure ParseAttributes(var P: THTMLParser; var Tok: THTMLToken);
// Parse all attributes until > or />
Var
  AName : String;
Begin
  Tok.AttrCount := 0;
  While P.Pos < P.SrcLen Do Begin
    SkipWhitespace(P);
    If P.Pos >= P.SrcLen Then Exit;

    // End of tag?
    If P.Src[P.Pos] = '>' Then Begin
      Inc(P.Pos);
      Exit;
    End;

    // Self-closing />?
    If (P.Src[P.Pos] = '/') and (P.Pos + 1 < P.SrcLen) and (P.Src[P.Pos + 1] = '>') Then Begin
      Inc(P.Pos, 2);
      Tok.Kind := htkSelfClose;
      Exit;
    End;

    // Read attribute name
    AName := ReadAttrName(P);
    If Length(AName) = 0 Then Begin
      // Skip unknown character
      Inc(P.Pos);
      Continue;
    End;

    If Tok.AttrCount < HTML_MAX_ATTRS Then Begin
      Tok.Attrs[Tok.AttrCount].Name := AName;
      Tok.Attrs[Tok.AttrCount].Value := '';

      // Check for = value
      SkipWhitespace(P);
      If (P.Pos < P.SrcLen) and (P.Src[P.Pos] = '=') Then Begin
        Inc(P.Pos); // skip =
        Tok.Attrs[Tok.AttrCount].Value := ReadAttrValue(P);
      End;

      Inc(Tok.AttrCount);
    End Else Begin
      // Too many attrs — skip
      SkipWhitespace(P);
      If (P.Pos < P.SrcLen) and (P.Src[P.Pos] = '=') Then Begin
        Inc(P.Pos);
        ReadAttrValue(P); // discard
      End;
    End;
  End;
End;

function ReadTextToken(var P: THTMLParser; var Tok: THTMLToken): Boolean;
// Read plain text until < or end of input. Decodes entities.
Var
  C      : Char;
  Entity : String;
Begin
  Result := False;
  Tok.Kind := htkText;
  Tok.Text := '';
  Tok.AttrCount := 0;
  Tok.TagID := htUnknown;
  Tok.TagName := '';

  While P.Pos < P.SrcLen Do Begin
    C := P.Src[P.Pos];
    If C = '<' Then Break;

    Inc(P.Pos);

    // Entity decoding
    If C = '&' Then Begin
      Entity := '';
      While (P.Pos < P.SrcLen) and (P.Src[P.Pos] <> ';') and
            (Length(Entity) < 10) Do Begin
        Entity := Entity + P.Src[P.Pos];
        Inc(P.Pos);
      End;
      If (P.Pos < P.SrcLen) and (P.Src[P.Pos] = ';') Then
        Inc(P.Pos); // skip ;
      C := HTMLDecodeEntity(Entity);
    End;

    If Length(Tok.Text) < HTML_MAX_TEXTLEN Then
      Tok.Text := Tok.Text + C;
    Result := True;
  End;
End;

function HTMLNextToken(var P: THTMLParser; var Tok: THTMLToken): Boolean;
Var
  C       : Char;
  IsClose : Boolean;
Begin
  Result := False;
  Tok.Kind      := htkNone;
  Tok.TagID     := htUnknown;
  Tok.TagName   := '';
  Tok.Text      := '';
  Tok.AttrCount := 0;

  If P.Pos >= P.SrcLen Then Exit;

  C := PeekChar(P);

  // Text content?
  If C <> '<' Then Begin
    Result := ReadTextToken(P, Tok);
    Exit;
  End;

  // It's a tag — skip <
  Inc(P.Pos);
  If P.Pos >= P.SrcLen Then Exit;

  C := PeekChar(P);

  // Comment: <!-- ... -->
  If (C = '!') and (P.Pos + 2 < P.SrcLen) and
     (P.Src[P.Pos + 1] = '-') and (P.Src[P.Pos + 2] = '-') Then Begin
    Inc(P.Pos, 3); // skip !--
    Tok.Kind := htkComment;
    Tok.Text := '';
    While P.Pos + 2 < P.SrcLen Do Begin
      If (P.Src[P.Pos] = '-') and (P.Src[P.Pos + 1] = '-') and (P.Src[P.Pos + 2] = '>') Then Begin
        Inc(P.Pos, 3);
        Break;
      End;
      If Length(Tok.Text) < HTML_MAX_TEXTLEN Then
        Tok.Text := Tok.Text + P.Src[P.Pos];
      Inc(P.Pos);
    End;
    Result := True;
    Exit;
  End;

  // DOCTYPE: <!DOCTYPE ...>
  If C = '!' Then Begin
    Inc(P.Pos);
    Tok.Kind := htkDocType;
    Tok.Text := '';
    While (P.Pos < P.SrcLen) and (P.Src[P.Pos] <> '>') Do Begin
      If Length(Tok.Text) < HTML_MAX_TEXTLEN Then
        Tok.Text := Tok.Text + P.Src[P.Pos];
      Inc(P.Pos);
    End;
    If P.Pos < P.SrcLen Then Inc(P.Pos); // skip >
    Result := True;
    Exit;
  End;

  // Closing tag: </TAG>
  IsClose := (C = '/');
  If IsClose Then Inc(P.Pos);

  // Read tag name
  Tok.TagName := ReadTagName(P);
  If Length(Tok.TagName) = 0 Then Begin
    // Malformed — skip to >
    While (P.Pos < P.SrcLen) and (P.Src[P.Pos] <> '>') Do Inc(P.Pos);
    If P.Pos < P.SrcLen Then Inc(P.Pos);
    Exit;
  End;

  Tok.TagID := HTMLTagNameToID(Tok.TagName);

  If IsClose Then Begin
    Tok.Kind := htkCloseTag;
    // Skip to >
    While (P.Pos < P.SrcLen) and (P.Src[P.Pos] <> '>') Do Inc(P.Pos);
    If P.Pos < P.SrcLen Then Inc(P.Pos);
  End Else Begin
    Tok.Kind := htkOpenTag;
    ParseAttributes(P, Tok);
    // Void elements are always self-closing
    If HTMLIsVoidTag(Tok.TagID) Then
      Tok.Kind := htkSelfClose;
  End;

  Result := True;
End;

end.
