#include <stddef.h>
#include <stdint.h>
#include <limits.h>
#include "fb.h"
#include "io.h"
#include "uart.h"
#include "stdio.h"
#include "string.h"

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
	struct fbinfo *fb = fb_init(1024, 768, 24);
	if (!fb) {
		puts("fb_init failed");
		goto end;
	}
	printf("width=%u, height=%u, bits=%u\n", fb->width, fb->height, fb->bits);
	printf("ptr=%u, size=%u\n", (unsigned)fb->ptr, fb->size);
end:
	puts("leaving kernel_main");
}
