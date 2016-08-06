%ifndef MMAP_INC
%define MMAP_INC

%define MMAP_BOOTENV_ADDR 0x500
%define MMAP_BOOTAPI_ADDR 0x600
%define MMAP_BOOTAPI_SIG_ADDR (0x1000-2)
%define MMAP_STACK_ADDR 0x4000
%define MMAP_KERNEL_ADDR MMAP_STACK_ADDR

; memory map for simple bootloader
; lower  -  upper description
; 0x0000 - 0x04ff unusable (idt etc.)
; 0x0500 - 0x05ff boot environment setup
; 0x0600 - 0x???? various
; 0x???? - 0x4000 stack
; 0x4000 - 0x???? bcc program
; 0x7c00 - 0x7dff initial program loader (reclaimable)
; 0xf000 - 0x???? bios reserved

%endif
