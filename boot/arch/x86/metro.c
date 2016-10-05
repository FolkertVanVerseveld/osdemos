/* my custom boot signature */
#asm
	db 0x58
	db 0x54
#endasm
void putchar();
void kputs();
void kwait();
void puts();
void putlf();
void setcursxy();
int getcurs();
int ttygetc();

#define getcursx() (getcurs()&0xff)
#define getcursy() ((getcurs()>>8)&0xff)

#define sleep(s) kwait((s)*16)

void bsod();

char *msdos_copy = "Microsoft(R) MS-DOS(R)  Version 8\n" "(C)Copyright Microsoft Corp 1981-1987\n";
char *msdos_deftime = "\n \333 \337\337\333 \334 \333\337\333 \337\337\333\n" " \333 \333\337\337 \334 \333 \333   \333\n" " \337 \337\337\337   \337\337\337   \337 AM\n" " 31 OCTOBER 1987\n";

char *ps1 = "A>";

#define CMD_BUFSZ 20
char cmd_buf[CMD_BUFSZ];

#define CMD_HALT "bsod"
#define CMD_HELP "help"
#define CMD_METRO "metro"
#define CMD_VERSION "version"

void cmd_main();

#define kgetc() (ttygetc()&0xff)

void main()
{
	kputs(msdos_copy);
	kputs(msdos_deftime);
	cmd_main();
#asm
here:
	hlt
	jmp here
#endasm
}

int strcmp(s1, s2)
char *s1, *s2;
{
	while (*s1 == *s2++)
		if (*s1++ == '\0') return 0;
	return (*(unsigned char*)s1 < *(unsigned char*)s2) ? -1 : 1;
}

#define streq(a,b) (strcmp(a,b)==0)

void metro();

void cmd_version()
{
	int i;
	puts("please wait...");
	sleep(1);
	puts("contacting NSA");
	kwait(8);
	puts("uploading all your privacy data");
	kwait(2);
	for (i = 0; i < 40; ++i) {
		putchar('.');
		kwait(1);
	}
	putlf();
	puts("say goodbye to your privacy :D");
	sleep(1);
	puts("enabling keylogger...");
	sleep(2);
	bsod();
}

void cmd_help()
{
	puts("help     Show teh best cmds eva");
	puts("bsod     Crash hard and reboot");
	puts("metro    Open our awesome metro :D");
	puts("version  Show OS diagnostics");
}

void cmd_parse()
{
	putlf();
	if (streq(cmd_buf, CMD_HELP)) {
		cmd_help();
		return;
	}
	if (streq(cmd_buf, CMD_METRO)) {
		metro();
		return;
	}
	if (streq(cmd_buf, CMD_VERSION)) {
		cmd_version();
	}
	if (streq(cmd_buf, CMD_HALT)) {
		bsod();
	}
	kputs("Bad command or file name!\nLearn how to type dumbass!");
}

void cmd_erasechar()
{
	int x, y;
	x = getcursx();
	y = getcursy();
	if (x == 0) {
		x = 79;
		if (y > 0) --y;
	} else
		--x;
	setcursxy(x,y);
	putchar(' ');
	setcursxy(x,y);
}

void cmd_main()
{
	int cmd_len = 0, ch;
	kputs(ps1);
	while (1) {
		ch = kgetc();
		if (ch == '\r') {
			cmd_parse();
			cmd_buf[cmd_len = 0] = '\0';
			putlf();
			kputs(ps1);
			continue;
		}
		if (cmd_len >= CMD_BUFSZ)
			continue;
		if (ch == '\b') {
			if (cmd_len <= 0)
				continue;
			cmd_buf[--cmd_len] = '\0';
			cmd_erasechar();
			continue;
		}
		if (ch < ' ' || ch > '~')
			continue;
		cmd_buf[cmd_len++] = ch;
		cmd_buf[cmd_len] = '\0';
		putchar(ch);
	}
}

void putchar(ch)
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
	int 0x10
	popf
	popa
#endasm
}

int getcurs()
{
#asm
	push bp
	pushf
	db 0xb4
	db 3
	xor bx, bx
	int 0x10
	mov ax, dx
	popf
	pop bp
#endasm
}

void setcursxy(x,y)
unsigned short x, y;
{
#asm
	push bp
#if !__FIRST_ARG_IN_AX__
	mov bp, sp
	mov dl, [bp+4]
	mov dh, [bp+6]
#else
	mov dl, al
	mov dh, bl
#endif
	db 0xb4
	db 2
	xor bx, bx
	int 0x10
	pop bp
#endasm
}

void putlf()
{
	putchar(0xd);
	putchar(0xa);
}

void puts(str)
register char *str;
{
	kputs(str);
	putlf();
}

void kputs(str)
register char *str;
{
	while (*str) {
		if (*str == '\n')
			putlf();
		else
			putchar(*str);
		++str;
	}
}

int ttygetc()
{
#asm
	db 0xb4
	db 0
	push sp
	push bp
	int 0x16
	pop bp
	pop sp
#endasm
}

void kwait(times)
unsigned times;
{
	while (times) {
#asm
		sti
		hlt
#endasm
		--times;
	}
}

void test()
{
	unsigned short *mem = 0xb8000;
	setcursxy(0,0);
	*mem = 0x1f20;
	mem += 2;
	*mem = 0x1f31;
	sleep(1);
	*((unsigned short*)0xb8000)=0x1f20;
}

void metro()
{
#define USERSZ 16
#define PASSSZ 8
	int pos, ch;
	pos = 0;
	kputs("Loading...");
	putlf();
	sleep(1);
	kputs("USER NAME>");
	while ((ch = kgetc()) != '\r') {
		if (ch == '\b' && pos > 0) {
			--pos;
			cmd_erasechar();
		}
		if (pos >= USERSZ || ch < ' ' || ch > '~')
			continue;
		++pos;
		putchar(ch);
	}
	putlf();
	kputs("PASSWORD>");
	pos = 0;
	while ((ch = kgetc()) != '\r') {
		if (ch == '\b' && pos > 0) {
			--pos;
			cmd_erasechar();
		}
		if (pos >= PASSSZ || ch < ' ' || ch > '~')
			continue;
		++pos;
		putchar('*');
	}
	putlf();
	sleep(1);
	bsod();
#undef PASSSZ
#undef USERSZ
}

void bsod()
{
	setcursxy(0, 0);
#asm
	pusha
	db 0xb8
	db 0
	db 0xb8
	mov es, ax
	db 0xb8
	db 0x20
	db 0x1f
	db 0xb9
	db 0xd0
	db 7
	cld
bsodloop:
	stosw
	loop bsodloop
	popa
#endasm
	puts("A problem has been detected and Windows has been shut down to prevent damage\n" "to your computer");
	putlf();
	puts("The problem seems to be caused by the following file: NTOSKRNL.EXE");
	puts("CRASH_RANDOMLY_WIT_INSTAKILL");
	putlf();
	puts("If this is the first time you've seen this Stop error screen,\n" "restart your computer. If this screen appears again, follow\n" "these steps:");
	putlf();
	puts("Check to make sure any new hardware or software is properly installed.\n" "If this is a new installation, ask your hardware or software manufacturer\n" "for any Windows update you might need.");
	putlf();
	puts("If problems continue, disable or remove any newly installed hardware\n" "or software. Disable BIOS memory options such as caching or shadowing.\n" "If you need to use Safe Mode to remove or disable components, restart\n" "your computer, press F8 to select Advanced Startup Options, and then\n" "select Safe Mode.");
	putlf();
	puts("Technical information:");
	putlf();
	puts("*** STOP: 0xDEADDEAD (0x1BADB002,0xCAFEBABE,0xFEEDFEED,0xBAD00BAD)");
	putlf();
	kputs("***  BITFUCK.SYS - Address DA0D5576 base at E6DA6FFB, DateStamp 93ACC0B5");
	sleep(4);
#asm
	jmp 0xffff:0
#endasm
}
