; partial code of quick bootloader
; you should not include the source directly
; just assemble with nasm and append your files

%define BOOT_ADDR 0x7c00

%define STACK_ADDR BOOT_ADDR
%define STAGE1_SIG 0xfeeb

%ifndef STAGE1_START
%define STAGE1_START (BOOT_ADDR+0x200)
%endif

%ifndef STAGE0_MAIN
%define STAGE0_MAIN stage1
%endif

%ifndef DRIVE_TRIES
%define DRIVE_TRIES 3
%endif
%ifndef DRIVE_SECTORS
%define DRIVE_SECTORS 7
%endif

ORG 0x7c00
bits 16

%include "boot.inc"

%ifdef FORCE_CS
	jmp 0:_bstart
%endif
_bstart:
; thrash only bx/cx and ds, preserving all others
%ifndef THRASH_BX
	mov cx, 0
	mov ds, cx
%else
	mov bx, 0
	mov ds, bx
%endif
; save bios stack regs in case we need to debug this
	mov [BOOTENV_ADDR + bootenv.ss], ss
	mov [BOOTENV_ADDR + bootenv.sp], sp
%ifndef THRASH_BX
	mov ss, cx
%else
	mov ss, bx
%endif
	mov sp, BOOTENV_ADDR + bootenv.flags + 2
	pushf
	pusha
	push cs
	push es
	push fs
	push gs
; all real mode registers are saved, setup proper stack
	mov sp, STACK_ADDR
; setup different drive letters to try
; use at most four different values and
; try all values until one works or give
; up after all values were tried.
	mov dl, [BOOTENV_ADDR + bootenv.dx]
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
	mov [BOOTENV_ADDR + bootenv.drive], dl
; save # and tries args
	push cx
dskrst:
	push bp
; get drive letter
	mov dl, [BOOTENV_ADDR + bootenv.drive]
; reset drive and ignore return values
	mov ah, 0
	mov [BOOTENV_ADDR + bootenv.tries], ah
	int 13h
; remove signature to look for in case
; uninitialized data just happened to
; be the signature we are looking for
	xor ax, ax
	mov [stage1sig], ax
	mov cx, ax
%ifdef FORCE_DS
	mov ds, ax
%endif
	mov es, ax
	mov bx, STAGE1_START
	mov ax, 0x0200 + DRIVE_SECTORS
	mov cl, ah
	mov dl, [BOOTENV_ADDR + bootenv.drive]
	int 13h
%ifdef FORCE_INT
	sti
%endif
	pop bp
	; check signature
	mov ax, [stage1sig]
	cmp ax, STAGE1_SIG
	je STAGE0_MAIN
	; bad signature, increment tries
	inc byte [BOOTENV_ADDR + bootenv.tries]
	dec bp
	jz short dskrst
	pop cx
	loop dskloop
