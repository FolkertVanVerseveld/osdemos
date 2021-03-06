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

; NOTE make sure this is after `mon_sig', because
;      it will be overwritten while loading part2!
%define DBG_ADDR_TMP 0x8200
%define DBG_ADDR     0x0800

; number of retries before giving up
%define DRIVE_TRIES 5
%define DRIVE_SECTORS 2

%define MON_SIZE (512 + DRIVE_SECTORS * 512)
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

	jmp part2

dump_state:
	push eax
	push ds

	; save eip
	xor ax, ax
	mov ds, ax
	mov ax, word [esp + 6]
	mov dword [eip_old], eax

	pop ds
	pop eax

; dump_state processor state
; all registers are preserved
_dump_state:
	push ds
	push es

	; prepare all arguments for dumping
	pushfd
	pushad
	; make it easier to grab eflags later (see line 173)
	pushfd

_dump_state2:
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

	; grab eflags (see line 144)
	pop edx

	call dump_eip_flags

	popad
	popfd

	pop es
	pop ds

	ret

dump_eip_flags:
	mov bx, str_flags0
	mov si, str_flags1
	; eflags has 18 fields (including preserved bits)
	mov cx, 18

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

	; increment both ptrs
	stosb
	inc bx

	loop .l
	jmp .done
.z:
	pop bx

	mov al, [bx]

	; increment both ptrs
	stosb
	inc bx

	loop .l

.done:
	; zero terminate
	mov al, 0
	stosb

	push str_flags
	push dword [eip_old]

	mov si, str_text2
	call printf

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
	call puts
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
	pusha
	mov ah, 0xe
	int 10h
	popa
	ret
_puts_loop:
	call putc
puts:
	cld
	lodsb
	cmp al, 0
	jne _puts_loop
	ret
put_key:
	mov ah, 0xe
	int 10h
	mov al, ' '
	int 10h
	ret

; I/O data
drive:
	db 0
tries:
	db DRIVE_TRIES
	times 0x200 - 2 - ($ - $$) db 0
	dw 0xaa55

part2:
	; dump initial program state

	; dump twice to check nothing gets thrashed
	; (except EIP is different of course)
	;int3 ; db 0xcc
	;int3 ; db 0xcc

	; dump_state initial program state
	; save eip
	xor eax, eax
	mov ax, PROG_ADDR
	mov dword [eip_old], eax

	; figure out stack
	mov bp, word [sp_old]
	mov bx, DBG_ADDR_TMP / 16
	mov ds, bx

	; debug stuff layout:
	;  0 gs
	;  2 fs
	;  4 es
	;  6 ds
	;  8 cs
	; 10 edi
	; 14 esi
	; 18 ebp
	; 22 esp
	; 26 ebx
	; 30 edx
	; 34 ecx
	; 38 eax
	; 42 eflags
	xor ax, ax
	push ax                ; ss = 0, because we trashed it in `reset'
	mov  ax,  [ds:bp + 0]
	push ax                ; push gs
	mov  ax,  [ds:bp + 2]
	push ax                ; push fs
	mov  eax, [ds:bp + 22]
	add  eax, byte 4
	push eax               ; push esp
	mov  eax, [ds:bp + 18]
	push eax               ; push ebp
	mov  eax, [ds:bp + 10]
	push eax               ; push edi
	mov  eax, [ds:bp + 14]
	push eax               ; push esi
	mov  ax,  [ds:bp + 4]
	push ax                ; push es
	mov  ax,  [ds:bp + 6]
	push ax                ; push ds
	mov  ax,  [ds:bp + 8]
	push ax                ; push cs
	mov  eax, [ds:bp + 30]
	push eax               ; push edx
	mov  eax, [ds:bp + 34]
	push eax               ; push ecx
	mov  eax, [ds:bp + 26]
	push eax               ; push ebx
	mov  eax, [ds:bp + 38]
	push eax               ; push eax

	mov edx, [ds:bp + 42]  ; grab eflags

	xor ax, ax
	mov ds, ax
	mov es, ax
	mov si, str_text
	mov dword [flags_old], edx ; save eflags
	call printf

	; restore eflags
	xor ax, ax
	mov ds, ax
	mov edx, dword [flags_old]
	call dump_eip_flags

	int3
; `jmp mon' would be sufficient, but just in case it
; may save the user's butt when corrupting the stack
.loop:
	call mon
	jmp .loop

; core debug handler
; this is the most important part of the whole program. it dumps the
; current processor state.
; it assumes it is called from int3 (db 0xcc)
; we still have to implement the following commands.:
; modify memory, dump memory, jump to address, dissassemble code
; continue...
;
; note that flags is already pushed on the stack: so pushf ... popf are
; not necessary.
dbg:
	pushad
	push ds
	push es

	; figure out EIP
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
	; figure out cs
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

	call _dump_state

	push ds
	push es

	xor ax, ax
	mov ds, ax
	mov es, ax

	; finish debug handler
	mov al, byte [dbg_state]
	and al, 0xfe
	mov byte [dbg_state], al

	; dump first row where cs:ip points to

	mov ax, word [cs_old]
	mov si, word [ds:eip_old]
	mov ds, ax
	call dump_state_row

	; start monitor and wait for continue
	call mon
dbg_ret:

	; restore stuff
	pop es
	pop ds
	popad

	iretw

mon:
	; FIXME write custom keyboard driver
	; FIXME interrupts are disabled, so int 16h doesn't
	; work on real hardware (except for a super bios?)
	xor ax, ax
	mov ds, ax
	mov es, ax
	call putln

.input:
	; wait for key press
	mov ah, 0
	int 16h
	cmp al, 'm'
	jnz $ + 5
	call dump
	cmp al, 'g'
	jz go

	; check if debug handler is running
	pop bx
	push bx
	cmp bx, dbg_ret
	jne .input

	; these commands are only available if invoked via int3
	cmp al, 'c'
	je .done

	jmp mon
.done:
	call putc
	jmp putln

dump:
	; get address
	call read_word
	pop ax
	mov word [dump_seg], ax
	push ax
	mov al, ':'
	call read_word
	pop ax
	mov word [dump_off], ax
	push ax
	; stack: si ds
dump2:
	pop si
	pop ds
	call dump_row

	; wait for input, unknown keys will terminate the command
	xor ax, ax
	mov ds, ax
	mov ah, 0
	int 16h
	; just print it for now
	; down: ah = 0x50, al = 0x00
	; up  : ah = 0x48, al = 0x00
	;call putshort
	cmp ah, 0x50
	je .down
	cmp ah, 0x48
	je .up

	ret

.down:
	mov ax, word [dump_off]
	add ax, byte 16
	mov word [dump_off], ax
	call putln
	jmp .next
.up:
	mov ax, word [dump_off]
	sub ax, byte 16
	mov word [dump_off], ax
	; fetch cursor location
	mov ah, 3
	mov bh, 0
	int 10h
	; scroll up if on first row
	cmp dh, 0
	jnz .noscroll

	mov ax, 0x0701
	mov bh, 7
	xor cx, cx
	mov dh, 24
	mov dl, 79
	int 10h
	jmp .next

.noscroll:
	; update cursor
	dec dh
	mov ah, 2
	mov bh, 0
	int 10h

.next:
	; fetch new row
	mov ax, word [dump_seg]
	push ax
	mov ax, word [dump_off]
	push ax
	jmp dump2

dump_off:
	dd 0xdead
dump_seg:
	dd 0xbeef

dump_row:
	; reposition cursor
	push ds
	push si

	; grab cursor line
	mov ah, 3
	mov bh, 0
	int 10h
	; update cursor line
	mov dl, 2
	mov ah, 2
	int 10h

	pop si
	pop ds

	; (re)print address
	push si
	push ds

	; push arguments
	push si
	push ds
	xor ax, ax
	mov ds, ax
	mov si, str_flat
	call printf

	pop ds
	pop si

	; dump row
	mov cx, 16
.loop:
	push cx

	; print separator
	push ds
	push si
	mov al, ' '
	call putc
	pop si
	pop ds

	; fetch byte
	cld
	lodsb

	; dump byte
	push ds
	push si
	call putbyte
	pop si
	pop ds

	pop cx
	loop .loop

	ret

; jump to specified address. e.g.: g 07c0:0000
; restarts the program
go:
	call put_key
	call get_word
	mov word [es:.lbl + 3], ax
	mov al, ':'
	call put_key
	call get_word
	mov word [es:.lbl + 1], ax
	; trash pipeline
	jmp .lbl
.lbl:
	jmp 0:start

; user input routines

; equivalent as if we have inlined the following:
;   call put_key
;   call get_word
;   push ax
read_word:
	call put_key
	call get_word
	pop bx
	push ax
	jmp bx

; text input routines
get_word:
	call get_byte
	mov ah, al
	push ax
	call get_byte
	pop bx
	mov ah, bh
	ret
get_byte:
	call get_nibble
	shl ax, byte 4
	push ax
	call get_nibble
	pop bx
	add al, bl
	ret
; ask user input for one xdigit
; and also print it on screen
get_nibble:
	call get_xdigit
	push ax
	mov al, bl
	mov ah, 0xe
	int 10h
	pop ax
	ret
get_xdigit:
	mov ah, 0
	int 16h
	mov bl, al
	cmp al, ' '
	jne .1
	jmp mon ;jmp 0:reset
.1:
	cmp al, '0'
	jb get_xdigit
	cmp al, '9'
	jg .2
	sub al, '0'
	ret
.2:
	cmp al, 'a'
	jb get_xdigit
	cmp al, 'f'
	ja get_xdigit
	sub al, 'a' - 10
	ret

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

dump_state_row:
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
	push si

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
	pop si
	pop eax
	; dump flat address
	push si
	push ds
	mov si, str_flat
	mov ds, bx
	call printf

	; dump row and ascii stuff
	mov cx, 16
	mov si, row_buf

	push si
.l1:
	mov al, ' '
	call putc
	cld
	lodsb
	call putbyte
	loop .l1

	mov al, ' '
	call putc

	pop si
	; print ascii stuff
	mov cx, 16
.l2:
	cld
	lodsb
	cmp al, 0xd
	ja .p
	mov al, '?'
.p:
	push si
	push cx
	call putc
	pop cx
	pop si
	loop .l2

	call putln

	ret

putln:
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

str_flat:
	db '%H:%H', 0

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
flags_old:
	dd 0
; flags scratch buffer
str_flags:
	db '                  ', 0
row_buf:
	times 16 db 0
