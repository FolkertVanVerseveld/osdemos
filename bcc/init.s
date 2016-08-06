%include "api.inc"

; function prologue of bcc is the signature
%define BCC_SIG 0x8955
%define DRIVE_SECTORS (18 - BS_SECTORS)
%ifndef DRIVE_TRIES
%define DRIVE_TRIES 3
%endif
%define DRIVE_START (BS_SECTORS+2)

; sequence point
struc seq_pt
	.ss: resw 1
	.sp: resw 1
	.gs: resw 1
	.fs: resw 1
	.es: resw 1
	.ds: resw 1
	.cs: resw 1
	.flags: resw 1
endstruc

org MMAP_BOOTAPI_ADDR
bits 16

	jmp short start
	jmp word api_call
start:
	mov bp, DRIVE_TRIES
dskrst:
	push bp
	mov dl, [MMAP_BOOTENV_ADDR + bootenv.drive]
	mov ah, 0
	int 13h
dskread:
	xor ax, ax
	mov [MMAP_KERNEL_ADDR], ax
	mov cx, ax
	mov ds, ax
	mov es, ax
	mov bx, MMAP_KERNEL_ADDR
	mov ax, 0x0200 + DRIVE_SECTORS
	mov cl, DRIVE_START
	mov dl, [MMAP_BOOTENV_ADDR + bootenv.drive]
	int 13h
	pop bp
	mov ax, [MMAP_KERNEL_ADDR]
	cmp ax, BCC_SIG
	je short dskdone
	dec bp
	jz short dskrst
	mov si, strk_missing
fail:
	call puts
	mov ah, 0
	int 16h
	int 18h
	int 19h
die:
	hlt
	jmp short die
dskdone:
; call in case it does return
	call MMAP_KERNEL_ADDR
; restore stuff
	xor ax, ax
	mov ss, ax
	mov sp, MMAP_STACK_ADDR
	mov ds, ax
	mov es, ax
	mov si, strk_return
	jmp fail
_putcloop:
	mov ah, 0xe
	int 10h
puts:
	cld
	lodsb
	cmp al, 0
	jne _putcloop
	ret
strk_missing db 'kernel not found', 13, 10, 0
strk_return db 'kernel_main returned', 13, 10, 0
; similar to dos interrupt/syscall
; bp+4 == nr
; bp+6 == first argument
api_call:
	mov bx, [bp+4]
	mov ax, [api_tbl + bx]
	jmp ax
; api jump table
api_tbl:
	dw kputs
kputs:
	mov si, [bp+6]
	jmp puts
str_trap db 'trap', 13, 10, 0
	times (MMAP_BOOTAPI_SIG_ADDR - MMAP_BOOTAPI_ADDR) - ($ - $$) db 0
	dw BOOTAPI_SIG
