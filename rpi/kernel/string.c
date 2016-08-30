#include "string.h"

size_t strlen(const char *str)
{
	size_t ret;
	for (ret = 0; str[ret]; ++ret)
		;
	return ret;
}
