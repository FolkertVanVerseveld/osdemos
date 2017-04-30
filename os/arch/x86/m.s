; tiny monitor
org 0x7c00

reset:
	jmp 0:start
start:
	cli
	xor ax, ax
	mov ss, ax
	mov sp, reset
	mov ds, ax
	mov es, ax
	sti
main:
	; put newline
	mov ax, 0x0e0d
	int 10h
	mov al, 0xa
	int 10h
.loop:
	; get keystroke
	mov ah, 0
	int 16h
	cmp al, 'a'
	jz assemble
	cmp al, 'd'
	jz dump
	cmp al, 'g'
	jz go
	cmp al, 'l'
	jz load
	cmp al, 'r'
	jz disk_reset
	jmp .loop
disk_reset:
	call put_key
	call get_byte
	mov ah, 0
	mov dl, al
	int 13h
	jmp disk_stat
assemble:
	call put_key
	call get_word
	push ax
	mov al, ':'
	call put_key
	call get_word
	pop es
	mov di, ax
.loop:
	mov al, ','
	call put_key
	push es
	push di
	call get_byte
	pop di
	pop es
	cld
	stosb
	jmp .loop
dump:
	call put_key
	call get_word
	push ax
	mov al, ':'
	call put_key
	call get_word
	push ax
	mov al, '*'
	call put_key
	call get_byte
	pop si
	pop ds
	mov cl, al
	mov ch, 0
.loop:
	push cx
	push ds
	push si
	mov al, ','
	call put_key
	pop si
	pop ds
	cld
	lodsb
	push ds
	push si
	call putbyte
	pop si
	pop ds
	pop cx
	loop .loop
	jmp main
go:
	call put_key
	call get_word
	mov word [.lbl + 3], ax
	mov al, ':'
	call put_key
	call get_word
	mov word [.lbl + 1], ax
	; trash pipeline
	jmp .lbl
.lbl:
	jmp 0:start
load:
	; get ES:BX
	call put_key
	call get_word
	mov ax, es
	push es
	mov al, ':'
	call put_key
	call get_word
	push ax
	; get sector count
	mov al, '*'
	call put_key
	call get_byte
	mov ah, 0x02
	push ax
	; get cylinder count and sector
	; CH = low eights bits of cylinder count
	; CL = high two bits of cylinder count (bits 6-7)
	;      and sector (bits 0-5)
	mov al, '@'
	call put_key
	call get_word
	push ax
	; get head number and drive letter
	mov al, '$'
	call put_key
	call get_word
	mov dx, ax
	; retrieve args
	pop cx
	pop ax
	pop bx
	pop es
	int 13h
disk_stat:
	pushf
	push ax
	mov al, ':'
	call put_key
	pop ax
	call putshort
	mov al, ':'
	call put_key
	pop ax
	call putshort
	jmp main
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
	jb .1
	add al, 'A' - '0' - 10
.1:
	add al, '0'
putc:
	mov ah, 0xe
	int 10h
	ret
put_key:
	mov ah, 0xe
	int 10h
	mov al, ' '
	int 10h
	ret
get_word:
	call get_byte
	mov ah, al
	push ax
	call get_byte
	pop bx
	mov ah, bh
	ret
get_byte:
	call get_nibble
	shl ax, byte 4
	push ax
	call get_nibble
	pop bx
	add al, bl
	ret
; ask user input for one xdigit
; and also print it on screen
get_nibble:
	call get_xdigit
	push ax
	mov al, bl
	mov ah, 0xe
	int 10h
	pop ax
	ret
get_xdigit:
	mov ah, 0
	int 16h
	mov bl, al
	cmp al, ' '
	jne .1
	jmp 0:reset
.1:
	cmp al, '0'
	jb get_xdigit
	cmp al, '9'
	jg .2
	sub al, '0'
	ret
.2:
	cmp al, 'a'
	jb get_xdigit
	cmp al, 'f'
	ja get_xdigit
	sub al, 'a' - 10
	ret

	times 0x200 - 2 - ($ - $$) db 0
	dw 0xaa55
