OUTPUT_FORMAT("coff-go32-exe")
ENTRY(start)
SECTIONS
{
  .text  0x1000+SIZEOF_HEADERS : {
  . = ALIGN(16);
  /tmp/fpc264irc/bin/units/i386-go32v2/prt0.o(.text)
  . = ALIGN(16);
  pdnet_loopback.o(.text)
  . = ALIGN(16);
  /tmp/fpc264irc/bin/units/i386-go32v2/system.o(.text)
  . = ALIGN(16);
  /tmp/fpc264irc/bin/units/i386-go32v2/exceptn.o(.text)
  . = ALIGN(16);
  /tmp/fpc264irc/bin/units/i386-go32v2/objpas.o(.text)
  . = ALIGN(16);
  /tmp/fpc264irc/bin/units/i386-go32v2/sysutils.o(.text)
  . = ALIGN(16);
  /tmp/fpc264irc/bin/units/i386-go32v2/classes.o(.text)
  . = ALIGN(16);
  m_pdtypes.o(.text)
  . = ALIGN(16);
  m_pdnet.o(.text)
  . = ALIGN(16);
  /tmp/fpc264irc/bin/units/i386-go32v2/go32.o(.text)
  . = ALIGN(16);
  /tmp/fpc264irc/bin/units/i386-go32v2/dos.o(.text)
  . = ALIGN(16);
  /tmp/fpc264irc/bin/units/i386-go32v2/strings.o(.text)
  . = ALIGN(16);
  /tmp/fpc264irc/bin/units/i386-go32v2/sysconst.o(.text)
  . = ALIGN(16);
  /tmp/fpc264irc/bin/units/i386-go32v2/typinfo.o(.text)
  . = ALIGN(16);
  /tmp/fpc264irc/bin/units/i386-go32v2/rtlconsts.o(.text)
  . = ALIGN(16);
  /tmp/fpc264irc/bin/units/i386-go32v2/types.o(.text)
  . = ALIGN(16);
  /tmp/fpc264irc/bin/units/i386-go32v2/sockets.o(.text)
    *(.text)
    etext  =  . ;
    PROVIDE(_etext  =  .);
    . = ALIGN(0x200);
  }
    .data  ALIGN(0x200) : {
      djgpp_first_ctor = . ;
      *(SORT(.ctors.*))
      *(.ctor)
      *(.ctors)
      djgpp_last_ctor = . ;
      djgpp_first_dtor = . ;
      *(SORT(.dtors.*))
      *(.dtor)
      *(.dtors)
      djgpp_last_dtor = . ;
      __environ = . ;
      PROVIDE(_environ = .);
      LONG(0)
      *(.data)
      *(.fpc*)
      *(.gcc_exc)
      ___EH_FRAME_BEGIN__ = . ;
      *(.eh_fram*)
      ___EH_FRAME_END__ = . ;
      LONG(0)
       edata  =  . ; _edata = .;
       . = ALIGN(0x200);
    }
    .bss  SIZEOF(.data) + ADDR(.data) :
    {
      _object.2 = . ;
      . += 32 ;
      *(.bss)
      *(COMMON)
       end = . ; _end = .;
       . = ALIGN(0x200);
    }
    /* Stabs debugging sections.  */
    .stab 0 : { *(.stab) }
    .stabstr 0 : { *(.stabstr) }
    /* DWARF 2 */
    .debug_aranges  0 : { *(.debug_aranges) }
    .debug_pubnames 0 : { *(.debug_pubnames) }
    .debug_info     0 : { *(.debug_info) *(.gnu.linkonce.wi.*) }
    .debug_abbrev   0 : { *(.debug_abbrev) }
    .debug_line     0 : { *(.debug_line) }
    .debug_frame    0 : { *(.debug_frame) }
    .debug_str      0 : { *(.debug_str) }
    .debug_loc      0 : { *(.debug_loc) }
    .debug_macinfo  0 : { *(.debug_macinfo) }
  }
SEARCH_DIR("/home/claude/mystic-repo/mdl/")
SEARCH_DIR("/tmp/fpc264irc/bin/units/i386-go32v2/")
SEARCH_DIR("/tmp/fpc264irc/bin/")
