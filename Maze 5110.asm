; ----------------------------------------------------------------------------
;
;	Maze maker for TEC SPI2C board with Nokia 5110 LCD
;
;	Designed to compile for the TEC-1 or SC-1 as the target machine
;
;	Assemble with TASM using the command line options -80 -g0
;
;	Copyright (C) 2022, Craig Hart. Distributed under the GPLv3 license
;
;	https://github.com/1971Merlin/SPI2C
;
; ----------------------------------------------------------------------------



; ----------------------------------------------------------------------------
; Our display buffer is an array of 504 bytes (84*48)/8 = 504 with each bit
; representing one pixel.
; byte 0 is the top left of the disply, bit 0 = the pixel at 0,0. bit 1 =
; the pixel at 0,1, bit 2 = pixel at 0,2, etc. i.e. each byte is a vertical
; column of 8 pixels. 84 bytes to a 'row' 8 pixels high, 6 rows.
;
; Our maze symbols are 8x8, meaning 6 rows of 10 symbols, with 4 pixels left
; over not used at the edge. This is simply convenient mathematically and
; makes our code easier. We could do other size symbols but this would be
; more difficult because a single symbol could overlap two bytes, meaning the
; code would need to be more complex in terms of manipulating the buffer.
; ----------------------------------------------------------------------------


; ----------------------------------------------------------------------------
; conditional defines - set the target machine platform
; ----------------------------------------------------------------------------


; using spi2c's onboard 74ls138 IO ports
spiport	.equ 42h

; start address for SC-1 code. change to 0900h for TEC-1
	.org 2000h


; ----------------------------------------------------------------------------
; hardware initialization code starts here
; ----------------------------------------------------------------------------

; reset spi bus to idle state
	ld c,spiport	; reset CS = 1
	ld a,0ffh	; Raise CS
	out (c),a


; write init to the 5110 display

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


	ld hl,0			; start at top of screen
	ld (buffptr),hl


; first clear buffer to all zeros

	ld bc,503		; n-1
	ld hl,buffa
	ld de,buffa
	inc de
	ld (hl),0		; zero fill
	ldir


; ----------------------------------------------------------------------------
; main program loop
; ----------------------------------------------------------------------------


mainloop:

; write buffer to display
; setup LCD

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

; Send pixels to 5110 display from buffer a
	ld bc,504
	ld hl,buffa

fillcd:	ld a,(HL)
	ld e,a
	ld d,08h
	call spi_wr

	inc hl
	dec bc

	ld a,b
	or c
	jr nz, fillcd



disloop:
	ld hl,(buffptr)			; copy a maze symbol to buffer
	ld bc,buffa
	add hl,bc
	push hl
	pop de

	call getrandom			; pick a random symbol
	and 1				; bitmask it odd/even decides
	jr z,charb

chara:	ld hl,mazea
	jr mcopy

charb:	ld hl,mazeb

mcopy:	ld bc,0008			; copy new symbol to buffer
	ldir


cont:	ld hl,(buffptr)			; move up one character space
	ld bc,0008
	add hl,bc
	ld (buffptr),hl



; bounds checking bottom of screen
bot:	ld de,500
	ld hl,(buffptr)
	or a
	sbc hl,de
	jr nc, eop			; end of buffer?
	jp eolchk

eop:	call scroll			; if so,scroll the buffer

	ld hl,420
	ld (buffptr),hl			; and jump back to start of row 6

	jp mainloop



; bounds checking end of row

eolchk:	ld hl,(buffptr)
	or a
	ld de,80
	sbc hl,de
	jr z, eol

	ld hl,(buffptr)
	or a
	ld de,164
	sbc hl,de
	jr z, eol

	ld hl,(buffptr)
	or a
	ld de,248
	sbc hl,de
	jr z, eol

	ld hl,(buffptr)
	or a
	ld de,332
	sbc hl,de
	jr z, eol

	ld hl,(buffptr)
	or a
	ld de,416
	sbc hl,de
	jr z, eol


	jp mainloop				; move on, not end of row



eol:	ld hl,(buffptr)			; add 4 if end of line 8*10=80 pixels
	ld bc,0004
	add hl,bc
	ld (buffptr),hl


	jp mainloop


; ----------------------------------------------------------------------------
; Generate a random number 0<=255 return it in A register
; ----------------------------------------------------------------------------

getrandom:
	push hl
	push de
	ld hl,(rndData)
	ld a,r
	ld d,a
	ld e,(hl)
	add hl,de
	add a,l
	xor h
	ld (rndData),hl
	pop de
	pop hl
	ret


; ----------------------------------------------------------------------------
; Scroll the display buffer
; ----------------------------------------------------------------------------

scroll:	push bc
	push de
	push hl


	ld hl,buffa+84			; 84 bytes per 'line'
	ld de,buffa
	ld bc,84*5			; 5 'lines'
	ldir


	ld bc,83			; one line -1 due pre-seed
	ld hl,buffa+420
	ld de,buffa+420
	inc de
	ld (hl),0			; zero fill line 6
	ldir


	pop hl
	pop de
	pop bc

	ret


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
;	data, variables, etc.
; ----------------------------------------------------------------------------

buffa	.ds 504		; (84*48 pixels)/8 pixels per byte

buffptr	.dw 0

rndData	.dw 0


mazea	.db 01h
	.db 02h
	.db 04h
	.db 08h
	.db 10h
	.db 20h
	.db 40h
	.db 80h

mazeb	.db 80h
	.db 40h
	.db 20h
	.db 10h
	.db 08h
	.db 04h
	.db 02h
	.db 01h


; ----------------------------------------------------------------------------
; end of our code and data, end of program. goodbye!
; ----------------------------------------------------------------------------

	.end
