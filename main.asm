//*****************************************************************************
// Universidad del Valle de Guatemala
// IE2023 Programacion de Microcontroladores
// Autor: Edgar Chavarria 22055
// Proyecto: Post_lab03.asm
// Descripcion: Cronometro de 60 segundos con contador binario de 4 bits funcionando con interrupciones 
// Hardware: ATMega328P
// Created: 2/12/2024 4:30:52 PM
// Author : Samuel
//*****************************************************************************
// ENCABEZADO
//*****************************************************************************
.INCLUDE "M328PDEF.inc"
.CSEG
.ORG 0x00
JMP MAIN 
.ORG 0x0006 ; VECTOR DE INTERRUPCION DE BOTON
JMP ISR_PCINT0
.ORG 0x0020 ; VECTOR DE INTERRUPCION DE TIMER0
JMP ISR_TIMER0_OVF
//*****************************************************************************
// CONFIGURACION DE MCU 
//*****************************************************************************
MAIN:
	LDI R16, LOW(RAMEND)
	OUT SPL, R16
	LDI R17, HIGH(RAMEND)
	OUT SPH, R17 
//*****************************************************************************
SETUP: 
	; CAMBIAR LA FRECUENCIA DEL CRISTAL A 1MHz
	LDI R16, (1 << CLKPCE)
	STS CLKPR, R16

	LDI R16, 0b0000_0001
	STS CLKPR, R16 

	; ACTIVACION DE LOS PUERTOS TX Y RX PARA QUE SE PUEDAN USAR COMO PINES NORMALES
	LDI R16,0x00
	STS UCSR0B, R16

	;DECLARACION DE PUERTOS DE SALIDA 
	SBI DDRD, PD7
	SBI DDRD, PD6
	SBI DDRD, PD5
	SBI DDRD, PD4
	SBI DDRD, PD3
	SBI DDRD, PD2
	SBI DDRD, PD1
	; SALIDAS DE TRANSISTORES 
	SBI DDRB, PB3 ;TRANSISTOR DISP 1
	SBI DDRB, PB2 ;TRANSISTOR DISP 2



	; DECLARACION DE PUERTOS DE SALIDA DE CONTADOR BINARIO 
	SBI DDRC, PC0
	SBI DDRC, PC1
	SBI DDRC, PC2
	SBI DDRC, PC3
	
	; DECLARACION DE PUERTOS DE ENTRADA Y COMO PULL-UPS PARA BOTONES
	SBI PORTB, PB0
	CBI DDRB, PB0
	SBI PORTB, PB1
	CBI DDRB, PB1

	; HABILITAR PCINT0 Y PCINT1
	LDI R16, (1 << PCINT1)|(1 << PCINT0)
	STS PCMSK0, R16
	
	; HABILITAMOS LA ISR PCINT[7:0] O SEA HABILITAR LA INTERRUPCION DE BOTONES
	LDI R16, (1 << PCIE0)
	STS PCICR, R16

	CALL INIT_T0
	SEI				; HABILITAMOS TODAS LAS INTERRUPCIONES

	; CARGAR VALORES PARA LOS CONTADORES 
	LDI R20, 0x00 ; CONTADOR DE TIM0
	LDI R21, 0x00 ; CONTADOR DE 7SEG 
	LDI R22, 0 ; CONTADOR 0-9
	LDI R23, 0xEE ; CONTADOR DECENAS
	LDI R24, 0 ; CONTADOR DECENAS
	LDI R25, 0xEE ; CONTADOR DECENAS

	LDI R18, 0x00 ; SELECCION DE TRANSISTOR


	LDI R19, 0x00



	;CARGAR VALOR A DELAY
	LDI R29, 25
	LDI R30, 25
	LDI R31, 25


//*****************************************************************************
// LOOP 
//*****************************************************************************

LOOP3:
	CPI R20, 80 ;COMPARA HASTA QUE PASE UN SEGUNDO EN EL TIMER0 
	BRNE LOOP3
	CLR R20    ; BORRAMOS LO QUE CONTIENE EL REGISTRO 20 
	CPI R22, 9 ; COMPARAMOS HASTA 9 LO QUE SIGNIFICA QUE ES EL DISPLAY DE SEGUNDOS 
	BREQ CLEAR ; CUANDO LLEGUE VA BORRAR
	CALL INC_SEG ; SE USA PARA CAMBIAR EL VALOR DEL DISPLAY DE SEGUNDOS
	CPI R24, 6	; COMPARA HASTA QUE EL DISPLAY DE DECENAS LLEGUE A 6 
	BREQ CLEAR_R24	; BORRA EL REGISTRO DE LAS DECENAS
	OUT PORTC, R19	; MUESTRA LO QUE TIENE EL CONTADOR BINARIO 
	
	RJMP LOOP3

CLEAR:
	CLR R22				; BORRA EL REGISTRO QUE LLEVA LA CUENTA DE LOS SEGUNDOS
	LDI R23, 0xEE		; LE CARGA EL VALOR PARA QUE MUESTRE 0 
	CALL SUMA_DECENA	
	RJMP LOOP3 

CLEAR_R24:
	CLR R24			; BORRA EL REGISTRO DE DECENAS 
	LDI R25, 0xEE	; MUESTRA EL VALOR 0 
	RJMP LOOP3




//*****************************************************************************
// SUBRUTINAS 
//*****************************************************************************

SUMA_DECENA: 
	INC R24				; INCREMENTA EL REGISTRO DE CONTADOR DE LAS DECENAS 
	CALL PUN_TAB_DEC	; BUSCA EL NUMERO QUE NECESITA EL DISPLAY DE DECENAS

	RET

INC_SEG: 
	INC R22				; INCREMENTA EL REGISTRO DE LOS SEGUNDOS 
	CALL PUN_TAB_SEG	; BUSCA EL NUMERO QUE NECESITA MOSTRAR EN EL DISPLAY 
	RET


PUN_TAB_SEG:
	LDI ZH, HIGH(TABLA7SEG << 1)
	LDI ZL, LOW (TABLA7SEG << 1)
	ADD ZL, R22
	LPM R23, Z
	RET

PUN_TAB_DEC:
	LDI ZH, HIGH(TABLA7SEG << 1)
	LDI ZL, LOW(TABLA7SEG << 1)
	ADD ZL, R24
	LPM R25, Z
	RET

//*****************************************************************************
// SUBRUTINA DE ISR INT0
//*****************************************************************************
ISR_PCINT0:
	PUSH R16
	IN R16, SREG
	PUSH R16				; GUARDA LO QUE HABIA EN EL REGISTRO EN EL SREG
	
	IN R17, PINB		    ; LEEMOS LO QUE HAY EN EL PINB

	SBRC R17, PB1			; REVISAMOS SI EL BOTON DE INCREMENTAR ESTA PRECIONADO 
	RJMP CHECKPB0			; SI NO ESTA PRESIONADO SALTA A REVISAR EL BOTON DE RESTA
	INC R19					; SI ESTA PRESIONADO INCREMENTA EL CONTADOR 
	CPI R19, 0b0000_1111	; COMPARA SI YA LLEGO AL VALOR MAXIMO
	BRNE SALIR				; SI AUN NO LLEGA SALTA A SALIR 
	CLR R19					; SI YA LLEGO, BORRA EL REGISTRO DEL CONTADOR
	JMP SALIR				

CHECKPB0:
	SBRC R17, PB0			; REVISA SI EL BOTON DE RESTA ESTA PRESIONADO
	JMP SALIR				; SI NO ESTA PRESIONADO SE SALE DE LA INTERRUPCION
	DEC R19					; SI ESTA PRESIONADO LE RESTA AL CONTADOR
	BRNE SALIR				
	
	
SALIR:
	SBI PINB, PB5			; HACE UN TOGGLE 
	SBI PCIFR, PCIF0		; QUITA LA BANDERA DEL OVERFLOW

	POP R16
	OUT SREG, R16
	POP R16					; REGRESA LO QUE HABIA EN EL REGISTRO
	RETI


//*****************************************************************************


//*****************************************************************************
// SUBRUTINA PARA EL TIMER0
//*****************************************************************************
INIT_T0:
	LDI R16, (1 << CS02) | (1 << CS00)	; PONEMOS UN PRESCALER DE 1024
	OUT TCCR0B, R16						
		
	LDI R16, 99							; LE CARGAMOS EL VALOR DEL DESBORDAMIENTO
	OUT TCNT0, R16

	LDI R16, (1 << TOIE0)				
	STS TIMSK0, R16						; ACTIVAMOS LA INTERRUPCION DEL TIMER0
	RET

//*****************************************************************************
// SUBRUTINA DE TIMER0 OVERFLOW
//*****************************************************************************

ISR_TIMER0_OVF:
	PUSH R16
	IN R16, SREG
	PUSH R16			; GUARDAMOS EN EL SREG LO QUE TIENE EL R16

	LDI R16, 158		; EL VALOR DEL DESBORDAMIENTO
	OUT TCNT0, R16		
	SBI TIFR0, TOV0
	INC R20				; INCREMENTAMOS EL VALOR DEL CONTADOR QUE SE USA PARA VER SI YA TERMINA DE CONTAR EL TIMER0

	; LOOP PARA QUE SE ENCIENDAN Y SE APAGUEN LAS LEDS CONSTANTEMENTE
	; PRIMER SEGMENTO PARA ENCENDER EL PRIMER DISPLAY QUE ES EL DE SEGUNDOS
	LDI R18, 0b0000_1000  
	OUT PORTB, R18
	OUT PORTD, R25
	BREQ DELAY

; CON EL DELAY LO QUE LOGRAMOS ES QUE LOS DOS SE PERCIBAN QUE ESTAN ENCENDIDOS 
DELAY:
	DEC R29 
	CPI R29, 0
	BRNE Delay 
	LDI R29, 25
	DEC R30
	CPI R30, 0
	BRNE DELAY
	LDI R30, 25
	DEC R31 
	CPI R31, 0
	BRNE DELAY
	LDI R31, 25

; ENCENDEMOS EL OTRO DISPLAY DE DECENAS
	LDI R18, 0b0000_0100  ; ENCENDER DISPLAY 1
	OUT PORTB, R18
	OUT PORTD, R23

	
	
	POP R16
	OUT SREG, R16
	POP R16				;REGRESAMOS LO QUE TIENE EL REGISTRO ANTES DE LA INTERRUPCION
	RETI

//*****************************************************************************
// TABLA DE VALORES
//*****************************************************************************

TABLA7SEG: .DB/*0*/ 0xEE, /*1*/ 0x82, /*2*/ 0x76, /*3*/ 0xD6, /*4*/ 0x9A, /*5*/ 0xDC, /*6*/ 0xFC, /*7*/ 0x86, /*8*/ 0xFE, /*9*/ 0x9E
