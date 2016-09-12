; very lazy booter that reads some sectors
; and goes into protected mode
; it has error checking for real hardware
; assumes x86 machine with 80386 or better
; (it also checks if it is a 80386+)
%include "layout.inc"
ORG MBR_ADDR
BITS 16
CPU 8086
_boot:
; check if cpu is 386 or better
%define CPU386_NORET
%include "cpu.s"
	jnc oops
CPU 386
	cli
	xor ax, ax
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov sp, _boot
	mov [drive], dl
	sti
	mov bp, 5
fdloop:
	mov ah, 0
	push bp
	stc
	int 13h
	pop bp
	jnc fdread
	dec bp
	jz oops
	jmp fdloop
fdread:
	xor ax, ax
	mov [mbrend], ax
	mov cx, ax
	mov dh, 0
	mov dl, [drive]
	mov es, ax
	mov bx, 0x7e00
	mov ax, 0x0205
	mov cl, ah
	stc
	pusha
	int 13h
	popa
	jnc prep
	dec bp
	jz oops
CPU 386
prep:
	mov ax, [mbrend]
	cmp ax, 'XT'
	jne oops
	;call chka20
	;jc skipa20
	mov ax, 0x2401
	int 15h
	call chka20
	jc skipa20
	jmp oops
; check a20
chka20:
	push ds
	cli
	xor ax, ax ; ax = 0
	mov es, ax
	not ax ; ax = 0xFFFF
	mov ds, ax
	mov di, 0x0500
	mov si, 0x0510
	mov al, byte [es:di]
	push ax
	mov al, byte [ds:si]
	push ax
	mov byte [es:di], 0x00
	mov byte [ds:si], 0xFF
	cmp byte [es:di], 0xFF
	pop ax
	mov byte [ds:si], al
	pop ax
	mov byte [es:di], al
	clc
	je .noa20
	stc
.noa20:
	pop ds
	ret
CPU 8086
oops:
	int 18h
	int 19h
hang:
	hlt
	jmp hang
skipa20:
%define KSEG_CODE 1
%define KSEG_DATA 2
%define KSEG_ADDR(seg) ((seg)<<3)
CPU 386
BITS 16
	cli
	lgdt [gdtdesc]
	mov eax, cr0
	or eax, 1
	mov cr0, eax
	jmp KSEG_ADDR(KSEG_CODE):pmboot
align 16
gdt:
	dd 0, 0
	; Code
	dw 0xFFFF           ; limit low
	dw 0                ; base low
	db 0                ; base middle
	db 10011010b            ; access
	db 11001111b            ; granularity
	db 0                ; base high

	; Data
	dw 0xFFFF           ; limit low
	dw 0                ; base low
	db 0                ; base middle
	db 10010010b            ; access
	db 11001111b            ; granularity
	db 0                ; base high
gdtdesc:
	dw gdtdesc - gdt - 1
	dd gdt
pmboot:
BITS 32
	mov ax, KSEG_ADDR(KSEG_DATA)
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov ax, 0
	mov fs, ax
	mov gs, ax
	mov esp, MBR_ADDR
	jmp mbrend
	MBR_PADSIG
drive:
	MBR_SIG
mbrend:
%ifdef HEADLESS
	db 'XT'
	jmp $
%endif
