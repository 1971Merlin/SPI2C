; -----------------------------------------------------------------------------
;
; PS/2 mouse support on SPI2C
;
; written for the Soutern Cross Monitor version 1.8 or later
;
; outputs mouse data to the serial terminal

; -----------------------------------------------------------------------------


#include "scm18_include.asm"


	.org	2000h

	ld c,SERINI
	rst 30h

	call i2c_init			; setup port

krst:	ld d,0f4h			; set leds state
	call i2c_ATtx


mloop:

	ld hl,mbuff
	call i2c_ATrx
	ld (hl),a
	inc hl
	call i2c_ATrx
	ld (hl),a
	inc hl
	call i2c_ATrx
	ld (hl),a


	ld hl,mbuff
	ld a,(hl)
	ld hl,dispbuf
	ld c,BYTASC
	rst 30h

	ld hl,mbuff+1
	ld a,(hl)
	ld hl,dispbuf+3
	ld c,BYTASC
	rst 30h

	ld hl,mbuff+2
	ld a,(hl)
	ld hl,dispbuf+6
	ld c,BYTASC
	rst 30h


	ld hl,dispbuf
	ld c,SNDMSG
	rst 30h

	jr mloop



mbuff	.db 0,0,0

dispbuf	.db "00 00 00",13,10,0


#include "spi2c_library.asm"



	.end

