; boxed bios calls for buggy bios'es
kint:
; modify int number if bp is different
	cmp bp, .int
	je .flush
	push ax
	mov ax, bp
	mov [.int], al
	pop ax
	je .flush
; flush pipeline
.flush:
; save everything
	pushad
%ifndef BIOS_TRASHF
	pushfd
%endif
	push ds
	push es
	push fs
	push gs
	mov bp, [kintbp]
	db 0xcd
.int:
	db 0
	pop gs
	pop fs
	pop es
	pop ds
; store results
	mov [.tmp], sp
	mov sp, [kintsp]
	pushad
	pushfd
	push ds
; revert state
	mov sp, [.tmp]
%ifndef BIOS_TRASHF
	popfd
%else
	sti
%endif
	popad
	ret
.tmp:
	dw 0
kintsp:
	dw BIOS_TMP_SP
kintbp:
	dw 0
