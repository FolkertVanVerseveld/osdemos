; all rights reserved
;
; machine code monitor
;
; stack starts at program start
; program layout:
; 0x00007c00 start stack & program
; 0x00007dff end   initial program
; 0x00007e00 start monitor part2
; 0x00007fff end   monitor code
; 0x00008000 start monitor data

; compile and run with:
;   nasm -f bin -o m2.bin m2.s && xxd m2.bin && qemu-system-i386 -m 1 -drive file=m2.bin,if=floppy,format=raw -monitor stdio

%define PROG_ADDR 0x7c00
%define STACK_ADDR PROG_ADDR

%define DBG_ADDR_TMP 0x8000
%define DBG_ADDR     0x0800

; number of retries before giving up
%define DRIVE_TRIES 5
%define DRIVE_SECTORS 1

%define MON_SIZE 1024
%define MON_SIG 0x1337

bits 16
org PROG_ADDR

reset:
	; preserve as much registers as possible
	; we have to thrash a gp reg as well as
	; the data or stack segment register
	mov bx, DBG_ADDR_TMP / 16
	mov ss, bx
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
	; everything has been safed
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
	; now load the whole monitor from disk
	; ensure signature must be loaded from disk
load:
	mov word [mon_sig], 0
	mov ax, 0x0200 + DRIVE_SECTORS
	mov cx, 0x0002
	mov dh, 0
	mov dl, byte [drive]
	mov bx, part2
	int 13h
	; ignore return status, just check signature
	cmp word [mon_sig], MON_SIG
	je init
	mov ah, 0
	mov dl, byte [drive]
	int 13h
	dec byte [tries]
	cmp byte [tries], 0
	jne load
hang:
	hlt
	jmp hang
init:
	; relocate initial program state to DBG_ADDR
	mov si, [STACK_ADDR - 2]
	mov di, DBG_ADDR

	; pushad + fd + segment registers
	mov cx, 8 + 1 + 5
	cld
	; yeah, i could unrol this, but size is more important
.loop:
	push word DBG_ADDR_TMP / 16
	pop ds
	lodsd
	stosd
	xor ax, ax
	mov ds, ax
	loop .loop

	; install custom int3 handler
	cld
	mov di, 3 * 4
	mov ax, dbg
	stosw
	xor ax, ax
	stosw
	; custom handler has been installed
	; make sure we are in the correct video mode
	; this also clears the screen and resets the cursor
	mov ax, 0x0003
	int 10h

	; TODO dump initial program state

	; dump twice to check nothing gets thrashed
	; (except EIP is different of course)
	int3 ; db 0xcc
	int3 ; db 0xcc
	jmp part2

dump:
	push eax
	push ds

	; save eip
	xor ax, ax
	mov ds, ax
	mov ax, word [esp + 6]
	mov dword [eip_old], eax

	pop ds
	pop eax

	jmp _dump

; dump processor state
; all registers are preserved
_dump:
	push ds
	push es

	; prepare all arguments for dumping
	pushfd
	pushad
	; make it easier to grab eflags later (see line 183)
	pushfd

_dump2:
	push ss
	push gs
	push fs
	push esp
	push ebp
	push edi
	push esi
	push es
	push ds
	; TODO use self-modifying code to hack cs
	push cs
	push edx
	push ecx
	push ebx
	push eax

	xor ax, ax
	mov ds, ax
	mov es, ax
	mov si, str_text
	call printf

	; we have dumped all gpr and segment registers
	; so we can thrash them without worrying about them
	mov bx, str_flags0
	mov si, str_flags1
	; eflags has 18 fields (including preserved bits)
	mov cx, 18

	; grab eflags (see line 150)
	pop edx

	mov ebp, 0x00040000

	mov di, str_flags
	cld

	; loop for each field and grab from
	; si if set or from bx if not set
.l:
	shr ebp, byte 1
	lodsb

	push bx
	mov ebx, edx
	and ebx, ebp
	jz .z
	pop bx

	stosb

	inc bx
	loop .l
	jmp .done
.z:
	pop bx

	mov al, [bx]

	stosb

	inc bx
	loop .l

.done:
	xor ax, ax
	stosb

	push str_flags
	push dword [eip_old]

	mov si, str_text2
	call printf

	popad
	popfd

	pop es
	pop ds

	ret

; simplistic real mode printf
; format string in $si
; arguments on stack
; supported types in format string:
; ch type   base cnt cprintf
; X  uint32  16   4        X
; H  uint16  16   2       hX
; S  uint8   16   2      hhX
; B  uint8   16   1      hhX
; c  uint8        2        c
; C  uint8        1        c
; s  char*        2        s
; you need to make sure your format string
; is correct and that you push enough arguments
; otherwise the stack will be corrupted
printf:
	push bp
	mov bp, sp
	add bp, 4
.floop:
	cld
	lodsb
	cmp al, 0
	je .fdone
	; look for argument
	cmp al, '%'
	jne .def
	; determine type
	lodsb
	cmp al, 'X'
	je .putX
	cmp al, 'H'
	je .putH
	cmp al, 'S'
	je .putS
	cmp al, 'B'
	je .putB
	cmp al, 'C'
	je .putC
	cmp al, 'c'
	je .putc
	cmp al, 's'
	je .puts
	; just print char
.def:
	; if newline
	cmp al, 0xa
	jne .char
	; print newline
	push ax
	mov al, 0xd
	call putc
	pop ax
.char:
	call putc
	jmp .floop
.putX:
	mov eax, [bp]
	call putint
	add bp, 4
	jmp .floop
.putH:
	mov ax, [bp]
	call putshort
	add bp, 2
	jmp .floop
.putS:
	mov ax, [bp]
	call putbyte
	add bp, 2
	jmp .floop
.putB:
	mov ax, [bp]
	call putbyte
	inc bp
	jmp .floop
.putc:
	mov ax, [bp]
	call putc
	add bp, 2
	jmp .floop
.putC:
	mov ax, [bp]
	call putc
	inc bp
	jmp .floop
.puts:
	push si
	mov si, [bp]
	push bp
	call puts
	pop bp
	add bp, 2
	pop si
	jmp .floop
.fdone:
%ifndef KF_NO_KEEP
; remove args from printf
	mov bx, bp
	mov bp, sp
	mov ax, [bp+2]
	pop bp
	mov sp, bx
	jmp ax
%else
	pop bp
	ret
%endif
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
putc:
	mov ah, 0xe
	int 10h
	ret
_puts_loop:
	call putc
puts:
	cld
	lodsb
	cmp al, 0
	jne _puts_loop
	ret

; I/O data
drive:
	db 0
tries:
	db DRIVE_TRIES
	times 0x200 - 2 - ($ - $$) db 0
	dw 0xaa55

part2:
	; TODO dump initial program state

	;push ds
	;mov si, word [sp_old]
	;mov ax, DBG_ADDR_TMP / 16
	;mov ds, ax
	;int3
	;jmp hang
	;;mov ax, 0xffff
	;;mov ds, ax
	;;mov si, 0
	;call dump_row
	;pop ds

	int3

	; scroll down test
.l:
	mov ah, 0
	int 16h
	cmp ah, 0x50
	je .down
	cmp ah, 0x48
	je .up
	cmp ah, 0x4b
	je .left
	cmp ah, 0x4d
	je .right
	jmp .l
.down:
	; save cursor
	call get_cursor
	cmp dh, 25 - 1
	jae .sdown
	; move down
	add dh, 1 ; increment row
	jmp .set

.sdown:
	mov dh, 25 - 1
	mov ah, 2
	mov bh, 0
	int 10h
	; scroll all rows up (i.e. 25 rows)
	mov ax, 0x0601 ; al = lines
	mov bh, 7 ; light gray
	xor cx, cx
	mov dx, 0x1850 ; 24 rows, 80 columns
	int 10h
	jmp .l
.up:
	; save cursor
	call get_cursor
	cmp dh, 0
	je .sup
	dec dh
	jmp .set

.sup:
	; scroll all rows up (i.e. 25 rows)
	mov ax, 0x0701 ; al = lines
	mov bh, 7 ; light gray
	xor cx, cx
	mov dx, 0x1850 ; 24 rows, 80 columns
	int 10h
	jmp .l

.left:
	call get_cursor
	cmp dl, 0
	je .wleft
	dec dl
	jmp .set
.wleft:
	mov dl, 80 - 1
	dec dh
	jns .set
	mov dh, 0
	call set_cursor
	jmp .sup
.set:
	call set_cursor
	jmp .l

.right:
	call get_cursor
	inc dl
	cmp dl, 80
	jne .set
.wright:
	mov dl, 0
	inc dh
	cmp dh, 25 - 2
	ja .sdown
	jmp .set

get_cursor:
	mov ah, 3
	mov bh, 0
	int 10h
	ret
set_cursor:
	mov ah, 2
	mov bh, 0
	int 10h
	ret

; core debug handler
; this is the most important part of the whole program it dumps the
; current processor state and allows one to invoke commands. e.g.:
; modify memory, dump memory, jump to address, dissassemble code
;
; note that flags is already pushed on the stack: so pushf ... popf are
; not necessary.
dbg:
	pushad
	push ds
	push es

	; figure out EIP
	; FIXME figure out cs
	pushfd
	push eax
	xor eax, eax
	mov ds, ax
	mov es, ax
	push bx
	mov bx, sp
	; EIP is just IP in real mode
	mov ax, word [bx + 46]
	; upper half is zero (see line xor eax, eax)
	mov dword [eip_old], eax
	mov ax, word [bx + 48]
	mov word [cs_old], ax
	pop bx
	; check if debug handler is already running
	mov al, byte [dbg_state]
	and al, 1
	jz .s
	mov si, str_dbg_loop
	jmp hcf
.s:
	; acknowledge debug handler
	or al, 1
	mov byte [dbg_state], al
	; restore registers for dumping
	pop eax
	popfd

	pop es
	pop ds

	call _dump

	; finish debug handler
	mov al, byte [dbg_state]
	and al, 0xfe
	mov byte [dbg_state], al

	; dump first row where cs:ip points to
	push ds

	mov ax, word [cs_old]
	mov ds, ax
	mov si, word [eip_old]
	call dump_row

	pop ds

	; FIXME write custom keyboard driver
	; wait for key press
	;mov ah, 0
	;int 16h

	popad

	iretw
; generic panic method
hcf:
	; just to make sure we have a proper environment
	cli
	jmp 0:.reset
.reset:
	xor ax, ax
	mov ss, ax
	mov sp, STACK_ADDR
	; enable the user to use CTRL+ALT+DEL
	sti
	; print message and die
	call puts
.hang:
	hlt
	jmp .hang

dump_row:
	; convert ds:si to flat address
	xor eax, eax
	mov ax, ds
	shl eax, byte 4
	add ax, si
	jnc .s
	add eax, 0x10000
.s:
	; save for dumping flat address
	push eax

	; fetch row
	xor bx, bx
	mov es, bx
	mov di, row_buf
	mov cx, 16
	cld
.l0:
	lodsb
	stosb
	loop .l0

	; restore flat address
	pop eax
	; dump flat address

	mov ds, bx
	call putint

	; dump row
	mov cx, 16
	mov si, row_buf
.l1:
	push si
	mov al, ' '
	call putc
	pop si
	cld
	lodsb
	push si
	call putbyte
	pop si
	loop .l1
	mov si, str_lf
	call puts

	ret

str_text:
	db 'EAX=%X EBX=%X ECX=%X EDX=%X CS=%H DS=%H ES=%H', 0xd, 0xa
	db 'ESI=%X EDI=%X EBP=%X ESP=%X FS=%H GS=%H SS=%H', 0xd, 0xa, 0
str_text2:
	db 'EIP=%X [%s]'
str_lf:
	db 0xd, 0xa, 0

str_flags1:
	db 'VR?NPLODITSZ?A?P1C', 0
str_flags0:
	db '--0---------0-0-!-', 0

str_dbg_loop:
	db 'panic: loop', 0xd, 0xa, 0

	times MON_SIZE - 2 - ($ - $$) db 0
mon_sig:
	dw MON_SIG

; old EIP for dumping processor state
eip_old:
	dd 0xcafebabe
cs_old:
	dw 0xdead
sp_old:
	dw 0
dbg_state:
	db 0
; flags scratch buffer
str_flags:
	db '                  ', 0
row_buf:
	times 16 db 0
