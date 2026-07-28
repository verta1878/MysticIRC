Unit bbs_hunspell;

// ====================================================================
// Mystic BBS — Hunspell Spell Check Integration
// ====================================================================
//
// Dynamically loads libhunspell at runtime.
// If DLL/SO not found, spell check is silently disabled.
//
// g00r00 pattern: same as Python — LoadLibrary + GetProcAddress.
// Requires: dictionary.dic + dictionary.aff in DataPath.
//
// GPLv3.

{$I M_OPS.PAS}

Interface

Uses
  {$IFDEF WINDOWS} Windows, {$ENDIF}
  {$IFDEF UNIX} DynLibs, {$ENDIF}
  SysUtils;

Type
  THunHandle = Pointer;

  THunSpell = Class
  Private
    FLib       : TLibHandle;
    FHandle    : THunHandle;
    FLoaded    : Boolean;
    FDictPath  : String;
    { Function pointers }
    FCreate    : Function(AffPath, DicPath: PChar): THunHandle; cdecl;
    FDestroy   : Procedure(H: THunHandle); cdecl;
    FSpell     : Function(H: THunHandle; Word: PChar): Integer; cdecl;
    FSuggest   : Function(H: THunHandle; Var SList: PPChar; Word: PChar): Integer; cdecl;
    FFreeSug   : Procedure(H: THunHandle; SList: PPChar; N: Integer); cdecl;
  Public
    Constructor Create(Const ADataPath: String);
    Destructor Destroy; Override;
    Function  IsLoaded: Boolean;
    Function  CheckWord(Const AWord: String): Boolean;
    Function  Suggest(Const AWord: String): String;
    Property  Loaded: Boolean Read FLoaded;
  End;

Implementation

Constructor THunSpell.Create(Const ADataPath: String);
Var
  AffFile, DicFile: String;
Begin
  Inherited Create;
  FLoaded := False;
  FDictPath := ADataPath;

  { Try loading hunspell library }
  {$IFDEF WINDOWS}
  FLib := LoadLibrary('libhunspell32.dll');
  If FLib = 0 Then FLib := LoadLibrary('libhunspell64.dll');
  If FLib = 0 Then FLib := LoadLibrary('hunspell.dll');
  {$ENDIF}
  {$IFDEF LINUX}
  FLib := LoadLibrary('libhunspell.so');
  If FLib = 0 Then FLib := LoadLibrary('libhunspell-1.7.so.0');
  If FLib = 0 Then FLib := LoadLibrary('libhunspell-1.6.so.0');
  {$ENDIF}
  {$IFDEF DARWIN}
  FLib := LoadLibrary('libhunspell.dylib');
  {$ENDIF}

  If FLib = 0 Then Exit;

  { Load function pointers }
  Pointer(FCreate)  := GetProcAddress(FLib, 'Hunspell_create');
  Pointer(FDestroy) := GetProcAddress(FLib, 'Hunspell_destroy');
  Pointer(FSpell)   := GetProcAddress(FLib, 'Hunspell_spell');
  Pointer(FSuggest) := GetProcAddress(FLib, 'Hunspell_suggest');
  Pointer(FFreeSug) := GetProcAddress(FLib, 'Hunspell_free_list');

  If Not Assigned(FCreate) Then Exit;
  If Not Assigned(FSpell)  Then Exit;

  { Open dictionary }
  AffFile := ADataPath + 'dictionary.aff';
  DicFile := ADataPath + 'dictionary.dic';

  If Not FileExists(AffFile) Or Not FileExists(DicFile) Then Exit;

  FHandle := FCreate(PChar(AffFile), PChar(DicFile));
  If FHandle = Nil Then Exit;

  FLoaded := True;
End;

Destructor THunSpell.Destroy;
Begin
  If FLoaded And Assigned(FDestroy) Then
    FDestroy(FHandle);
  If FLib <> 0 Then
    FreeLibrary(FLib);
  Inherited;
End;

Function THunSpell.IsLoaded: Boolean;
Begin
  Result := FLoaded;
End;

Function THunSpell.CheckWord(Const AWord: String): Boolean;
Begin
  If Not FLoaded Then Begin Result := True; Exit; End;
  Result := FSpell(FHandle, PChar(AWord)) <> 0;
End;

Function THunSpell.Suggest(Const AWord: String): String;
Var
  SList: PPChar;
  N: Integer;
Begin
  Result := '';
  If Not FLoaded Then Exit;
  If Not Assigned(FSuggest) Then Exit;

  N := FSuggest(FHandle, SList, PChar(AWord));
  If N > 0 Then Begin
    Result := StrPas(SList^);
    If Assigned(FFreeSug) Then
      FFreeSug(FHandle, SList, N);
  End;
End;

End.
