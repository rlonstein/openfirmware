\ See license at end of file
purpose: PCI bus package

d# 33,333,333 " clock-frequency" integer-property

: preassigned-pci-slot?  ( my-space -- flag )
   h# f.f800 and
   dup h# 800 =  if  drop true exit  then
   drop false
;

0 [if]
   \ Suppress PCI address assignment; use the addresses the BIOS assigned
   patch false true master-probe
   patch noop assign-all-addresses prober
   patch noop clear-addresses populate-device-node
   patch noop clear-addresses populate-device-node
   patch noop temp-assign-addresses find-fcode?
   patch 2drop my-w! populate-device-node
   : or-w!  ( bitmask reg# -- )  tuck my-w@  or  swap my-w!  ;
   patch or-w! my-w! find-fcode?
   patch 2drop my-w! find-fcode?
[then]

[ifdef] addresses-assigned
\   patch false true master-probe
: nonvirtual-probe-state?  ( -- flag )
   my-space preassigned-pci-slot?  if  false  else  probe-state?  then
;
patch nonvirtual-probe-state? probe-state? map-in

\  patch noop assign-all-addresses prober
warning @ warning off
: assign-pci-addr  ( phys.lo phys.mid phys.hi len | -1 -- phys.hi paddr size )
   dup -1 <>  if   ( phys.lo phys.mid phys.hi len )
      over preassigned-pci-slot?  if               ( phys.lo phys.mid phys.hi len )
         2swap 2drop    >r                         ( phys.hi r: len )
         dup config-l@  1 invert and  r>           ( phys.hi paddr len )
         exit
      then         ( phys.lo phys.mid phys.hi len )
   then            ( phys.lo phys.mid phys.hi len | -1 )
   assign-pci-addr
;
warning !

: ?clear-addresses  ( -- )
   my-space preassigned-pci-slot?  if  exit  then  clear-addresses
;
patch ?clear-addresses clear-addresses populate-device-node
patch ?clear-addresses clear-addresses populate-device-node

: ?temp-assign-addresses  ( -- )
   my-space preassigned-pci-slot?  if  exit  then  temp-assign-addresses
;

patch ?temp-assign-addresses temp-assign-addresses find-fcode?

\ These patches leave devices turned on
\ patch 2drop my-w! populate-device-node
\ : or-w!  ( bitmask reg# -- )  tuck my-w@  or  swap my-w!  ;
\ patch or-w! my-w! find-fcode?
\ patch 2drop my-w! find-fcode?
[then]

h# 0000 encode-int  " slave-only" property
h# 0000 encode-int			\ Mask of implemented add-in slots
" slot-names" property

also forth definitions

: pci-probe-list  ( -- adr len )
   " 1,2,3,4,5,6,7,8,9,a,b,c,d,e,f,10,11,12,13,14"
;
\    " c,f" dup  config-string pci-probe-list

previous definitions

h# 8000.0000 to first-mem
h# 9000.0000 to mem-space-top
h# 0000.8000 to first-io		\ Avoid mappings established by BIOS

0 [if]
\ These are here for completeness, but won't be used because we don't
\ do dynamic address assignment on this system.
h# 1000.0000 to first-mem		\ Avoid RAM at low addresses
h# 2000.0000 to mem-space-top
h# 0000.8000 to first-io		\ Avoid mappings established by BIOS
[then]

: pirq@  ( n -- irq )
   case
   0  of  h# 8855 config-b@ 4 rshift  endof
   1  of  h# 8856 config-b@ h# f and  endof
   2  of  h# 8856 config-b@ 4 rshift  endof
   3  of  h# 8857 config-b@ 4 rshift  endof
   ( default )  0 swap
   endcase
;

: set-level-trigger  ( irq# -- irq# )
   dup 8 /mod    ( irq# low high )
   h# 4d0 +      ( irq# low reg# )
   1 rot lshift  ( irq# reg# bitmask )
   over pc@  or  ( irq# reg# newvalue )
   swap pc!
;

\ Determine the parent interrupt information (the "interrupt line" in PCI
\ parlance) from the child's "interrupt pin" and the child's address,
\ returning "int-line true" if the child's interrupt line register should
\ be set or "false" otherwise.
: assign-int-line  ( phys.hi.func INTx -- irq true )
   \ Get the value from the platform-specific mapping registers
   \ XXX PIC version is below - need APIC version too
   drop case
      \ Wouldn't it be nice if you could get the argument to pirq@ from
      \ the interrupt pin register (offset 3d)?  But that doesn't work,
      \ because some devices say pin A but use PIRQB.
      h# 0800 of  d# 10   set-level-trigger  true exit  endof  \ Display
      h# 5800 of  1 pirq@ set-level-trigger  true exit  endof  \ USB device - PIRQB
      h# 6000 of  0 pirq@ set-level-trigger  true exit  endof  \ SDIO - PIRQA
      h# 6800 of  0 pirq@ set-level-trigger  true exit  endof  \ SDC - PIRQA
      h# 7800 of  1 pirq@ set-level-trigger  true exit  endof  \ EIDE - PIRQB
      h# 8000 of  0 pirq@ set-level-trigger  true exit  endof  \ UHCI01 - PIRQ A
      h# 8100 of  1 pirq@ set-level-trigger  true exit  endof  \ UHCI23 - PIRQ B
      h# 8200 of  2 pirq@ set-level-trigger  true exit  endof  \ UHCI45 - PIRQ C
      h# 8400 of  3 pirq@ set-level-trigger  true exit  endof  \ EHCI - PIRQ D
      h# a000 of  1 pirq@ set-level-trigger  true exit  endof  \ HDAudio - PIRQ B
      ( default )  dup h# 3c + config-b@  dup  if  set-level-trigger  then  true  rot    \ Reiterate previous setting
   endcase
;

0 value interrupt-parent

1  " #interrupt-cells" integer-property
0 0 encode-bytes  0000.ff00 +i  0+i  0+i  7 +i  " interrupt-map-mask" property

: +map  ( adr len dev# int-pin# int-level -- adr' len' )
   >r >r                  ( $ dev# R: level pin )
   +i                     ( $' R: level pin )
   0+i 0+i  r> +i         ( $' R: level )
   interrupt-parent +i    ( $' R: level )
   r> +i  0 +i            ( $' )   \ 0 is active low, level senstive for ISA
;

external

: make-interrupt-map  ( -- )
   " /isa/interrupt-controller" find-package  0=  if  exit  then  to interrupt-parent

   0 0 encode-bytes                    ( prop$ )

   h# 10000 0  do                      ( prop$ )
      i h# 3d + config-b@              ( prop$ pin# )
      dup 0<>  over h# ff <>  and  if  ( prop$ pin# )
         i h# 3c + config-b@           ( prop$ pin# level )
         i -rot  +map                  ( prop$' )
      else                             ( prop$ pin# )
         drop                          ( prop$ )
      then                             ( prop$ )
   h# 100 +loop                        ( prop$ )
   " interrupt-map" property           ( )
;

also known-int-properties definitions
\ In some systems the number of interrupt-map ints is variable,
\ but on OLPC, the only node with an interrupt-map is PCI.
: interrupt-map  7  ;
: interrupt-map-mask  4  ;
previous definitions

\ Just use the global versions
warning @ warning off
: config-b@  ( config-adr -- b )  config-b@  ;
: config-w@  ( config-adr -- w )  config-w@  ;
: config-l@  ( config-adr -- l )  config-l@  ;
: config-b!  ( b config-adr -- )  config-b!  ;
: config-w!  ( w config-adr -- )  config-w!  ;
: config-l!  ( l config-adr -- )  config-l!  ;
warning !

\ The io-base handling really ought to be in the root node, but
\ that would require more changes than I'm willing to do at present.
warning @ warning off
: map-out  ( vaddr size -- )
   over io-base u>=  if  2drop exit  then  ( vaddr size )
   map-out                                 ( )
;   
warning !

\ LICENSE_BEGIN
\ Copyright (c) 2006 FirmWorks
\ 
\ Permission is hereby granted, free of charge, to any person obtaining
\ a copy of this software and associated documentation files (the
\ "Software"), to deal in the Software without restriction, including
\ without limitation the rights to use, copy, modify, merge, publish,
\ distribute, sublicense, and/or sell copies of the Software, and to
\ permit persons to whom the Software is furnished to do so, subject to
\ the following conditions:
\ 
\ The above copyright notice and this permission notice shall be
\ included in all copies or substantial portions of the Software.
\ 
\ THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
\ EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
\ MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
\ NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
\ LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
\ OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
\ WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
\
\ LICENSE_END
