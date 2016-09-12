%include "tty.inc"
%ifndef PUTHEX_NOINT
%macro putint 1
	mov eax, %1
	call kputint
%endmacro
%endif
%macro putshort 1
	mov ax, %1
	call kputshort
%endmacro
%macro putbyte 1
	mov al, %1
	call kputbyte
%endmacro
%macro putchar 1
	mov al, %1
	call kputchar
%endmacro
%macro putnyb 1
	mov al, %1
	call kputnyb
%endmacro
