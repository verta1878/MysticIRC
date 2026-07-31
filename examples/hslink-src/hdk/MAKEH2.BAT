rem make HUGE model HDK library
make -DMODEL=h -DCPU=2 -DTARGET=HDKH2 -DCOMP=BCC %1 %2
if errorlevel 1 pause
