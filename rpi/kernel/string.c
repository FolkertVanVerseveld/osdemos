#include "string.h"

char *strchr(const char *str, int ch)
{
	for (; *str; ++str)
		if (*str == ch)
			return (char*)str;
	return NULL;
}

char *strrchr(const char *str, int ch)
{
	const char *ptr;
	size_t n = strlen(str);
	for (ptr = str + n; n; --n)
		if (*--ptr == ch)
			return (char*)ptr;
	return NULL;
}

void *memchr(const void *ptr, int ch, size_t n)
{
	for (const unsigned char *p = ptr; n; --n, ++p)
		if (*p == ch)
			return (void*)p;
	return NULL;
}

void *memrchr(const void *ptr, int ch, size_t n)
{
	for (const unsigned char *p = (const unsigned char*)ptr + n; n; --n, --p)
		if (*p == ch)
			return (void*)p;
	return NULL;
}

size_t strlen(const char *str)
{
	size_t ret;
	for (ret = 0; str[ret]; ++ret)
		;
	return ret;
}

void *memcpy(void *restrict dest, const void *restrict src, size_t n)
{
	unsigned char *d = dest;
	const unsigned char *s = src;
	for (; n; --n)
		*d++ = *s++;
	return dest;
}

void *memmove(void *restrict dest, const void *restrict src, size_t n)
{
	unsigned char *d = dest;
	const unsigned char *s = src;
	if (d <= s)
		memcpy(dest, src, n);
	else
		for (s += n - 1, d += n - 1; n; --n)
			*d-- = *s--;
	return dest;
}
