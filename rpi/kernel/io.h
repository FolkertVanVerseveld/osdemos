#ifndef IO_H
#define IO_H

#include <stdint.h>

static inline void mmio_write(uint32_t reg, uint32_t data)
{
	*(volatile uint32_t*)reg = data;
}

static inline uint32_t mmio_read(uint32_t reg)
{
	return *(volatile uint32_t*)reg;
}

void gpio_led_on(void);
void gpio_led_off(void);

#endif
