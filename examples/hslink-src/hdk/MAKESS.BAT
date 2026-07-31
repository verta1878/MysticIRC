rem make SMALL model HDK library with static workspace (bcc)
rem make -DMODEL=s -DSTATIC -DTARGET=HDKSS -DCOMP=BCC %1 %2
del *.obj
make -DMODEL=s -DSTATIC -DTARGET=HDKSS -DCOMP=TCC %1 %2
if errorlevel 1 pause
