LCDLINE		EQU	40h				;16 Bytes
TF0OVF		EQU	50h

;RESET:***********************************************
		ORG	0000h
		AJMP	START

START:		ACALL	LCDCLEARBUFF
		ACALL	LCDINIT
START1:		ACALL	FREQUENCY
		AJMP	START1
		
FREQUENCY:	ACALL	FRQCOUNT
		MOV	R0,#LCDLINE+4			;Decimal buffer
FREQUENCY1:	ACALL	BIN2DEC
		MOV	R7,A				;Number of digits
		ACALL	FRQFORMAT
		MOV	A,#40h				;Output result
		ACALL	LCDSETADR
		MOV	R0,#LCDLINE
		MOV	R7,#10h
		ACALL	LCDPRINTSTR
		RET

;------------------------------------------------------------------
;Binary to decimal converter
;Converts R7:R6:R5:R4 to decimal pointed to by R0
;Returns with number of digits in A
;------------------------------------------------------------------
BIN2DEC:	PUSH	00h
		MOV	DPTR,#BINDEC
		MOV	R2,#0Ah
BIN2DEC1:	MOV	R3,#2Fh
BIN2DEC2:	INC	R3
		ACALL	SUBIT
		JNC	BIN2DEC2
		ACALL	ADDIT
		MOV	A,R3
		MOV	@R0,A
		INC	R0
		INC	DPTR
		INC	DPTR
		INC	DPTR
		INC	DPTR
		DJNZ	R2,BIN2DEC1
		POP	00h
		;Remove leading zeroes
		MOV	R2,#09h
BIN2DEC3:	MOV	A,@R0
		CJNE	A,#30h,BIN2DEC4
		MOV	@R0,#20h
		INC	R0
		DJNZ	R2,BIN2DEC3
BIN2DEC4:	INC	R2
		MOV	A,R2
		RET

SUBIT:		CLR	A
		MOVC	A,@A+DPTR
		XCH	A,R4
		CLR	C
		SUBB	A,R4
		MOV	R4,A
		MOV	A,#01h
		MOVC	A,@A+DPTR
		XCH	A,R5
		SUBB	A,R5
		MOV	R5,A
		MOV	A,#02h
		MOVC	A,@A+DPTR
		XCH	A,R6
		SUBB	A,R6
		MOV	R6,A
		MOV	A,#03h
		MOVC	A,@A+DPTR
		XCH	A,R7
		SUBB	A,R7
		MOV	R7,A
		RET

ADDIT:		CLR	A
		MOVC	A,@A+DPTR
		ADD	A,R4
		MOV	R4,A
		MOV	A,#01h
		MOVC	A,@A+DPTR
		ADDC	A,R5
		MOV	R5,A
		MOV	A,#02h
		MOVC	A,@A+DPTR
		ADDC	A,R6
		MOV	R6,A
		MOV	A,#03h
		MOVC	A,@A+DPTR
		ADDC	A,R7
		MOV	R7,A
		RET

;------------------------------------------------------------------
;Wait loop. Waits 1 second, 2 000 000 cycles on a 24 MHz MCU
;------------------------------------------------------------------
WAITASEC:	NOP
		MOV	R7,#96
		MOV	R6,#21
		MOV	R5,#6
WAITASEC1:	JBC	TCON.5,WAITASEC2
		SJMP	WAITASEC3
WAITASEC2:	INC	TF0OVF
		NOP
WAITASEC3:	DJNZ	R7,WAITASEC1
		DJNZ	R6,WAITASEC1
		DJNZ	R5,WAITASEC1
		RET

;------------------------------------------------------------------
;Frequency counter. LSB from 74HC590 read at P0, TL0, TH0 and
;TF0 bit. 25 bits total, max 33554431 Hz
;IN:	A Channel (0-3)
;OUT:	32 Bit result in R7:R6:R5:R4
;------------------------------------------------------------------
FRQCOUNT:	MOV	TL0,#00h
		MOV	TH0,#00h
		MOV	TF0OVF,#00h
		MOV	A,TMOD
		SETB	ACC.0				;M00
		CLR	ACC.1				;M01
		SETB	ACC.2				;C/T0#
		CLR	ACC.3				;GATE0
		MOV	TMOD,A
		MOV	A,TCON
		CLR	ACC.4				;TR0
		CLR	ACC.5				;TF0
		MOV	TCON,A
FRQCOUNT1:	SETB	TCON.4				;ENABLR TIMER0 COUNT
		ACALL	WAITASEC
		CLR	TCON.4				;DISABLE TIMER0 COUNT
FRQCOUNT2:	MOV	A,TL0				;8 BITS FROM TL0
		MOV	R4,A
		MOV	A,TH0				;8 BITS FROM TH0
		MOV	R5,A
		MOV	A,TF0OVF			;8 BITS
		MOV	R6,A
		CLR	A				;8 BITS
		MOV	R7,A
		RET

;------------------------------------------------------------------
;Format frequency conter text line
;	LCDLINE+4 Decimal result
;	R7 Number of digits
;OUT:	Formatted LCDLINE
;------------------------------------------------------------------
FRQFORMAT:	MOV	LCDLINE+0,#'F'
		MOV	LCDLINE+1,#'='
		MOV	LCDLINE+2,#' '
		MOV	R0,#LCDLINE+3
		MOV	R1,#LCDLINE+5
		CJNE	R7,#07h,$+3
		JC	FRQFORMATKHZ
		;MHz
		MOV	R7,#09h
FRQFORMATMHZ1:	MOV	A,@R1
		CJNE	R7,#06h,FRQFORMATMHZ2
		MOV	@R0,#'.'
		INC	R0
FRQFORMATMHZ2:	MOV	@R0,A
		INC	R0
		INC	R1
		DJNZ	R7,FRQFORMATMHZ1
		MOV	LCDLINE+13,#'M'
		MOV	LCDLINE+14,#'H'
		MOV	LCDLINE+15,#'z'
		SJMP	FRQFORMATDONE
FRQFORMATKHZ:	CJNE	R7,#04h,$+3
		JC	FRQFORMATHZ
		;KHz
		MOV	R7,#09h
FRQFORMATKHZ1:	MOV	A,@R1
		CJNE	R7,#03h,FRQFORMATKHZ2
		MOV	@R0,#'.'
		INC	R0
FRQFORMATKHZ2:	MOV	@R0,A
		INC	R0
		INC	R1
		DJNZ	R7,FRQFORMATKHZ1
		MOV	LCDLINE+13,#'K'
		MOV	LCDLINE+14,#'H'
		MOV	LCDLINE+15,#'z'
		SJMP	FRQFORMATDONE
FRQFORMATHZ:	;Hz
		INC	R0
		MOV	R7,#09h
FRQFORMATHZ1:	MOV	A,@R1
		MOV	@R0,A
		INC	R0
		INC	R1
		DJNZ	R7,FRQFORMATHZ1
		MOV	LCDLINE+13,#'H'
		MOV	LCDLINE+14,#'z'
		MOV	LCDLINE+15,#' '
FRQFORMATDONE:	RET

;------------------------------------------------------------------
;LCD Output.
;------------------------------------------------------------------
LCDDELAY:	PUSH	07h
		MOV	R7,#00h
		DJNZ	R7,$
		POP	07h
		RET

;A contains nibble, ACC.4 contains RS
LCDNIBOUT:	SETB	ACC.5				;E
		MOV	P2,A
		CLR	P2.5				;Negative edge on E
		RET

;A contains byte
LCDCMDOUT:	PUSH	ACC
		SWAP	A				;High nibble first
		ANL	A,#0Fh
		ACALL	LCDNIBOUT
		POP	ACC
		ANL	A,#0Fh
		ACALL	LCDNIBOUT
		ACALL	LCDDELAY			;Wait for BF to clear
		RET

;A contains byte
LCDCHROUT:	PUSH	ACC
		SWAP	A				;High nibble first
		ANL	A,#0Fh
		SETB	ACC.4				;RS
		ACALL	LCDNIBOUT
		POP	ACC
		ANL	A,#0Fh
		SETB	ACC.4				;RS
		ACALL	LCDNIBOUT
		ACALL	LCDDELAY			;Wait for BF to clear
		RET

LCDCLEAR:	MOV	A,#00000001b
		ACALL	LCDCMDOUT
		MOV	R7,#00h
LCDCLEAR1:	ACALL	LCDDELAY
		DJNZ	R7,LCDCLEAR1
		RET

;A contais address
LCDSETADR:	ORL	A,#10000000b
		ACALL	LCDCMDOUT
		RET

LCDPRINTSTR:	MOV	A,@R0
		ACALL	LCDCHROUT
		INC	R0
		DJNZ	R7,LCDPRINTSTR
		RET

PRNTCDPTRLCD:	CLR	A
		MOVC	A,@A+DPTR
		JZ	PRNTCDPTRLCD1
		ACALL	LCDCHROUT
		INC	DPTR
		SJMP	PRNTCDPTRLCD
PRNTCDPTRLCD1:	RET

LCDINIT:	MOV	A,#00000011b			;Function set
		ACALL	LCDNIBOUT
		ACALL	LCDDELAY			;Wait for BF to clear
		MOV	A,#00101000b
		ACALL	LCDCMDOUT
		MOV	A,#00101000b
		ACALL	LCDCMDOUT
		MOV	A,#00001100b			;Display ON/OFF
		ACALL	LCDCMDOUT
		ACALL	LCDCLEAR			;Clear
		MOV	A,#00000110b			;Cursor direction
		ACALL	LCDCMDOUT
		RET

LCDCLEARBUFF:	MOV	R0,#LCDLINE
		MOV	R7,#10h
		MOV	A,#20H
LCDCLEARBUFF1:	MOV	@R0,A
		INC	R0
		DJNZ	R7,LCDCLEARBUFF1
		RET

BINDEC:		DB	000h,0CAh,09Ah,03Bh		;1000000000
		DB	000h,0E1h,0F5h,005h		; 100000000
		DB	080h,096h,098h,000h		;  10000000
		DB	040h,042h,0Fh,0000h		;   1000000
		DB	0A0h,086h,001h,000h		;    100000
		DB	010h,027h,000h,000h		;     10000
		DB	0E8h,003h,000h,000h		;      1000
		DB	064h,000h,000h,000h		;       100
		DB	00Ah,000h,000h,000h		;        10
		DB	001h,000h,000h,000h		;         1

		END
