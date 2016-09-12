BITS 16
ORG 0
SEGMENT_MAIN equ 0x7C0
boot:
	mov ax, SEGMENT_MAIN
	mov ds, ax
	add ax, 64
	cli
	mov ss, ax
	mov sp, 1024
	sti
	mov ah, 0
	mov al, 3
	int 10h
	mov ah, 2
	mov dh, 0
	mov dl, 0
	mov bh, 0
	int 10h
; event loop
main:
	mov si, yay
	call puts
	call swait
	mov si, gay
	call puts
	call swait
	jmp boot
swait:
	mov ah, 86h
	mov dx, 8480h
	mov cx, 1Eh
	int 15h
	ret
; text
	yay db 'yay', 0
	gay db 'gay', 0
puts:
	mov ah, 0Eh
.putchar:
	lodsb
	cmp al, 0
	je .putln
	int 10h
	jmp .putchar
.putln:
	mov ah, 3
	mov bh, 0
	int 10h
	mov dl, 0
	inc dh
	mov ah, 2
	int 10h
	ret

	times 510 - ($ - $$) db 0
	dw 0xAA55
