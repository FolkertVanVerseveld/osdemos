kstrcmp:
	cld
	lodsb
	cmp al, [bp]
	jnz .diff
	cmp al, 0
	jz .done
	inc bp
	jmp kstrcmp
.done:
	clc
	ret
.diff:
	stc
	ret
