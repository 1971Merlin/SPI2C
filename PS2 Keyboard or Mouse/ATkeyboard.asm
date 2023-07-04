; -----------------------------------------------------------------------------
;
; AT Keyboard support on SPI2C
;
;
; written for the Soutern Cross Monitor version 1.8 or later
;
; outputs keystrokes to the serial terminal
;
; -----------------------------------------------------------------------------


#include "scm18_include.asm"


	.org	2000h

	ld c,SERINI
	rst 30h

	call i2c_init			; setup port

	ld a,1				; set basic state
	ld (shifted),a
	ld (caps),a


krst:	ld d,0edh			; set leds state
	call i2c_ATtx
	ld d,0				; kb leds bits all off
	call i2c_ATtx




mloop:	call getkey
	cp 00h
	jr z,mloop

	call scan2asc
	cp 0ffh
	jr z,mloop

	ld c,TXDATA
	rst 30h

	jr mloop




; ------------------------------------------------------
; getkey - waits for a keypress
;
; returns with scancode in A or 00 = no valid key
; ------------------------------------------------------

getkey:

 	call i2c_ATrx		; wait for a keystroke

	cp 0f0h			; release?
	jr z, release

	cp 0e0h
	jr z, special		; special key?

	cp 12h			; shift?
	jr z,shifton
	cp 59h
	jr z,shifton

	cp 58h			; caps lock?
	jr z,capstog

	ret			; return normal scan code


; f0h, xxh
release:
	call i2c_ATrx		; get but ignore (most) keys

	cp 12h
	jr z,shiftoff
	cp 59h
	jr z,shiftoff

	xor a
	ret


; e0h xxxh
special:
	call i2c_ATrx
	cp 0f0h
	jr z, release

	xor a			; we ignoring special keys for now
	ret

shifton:
	ld a,2
	ld (shifted),a
	xor a
	ret

shiftoff:
	ld a,1
	ld (shifted),a
	xor a
	ret

capstog:
	ld a,(caps)			; flip status bit
	xor 3
	ld (caps),a

	ld d,0edh			; set leds state
	call i2c_ATtx

	ld a,(caps)
	sla a
	and 04h
	ld d,a				; kb leds bits
	call i2c_ATtx

	xor a
	ret



; ------------------------------------------------------
; scan code to ASCII conversion
;
;
; in: A = scancode
; out A = translated ASCII value or FFh if not translatable
; ------------------------------------------------------


scan2asc:	ld hl,keytable
		ld e,a


ascloop:	ld a,(hl)
		inc hl
		cp 0ffh			; end of table?
		ret z

		cp e
		jr z, fixx

		inc hl			; skip mapped value
		jr ascloop		; try next map


fixx:		ld a,(hl)


; now fix case
		cp 07fh			; ignore backspace
		ret z

		cp 61h			; letters?
		ret c

		ld e,a


; use xor logic!!

		ld a,(shifted)
		ld b,a
		ld a,(caps)
		xor b
		ld a,e
		ret z


toupper:	sub 020h
		ret



keytable:	.db 01ch,'a'
		.db 032h,'b'
		.db 021h,'c'
		.db 023h,'d'
		.db 024h,'e'
		.db 02bh,'f'
		.db 034h,'g'
		.db 033h,'h'
		.db 043h,'i'
		.db 03bh,'j'
		.db 042h,'k'
		.db 04bh,'l'
		.db 03ah,'m'
		.db 031h,'n'
		.db 044h,'o'
		.db 04dh,'p'
		.db 015h,'q'
		.db 02dh,'r'
		.db 01bh,'s'
		.db 02ch,'t'
		.db 03ch,'u'
		.db 02ah,'v'
		.db 01dh,'w'
		.db 022h,'x'
		.db 035h,'y'
		.db 01ah,'z'

		.db 045h,'0'
		.db 016h,'1'
		.db 01eh,'2'
		.db 026h,'3'
		.db 025h,'4'
		.db 02eh,'5'
		.db 036h,'6'
		.db 03dh,'7'
		.db 03eh,'8'
		.db 046h,'9'

		.db 00eh,'`'
		.db 04eh,'-'
		.db 055h,'='
		.db 05dh,'\'
		.db 054h,'['
		.db 05bh,']'
		.db 04ch,';'
		.db 041h,','
		.db 049h,'.'
		.db 04ah,'/'

; keypad keys
		.db 07ch,'*'
		.db 07bh,'-'
		.db 079h,'+'


; nonprinting keys
		.db 029h,' '	; Space
		.db 05ah,0dh	; Enter
		.db 066h,7fh	; bkspc
		.db 00dh,09h	; Tab
		.db 076h,1bh	; Esc
		.db 052h,27h	; apostrophe


		.db 0ffh	; end of table


shifted:	.db 01h
caps:		.db 01h


#include "spi2c_library.asm"




	.end

