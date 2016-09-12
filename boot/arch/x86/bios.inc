%ifndef BIOS
%define BIOS
%macro bioscall 1
	mov bp, %1
	call kint
%endmacro
%ifndef BIOS_TMP_SP
%define BIOS_TMP_SP (MBR_ADDR - 1024)
%endif
%macro biosgetax 0
	mov bp, [kintsp]
	sub bp, byte 4
	mov eax, [bp]
%endmacro
%macro biosgetcx 0
	mov bp, [kintsp]
	sub bp, byte 8
	mov ecx, [bp]
%endmacro
%macro biosgetdx 0
	mov bp, [kintsp]
	sub bp, byte 12
	mov edx, [bp]
%endmacro
%macro biosgetbx 0
	mov bp, [kintsp]
	sub bp, byte 16
	mov ebx, [bp]
%endmacro
%macro biosgetbxcxdx 0
	biosgetcx
	biosgetdx
	biosgetbx
%endmacro
%endif
