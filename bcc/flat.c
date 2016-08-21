int main();
void ksyscall();
char *test;

int main()
{
	ksyscall(0, test);
	return 0;
}

void ksyscall(nr)
int nr;
{
	void (*func)();
	func = 0x602;
	func();
}

char *test = "whoah";
