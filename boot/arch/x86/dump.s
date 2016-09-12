; minimalistic bootable program
; that prints all 8086 registers
; in the following format:
; CS DS ES SS FLAGS IP DI SI BP SP BX DX CX AX
BITS 16
ORG 0x7c00
boot:
	cli
	xor ax, ax
	mov ds, ax
	mov ss, ax
	mov sp, 0x9c00
	sti
	call main
	call main
	jmp short halt
main:
	pushf
	pusha
	pusha
; get and push ip
	mov bp, sp
	mov ax, [bp+34]
	push ax
	pushf
	push ss
	push es
	push ds
	push cs
	mov cx, 6
dumps:
	pop ax
	mov word [hreg], ax
	push cx
	call putrv
	pop cx
	loop dumps
; print pusha regs
	mov cx, 8
dumpr:
	pop ax
	mov word [hreg], ax
	push cx
	call putrv
	pop cx
	loop dumpr
	mov si, nl
	call puts
; restore all
	popa
	popf
	ret
halt:
	hlt
	nop
	jmp short halt
putrv:
	mov di, hout
	mov ax, [hreg]
	mov cx, 4
puthex:
	rol ax, 4
	mov bx, ax
	and bx, 0x0f
	mov bh, '0'
	add bh, bl
	cmp bh, '9'
	ja short putha
puthg:
	mov [di], bh
	inc di
	dec cx
	jnz puthex
	mov si, hout
	call puts
	ret
putha:
	add bh, 7
	jmp short puthg
puts:
	mov ah, 0Eh
putchar:
	lodsb
	cmp al, 0
	je ret0
	int 10h
	jmp putchar
ret0:
	ret
reg	db 0, 'H', 0, 'L ', 0
nl	db 13, 10, 0
hout	db '0000 ', 0
hreg	dw 0
	times 510 - ($ - $$) db 0
	dw 0xAA55

