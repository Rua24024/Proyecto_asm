/*
* Proyecto01.asm
*
* Creado:
* Autor : Sebastiàn Ruano 
* Descripción: Proyecto 1 en asm, reloj y calendario
*/
/****************************************/
// Encabezado (Definición de Registros, Variables y Constantes)
.include "M328PDEF.inc"     // Include definitions specific to ATMega328P

.equ SEG_PD_MASK = 0b11111110                    ; PD2..PD7 = A..F

.equ DIG_MASK    = (1<<PB1)|(1<<PB2)|(1<<PB3)|(1<<PB4) ; PB1..PB4 = D9..D12 (transistores)

.equ BTN_MODE_M  = (1<<PB5)                      ; PB5 (D13) botón modo
.equ BTN_PC_MASK = (1<<PC0)|(1<<PC1)|(1<<PC2)|(1<<PC3) ; PC0..PC3 = A0..A3 botones
; PC4 = buzzer (salida)
; PC5 = LED1 (salida)
; PD0 = LED2 (salida)

/****************************************/
.dseg
.org    SRAM_START


/****************************************/
.cseg
.org 0x0000
/****************************************/
// Configuración de la pila
LDI     R16, LOW(RAMEND)
OUT     SPL, R16
LDI     R16, HIGH(RAMEND)
OUT     SPH, R16

/****************************************/
// Configuracion MCU
SETUP:
    CLI

    ; SALIDAS

    ; Segmentos A..G en PD1..PD7 (salida)
    IN      R16, DDRD
    ORI     R16, SEG_PD_MASK
    OUT     DDRD, R16

    ; Display ánodo común
    IN      R16, PORTD
    ORI     R16, SEG_PD_MASK
    OUT     PORTD, R16

    ; LED2 en PD0 (salida) - apagado
    SBI     DDRD, DDD0
    CBI     PORTD, PORTD0

    ; LEDS PB0 (salida) - apagado (1)
    SBI     DDRB, DDB0
    SBI     PORTB, PORTB0

    ; Transistores de dígitos PB1..PB4 (salida)
    IN      R16, DDRB
    ORI     R16, DIG_MASK
    OUT     DDRB, R16

    ; Estado inicial de transistores: OFF = 1 
    IN      R16, PORTB
    ORI     R16, DIG_MASK
    OUT     PORTB, R16

    ; Buzzer en PC4 (A4) (salida) - apagado
    SBI     DDRC, DDC4
    CBI     PORTC, PORTC4

    ; LED1 en PC5 (A5) (salida) - apagado
    SBI     DDRC, DDC5
    CBI     PORTC, PORTC5



    ; =========================
    ; ENTRADAS (pull-up)
    ; =========================

    ; Botón modo en PB5 (D13): entrada + pull-up
    CBI     DDRB, DDB5
    SBI     PORTB, PORTB5

    ; Botones en PC0..PC3 (A0..A3): entradas + pull-up
    IN      R16, DDRC
    ANDI    R16, 0b11110000              ; PC0..PC3 = input
    OUT     DDRC, R16

    IN      R16, PORTC
    ORI     R16, BTN_PC_MASK             ; pull-ups ON
    OUT     PORTC, R16

    ; TIMERS
    ; F_CPU = 16 MHz (Arduino UNO/Nano estándar)

    ; -------- TIMER0: CTC cada 1ms (para multiplex y scheduler) --------
    ;  OCR0A = 249
    LDI     R16, (1<<WGM01)              ; CTC
    STS     TCCR0A, R16
    LDI     R16, (1<<CS01)|(1<<CS00)     ; prescaler 64
    STS     TCCR0B, R16
    LDI     R16, 249
    STS     OCR0A, R16
    LDI     R16, (1<<OCIE0A)             ; habilitar ISR 
    STS     TIMSK0, R16
    ; limpiar flag 
    LDI     R16, (1<<OCF0A)
    STS     TIFR0, R16

    ; -------- TIMER1: Overflow cada 1s (tick de reloj) --------
    ; preload = 0xC2F7
    LDI     R16, 0x00
    STS     TCCR1A, R16                 ; normal
    LDI     R16, (1<<CS12)|(1<<CS10)    ; prescaler 1024
    STS     TCCR1B, R16

    LDI     R16, HIGH(0xC2F7)
    STS     TCNT1H, R16
    LDI     R16, LOW(0xC2F7)
    STS     TCNT1L, R16

    LDI     R16, (1<<TOIE1)             ; habilitar ISR OVF1
    STS     TIMSK1, R16
    ; limpiar flag por si acaso
    LDI     R16, (1<<TOV1)
    STS     TIFR1, R16

    SEI
