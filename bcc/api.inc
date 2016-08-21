%ifndef BOOTAPI_INC
%define BOOTAPI_INC

%define BOOTAPI_SIG 0xb01

struc bios_call
	.es   : resw 1
	.ds   : resw 1
	.di   : resw 1
	.si   : resw 1
	.bp   : resw 1
	.sp   : resw 1
	.bx   : resw 1
	.dx   : resw 1
	.cx   : resw 1
	.ax   : resw 1
	.flags: resw 1
endstruc

%include "boot.inc"

%endif
