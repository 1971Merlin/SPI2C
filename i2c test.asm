; -----------------------------------------------------------------------------------------------
;
;	Test code for TEC SPI2C board with MAX7219, DS1307 RTC
;
;	Uses a MAX7219 8-digit, 7-segment display; Duinotech XC-3714 or equivilant
;	Uses a DS1307 RTC board; Duinotech XC-4450 or equivilant
;
;	Designed to compile for the TEC-1 or SC-1 as the target machine
;
;	Assemble with TASM using the command line options -80 -g0
;
;	Copyright (C) 2022, Craig Hart. Distributed under the GPLv3 license
;
;	https://github.com/1971Merlin/SPI2C
;
; -----------------------------------------------------------------------------------------------




; ----------------------------------------------------------------------------
; define global constants to the compiler
; ----------------------------------------------------------------------------

ds1307	.equ	68h
lc16b	.equ	0a0h

; ----------------------------------------------------------------------------
; conditional defines - set the target machine platform
; comment or un-commnt the following two lines to compile for target machine
; ----------------------------------------------------------------------------

#define SC1
;#define TEC1


#ifdef SC1

; using i2cspi's onboard 74ls138 IO ports
i2cport	.equ	40h
spiport	.equ	42h

; SC-1 7-seg ports
disscan .equ	85h
disseg	.equ	84h

; keyboard port
keyport	.equ	86h

; start address for SC-1 code
	.org 2000h

#endif



#ifdef TEC1

; using TEC's 74ls138 IO ports
i2cport	.equ	06h
spiport	.equ	07h

; tec-1 7-seg ports
disscan	.equ	01h
disseg	.equ	02h

; keyboard port
keyport	.equ	00h


; start address for TEC code
	.org 0900h

#endif

; ----------------------------------------------------------------------------
; hardware initialization code starts here
; ----------------------------------------------------------------------------

; reset i2c bus to idle state
	ld a,03h	; idle state = SCL and SDA both high
	ld c,i2cport
	out (c),a

; reset spi bus to idle state
	ld c,spiport	; reset CS = 1
	ld a,0fch	; Raise CS
	out (c),a
	call ldelay	; pause to establish stable state

; init SPI 7-seg dispay to required operational mode
	ld de,09ffh	; decode mode digits 7-0
	call spi_wr
	ld de,0a0fh	; max brightness
	call spi_wr
	ld de,0b07h	; all 8 digits on
	call spi_wr
	ld de,0c01h	; normal op
	call spi_wr


; setup the DS307's initial starting time. & date
	call set1307
	call ldelay

; ----------------------------------------------------------------------------
; main program loop
; read the clock from the i2c bus
; display the clock on the internal 7-seg's (for testing!)
; display the clock also on the i2c 7-seg module
; ----------------------------------------------------------------------------

loop:

	call rd1307	; Read DS1387 registers

	call convdata	; Convert DS1387 data to TEC format

	call scan_7seg	; put display buffer contents on internal display

	call maxout	; Put display buffer contents on MAX7219 7-segs

	call pollkey	; get a key
	cp 0ffh
	jr z, loop

; OK pressing a key


	ld a,(mode)
	xor 80h
	ld (mode),a

loop2	call pollkey	; get a key
	cp 0ffh
	jr nz, loop2



	jp loop


; ----------------------------------------------------------------------------
; poll keyboard
;
; returns a=0ffh if no key, otherwise value read
;
; not yet modded for TEC-1
; ----------------------------------------------------------------------------

pollkey:
	in a,(keyport)

#ifdef SC1
	bit 5,a
	jr nz, key
#endif

	ld a,0ffh
	ret

key:	and 1fh
	ret




; ----------------------------------------------------------------------------
; General purpose delay loop
; ----------------------------------------------------------------------------
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


; ----------------------------------------------------------------------------
; make the i2c bus active
; ----------------------------------------------------------------------------

i2c_start:
	push af
	push bc
	ld c,i2cport
	ld a,02h	; SCL 1, SDA 0 = start
	out (c),a
	ld a,00h
	out (c),a	; SCL 0, SDA 0 = bus idle active
	pop bc
	pop af
	ret

; ----------------------------------------------------------------------------
; return i2c bus to idle
; ----------------------------------------------------------------------------

i2c_stop:
	push af
	push bc
	ld c,i2cport
	ld a,01h	; SCL 0, SDA 1 = stop
	out (c),a
	ld a,03h
	out (c),a	; SCL 1, SDA 1 = bus idle inactive
	pop bc
	pop af
	ret


; ----------------------------------------------------------------------------
; transmit a byte on the i2c bus
;
; enter  d = byte to send
; return d = result
; ----------------------------------------------------------------------------


i2c_txbyte:
	push af
	push bc

	ld c,i2cport
	ld b,8		; 8 bits

txbyte1:
	ld a,00h	; prep CL=low, data = ?
	rlc d		; set CF = data
	adc a,a		; set bit 0 to our data
	out (c),a	; SDA=data, SCL = 0

	set 1,a		; Pulse SCL high
	out (c),a
	res 1,a		; and SCL low again
	out (c),a

	dec b
	jr nz, txbyte1

; get ACK since we did a set address command -- if the device is there we should get an answer bit = 0

	ld a,03h	; SET SCL = 1 (leave data high == bus free for response)
	out (c),a
	in a,(c)	;get result; 0 = response received
	ld d,a		; store d=result
	ld a,01h	; SCL = 0, SDA = 1
	out (c),a

; d holds our result, should be a 0-bit if an ACK received

	pop bc
	pop af
	ret


; ----------------------------------------------------------------------------
; receive a byte from the i2c bus
;
; return d = result
; ----------------------------------------------------------------------------

i2c_rxbyte:
	push af
	push bc

	ld c,i2cport
	ld b,8		; 8 bits
	ld d,00h	; (our data to be read)


rxbyte1:
	ld a,01h	; prep SCL=low, data = high (tristate output)
	out (c),a	; SDA=data, SCL = 0

	ld a,03h	; SCL = 1, SDA = 1
	out (c),a

	in a,(c)	; read bit (they send us SDA)
	rrc a		; store into CF
	rl d		; and read into d

	ld a,01h
	out (c),a	; SCL = 0, SDA = 1 (tristate output)

	dec b
	jr nz, rxbyte1

; send ACK since we read a byte


ack:	ld a,01h	; Setup ACK pulse SCL=0 with SDA=1
	out (c),a
	ld a,03h	; Send ACK SCL = 1, SDA = 1
	out (c),a
	ld a,01h	; lower SCL; idle ready state
	out (c),a

	pop bc
	pop af
	ret


; ----------------------------------------------------------------------------
; utility routine to scan the internal 7-seg displays
; ----------------------------------------------------------------------------

scan_7seg:
	push af
	push bc
	push hl

outerloop:
	ld c,020h
	ld hl,disp_buff
	inc hl

scanloop:
	ld a,(hl)	; output value
	call conv7seg
	out (disseg),a
	ld a,c		; turn on display
	out (disscan),a
	ld b,0c0h
on:	djnz on

	ld a,00h	; turn off display
	out (disscan),a
	ld b,18h
off:	djnz off

	inc hl
	rrc c
	jr nc,scanloop

	ld a,00h	; turn off displays
	out (disseg),a
	out (disscan),a

	pop hl
	pop bc
	pop af
	ret


conv7seg:
	PUSH	BC
	PUSH	HL
	LD	HL,segs
	AND	0fh	;TO INDEX TO THE
	LD	C,A	;THE SEVEN SEGMENT
	LD	B,00h	;CODE FOR THAT VALUE
	ADD	HL,BC	;AND RETURN WITH
	LD	A,(HL)	;CODE IN A
	POP	HL
	POP	BC
	RET

; ----------------------------------------------------------------------------
; write to the SPI bus
;
; d = command
; e = data byte
; ----------------------------------------------------------------------------

spi_wr:	push af
	push bc
	push de

	ld c,spiport
	ld b,8


nbit:	ld a,0f8h	; set 3 lines low
	rlc d		; next bit into CF
	adc a,a		; Add Data bit 0
	out (c),a	; set data
	set 1,a		; set CLK High
	out (c),a
	ld a,00h	; set cLK low
	out (c),a
	dec b
	jr nz, nbit

	ld b,8

nbit2:	ld a,078h
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

	pop de
	pop bc
	pop af
	ret


; ----------------------------------------------------------------------------
; read the DS1307 clock chip
; ----------------------------------------------------------------------------

rd1307:
	ld hl,reg_buffer
	ld b,7		; 7 bytes to read
	ld e,0		; starting from reg 0



lp1307:	ld d,ds1307	; i2c address
	rlc d		; 7 bits only
	res 0,d		; new bit zero = 0 = write
	call i2c_start
	call i2c_txbyte
	ld d,e		; second byte ; selects the required register
	call i2c_txbyte
	call i2c_stop



	ld d,ds1307	; i2c address
	rlc d		; 7 bits only
	set 0,d		; new bit zero = 1 = read

	call i2c_start
	call i2c_txbyte
	call i2c_rxbyte
	ld (hl),d	; store result into buffer, this is our register's value

	call i2c_stop

	inc e
	inc hl
	djnz lp1307


;	call i2c_stop

	ret



; ----------------------------------------------------------------------------
; set the DS1307 clock chip
; ----------------------------------------------------------------------------

set1307:
	ld hl,clockset
	ld b,7		; 7 bytes to write
	ld e,0		; starting from reg 0



lps1307:
	ld d,ds1307	; i2c address
	rlc d		; 7 bits only
	res 0,d		; new bit zero = 0 = write
	call i2c_start
	call i2c_txbyte
	ld d,e		; second byte ; selects the required register
	call i2c_txbyte

	ld d,(hl)
	call i2c_txbyte	; third byte = write our value
	call i2c_stop

	inc e
	inc hl
	djnz lps1307

	ret




; ----------------------------------------------------------------------------
; process the clock chip's raw data into the display buffer format
; ----------------------------------------------------------------------------

convdata:
	ld hl,reg_buffer	; src

	ld a,(mode)
	bit 7,a

	jr nz, conv2

	inc hl			; move to D/M/Y
	inc hl
	inc hl
	inc hl




conv2:	ld de,disp_buff		; dest (to be filled right to left)
	inc de
	inc de
	inc de
	inc de
	inc de
	inc de
	ld a,00h

;secs / date
	rrd
	ld (de),a
	dec de
	rrd
	ld (de),a
	dec de

;mins / month
	inc hl
	rrd
	ld (de),a
	dec de
	rrd
	ld (de),a
	dec de

; hours / year
	inc hl
	rrd
	ld (de),a
	dec de
	rrd
	ld (de),a
	dec de

	ret



; ----------------------------------------------------------------------------
; Send the contents of the display buffer to the MAX7219 chip
; ----------------------------------------------------------------------------

maxout:	ld hl,disp_buff
	ld d,8

lout:	ld e,(hl)
	call spi_wr
	inc hl
	dec d
	jr nz, lout

	ret




; ----------------------------------------------------------------------------
;	data, variables, etc.
; ----------------------------------------------------------------------------

reg_buffer:
	.db 00h
	.db 00h
	.db 00h
	.db 00h
	.db 00h
	.db 00h
	.db 00h

disp_buff:
	.db 0fh
	.db 0fh
	.db 0fh
	.db 0fh
	.db 0fh
	.db 0fh
	.db 0fh
	.db 0fh

mode:	.db 80h


clockset:
	.db 00h	; osc, 10secs, secs
	.db 30h	; 10 mins, mins
	.db 18h ; hours
	.db 01h ; day
	.db 07h ; date
	.db 10h	; month
	.db 22h	; year


#ifdef SC1
segs:
	.db 3fh
	.db 06h
	.db 5bh
	.db 4fh
	.db 66h
	.db 6dh
	.db 7dh
	.db 07h
	.db 7fh
	.db 6fh
#endif


#ifdef TEC1
segs:
	.db ebh
	.db 28h
	.db cdh
	.db adh
	.db 2eh
	.db a7h
	.db e7h
	.db 29h
	.db efh
	.db 2fh
#endif


; ----------------------------------------------------------------------------
; end of our code and data, end of program. goodbye!
; ----------------------------------------------------------------------------

	.end
