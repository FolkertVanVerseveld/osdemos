#ifndef STRING_H
#define STRING_H

#include <stddef.h>

char *strchr(const char *str, int ch);
char *strrchr(const char *str, int ch);
size_t strlen(const char *str);
void *memchr(const void *ptr, int ch, size_t count);
void *memrchr(const void *ptr, int ch, size_t count);
void *memcpy(void *restrict dest, const void *restrict src, size_t count);
void *memmove(void *restrict dest, const void *restrict src, size_t count);

#endif
