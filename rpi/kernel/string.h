#ifndef STRING_H
#define STRING_H

#include <stddef.h>

char *strchr(const char *str, int ch);
size_t strlen(const char *str);
void *memcpy(void *restrict dest, const void *restrict src, size_t count);
void *memmove(void *restrict dest, const void *restrict src, size_t count);

#endif
