//
// This file is part of the Mystic BBS IRC Fork.
//
// Copyright (C) 2026 Mystic BBS IRC Fork Contributors
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
//
unit utrayit;
{ ==========================================================================
  utrayit - cross-platform console-window tray/minimize class for FPC 2.6.4

  Compiles on every FPC 2.6.4irc target. Capabilities per platform:

    win32/win64  : Windows 2000/XP through Windows 11. Only APIs that
                   exist since Win2000 are imported (GetConsoleWindow,
                   Shell_NotifyIconW V2 layout), so the unit is XP-safe
                   with no dynamic loading needed.
                   MinimizeConsole / RestoreConsole via the real console
                   window handle. TrayConsole hides the console and puts
                   a live icon in the notification area (background
                   thread runs the message pump, so plain console
                   programs need no message loop of their own). The icon
                   is removed and the console restored on left-click, on
                   UnTrayConsole, or automatically at unit finalization -
                   so no stuck Win7 icons, ever.

    unix (linux, freebsd, ...) :
                   MinimizeConsole / RestoreConsole send the XTWINOPS
                   escape sequences (CSI 2 t = iconify, CSI 1 t =
                   de-iconify) to the controlling terminal. Works in
                   xterm and most xterm-compatible emulators; silently
                   ignored elsewhere. TrayConsole falls back to
                   MinimizeConsole (there is no portable tray for a
                   plain tty).

    go32v2 / msdos / os2 / everything else :
                   graceful stubs - all methods return False,
                   ConsoleSupported/TraySupported report False.
                   Programs using the class still compile and run.

  Usage:
      uses utrayit;
      var t: TTrayIt;
      begin
        t := TTrayIt.Create;
        t.TrayConsole('My daemon - click to restore');
        ... work ...
        t.UnTrayConsole;
        t.Free;
      end.
  ========================================================================== }
{$mode objfpc}{$H+}

interface

type
  TTrayIt = class
  private
    FInTray    : Boolean;
    FMinimized : Boolean;
  public
    destructor Destroy; override;

    { True if this platform can minimize/restore the console window }
    class function ConsoleSupported: Boolean;
    { True if this platform has a real notification-area tray }
    class function TraySupported: Boolean;

    { Minimize the console window (iconify). }
    function MinimizeConsole: Boolean;
    { Restore / de-iconify the console window. }
    function RestoreConsole: Boolean;

    { Hide the console completely and show a tray icon (Windows).
      On platforms without a tray this falls back to MinimizeConsole. }
    function TrayConsole(const ATip: string): Boolean;
    { Remove the tray icon and show the console again. }
    function UnTrayConsole: Boolean;

    property InTray: Boolean read FInTray;
    property Minimized: Boolean read FMinimized;
  end;

implementation

{ ========================================================================= }
{$IFDEF WINDOWS}
{ ========================================================================= }
uses
  Windows;

const
  WM_TRAYCB  = WM_APP + 1;
  NIM_ADD    = 0;  NIM_DELETE = 2;
  NIF_MESSAGE= 1;  NIF_ICON   = 2;  NIF_TIP = 4;
  GCL_HICONSM= -34;

type
  { NOTIFYICONDATAW, Win2000 layout (936 bytes) - fine on Win2k..Win11 }
  TNID = packed record
    cbSize          : DWORD;
    hWnd            : HWND;
    uID             : UINT;
    uFlags          : UINT;
    uCallbackMessage: UINT;
    hIcon           : HICON;
    szTip           : array[0..127] of WideChar;
    dwState         : DWORD;
    dwStateMask     : DWORD;
    szInfo          : array[0..255] of WideChar;
    uVersion        : UINT;
    szInfoTitle     : array[0..63] of WideChar;
    dwInfoFlags     : DWORD;
  end;

function Shell_NotifyIconW(dwMessage: DWORD; var nid: TNID): BOOL; stdcall;
  external 'shell32.dll' name 'Shell_NotifyIconW';
function XGetConsoleWindow: HWND; stdcall;
  external 'kernel32.dll' name 'GetConsoleWindow';

var
  gHelperWnd   : HWND    = 0;      { hidden window owning the tray icon }
  gThread      : THandle = 0;
  gThreadId    : DWORD   = 0;
  gTipW        : WideString = '';
  gClicked     : Boolean = False;  { user clicked the icon               }
  gClassDone   : Boolean = False;
  gTaskbarMsg  : UINT    = 0;

procedure HelperAddIcon; forward;

function HelperWndProc(h: HWND; msg: UINT; wp: WPARAM; lp: LPARAM): LRESULT; stdcall;
var
  nid: TNID;
begin
  Result := 0;
  if (gTaskbarMsg <> 0) and (msg = gTaskbarMsg) then
  begin
    HelperAddIcon;                       { Explorer restarted: re-add }
    Exit;
  end;
  case msg of
    WM_TRAYCB:
      if (LOWORD(lp) = WM_LBUTTONUP) or (LOWORD(lp) = WM_LBUTTONDBLCLK) then
      begin
        gClicked := True;
        PostMessage(h, WM_CLOSE, 0, 0);  { thread cleans up + restores }
      end;
    WM_CLOSE:
      DestroyWindow(h);
    WM_DESTROY:
      begin
        FillChar(nid, SizeOf(nid), 0);
        nid.cbSize := SizeOf(nid);
        nid.hWnd   := h;
        nid.uID    := 1;
        Shell_NotifyIconW(NIM_DELETE, nid);   { never leave a stuck icon }
        gHelperWnd := 0;
        PostQuitMessage(0);
      end;
  else
    Result := DefWindowProcW(h, msg, wp, lp);
  end;
end;

function ConsoleIcon: HICON;
var
  cw: HWND;
begin
  { Try embedded resource first (MAINICON from mystic.res) }
  Result := LoadIcon(GetModuleHandleW(nil), 'MAINICON');
  if Result <> 0 then Exit;
  
  { Fall back to console window class icon }
  cw := XGetConsoleWindow;
  if cw <> 0 then
  begin
    Result := HICON(GetClassLongW(cw, GCL_HICONSM));
    if Result = 0 then Result := HICON(GetClassLongW(cw, GCL_HICON));
  end;
  if Result = 0 then Result := LoadIcon(0, IDI_APPLICATION);
end;

procedure HelperAddIcon;
var
  nid: TNID;
  n  : integer;
begin
  if gHelperWnd = 0 then Exit;
  FillChar(nid, SizeOf(nid), 0);
  nid.cbSize := SizeOf(nid);
  nid.hWnd   := gHelperWnd;
  nid.uID    := 1;
  nid.uFlags := NIF_MESSAGE or NIF_ICON or NIF_TIP;
  nid.uCallbackMessage := WM_TRAYCB;
  nid.hIcon  := ConsoleIcon;
  n := Length(gTipW);
  if n > 127 then n := 127;
  if n > 0 then Move(gTipW[1], nid.szTip[0], n * SizeOf(WideChar));
  nid.szTip[n] := #0;
  if not Shell_NotifyIconW(NIM_ADD, nid) then
  begin
    Sleep(150);
    Shell_NotifyIconW(NIM_ADD, nid);
  end;
end;

function HelperThread(param: Pointer): DWORD; stdcall;
var
  wc  : TWndClassExW;
  m   : TMsg;
  cls : WideString;
  tbc : WideString;
begin
  Result := 0;
  cls := 'UTrayItHelperWnd';
  if not gClassDone then
  begin
    FillChar(wc, SizeOf(wc), 0);
    wc.cbSize        := SizeOf(wc);
    wc.lpfnWndProc   := @HelperWndProc;
    wc.hInstance     := GetModuleHandleW(nil);
    wc.lpszClassName := PWideChar(cls);
    RegisterClassExW(wc);                { failing twice is harmless }
    gClassDone := True;
  end;
  tbc := 'TaskbarCreated';
  gTaskbarMsg := RegisterWindowMessageW(PWideChar(tbc));

  { top-level so it receives the TaskbarCreated broadcast }
  gHelperWnd := CreateWindowExW(0, PWideChar(cls), PWideChar(cls),
                  WS_OVERLAPPED, 0, 0, 0, 0, 0, 0,
                  GetModuleHandleW(nil), nil);
  if gHelperWnd = 0 then Exit;

  HelperAddIcon;

  while GetMessageW(m, 0, 0, 0) do
  begin
    TranslateMessage(m);
    DispatchMessageW(m);
  end;

  { icon was clicked -> bring the console back ourselves }
  if gClicked then
  begin
    ShowWindow(XGetConsoleWindow, SW_SHOW);
    ShowWindow(XGetConsoleWindow, SW_RESTORE);
    SetForegroundWindow(XGetConsoleWindow);
  end;
end;

class function TTrayIt.ConsoleSupported: Boolean;
begin
  Result := XGetConsoleWindow <> 0;
end;

class function TTrayIt.TraySupported: Boolean;
begin
  Result := True;
end;

function TTrayIt.MinimizeConsole: Boolean;
var cw: HWND;
begin
  cw := XGetConsoleWindow;
  Result := cw <> 0;
  if Result then
  begin
    ShowWindow(cw, SW_MINIMIZE);
    FMinimized := True;
  end;
end;

function TTrayIt.RestoreConsole: Boolean;
var cw: HWND;
begin
  cw := XGetConsoleWindow;
  Result := cw <> 0;
  if Result then
  begin
    ShowWindow(cw, SW_SHOW);
    ShowWindow(cw, SW_RESTORE);
    SetForegroundWindow(cw);
    FMinimized := False;
  end;
end;

function TTrayIt.TrayConsole(const ATip: string): Boolean;
var cw: HWND;
begin
  Result := False;
  if FInTray then Exit;
  cw := XGetConsoleWindow;
  if cw = 0 then Exit;

  gTipW    := WideString(ATip);
  gClicked := False;
  gThread  := CreateThread(nil, 0, @HelperThread, nil, 0, gThreadId);
  if gThread = 0 then Exit;

  ShowWindow(cw, SW_HIDE);
  FInTray := True;
  Result  := True;
end;

function TTrayIt.UnTrayConsole: Boolean;
begin
  Result := False;
  if not FInTray then Exit;
  gClicked := False;                     { we restore, thread should not }
  if gHelperWnd <> 0 then
    PostMessage(gHelperWnd, WM_CLOSE, 0, 0);
  if gThread <> 0 then
  begin
    WaitForSingleObject(gThread, 3000);
    CloseHandle(gThread);
    gThread := 0;
  end;
  FInTray := False;
  Result  := RestoreConsole;
end;

destructor TTrayIt.Destroy;
begin
  if FInTray then UnTrayConsole;         { guarantees no stuck icon }
  inherited Destroy;
end;

{ ========================================================================= }
{$ELSE}
{$IFDEF UNIX}
{ ========================================================================= }
uses
  BaseUnix, termio;

const
  SEQ_ICONIFY   : string = #27'[2t';     { XTWINOPS: iconify terminal    }
  SEQ_DEICONIFY : string = #27'[1t';     { XTWINOPS: de-iconify terminal }

function WriteToTty(const s: string): Boolean;
var
  fd: cint;
begin
  { prefer the controlling terminal so redirection doesn't eat the codes }
  fd := FpOpen('/dev/tty', O_WRONLY);
  if fd >= 0 then
  begin
    Result := FpWrite(fd, s[1], Length(s)) = Length(s);
    FpClose(fd);
  end
  else if IsATTY(1) = 1 then
    Result := FpWrite(1, s[1], Length(s)) = Length(s)
  else
    Result := False;
end;

class function TTrayIt.ConsoleSupported: Boolean;
begin
  { best effort: we can only try if we are attached to a terminal }
  Result := IsATTY(1) = 1;
  if not Result then
    Result := FpAccess('/dev/tty', W_OK) = 0;
end;

class function TTrayIt.TraySupported: Boolean;
begin
  Result := False;                       { no portable tray for a tty }
end;

function TTrayIt.MinimizeConsole: Boolean;
begin
  Result := WriteToTty(SEQ_ICONIFY);
  if Result then FMinimized := True;
end;

function TTrayIt.RestoreConsole: Boolean;
begin
  Result := WriteToTty(SEQ_DEICONIFY);
  if Result then FMinimized := False;
end;

function TTrayIt.TrayConsole(const ATip: string): Boolean;
begin
  if ATip = '' then ;                    { unused on this platform }
  Result := MinimizeConsole;             { closest available behaviour }
  FInTray := Result;
end;

function TTrayIt.UnTrayConsole: Boolean;
begin
  Result := RestoreConsole;
  FInTray := False;
end;

destructor TTrayIt.Destroy;
begin
  if FInTray then UnTrayConsole;
  inherited Destroy;
end;

{ ========================================================================= }
{$ELSE}
{ go32v2, msdos, os2, embedded, ... : graceful stubs                        }
{ ========================================================================= }

class function TTrayIt.ConsoleSupported: Boolean;
begin
  Result := False;
end;

class function TTrayIt.TraySupported: Boolean;
begin
  Result := False;
end;

function TTrayIt.MinimizeConsole: Boolean;
begin
  Result := False;
end;

function TTrayIt.RestoreConsole: Boolean;
begin
  Result := False;
end;

function TTrayIt.TrayConsole(const ATip: string): Boolean;
begin
  if ATip = '' then ;
  Result := False;
end;

function TTrayIt.UnTrayConsole: Boolean;
begin
  Result := False;
end;

destructor TTrayIt.Destroy;
begin
  inherited Destroy;
end;

{$ENDIF}
{$ENDIF}

end.
