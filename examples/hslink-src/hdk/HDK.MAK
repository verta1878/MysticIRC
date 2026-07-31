
#
# TC++ 1.0 Makefile for "HS/Link Developer Kit"
# Samuel H. Smith, 10/14/91
#

# default memory model and CPU type

!if $d(MODEL)
!else
MODEL=s
!endif

!if $d(CPU)
CPUOPT=-$(CPU)
!else
CPUOPT=
!endif

# build library files

HDK: HSCRC.OBJ HSRECV.OBJ HSTRANS.OBJ HSMISC.OBJ HSBUF.OBJ HSOPT.OBJ HSTOP.OBJ
        TLIB HDK$(MODEL)$(CPU) +-HSCRC.OBJ +-HSRECV.OBJ +-HSTRANS.OBJ +-HSMISC.OBJ +-HSBUF.OBJ +-HSOPT.OBJ +-HSTOP.OBJ,HDK$(MODEL)$(CPU)

# default compilation rules

.C.OBJ:
        TCC -c -f- -k- -v -y -d -G -O -w $(CPUOPT) -m$(MODEL) {$< }

.C.ASM:
        TCC -c -f- -k- -v -y -d -G -O -w $(CPUOPT) -m$(MODEL) -S {$< }

# nested include files

HDK=INCLUDE\hdk.h INCLUDE\hslink.h INCLUDE\hsdisp.h INCLUDE\hscomm.h INCLUDE\hstrans.h INCLUDE\hsrecv.h INCLUDE\hsopt.h
HSPRIV=hspriv.h hsbuf.h

# compile each source file

HSTOP.OBJ: HSTOP.C $(HDK) $(HSPRIV) DEBUG.H HSMISC.H INCLUDE\HSUID.H INCLUDE\HSTOP.H HSCRC.H

HSCRC.OBJ: HSCRC.C $(HDK) $(HSPRIV) INCLUDE\HSUID.H HSCRC.H

HSMISC.OBJ: HSMISC.C $(HDK) $(HSPRIV) HSMISC.H

HSBUF.OBJ: HSBUF.C $(HDK) $(HSPRIV) HSMISC.H DEBUG.H

HSOPT.OBJ: HSOPT.C $(HDK) $(HSPRIV) HSMISC.H INCLUDE\HSUID.H

HSRECV.OBJ: HSRECV.C $(HDK) $(HSPRIV) HSMISC.H INCLUDE\HSUID.H DEBUG.H

HSTRANS.OBJ: HSTRANS.C $(HDK) $(HSPRIV) HSMISC.H DEBUG.H

