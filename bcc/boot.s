; strictly designed for 18 or more sectors per cylinder on boot medium
; simple bootloader that makes it easier to call low level things from
; bcc programs by providing a simple api

org 0x7c00
bits 16

%ifndef DRIVE_TRIES
%define DRIVE_TRIES 3
%endif

%include "api.inc"

%ifndef THRASH_BX
	mov cx, 0
	mov ds, cx
%else
	mov bx, 0
	mov ds, bx
%endif
	mov [MMAP_BOOTENV_ADDR + bootenv.ss], ss
	mov [MMAP_BOOTENV_ADDR + bootenv.sp], sp
%ifndef THRASH_BX
	mov ss, cx
%else
	mov ss, bx
%endif
	mov sp, MMAP_BOOTENV_ADDR + bootenv.flags + 2
	pushf
	pusha
	push cs
	push es
	push fs
	push gs
; all real mode registers are saved, setup proper stack
	mov sp, MMAP_STACK_ADDR
; setup different drive letters to try
; use at most four different values and
; try all values until one works or give
; up after all values were tried.
	mov [MMAP_BOOTENV_ADDR + bootenv.drive], dl
	mov bl, dl
	xor bl, byte 0x81
	push bx
	xor bl, byte 1
	push bx
	xor dl, byte 1
	push dx
	xor dl, byte 1
; dl gets xor'ed twice with same mask
; so we ensure that the drive letter
; provided by BIOS is tried first
	push dx
	mov cx, 4 ; # pushed
	mov bp, DRIVE_TRIES
dskloop:
; get drive letter
	pop dx
; save drive letter
	mov [MMAP_BOOTENV_ADDR + bootenv.drive], dl
; save # and tries args
	push cx
dskrst:
	push bp
; get drive letter
	mov dl, [MMAP_BOOTENV_ADDR + bootenv.drive]
; reset drive and ignore return values
	mov ah, 0
	mov [MMAP_BOOTENV_ADDR + bootenv.tries], ah
	int 13h
; remove signature to look for in case
; uninitialized data just happened to
; be the signature we are looking for
	xor ax, ax
	mov [MMAP_BOOTAPI_SIG_ADDR], ax
	mov cx, ax
	mov ds, ax
	mov es, ax
	mov bx, MMAP_BOOTAPI_ADDR
	mov ax, 0x0200 + BS_SECTORS
	mov cl, ah
	mov dl, [MMAP_BOOTENV_ADDR + bootenv.drive]
	int 13h
	pop bp
	mov ax, [MMAP_BOOTAPI_SIG_ADDR]
	cmp ax, BOOTAPI_SIG
	je dskdone
	; bad signature, increment tries
	inc byte [MMAP_BOOTENV_ADDR + bootenv.tries]
	dec bp
	jz short dskrst
	pop cx
	loop dskloop
fail:
	int 18h
	int 19h
die:
	hlt
	jmp short die
dskdone:
	jmp 0:MMAP_BOOTAPI_ADDR
	times 510 - ($ - $$) db 0
	dw 0xaa55
