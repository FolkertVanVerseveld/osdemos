.section ".text.boot"
.globl _start
.set LOADER_ADDR, 0x8000

// Entry point for the kernel.
// r0 -> 0x00000000
// r1 -> 0x00000C42
// r2 -> 0x00000100 - start of ATAGS
// preserve these registers as argument for kernel_main
_start:
	// Setup the stack.
	mov sp, #LOADER_ADDR

	// Clear out bss.
	ldr r4, =__bss_start
	ldr r9, =__bss_end
	// use four at a time for speeding up process
	mov r5, #0
	mov r6, #0
	mov r7, #0
	mov r8, #0
	b       2f

1:
	// store multiple at r4.
	stmia r4!, {r5-r8}

2:
	// If we are still below bss_end, loop.
	cmp r4, r9
	blo 1b

	// Call kernel_main
	ldr r3, =kernel_main
	blx r3
	// unexpected return safeguard
halt:
	wfe
	b halt
