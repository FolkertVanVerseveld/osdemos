%include "layout.inc"
%include "puts.inc"
ORG MBR_ADDR
BITS 16
CPU 8086
_boot:
; setup segs
	cli
	xor ax, ax
	mov ss, ax
	mov ds, ax
; stack setup
	mov sp, _boot
; save drive while ints disabled
	mov [drive], dl
	sti
; ensure dl is a hard drive
; if qemu emulates floppy drive
; int13 ext are unavailable
	and dl, 0x80
	jz nohdd
; loop for next stage
; try max 5 times
	mov cx, 5
prepnext:
	push cx
; reset drive so state is known
	xor ax, ax
	stc
	int 13h
	jc noreset
; prepare for extended read
	mov ah, 0x41
	mov bx, 0x55aa
	stc
	int 13h
; check if supported
	jc noext
	cmp bx, 0xaa55
	jne noext
	and cl, 1
	jz noext
; extended read is supported
; prepare to read some lba sectors
	mov si, pack
	mov ah, 0x42
	mov dl, [drive]
	stc
	int 13h
; if carry reset drive cuz real hardware
; may fail multiple times (e.g. 3)
	jc tryagain
; remove count
	pop cx
	mov ax, [drive + 2]
	cmp ax, 'XT'
	jnz nonext
	mov dl, [drive]
; do long jump
	jmp 0:drive+2
nohdd:
	int 18h
hang:
	hlt
	jmp hang
noext:
	puts strnox
	jmp hang
tryagain:
	pop cx
	loop prepnext
noread:
nonext:
	puts strget
	jmp hang
noreset:
	puts strdrv
	jmp hang
strnox:
	db 'no int13 ext', 0
strget:
	db 'broken read', 0
strdrv:
	db 'crappy drive', 0
pack:
	db 0x10 ; size of this packet
	db 0 ; reserved, always zero
	dw 1 ; sector count
	dw 0x7e00 ; destination address
	dw 0 ; destination segment
	dq 1 ; absolute lba OR chs address
%include "puts.s"
	times MBR_SIZE - 2 - ($ - $$) db 0
drive:
	dw 0xAA55
