#include <stddef.h>
#include <stdint.h>
#include <limits.h>
#include "io.h"
#include "uart.h"
#include "stdio.h"
#include "string.h"

void kernel_main(uint32_t r0, uint32_t r1, uint32_t atags)
{
	(void)r0;
	(void)r1;
	(void)atags;

	uart_init();
	printf(
		"r0=%x,r1=%x,atags=%x\n",
		(unsigned)r0,
		(unsigned)r1,
		(unsigned)atags
	);
}
