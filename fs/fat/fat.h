#ifndef FS_FAT_H
#define FS_FAT_H

#include <stdint.h>

#define FS_FATE 0
#define FS_FAT12 1
#define FS_FAT16 2
#define FS_FAT32 3

static const char *fstbl[] = {
	[FS_FATE ] = "ExFAT",
	[FS_FAT12] = "FAT12",
	[FS_FAT16] = "FAT16",
	[FS_FAT32] = "FAT32",
};

struct bpb {
	uint8_t jmp[3];
	char     oem[8];
	uint16_t sec;
	uint8_t  clsec;
	uint16_t sres;
	uint8_t  nfat;
	uint16_t ndir;
	uint16_t nsec;
	uint8_t  mdb;
	uint16_t sfat;
	uint16_t strack;
	uint16_t nhead;
	uint32_t nhidden;
	uint32_t nlarge;
} __attribute__((packed));

struct fat12 {
	uint8_t  drive;
	uint8_t  nt;
	uint8_t  sig;
	uint32_t serial;
	char     label[11];
	char     sysid[8];
	uint8_t  boot[448];
	uint16_t bsig;
} __attribute__((packed));

struct fat32 {
	uint32_t sfat;
	uint16_t opt;
	uint16_t ver;
	uint32_t rootno;
	uint16_t fsino;
	uint16_t fsckno;
	uint8_t  res[12];
	uint8_t  drive;
	uint8_t  nt;
	uint8_t  sig;
	uint32_t serial;
	char     label[11];
	char     sysid[8];
	uint8_t  boot[420];
	uint16_t bsig;
} __attribute__((packed));

#endif
