{$MODE OBJFPC}{$H+}
Unit mt_spell;
{ Hunspell spell check — runtime dynamic loading.
  Bypasses FPC DynLibs unit to avoid -ldl link issue on modern glibc.
  On DOS (go32v2), spell check is disabled (no shared libraries).

  GPLv3 — FPC264IRC Contributors
  Credits: verta1878, sysop/0, evga, kiddo, wrench }

Interface

Uses SysUtils;

Type
  THunHandle = Pointer;

  THunSpell = Class
  Private
    FHandle  : THunHandle;
    FLoaded  : Boolean;
  Public
    Constructor Create(Const ADataPath: String);
    Destructor Destroy; Override;
    Function  IsLoaded: Boolean;
    Function  CheckWord(Const AWord: String): Boolean;
    Function  Suggest(Const AWord: String): String;
    Property  Loaded: Boolean Read FLoaded;
  End;

Implementation

{$IFDEF UNIX}
{ Direct dlopen/dlsym/dlclose — these are in libc on glibc 2.34+,
  so we don't need -ldl. On older systems they're in libdl which
  libc links anyway. }
const
  RTLD_LAZY = 1;

function dlopen(filename: PChar; flags: LongInt): Pointer; cdecl; external 'c';
function dlsym(handle: Pointer; symbol: PChar): Pointer; cdecl; external 'c';
function dlclose(handle: Pointer): LongInt; cdecl; external 'c';
{$ENDIF}

{$IFDEF WINDOWS}
function LoadLibraryA(lpFileName: PChar): Pointer; stdcall; external 'kernel32.dll';
function GetProcAddress(hModule: Pointer; lpProcName: PChar): Pointer; stdcall; external 'kernel32.dll';
function FreeLibrary(hModule: Pointer): LongBool; stdcall; external 'kernel32.dll';
{$ENDIF}

Type
  THunCreateFunc = Function(AffPath, DicPath: PChar): THunHandle; cdecl;
  THunDestroyProc = Procedure(H: THunHandle); cdecl;
  THunSpellFunc = Function(H: THunHandle; W: PChar): Integer; cdecl;
  THunSuggestFunc = Function(H: THunHandle; Var SL: PPChar; W: PChar): Integer; cdecl;
  THunFreeListProc = Procedure(H: THunHandle; SL: PPChar; N: Integer); cdecl;

Var
  HunLib: Pointer = nil;
  pCreate:   THunCreateFunc = nil;
  pDestroy:  THunDestroyProc = nil;
  pSpell:    THunSpellFunc = nil;
  pSuggest:  THunSuggestFunc = nil;
  pFreeList: THunFreeListProc = nil;
  LibTried:  Boolean = False;

function LoadLib(const Name: String): Pointer;
begin
  {$IFDEF UNIX}
  Result := dlopen(PChar(Name), RTLD_LAZY);
  {$ENDIF}
  {$IFDEF WINDOWS}
  Result := LoadLibraryA(PChar(Name));
  {$ENDIF}
  {$IFDEF GO32V2}
  Result := nil;
  {$ENDIF}
end;

function GetSym(Lib: Pointer; const Name: String): Pointer;
begin
  {$IFDEF UNIX}
  Result := dlsym(Lib, PChar(Name));
  {$ENDIF}
  {$IFDEF WINDOWS}
  Result := GetProcAddress(Lib, PChar(Name));
  {$ENDIF}
  {$IFDEF GO32V2}
  Result := nil;
  {$ENDIF}
end;

procedure CloseLib(Lib: Pointer);
begin
  {$IFDEF UNIX}
  dlclose(Lib);
  {$ENDIF}
  {$IFDEF WINDOWS}
  FreeLibrary(Lib);
  {$ENDIF}
end;

Procedure LoadHunspell;
Begin
  If LibTried Then Exit;
  LibTried := True;

  {$IFDEF WINDOWS}
  HunLib := LoadLib('libhunspell32.dll');
  If HunLib = nil Then HunLib := LoadLib('libhunspell64.dll');
  If HunLib = nil Then HunLib := LoadLib('hunspell.dll');
  {$ENDIF}
  {$IFDEF LINUX}
  HunLib := LoadLib('libhunspell.so');
  If HunLib = nil Then HunLib := LoadLib('libhunspell-1.7.so.0');
  If HunLib = nil Then HunLib := LoadLib('libhunspell-1.6.so.0');
  If HunLib = nil Then HunLib := LoadLib('libhunspell-1.5.so.0');
  {$ENDIF}
  {$IFDEF DARWIN}
  HunLib := LoadLib('libhunspell.dylib');
  {$ENDIF}

  If HunLib = nil Then Exit;

  pCreate   := THunCreateFunc(GetSym(HunLib, 'Hunspell_create'));
  pDestroy  := THunDestroyProc(GetSym(HunLib, 'Hunspell_destroy'));
  pSpell    := THunSpellFunc(GetSym(HunLib, 'Hunspell_spell'));
  pSuggest  := THunSuggestFunc(GetSym(HunLib, 'Hunspell_suggest'));
  pFreeList := THunFreeListProc(GetSym(HunLib, 'Hunspell_free_list'));
End;

Constructor THunSpell.Create(Const ADataPath: String);
Var AffFile, DicFile: String;
Begin
  Inherited Create;
  FLoaded := False;
  LoadHunspell;
  If HunLib = nil Then Exit;
  If Not Assigned(pCreate) Then Exit;
  If Not Assigned(pSpell) Then Exit;

  AffFile := ADataPath + 'dictionary.aff';
  DicFile := ADataPath + 'dictionary.dic';
  If Not FileExists(AffFile) Or Not FileExists(DicFile) Then Exit;

  FHandle := pCreate(PChar(AffFile), PChar(DicFile));
  If FHandle <> nil Then FLoaded := True;
End;

Destructor THunSpell.Destroy;
Begin
  If FLoaded And Assigned(pDestroy) Then pDestroy(FHandle);
  Inherited;
End;

Function THunSpell.IsLoaded: Boolean;
Begin Result := FLoaded; End;

Function THunSpell.CheckWord(Const AWord: String): Boolean;
Begin
  If Not FLoaded Then Begin Result := True; Exit; End;
  Result := pSpell(FHandle, PChar(AWord)) <> 0;
End;

Function THunSpell.Suggest(Const AWord: String): String;
Var SList: PPChar; N: Integer;
Begin
  Result := '';
  If Not FLoaded Or Not Assigned(pSuggest) Then Exit;
  N := pSuggest(FHandle, SList, PChar(AWord));
  If N > 0 Then Begin
    Result := StrPas(SList^);
    If Assigned(pFreeList) Then pFreeList(FHandle, SList, N);
  End;
End;

Finalization
  If HunLib <> nil Then CloseLib(HunLib);

End.
