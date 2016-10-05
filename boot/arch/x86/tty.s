%ifndef TTY
%define TTY
%ifdef BIOS
	%define ttyint bioscall 10h
%else
	%define ttyint int 10h
%endif
ttyrt:
	ttyctl 0xf
	biosgetax
	mov [ttyvmod], ax
	xor ax, ax
	mov [ttypos], ax
	ret
ttybios:
	cmp ah, 0xe
	je ttyputchar
	ttyint
	ret
%ifdef TTY_USE_VMEM
ttyputchar:
	push ax
	push es
	mov cx, 0xb800
	push cx
	pop es
	mov bx, [ttypos]
	cmp al, 0
	je ttyputdone
	cmp al, 0xa
	je ttyputln
	mov ah, [ttyclr]
	mov [es:bx], ax
	inc bx
	inc bx
ttyputdone:
	mov [ttypos], bx
	pop es
	pop ax
	ret
ttyputln:
	push ax
	mov al, [ttycolsz]
	cbw
	shl ax, byte 1
	add bx, ax
	xchg ax, bx
	div bl
	mul bl
	mov bx, ax
	pop ax
	jmp ttyputdone
%else
ttyputln:
	mov al, 0xd
	call ttyputchar
	mov al, 0xa
ttyputchar:
	mov ah, 0xe
	ttyint
	ret
%endif
align 2
ttyvmod:
	db 0
ttycolsz:
	db 0
ttypos:
	dw 0
ttyclr:
	db 0xf
%endif
