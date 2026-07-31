rem make PHAR LAP DOS EXTENDER 286 library
make -DMODEL=l -DCPU=2 -DTARGET=HDKP286 -DCOMP=BCC286 %1 %2
if errorlevel 1 pause
