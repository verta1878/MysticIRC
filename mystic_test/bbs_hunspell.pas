Unit bbs_hunspell;

// Mystic BBS — Hunspell Spell Check Integration
// Dynamically loads libhunspell at runtime.
// GPLv3.

{$I M_OPS.PAS}

Interface

Uses
  {$IFDEF WINDOWS} Windows, {$ENDIF}
  DynLibs;

Type
  THunHandle = Pointer;
  PPChar = ^PChar;

  THunCreateFunc  = Function(AffPath, DicPath: PChar): THunHandle; cdecl;
  THunDestroyProc = Procedure(H: THunHandle); cdecl;
  THunSpellFunc   = Function(H: THunHandle; Word: PChar): Integer; cdecl;
  THunSuggestFunc = Function(H: THunHandle; Var SList: PPChar; Word: PChar): Integer; cdecl;
  THunFreeProc    = Procedure(H: THunHandle; SList: PPChar; N: Integer); cdecl;

  THunSpell = Class
  Private
    FLib       : TLibHandle;
    FHandle    : THunHandle;
    FLoaded    : Boolean;
    FCreate    : THunCreateFunc;
    FDestroy   : THunDestroyProc;
    FSpell     : THunSpellFunc;
    FSuggest   : THunSuggestFunc;
    FFreeSug   : THunFreeProc;
  Public
    Constructor Create(Const ADataPath: String);
    Destructor Destroy; Override;
    Function  CheckWord(Const AWord: String): Boolean;
    Function  Suggest(Const AWord: String): String;
    Property  Loaded: Boolean Read FLoaded;
  End;

Implementation

Constructor THunSpell.Create(Const ADataPath: String);
Var
  AffFile, DicFile: String;
  AffPChar, DicPChar: PChar;
Begin
  Inherited Create;

  FLoaded  := False;
  FLib     := NilHandle;
  FHandle  := Nil;

  { Try loading library }
  {$IFDEF WINDOWS}
  FLib := LoadLibrary('libhunspell32.dll');
  If FLib = NilHandle Then FLib := LoadLibrary('hunspell.dll');
  {$ENDIF}
  {$IFDEF UNIX}
  FLib := LoadLibrary('libhunspell.so');
  If FLib = NilHandle Then FLib := LoadLibrary('libhunspell-1.7.so.0');
  If FLib = NilHandle Then FLib := LoadLibrary('libhunspell-1.6.so.0');
  {$ENDIF}
  {$IFDEF DARWIN}
  FLib := LoadLibrary('libhunspell.dylib');
  {$ENDIF}

  If FLib = NilHandle Then Exit;

  { Load function pointers }
  @FCreate  := GetProcAddress(FLib, 'Hunspell_create');
  @FDestroy := GetProcAddress(FLib, 'Hunspell_destroy');
  @FSpell   := GetProcAddress(FLib, 'Hunspell_spell');
  @FSuggest := GetProcAddress(FLib, 'Hunspell_suggest');
  @FFreeSug := GetProcAddress(FLib, 'Hunspell_free_list');

  If Not Assigned(FCreate) Then Exit;
  If Not Assigned(FSpell)  Then Exit;

  { Open dictionary }
  AffFile := ADataPath + 'dictionary.aff';
  DicFile := ADataPath + 'dictionary.dic';

  AffPChar := @AffFile[1];
  DicPChar := @DicFile[1];

  FHandle := FCreate(AffPChar, DicPChar);

  If FHandle <> Nil Then
    FLoaded := True;
End;

Destructor THunSpell.Destroy;
Begin
  If (FHandle <> Nil) And Assigned(FDestroy) Then
    FDestroy(FHandle);

  If FLib <> NilHandle Then
    FreeLibrary(FLib);

  Inherited Destroy;
End;

Function THunSpell.CheckWord(Const AWord: String): Boolean;
Var
  P: PChar;
Begin
  If Not FLoaded Then Begin Result := True; Exit; End;
  P := @AWord[1];
  Result := FSpell(FHandle, P) <> 0;
End;

Function THunSpell.Suggest(Const AWord: String): String;
Var
  SList: PPChar;
  N: Integer;
  P: PChar;
Begin
  Result := '';
  If Not FLoaded Then Exit;
  If Not Assigned(FSuggest) Then Exit;

  P := @AWord[1];
  N := FSuggest(FHandle, SList, P);
  If N > 0 Then Begin
    Result := StrPas(SList^);
    If Assigned(FFreeSug) Then
      FFreeSug(FHandle, SList, N);
  End;
End;

End.
