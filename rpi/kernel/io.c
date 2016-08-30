#include "io.h"

enum {
	GPIO_BASE = 0x20200000,
	GPFSEL0   = (GPIO_BASE + 0x00),
	GPFSEL1   = (GPIO_BASE + 0x04),
	GPFSEL2   = (GPIO_BASE + 0x08),
	GPFSEL3   = (GPIO_BASE + 0x0c),
	GPFSEL4   = (GPIO_BASE + 0x10),
	GPFSEL5   = (GPIO_BASE + 0x14),
	GPSET0    = (GPIO_BASE + 0x1c),
	GPSET1    = (GPIO_BASE + 0x20),
	GPCLR0    = (GPIO_BASE + 0x28),
	GPCLR1    = (GPIO_BASE + 0x2c),
	GPLEV0    = (GPIO_BASE + 0x34),
	GPLEV1    = (GPIO_BASE + 0x38),
	GPEDS0    = (GPIO_BASE + 0x40),
	GPEDS1    = (GPIO_BASE + 0x44),
	GPREN0    = (GPIO_BASE + 0x4c),
	GPREN1    = (GPIO_BASE + 0x50),
	GPFEN0    = (GPIO_BASE + 0x58),
	GPFEN1    = (GPIO_BASE + 0x5c),
	GPHEN0    = (GPIO_BASE + 0x64),
	GPHEN1    = (GPIO_BASE + 0x68),
	GPLEN0    = (GPIO_BASE + 0x70),
	GPLEN1    = (GPIO_BASE + 0x74),
	GPAREN0   = (GPIO_BASE + 0x7c),
	GPAREN1   = (GPIO_BASE + 0x80),
	GPAFEN0   = (GPIO_BASE + 0x88),
	GPAFEN1   = (GPIO_BASE + 0x8c),
	GPPUD     = (GPIO_BASE + 0x94),
	GPPUDCLK0 = (GPIO_BASE + 0x98),
	GPPUDCLK1 = (GPIO_BASE + 0x9c),
};

void gpio_led_on(void)
{
	mmio_write(GPFSEL1, 1<<18);
	mmio_write(GPCLR0 , 1<<16);
}

void gpio_led_off(void)
{
	mmio_write(GPFSEL1, 1<<18);
	mmio_write(GPSET0 , 1<<16);
}
