; copyright 2017-2018 folkert van verseveld
; all rights reserved
;
; tiny monitor with spartan interface
; the program is a completely self contained bootable floppy
;
; stack starts at program start
; program layout:
; 0x00007c00 start of stack and program start
; 0x00007dff end of program

; the following commands are supported:
;  a  write to memory
;  d  dump memory
;  g  jump to address
;  l  load from drive
;  r  reset disk drive
; press ` ' to terminate commands asking user input

; compile with:
;   nasm -f bin -o m.bin m.s
; and run with:
;   qemu-system-i386 -m 1 -drive file=m.bin,format=raw -monitor stdio

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
	; print '\r\n'
	call putln
.loop:
	; get command
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
; ask for drive letter to be reset and dump result from interrupt e.g.:
;       r 80
; or  : r 00
; yield respectively when booting from floppy:
; r 80: 0180: 0283
; r 00: 0000: 0246
disk_reset:
	call put_key
	call get_byte
	mov ah, 0
	mov dl, al
	int 13h
	jmp disk_stat
assemble:
	call read_word
	mov al, ':'
	call read_word
	pop di
	pop es
	; remember that you can terminate this loop by pressing ` '
.loop:
	mov al, ','
	call put_key

	; make sure we don't globber destination ptr
	push es
	push di

	call get_byte

	pop di
	pop es

	; write data
	cld
	stosb
	jmp .loop
; dump memory
; example: d 07c0: 0000* 10
; dumps 16 bytes starting at 0x07c0:0
dump:
	call read_word
	mov al, ':'
	call read_word
	mov al, '*'
	call put_key
	call get_byte
	pop si
	pop ds
	; if count is 0, use 0x100
	cmp al, 0
	jnz .skip
	mov cx, 0x100
	jmp .loop
.skip:
	mov cl, al
	mov ch, 0
; dump memory
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

	push ax
	; put newline for each 16 bytes
	mov al, byte [es:cnt]
	cmp al, 15
	jnz .skip2
	call putln
	mov al, 0
	mov byte [es:cnt], al
	jmp .skip3
.skip2:
	inc byte [es:cnt]
.skip3:
	pop ax

	call putbyte

	pop si
	pop ds
	pop cx

	loop .loop
	; restore counter
	mov al, 15
	mov byte [es:cnt], al
	jmp main
cnt:
	db 15
; jump to specified address. e.g.: g 07c0:0000
; restarts the program
go:
	call put_key
	call get_word
	mov word [es:.lbl + 3], ax
	mov al, ':'
	call put_key
	call get_word
	mov word [es:.lbl + 1], ax
	; trash pipeline
	jmp .lbl
.lbl:
	jmp 0:start
; read sectors into memory. e.g.:
; l 07e0: 0000* 01@ 0001$ 0000: 0001: 0246
;   segm: offs* nn@ cyle$ hhdd:
; segm = segment
; offs = offset
; nn   = sector count
; cyle = cylinder count (see below for format)
; hh   = head number
; dd   = drive number
load:
	; get ES:BX
	call read_word
	mov al, ':'
	call read_word
	; get sector count
	mov al, '*'
	call put_key
	call get_byte
	push ax
	; get cylinder count and sector
	; CH = low eight bits of cylinder count
	; CL = high two bits of cylinder count (bits 6-7)
	;      and sector (bits 0-5)
	mov al, '@'
	call read_word
	; get head number and drive letter
	mov al, '$'
	call read_word
	pop dx
	; retrieve args
	pop cx
	pop ax
	mov ah, 0x02
	pop bx
	pop es
	int 13h
	; restore es for other commands
	mov ax, 0
	mov es, ax
; dump ax and flags
; this is called after a drive has been reset
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

; text output routines
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

; text input routines
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

putln:
	mov ax, 0x0e0d
	int 10h
	mov al, 0xa
	int 10h
	ret

; equivalent as if we have inlined the following:
;   call put_key
;   call get_word
;   push ax
read_word:
	call put_key
	call get_word
	pop bx
	push ax
	jmp bx

; make block bootable
	times 0x200 - 2 - ($ - $$) db 0
	dw 0xaa55
