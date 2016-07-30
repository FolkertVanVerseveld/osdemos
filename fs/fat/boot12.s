ORG 0x7c00
BITS 16

%define BS_STACK_ADDR 0x8000
%define FAT_IOBUF_ADDR 0x600
%define FAT_IOBUF_SEG (FAT_IOBUF_ADDR >> 4)
%define BS_STAGE1_FNAME "KERNEL  BIN"
%ifndef BS_STAGE1_ADDR
%define BS_STAGE1_ADDR 0x20000
%endif
%define BS_STAGE1_SEG (BS_STAGE1_ADDR >> 4)

%ifndef BPB_IO_TRIES
%define BPB_IO_TRIES 5
%endif

%ifndef BPB_SECTORSZ
%define BPB_SECTORSZ 512
%endif
%ifndef BPB_CLUSTERSZ
%define BPB_CLUSTERSZ 1
%endif
%ifndef BPB_ROOTRESSZ
%define BPB_ROOTRESSZ 1
%endif
%ifndef BPB_FAT_NBACKUP
%define BPB_FAT_NBACKUP 2
%endif
%ifndef BPB_NROOT
%define BPB_NROOT 224
%endif
%ifndef BPB_NSECTOR
%define BPB_NSECTOR 2880
%endif
%ifndef BPB_MDT
%define BPB_MDT 0xf0
%endif
%ifndef BPB_FAT_NSECTOR
%define BPB_FAT_NSECTOR 9
%endif
%ifndef BPB_TRACKSZ
%define BPB_TRACKSZ 18
%endif
%ifndef BPB_NHEAD
%define BPB_NHEAD 2
%endif
%ifndef BPB_SIG
%define BPB_SIG 41
%endif
%ifndef BPB_SERIAL
%define BPB_SERIAL 0
%endif

	jmp short start
	nop
%ifdef BPB_OEM
bpb_oem         db BPB_OEM
%endif
times 11 - ($ - $$) db ' '
bpb_sectorsz    dw BPB_SECTORSZ
bpb_clustersz   db BPB_CLUSTERSZ
bpb_rootressz   dw BPB_ROOTRESSZ
bpb_fat_nbackup db BPB_FAT_NBACKUP
bpb_nroot       dw BPB_NROOT
bpb_nsector     dw BPB_NSECTOR
bpb_mdt         db BPB_MDT
bpb_fat_nsector dw BPB_FAT_NSECTOR
bpb_tracksz     dw BPB_TRACKSZ
bpb_nhead       dw BPB_NHEAD
times 36 - ($ - $$) db 0
bpb_drive       db 0
bpb_nt          db 0
bpb_sig         db BPB_SIG
bpb_serial      dd BPB_SERIAL
%ifdef BPB_LABEL
bpb_label       db BPB_LABEL
%endif
times 54 - ($ - $$) db ' '
%ifdef BPB_SYSID
bpb_sysid       db BPB_SYSID
%endif
times 62 - ($ - $$) db ' '

start:
	xor ax, ax
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov sp, BS_STACK_ADDR
	mov [geom_drive], dl
	mov ah, 8
	mov dl, [geom_drive]
	int 13h
	; ignore status and try anyway
	mov [geom_type], bl
	mov ah, cl
	shr ah, byte 6
	mov al, ch
	inc ax
	mov [geom_cyl], ax
	; bpb->sec = bpb_sectorsz
	; bpb->ndir = bpb_nroot
	; this->ndir = (bpb->ndir * 32 + bpb->sec - 1) / bpb->sec
	mov cx, [bpb_sectorsz]
	mov ax, [bpb_nroot]
	mov bx, 32
	mul bx
	add ax, cx
	dec ax
	div cx
	mov [geom_nroot], ax
	; this->ndir = geom_nroot
	; this->sfat = bpb->sfat = bpb_fat_nsector
	; bpb->sres = bpb_rootressz
	; bpb->nfat = bpb_fat_nbackup
	xchg bx, ax ; ah = 0, 'cause bh = 0
	mov al, [bpb_fat_nbackup]
	mul word [bpb_fat_nsector]
	add ax, word [bpb_rootressz]
	add ax, bx
	mov [geom_data], ax
	sub ax, bx
	mov [geom_root], ax
	; this->data = bpb->sres + (bpb->nfat * this->sfat) + this->ndir = geom_data
	; this->root = this->data - this->ndir = geom_root
	mov cl, 14
	call fdc_read
; search in mem for stage 1
	mov ax, FAT_IOBUF_SEG
	mov es, ax
	mov cx, [bpb_nroot]
	mov ax, 0
	mov di, ax
.loop:
	xchg cx, dx
	cld
	mov cx, 11
	mov si, stage1name
	mov bx, di
	rep cmpsb
	je stage1_found
	xchg cx, dx
	mov di, bx
	mov bx, 32
	add di, bx
	loop .loop
	jmp die
stage1_found:
	mov bx, word [es:di+0xf]
	mov cl, [bpb_fat_nsector]
	mov ax, [bpb_rootressz]
	mov [bs_stage1_cluster], bx
	call fdc_read
	mov ax, BS_STAGE1_SEG
	mov [bpb_iobuf_seg], ax
	jmp short bs_next_cluster
	; fetch cluster from table
bs_fetch_next:
	; TODO compute magic number
	add ax, byte 30
	mov cl, 1
	call fdc_read
	add word [bpb_iobuf_seg], (BPB_CLUSTERSZ * BPB_SECTORSZ) >> 4
bs_next_cluster:
	mov ax, word [bs_stage1_cluster]
	xor dx, dx
	mov si, dx
	mov bx, 3
	mul bx
	dec bx
	div bx
	add si, ax
	mov ax, FAT_IOBUF_SEG
	mov es, ax
	es lodsw
	or dx, dx
	jz short .even
	shr ax, 4
	jmp short .next
.even:
	and ax, 0xfff
.next:
	mov word [bs_stage1_cluster], ax
	cmp ax, 0xff8
	jnae bs_fetch_next
	jmp short bs_next_stage
fdc_read:
	mov bp, BPB_IO_TRIES
.loop:
	push bp
	mov bx, [bpb_iobuf_seg]
	mov es, bx
	mov dh, 0
	shl bx, byte 2
	mov [bx], dh
	push cx
	call lba2chs
	pop ax
	mov ah, 2
	mov dl, [geom_drive]
	xor bx, bx
	stc
	int 13h
	pop bp
	jnc .good
	mov dh, [FAT_IOBUF_ADDR]
	cmp dh, 0
	jnz .good
	mov ah, 0
	mov dh, [geom_drive]
	int 13h
	dec bp
	jnz .loop
	jmp die
.good:
	ret
die:
	hlt
	jmp short die
lba2chs:
	push bx
	push ax
	mov bx, ax
	mov dx, 0
	div word [bpb_tracksz]
	add dl, byte 1
	mov cl, dl
	mov ax, bx
	mov dx, 0
	div word [bpb_tracksz]
	mov dx, 0
	div word [bpb_nhead]
	mov dh, dl
	mov ch, al
	pop ax
	pop bx
	ret
bpb_iobuf_seg dw FAT_IOBUF_SEG
bs_stage1_cluster dw 0
stage1name db BS_STAGE1_FNAME
geom_drive   db 0
geom_type    db 0
geom_cyl     dw 0
geom_nroot   dw 0
geom_data    dw 0
geom_root    dw 0

bs_next_stage:
	mov dx, [geom_drive]
	jmp BS_STAGE1_SEG:0

	times 510 - ($ - $$) db 0
	dw 0xaa55
