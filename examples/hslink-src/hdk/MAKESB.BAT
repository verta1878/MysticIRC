rem make SMALL model HDK library with dynamic workspace (bcc)
make -DMODEL=s -DTARGET=HDKSB -DCOMP=BCC %1 %2
if errorlevel 1 pause
