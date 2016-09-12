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
%define PUTS_CCHR
kprintf:
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
	je .kputX
	cmp al, 'H'
	je .kputH
	cmp al, 'S'
	je .kputS
	cmp al, 'B'
	je .kputB
	cmp al, 'C'
	je .kputC
	cmp al, 'c'
	je .kputc
	cmp al, 's'
	je .kputs
; just print char
.def:
; if newline
	cmp al, 0xa
	jne .char
; print newline
	push ax
	mov al, 0xd
	call kputchar
	pop ax
.char:
	call kputchar
	jmp .floop
.kputX:
	mov eax, [bp]
	call kputint
	add bp, 4
	jmp .floop
.kputH:
	mov ax, [bp]
	call kputshort
	add bp, 2
	jmp .floop
.kputS:
	mov ax, [bp]
	call kputbyte
	add bp, 2
	jmp .floop
.kputB:
	mov ax, [bp]
	call kputbyte
	inc bp
	jmp .floop
.kputc:
	mov ax, [bp]
	call kputchar
	add bp, 2
	jmp .floop
.kputC:
	mov ax, [bp]
	call kputchar
	inc bp
	jmp .floop
.kputs:
	push si
	mov si, [bp]
	push bp
	call kputs
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
%include "puthex.s"
%include "puts.s"
