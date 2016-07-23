/* NOTE assumes little endian byte order */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "fat.h"

#define MBR_SIZE 512

static FILE *file = NULL;

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
	size_t n;
	char mbr[MBR_SIZE];
	struct bpb *bpb;
	struct fat12 *e12;
	struct fat32 *e32;
} fs;

static int mbr_read(struct vfat *this, FILE *file)
{
	int ret = 1;
	size_t n = fread(this->mbr, 1, MBR_SIZE, file);
	if (n < sizeof(struct bpb)) {
		fputs("bad vfat volume\n", stderr);
		goto fail;
	}
	this->n = n;
	this->bpb = (struct bpb*)this->mbr;
	ret = 0;
fail:
	return ret;
}

static void cleanup(void)
{
	if (file) {
		fclose(file);
		file = NULL;
	}
}

static void bpb_stat(struct bpb *this)
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
		oem,
		this->sec,
		this->clsec,
		this->sres,
		this->nfat,
		this->ndir,
		this->nsec,
		this->mdb,
		this->sfat,
		this->strack,
		this->nhead,
		this->nhidden,
		this->nlarge
	);
}

int main(int argc, char **argv)
{
	int ret = 1;
	atexit(cleanup);
	if (argc != 2) {
		fprintf(stderr, "usage: %s file\n", argc > 0 ? argv[0] : "bpb");
		goto fail;
	}
	file = fopen(argv[1], "rb");
	if (!file) {
		perror(argv[1]);
		goto fail;
	}
	if (mbr_read(&fs, file))
		goto fail;
	struct bpb *bpb = fs.bpb;
	bpb_stat(bpb);
	if (fs.n < MBR_SIZE)
		goto end;
	fs.e12 = (struct fat12*)(fs.mbr + sizeof(struct bpb));
	fs.e32 = (struct fat32*)(fs.mbr + sizeof(struct bpb));
	char label[12], sysid[9], label2[12], sysid2[9];
	strncpy(label, fs.e12->label, 12);
	strncpy(sysid, fs.e12->sysid, 9);
	label[11] = sysid[8] = '\0';
	strncpy(label2, fs.e32->label, 12);
	strncpy(sysid2, fs.e32->sysid, 9);
	label2[11] = sysid2[8] = '\0';
	uint32_t nsec, sfat, ndir, data, ndata, nclus;
	uint16_t fati;
	nsec = bpb->nsec ? bpb->nsec : bpb->nlarge;
	sfat = bpb->sfat ? bpb->sfat : fs.e32->sfat;
	ndir = ((bpb->ndir * 32) + (bpb->sec - 1)) / bpb->sec;
	data = bpb->sres + (bpb->nfat * sfat) + ndir;
	fati = bpb->sres;
	ndata = nsec - (bpb->sres + (bpb->nfat * sfat) + ndir);
	nclus = ndata / bpb->clsec;
	unsigned fstype = FS_FATE;
	if (nclus < 4085)
		fstype = FS_FAT12;
	else if (nclus < 65525)
		fstype = FS_FAT16;
	else if (nclus < 268435445)
		fstype = FS_FAT32;
	if (fstype == FS_FAT12 || fstype == FS_FAT16)
		printf(
			"drive number         : %hhu\n"
			"windows nt flags     : %02hhX\n"
			"signature            : %02hhX\n"
			"volume serial ID     : %08X\n"
			"volume label         : %s\n"
			"system identifier    : %s\n"
			"boot record signature: %04hX\n",
			fs.e12->drive,
			fs.e12->nt,
			fs.e12->sig,
			fs.e12->serial,
			label, sysid,
			fs.e12->bsig
		);
	else
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
			fs.e32->sfat,
			fs.e32->opt,
			fs.e32->ver,
			fs.e32->rootno,
			fs.e32->fsino,
			fs.e32->fsckno,
			fs.e32->drive,
			fs.e32->nt, fs.e32->sig,
			fs.e32->serial,
			label2, sysid2,
			fs.e32->bsig
		);
	printf(
		"disk geometry:\n"
		"total sectors   : %u\n"
		"fat size        : %u\n"
		"root dir sectors: %u\n"
		"data start      : %u\n"
		"fat start       : %hu\n"
		"data sectors    : %u\n"
		"cluster count   : %u\n",
		nsec, sfat, ndir, data, fati, ndata, nclus
	);
	const char *type = fstbl[fstype];
	printf("fs type: %s\n", type);
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
end:
	ret = 0;
fail:
	cleanup();
	return ret;
}
