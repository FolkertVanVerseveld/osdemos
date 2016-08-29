#include <stddef.h>
#include <stdint.h>
#include <limits.h>
#include "uart.h"
#include "stdio.h"

void kernel_main(uint32_t r0, uint32_t r1, uint32_t atags)
{
	(void)r0;
	(void)r1;
	(void)atags;

	uart_init();
	printf("Hello, %s World!\n", "kernel");
}
