%define STAGE0_MAIN sinit
%define DRIVE_SECTORS 1

%define CMOS_ADDR 0x580

%include "cmos.inc"

%include "bootenv.s"
die:
	hlt
	jmp die
sinit:
	jmp stage1
	times 510 - ($ - $$) db 0
	dw 0xaa55
putc:
	mov ah, 0xe
	int 10h
	ret
_putsloop:
	mov ah, 0xe
	int 10h
puts:
	cld
	lodsb
	cmp al, 0
	jne _putsloop
	ret
stage1:
	call cpu386
	jc .1
	mov si, str_cpu_old
	call puts
	jmp die
.1:
	mov si, str_cmos
	call puts
	call cmoscpy
	mov si, str_done
	call puts
	jmp die
cpu386:
	mov ax, sp
	push sp
	pop bx
	cmp ax, bx
	jne .no386
	stc
	ret
.no386:
	clc
	ret
cmoscpy:
	cli
	mov cx, 128
	mov di, CMOS_ADDR
	mov al, 0
.regloop:
	out 0x70, al
	in al, 0x71
	inc al
	loop .regloop
	sti
	ret
str_cmos db 'copy cmos... ', 0
str_cpu_old db 'cpu too old', 13, 10, 0
str_done db 'OK', 13, 10, 0
stage1sig:
	dw STAGE1_SIG
