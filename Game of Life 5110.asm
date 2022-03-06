; ----------------------------------------------------------------------------
;
;	Game of Life for TEC SPI2C board with Nokia 5110 LCD
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


; ----------------------------------------------------------------------------
; conditional defines - set the target machine platform
; ----------------------------------------------------------------------------


#define debug

; #define random


; using spi2c's onboard 74ls138 IO ports
spiport	.equ 42h

; start address for SC-1 code. change to 0900h for TEC-1
	.org 2000h



#ifdef debug

; SC-1 7-seg ports
disscan .equ	85h
disseg	.equ	84h

#endif


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


#ifndef random

; setup our starting point life
; first clear buffer b

	ld bc,503		; n-1
	ld hl,buffb
	ld de,buffb
	inc de
	ld (hl),0		; zero fill
	ldir


; seed the starting point into the buffer

	ld b,42
	ld c,31
	ld a,1
	call putpixel

	ld b,43
	ld c,31
	ld a,1
	call putpixel

	ld b,44
	ld c,31
	ld a,1
	call putpixel

	ld b,44
	ld c,32
	ld a,1
	call putpixel

	ld b,44
	ld c,33
	ld a,1
	call putpixel

	ld b,42
	ld c,32
	ld a,1
	call putpixel


; copy buffb to buffa because putpixel goes to buffb
	ld bc,504
	ld hl,buffb
	ld de,buffa
	ldir

#endif


#ifdef debug

; setup debugging - enable LHD 7-seg display
	ld c,disscan
	ld a,20h
	out (c),a
#endif


#ifdef random

; seed random number generator

	ld a,r			; grab a random number
	ld (rndData),a


; random fill buffa to start the game

	ld bc,504
	ld hl,buffa


floop:	call getrandom

	ld (hl),a
	inc hl

	dec bc
	ld a,b
	or c
	jp nz,floop

#endif


; ----------------------------------------------------------------------------
; main program loop
; ----------------------------------------------------------------------------


mainloop:

; write buffer a to display
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



; perform an iteration of G.O.L. to buffer B

; first clear buffer b to all zeros

	ld bc,503		; n-1
	ld hl,buffb
	ld de,buffb
	inc de
	ld (hl),0		; zero fill
	ldir


; now iterate each cell and test it
; we skip the edges as then we don't have to do bounds checking
; edges are always 0's...dead.

	ld h, 1			; x=1

touter:
	ld l, 1			; y=1


#ifdef debug
	ld c,disseg
	ld a,(flag)
	xor 01h
	ld (flag),a
	out (c),a
#endif

tinner:

#ifdef debug
	ld c,disseg
	ld a,(flag)
	xor 08h
	ld (flag),a
	out (c),a
#endif

; test a pixel block to see if neighbours are alive or dead

	ld d,0		; result count

; top row
	ld b,h	; x-1
	dec b
	ld c,l	; y-1
	dec c

	call getpixel
	add a,d		; increment result
	ld d,a		; and store it
	inc b

	call getpixel
	add a,d		; increment result
	ld d,a		; and store it
	inc b

	call getpixel
	add a,d		; increment result
	ld d,a		; and store it

; bottom row
	ld b,h	; x-1
	dec b
	ld c,l	; y+1
	inc c

	call getpixel
	add a,d		; increment result
	ld d,a		; and store it

; optimization - if already >3, no need to do more checks
	cp 4
	jr nc, nostore

	inc b
	call getpixel
	add a,d		; increment result
	ld d,a		; and store it

; optimization - if already >3, no need to do more checks
	cp 4
	jr nc, nostore

	inc b
	call getpixel
	add a,d		; increment result
	ld d,a		; and store it

; optimization - if already >3, no need to do more checks
	cp 4
	jr nc, nostore


; middle row
	ld b,h	; x-1
	dec b
	ld c,l	; y


	call getpixel
	add a,d		; increment result
	ld d,a		; and store it


; optimization - if already >3, no need to do more checks
	cp 4
	jr nc, nostore

	inc b	; x+1
	inc b
	call getpixel
	add a,d		; increment result
	ld d,a		; and store it

; ok now d = number of active neighbour pixels
; >4 = die
; <2 = die
	cp 4
	jr nc, nostore
	cp 2
	jr c, nostore

; so d=2 or 3 now
; are we alive?

	ld b,h
	ld c,l
	call getpixel

; now a = 1 = we are alive
; if live we stay alive, so decision to live made
	cp 1
	jr z, live

; if dead check d = 3
; and make live if so

dead:
	ld a,d
	cp 3
	jr z, live
	jr nostore		; die; no need to write a 0 as we start with buff b = all 0

live:
	ld a,1

store:
	ld b,h
	ld c,l
	call putpixel


; next pixel

nostore:
	inc l
	ld a,l

	cp 2eh				; 2fh = 0..47; needs n-1 due border pixel
	jr nz, tinner

	inc h
	ld a,h
	cp 52h				; 53h = 0..83; needs n-1 due border pixel
	jp nz, touter








; copy buffer b to buffer a ready for next round

	ld bc,504
	ld hl,buffb
	ld de,buffa
	ldir





	jp mainloop


; ----------------------------------------------------------------------------
; Generate a random number 0<=255 return it in A register
; ----------------------------------------------------------------------------

getrandom:
        push    hl
        push    de
        ld      hl,(rndData)
        ld      a,r
        ld      d,a
        ld      e,(hl)
        add     hl,de
        add     a,l
        xor     h
        ld      (rndData),hl
        pop     de
        pop     hl
        ret


; ----------------------------------------------------------------------------
; Get the living or dead flag (1=living) from buff a
; pointer b=x c=y
; return with a = pixel status in bit 0
;
; the pixel buffer is 6 rows of 84 bytes = 504 bytes
; each byte contains 8 pixels
;
; byte = x+(84*(y/8))
; bit = y and 7
; ----------------------------------------------------------------------------

getpixel:
	push bc
	push de
	push hl

	ld d,c		; store Y in d for later

	ld hl,buffa	; setup base pointer
	ld c,b		; add X offset to it
	ld b,0
	add hl,bc


	ld a,d		; work out which row
	sra a
	sra a
	sra a

	ld bc,84	; width of a bitmap row


lp:	or a		; move up the offset; was cp 0
	jr z, nxt

	add hl,bc	; add the offset
	dec a
	jr lp

nxt:	ld a,d		; grab our Y byte back
	and 07h		; mask off bits to work out which bit we want
	ld b,a
	inc b		; set loop counter

	ld a,(hl)	; get the byte that holds our bit

rrloop:
	rrca		; put the correct bit in carry
	djnz rrloop

	rla		; grab from carry back to a register bit 0
	and 1		; mask off junk

	pop hl
	pop de
	pop bc

        ret




; ----------------------------------------------------------------------------
; Set the living or dead flag (1=living) to buff b
; pointer b=x c=y
; value a = pixel status in bit 0
;
; the pixel buffer is 6 rows of 84 bytes = 504 bytes
; each byte contains 8 pixels
;
; byte = x+(84*(y/8))
; bit = y and 7
; ----------------------------------------------------------------------------

putpixel:
	push bc
	push de
	push hl

	ld e,a		; save bit value we are storing
	ld d,c		; save Y in d for later


	ld hl,buffb
	ld c,b		; add X offset to it
	ld b,0
	add hl,bc


	ld a,d		; work out which row
	sra a
	sra a
	sra a

	ld bc,84	; width of a bitmap row


lp2:	or a		; move up the offset; was cp 0
	jr z, nxt2

	add hl,bc	; add the offset
	dec a
	jr lp2




nxt2:	ld a,d		; grab our byte back
	and 07h		; mask off bits to work out which bit we want
	ld b,a
	inc b
	ld a,e		; fetch our bit
	rrca		; adjust it because we do at least one RLCA for bit 0

rrloop2:
	rlca		; put bit in right place
	djnz rrloop2


	ld b,(hl)	; get current byte value
	or b		; insert our new bit from (originally) a register
	ld (hl),a	; put the byte back where it came from

bail:
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

buffb	.ds 504

rndData	.dw 0

flag	.db 0



; ----------------------------------------------------------------------------
; end of our code and data, end of program. goodbye!
; ----------------------------------------------------------------------------

	.end
