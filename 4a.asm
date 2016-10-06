
.include "m2560def.inc"
.def row = r16 
.def col = r17 
.def rmask = r18 
.def cmask = r19 
.def temp1 = r20 
.def temp2 = r21
.equ PORTLDIR = 0b11110000 
.equ INITCOLMASK = 0b11101111 
.equ INITROWMASK = 0b00000001 
.equ ROWMASK = 0b00001111

RESET:
	ldi temp1, low(RAMEND) 
	out SPL, temp1
	ldi temp1, high(RAMEND)
	out SPH, temp1

	ldi temp1, PORTLDIR
	sts DDRL, temp1
	ser temp1
	out DDRC, temp1
	out PORTC, temp1

main:
	; initialize the stack
	ldi cmask, INITCOLMASK 
	clr col

colloop:
	cpi col, 4
	breq main 
	sts PORTL, cmask
	ldi temp1, 0xFF

delay: 
	dec temp1
	brne delay
	lds temp1, PINL			; Read PORTL
	andi temp1, ROWMASK		; Get the keypad output value
	cpi temp1, 0xF			; Check if any row is low
	breq nextcol

	ldi rmask, INITROWMASK	; If yes, find which row is low
	clr row					; Initialize for row check

rowloop:
	cpi row, 4
	breq nextcol
	mov temp2, temp1 
	and temp2, rmask 
	breq convert
	inc row
	lsl rmask
	jmp rowloop
	
nextcol:
	lsl cmask
	inc col
	jmp colloop

; in the convert session, all it does it find the
; char, and put it into the temp1 register, and
; rjmp to convert_end
convert:
	cpi col, 3
	breq letters
	cpi row, 3 
	breq symbols
	mov temp1, row 
	lsl temp1
	add temp1, row		; temp1 = row*3 + col
	add temp1, col 
	subi temp1, -'1'	; Add the value of character ‘1’
	jmp convert_end

letters:
	ldi temp1, 'A'
	add temp1, row
	jmp convert_end

symbols:
	cpi col, 0
	breq star
	cpi col, 1
	breq zero
	ldi temp1, '#'
	jmp convert_end

star:
	ldi temp1, '*'
	jmp convert_end

zero:
	ldi temp1, '0'

convert_end:
	out PORTC, temp1
	jmp main