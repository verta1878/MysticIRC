	.file "m_types.pas"
# Begin asmlist al_begin
# End asmlist al_begin
# Begin asmlist al_stabs
# End asmlist al_stabs
# Begin asmlist al_procedures
# End asmlist al_procedures
# Begin asmlist al_globals

.data
	.balign 4
.globl	THREADVARLIST_M_TYPES
THREADVARLIST_M_TYPES:
	.long	0
# End asmlist al_globals
# Begin asmlist al_const
# End asmlist al_const
# Begin asmlist al_typedconsts
# End asmlist al_typedconsts
# Begin asmlist al_rotypedconsts
# End asmlist al_rotypedconsts
# Begin asmlist al_threadvars
# End asmlist al_threadvars
# Begin asmlist al_imports
# End asmlist al_imports
# Begin asmlist al_exports
# End asmlist al_exports
# Begin asmlist al_resources
# End asmlist al_resources
# Begin asmlist al_rtti

.data
	.balign 4
.globl	INIT_M_TYPES_DEF0
INIT_M_TYPES_DEF0:
	.byte	1
	.ascii	"\000"
	.byte	0
	.long	1,26

.data
	.balign 4
.globl	INIT_M_TYPES_TMENUFORMFLAGSREC
INIT_M_TYPES_TMENUFORMFLAGSREC:
	.byte	5,17
	.ascii	"TMenuFormFlagsRec"
	.byte	5
	.long	INIT_M_TYPES_DEF0

.data
	.balign 4
.globl	RTTI_M_TYPES_DEF0
RTTI_M_TYPES_DEF0:
	.byte	1
	.ascii	"\000"
	.byte	0
	.long	1,26

.data
	.balign 4
.globl	RTTI_M_TYPES_TMENUFORMFLAGSREC
RTTI_M_TYPES_TMENUFORMFLAGSREC:
	.byte	5,17
	.ascii	"TMenuFormFlagsRec"
	.byte	5
	.long	RTTI_M_TYPES_DEF0

.data
	.balign 4
.globl	INIT_M_TYPES_TCHARINFO
INIT_M_TYPES_TCHARINFO:
	.byte	13,9
	.ascii	"TCharInfo"
	.long	2,0

.data
	.balign 4
.globl	RTTI_M_TYPES_TCHARINFO
RTTI_M_TYPES_TCHARINFO:
	.byte	13,9
	.ascii	"TCharInfo"
	.long	2,2
	.long	RTTI_SYSTEM_BYTE
	.long	0
	.long	RTTI_SYSTEM_CHAR
	.long	1

.data
	.balign 4
.globl	INIT_M_TYPES_TCONSOLELINEREC
INIT_M_TYPES_TCONSOLELINEREC:
	.byte	12
	.ascii	"\017TConsoleLineRec"
	.long	2,80
	.long	INIT_M_TYPES_TCHARINFO
	.long	-1

.data
	.balign 4
.globl	RTTI_M_TYPES_TCONSOLELINEREC
RTTI_M_TYPES_TCONSOLELINEREC:
	.byte	12
	.ascii	"\017TConsoleLineRec"
	.long	2,80
	.long	RTTI_M_TYPES_TCHARINFO
	.long	-1

.data
	.balign 4
.globl	INIT_M_TYPES_TCONSOLESCREENREC
INIT_M_TYPES_TCONSOLESCREENREC:
	.byte	12
	.ascii	"\021TConsoleScreenRec"
	.long	160,50
	.long	INIT_M_TYPES_TCONSOLELINEREC
	.long	-1

.data
	.balign 4
.globl	RTTI_M_TYPES_TCONSOLESCREENREC
RTTI_M_TYPES_TCONSOLESCREENREC:
	.byte	12
	.ascii	"\021TConsoleScreenRec"
	.long	160,50
	.long	RTTI_M_TYPES_TCONSOLELINEREC
	.long	-1

.data
	.balign 4
.globl	INIT_M_TYPES_TCONSOLEIMAGEREC
INIT_M_TYPES_TCONSOLEIMAGEREC:
	.byte	13,16
	.ascii	"TConsoleImageRec"
	.long	8007,0

.data
	.balign 4
.globl	RTTI_M_TYPES_TCONSOLEIMAGEREC
RTTI_M_TYPES_TCONSOLEIMAGEREC:
	.byte	13,16
	.ascii	"TConsoleImageRec"
	.long	8007,8
	.long	RTTI_M_TYPES_TCONSOLESCREENREC
	.long	0
	.long	RTTI_SYSTEM_BYTE
	.long	8000
	.long	RTTI_SYSTEM_BYTE
	.long	8001
	.long	RTTI_SYSTEM_BYTE
	.long	8002
	.long	RTTI_SYSTEM_BYTE
	.long	8003
	.long	RTTI_SYSTEM_BYTE
	.long	8004
	.long	RTTI_SYSTEM_BYTE
	.long	8005
	.long	RTTI_SYSTEM_BYTE
	.long	8006
# End asmlist al_rtti
# Begin asmlist al_dwarf_frame
# End asmlist al_dwarf_frame
# Begin asmlist al_dwarf_info
# End asmlist al_dwarf_info
# Begin asmlist al_dwarf_abbrev
# End asmlist al_dwarf_abbrev
# Begin asmlist al_dwarf_line
# End asmlist al_dwarf_line
# Begin asmlist al_picdata
# End asmlist al_picdata
# Begin asmlist al_resourcestrings
# End asmlist al_resourcestrings
# Begin asmlist al_objc_data
# End asmlist al_objc_data
# Begin asmlist al_objc_pools
# End asmlist al_objc_pools
# Begin asmlist al_end
# End asmlist al_end

