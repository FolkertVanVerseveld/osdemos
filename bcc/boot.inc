%ifndef BOOT_INC
%define BOOT_INC

%include "mmap.inc"

%define BS_SECTORS 5
%define BOOTSIG 0xb01

struc bootenv
	.ss   : resw 1 ; bios stack segment
	.sp   : resw 1 ; bios stack pointer
	.gs   : resw 1 ; bios g     segment
	.fs   : resw 1 ; bios f     segment
	.es   : resw 1 ; bios extra segment
	.cs   : resw 1 ; bios code  segment
	; bios registers
	.di   : resw 1
	.si   : resw 1
	.bp   : resw 1
	.res  : resw 1
	.bx   : resw 1
	.dx   : resw 1
	.cx   : resw 1
	.ax   : resw 1
	.flags: resw 1
	; used drive letter in order to load
	; next stage. note that this may differ
	; from bios drive letter
	.drive: resb 1
	; number of times we had to try to
	; find a working drive letter
	.tries: resb 1
endstruc

%endif
