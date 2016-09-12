; this is a ultimate boot floppy
; the main purpose is to be able
; to preserve as much information
; as possible so debugging on real
; hardware should be easy.
;
; trashed regs are dx and ds
; all other regs are preserved
;
; NOTE: this source code uses
; very dangerous stuff, so do not
; adept this coding style for
; any *real* programs!
;%define PUTHEX_NOINT
%define PUTHEX_SHORTSEP
%define BIOS_TRASHF
%include "layout.inc"
%include "bios.inc"
%include "puthex.inc"
%include "strcmp.inc"
ORG MBR_ADDR
BITS 16
CPU 386
; preserve as much as possible
_boot:
acc:
; assume dx is 0
	mov dx, ax
stackseg:
	xor ax, ax
stackptr:
	mov ds, ax
; now save registers
; before we trash them
flags:
	mov [acc], dx
	mov [stackseg], ss
	mov [stackptr], sp
%if 1
	nop
%else
	hlt
%endif
; if we have an interrupt here
; we are in *BIG* trouble
	mov ss, ax
	mov sp, _boot
	pushf
	pop ax
	mov [flags], ax
; yay, now do some real stuff
; ax, ss, sp and f are saved
; push all registers on stack
	cli
; oh my god, this is awful
	mov sp, $+2
; XXX do NOT try to execute
; code before this, because
; that code is destroyed!
	push cs
	push es
	push fs
	push gs
	xor ax, ax
	xchg ax, dx
	pusha
	mov sp, _boot
	sti
; print preserved values
; with nice names etc.
	mov cx, 16
	mov si, strregs
nameloop:
	push cx
	mov al, ' '
	call kputchar
	cld
	lodsb
	call kputchar
	lodsb
	call kputchar
	mov al, ' '
	call kputchar
	call kputchar
	pop cx
	loop nameloop
	mov si, acc
	mov cx, 16
regloop:
	push cx
	cld
	lodsw
	push si
	call kputshort
	pop si
	pop cx
	loop regloop
%ifndef UBOOT_BAREBONES
; vbr main loop
%ifdef UBOOT_WAIT
	mov ah, 0
	int 16h
	cmp al, 's'
	jne fdrst
	int 19h
%endif
; try boot from drive
	mov al, 0
ddboot:
	mov [drive], al
fdrst:
	mov ah, 0
	call fdint
	xor ax, ax
	mov [mbrend], ax
	mov cx, ax
	mov dx, ax
	mov es, ax
	mov bx, 0x7e00
	mov ax, 0x0205
	mov cl, ah
	call fdint
	mov ax, [mbrend]
	cmp ax, 'XT'
	je mbrend+2
; if floppy and hard
; disk failed, panic
	mov al, [drive]
	cmp al, 0
	jne hang
; try hard disk
	mov al, 80h
	jmp ddboot
%endif
hang:
	int 18h
reboot:
	jmp 0xffff:0
%ifndef UBOOT_BAREBONES
fdint:
	mov bp, 5
fdloop:
	stc
	push bp
	mov dl, [drive]
	bioscall 13h
	jnc fddone
%ifndef NO_ERRCTL
	pusha
	mov ax, 0xdead
	call kputshort
	popa
%endif
	pop bp
	dec bp
	jnz fdloop
	ret
fddone:
	pop bp
	sub sp, 2
	ret
%endif
%include "puthex.s"
%include "bios.s"
strregs:
	db 'AXSSSPIFDISIBPSPBXDXCXAXGSFSESCS'
	times MBR_SIZE - 2 - ($ - $$) db 0
drive:
	dw 0xAA55
mbrend:
%ifndef UBOOT_BAREBONES
%define PUTS_CCHR
%include "puts.inc"
%define CMDSIZE 120
stage2:
	db 'XT'
	putsln strboot
	bioscall 12h
	biosgetax
	push ax
	mov si, strmeml
	call kprintf
	mov ah, 0xf
	bioscall 10h
	biosgetax
	mov [vmod], ax
	push ax
	mov si, strvmod
	call kprintf
	putsln strbios
	mov ah, 0
	bioscall 16h
	biosgetax
	cmp al, 'r'
	je reboot
	cmp al, 'p'
	je reboot
	putsln strbnorm
	mov ax, [vmod]
	cmp al, 3
	je .nochange
	mov ah, 0
	bioscall 10h
	mov ax, [vmod]
.nochange:
	putsln strbdone
cmdloop:
	puts strps1
.kbp:
	mov ah, 0
	bioscall 16h
	biosgetax
; ignore if invalid key
	cmp al, 8
	je .noctl
	cmp al, 0xd
	je .noctl
	cmp al, ' '
	jb .kbp
	cmp al, '~'
	ja .kbp
.noctl:
	push ax
	mov ah, 3
	mov bh, 0
	bioscall 10h
	biosgetdx
	mov [cursy], dh
	mov [cursx], dl
	pop ax
	push ax
	cmp al, 0xd
	jne .bs
; goto next line by moving
; cursor to last column and
; advancing one character
	mov al, [vmod + 1]
	mov dl, al
	dec dl
	mov ah, 2
	mov bh, 0
	bioscall 10h
	mov al, ' '
	call kputchar
; TODO parse cmd
; reset buffer
	mov si, cmdbuf
	mov ah, 0
	mov al, [cmdlen]
	add si, ax
	mov al, 0
	cld
	stosb
	mov [cmdlen], al
	strcmp cmdbuf, cmdhalt
	jnc reboot
	strcmp cmdbuf, cmdhelp
	jnc .cmdhelp
	putsln strcmdbad
	jmp cmdloop
.cmdhelp:
	putsln strhelp
	jmp cmdloop
.bs:
	cmp al, 8
	jne .chk
	mov al, [cmdlen]
	cmp al, 0
	je .kbp
	dec al
	mov [cmdlen], al
	mov ah, 2
	xor bx, bx
	mov dh, [cursy]
	mov dl, [cursx]
	cmp dl, 0
	jnz .mincol
	mov al, [vmod + 1]
	dec al
	mov dl, al
	cmp dh, 0
	je .skip
	dec dh
	jmp .skip
.mincol:
	dec dl
	mov [cursx], dl
.skip:
	bioscall 10h
	mov ah, 0xa
	mov al, ' '
	bioscall 10h
	jmp .kbp
.chk:
	mov dl, [cmdlen]
	cmp dl, CMDSIZE-1
	jge .kbp
	mov di, cmdbuf
	push ax
	movzx ax, dl
	add di, ax
	pop ax
	cld
	stosb
	inc dl
	mov [cmdlen], dl
	call kputchar
	pop ax
	mov ah, 3
	mov bh, 0
	bioscall 10h
	biosgetdx
	mov [cursy], dh
	mov [cursx], dl
%ifndef NDEBUG
	push ax
	mov ah, 2
	mov bh, 0
	xor dx, dx
	bioscall 10h
	mov al, [cursy]
	call kputbyte
	mov al, ' '
	call kputchar
	mov al, [cursx]
	call kputbyte
	mov al, ' '
	call kputchar
	pop ax
	call kputbyte
	mov ah, 2
	mov bh, 0
	mov dh, [cursy]
	mov dl, [cursx]
	bioscall 10h
%endif
	jmp .kbp
die:
	hlt
	jmp die
align 2
vmod:
	dw 0
cursx:
	db 0
cursy:
	db 0
%include "printf.s"
%include "strcmp.s"
strboot:
	db 0xa, 'UBOOT 150806', 0xa
	db 'cpu stats', 0xa
	db 'mode vintage', 0xa
	db 'arch x86', 0xa
	db 'type 386+', 0
strmeml:
	db 'low mem 0x%HKB', 0xa, 0
strvmod:
	db 'video mode 0x%H', 0xa, 0
strbios:
	db 0xa, 0xa, 'Welcome to Ultimate Boot disk (UBOOT)', 0xa
	db 'In this menu, you can tell UBOOT how you want to boot this machine', 0xa
	;db 'Press P to boot in paranoid mode', 0xa
	db 'Press R to reboot the machine', 0xa
	db 'Press anything else to boot in normal mode', 0x0
	;db 'Use P if you have problems with booting', 0
strbnorm:
	db 'Now booting UBOOT', 0
strbdone:
	db 'Operating in shell mode, type help for help', 0
strps1:
	db '$ ', 0
cmdlen:
	db 0
cmdbuf:
	times CMDSIZE db 0
cmdhalt:
	db 'halt', 0
cmdhelp:
	db 'help', 0
strcmdbad:
	db 'Unknown command, type help for help', 0
strhelp:
	db 'Sorry, nothing to see here yet.', 0xa
	db 'Type halt to reboot the machine', 0
%endif
