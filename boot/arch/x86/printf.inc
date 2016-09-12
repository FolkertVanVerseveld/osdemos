%include "puthex.inc"
%include "puts.inc"

%macro printf 1
	mov si, %1
	call kprintf
%endmacro
