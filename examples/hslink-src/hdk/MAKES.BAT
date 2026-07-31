rem make SMALL model HDK library with dynamic workspace (tcc)
make -DMODEL=s -DTARGET=HDKS -DCOMP=TCC %1 %2
if errorlevel 1 pause
