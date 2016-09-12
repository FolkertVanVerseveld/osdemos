%ifndef LAYOUT_INC
%define LAYOUT_INC

%define MBR_SEG 0x7c0
%define MBR_ADDR (MBR_SEG << 4)
%define MBR_SIZE 0x200
%define STAGE1_SEG (MBR_SEG + 0x20)
%define STAGE1_ADDR (STAGE1_SEG << 4)
%macro MBR_PADSIG 0
	times MBR_SIZE - 2 - ($ - $$) db 0
%endmacro
%define MBR_SIG dw 0xAA55
STAGE_SIG equ 'XT'

%endif
