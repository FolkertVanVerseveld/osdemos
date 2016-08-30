#include "stdio.h"
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

int printf(const char *restrict format, ...)
{
	const char *ptr;
	unsigned n = 0;
	unsigned long long num;
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
				num = va_arg(args, unsigned);
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
				arg = va_arg(args, int);
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
			default:
				putchar(*ptr);
				++n;
				break;
		}
	}
	va_end(args);
	return n;
}
