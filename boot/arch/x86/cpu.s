kcpuis386:
	clc
%if 0
	mov ax, sp
	push sp
	pop bx
	cmp ax, bx
	jne .kcpuno2
%else
	mov cx, 0x121
	shl ch, cl
	je .kcpuno2
%endif
	stc
.kcpuno2:
%ifndef CPU386_NORET
	ret
%endif
