ENTRY(_start)

SECTIONS
{
	/* Starts at LOADER_ADDR. */
	. = 0x8000;
	__start = .;
	__text_start = .;
	/* initial program loader and code */
	.text : {
		KEEP(*(.text.boot))
		*(.text)
	}
	. = ALIGN(4096);
	__text_end = .;

	__rodata_start = .;
	.rodata : {
		*(.rodata)
	}
	. = ALIGN(4096);
	__rodata_end = .;

	__data_start = .;
	.data : {
		*(.data)
	}
	. = ALIGN(4096);
	__data_end = .;

	__bss_start = .;
	.bss : {
		bss = .;
		*(.bss)
	}
	. = ALIGN(4096);
	__bss_end = .;
	__end = .;
}
