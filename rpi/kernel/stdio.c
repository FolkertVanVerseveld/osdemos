#include "stdio.h"
#include <stddef.h>
#include <stdarg.h>
#include <limits.h>
#include "string.h"
#include "uart.h"

static const char *HEX = "0123456789ABCDEF";
static const char *hex = "0123456789abcdef";

void putchar(int ch)
{
	uart_putc(ch);
}

int puts(const char *str)
{
	size_t len = strlen(str);
	uart_write((const unsigned char*)str, len);
	++len;
	uart_putc('\n');
	return len & INT_MAX;
}

/*
simple printf that lacks many conversion specifiers.
some of them may be added in the future in userspace,
but probably not in kernel space.
*/
int printf(const char *restrict format, ...)
{
	const char *ptr;
	unsigned n = 0;
	unsigned long long num;
	int wide;
	va_list args;
	va_start(args, format);
	for (ptr = format; *ptr; ++ptr) {
		if (*ptr != '%') {
			putchar(*ptr);
			++n;
			continue;
		}
		if (!*++ptr)
			break;
		wide = 0;
		/* note that the shortest type in va_arg is a word
		(e.g. int) so there's no need to add special cases
		for elements shorter than an (unsigned) int */
	parse_opt:
		switch (*ptr) {
			case 'X': {
				unsigned i, ch, num = va_arg(args, unsigned);
				for (i = sizeof(unsigned), n += i; i; --i) {
					ch = (num >> ((i - 1) << 3)) & 0xff;
					putchar(HEX[ch >> 4]);
					putchar(HEX[ch & 0xf]);
				}
				break;
			}
			case 'x': {
				unsigned i, ch, num = va_arg(args, unsigned);
				for (i = sizeof(unsigned), n += i; i; --i) {
					ch = (num >> ((i - 1) << 3)) & 0xff;
					putchar(hex[ch >> 4]);
					putchar(hex[ch & 0xf]);
				}
				break;
			}
			case 'u': {
				unsigned long long m;
				switch (wide) {
					case 3:
						num = va_arg(args, size_t);
						break;
					case 2:
						num = va_arg(args, unsigned long long);
						break;
					case 1:
						num = va_arg(args, unsigned long);
						break;
					default:
						num = va_arg(args, unsigned);
						break;
				}
			arg_u:
				for (m = 1; m < num; m *= 10)
					;
				while (m > 10) {
					m /= 10;
					putchar('0' + (num / m) % 10);
					++n;
				}
				putchar('0' + num % 10);
				++n;
				break;
			}
			case 'd': {
				long long arg;
				switch (wide) {
					case 3:
						/* XXX should be ssize_t, but stddef does not provide one */
						arg = va_arg(args, long signed int);
						break;
					case 2:
						arg = va_arg(args, long long);
						break;
					case 1:
						arg = va_arg(args, long);
						break;
					default:
						arg = va_arg(args, int);
						break;
				}
				if (arg < 0) {
					putchar('-');
					num = -arg;
					++n;
				} else
					num = arg;
				goto arg_u;
			}
			case 'c':
				putchar((unsigned)va_arg(args, int));
				++n;
				break;
			case 's': {
				const char *str = va_arg(args, char*);
				size_t len = strlen(str);
				n += len;
				uart_write((const unsigned char*)str, len);
				break;
			}
			case 'l':
				++wide;
				if (!*++ptr)
					goto end;
				goto parse_opt;
			case 'h':
				--wide;
				if (!*++ptr)
					goto end;
				goto parse_opt;
			case 'z':
				wide = 3;
				if (!*++ptr)
					goto end;
				goto parse_opt;
			default:
				putchar(*ptr);
				++n;
				break;
		}
	}
end:
	va_end(args);
	return n;
}
