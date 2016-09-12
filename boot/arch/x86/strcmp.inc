%macro strcmp 2
	mov si, %1
	mov bp, %2
	call kstrcmp
%endmacro
