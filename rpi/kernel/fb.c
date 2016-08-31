#include "fb.h"
#include <stddef.h>
#include <stdint.h>
#include "mem.h"
#include "io.h"
#include "stdio.h"
#include "time.h"

#define MBOX_BASE  0x2000B880
#define MBOX_EMPTY 0x40000000
#define MBOX_FULL  0x80000000

enum {
	MB0READ   = MBOX_BASE + 0x00,
	MB0PEEK   = MBOX_BASE + 0x10,
	MB0SENDER = MBOX_BASE + 0x14,
	MB0STATUS = MBOX_BASE + 0x18,
	MB0CONFIG = MBOX_BASE + 0x1c,
	MB1WRITE  = MBOX_BASE + 0x20,
	MB1PEEK   = MBOX_BASE + 0x30,
	MB1SENDER = MBOX_BASE + 0x34,
	MB1STATUS = MBOX_BASE + 0x38,
	MB1CONFIG = MBOX_BASE + 0x3c,
};

struct fbinfo fb_setup;

static inline void *arm2vc(void *p)
{
	return (void*)((uint32_t)p + 0xc0000000);
}

static inline void *vc2arm(void *p)
{
	return (void*)((uint32_t)p - 0xc0000000);
}

uint32_t mbox_read(unsigned char channel)
{
	for (;;) {
		do
			mem_sync();
		while (mmio_read(MB0STATUS) & MBOX_EMPTY);
		mem_sync();
		uint32_t data = mmio_read(MB0READ);
		printf("read from %X: %X\n", MB0READ, (unsigned)data);
		if (channel == (data & 0xf))
			return data >> 4;
	}
}

void mbox_write(unsigned char channel, uint32_t data)
{
	if ((data & 0xf) || channel > 0xf) {
		puts("internal error");
		return;
	}
	do
		mem_sync();
	while (mmio_read(MB0STATUS) & MBOX_FULL);
	mmio_write(MB1WRITE, data | channel);
	mem_sync();
	printf("written to %X: %X\n", MB1WRITE, (unsigned)data | channel);
}

struct buf {
	uint32_t size;
	uint32_t code;
	struct {
		uint32_t id;
		uint32_t valuesz;
		uint32_t valuelen;
		uint32_t value;
	} tag;
} buf __attribute__((aligned(16)));

void fb_stat(void)
{
	/*
	get firmware version
	tag: 1
	request: length: 0
	response: length: 4, value: u32: firmware version

	channel request: 8
	channel response: 9
	*/
	puts("fb_stat");
	buf.tag.id = 1;
	buf.tag.valuesz = buf.tag.valuelen = 4;
	buf.tag.value = 0;
	buf.code = 0;
	buf.size = 6 * sizeof(uint32_t);
	mbox_write(8, 0x40000000 + (uint32_t)&buf);
	unsigned result = mbox_read(9);
	// FIXME does not print anything
	// seems like channel 8 request is incorrectly setup
	printf("result = %u\n", result);
}

void *fb_init(unsigned width, unsigned height, unsigned bits)
{
	puts("fb_init");
	if (width > 4096 || height > 4096 || bits > 32)
		return NULL;
	fb_setup.width = fb_setup.vwidth = width;
	fb_setup.height = fb_setup.vheight = height;
	fb_setup.pitch = 0;
	fb_setup.bits = bits;
	fb_setup.x = fb_setup.y = 0;
	fb_setup.ptr = NULL;
	fb_setup.size = 0;
	printf(
		"fb setup:\n"
		"resolution: (%u, %u)\n"
		"virtual resolution: (%u, %u)\n"
		"bit depth: %u\n",
		fb_setup.width, fb_setup.height,
		fb_setup.vwidth, fb_setup.vheight,
		fb_setup.bits
	);
	mbox_write(1, 0x40000000 + (uint32_t)&fb_setup);
	uint32_t result = mbox_read(1);
	if (result)
		return NULL;
	return &fb_setup;
}
