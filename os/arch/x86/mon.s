; copyright folkert van verseveld. all rights reserved

; paranoid real mode machine code monitor

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

; number of retries before giving up
%define DRIVE_TRIES 5
%define DRIVE_SECTORS 2

%define MON_SIZE (512 + DRIVE_SECTORS * 512)
%define MON_SIG 0x1337

; stack smashed
%define ERR_SSP 1

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
	jmp 0:start
start:
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
	; FIXME stub
	; now load the whole monitor from disk
	; ensure signature must be loaded from disk
load:
	mov word [mon_sig], 0
	mov ax, 0x0200 + DRIVE_SECTORS
	mov cx, 0x0002
	mov dh, 0
	mov dl, byte [drive]
	mov bx, part2
	mov bp, 13h
	call bioscall
	; ignore return status, just check signature
	cmp word [mon_sig], MON_SIG
	je init
	mov ah, 0
	mov dl, byte [drive]
	call bioscall
	dec byte [tries]
	cmp byte [tries], 0
	jne load
hang:
	hlt
	jmp hang
init:
	; TODO setup monitor
	; TODO install debug handler (int3)
	call ssp_save

	call dump_ips

	call ssp_load

	jmp hang

; dump initial processor state
dump_ips:
	; TODO dump initial program state
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
	mov si, word [sp_old]
	push DBG_ADDR_TMP / 16
	pop es

	; print
	; EAX EBX ECX EDX ESI EDI EBP ESP
	; CS DS ES FS GS SS
	mov eax, dword [es:si + 0x26]
	call putint_sp
	mov eax, dword [es:si + 0x1A]
	call putint_sp
	mov eax, dword [es:si + 0x22]
	call putint_sp
	mov eax, dword [es:si + 0x1E]
	call putint_sp
	mov eax, dword [es:si + 0x0E]
	call putint_sp
	mov eax, dword [es:si + 0x0A]
	call putint_sp
	mov eax, dword [es:si + 0x12]
	call putint_sp
	mov eax, dword [es:si + 0x16]
	call putint_sp
	mov si, str_lf
	call puts

	push word 0
	pop es

	ret

putint_sp:
	call putint
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

	call bioscall
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

	; save ss:sp, modify restore code
	mov word [bc_ax + 1], ax
	push ss
	pop ax
	mov word [bc_ss + 1], ax
	mov word [bc_sp + 1], sp
	; self modify interrupt vector
	push ds

	push word 0
	pop ds
	mov ax, bp
	mov byte [bc_int + 1], al

	pop ds
	; all set! but pipeline is dirty
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

	; TODO data

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