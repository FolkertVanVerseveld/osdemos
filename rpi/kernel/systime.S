.section ".text"

.globl systime_get
systime_get:
	ldr r0, =0x20003000
	ldrd r0, r1, [r0, #4]
	mov pc, lr
