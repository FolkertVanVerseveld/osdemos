#ifndef FB_H
#define FB_H

struct fbinfo {
	unsigned width, height;
	unsigned vwidth, vheight;
	unsigned pitch, bits;
	int x, y;
	void *ptr;
	unsigned size;
} __attribute__((aligned(16)));

void fb_stat(void);
void *fb_init(unsigned width, unsigned height, unsigned bits);

#endif
