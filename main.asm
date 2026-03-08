/*
* Proyecto01.asm
*
* Creado:
* Autor : Sebastiàn Ruano 
* Descripción: Reloj - inicio: horas 00, cuenta minutos rápido
*/
/****************************************/
.include "M328PDEF.inc"

/*********** Pines ***********/
.equ SEG_AF_MASK = 0b11111100                    ; PD2..PD7 = A..F
.equ DIG_MASK    = (1<<PB1)|(1<<PB2)|(1<<PB3)|(1<<PB4) ; PB1..PB4 = D9..D12

/*********** Constantes ***********/
.equ T1_PRELOAD_H = HIGH(0xF9E5)   ; 100ms con prescaler 1024 (1563 ticks)
.equ T1_PRELOAD_L = LOW(0xF9E5)
.equ FAST_MIN_TICKS = 5            ; 5 * 100ms = 500ms por minuto (rápido)

/****************************************/
.dseg
.org SRAM_START

mins:       .byte 1        ; 0..59
fastcnt:    .byte 1        ; 0..(FAST_MIN_TICKS-1)
mux:        .byte 1        ; 0..3

d0:         .byte 1        ; HH tens
d1:         .byte 1        ; HH units
d2:         .byte 1        ; MM tens
d3:         .byte 1        ; MM units

/****************************************/
.cseg
.org 0x0000
    RJMP RESET

.org OC0Aaddr
    RJMP TMR0_COMPA_ISR

.org OVF1addr
    RJMP TMR1_OVF_ISR

/****************************************/
// Stack
RESET:
LDI     R16, LOW(RAMEND)
STS     SPL, R16
LDI     R16, HIGH(RAMEND)
STS     SPH, R16

/****************************************/
// SETUP
SETUP:
    CLI

    ; ----- Segmentos A..F (PD2..PD7) salida -----
    IN      R16, DDRD
    ORI     R16, SEG_AF_MASK
    OUT     DDRD, R16

    ; Anodo común: apagar A..F = 1
    IN      R16, PORTD
    ORI     R16, SEG_AF_MASK
    OUT     PORTD, R16

    ; ----- Segmento G (PD0/RX) salida -----
    SBI     DDRD, DDD0
    ; apagar G = 1
    SBI     PORTD, PORTD0

    ; ----- Dígitos PB1..PB4 salida -----
    IN      R16, DDRB
    ORI     R16, DIG_MASK
    OUT     DDRB, R16

    ; OFF inicial (según tu prueba: OFF = 0, ON = 1)  <-- IMPORTANTE
    ; Como ya te funcionó en FASE 2 (ON=1), dejamos PB1..PB4 apagados en 0 al inicio:
    CBI     PORTB, PB1
    CBI     PORTB, PB2
    CBI     PORTB, PB3
    CBI     PORTB, PB4

    ; ----- Timer0 CTC 1ms (multiplex) -----
    LDI     R16, (1<<WGM01)
    STS     TCCR0A, R16
    LDI     R16, (1<<CS01)|(1<<CS00)     ; /64
    STS     TCCR0B, R16
    LDI     R16, 249
    STS     OCR0A, R16
    LDI     R16, (1<<OCIE0A)
    STS     TIMSK0, R16
    LDI     R16, (1<<OCF0A)
    STS     TIFR0, R16

    ; ----- Timer1 OVF ~100ms (para minutos rápidos) -----
    LDI     R16, 0x00
    STS     TCCR1A, R16
    LDI     R16, (1<<CS12)|(1<<CS10)     ; /1024
    STS     TCCR1B, R16

    LDI     R16, T1_PRELOAD_H
    STS     TCNT1H, R16
    LDI     R16, T1_PRELOAD_L
    STS     TCNT1L, R16

    LDI     R16, (1<<TOIE1)
    STS     TIMSK1, R16
    LDI     R16, (1<<TOV1)
    STS     TIFR1, R16

    ; ----- Inicializar reloj -----
    CLR     R16
    STS     mins, R16
    STS     fastcnt, R16
    STS     mux, R16

    ; Horas = 00
    CLR     R16
    STS     d0, R16
    STS     d1, R16

    ; Minutos = 00
    CLR     R16
    STS     d2, R16
    STS     d3, R16

    SEI
    RJMP MAIN_LOOP

/****************************************/
// Loop Infinito
MAIN_LOOP:
    RJMP MAIN_LOOP

/****************************************/
// Interrupt routines

; ---------------------------
; TIMER0 COMPA 1ms: multiplex 4 dígitos
; Nota: según tu prueba buena, dígito ON = 1, OFF = 0
; PB1..PB4: encender dígito con SBI, apagar con CBI
; ---------------------------
TMR0_COMPA_ISR:
    PUSH    R16
    PUSH    R17
    PUSH    R18
    PUSH    R30
    PUSH    R31

    ; Apagar todos los dígitos (OFF=0)
    CBI     PORTB, PB1
    CBI     PORTB, PB2
    CBI     PORTB, PB3
    CBI     PORTB, PB4

    ; Apagar todos los segmentos (anodo común: 1=apagado)
    IN      R16, PORTD
    ORI     R16, SEG_AF_MASK
    OUT     PORTD, R16
    SBI     PORTD, PORTD0        ; G apagado

        ; cargar mux index
    LDS     R16, mux

    ; seleccionar dígito y valor
    CPI     R16, 0
    BREQ    MUX_D0
    CPI     R16, 1
    BREQ    MUX_D1
    CPI     R16, 2
    BREQ    MUX_D2
    ; else -> 3
MUX_D3:
    LDS     R17, d3
    SBI     PORTB, PB4           ; D12 ON
    RJMP    LOAD_SEG

MUX_D2:
    LDS     R17, d2
    SBI     PORTB, PB3           ; D11 ON
    RJMP    LOAD_SEG

MUX_D1:
    LDS     R17, d1
    SBI     PORTB, PB2           ; D10 ON
    RJMP    LOAD_SEG

MUX_D0:
    LDS     R17, d0
    SBI     PORTB, PB1           ; D9 ON
 

LOAD_SEG:
    ; tabla anodo común: bit=0 encendido, bit=1 apagado
    LDI     ZH, HIGH(SEG_TAB_AN*2)
    LDI     ZL, LOW(SEG_TAB_AN*2)
    ADD     ZL, R17
    ADC     ZH, R1
    LPM     R18, Z               ; bits: 0=A 1=B 2=C 3=D 4=E 5=F 6=G

    ; aplicar A..F en PD2..PD7
    SBRS    R18, 0
    CBI     PORTD, PORTD2        ; A
    SBRS    R18, 1
    CBI     PORTD, PORTD3        ; B
    SBRS    R18, 2
    CBI     PORTD, PORTD4        ; C
    SBRS    R18, 3
    CBI     PORTD, PORTD5        ; D
    SBRS    R18, 4
    CBI     PORTD, PORTD6        ; E
    SBRS    R18, 5
    CBI     PORTD, PORTD7        ; F
    ; G en PD0
    SBRS    R18, 6
    CBI     PORTD, PORTD0        ; G

    ; mux++
    INC     R16
    CPI     R16, 4
    BRLO    MUX_STORE
    CLR     R16
MUX_STORE:
    STS     mux, R16

    POP     R31
    POP     R30
    POP     R18
    POP     R17
    POP     R16
    RETI

; ---------------------------
; TIMER1 OVF ~100ms: acelera conteo de minutos
; ---------------------------
TMR1_OVF_ISR:
    PUSH    R16
    PUSH    R17
    PUSH    R18

    ; recargar 100ms
    LDI     R16, T1_PRELOAD_H
    STS     TCNT1H, R16
    LDI     R16, T1_PRELOAD_L
    STS     TCNT1L, R16

    ; fastcnt++
    LDS     R16, fastcnt
    INC     R16
    CPI     R16, FAST_MIN_TICKS
    BRLO    FC_STORE

    ; llegó a FAST_MIN_TICKS -> minuto++
    CLR     R16
    STS     fastcnt, R16

    ; mins++
    LDS     R17, mins
    INC     R17
    CPI     R17, 60
    BRLO    MINS_OK
    CLR     R17
MINS_OK:
    STS     mins, R17

    ; convertir mins a decenas/unidades (restas de 10)
    MOV     R18, R17          ; tmp = mins
    CLR     R16               ; tens = 0
DIV10:
    CPI     R18, 10
    BRLO    DIV10_DONE
    SUBI    R18, 10
    INC     R16
    RJMP    DIV10
DIV10_DONE:
    ; d2 = tens, d3 = units
    STS     d2, R16
    STS     d3, R18

    RJMP    T1_EXIT

FC_STORE:
    STS     fastcnt, R16

T1_EXIT:
    POP     R18
    POP     R17
    POP     R16
    RETI

/****************************************/

SEG_TAB_AN:
    .db 0b1000000  ; 0
    .db 0b1111001  ; 1
    .db 0b0100100  ; 2
    .db 0b0110000  ; 3
    .db 0b0011001  ; 4
    .db 0b0010010  ; 5
    .db 0b0000010  ; 6
    .db 0b1111000  ; 7
    .db 0b0000000  ; 8
    .db 0b0010000  ; 9