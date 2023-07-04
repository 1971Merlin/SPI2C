; ----------------------------------------------------------------------------
; 	Libraries for SPI2C board.
;
;	Copyright (C) 2023, Craig Hart. Distributed under the GPLv3 license.
;
;	https://github.com/1971Merlin/SPI2C
;
; ----------------------------------------------------------------------------

; ----------------------------------------------------------------------------
;
; Common Parameters
;
; the user should change the ports according to the hardware in use
;
; ----------------------------------------------------------------------------


i2cport	.equ 40h	; IO port our I2C "controller" lives on
			; 40h for SC-1 using the onboard 74HC138
			; user selected for TEC-1

spiport	.equ 42h	; IO port our SPI "controller" lives on
			; 42h for SC-1 using the onboard 74HC138
			; user selected for TEC-1

	
spics1	.equ 0fbh
spics2	.equ 0efh
spics3	.equ 0dfh
spics4	.equ 0bfh
spics5	.equ 07fh



; ----------------------------------------------------------------------------
; I2C Routines
; ----------------------------------------------------------------------------

i2cidle	.equ 03h

i2c_init:
	push af
	ld a,i2cidle	; idle state = SCL and SDA both high
	out (i2cport),a
	pop af
	ret

; ----------------------------------------------------------------------------
; Routine to make the i2c bus active
; ----------------------------------------------------------------------------

i2c_start:
	push af
	ld a,02h	; SCL 1, SDA 0 = start
	out (i2cport),a
	ld a,00h
	out (i2cport),a	; SCL 0, SDA 0 = bus idle active
	pop af
	ret

; ----------------------------------------------------------------------------
; Routine to return i2c bus to idle
; ----------------------------------------------------------------------------

i2c_stop:
	push af
	ld a,01h	; SCL 0, SDA 1 = stop
	out (i2cport),a
	ld a,03h
	out (i2cport),a	; SCL 1, SDA 1 = bus idle inactive
	pop af
	ret

; ----------------------------------------------------------------------------
; Routine to transmit a byte on the i2c bus
;
; enter  d = byte to send
; return d bit 0 = result; 0 = accepted/OK; 1 = ignored/no device
; ----------------------------------------------------------------------------

i2c_txbyte:
	push af
	push bc

	ld b,8		; 8 bits

txbyte1:
	ld a,00h	; prep CL=low, data = ?
	rlc d		; set CF = data
	adc a,a		; set bit 0 to our data
	out (i2cport),a	; SDA=data, SCL = 0

	set 1,a		; Pulse SCL high
	out (i2cport),a
	res 1,a		; and SCL low again
	out (i2cport),a

	dec b
	jr nz, txbyte1

; get ACK since we did a set address command --
; if the device is there we should get an answer bit = 0

rxack:	ld a,03h	; SET SCL = 1 (leave data high = bus free for response)
	out (i2cport),a
	in a,(i2cport)	;get result; 0 = response received
	ld d,a		; store d=result
	ld a,01h	; SCL = 0, SDA = 1
	out (i2cport),a

; d holds our result, bit zro should be a 0 if an ACK received

	pop bc
	pop af
	ret

; ----------------------------------------------------------------------------
; Routine to receive a byte from the i2c bus
;
; return d = result
; ----------------------------------------------------------------------------

i2c_rxbyte:
	push af
	push bc

	ld b,8		; 8 bits
	ld d,00h	; (our data to be read)

rxbyte1:
	ld a,01h	; prep SCL=low, data = high (tristate output)
	out (i2cport),a	; SDA=data, SCL = 0

	ld a,03h	; SCL = 1, SDA = 1
	out (i2cport),a

	in a,(i2cport)	; read bit (they send us SDA)
	rrc a		; store into CF
	rl d		; and read into d

	ld a,01h
	out (i2cport),a	; SCL = 0, SDA = 1 (tristate output)

	dec b
	jr nz, rxbyte1

; send ACK since we read a byte

txack:	ld a,01h	; Setup ACK pulse SCL=0 with SDA=1
	out (i2cport),a
	ld a,03h	; Send ACK SCL = 1, SDA = 1
	out (i2cport),a
	ld a,01h	; lower SCL; idle ready state
	out (i2cport),a

	pop bc
	pop af
	ret


; ----------------------------------------------------------------------------
; Routine to receive an AT keyboard byte from the i2c bus
;
; return a = result
; ----------------------------------------------------------------------------

i2c_ATrx:

	call rxAT	; get the start bit and discard it

	ld b,8		; 8 bits
	ld d,00h	; (our data to be read)

ATbits:	call rxAT	; get 8 data bits
	djnz ATbits

	ld c,d		; backup for later

	call rxAT	; get parity bit and discard it
	call rxAT	; get stop bit and discard it

	ld a,c		; restore value

	ret




rxAT:

rxAT1:	in a,(spiport)	; read
	and 08h
	jp nz,rxAT1	; wait for clk to go low

	in a,(i2cport)	; read bit 0 == data
	rrca		; bit 0 into carry
	rr d		; carry into d bit 7, shifting right each time

rxAT2:	in a,(spiport)	; wait for clock to go high
	and 08h
	jp z,rxAT2

	ret





; ----------------------------------------------------------------------------
; Routine to transmit an AT keyboard byte from the i2c bus
;
; d = byte to transmit
; ----------------------------------------------------------------------------

i2c_ATtx:

	ld c,0

	ld a,d
	or a			; set parity bit
	jp po,noparity

	ld c,1

noparity:
	ld a,01
	out (i2cport),a		; CLK low (bit 1) data high (bit 0)

	ld b,09h			; delay 100us
grabck:	djnz grabck

	ld a,00			; both low
	out (i2cport),a
	
	nop
	nop
	nop
	nop

	ld a,02		; CLK high data low; start bit
	out (i2cport),a

	call txAT1	; wait ack.


	ld b,8		; now send 8 data bits
	
ATbit2:	call txAT
	srl d
	djnz ATbit2

	ld d,c		; send parity  bit
	call txAT

	ld a,03		; back to idle
	out (i2cport),a


	call rxAT
	call rxAT

;	ld b,0fh	; small delay
;ignore:	djnz ignore
	
	
	ret


txAT:	ld a,d
	or 2		; keep CLK high our side, set data bit =b0
	out (i2cport),a	; set bit 0 == data

txAT1:	in a,(spiport)
	and 08h
	jp z,txAT1	; wait for clk to go high


	
txAT2:	in a,(spiport)	; wait for clock to go low
	and 08h
	jp nz,txAT2

	ret
	



; ----------------------------------------------------------------------------
; SPI Routines
; ----------------------------------------------------------------------------

spiidle	.equ 0f4h	; Idle state

; SPI port bits
;
; bit 0 - MOSI/MISO
; bit 1 - CLK
; bit 2 - CS1
; bit 3 - D/C
; bit 4 - CS2
; bit 5 - CS3
; bit 6 - CS4
; bit 7 - CS5

; ----------------------------------------------------------------------------
; SPI initialization code starts here; call once at start of code
;
; idle state == 1111 0100  === MOSI, D/C and CLK low, CSx all high
; ----------------------------------------------------------------------------

spi_init:
	push af
	ld a,spiidle	; Set idle state
	out (spiport),a
	pop af
	ret

; ----------------------------------------------------------------------------
; Routine to send byte to the SPI bus
;
; c = SPI CS pin required (use the spics EQUs above)
; d = command/data 00 = command, 08 = data
; e = data byte
;
; no results returned, no registers odified
; ----------------------------------------------------------------------------

spi_wr:	push af
	push de
	call spi_wrb
	jr spi_done

; ----------------------------------------------------------------------------
; Routine to send two bytes to the SPI bus
;
; c = SPI CS pin required (use the spics EQUs above)
; d = command byte
; e = data byte
;
; no results returned, no registers modified
; ----------------------------------------------------------------------------

spi_wrw:
	push af
	push de
	ld a,e
	ld e,d
	ld d,08h
	call spi_wrb

	ld e,a
	ld d,08h
	call spi_wrb

spi_done:	
	ld a,spiidle	; return to idle mode
	out (spiport),a
	pop de
	pop af
	ret

; ----------------------------------------------------------------------------
; Routine to transmit one byte to the SPI bus
;
; c = SPI CS pin required (use the spics EQUs above)
; d = command/data 00 = command, 08 = data
; e = data byte
;
; no results returned, no registers modified
; ----------------------------------------------------------------------------

spi_wrb:
	push af
	push bc
	push de

	ld b,8		; 8 BITS

nbit:	ld a,spiidle	; starting point
	or d		; add in the command/data register select
	and c		; add in the CS pin
	bit 7,e
	jr z, no
	set 0,a

no:	out (spiport),a
	set 1,a		; set CLK
	out (spiport),a
	res 1,a		; clear CLK
	out (spiport),a
	rlc e		; next bit
	djnz nbit

	pop de
	pop bc
	pop af
	ret
