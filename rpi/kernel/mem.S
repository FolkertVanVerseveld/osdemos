.section ".text"
.globl mem_sync
mem_sync:
	mcr 15, 0, ip, c7, c5 , 0 @ invalidate I cache
	mcr 15, 0, ip, c7, c5 , 6 @ invalidate BTB
	mcr 15, 0, ip, c7, c10, 4 @ drain write buffer
	mcr 15, 0, ip, c7, c5 , 4 @ prefetch flush
	mov pc, lr
