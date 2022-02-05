; -----------------------------------------------------------------------------------------------
;
;	Test code for TEC SPI2C board and MAX7219
;
;	Uses a MAX7219 8-digit, 7-segment display; Duinotech XC-3714 or equivilant
;
;	Assemble with TASM using the command line options -80 -g0
;
;	Copyright (C) 2022, Craig Hart. Distributed under the GPLv3 license
;
;	https://github.com/1971Merlin/SPI2C
;
; -----------------------------------------------------------------------------------------------



ioport	.equ 42h	; IO port our SPI "controller" lives on; 42h for SC-1 using the onboard 74HC138

	.org 2000h	; Start of code inRAM; 2000h for SC-1 or 0900 for TEC




; Initialize the SPI bus to an idle state; CS = 1, data and cLK = 0

start:	ld c,ioport
	ld a,0fch
	out (c),a
	call ldelay	; pause to let display chip and SPI bus settle



; fill our display buffer in memory with some initial values - 00h to 15h

	ld a,00h
	ld b,10h
	ld hl,dbuf
fil:	ld (hl),a
	inc hl
	inc a
	dec b
	jr nz,fil



; configure MAX7219 registers

	ld de,09ffh	; Register 0x09 -- select decode mode enabled [enables display values 0123456789-EHLP and space; bit 7 = decimal point on]
	call wr
	ld de,0a0fh	; Register 0x0A -- select max intensity of 0fh
	call wr
	ld de,0b07h	; Register 0x0B --  enable digits 7-0 to be actively scanned
	call wr
	ld de,0c01h	; Register 0x0C -- enable normal operation (bit 0-1, normal operation; bit 0=0,shutdown mode)
	call wr
	ld de,0f00h	; Register 0x0F -- disable display test
	call wr



; start of main loop

cycle:	ld hl,dbuf	; send the first 8 bytes of the display buffer to the SPI device
	ld d,8
out:	ld e,(hl)
	call wr

	inc hl
	dec d
	jr nz, out


; pause so we see something on MAX7219's displays

	call ldelay


; rotate the display buffer contents to the left

	ld hl,dbuf	; HL = Source memory address = start of buffer +1
	ld a,(hl)	; backup 1st byte
	inc hl		; and load into HL

	ld de,dbuf	; DE = Destination memory address = start of buffer
	ld bc,000fh	; loop 15 times

	ldir		;  copy the byte at (HL) to (DE), bc times. Increment HL and DE after each byte is copied

	ld (de),a	; drop in our first byte that we backed up, into the last display buffer location, which DE now points to


	jp cycle	; and loop infinately



; Routinte to transmit one byte to the SPI bus
;
; D = desired MAX7219 register to select
; E = byte to write to the rgister selected
;
;
; an SPI bus transaction consists of 16 bits clocked out to the SPI device each time CLK goes high (whilst CS is low) - the bit to be transmitted is the state of the MOSI bit
;
;

wr:	push af
	push bc
	push de

	ld c,ioport	; our I2C controller
	ld b,8		; 8 bits


nbit:	ld a,0f8h	; Lower CS (and zero out bits 0 and 1 of A, ready for the following steps)
	rlc d		; load next bit (from D register) into CF
	adc a,a		; load CF into A register, bit 0 - this sets the desired MOSI state
	out (c),a	; sede our data onto the SPI bus - we have not raised CLK yet so this gives time for the data to stabilise
	set 1,a		; set CLK High
	out (c),a
	ld a,00h	; set cLK low
	out (c),a
	dec b		; loop 8 times = 8 bits
	jr nz, nbit


; at this point we have selected the desired registr, now send the desired data

	ld b,8		; another 8 bits to send

nbit2:	ld a,0f8h	; same as before, but this time output contents of e register
	rlc e
	adc a,a
	out (c),a
	set 1,a
	out (c),a
	ld a,00h
	out (c),a
	dec b
	jr nz, nbit2


	ld a,0fch	; raise CS
	out (c),a
;	call delay	; short


	pop de
	pop bc
	pop af
	ret

; General purpose delay loop

ldelay:	push af
	push de
	ld de,0c000h

linner:	dec de
	ld a,d
	or e
	jr nz, linner

	pop de
	pop af
	ret


; end of code, now comes our data region

dbuf	.block 16		; reserve our 16 bytes of memory for the display buffer


	.end
