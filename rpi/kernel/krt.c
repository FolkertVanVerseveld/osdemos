#include "krt.h"
#include "stdio.h"

void panic(const char *str)
{
	printf("panic: %s\n", str);
halt:
	asm volatile("wfe");
	goto halt;
}
