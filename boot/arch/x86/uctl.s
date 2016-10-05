;%define TTY_USE_VMEM
%define BIOS_TRASHF
%define PUTS_CCHR
%include "layout.inc"
%include "printf.inc"
%include "bios.inc"
ORG 0x7e00
BITS 16
CPU 386
	db 'XT'
	ttyinit
	putsln strboot
	bioscall 12h
	biosgetax
	push ax
	mov si, strmeml
	call kprintf
	mov ax, [ttyvmod]
	push ax
	mov si, strvmod
	call kprintf
	putsln strbios
hang:
	hlt
	jmp hang
%include "tty.s"
%include "printf.s"
%include "bios.s"
align 2
vmod:
	dw 0
strboot:
	db 'UBOOT 150830', 0xa
	db 'cpu stats', 0xa
	db 'mode real arch  x86 type 386+', 0
strmeml:
	db 'low mem 0x%HKB', 0xa, 0
strvmod:
	db 'video mode 0x%H', 0xa, 0
strbios:
	db 0xa, 0xa
	db 'Welcome to Ultimate Boot disk (UBOOT)', 0xa
	db 'In this menu, you can tell UBOOT how you want to boot this machine', 0xa
	db 'Press R to reboot the machine', 0xa
	db 'Press anything else to boot in normal mode', 0
