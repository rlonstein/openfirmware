   \ Enable DLL, load Extended Mode Register by set and clear PROG_DRAM
   20000018 rmsr
   10000001 bitset  20000018 wmsr
   10000001 bitclr  20000018 wmsr

   \ Reset DLL (bit 27 is undocumented in GX datasheet, but is in the LX one)
   08000001 bitset  20000018 wmsr
   08000001 bitclr  20000018 wmsr

   \ Here we are supposed to wait 200 SDCLK cycles to let the DLL settle.
   \ That is approximately 2 uS.  The ROM instruction access is so slow that
   \ anything we do will take quite a bit longer than that, so we just let the
   \ "rmsr, bitset" sequence take care of the time delay for us.

   \ In the following sequence of writes the 2000.0018 MSR, we
   \ take advantage of the fact that the existing value stays
   \ in EAX/EDX, so we don't have to re-read the value.

   \ Generate 2 refresh requests.  The refresh queue is 8 deep, and we
   \ need to make sure 2 refreshes hit the chips, so we have to issue
   \ 10 requests to the queue.  According to the GX datasheet, we don't
   \ have to clear the REF_TST bit (8) explicitly between writes 
   20000018 rmsr  8 bitset
   wrmsr wrmsr wrmsr wrmsr wrmsr wrmsr wrmsr wrmsr wrmsr wrmsr
   8 bitclr

\ LinuxBIOS LX raminit.c has a big delay here, using Port 61

   \ Load Mode Register
   1 bitset  20000018 wmsr
   1 bitclr  20000018 wmsr

   \ Set up a descriptor to give access to memory
   \ GLIU0 P2D Base Mask Descriptors - page 85
   20000000.000fff00.   10000020 set-msr  \ memory - 0..fffff

   \ The RAM DLL needs a write to lock on
   ax  h# ffff0 #)  mov

   \ Turn on the cache
   cr0	ax   mov
   6000.0000 bitclr  \ Cache-disable off, coherent
   ax   cr0  mov
   invd

   0000f001.00001400.   5140000f set-msr  \ PMS BAR

   \ It is tempting to test bit 0 of PM register 5c, but a 5536 erratum
   \ prevents that bit from working.
   1454 port-rl  2 bitand  0<>  if  \ Wakeup event flag
      char r 3f8 port-wb  begin  3fd port-rb 40 bitand  0<> until
      resume-entry # sp mov  sp jmp
   then

   h# 1808 rmsr                \ Default region configuration properties MSR
   h# 0fffff00 # ax and        \ Top of System Memory field
   4 # ax shl                  \ Shift into place
   ax mem-info-pa 4 + #)  mov  \ Put it where resetend.fth can find it

   \ char D 3f8 port-wb  begin  3fd port-rb 40 bitand  0<> until

   \ Memory is now on
   h# 8.0000 #  sp  mov        \ Setup a stack pointer for later code

\ Some optional debugging stuff ...
[ifdef] debug-startup
init-com1

carret report
linefeed report
ascii F report
ascii o report
ascii r report
[then]

\ fload ${BP}/cpu/x86/pc/ramtest.fth

0 [if]
ax ax xor
h# 12345678 #  bx mov
bx 0 [ax] mov
h# 5555aaaa #  4 [ax] mov
0 [ax] dx  mov
dx bx cmp  <>  if  ascii B report  ascii A report  ascii D report  begin again  then
[then]

