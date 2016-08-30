#include <stddef.h>
#include <stdint.h>
#include <limits.h>
#include "io.h"
#include "uart.h"
#include "stdio.h"
#include "string.h"
#include "time.h"

uint64_t systime_get(void);

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
	uint32_t tlow, thigh;
	uint64_t time;
	time = systime_get();
	thigh = time >> 32LU;
	tlow = time & 0xffffffffLU;
	printf("time=%x%x\n", (unsigned)thigh, (unsigned)tlow);
	puts("waiting for 3000ms...");
	busydelay(3000 * 1000);
	puts("done waiting");
}
