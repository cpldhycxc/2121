
.include "m2560def.inc"

.macro do_lcd_command
	ldi temp1, @0
	rcall lcd_command
	rcall lcd_wait
.endmacro
.macro do_lcd_data
	mov temp1, @0
	rcall lcd_data
	rcall lcd_wait
.endmacro

.macro lcd_set
	sbi PORTA, @0
.endmacro
.macro lcd_clr
	cbi PORTA, @0
.endmacro

.def row = r16 
.def col = r17 
.def rmask = r18 
.def cmask = r19 
.def temp1 = r20 
.def temp2 = r21
.def acculmulator = r22
.def pressed_flag = r23
.def currNum = r24
.def result = r25
.equ PORTLDIR = 0b11110000 
.equ INITCOLMASK = 0b11101111 
.equ INITROWMASK = 0b00000001 
.equ ROWMASK = 0b00001111

.equ LCD_RS = 7
.equ LCD_E = 6
.equ LCD_RW = 5
.equ LCD_BE = 4

.org 0
	jmp RESET

RESET:
	ldi temp1, low(RAMEND) 
	out SPL, temp1
	ldi temp1, high(RAMEND)
	out SPH, temp1

	ldi temp1, PORTLDIR
	sts DDRL, temp1
	ser temp1
	out DDRF, temp1
	out DDRA, temp1
	out DDRC, temp1			; for debugging
	clr temp1
	out PORTF, temp1
	out PORTA, temp1

	do_lcd_command 0b00111000 ; 2x5x7
	rcall sleep_5ms
	do_lcd_command 0b00111000 ; 2x5x7
	rcall sleep_1ms
	do_lcd_command 0b00111000 ; 2x5x7
	do_lcd_command 0b00111000 ; 2x5x7
	do_lcd_command 0b00001000 ; display off?
	do_lcd_command 0b00000110 ; increment, no display shift
	do_lcd_command 0b00001110 ; Cursor on, bar, no blink
	rcall reset_display
	jmp reset_flag
	
; function refactored from RESET, inorder to reuse, therefore,
; at the end of RESET, it has to jmp to reset_flag
reset_display:
	clr acculmulator
	clr currNum
	; clear display and load 0 to the first line
	do_lcd_command 0b00000001 ; clear display
	ldi r16, '0'
	do_lcd_data r16
	do_lcd_command 0b11000000
	ret

reset_flag:
	clr pressed_flag
main:
	; initialize the stack
	ldi cmask, INITCOLMASK 
	clr col

colloop:
	cpi col, 4
	breq reset_flag 
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
	cpi pressed_flag, 1
	breq main
	ldi pressed_flag, 1
	cpi col, 3
	breq letters
	cpi row, 3 
	breq symbols
	mov temp1, row 
	lsl temp1
	add temp1, row		; temp1 = row*3 + col
	add temp1, col 
	rcall store_curr_num	; store the curr typed num
	subi temp1, -'1'	; Add the value of character ‘1’
	jmp convert_end

store_curr_num:
	push temp2
	ldi temp2, 10
	mul currNum, temp2
	mov currNum, r0
	inc temp1
	add currNum, temp1
	out PORTC, currNum	; debug
	dec temp1
	pop temp2
	ret

; all letters handle here
letters:
	cpi row, 0
	breq a_add
	cpi row, 1
	breq b_sub
	cpi row, 2
	breq c_mul
	cpi row, 3
	breq d_div
	;cpi row, 2
a_add:
	add acculmulator, currNum
	jmp command_end
b_sub:
	sub acculmulator, currNum
	jmp command_end
c_mul:
	mul acculmulator, currNum
	mov acculmulator, r0
	jmp command_end
d_div:
	cpi currNum, 0
	breq command_end
	mov temp1, acculmulator
	mov temp2, currNum
	rcall divide
	mov acculmulator, result
	jmp command_end
command_end:
	do_lcd_command 0b00000001
	rcall display_curr_num
	do_lcd_command 0b11000000
	clr currNum
	jmp main


symbols:
	cpi col, 0
	breq star
	cpi col, 1
	breq zero
	ldi temp1, '#'
	jmp convert_end
; press * to reset
star:
	rcall reset_display
	jmp main
zero:
	ldi temp1, -1
	rcall store_curr_num
	ldi temp1, '0'
convert_end:
	do_lcd_data temp1
	jmp main

; function used to display curr num
display_curr_num:
	push acculmulator
	push temp1
	push temp2
	clr temp2
	clr temp1
cp_hundred:
	cpi acculmulator, 100
	brlo finish_cp_hundred
	subi acculmulator, 100
	inc temp2				; for counting
	inc temp1				; ensure there is a bit in
	rjmp cp_hundred
finish_cp_hundred:
	cpi temp2, 0
	breq cp_ten
	subi temp2, -'0'
	do_lcd_data temp2
	clr temp2
cp_ten:
	cpi acculmulator, 10
	brlo finish_cp_ten
	subi acculmulator, 10
	inc temp2
	rjmp cp_ten
finish_cp_ten:
	cpi temp2, 0
	breq check_second
	subi temp2, -'0'
	do_lcd_data temp2
	jmp lt_ten
check_second:
	cpi temp1, 0
	breq lt_ten
	ldi temp2, '0'
	do_lcd_data temp2
lt_ten:
	subi acculmulator, -'1'
	dec acculmulator
	do_lcd_data acculmulator
	pop temp2
	pop temp1
	pop acculmulator
	ret

; takes temp1 as dividend, temp2 as divisor, result as return
divide:
	clr result
div_loop:
	cp temp1, temp2
	brlo div_return
	sub temp1, temp2
	inc result
	rjmp div_loop
div_return:
	ret


;;;;;;;;;;;;;;;;;;;;;;;;   LCD   ;;;;;;;;;;;;;;;;;;;
lcd_command:
	out PORTF, temp1
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	lcd_clr LCD_E
	rcall sleep_1ms
	ret

lcd_data:
	out PORTF, temp1
	lcd_set LCD_RS		; change to data input mode
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	lcd_clr LCD_E
	rcall sleep_1ms
	lcd_clr LCD_RS		; back to command mode
	ret

lcd_wait:
	push temp1
	clr temp1
	out DDRF, temp1
	out PORTF, temp1
	lcd_set LCD_RW
lcd_wait_loop:
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	in temp1, PINF
	lcd_clr LCD_E
	sbrc temp1, 7
	rjmp lcd_wait_loop
	lcd_clr LCD_RW
	ser temp1
	out DDRF, temp1
	pop temp1
	ret

.equ F_CPU = 16000000
.equ DELAY_1MS = F_CPU / 4 / 1000 - 4
; 4 cycles per iteration - setup/call-return overhead

sleep_1ms:
	push r24
	push r25
	ldi r25, high(DELAY_1MS)
	ldi r24, low(DELAY_1MS)
delayloop_1ms:
	sbiw r25:r24, 1
	brne delayloop_1ms
	pop r25
	pop r24
	ret

sleep_5ms:
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	ret