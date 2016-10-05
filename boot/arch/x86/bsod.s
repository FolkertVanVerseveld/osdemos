BITS 16
ORG 0x7C00

%define vmem(x,y) (0xb8000+(y)*160+(x)*2)

mbr:
	jmp 0000:start
start:
	cli
	xor ax, ax
	mov ds, ax
	mov ss, ax
	mov sp, mbr
	sti
	mov di, ax
	mov ax, 0xb800
	mov es, ax
; backcol=blue
; forecol=white
	mov ax, 0x1F20
	mov cx, 2000
	cld
.scrloop:
	stosw
	loop .scrloop
	mov dh, 0
reset:
	mov ax, 0
	push dx
	int 13h
	pop dx
	jc reset
read:
	mov ax, 0x7e0
	mov es, ax
	xor bx, bx
	mov ax, 0x0202
	mov cx, 0x0002
	push dx
	int 13h
	pop dx
	jc read
; setup print shit
	mov ax, 0xb800
	mov es, ax
	xor di, di
	mov ah, 0x1F
; okay now it's time to
; print the infamous BSOD
	mov cx, (str0 - strs) / 2
	mov bx, strs
.strloop:
	mov si, [bx]
	inc bx
	inc bx
	call puts
	loop .strloop
hang:
	hlt
	jmp hang
putchar:
	mov ah, 0x1F
	stosw
puts:
	mov ah, 0
	lodsb
	test ax, ax
	jnz putchar
putln:
; increment row
	mov dl, 160
	add di, dx
; adjust col
	mov ax, di
	mov dl, byte 160
	div dl
	shr ax, byte 8
	sub di, ax
	ret
; signature
	times 510 - ($ - $$) db 0
	dw 0AA55h
strs:
	dw str0, str1, strl, str2, str3, strl, str4, str5, str6, strl, str7, str8, str9, strl, stra, strb, strc, strd, stre, strl, strf, strl, str10, strl, str11
str0:
	db 'A problem has been detected and Windows has been shut down to prevent damage'
strl:
	db 0
str1:
	db 'to your computer.', 0
str2:
	db 'The problem seems to be caused by the following file: APPLE.SYS', 0
str3:
	db 'CRASH_RANDOMLY_WIT_INSTAKILL', 0
str4:
	db 'If this is the first time you', 0x27, 've seen this Stop error screen,', 0
str5:
	db 'restart your computer. If this screen appears again, follow', 0
str6:
	db 'these steps:', 0
str7:
	db 'Check to make sure any new hardware or software is properly installed.', 0
str8:
	db 'If this is a new installation, ask your hardware or software manufacturer', 0
str9:
	db 'for any Windows update you might need.', 0
stra:
	db 'If problems continue, disable or remove any newly installed hardware', 0
strb:
	db 'or software. Disable BIOS memory options such as caching or shadowing.', 0
strc:
	db 'If you need to use Safe Mode to remove or disable components, restart', 0
strd:
	db 'your computer, press F8 to select Advanced Startup Options, and then', 0
stre:
	db 'select Safe Mode.', 0
strf:
	db 'Technical information:', 0
str10:
	db '*** STOP: 0xDEADDEAD (0x1BADB002,0xCAFEBABE,0xFEEDFEED,0xBAD00BAD)', 0
str11:
	db '***  BITFUCK.SYS - Address DA0D5576 base at E6DA6FFB, DateStamp 93ACC0B5', 0

