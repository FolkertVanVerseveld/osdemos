; BROKEN CODE DO NOT USE
%define VBR_ADDR 0x7c00
%define BUF_ADDR 0x800
%define SCRATCH_ADDR 0x600
bits 16
org VBR_ADDR

	jmp 0:start
start:
	xor ax, ax
	mov ss, ax
	mov sp, VBR_ADDR
	pushf
	mov sp, SCRATCH_ADDR
	push es
	push ds
	push cx ;3
; die if 286 or lower
	mov cx, 0x121
	shl ch, cl
	je die
	pop cx
	pushad
	push gs
	push fs
	mov sp, VBR_ADDR-3*2 ;3
	xor ax, ax
	mov es, ax
	mov ds, ax
; show everything's good
main:
	mov si, ps1
	call puts
getkey:
	mov ah, 1
	int 16h
	jnz main
	mov ah, 0
	int 16h
	cmp al, 0xd
	je parse
	cmp al, ' '
	jb getkey
	mov bx, BUF_ADDR
	mov cl, [bufpos]
	mov ch, 0
	cmp cl, 10
	ja getkey
	inc cl
	mov [bufpos], cl
	add bx, cx
	mov di, bx
	stosb
	call putchar
	jmp getkey
num dw 0x9090
bufpos db 0
parse:
	mov al, [bufpos]
	call putbyte
	mov al, 0
	mov [bufpos], al
	jmp main
die:
	hlt
	jmp short die
putshort:
	push ax
	mov al, ah
	call putbyte
	pop ax
putbyte:
	push ax
	shr al, byte 4
	call putnyb
	pop ax
putnyb:
	and al, byte 0xf
	mov dl, 10
	cmp al, dl
	jb .digit
	add al, 'A' - '0' - 10
.digit:
	add al, '0'
putchar:
	mov ah, 0eh
	int 10h
	ret
putc:
	call putchar
puts:
	cld
	lodsb
	cmp al, 0
	jne putc
	ret
ps1	db 0xd, 0xa, '#', 0
; signature
	times 510 - ($ - $$) db 0
	dw 0xaa55
