BITS 16
ORG 0
SEGMENT_MAIN equ 0x7C0
boot:
	mov ax, SEGMENT_MAIN
	mov ds, ax
	mov ax, SEGMENT_MAIN
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
; print your shit here
	mov si, yay
	call puts
	call getkey
	mov si, gay
	call puts
	call getkey
	mov si, dope
	call puts
	call getkey
; reboot
	jmp boot
getkey:
	mov ah, 010h
	int 16h
	ret
; put your text here
	yay db 'yay', 0
	gay db 'gay', 0
	dope db 'press any key to reboot', 0
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
