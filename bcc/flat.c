int main();
void putchar(ch);

int main()
{
	void (*func)();
	func = 0x602;
	func();
	return 0;
}

void putchar(ch)
int ch;
{
}
