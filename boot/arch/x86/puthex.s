%ifndef PUTHEX
%define PUTHEX
%ifndef PUTHEX_NOINT
kputint:
	push eax
	shr eax, 16
	call kputshort
	pop eax
%endif
kputshort:
	push ax
	mov al, ah
	call kputbyte
	pop ax
%ifdef PUTHEX_SHORTSEP
	call kputbyte
	mov al, ' '
	jmp kputchar
%endif
kputbyte:
	push ax
%ifdef CPU_8086 or CPU_80186
	mov cl, 4
	shr al, cl
%else
	shr al, byte 4
%endif
	call kputnyb
	pop ax
kputnyb:
	and al, byte 0xF
	mov dl, 10
	cmp al, dl
	jb .knybdig
	add al, 'A' - '0' - 10
.knybdig:
	add al, '0'
kputchar:
	xor bx, bx
	ttybpctl 0xe
	ret
%endif
