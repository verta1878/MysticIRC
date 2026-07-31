rem make SMALL model HDK library with static workspace (bcc 3.1)
make -DMODEL=s -DSTATIC -DTARGET=HDKSSB -DCOMP=BCC %1 %2
if errorlevel 1 pause
