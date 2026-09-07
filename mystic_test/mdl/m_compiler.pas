// ====================================================================
// m_compiler.pas — MDL Compiler Abstraction Layer
// ====================================================================
//
// Copyright (C) 2026 Mystic BBS IRC Fork Contributors — GPLv3
//
// Single include point for compiler detection and compatibility.
// Every MDL unit should `uses m_compiler;` or `{$I m_compiler.inc}`
// as its first dependency.
//
// SUPPORTED COMPILERS:
//   FPC 2.6.4irc    {$IFDEF FPC}
//   FPC 3.2.2+      {$IFDEF FPC}
//   Delphi 7+       {$IFDEF DELPHI} or {$IFDEF DCC}
//   Virtual Pascal  {$IFDEF VIRTUALPASCAL}
//   Turbo Pascal 7  {$IFDEF TURBOPASCAL}
//
// USAGE:
//   uses m_compiler;   // sets up types, string mode, compiler quirks
//
// WHAT THIS PROVIDES:
//   - MDL_FPC, MDL_DELPHI, MDL_VP, MDL_TP compiler symbols
//   - MDL_WIN, MDL_UNIX, MDL_DOS, MDL_OS2 platform symbols
//   - Cross-compiler type aliases (PtrInt, PtrUInt, SizeInt)
//   - String mode normalization (AnsiString everywhere)
//   - Inline/override keyword compatibility
//
// CREDITS:
//   sysop/0 — architecture, initial draft
// ====================================================================

Unit m_compiler;

{$IFDEF FPC}
  {$MODE OBJFPC}
  {$H+}
  {$DEFINE MDL_FPC}
{$ENDIF}

{$IFDEF DCC}
  {$DEFINE MDL_DELPHI}
{$ENDIF}

{$IFDEF VIRTUALPASCAL}
  {$DEFINE MDL_VP}
{$ENDIF}

{$IFDEF VER70}
  {$DEFINE MDL_TP}
  {$DEFINE TURBOPASCAL}
{$ENDIF}

// ---- Platform normalization ----

{$IFDEF MSWINDOWS}  {$DEFINE MDL_WIN}    {$ENDIF}
{$IFDEF WINDOWS}    {$DEFINE MDL_WIN}    {$ENDIF}
{$IFDEF WIN32}      {$DEFINE MDL_WIN}    {$ENDIF}
{$IFDEF WIN64}      {$DEFINE MDL_WIN}    {$ENDIF}

{$IFDEF LINUX}      {$DEFINE MDL_UNIX}   {$ENDIF}
{$IFDEF FREEBSD}    {$DEFINE MDL_UNIX}   {$ENDIF}
{$IFDEF OPENBSD}    {$DEFINE MDL_UNIX}   {$ENDIF}
{$IFDEF NETBSD}     {$DEFINE MDL_UNIX}   {$ENDIF}
{$IFDEF DARWIN}     {$DEFINE MDL_UNIX}   {$ENDIF}
{$IFDEF UNIX}       {$DEFINE MDL_UNIX}   {$ENDIF}

{$IFDEF GO32V2}     {$DEFINE MDL_DOS}    {$ENDIF}
{$IFDEF MSDOS}      {$DEFINE MDL_DOS}    {$ENDIF}
{$IFDEF DPMI}       {$DEFINE MDL_DOS}    {$ENDIF}

{$IFDEF OS2}        {$DEFINE MDL_OS2}    {$ENDIF}

Interface

// ====================================================================
// Type aliases — same types, every compiler
// ====================================================================

{$IFNDEF MDL_FPC}
Type
  {$IFDEF MDL_DELPHI}
  {$IF CompilerVersion < 23}
  PtrInt   = Integer;
  PtrUInt  = Cardinal;
  SizeInt  = Integer;
  SizeUInt = Cardinal;
  {$ELSE}
  PtrInt   = NativeInt;
  PtrUInt  = NativeUInt;
  SizeInt  = NativeInt;
  SizeUInt = NativeUInt;
  {$IFEND}
  QWord    = UInt64;
  {$ENDIF}

  {$IFDEF MDL_VP}
  PtrInt   = LongInt;
  PtrUInt  = Cardinal;
  SizeInt  = LongInt;
  SizeUInt = Cardinal;
  QWord    = Int64;
  {$ENDIF}

  {$IFDEF MDL_TP}
  PtrInt   = Integer;
  PtrUInt  = Word;
  SizeInt  = Integer;
  SizeUInt = Word;
  LongWord = LongInt;
  {$ENDIF}
{$ENDIF}

// ====================================================================
// Compiler capability flags
// ====================================================================

Const
  MDL_HAS_CLASSES     = {$IFDEF MDL_TP} False {$ELSE} True {$ENDIF};
  MDL_HAS_EXCEPTIONS  = {$IFDEF MDL_TP} False {$ELSE} True {$ENDIF};
  MDL_HAS_ANSISTRING  = {$IFDEF MDL_TP} False {$ELSE} True {$ENDIF};
  MDL_HAS_INT64       = {$IFDEF MDL_TP} False {$ELSE} True {$ENDIF};
  MDL_HAS_DYNARRAY    = {$IFDEF MDL_TP} False {$ELSE} True {$ENDIF};
  MDL_HAS_OVERLOAD    = {$IFDEF MDL_TP} False {$ELSE} True {$ENDIF};

// ====================================================================
// Platform info
// ====================================================================

  MDL_PLATFORM =
    {$IFDEF MDL_WIN}  'WINDOWS' {$ENDIF}
    {$IFDEF MDL_UNIX} 'UNIX'    {$ENDIF}
    {$IFDEF MDL_DOS}  'DOS'     {$ENDIF}
    {$IFDEF MDL_OS2}  'OS2'     {$ENDIF} ;

  MDL_COMPILER =
    {$IFDEF MDL_FPC}    'FPC'    {$ENDIF}
    {$IFDEF MDL_DELPHI} 'DELPHI' {$ENDIF}
    {$IFDEF MDL_VP}     'VP'     {$ENDIF}
    {$IFDEF MDL_TP}     'TP7'    {$ENDIF} ;

  MDL_PATHSEP =
    {$IFDEF MDL_WIN} '\' {$ENDIF}
    {$IFDEF MDL_UNIX} '/' {$ENDIF}
    {$IFDEF MDL_DOS} '\' {$ENDIF}
    {$IFDEF MDL_OS2} '\' {$ENDIF} ;

  MDL_LINEENDING =
    {$IFDEF MDL_WIN}  #13#10 {$ENDIF}
    {$IFDEF MDL_UNIX} #10    {$ENDIF}
    {$IFDEF MDL_DOS}  #13#10 {$ENDIF}
    {$IFDEF MDL_OS2}  #13#10 {$ENDIF} ;

// ====================================================================
// Serial device defaults
// ====================================================================

  MDL_DEFAULT_SERIAL =
    {$IFDEF LINUX}   '/dev/ttyS0'     {$ENDIF}
    {$IFDEF FREEBSD} '/dev/cuau0'     {$ENDIF}
    {$IFDEF DARWIN}   '/dev/cu.serial' {$ENDIF}
    {$IFDEF MDL_WIN} 'COM1'           {$ENDIF}
    {$IFDEF MDL_OS2} 'COM1'           {$ENDIF}
    {$IFDEF MDL_DOS} 'COM1'           {$ENDIF} ;

Implementation

End.
