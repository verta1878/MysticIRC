# DOS (go32v2) socket layer - sockets_go32v2

How the fork gets TCP/IP on DOS without adding C code to its own tree.

> **Scope: 32-bit protected-mode DOS (go32v2/DJGPP) only.** Everything here
> targets go32v2 - 32-bit, needs a 386+ and a DPMI host (CWSDPMI). There is no
> 16-bit (i8086 real-mode) DOS support; FPC 2.6.x has no i8086 target.

## The approach

Every non-DOS target gets sockets from an FPC RTL unit (`Sockets` + platform
helpers). FPC 2.6.2's go32v2 RTL ships no `Sockets` unit, so `mdl/sockets_go32v2.pas`
provides the SAME API surface the fork's socket layer (`mdl/m_io_sockets.pas`)
calls, mapped onto the Watt-32 TCP/IP library. The fork's own socket code is
UNCHANGED - `m_io_sockets` just `Uses sockets_go32v2` instead of `Sockets` on
go32v2:

```pascal
{$IFDEF GO32V2}
  sockets_go32v2,
{$ELSE}
  Sockets,
{$ENDIF}
```

## What sockets_go32v2 exposes (COMPLETE Layer 1)

This is the full BSD-socket surface, not a minimal shim, so Layer-2 services
(FTP, telnet, SMTP, POP3, NNTP, binkp, ...) can be built on it.

- **Core:** `fpSocket fpBind fpConnect fpListen fpAccept fpShutdown`
- **Stream I/O:** `fpSend fpRecv`
- **Datagram I/O (UDP):** `fpSendTo fpRecvFrom`
- **Options:** `fpSetSockOpt fpGetSockOpt`
- **Names:** `fpGetSockName fpGetPeerName`
- **Multiplexing:** `fpSelect` + `fpFD_Zero/Set/Clr/IsSet`
  (+ non-fp aliases `FD_Zero/FD_Set/FD_Clr/FD_IsSet/Select`)
- **Close/ioctl/errno:** `CloseSocket ioctlSocket SocketError`
- **Byte order:** `htons htonl ntohs ntohl`
- **Address helpers:** `inet_addr inet_ntoa inet_aton` +
  `StrToNetAddr NetAddrToStr HostAddrToStr StrToHostAddr`
- **DNS / resolver:** `GetHostByName GetHostByAddr GetServByName
  GetProtoByName` + `ResolveName` (hostname OR dotted-quad -> net-order addr;
  the path DoveNet hostname hubs need)
- **Startup:** `InitWatt32` (wraps `sock_init`), `DoneWatt32` (`sock_exit`)
- **Types:** `TSocket TInetSockAddr TInAddr TFDSet TTimeVal THostEnt/PHostEnt
  TServEnt/PServEnt TSockLen`
- **Consts:** families (`AF_INET/PF_INET`), types (`SOCK_STREAM/DGRAM/RAW`),
  protocols (`IPPROTO_TCP/UDP/IP/ICMP`), `SOL_SOCKET` + `SO_*` options,
  `TCP_NODELAY`, `MSG_*`, `SHUT_*`, `FIONBIO/FIONREAD`, `INADDR_*`,
  `ESOCKEWOULDBLOCK/EINPROGRESS/EINTR`.

Each routine is a thin passthrough to the matching Watt-32 C entry point
(declared `cdecl external`). `SocketError` reads djgpp's `errno` via `__errno`.

## Build / link requirements

`sockets_go32v2` only DECLARES Watt-32's entry points; it does not contain
them. To link a networked DOS binary you need:

1. **Watt-32 built for djgpp/go32v2** (`libwatt.a`) on the link path:
   `ppcross386 -Tgo32v2 ... -k-lwatt`
2. **`sock_init` called once** before any socket use - wrapped by
   `InitWatt32` (call it at network startup).
3. **At runtime:** a DOS packet driver loaded + `WATTCP.CFG` (or DHCP) for IP
   config. This is standard Watt-32 deployment.

Watt-32 is a SEPARATE, permissively-licensed C library - an external build/
runtime dependency (like a packet driver), NOT bundled in this GPLv3 repo. Only
its entry points are declared here.

## Status

- `sockets_go32v2.pas` (COMPLETE Layer 1, ~485 lines) compiles clean for
  go32v2 (FPC 2.6.2).
- A full API-exerciser program (TCP client, UDP, sockopts, names, select/
  fd_set, ioctl, DNS, address helpers, errno) compiles + type-checks clean -
  every declared symbol is usable.
- `mdl/m_io_sockets.pas` (the fork's socket layer) COMPILES for go32v2 against
  it - the DOS socket gap is closed at the Pascal level.
- No regression: `m_io_sockets` still builds for Linux and OS/2.

REMAINING before a networked DOS binary runs (in build order):
  1. **`m_io_stdio.pas`** uses `BaseUnix` unconditionally in its non-OS2
     branch; needs a go32v2 branch (stdin/stdout via go32v2 RTL, or a stub -
     DOS BBSes use FOSSIL/serial, not Unix stdio pipes).
  2. **Build Watt-32 for djgpp** (`libwatt.a`). The complete API above is
     declarations until the library exists to link against. Everything is
     "joined at the hip" with this build.
  3. **Link-test** a service against real `libwatt.a`.
  4. **Runtime shake-out** on DOS with a packet driver + WATTCP.CFG.

## Recommended build order for Layer 2 (services)

Complete the socket layer (done), then build ONE service end-to-end - the
**FTP client** (for QWK-over-FTP / DoveNet dial-out) - to prove the whole
stack before spreading effort across six half-services. A client (dialing out
to a hub) is the simplest starting point; a multi-node server is more work on
DOS not because of a connection limit but because of the threading model (see
below). OpenOLMS/DoveNet dial-out is mostly a client.

## DOS concurrency model (important - not "one connection")

Watt-32 is a real TCP/IP stack and handles MULTIPLE concurrent sockets. It
exposes `select_s()` precisely so a single process can watch several
connections at once. The DOS constraint is **no preemptive threads**, not
"one connection":

- On Linux/Win32/OS2 the server runs a thread (or process) per caller
  (`TServerClient = Class(TThread)`). DOS is single-tasking, so that model
  does not apply.
- The correct DOS design is **cooperative multiplexing**: one process, sockets
  put in non-blocking mode (`ioctlSocket`+`FIONBIO`), all polled with
  `fpSelect` in one accept/service loop. Many connections, one thread.
- `sockets_go32v2` already provides every primitive this needs: `fpSelect`,
  `fpFD_Zero/Set/Clr/IsSet`, and non-blocking via `ioctlSocket(FIONBIO)`.

So: **multiple connections yes; multiple threads no.** The current `mis` DOS
`Execute` serves one caller at a time (hands the socket to a `mystic -n<N>
-TID<handle>` session and waits) - that is an initial-bring-up simplification,
NOT a Watt-32 limitation. Multiplexing several concurrent nodes with a
cooperative `select()` accept-loop is the planned upgrade.

## Why not pure Pascal all the way down?

DOS has no OS-level TCP/IP stack. The IP stack itself (Watt-32) is C, plus a
packet driver. The goal achieved here is that the FORK's code stays Pascal and
uses its normal `Sockets` API; the C stack is an external dependency, not code
in this repo. This matches the sysop decision (see docs/DECISIONS.md,
"DOS sockets", 2026-07-09).

## Full DOS compile test (2026-07-09) - 10/14, incl. the mystic server

After the socket layer + the platform-branch fixes below, a full go32v2 compile
pass builds **10 of 14** programs, INCLUDING `mystic` (the BBS server itself):

    OK  (10): maketheme mplc mutil mystpack install install_make 109to110
              mide mbbsutil  +  MYSTIC
    FAIL (4): mis fidopoll nodespy qwkpoll

Platform-branch fixes that got mystic compiling (all committed):
  - mdl/m_io_stdio.pas : GO32V2 branch - stdin/stdout via FileRead/FileWrite
    (Dos+SysUtils), no BaseUnix; DataWaiting returns ready (no select on DOS
    file handles, like OS/2).
  - mdl/m_pipe.pas     : GO32V2 -> TPipeDisk (disk-based pipe, like OS/2).
  - mystic/mis_server.pas : GO32V2 -> sockets_go32v2 instead of Sockets.

### The remaining 4, categorized

**fidopoll / nodespy / qwkpoll - TOOLCHAIN blocker - NOW SOLVED (binutils patch).**
These reached the LINK stage and failed with:
    i386-go32v2-ld: sockets_go32v2.o: Unrecognized storage class 104 for
    .text symbol - could not read symbols: Invalid operation
Root cause: FPC 2.6.2 emits storage class 0x68 (104) = C_SECTION for its
section symbols (the PE convention); binutils 2.30's coff-go32 target, built
WITHOUT COFF_WITH_PE, treats 0x68 as C_LINE and rejects it. A `cdecl external`
C symbol forces FPC to invoke the EXTERNAL GNU ld (to bind the C library), which
is where the rejection bit. The 10 non-C-external programs linked fine because
FPC uses its internal linker for them.

FIXED at the compiler/toolchain level by FPC 2.6.4irc r3.1, which bundles a go32v2
toolchain (bin/tools/i386-go32v2/) and emits proper COFF section attributes so
the linker handles C_SECTION (0x68) natively.  (History: this was originally
solved by a standalone binutils patch that defined COFF_GO32_C_SECTION in
coffcode.h for coff-go32, mirroring the OS/2 emx binutils patch; that patch was
removed from libs/ once r3.1 took over the concern.)  VERIFIED at the time: patched
objdump/nm read FPC objects; a non-networked program still links (no regression);
and fidopoll linked PAST the class-104 rejection - the ONLY remaining errors were
`undefined reference to sock_init/socket/connect/...`, i.e. the Watt-32
functions that libwatt.a provides.

    REMAINING: build Watt-32 (libwatt.a) for djgpp and add -lwatt to the link.
    The object-reading blocker - which also gated the whole Watt-32 link - is
    now cleared, so libwatt.a is the last piece for a networked DOS binary.

**mis - CODE issues FIXED (2026-07-09).** mis previously failed to compile on
go32v2 for three reasons, all now resolved:
  - TTelnetServer.Execute had no DOS body (only WINDOWS/USEFORK/USEPROCESS).
    DOS has no preemptive threads, so the thread-per-client model does not
    apply. The go32v2 Execute accepts the caller, grabs a free node, and hands
    the socket straight to a `mystic -n<N> -TID<handle>` session (exactly what
    the Windows path does with CommHandle), waiting for that call to finish.
    This serves ONE caller at a time as an initial-bring-up simplification -
    NOT a Watt-32 limit (Watt-32 does multiple sockets; see "DOS concurrency
    model" above). A cooperative select() accept-loop multiplexing several
    concurrent nodes in one process is the planned upgrade.
  - TEventEngine.ShellExec had no DOS body. Added a go32v2 branch mirroring
    OS/2: run via COMMAND.COM (COMSPEC) /C using SysUtils.ExecuteProcess.
  - The MD5 unit (FPC hash package) was missing from the go32v2 toolchain.
    Built md5.pp for go32v2 and added md5.ppu/.o to libs/dos-toolchain.zip.
mis now compiles fully and reaches the link stage - failing ONLY on the same
undefined Watt-32 symbols as the other networked programs.

### Where this leaves DOS (updated 2026-07-09)
- Source-side: DONE. The socket layer is complete, `mystic` compiles, and all
  the mis/events/md5 code gaps are fixed. There are NO remaining source-level
  blockers for DOS.
- The binutils<->FPC object-format mismatch is FIXED (FPC 2.6.4irc r3.1's go32v2 toolchain,
  bin/tools/i386-go32v2/) - r3.1's ld reads FPC objects natively.
- All 4 networked programs (mis, fidopoll, nodespy, qwkpoll) now compile and
  reach the link stage, failing ONLY on undefined Watt-32 symbols. The single
  remaining piece is libwatt.a (Watt-32 built for djgpp). build-dos.sh already
  wires -lwatt via WATT32LIB=<dir>. Build Watt-32 -> 14/14.
