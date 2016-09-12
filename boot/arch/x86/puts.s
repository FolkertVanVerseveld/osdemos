%ifndef PUTS
%define PUTS
kputsln:
	call kputs
_kputlf:
	mov si, ..@kstrln
..@kputsc:
%ifdef PUTS_CCHR
%ifndef TTY_USE_VMEM
	cmp al, 0xA
	jne ..@kputcc
	push ax
	mov al, 0xD
	%ifdef PUTHEX
		call kputchar
	%else
		xor bx, bx
		ttyputc
	%endif
	pop ax
..@kputcc:
%endif
%endif
	xor bx, bx
	ttyputc
kputs:
	cld
	lodsb
	cmp al, 0
	jne ..@kputsc
	ret
..@kstrln:
%ifdef PUTS_CCHR
	db 0xA, 0
%else
	db 0xD, 0xA, 0
%endif
%endif
