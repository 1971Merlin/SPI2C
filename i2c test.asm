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


; ----------------------------------------------------------------------------
; main program loop
; read the clock from the i2c bus
; display the clock on the internal 7-seg's (for testing!)
; display the clock also on the i2c 7-seg module
; ----------------------------------------------------------------------------

loop:

; ----------------------------------------------------------------------------
; read the DS1307 clock chip
; ----------------------------------------------------------------------------

; d = i2c address
; e = addres data
; hl = result storage

; reg 0
	ld hl,reg_buffer
	ld d,ds1307	; i2c address
	rlc d		; 7 bits only
	res 0,d		; new bit zero = 0 = write
	ld e,00h	; e = register select
	call addr_set

; d = i2c address
; e = addres data
; hl = result storage

	ld hl,reg_buffer
	ld d,ds1307	; i2c address
	rlc d		; 7 bits only
	set 0,d		; new bit zero = 1 = read
	ld e,1
	call reg_read

; reg 1
	ld hl,reg_buffer
	ld d,ds1307	; i2c address
	rlc d		; 7 bits only
	res 0,d		; new bit zero = 0 = write
	ld e,01h	; e = register select
	call addr_set

	ld hl,reg_buffer
	inc hl
	ld d,ds1307	; i2c address
	rlc d		; 7 bits only
	set 0,d		; new bit zero = 1 = read
	ld e,1
	call reg_read

; reg 2

	ld hl,reg_buffer
	ld d,ds1307	; i2c address
	rlc d		; 7 bits only
	res 0,d		; new bit zero = 0 = write
	ld e,02h	; e = register select
	call addr_set


	ld hl,reg_buffer
	inc hl
	inc hl
	ld d,ds1307	; i2c address
	rlc d		; 7 bits only
	set 0,d		; new bit zero = 1 = read
	ld e,1
	call reg_read




; process the clock chip's data into the display buffer

	ld hl,reg_buffer	; src
	ld de,disp_buff		; dest (to be filled right to left, so start at the end)
	inc de
	inc de
	inc de
	inc de
	inc de
	inc de

;secs
	ld a,(hl)
	and 0fh
	ld (de),a
	dec de

; 10s secs
	ld a,(hl)
	and 070h
	rrc a
	rrc a
	rrc a
	rrc a
	ld (de),a
	dec de

; next register
	inc hl

;mins
	ld a,(hl)
	and 0fh
	ld (de),a
	dec de

; 10s mins
	ld a,(hl)
	and 070h
	rrc a
	rrc a
	rrc a
	rrc a
	ld (de),a
	dec de

; next register
	inc hl

; hours
	ld a,(hl)
	and 0fh
	ld (de),a
	dec de

; 10s hours
	ld a,(hl)
	and 030h
	rrc a
	rrc a
	rrc a
	rrc a
	ld (de),a
	dec de

; put display buffer contents on internal display
	call scan_7seg

; put display buffer contents on SPI 7-seg

SPIcycle:
	ld hl,disp_buff
	ld d,8
out:	ld e,(hl)
	call spi_wr

	inc hl
	dec d
	jr nz, out


; and do it again!
	jp loop





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
; set the i2c address onto the i2c bus
; ----------------------------------------------------------------------------
; d = i2c address
; e = address to set register pointer to
; hl = place to store result

addr_set:

	call i2c_start

	call i2c_txbyte
;	push de		; store result

	ld d,e		; second byte

	call i2c_txbyte
;	push de		; store result

	call i2c_stop

	ret






; ----------------------------------------------------------------------------
; read data from the i2c bus
; ----------------------------------------------------------------------------

; d = i2c address, then read data
; e = number of bytes to read
; hl = place to store rsult

reg_read:

	call i2c_start
	call i2c_txbyte
rloop:
	call i2c_rxbyte

	ld (hl),d	; store result
	inc hl
	dec e
	jr nz, rloop

	call i2c_stop

	ret





; ----------------------------------------------------------------------------
; make the i2c bus active
; ----------------------------------------------------------------------------

i2c_start:

	ld c,i2cport
	ld a,02h	; SCL 1, SDA 0
	out (c),a
	ld a,00h
	out (c),a	; SCL 0, ADA 0
	ret

; ----------------------------------------------------------------------------
; return i2c bus to idle
; ----------------------------------------------------------------------------

i2c_stop:

	ld c,i2cport
	ld a,01h	; SCL 0, SDA 1
	out (c),a
	ld a,03h
	out (c),a	; SCL 1, ADA 1
	ret


; ----------------------------------------------------------------------------
; transmit a byte on the i2c bus
; ----------------------------------------------------------------------------

i2c_txbyte:

; enter  d = byte to send
; return d = result

	ld c,i2cport
	ld b,8		; 8 bits

txbyte1:
	ld a,00h	; prep CL=low, data = high
	rlc d		; set CF = data
	adc a,a		; set bit 0 to our data
	out (c),a	; SDA=data, SCL = 0

	set 1,a		; Pulse SCL high
	out (c),a
	res 1,a
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

	ret


; ----------------------------------------------------------------------------
; read a byte form the i2c bus
; return d = result
; ----------------------------------------------------------------------------

i2c_rxbyte:

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

; send aCK since we read a byte


ack:	ld a,01h	; Send ACL pulse clock with D=1
	out (c),a
	ld a,03h	; SCL = 1, SDA = 1
	out (c),a
	ld a,01h	; lower SCL
	out (c),a

	ret


; ----------------------------------------------------------------------------
; utility routine to scan the internal 7-seg displays
; ----------------------------------------------------------------------------

scan_7seg:

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
	ld b,80h
on:	djnz on

	ld a,00h	; turn off display
	out (disscan),a
	ld b,20h
off:	djnz off

	inc hl
	rrc c
	jr nc,scanloop

	ld a,00h	; turn off displays
	out (disseg),a
	out (disscan),a

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
; call with de = comand, data bytes to write
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
;	data, variables, etc.
; ----------------------------------------------------------------------------

reg_buffer:
	.db 0
	.db 0
	.db 0
	.db 0
	.db 0
	.db 0
	.db 0
	.db 0

disp_buff:
	.db 0fh
	.db 0fh
	.db 0fh
	.db 0fh
	.db 0fh
	.db 0fh
	.db 0fh
	.db 0fh

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
