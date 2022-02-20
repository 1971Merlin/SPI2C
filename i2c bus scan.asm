; ----------------------------------------------------------------------------
;
;	Test code for TEC SPI2C board. Detects i2c devices and displays
;       their address on the 7-seg displays. press any key to go on.
;
;       FF on the dispaly means no i2c devices detected
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


; ----------------------------------------------------------------------------
; main program loop
; read the clock from the i2c bus
; display the clock on the internal 7-seg's (for testing!)
; display the clock also on the i2c 7-seg module
; ----------------------------------------------------------------------------

	ld a,00h
	ld (mode),a



oloop:	ld a,00h
	ld (i2caddr),a
	ld (found),a

loop:	call i2c_start
	ld a,(i2caddr)
	ld d,a			; convert to i2c address
	rlc d
	res 0,d
	call i2c_txbyte
	call i2c_stop

	bit 0,d
	jp z,got

rloop:	ld a,(i2caddr)		; next address
	inc a
	ld (i2caddr),a
	cp 80h			; addresses are 7 bit only
	jr z,ni2cn

	jr loop


ni2cn:	ld a,(found)		; end of loop but found something prior, so rescan
	cp 0
	jp nz,oloop


	ld a,00h		; reset for future
	ld (i2caddr),a
	ld hl,disp_buff		; nothing found
	ld a,0fh
	ld (hl),a
	inc hl
	ld (hl),a
	jp dloop


got:	ld a,(found)		; found a device
	inc a
	ld (found),a

	ld hl,disp_buff
	ld a,(i2caddr)
	srl a
	srl a
	srl a
	srl a
	ld (hl),a
	inc hl
	ld a,(i2caddr)
	and 0fh
	ld (hl),a


dloop:	call scan_7seg

	call pollkey	; sample keyboard state
	call handlekey	; process a keystroke, if any

	ld a,(mode)
	cp 0ffh

	jp nz,dloop


	ld a,0
	ld (mode),a

	ld a,0ffh
	ld hl,disp_buff
	ld (hl),a
	inc hl
	ld (hl),a

	call ldelay

	jp rloop


; ----------------------------------------------------------------------------
; handle key; check buffer fora keystroke and do something if found
; ----------------------------------------------------------------------------

handlekey:
	push af

	ld a,(keyval)	; bit 7=1 = valid keypress in buffer
	bit 5,a
	jr z, nohndl	; nope, no key in buffer

	res 5,a		; clear keypress valid bit - we used our keypress
	ld (keyval),a

; at this poin A contains a value 0-F represernting the pressed key

	ld a,0ffh	; pressing a key
	ld (mode),a


nohndl:	pop af
	ret


; ----------------------------------------------------------------------------
; poll keyboard; update buffer if a keypress detected
;
;
; ----------------------------------------------------------------------------

pollkey:
	push af
	push bc
	in a,(keyport)

; SC-1 keyboard routine. Ensures only one keypress at a time and loop doesn't pause

#ifdef SC1
	bit 5,a		; bit 5=1 = key pressed on SC-1
	jr nz, key
#endif


#ifdef TEC1
	res 5,a
	bit 6,a		; bit 6=0 = key pressed on TEC1 (Requires jmon resistor mod)
	jr nz,nokey
	set 5,a
	jr key
#endif

nokey:
	ld (keyflag),a
	jr bail


key:	and 3fh		; mask off top bits
	ld b,a		; backup value
	ld a,(keyflag)	; did we already see it pressed?
	bit 5,a
	jr nz, bail

	ld a,b		; restore value and save; set flag
	ld (keyflag),a
	ld (keyval),a

bail:
	pop bc
	pop af
	ret


; ----------------------------------------------------------------------------
; General purpose delay loop
; ----------------------------------------------------------------------------
ldelay:	push af
	push de
	ld de,08000h

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
; Utility routine to scan the internal 7-seg displays
; Borrowed from Craig Jones SC-1 monitor
; ----------------------------------------------------------------------------

scan_7seg:
	push af
	push bc
	push hl

outerloop:
	ld c,020h
	ld hl,disp_buff

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
	ld b,20h
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

; converts a decimal value in register A to a 7-seg value of that digit
; returns A with which segs to light up

conv7seg:
	push bc		; this is really a lookup table fetch that allows
	push hl		; for memory wrapping of the lower byte

	cp 0ffh		; blank? don't light up blanks
	jr nz, cont
	ld a,00h
	jr ex

cont:	ld hl, segs	; list of 0-9 digits which segs to light for each
	and 0fh		; ensure a is in a valid range
	ld c,a		; put into lwr half of bc
	ld b,00h	; upper half is 0
	add hl,bc	; 16-bit add
	ld a,(hl)	; fetch value from memory

ex:	pop hl
	pop bc
	ret


; ----------------------------------------------------------------------------
;	data, variables, etc.
; ----------------------------------------------------------------------------

mode:	.db 00h

keyflag	.db 00h
keyval	.db 00h

i2caddr	.db 00h

found	.db 00h


disp_buff:
	.db 0ffh, 0ffh, 0ffh, 0ffh, 0ffh ,0ffh


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
	.db 77h
	.db 7ch
	.db 39h
	.db 5eh
	.db 79h
	.db 71h

#endif

#ifdef TEC1
segs:
	.db 0ebh
	.db 028h
	.db 0cdh
	.db 0adh
	.db 02eh
	.db 0a7h
	.db 0e7h
	.db 029h
	.db 0efh
	.db 02fh
	.db 06fh
	.db 0e6h
	.db 0c3h
	.db 0ech
	.db 0c7h
	.db 047h

#endif


; ----------------------------------------------------------------------------
; end of our code and data, end of program. goodbye!
; ----------------------------------------------------------------------------

	.end
