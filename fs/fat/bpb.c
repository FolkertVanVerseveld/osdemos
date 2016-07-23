/* NOTE assumes little endian byte order */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>
#include "fat.h"

#define MBR_SIZE 512
#define SECTORSZ 512

struct md {
	uint8_t val;
	uint8_t type;
	uint16_t sec;
	uint16_t head;
	uint16_t diag;
	const char *cap;
};

static const struct md mdtbl[] = {
	{0xf0, 0, 36, 2, 350, "2.88MB"},
	{0xf0, 0, 18, 2, 350, "1.44MB"},
	{0xf8, 1,  0, 0,   0, "?"     },
	{0xf9, 0,  9, 2, 350, "720KB" },
	{0xf9, 0, 15, 2, 525, "1.2MB" },
	{0xfa, 1,  0, 0,   0, "?"     },
	{0xfb, 1,  0, 0,   0, "?"     },
	{0xfc, 0,  9, 1, 525, "180KB" },
	{0xfd, 0,  8, 1, 525, "360KB" },
	{0xfe, 0,  8, 1, 525, "160KB" },
	{0xff, 0,  8, 2, 525, "320KB" },
};

#define MDTBLSZ (sizeof(mdtbl)/(sizeof(mdtbl[0])))

static struct vfat {
	int fd;
	struct stat st;
	/* data vars */
	void *map;
	struct bpb *bpb;
	struct fat12 *e12;
	struct fat32 *e32;
	/* geometry */
	uint32_t nsec, sfat, ndir;
	uint32_t data, ndata, nclus;
	uint16_t fati;
	uint32_t root;
	unsigned fstype;
	unsigned md_i;
} fs = {
	.fd = -1,
	.map = MAP_FAILED
};

static int mbr_open(struct vfat *this, const char *name)
{
	int fd = -1;
	void *map = MAP_FAILED;
	fd = open(name, O_RDONLY);
	if (fd == -1 || fstat(fd, &this->st)) {
		perror(name);
		goto fail;
	}
	this->fd = fd;
	map = mmap(NULL, this->st.st_size, PROT_READ, MAP_PRIVATE, fd, 0);
	if (map == MAP_FAILED) {
		perror("mmap");
		goto fail;
	}
	this->map = map;
	return 0;
fail:
	if (fd != -1)
		close(fd);
	return 1;
}

static void mbr_close(struct vfat *this)
{
	if (this->map != MAP_FAILED) {
		munmap(this->map, this->st.st_size);
		this->map = MAP_FAILED;
	}
	if (this->fd != -1) {
		close(this->fd);
		this->fd = -1;
	}
}

static void cleanup(void)
{
	mbr_close(&fs);
}

static int mbr_read(struct vfat *this)
{
	size_t n = this->st.st_size;
	if (n < sizeof(struct bpb)) {
		fputs("bad vfat volume\n", stderr);
		return 1;
	}
	if (n < MBR_SIZE) {
		fputs("bad mbr\n", stderr);
		return 1;
	}
	char *map = this->map;
	this->bpb = this->map;
	this->e12 = (struct fat12*)(map + sizeof(struct bpb));
	this->e32 = (struct fat32*)(map + sizeof(struct bpb));
	return 0;
}

static void fat_map(struct vfat *this)
{
	const struct bpb *bpb = this->bpb;
	unsigned fstype = FS_FATE, nclus;
	this->nsec = bpb->nsec ? bpb->nsec : bpb->nlarge;
	this->sfat = bpb->sfat ? bpb->sfat : this->e32->sfat;
	this->ndir = (bpb->ndir * 32 + (bpb->sec - 1)) / bpb->sec;
	this->data = bpb->sres + (bpb->nfat * this->sfat) + this->ndir;
	this->fati = bpb->sres;
	this->ndata = this->nsec - (bpb->sres + (bpb->nfat * this->sfat) + this->ndir);
	nclus = this->ndata / bpb->clsec;
	fstype = FS_FATE;
	if (nclus < 4085)
		fstype = FS_FAT12;
	else if (nclus < 65525)
		fstype = FS_FAT16;
	else if (nclus < 268435445)
		fstype = FS_FAT32;
	this->nclus = nclus;
	this->fstype = fstype;
	this->root = fstype == FS_FAT12 || fstype == FS_FAT16 ? this->data - this->ndir : this->e32->rootno;
}

static void fat12_stat(const struct fat12 *this)
{
	char label[12], sysid[9];
	strncpy(label, this->label, 12);
	strncpy(sysid, this->sysid, 9);
	label[11] = sysid[8] = '\0';
	printf(
		"drive number         : %hhu\n"
		"windows nt flags     : %02hhX\n"
		"signature            : %02hhX\n"
		"volume serial ID     : %08X\n"
		"volume label         : %s\n"
		"system identifier    : %s\n"
		"boot record signature: %04hX\n",
		this->drive,
		this->nt,
		this->sig,
		this->serial,
		label, sysid,
		this->bsig
	);
}

static void bpb_stat(const struct bpb *this)
{
	char oem[9];
	strncpy(oem, this->oem, 9);
	oem[8] = '\0';
	if (this->jmp[0] == 0xeb)
		printf("text start: %02hhX\n", this->jmp[1]);
	else
		printf("text start: %04hX\n", (uint16_t)this->jmp[1] | (this->jmp[2] << 8));
	if (this->sec / 512 != this->clsec) {
		if (this->sec % 512)
			fprintf(stderr, "bad sector size: %hu\n", this->sec);
		else
			fprintf(stderr, "bad cluster size: %hu\n", this->clsec);
	}
	printf(
		"oem identifier       : %s\n"
		"sector size          : %hu\n"
		"cluster size         : %hhu\n"
		"reserved sectors     : %hu\n"
		"fat count            : %hhu\n"
		"directory entries    : %hu\n"
		"sector count         : %hu\n"
		"media descriptor     : %02hhX\n"
		"fat sector count     : %hu\n"
		"track sector count   : %hu\n"
		"head count           : %hu\n"
		"hidden sector count  : %u\n"
		"large sector count   : %u\n",
		oem, this->sec, this->clsec, this->sres,
		this->nfat, this->ndir, this->nsec, this->mdb,
		this->sfat, this->strack,
		this->nhead, this->nhidden, this->nlarge
	);
}

static void fat32_stat(const struct fat32 *this)
{
	char label[12], sysid[9];
	strncpy(label, fs.e32->label, 12);
	strncpy(sysid, fs.e32->sysid, 9);
	label[11] = sysid[8] = '\0';
	printf(
		"fat sector count     : %u\n"
		"flags                : %hu\n"
		"version              : %hu\n"
		"root cluster         : %u\n"
		"fat info cluster     : %hu\n"
		"backup cluster       : %hu\n"
		"reserved[12]\n"
		"drive number         : %02hhX\n"
		"windows nt flags     : %02hhX\n"
		"boot signature       : %02hhX\n"
		"volume serial ID     : %08X\n"
		"volume label         : %s\n"
		"system identifier    : %s\n"
		"boot record signature: %04hX\n",
		this->sfat, this->opt, this->ver,
		this->rootno, this->fsino, this->fsckno,
		this->drive, this->nt, this->sig,
		this->serial, label, sysid, this->bsig
	);
}

static void cluster_stat(const struct vfat *fs)
{
	uint16_t sec = fs->bpb->sec;
	for (unsigned j = 0, i = 0; ; ++i) {
		uint32_t fat_offset = i + i / 2; // * 1.5
		if (fat_offset >= SECTORSZ * fs->sfat) {
			if (j)
				putchar('\n');
			break;
		}
		uint32_t fat_sector = fs->fati + fat_offset / sec;
		// wiki uses (char*)fs->map + fat_sector * sec + fat_offset % sec,
		// but `% sec' should not be necessary
		uint16_t v = *(uint16_t*)((char*)fs->map + fat_sector * sec + fat_offset);
		if (i & 1)
			v >>= 4;
		else
			v &= 0xfff;
		printf("%03hX ", v);
		j = (j + 1) & 0xf;
		if (!j)
			putchar('\n');
	}
}

static int root_stat(const struct vfat *fs)
{
	uint32_t root = fs->root;
	char *map = (char*)fs->map + root * SECTORSZ;
	struct fat_entry *item;
	unsigned i = 0, max = 0;
	blksize_t blocks = fs->st.st_blocks;
	if (root > blocks) {
		fprintf(stderr, "bad image: blocks=%zu, root=%u\n", (size_t)blocks, root);
		return 1;
	}
	max = (fs->st.st_blocks - root) * 512 / 32;
	char *pmap;
	for (pmap = map; *pmap && i < max; pmap += 32, ++i) ;
	//printf("max: %u, entry count: %u\n", max, i);
	max = i;
	printf("root entry count: %u\ncontents:\n", max);
	char buf[64], fname[12];
	for (pmap = map, i = 0; i < max; pmap += 32, ++i) {
		item = (struct fat_entry*)pmap;
		memcpy(fname, item->name, 11);
		fname[11] = '\0';
		unsigned i, ext_ri = 11 - 3 - 1;
		while (fname[ext_ri] == ' ')
			--ext_ri;
		++ext_ri;
		fname[ext_ri  ] = fname[8];
		fname[ext_ri+1] = fname[9];
		fname[ext_ri+2] = fname[10];
		for (i = 0; i < ext_ri; ++i)
			buf[i] = fname[i];
		buf[i++] = '.';
		buf[i++] = fname[ext_ri];
		buf[i++] = fname[ext_ri+1];
		buf[i++] = fname[ext_ri+2];
		buf[i] = '\0';
		puts(buf);
	}
	return 0;
}

int main(int argc, char **argv)
{
	int ret = 1;
	atexit(cleanup);
	if (argc != 2) {
		fprintf(stderr, "usage: %s file\n", argc > 0 ? argv[0] : "bpb");
		goto fail;
	}
	if (mbr_open(&fs, argv[1]))
		goto fail;
	if (mbr_read(&fs))
		goto fail;
	struct bpb *bpb = fs.bpb;
	if (bpb->sec < MBR_SIZE) {
		fprintf(stderr, "bad sector size: %hu\n", bpb->sec);
		goto fail;
	}
	if (!bpb->clsec) {
		fprintf(stderr, "bad cluster size: %hu\n", bpb->clsec);
		goto fail;
	}
	bpb_stat(bpb);
	fat_map(&fs);
	if (fs.fstype == FS_FAT12 || fs.fstype == FS_FAT16)
		fat12_stat(fs.e12);
	else
		fat32_stat(fs.e32);
	printf(
		"disk geometry:\n"
		"total sectors   : %u\n"
		"fat size        : %u\n"
		"root dir sectors: %u\n"
		"data start      : %u\n"
		"fat start       : %hu\n"
		"data sectors    : %u\n"
		"cluster count   : %u\n"
		"root start      : %u\n",
		fs.nsec, fs.sfat, fs.ndir,
		fs.data, fs.fati, fs.ndata, fs.nclus, fs.root
	);
	printf("fs type: %s\n", fstbl[fs.fstype]);
	for (unsigned i = 0; i < MDTBLSZ; ++i) {
		const struct md *d = &mdtbl[i];
		if (bpb->mdb == d->val && bpb->nhead == d->head && bpb->strack == d->sec) {
			if (!d->type)
				printf(
					"physical format:\n"
					"%s %u.%02u-inch, %u-sided, %u-sector\n",
					d->cap, d->diag / 100, d->diag % 100,
					d->head, d->sec
				);
			else
				puts(d->val == 0xf8 ? "fixed disk" : "?");
			goto end;
		}
	}
	fputs("bad physical format descriptor\n", stderr);
	goto fail;
end:
	//cluster_stat(&fs);
	root_stat(&fs);
	ret = 0;
fail:
	cleanup();
	return ret;
}
