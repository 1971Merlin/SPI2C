; ----------------------------------------------------------------------------
;
;	Test code for TEC SPI2C board with Nokia 5110 LCD
;
;	Designed to compile for the TEC-1 or SC-1 as the target machine
;
;	Assemble with TASM using the command line options -80 -g0
;
;	Copyright (C) 2022h, Craig Hart. Distributed under the GPLv3 license
;
;	https://github.com/1971Merlin/SPI2C
;
; ----------------------------------------------------------------------------


; uses https://www.riyas.org/2017/01/online-tool-to-convert-bitmap-to-hex-nokia-arduino.html



; ----------------------------------------------------------------------------
; conditional defines - set the target machine platform
; comment or un-commnt the following two lines to compile for target machine
; ----------------------------------------------------------------------------



; using i2cspi's onboard 74ls138 IO ports
spiport	.equ	42h

; start address for SC-1 code
	.org 2000h



; ----------------------------------------------------------------------------
; hardware initialization code starts here
; ----------------------------------------------------------------------------

; reset spi bus to idle state
	ld c,spiport	; reset CS = 1
	ld a,0ffh	; Raise CS
	out (c),a


; ----------------------------------------------------------------------------
; main program loop
; ----------------------------------------------------------------------------

loop:


; write init

	ld e,21h		; complex mode
	ld d,00h
	call spi_wr

	ld e,0b9h		; set vOP
	ld d,00h
	call spi_wr

	ld e,04h		; temp coeficcient
	ld d,00h
	call spi_wr

	ld e,14h		; lcd bias
	ld d,00h
	call spi_wr

	ld e,20h		; simple mode
	ld d,00h
	call spi_wr

	ld e,40h		; Y = 0
	ld d,00h
	call spi_wr

	ld e,80h		; X = 0
	ld d,00h
	call spi_wr

	ld e,0ch		; normal mode
	ld d,00h
	call spi_wr


; write data
	ld bc,504
	ld hl,ddata

fill:	ld a,(HL)
	ld e,a
	ld d,08h
	call spi_wr

	inc hl
	dec bc

	ld a,b
	or c
	jr nz, fill

	halt



; ----------------------------------------------------------------------------
; write COMMAND to the SPI bus
;
; d = command/data 00 = commandh, 08 = data
; e = data byte
; ----------------------------------------------------------------------------

spi_wr:
	push af
	push bc
	push de

	ld c,spiport
	ld b,8		; 8 BITS

nbit2:	ld a,0e4h	; chip select,command low
	add a,d		; add in the command/data register
	bit 7,e
	jr z, no
	set 0,a

no:	out (c),a
	set 1,a		; set CLK
	out (c),a
	res 1,a		; clear CLK
	out (c),a

	rlc e		; next bit

	djnz nbit2

	ld a,0f4h	; raise CS
	out (c),a

	pop de
	pop bc
	pop af
	ret



; ----------------------------------------------------------------------------
;	datah, variables, etc.
; ----------------------------------------------------------------------------

ddata:

	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 020h
	.db 03ch
	.db 03ch
	.db 03ch
	.db 0fch
	.db 0fch
	.db 0fch
	.db 0fch
	.db 0fch
	.db 0fch
	.db 0fch
	.db 0fch
	.db 0fch
	.db 0fch
	.db 0fch
	.db 03ch
	.db 03ch
	.db 03ch
	.db 03ch
	.db 03ch
	.db 01ch
	.db 0e0h
	.db 0f0h
	.db 0f8h
	.db 0f8h
	.db 0fch
	.db 0fch
	.db 0fch
	.db 0fch
	.db 0fch
	.db 0fch
	.db 03ch
	.db 03ch
	.db 03ch
	.db 03ch
	.db 03ch
	.db 03ch
	.db 03ch
	.db 03ch
	.db 03ch
	.db 03ch
	.db 03ch
	.db 03ch
	.db 03ch
	.db 03ch
	.db 03ch
	.db 01ch
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 080h
	.db 0e0h
	.db 0f0h
	.db 0f8h
	.db 0f8h
	.db 0fch
	.db 0fch
	.db 0fch
	.db 0fch
	.db 0fch
	.db 0fch
	.db 03ch
	.db 03ch
	.db 03ch
	.db 03ch
	.db 03ch
	.db 03ch
	.db 03ch
	.db 03ch
	.db 03ch
	.db 03ch
	.db 03ch
	.db 03ch
	.db 03ch
	.db 03ch
	.db 03ch
	.db 00ch
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 0c0h
	.db 0f8h
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 03fh
	.db 007h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 0c0h
	.db 0f8h
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 07fh
	.db 07fh
	.db 07ch
	.db 07ch
	.db 078h
	.db 07ch
	.db 078h
	.db 07ch
	.db 07ch
	.db 07ch
	.db 038h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 0c0h
	.db 0fch
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 03fh
	.db 007h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 0e0h
	.db 0feh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 00fh
	.db 001h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 0e0h
	.db 0feh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0f9h
	.db 0f8h
	.db 0f8h
	.db 0f8h
	.db 0f8h
	.db 0f8h
	.db 0f8h
	.db 0f8h
	.db 0f8h
	.db 0f8h
	.db 0f8h
	.db 0f8h
	.db 0f8h
	.db 0f8h
	.db 018h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 080h
	.db 0f0h
	.db 0feh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0f9h
	.db 0f8h
	.db 0f8h
	.db 0f8h
	.db 0f8h
	.db 0f8h
	.db 0f8h
	.db 0f8h
	.db 0f8h
	.db 0f8h
	.db 0f8h
	.db 0f8h
	.db 0f8h
	.db 078h
	.db 008h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 0c0h
	.db 0f8h
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 087h
	.db 080h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 001h
	.db 007h
	.db 007h
	.db 00fh
	.db 00fh
	.db 00fh
	.db 00fh
	.db 00fh
	.db 00fh
	.db 00fh
	.db 00fh
	.db 00fh
	.db 00fh
	.db 00fh
	.db 00fh
	.db 00fh
	.db 00fh
	.db 00fh
	.db 00fh
	.db 00fh
	.db 00fh
	.db 00fh
	.db 00fh
	.db 00fh
	.db 007h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 003h
	.db 007h
	.db 00fh
	.db 00fh
	.db 00fh
	.db 00fh
	.db 00fh
	.db 00fh
	.db 00fh
	.db 00fh
	.db 00fh
	.db 00fh
	.db 00fh
	.db 00fh
	.db 00fh
	.db 00fh
	.db 00fh
	.db 00fh
	.db 00fh
	.db 00fh
	.db 00fh
	.db 00fh
	.db 00fh
	.db 00fh
	.db 007h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 080h
	.db 0f0h
	.db 0feh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 0ffh
	.db 07fh
	.db 00fh
	.db 001h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 007h
	.db 00fh
	.db 01fh
	.db 01fh
	.db 01fh
	.db 01fh
	.db 01fh
	.db 01fh
	.db 01fh
	.db 01fh
	.db 01fh
	.db 01fh
	.db 01fh
	.db 01fh
	.db 01fh
	.db 01fh
	.db 01fh
	.db 01fh
	.db 01fh
	.db 01fh
	.db 01fh
	.db 01fh
	.db 01fh
	.db 01fh
	.db 01fh
	.db 01fh
	.db 01fh
	.db 01fh
	.db 01fh
	.db 01fh
	.db 01fh
	.db 01fh
	.db 01fh
	.db 01fh
	.db 003h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h
	.db 000h









; ----------------------------------------------------------------------------
; end of our code and data, end of program. goodbye!
; ----------------------------------------------------------------------------

	.end
