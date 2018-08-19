; Copyright Folkert van Verseveld. All rights reversed
; CPU Type processor detector

; listings taken (and fixed) from OSdev wiki and:
; http://rcollins.org/ddj/Sep96/Sep96.html

%define PROG_ADDR 0x7c00
%define STACK_ADDR PROG_ADDR

bits 16
org PROG_ADDR

; to make sure this works properly, ensure
; nasm won't emit instructions above 8086
cpu 8086

reset:
	xor ax, ax
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov sp, STACK_ADDR

	mov si, str_hdr
	call puts

	; start from oldest one and incrementally
	; check newer processor quirks (dl = type)
	push sp
	pop bx

	cmp bx, sp
	; FIXME /jnz/jz/ after testing
	jz sp_good

	; microcode sp bug, so probably one of:
	;   8086, 8088, 80186, 80188
	cli
	mov ax, word [0x0000]
	mov bx, word [0xffff]

	mov byte [0x0000], 0x00
	mov word [0xffff], 0xffff
	cmp byte [0x0000], 0xff

	mov word [0x0000], ax
	mov word [0xffff], bx
	sti

	mov dl, 0
	je dump

	; probably 80186 or 80188
	mov dl, 1
	jmp dump

cpu 286

sp_good:
	; probably 80286 or better
	or cx, 0xf000

	push cx
	popf

	pushf
	pop ax

	and ax, 0xf000
	mov dl, 2
	jz dump

cpu 386

	pushfd
	pop eax

	mov ecx, eax
	xor eax, 0x40000

	push eax
	popfd

	pushfd
	pop eax

	xor eax, ecx
	mov dl, 3
	jz dump

	; restore ac
	push ecx
	popfd

	mov dl, 4

cpu 486

	mov eax, ecx
	xor eax, 0x200000

	push eax
	popfd

	pushfd
	pop eax

	xor eax, ecx
	je dump

	mov dl, 5

cpu 586
	; TODO detect stuff above 80586

cpu 8086

dump:
	cmp dl, 0
	jz .1

	mov al, dl
	add al, byte '0'
	call putc

.1:
	mov si, str_end
	call puts

die:
	hlt
	jmp die

putc:
	push si
	mov ah, 0xe
	xor bx, bx
	int 10h
	pop si
	ret
_puts_loop:
	call putc
puts:
	cld
	lodsb
	cmp al, 0
	jne _puts_loop
	ret

type:
	db 0

str_hdr:
	db "80", 0
str_end:
	db "86", 0

	times 0x200 - 2 - ($ - $$) db 0
	dw 0xaa55
