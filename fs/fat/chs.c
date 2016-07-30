#include <stdio.h>
#include <stdlib.h>

int main(int argc, char **argv)
{
	unsigned secsz, nhead, ncyl, nsec;
	if (argc != 5) {
		fprintf(
			stderr,
			"usage: %s sectorsize cylinders heads sectors\n",
			argc > 0 ? argv[0] : "chs"
		);
		return 1;
	}
	secsz = atoi(argv[1]);
	ncyl  = atoi(argv[2]);
	nhead = atoi(argv[3]);
	nsec  = atoi(argv[4]);
	if (!secsz) {
		fprintf(stderr, "bad sector size: %s\n", argv[1]);
		return 1;
	}
	if (!ncyl) {
		fprintf(stderr, "bad cylinder count: %s\n", argv[2]);
		return 1;
	}
	if (!nhead) {
		fprintf(stderr, "bad head count: %s\n", argv[3]);
		return 1;
	}
	if (!nsec) {
		fprintf(stderr, "bad sector count: %s\n", argv[4]);
		return 1;
	}
	printf("%u %u %u %u\n", secsz, nhead, ncyl, nsec);
	unsigned long offset = 0;
	unsigned head, cyl, sec;
	for (unsigned lba = 0; lba < 4096; ++lba) {
		cyl  = lba / (nhead * nsec);
		head = (lba / nsec) % nhead;
		sec  = lba % nsec + 1;
		if (cyl > ncyl)
			break;
		printf(
			"%4u %3u %2u %3u %lu\n",
			lba, cyl, head, sec, offset
		);
		offset += secsz;
	}
	return 0;
}
