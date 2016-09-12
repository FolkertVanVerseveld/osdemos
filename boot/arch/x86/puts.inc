%include "tty.inc"
%macro puts 1
	mov si, %1
	call kputs
%endmacro
%macro putsln 1
	mov si, %1
	call kputsln
%endmacro
%define LF 0xD, 0xA
