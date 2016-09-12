; very simple booter that some sectors
; and jumps to that code if success
; provides multiple error checking:
;  80386 or better check
;  tries 5 times to read the sectors
; calls ROM basic if booting fails
; (most pc's try the next one in
; boot order or just say the device
; is not bootable)
%include "layout.inc"
%ifndef STAGE2_NSEC
%define STAGE2_NSEC 11
%endif
ORG MBR_ADDR
BITS 16
CPU 8086
%define STAGE2_SIG 'XT'
%define CPU386_NORET
%ifndef NO_CS_FIX
	jmp 0:_boot
%endif
_boot:
%include "cpu.s"
	jnc die
CPU 386
	cli
	xor ax, ax
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov sp, MBR_ADDR
	mov [drive], dl
	sti
	mov bp, 5
dloop:
	mov ah, 0
	push bp
	stc
	int 13h
	pop bp
	jnc dread
	dec bp
	jz die
	jmp dloop
dread:
	xor ax, ax
	mov [mbrend], ax
	mov cx, ax
	mov dh, 0
	mov dl, [drive]
	mov es, ax
	mov bx, MBR_ADDR + MBR_SIZE
	mov ax, 0x0200 + STAGE2_NSEC
	mov cl, ah
	stc
	pusha
	int 13h
	popa
	jnc prep
	dec bp
	jz die
prep:
	mov ax, [mbrend]
	cmp ax, STAGE2_SIG
	jne dloop
	jmp mbrend + 2
die:
	int 18h
hang:
	hlt
	jmp hang
	MBR_PADSIG
drive:
	MBR_SIG
mbrend:
%ifdef HEADLESS
	db STAGE2_SIG
	mov ah, 0eh
	mov al, '!'
	int 10h
	jmp hang
%endif
