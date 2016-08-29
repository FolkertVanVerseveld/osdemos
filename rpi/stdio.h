#ifndef STDIO_H
#define STDIO_H

#define EOF (-1)

void putchar(int ch);
int puts(const char *str);
int printf(const char *restrict format, ...) __attribute__((__format__(__printf__, 1, 2)));

#endif
