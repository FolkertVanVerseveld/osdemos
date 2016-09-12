%ifndef TTY_INC
%define TTY_INC
%define ttyputc ttyctl 0xe
%define ttyinit call ttyrt
%macro ttyctl 0-1
	%if %0 == 1
		mov ah, %1
	%endif
	%ifdef TTY_USE_VMEM
		call ttybios
	%elifdef BIOS
		bioscall 10h
	%else
		int 10h
	%endif
%endmacro
%macro ttybpctl 0-1
	%if %0 == 1
		mov ah, %1
	%endif
	%ifdef TTY_USE_VMEM
		call ttybios
	%elifdef BIOS
		push bp
		bioscall 10h
		pop bp
	%else
		int 10h
	%endif
%endmacro
%endif
