%ifndef CMOS_INC
%define CMOS_INC
; cmos mapping

struc cmos
	.rtc_sec       : resb 1
	.rtc_sec_alarm : resb 1
	.rtc_min       : resb 1
	.rtc_mint      : resb 1
	.rtc_hour      : resb 1
	.rtc_hour_alarm: resb 1
	.rtc_day_week  : resb 1
	.rtc_day_month : resb 1
	.rtc_month     : resb 1
	.rtc_year      : resb 1
	.status_a      : resb 1
	.status_b      : resb 1
	.status_c      : resb 1
	.status_d      : resb 1
	.diagnostics   : resb 1
	.haltcfg       : resb 1
	.fdd_type      : resb 1
	.sysconfig     : resb 1
	.hdd_type      : resb 1
	.peripherals   : resb 1
	.mem_base      : resw 1
	.mem_extended  : resw 1
	.hdd_ext_type0 : resb 1
	.hdd_ext_type1 : resb 1
	.c_cylinders   : resw 1
	.c_heads       : resb 1
	.c_wp_cylinders: resw 1
	.c_control     : resb 1
	.c_landzone    : resw 1
	.c_sectors     : resb 1
	.d_cylinders   : resw 1
	.d_heads       : resb 1
	.d_wp_cylinders: resw 1
	.d_control     : resb 1
	.d_landzone    : resw 1
	.d_sectors     : resb 1
	.system_state  : resb 1
	.checksum      : resw 1
	.mem_extended2 : resw 1
	.century_bcd   : resb 1
	.post_info     : resb 1
	.shadow_flags  : resw 1
	.etc           : resb 1
	.password_color: resb 1
	.password_hash : resb 6
	.checksum_ext  : resw 1
	.modelno       : resb 1
	.serials       : resb 6
	.crc           : resb 1
	.century       : resb 1
	.date_alarm    : resb 1
	.control_ext_4a: resb 1
	.control_ext_4b: resb 1
	.reserved_4C_2 : resb 0x2
	.rtc_addr_2    : resb 1
	.rtc_addr_3    : resb 1
	.ram_ext_addr  : resw 1
	.ram_ext_port  : resb 1
	.reserved_55_2b: resb 0x2b
endstruc

%endif
