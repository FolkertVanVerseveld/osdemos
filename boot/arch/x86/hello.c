#asm
	db 0x58
	db 0x54
#endasm
void kputc();
void kputs();
void kputlf();

char *tty_hex = "0123456789ABCDEF";

void main()
{
	register int y, x, ch;
	kputc(' ');
	kputc(' ');
	for (x = 0; x < 16; ++x) {
		kputc(tty_hex[x]);
		kputc(' ');
	}
	kputlf();
	for (ch = y = 0; y < 16; ++y) {
		kputc(tty_hex[y]);
		kputc(' ');
		for (x = 0; x < 16; ++x, ++ch) {
			if (ch == 7 || ch == 8 || ch == '\t' || ch == '\r' || ch == '\n')
				kputc(' ');
			else
				kputc(ch);
			kputc(' ');
		}
		kputlf();
	}
	while (1) {
#asm
	hlt
#endasm
	}
}

void kputc(ch)
register int ch;
{
#asm
#if !__FIRST_ARG_IN_AX__
	mov bx, sp
	mov al, [bx+2]
#endif
	db 0xb4
	db 0xe
	pusha
	pushf
	db 0xcd
	db 0x10
	popf
	popa
#endasm
}

void kputlf()
{
	kputc(0xd);
	kputc(0xa);
}

void kputs(str)
register char *str;
{
	while (*str) {
		if (*str == '\n')
			kputlf();
		else
			kputc(*str);
		++str;
	}
}
