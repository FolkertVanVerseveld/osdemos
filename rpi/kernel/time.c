#include "time.h"

#include <stdint.h>

uint64_t systime_get(void);

void busydelay(unsigned micros)
{
	uint64_t target, now = systime_get();
	target = now + micros;
	do
		now = systime_get();
	while (now < target);
}
