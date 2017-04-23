; tiny monitor
org 0x7c00

	jmp 0:start
start:
	cli
	xor ax, ax
	mov ss, ax
	mov sp, start
	mov ds, ax
	mov es, ax
	sti
main:
	; put newline
	mov ax, 0x0e0d
	int 10h
	mov al, 0xa
	int 10h
	; get keystroke
	mov ah, 0
	int 16h
	cmp al, 'a'
	jz assemble
	jmp main
assemble:
	call put_key
	jmp main
put_key:
	mov ah, 0xe
	int 10h
	mov al, ' '
	int 10h
	ret
	times 0x200 - 2 - ($ - $$) db 0
	dw 0xaa55
