; copyright folkert van verseveld. all rights reserved

; paranoid real mode machine code monitor
; 80386 or better required (for pushfd etc.)

; stack starts at program start
; program layout:
; 0x00007c00 start stack & program
; 0x00007dff end   initial program
; 0x00007e00 start monitor part2
; 0x00007fff end   monitor code
; 0x00008000 start monitor data

; compile and run with:
;   nasm -f bin -o mon.bin mon.s && xxd mon.bin && qemu-system-i386 -m 1 -drive file=mon.bin,if=floppy,format=raw -monitor stdio

%define PROG_ADDR 0x7c00
%define STACK_ADDR PROG_ADDR

; NOTE make sure this is after `mon_sig', because
;      it will be overwritten while loading part2!
%define DBG_ADDR_TMP 0x8200
%define DBG_ADDR     0x0800

; bios call return state dump
; layout:
; 0x0700: edi
; 0x0704: esi
; 0x0708: ebp
; 0x070C: esp
; 0x0710: ebx
; 0x0714: edx
; 0x0718: ecx
; 0x071C: eax
; 0x0720: gs
; 0x0722: fs
; 0x0724: es
; 0x0726: ds
; 0x0728: eflags

%define BIOSCALL_ADDR 0x0700
%define BIOSCALL_ADDR_EAX (BIOSCALL_ADDR + 0x1C)
%define BIOSCALL_ADDR_ECX (BIOSCALL_ADDR + 0x18)
%define BIOSCALL_ADDR_EDX (BIOSCALL_ADDR + 0x14)

; --------V-1006-------------------------------
; INT 10 - VIDEO - SCROLL UP WINDOW
; 	AH = 06h
; 	AL = number of lines by which to scroll up (00h = clear entire window)
; 	BH = attribute used to write blank lines at bottom of window
; 	CH,CL = row,column of window's upper left corner
; 	DH,DL = row,column of window's lower right corner
; Return: nothing
; Note:	affects only the currently active page (see AH=05h)
; BUGS:	some implementations (including the original IBM PC) have a bug which
; 	  destroys BP
; 	the Trident TVGA8900CL (BIOS dated 1992/9/8) clears DS to 0000h when
; 	  scrolling in an SVGA mode (800x600 or higher)
; SeeAlso: AH=07h,AH=12h"Tandy 2000",AH=72h,AH=73h,AX=7F07h,INT 50/AX=0014h
; --------V-1007-------------------------------
; INT 10 - VIDEO - SCROLL DOWN WINDOW
; 	AH = 07h
; 	AL = number of lines by which to scroll down (00h=clear entire window)
; 	BH = attribute used to write blank lines at top of window
; 	CH,CL = row,column of window's upper left corner
; 	DH,DL = row,column of window's lower right corner
; Return: nothing
; Note:	affects only the currently active page (see AH=05h)
; BUGS:	some implementations (including the original IBM PC) have a bug which
; 	  destroys BP
; 	the Trident TVGA8900CL (BIOS dated 1992/9/8) clears DS to 0000h when
; 	  scrolling in an SVGA mode (800x600 or higher)
; SeeAlso: AH=06h,AH=12h"Tandy 2000",AH=72h,AH=73h,INT 50/AX=0014h

; --------V-1002-------------------------------
; INT 10 - VIDEO - SET CURSOR POSITION
; 	AH = 02h
; 	BH = page number
; 	    0-3 in modes 2&3
; 	    0-7 in modes 0&1
; 	    0 in graphics modes
; 	DH = row (00h is top)
; 	DL = column (00h is left)
; Return: nothing
; SeeAlso: AH=03h,AH=05h,INT 60/DI=030Bh,MEM 0040h:0050h
; --------V-1003-------------------------------
; INT 10 - VIDEO - GET CURSOR POSITION AND SIZE
; 	AH = 03h
; 	BH = page number
; 	    0-3 in modes 2&3
; 	    0-7 in modes 0&1
; 	    0 in graphics modes
; Return: AX = 0000h (Phoenix BIOS)
; 	CH = start scan line
; 	CL = end scan line
; 	DH = row (00h is top)
; 	DL = column (00h is left)
; Notes:	a separate cursor is maintained for each of up to 8 display pages
; 	many ROM BIOSes incorrectly return the default size for a color display
; 	  (start 06h, end 07h) when a monochrome display is attached
; 	With PhysTechSoft's PTS ROM-DOS the BH value is ignored on entry.
; SeeAlso: AH=01h,AH=02h,AH=12h/BL=34h,MEM 0040h:0050h,MEM 0040h:0060h

; number of retries before giving up
%define DRIVE_TRIES 5
%define DRIVE_SECTORS 2

%define MON_SIZE (512 + DRIVE_SECTORS * 512)
%define MON_SIG 0x1337

; stack smashed
%define ERR_SSP 1

%define INT_BIOS_WRAPPER 0xf5

bits 16
org PROG_ADDR

reset:
	; preserve as much registers as possible
	; we have to thrash a gp reg as well as
	; the data or stack segment register
	push word DBG_ADDR_TMP / 16
	pop ss
	pushfd
	pushad
	push cs
	push ds
	push es
	; this long jump recides exactly within the
	; first 16 bytes of the whole program. this
	; trick ensures that this jump is always
	; reachable even with a bogus initial cs
	jmp 0:$+5
	push fs
	push gs
	; everything has been saved
	; setup a proper environment
	cli
	mov bx, sp
	xor ax, ax
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov sp, STACK_ADDR
	mov word [sp_old], bx
	; in case the bios fucks this up
	mov dl, byte [drive]
	sti
	; setup bios wrapper
	cld
	mov di, INT_BIOS_WRAPPER * 4
	mov ax, bios_wrapper
	stosw
	xor ax, ax
	stosw
	; make sure we are in the correct video mode
	; this also clears the screen and resets the cursor
	mov ax, 0x0003
	mov bp, 10h
	int INT_BIOS_WRAPPER
	; now load the whole monitor from disk
	; ensure signature must be loaded from disk
load:
	; just in case the BIOS manages to fuck this up
	call ssp_save

	mov word [mon_sig], 0
	mov ax, 0x0200 + DRIVE_SECTORS
	mov cx, 0x0002
	mov dh, 0
	mov dl, byte [drive]
	mov bx, part2
	mov bp, 13h
	int INT_BIOS_WRAPPER

	call ssp_load

	; ignore return status, just check signature
	cmp word [mon_sig], MON_SIG
	je init
	mov ah, 0
	mov dl, byte [drive]
	int INT_BIOS_WRAPPER
	dec byte [tries]
	cmp byte [tries], 0
	jne load
hang:
	hlt
	jmp hang
init:
	; TODO setup monitor
	; TODO install debug handler (int3)
	call dump_ips

	jmp part2

die:
	mov ax, 0x0e00 + '!'
	mov bp, 10h
	int INT_BIOS_WRAPPER
	hlt
	jmp die

; interrupt handler
; candidates: f5, f6
bios_wrapper:
	call bioscall
	iretw

; dump initial processor state
dump_ips:
	; data is somewhere in segment 0x8200
	; qemu has sp=0x6efe
	; which means data starts at: 0x8200 + 0x6efe = 0xf0fe
	; 00: gs
	; 02: fs
	; 04: es
	; 06: ds
	; 08: cs
	; 0A: edi
	; 0E: esi
	; 12: ebp
	; 16: esp
	; 1A: ebx
	; 1E: edx
	; 22: ecx
	; 26: eax
	; 2A: eflags

	; print format:
	; EAX ECX EDX EBX ESP EBP ESI EDI
	; CS DS ES FS GS EFLAGS
	mov si, [sp_old]
	add si, 0x26
	push word DBG_ADDR_TMP / 16
	pop ds

	std
	mov cx, 8
.l:
	lodsd
	call putint_sp
	loop .l
	mov cx, 5

	call putlf

.l2:
	lodsw
	call putshort_sp
	loop .l2
	mov eax, dword [si + 0x2e]
	call putint_sp

	call putlf

	push word 0
	pop ds

	ret

putlf:
	mov al, 0xd
	call putchar
	mov al, 0xa
	jmp putchar

putint_sp:
	call putint
	mov al, ' '
	jmp putchar
putshort_sp:
	call putshort
	mov al, ' '
	jmp putchar
putbyte_sp:
	call putbyte
	mov al, ' '
	jmp putchar

; stack smashing protection
; ssp_save dumps correct stack state
; ssp_load reads and checks stack state
ssp_save: ; sp - 2
	pushf ; sp - 4
	push ds ; sp - 6

	push word 0
	pop ds ; sp - 6

	mov word [ssp_ss], ss
	; correct sp
	add sp, 6
	mov word [ssp_sp], sp
	sub sp, 6

	pop ds
	popf
	ret

ssp_load: ; sp - 2
	push ds ; sp - 4
	pusha ; sp - 20

	push word 0
	pop ds ; sp - 20

	mov al, ERR_SSP

	push ss
	pop bx ; sp - 20
	cmp bx, word [ssp_ss]
	jne panic

	add sp, 20
	cmp sp, word [ssp_sp]
	jne panic
	sub sp, 20

	popa
	pop ds
	ret

panic:
	push ax

	push word 0
	pop ds

	mov si, str_panic
	call puts

	pop ax

	call putbyte

	jmp hang

_puts_loop:
	call putchar
puts:
	cld
	lodsb
	cmp al, 0
	jne _puts_loop
	ret

; text output routines
putint:
	push eax
	shr eax, 16
	call putshort
	pop eax
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
putchar:
	;mov byte [bc_int + 1], 10h
	mov bp, 10h
	mov ah, 0xe
	xor bx, bx

	int INT_BIOS_WRAPPER
	ret

; paranoid sandbox
; ensures that the bios doesn't mess with anything it shouldn't
; preserves everything except cs
; NOTE: the interrupt vector is specified in bp
bioscall:
	push ds
	push es
	push fs
	push gs

	pushad
	pushfd

	push ds
	push word 0
	pop ds

	; save ss:sp, modify restore code
	mov word [bc_ax + 1], ax
	push ss
	pop ax
	mov word [bc_ss + 1], ax
	; we saved ds earlier, so sp is different
	add sp, 2
	mov word [bc_sp + 1], sp
	sub sp, 2

	; self modify interrupt vector
	mov ax, bp
	mov byte [bc_int + 1], al

	; all set! but pipeline is dirty
	pop ds
	jmp bc_ax
bc_ax:
	mov ax, word 0x0bad
bc_int:
	int 13h
	; interrupt returned
	; save all stuff except cs:ip

	; XXX make this fit in segment shizzle
	jmp 0:bc_ss
bc_ss:
	push word 0xdead
	pop ss
bc_sp:
	mov sp, word 0xbabe

	pushfd
	push ds
	push es
	push fs
	push gs
	pushad

	xor ax, ax
	mov ds, ax
	mov es, ax
	mov si, sp
	mov di, BIOSCALL_ADDR
	mov cx, 11
	cld
	rep
	movsd
	add sp, 44

	popfd
	popad

	pop gs
	pop fs
	pop es
	pop ds

	ret

tries:
	db DRIVE_TRIES

	times 0x200 - 2 - ($ - $$) db 0
	dw 0xaa55
part2:
	call get_key

	mov ax, [BIOSCALL_ADDR_EAX]
	cmp al, 0x6d
	jne .1
	call dump_mem
	jmp part2
.1:

	call putshort

	jmp part2

	; TODO data

get_key:
	mov ah, 0
	mov bp, 16h
	int INT_BIOS_WRAPPER
	ret

dump_mem:
	mov ax, word [dm_seg]
	call putshort
	mov al, ':'
	call putchar
	mov ax, word[dm_off]
	call putshort_sp

	mov si, word [dm_off]
	push word [dm_seg]
	pop ds

	mov cx, 16
.l:
	cld
	lodsb
	call putbyte_sp
	loop .l

	push word 0
	pop ds

	; wait for user input
.w:
	call get_key

	mov ax, [BIOSCALL_ADDR_EAX]
	cmp ah, 0x48

	je .up

	call putlf
	ret

.up:
	; fetch cursor position
	mov ah, 3
	mov bh, 0
	int 10h

	; scroll if on first row
	;mov dx, word [BIOSCALL_ADDR_EDX]
	cmp dh, 0
	jnz .2

	; move cursor up by scrolling down
	mov ah, 0x0701
	mov bh, 7
	xor cx, cx
	mov dh, 25 - 1
	mov dl, 80 - 1

	int 10h

	; update read ptr
.2:
	mov si, word [dm_off]
	sub si, byte 16

	ja .1
	dec word [dm_seg]
.1:
	mov word [dm_off], si

	; apply new position
	dec dh
	mov dl, 0
	mov ah, 2
	mov bh, 0

	int 10h

	; dump new row
	jmp dump_mem
.down:
	jmp .w

str_panic:
	db 0xd, 0xa, "ERR: ", 0
str_lf:
	db 0xd, 0xa, 0

	times MON_SIZE - 2 - ($ - $$) db 0
mon_sig:
	dw MON_SIG

; I/O data
drive:
	db 0
sp_old:
	dw 0
; stack smashing protector
ssp_ss:
	dw 0
ssp_sp:
	dw 0
; dump memory command
dm_seg:
	dw 0
dm_off:
	dw 0
