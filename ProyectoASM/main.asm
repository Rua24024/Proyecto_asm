/*
* PROYECTO1.asm
*
* Creado: 
* Autor : José Sebastián Ruano Ruano
* Descripción: Proyecto 1, reloj en assembler
*
/****************************************/


.include "M328PDEF.inc"

/****************************************/
/* Constantes */
.equ T0_COMPARE   = 124
.equ T1_COMPARE_H = HIGH(7811)
.equ T1_COMPARE_L = LOW(7811)

/****************************************/
/* SRAM */
.dseg
.org SRAM_START
mux:            .byte 1
u_min:          .byte 1
d_min:          .byte 1
u_hor:          .byte 1
d_hor:          .byte 1
u_dia:          .byte 1
d_dia:          .byte 1
u_mes:          .byte 1
d_mes:          .byte 1
sec_cnt:        .byte 1
mode_view:      .byte 1

u_min_alarm:    .byte 1
d_min_alarm:    .byte 1
u_hor_alarm:    .byte 1
d_hor_alarm:    .byte 1
alarm_on:       .byte 1
alarm_enabled:  .byte 1
blink_500ms:    .byte 1

/****************************************/
/* Código */
.cseg
.org 0x0000
    RJMP RESET

.org 0x0016
    RJMP TMR1_ISR

.org 0x001C
    RJMP TMR0_ISR

/****************************************/
/* Reset */
/* Inicializa el stack pointer y salta a la configuración general del microcontrolador. */
RESET:
    LDI     R16, LOW(RAMEND)
    OUT     SPL, R16
    LDI     R16, HIGH(RAMEND)
    OUT     SPH, R16
    RJMP    SETUP

/****************************************/
/* Setup */
/* Configura puertos, estados iniciales, variables y temporizadores necesarios para el reloj. */
SETUP:
    CLI
    CLR     R1

    ; apagar UART para usar PD0/PD1 como GPIO
    LDI     R16, 0x00
    STS     UCSR0B, R16

    ; PORTB: PB0..PB5 como salidas
    LDI     R16, (1<<DDB0)|(1<<DDB1)|(1<<DDB2)|(1<<DDB3)|(1<<DDB4)|(1<<DDB5)
    OUT     DDRB, R16

    ; apagar D8, dígitos y buzzer
    CBI     PORTB, PORTB0
    CBI     PORTB, PORTB1
    CBI     PORTB, PORTB2
    CBI     PORTB, PORTB3
    CBI     PORTB, PORTB4
    CBI     PORTB, PORTB5

    ; PORTD: segmentos + TX1
    LDI     R16, 0xFF
    OUT     DDRD, R16

    ; apagar todos los segmentos, TX1 off
    LDI     R16, 0b11111101
    OUT     PORTD, R16

    ; A0..A4 entradas con pull-up
    CBI     DDRC, DDC0
    CBI     DDRC, DDC1
    CBI     DDRC, DDC2
    CBI     DDRC, DDC3
    CBI     DDRC, DDC4

    SBI     PORTC, PORTC0
    SBI     PORTC, PORTC1
    SBI     PORTC, PORTC2
    SBI     PORTC, PORTC3
    SBI     PORTC, PORTC4

    ; A5 = salida LED confirmación
    SBI     DDRC, DDC5
    CBI     PORTC, PORTC5

    ; variables en 0
    CLR     R16
    STS     mux, R16
    STS     u_min, R16
    STS     d_min, R16
    STS     u_hor, R16
    STS     d_hor, R16
    STS     sec_cnt, R16
    STS     mode_view, R16

    STS     u_min_alarm, R16
    STS     d_min_alarm, R16
    STS     u_hor_alarm, R16
    STS     d_hor_alarm, R16
    STS     alarm_on, R16
    STS     alarm_enabled, R16
	STS     blink_500ms, R16

    ; fecha inicial 01/01
    LDI     R16, 1
    STS     u_dia, R16
    STS     u_mes, R16
    CLR     R16
    STS     d_dia, R16
    STS     d_mes, R16

    ; TIMER0 -> multiplexado ~2ms
    LDI     R16, (1<<WGM01)
    OUT     TCCR0A, R16

    LDI     R16, (1<<CS02)
    OUT     TCCR0B, R16

    LDI     R16, T0_COMPARE
    OUT     OCR0A, R16

    CLR     R16
    OUT     TCNT0, R16

    LDI     R16, (1<<OCF0A)
    OUT     TIFR0, R16

    LDI     R16, (1<<OCIE0A)
    STS     TIMSK0, R16

    ; TIMER1 -> 1 segundo
    CLR     R16
    STS     TCCR1A, R16

    LDI     R16, (1<<WGM12)|(1<<CS12)|(1<<CS10)
    STS     TCCR1B, R16

    LDI     R16, T1_COMPARE_H
    STS     OCR1AH, R16
    LDI     R16, T1_COMPARE_L
    STS     OCR1AL, R16

    CLR     R16
    STS     TCNT1H, R16
    STS     TCNT1L, R16

    LDI     R16, (1<<OCIE1A)
    STS     TIMSK1, R16

    SEI

/****************************************/
/* Loop principal */
/* Bucle principal: revisa la variable mode_view y redirige al modo activo. */
MAIN_LOOP:

    LDS     R16, mode_view

    CPI     R16, 0
    BRNE    MAIN_CHECK_1
    RJMP    MODE_HORA_LOOP

MAIN_CHECK_1:
    CPI     R16, 1
    BRNE    MAIN_CHECK_2
    RJMP    MODE_FECHA_LOOP

MAIN_CHECK_2:
    CPI     R16, 2
    BRNE    MAIN_CHECK_3
    RJMP    MODE_CONFIG_HORA_LOOP

MAIN_CHECK_3:
    CPI     R16, 3
    BRNE    MAIN_CHECK_4
    RJMP    MODE_CONFIG_FECHA_LOOP

MAIN_CHECK_4:
    CPI     R16, 4
    BRNE    MAIN_CHECK_5
    RJMP    MODE_CONFIG_ALARMA_LOOP

MAIN_CHECK_5:
    RJMP    MODE_APAGAR_ALARMA_LOOP

/****************************************/
/* Modo hora */
/* Modo 0: muestra la hora y permite pasar al modo fecha con A4. */
MODE_HORA_LOOP:
    ; A4 -> fecha
    SBIC    PINC, PINC4
    RJMP    MAIN_LOOP
    RCALL   DEBOUNCE_DELAY
    SBIC    PINC, PINC4
    RJMP    MAIN_LOOP
    LDI     R16, 1
    STS     mode_view, R16
WAIT_RELEASE_A4_FROM_HORA:
    SBIS    PINC, PINC4
    RJMP    WAIT_RELEASE_A4_FROM_HORA
    RJMP    MAIN_LOOP

/****************************************/
/* Modo fecha */
/* Modo 1: muestra la fecha y permite pasar a configuración de hora con A4. */
MODE_FECHA_LOOP:
    ; A4 -> config hora
    SBIC    PINC, PINC4
    RJMP    MAIN_LOOP
    RCALL   DEBOUNCE_DELAY
    SBIC    PINC, PINC4
    RJMP    MAIN_LOOP
    LDI     R16, 2
    STS     mode_view, R16
WAIT_RELEASE_A4_FROM_FECHA:
    SBIS    PINC, PINC4
    RJMP    WAIT_RELEASE_A4_FROM_FECHA
    RJMP    MAIN_LOOP

/****************************************/
/* Config hora */
/* Modo 2: permite editar horas y minutos con A0..A3; A4 cambia al modo de configuración de fecha. */
MODE_CONFIG_HORA_LOOP:
    ; A4 -> config fecha
    SBIC    PINC, PINC4
    RJMP    CHECK_A0_H
    RCALL   DEBOUNCE_DELAY
    SBIC    PINC, PINC4
    RJMP    CHECK_A0_H
    LDI     R16, 3
    STS     mode_view, R16
WAIT_RELEASE_A4_FROM_CONFIG_HORA:
    SBIS    PINC, PINC4
    RJMP    WAIT_RELEASE_A4_FROM_CONFIG_HORA
    RJMP    MAIN_LOOP

CHECK_A0_H:
    SBIC    PINC, PINC0
    RJMP    CHECK_A1_H
    RCALL   DEBOUNCE_DELAY
    SBIC    PINC, PINC0
    RJMP    CHECK_A1_H
    RCALL   INC_MIN
WAIT_RELEASE_A0_H:
    SBIS    PINC, PINC0
    RJMP    WAIT_RELEASE_A0_H
    RJMP    MAIN_LOOP

CHECK_A1_H:
    SBIC    PINC, PINC1
    RJMP    CHECK_A2_H
    RCALL   DEBOUNCE_DELAY
    SBIC    PINC, PINC1
    RJMP    CHECK_A2_H
    RCALL   DEC_MIN
WAIT_RELEASE_A1_H:
    SBIS    PINC, PINC1
    RJMP    WAIT_RELEASE_A1_H
    RJMP    MAIN_LOOP

CHECK_A2_H:
    SBIC    PINC, PINC2
    RJMP    CHECK_A3_H
    RCALL   DEBOUNCE_DELAY
    SBIC    PINC, PINC2
    RJMP    CHECK_A3_H
    RCALL   INC_HOUR
WAIT_RELEASE_A2_H:
    SBIS    PINC, PINC2
    RJMP    WAIT_RELEASE_A2_H
    RJMP    MAIN_LOOP

CHECK_A3_H:
    SBIC    PINC, PINC3
    RJMP    MAIN_LOOP
    RCALL   DEBOUNCE_DELAY
    SBIC    PINC, PINC3
    RJMP    MAIN_LOOP
    RCALL   DEC_HOUR
WAIT_RELEASE_A3_H:
    SBIS    PINC, PINC3
    RJMP    WAIT_RELEASE_A3_H
    RJMP    MAIN_LOOP

/****************************************/
/* Config fecha */
/* Modo 3: permite editar día y mes con A0..A3; A4 cambia al modo de configuración de alarma. */
MODE_CONFIG_FECHA_LOOP:
    ; A4 -> config alarma
    SBIC    PINC, PINC4
    RJMP    CHECK_A0_F
    RCALL   DEBOUNCE_DELAY
    SBIC    PINC, PINC4
    RJMP    CHECK_A0_F
    LDI     R16, 4
    STS     mode_view, R16
WAIT_RELEASE_A4_FROM_CONFIG_FECHA:
    SBIS    PINC, PINC4
    RJMP    WAIT_RELEASE_A4_FROM_CONFIG_FECHA
    RJMP    MAIN_LOOP

CHECK_A0_F:
    SBIC    PINC, PINC0
    RJMP    CHECK_A1_F
    RCALL   DEBOUNCE_DELAY
    SBIC    PINC, PINC0
    RJMP    CHECK_A1_F
    RCALL   INC_DAY
WAIT_RELEASE_A0_F:
    SBIS    PINC, PINC0
    RJMP    WAIT_RELEASE_A0_F
    RJMP    MAIN_LOOP

CHECK_A1_F:
    SBIC    PINC, PINC1
    RJMP    CHECK_A2_F
    RCALL   DEBOUNCE_DELAY
    SBIC    PINC, PINC1
    RJMP    CHECK_A2_F
    RCALL   DEC_DAY
WAIT_RELEASE_A1_F:
    SBIS    PINC, PINC1
    RJMP    WAIT_RELEASE_A1_F
    RJMP    MAIN_LOOP

CHECK_A2_F:
    SBIC    PINC, PINC2
    RJMP    CHECK_A3_F
    RCALL   DEBOUNCE_DELAY
    SBIC    PINC, PINC2
    RJMP    CHECK_A3_F
    RCALL   INC_MONTH
WAIT_RELEASE_A2_F:
    SBIS    PINC, PINC2
    RJMP    WAIT_RELEASE_A2_F
    RJMP    MAIN_LOOP

CHECK_A3_F:
    SBIC    PINC, PINC3
    RJMP    MAIN_LOOP
    RCALL   DEBOUNCE_DELAY
    SBIC    PINC, PINC3
    RJMP    MAIN_LOOP
    RCALL   DEC_MONTH
WAIT_RELEASE_A3_F:
    SBIS    PINC, PINC3
    RJMP    WAIT_RELEASE_A3_F
    RJMP    MAIN_LOOP

/****************************************/
/* Config alarma */
/* Modo 4: permite editar la hora de la alarma con A0..A3; A4 cambia al modo de apagar alarma. */
MODE_CONFIG_ALARMA_LOOP:
    ; A4 -> modo apagar alarma
    SBIC    PINC, PINC4
    RJMP    CHECK_A0_A
    RCALL   DEBOUNCE_DELAY
    SBIC    PINC, PINC4
    RJMP    CHECK_A0_A

    LDI     R16, 5
    STS     mode_view, R16

WAIT_RELEASE_A4_FROM_CONFIG_ALARMA_MODE:
    SBIS    PINC, PINC4
    RJMP    WAIT_RELEASE_A4_FROM_CONFIG_ALARMA_MODE
    RJMP    MAIN_LOOP

CHECK_A0_A:
    SBIC    PINC, PINC0
    RJMP    CHECK_A1_A
    RCALL   DEBOUNCE_DELAY
    SBIC    PINC, PINC0
    RJMP    CHECK_A1_A
    RCALL   INC_MIN_ALARM
WAIT_RELEASE_A0_A:
    SBIS    PINC, PINC0
    RJMP    WAIT_RELEASE_A0_A
    RJMP    MAIN_LOOP

CHECK_A1_A:
    SBIC    PINC, PINC1
    RJMP    CHECK_A2_A
    RCALL   DEBOUNCE_DELAY
    SBIC    PINC, PINC1
    RJMP    CHECK_A2_A
    RCALL   DEC_MIN_ALARM
WAIT_RELEASE_A1_A:
    SBIS    PINC, PINC1
    RJMP    WAIT_RELEASE_A1_A
    RJMP    MAIN_LOOP

CHECK_A2_A:
    SBIC    PINC, PINC2
    RJMP    CHECK_A3_A
    RCALL   DEBOUNCE_DELAY
    SBIC    PINC, PINC2
    RJMP    CHECK_A3_A
    RCALL   INC_HOUR_ALARM
WAIT_RELEASE_A2_A:
    SBIS    PINC, PINC2
    RJMP    WAIT_RELEASE_A2_A
    RJMP    MAIN_LOOP

CHECK_A3_A:
    SBIC    PINC, PINC3
    RJMP    MAIN_LOOP
    RCALL   DEBOUNCE_DELAY
    SBIC    PINC, PINC3
    RJMP    MAIN_LOOP
    RCALL   DEC_HOUR_ALARM
WAIT_RELEASE_A3_A:
    SBIS    PINC, PINC3
    RJMP    WAIT_RELEASE_A3_A
    RJMP    MAIN_LOOP

/****************************************/
/* Apagar alarma */
/* Modo 5: permite apagar la alarma con A0 y volver al modo hora con A4. */
MODE_APAGAR_ALARMA_LOOP:
    ; si ya está apagada, asegurar buzzer off
    LDS     R16, alarm_enabled
    CPI     R16, 0
    BRNE    MODE5_CHECK_A0
    CBI     PORTB, PORTB5

MODE5_CHECK_A0:
    ; A0 = apagar alarma
    SBIC    PINC, PINC0
    RJMP    MODE5_CHECK_A4

    RCALL   DEBOUNCE_DELAY
    SBIC    PINC, PINC0
    RJMP    MODE5_CHECK_A4

    ; apagar ambas banderas
    CLR     R16
    STS     alarm_enabled, R16
    STS     alarm_on, R16
    CBI     PORTB, PORTB5

    ; LEDs de confirmación
    SBI     PORTD, PORTD1
    SBI     PORTC, PORTC5
    RCALL   DELAY_1S_VISUAL
    CBI     PORTD, PORTD1
    CBI     PORTC, PORTC5

WAIT_RELEASE_A0_MODE5:
    SBIS    PINC, PINC0
    RJMP    WAIT_RELEASE_A0_MODE5
    RJMP    MAIN_LOOP

MODE5_CHECK_A4:
    ; A4 = volver a hora
    SBIC    PINC, PINC4
    RJMP    MAIN_LOOP

    RCALL   DEBOUNCE_DELAY
    SBIC    PINC, PINC4
    RJMP    MAIN_LOOP

    CLR     R16
    STS     mode_view, R16

WAIT_RELEASE_A4_FROM_MODE5:
    SBIS    PINC, PINC4
    RJMP    WAIT_RELEASE_A4_FROM_MODE5
    RJMP    MAIN_LOOP

/* Retardo aproximado de 1 segundo para mantener visibles los LEDs de confirmación. */
DELAY_1S_VISUAL:
    LDI     R22, 4
D1S_LOOP:
    RCALL   DELAY_250MS_PLAIN
    DEC     R22
    BRNE    D1S_LOOP
    RET

/* Retardo simple aproximado de 250 ms usado por el retardo visual de 1 segundo. */
DELAY_250MS_PLAIN:
    LDI     R23, 80
D250P_OUTER:
    LDI     R24, 255
D250P_INNER:
    DEC     R24
    BRNE    D250P_INNER
    DEC     R23
    BRNE    D250P_OUTER
    RET
/****************************************/
/* Antirrebote y timing */
/* Retardo de antirrebote para confirmar que un botón realmente fue presionado. */
DEBOUNCE_DELAY:
    LDI     R20, 60
DLY1:
    LDI     R21, 255
DLY2:
    DEC     R21
    BRNE    DLY2
    DEC     R20
    BRNE    DLY1
    RET




/****************************************/
/* Subrutinas display */
/* Apaga los cuatro dígitos del display antes de multiplexar el siguiente. */
DIGITS_OFF:
    IN      R18, PORTB
    ANDI    R18, 0b11100001
    OUT     PORTB, R18
    RET

/* Enciende el dígito de unidades de minuto. */
DIGIT_UM_ON:
    IN      R18, PORTB
    ANDI    R18, 0b11100001
    ORI     R18, (1<<PB4)
    OUT     PORTB, R18
    RET

/* Enciende el dígito de decenas de minuto. */
DIGIT_DM_ON:
    IN      R18, PORTB
    ANDI    R18, 0b11100001
    ORI     R18, (1<<PB3)
    OUT     PORTB, R18
    RET

/* Enciende el dígito de unidades de hora o día, según el modo. */
DIGIT_UH_ON:
    IN      R18, PORTB
    ANDI    R18, 0b11100001
    ORI     R18, (1<<PB2)
    OUT     PORTB, R18
    RET

/* Enciende el dígito de decenas de hora o día, según el modo. */
DIGIT_DH_ON:
    IN      R18, PORTB
    ANDI    R18, 0b11100001
    ORI     R18, (1<<PB1)
    OUT     PORTB, R18
    RET

/* Escribe el patrón de segmentos para un display de 7 segmentos de ánodo común. */
SEG7_WRITE:
    PUSH    R18
    PUSH    R19

    ; conservar PD1 y apagar solo segmentos
    IN      R19, PORTD
    ANDI    R19, (1<<PD1)
    ORI     R19, 0b11111101
    OUT     PORTD, R19

    SBRS    R16, 0
    CBI     PORTD, PORTD2
    SBRS    R16, 1
    CBI     PORTD, PORTD3
    SBRS    R16, 2
    CBI     PORTD, PORTD4
    SBRS    R16, 3
    CBI     PORTD, PORTD5
    SBRS    R16, 4
    CBI     PORTD, PORTD6
    SBRS    R16, 5
    CBI     PORTD, PORTD7
    SBRS    R16, 6
    CBI     PORTD, PORTD0

    POP     R19
    POP     R18
    RET

/* Convierte un número decimal de 0 a 9 al patrón de segmentos usando la tabla TABLA. */
SEG7_DECODE:
    PUSH    ZL
    PUSH    ZH
    LDI     ZH, HIGH(TABLA*2)
    LDI     ZL, LOW(TABLA*2)
    ADD     ZL, R16
    ADC     ZH, R1
    LPM     R16, Z
    POP     ZH
    POP     ZL
    RET

/****************************************/
/* Ajuste hora */
/* Incrementa los minutos con aritmética decimal en BCD sin exceder 59. */
INC_MIN:
    LDS     R16, u_min
    LDS     R17, d_min
    INC     R16
    CPI     R16, 10
    BRLO    SAVE_INC_MIN
    CLR     R16
    INC     R17
    CPI     R17, 6
    BRLO    SAVE_INC_MIN
    CLR     R17
SAVE_INC_MIN:
    STS     u_min, R16
    STS     d_min, R17
    RET

/* Decrementa los minutos con aritmética decimal en BCD y hace wrap de 00 a 59. */
DEC_MIN:
    LDS     R16, u_min
    LDS     R17, d_min
    TST     R16
    BRNE    DEC_MIN_ONLY_UNIT
    TST     R17
    BRNE    DEC_MIN_BORROW
    LDI     R16, 9
    LDI     R17, 5
    RJMP    SAVE_DEC_MIN
DEC_MIN_BORROW:
    LDI     R16, 9
    DEC     R17
    RJMP    SAVE_DEC_MIN
DEC_MIN_ONLY_UNIT:
    DEC     R16
SAVE_DEC_MIN:
    STS     u_min, R16
    STS     d_min, R17
    RET

/* Incrementa la hora en formato de 24 horas, de 00 a 23. */
INC_HOUR:
    LDS     R16, u_hor
    LDS     R17, d_hor
    CPI     R17, 2
    BRNE    INC_HOUR_NORMAL
    CPI     R16, 3
    BRNE    INC_HOUR_NORMAL
    CLR     R16
    CLR     R17
    RJMP    SAVE_INC_HOUR
INC_HOUR_NORMAL:
    INC     R16
    CPI     R17, 2
    BRNE    INC_HOUR_CHECK_10
    CPI     R16, 4
    BRLO    SAVE_INC_HOUR
    CLR     R16
    CLR     R17
    RJMP    SAVE_INC_HOUR
INC_HOUR_CHECK_10:
    CPI     R16, 10
    BRLO    SAVE_INC_HOUR
    CLR     R16
    INC     R17
SAVE_INC_HOUR:
    STS     u_hor, R16
    STS     d_hor, R17
    RET

/* Decrementa la hora en formato de 24 horas, de 00 a 23 con wrap. */
DEC_HOUR:
    LDS     R16, u_hor
    LDS     R17, d_hor
    TST     R16
    BRNE    DEC_HOUR_UNIT_ONLY
    TST     R17
    BRNE    DEC_HOUR_BORROW
    LDI     R16, 3
    LDI     R17, 2
    RJMP    SAVE_DEC_HOUR
DEC_HOUR_BORROW:
    CPI     R17, 1
    BREQ    SET_09
    CPI     R17, 2
    BREQ    SET_19
    RJMP    SAVE_DEC_HOUR
SET_09:
    LDI     R16, 9
    CLR     R17
    RJMP    SAVE_DEC_HOUR
SET_19:
    LDI     R16, 9
    LDI     R17, 1
    RJMP    SAVE_DEC_HOUR
DEC_HOUR_UNIT_ONLY:
    DEC     R16
SAVE_DEC_HOUR:
    STS     u_hor, R16
    STS     d_hor, R17
    RET

/****************************************/
/* Ajuste alarma */
/* Incrementa los minutos de la alarma y habilita la alarma. */
INC_MIN_ALARM:
    LDS     R16, u_min_alarm
    LDS     R17, d_min_alarm
    INC     R16
    CPI     R16, 10
    BRLO    SAVE_INC_MIN_ALARM
    CLR     R16
    INC     R17
    CPI     R17, 6
    BRLO    SAVE_INC_MIN_ALARM
    CLR     R17
SAVE_INC_MIN_ALARM:
    STS     u_min_alarm, R16
    STS     d_min_alarm, R17
    LDI     R18, 1
    STS     alarm_enabled, R18
    RET

/* Decrementa los minutos de la alarma y mantiene la alarma habilitada. */
DEC_MIN_ALARM:
    LDS     R16, u_min_alarm
    LDS     R17, d_min_alarm
    TST     R16
    BRNE    DEC_MIN_ALARM_ONLY_UNIT
    TST     R17
    BRNE    DEC_MIN_ALARM_BORROW
    LDI     R16, 9
    LDI     R17, 5
    RJMP    SAVE_DEC_MIN_ALARM
DEC_MIN_ALARM_BORROW:
    LDI     R16, 9
    DEC     R17
    RJMP    SAVE_DEC_MIN_ALARM
DEC_MIN_ALARM_ONLY_UNIT:
    DEC     R16
SAVE_DEC_MIN_ALARM:
    STS     u_min_alarm, R16
    STS     d_min_alarm, R17
    LDI     R18, 1
    STS     alarm_enabled, R18
    RET

/* Incrementa la hora de la alarma en formato de 24 horas y habilita la alarma. */
INC_HOUR_ALARM:
    LDS     R16, u_hor_alarm
    LDS     R17, d_hor_alarm
    CPI     R17, 2
    BRNE    INC_HOUR_ALARM_NORMAL
    CPI     R16, 3
    BRNE    INC_HOUR_ALARM_NORMAL
    CLR     R16
    CLR     R17
    RJMP    SAVE_INC_HOUR_ALARM
INC_HOUR_ALARM_NORMAL:
    INC     R16
    CPI     R17, 2
    BRNE    INC_HOUR_ALARM_CHECK10
    CPI     R16, 4
    BRLO    SAVE_INC_HOUR_ALARM
    CLR     R16
    CLR     R17
    RJMP    SAVE_INC_HOUR_ALARM
INC_HOUR_ALARM_CHECK10:
    CPI     R16, 10
    BRLO    SAVE_INC_HOUR_ALARM
    CLR     R16
    INC     R17
SAVE_INC_HOUR_ALARM:
    STS     u_hor_alarm, R16
    STS     d_hor_alarm, R17
    LDI     R18, 1
    STS     alarm_enabled, R18
    RET

/* Decrementa la hora de la alarma en formato de 24 horas y habilita la alarma. */
DEC_HOUR_ALARM:
    LDS     R16, u_hor_alarm
    LDS     R17, d_hor_alarm
    TST     R16
    BRNE    DEC_HOUR_ALARM_UNIT_ONLY
    TST     R17
    BRNE    DEC_HOUR_ALARM_BORROW
    LDI     R16, 3
    LDI     R17, 2
    RJMP    SAVE_DEC_HOUR_ALARM
DEC_HOUR_ALARM_BORROW:
    CPI     R17, 1
    BREQ    SET_09_ALARM
    CPI     R17, 2
    BREQ    SET_19_ALARM
    RJMP    SAVE_DEC_HOUR_ALARM
SET_09_ALARM:
    LDI     R16, 9
    CLR     R17
    RJMP    SAVE_DEC_HOUR_ALARM
SET_19_ALARM:
    LDI     R16, 9
    LDI     R17, 1
    RJMP    SAVE_DEC_HOUR_ALARM
DEC_HOUR_ALARM_UNIT_ONLY:
    DEC     R16
SAVE_DEC_HOUR_ALARM:
    STS     u_hor_alarm, R16
    STS     d_hor_alarm, R17
    LDI     R18, 1
    STS     alarm_enabled, R18
    RET

/****************************************/
/* Ajuste fecha */
/* Determina el máximo día válido del mes actual: 28, 30 o 31. */
GET_MAX_DAY:
    LDS     R16, d_mes
    CPI     R16, 0
    BRNE    GET_MONTH_10_12

    LDS     R16, u_mes
    CPI     R16, 2
    BREQ    MAX_28
    CPI     R16, 4
    BREQ    MAX_30
    CPI     R16, 6
    BREQ    MAX_30
    CPI     R16, 9
    BREQ    MAX_30
    RJMP    MAX_31

GET_MONTH_10_12:
    LDS     R16, u_mes
    CPI     R16, 1
    BREQ    MAX_30
    RJMP    MAX_31

MAX_28:
    LDI     R19, 28
    RET
MAX_30:
    LDI     R19, 30
    RET
MAX_31:
    LDI     R19, 31
    RET

/* Corrige el día actual si el nuevo mes no soporta el valor almacenado. */
ADJUST_DAY_TO_MONTH:
    RCALL   GET_MAX_DAY
    LDS     R16, d_dia
    LDS     R17, u_dia

    CPI     R19, 28
    BREQ    ADJ_TO_28
    CPI     R19, 30
    BREQ    ADJ_TO_30
    RET

ADJ_TO_28:
    CPI     R16, 2
    BRLO    ADJ_DONE
    BRNE    FORCE_28
    CPI     R17, 9
    BRLO    ADJ_DONE
FORCE_28:
    LDI     R16, 2
    LDI     R17, 8
    RJMP    ADJ_SAVE

ADJ_TO_30:
    CPI     R16, 3
    BRLO    ADJ_DONE
    BRNE    FORCE_30
    CPI     R17, 1
    BRLO    ADJ_DONE
FORCE_30:
    LDI     R16, 3
    CLR     R17
    RJMP    ADJ_SAVE

ADJ_DONE:
    RET

ADJ_SAVE:
    STS     d_dia, R16
    STS     u_dia, R17
    RET

/* Incrementa el día respetando la cantidad de días válida del mes actual. */
INC_DAY:
    RCALL   GET_MAX_DAY
    LDS     R16, d_dia
    LDS     R17, u_dia

    CPI     R16, 3
    BRNE    INC_DAY_NOT_30S
    CPI     R17, 1
    BREQ    INC_DAY_WRAP31
    CPI     R17, 0
    BREQ    INC_DAY_WRAP30
INC_DAY_NOT_30S:
    CPI     R16, 2
    BRNE    INC_DAY_NORMAL
    CPI     R17, 8
    BREQ    INC_DAY_WRAP28

INC_DAY_NORMAL:
    INC     R17
    CPI     R17, 10
    BRLO    SAVE_INC_DAY
    CLR     R17
    INC     R16
    RJMP    SAVE_INC_DAY

INC_DAY_WRAP28:
    CPI     R19, 28
    BRNE    INC_DAY_NORMAL
    LDI     R17, 1
    CLR     R16
    RJMP    SAVE_INC_DAY

INC_DAY_WRAP30:
    CPI     R19, 30
    BRNE    INC_DAY_NORMAL
    LDI     R17, 1
    CLR     R16
    RJMP    SAVE_INC_DAY

INC_DAY_WRAP31:
    CPI     R19, 31
    BRNE    INC_DAY_NORMAL
    LDI     R17, 1
    CLR     R16

SAVE_INC_DAY:
    STS     d_dia, R16
    STS     u_dia, R17
    RET

/* Decrementa el día respetando la cantidad de días válida del mes actual. */
DEC_DAY:
    RCALL   GET_MAX_DAY
    LDS     R16, d_dia
    LDS     R17, u_dia

    CPI     R16, 0
    BRNE    DEC_DAY_NORMAL
    CPI     R17, 1
    BRNE    DEC_DAY_NORMAL

    CPI     R19, 28
    BREQ    SET_DAY_28
    CPI     R19, 30
    BREQ    SET_DAY_30
    LDI     R16, 3
    LDI     R17, 1
    RJMP    SAVE_DEC_DAY

SET_DAY_28:
    LDI     R16, 2
    LDI     R17, 8
    RJMP    SAVE_DEC_DAY

SET_DAY_30:
    LDI     R16, 3
    CLR     R17
    RJMP    SAVE_DEC_DAY

DEC_DAY_NORMAL:
    TST     R17
    BRNE    DEC_DAY_UNIT
    LDI     R17, 9
    DEC     R16
    RJMP    SAVE_DEC_DAY

DEC_DAY_UNIT:
    DEC     R17

SAVE_DEC_DAY:
    STS     d_dia, R16
    STS     u_dia, R17
    RET

/* Incrementa el mes de 01 a 12 y ajusta el día si es necesario. */
INC_MONTH:
    LDS     R16, d_mes
    LDS     R17, u_mes
    CPI     R16, 1
    BRNE    INC_MONTH_NORMAL
    CPI     R17, 2
    BRNE    INC_MONTH_NORMAL
    CLR     R16
    LDI     R17, 1
    RJMP    SAVE_INC_MONTH

INC_MONTH_NORMAL:
    INC     R17
    CPI     R17, 10
    BRLO    SAVE_INC_MONTH
    CLR     R17
    INC     R16

SAVE_INC_MONTH:
    STS     d_mes, R16
    STS     u_mes, R17
    RCALL   ADJUST_DAY_TO_MONTH
    RET

/* Decrementa el mes de 12 a 01 y ajusta el día si es necesario. */
DEC_MONTH:
    LDS     R16, d_mes
    LDS     R17, u_mes
    CPI     R16, 0
    BRNE    DEC_MONTH_NORMAL
    CPI     R17, 1
    BRNE    DEC_MONTH_NORMAL
    LDI     R16, 1
    LDI     R17, 2
    RJMP    SAVE_DEC_MONTH

DEC_MONTH_NORMAL:
    CPI     R17, 0
    BRNE    DEC_MONTH_UNIT
    LDI     R17, 9
    DEC     R16
    RJMP    SAVE_DEC_MONTH

DEC_MONTH_UNIT:
    DEC     R17

SAVE_DEC_MONTH:
    STS     d_mes, R16
    STS     u_mes, R17
    RCALL   ADJUST_DAY_TO_MONTH
    RET

/****************************************/
/* Fecha automática */
/* Incrementa la fecha automáticamente cuando la hora pasa de 23:59 a 00:00. */
INC_DATE:
    RCALL   GET_MAX_DAY

    LDS     R16, d_dia
    LDS     R17, u_dia

    CPI     R19, 28
    BREQ    CHECK_LAST_28
    CPI     R19, 30
    BREQ    CHECK_LAST_30
    RJMP    CHECK_LAST_31

CHECK_LAST_28:
    CPI     R16, 2
    BRNE    INC_DATE_NORMAL
    CPI     R17, 8
    BREQ    NEXT_MONTH
    RJMP    INC_DATE_NORMAL

CHECK_LAST_30:
    CPI     R16, 3
    BRNE    INC_DATE_NORMAL
    CPI     R17, 0
    BREQ    NEXT_MONTH
    RJMP    INC_DATE_NORMAL

CHECK_LAST_31:
    CPI     R16, 3
    BRNE    INC_DATE_NORMAL
    CPI     R17, 1
    BREQ    NEXT_MONTH
    RJMP    INC_DATE_NORMAL

INC_DATE_NORMAL:
    INC     R17
    CPI     R17, 10
    BRLO    SAVE_INC_DATE_DAY
    CLR     R17
    INC     R16

SAVE_INC_DATE_DAY:
    STS     d_dia, R16
    STS     u_dia, R17
    RET

NEXT_MONTH:
    LDI     R16, 0
    LDI     R17, 1
    STS     d_dia, R16
    STS     u_dia, R17

    LDS     R16, d_mes
    LDS     R17, u_mes

    INC     R17
    CPI     R17, 10
    BRLO    CHECK_MONTH_13
    CLR     R17
    INC     R16

CHECK_MONTH_13:
    CPI     R16, 1
    BRNE    SAVE_NEXT_MONTH
    CPI     R17, 3
    BRNE    SAVE_NEXT_MONTH

    CLR     R16
    LDI     R17, 1

SAVE_NEXT_MONTH:
    STS     d_mes, R16
    STS     u_mes, R17
    RET

/****************************************/
/* ISR Timer0 -> multiplexado del display */
/* ISR de Timer0: realiza el multiplexado del display según el modo activo. */
TMR0_ISR:
    PUSH    R16
    PUSH    R17
    PUSH    R18
    IN      R17, SREG
    PUSH    R17

    RCALL   DIGITS_OFF

    LDS     R18, mode_view

    ; modos con display titilando
    CPI     R18, 2
    BREQ    T0_BLINK_CHECK
    CPI     R18, 3
    BREQ    T0_BLINK_CHECK
    CPI     R18, 5
    BREQ    T0_BLINK_CHECK
    RJMP    T0_MODE_SELECT

T0_BLINK_CHECK:
    LDS     R16, blink_500ms
    CPI     R16, 0
    BRNE    T0_BLINK_CONT
    RJMP    END_T0

T0_BLINK_CONT:

T0_MODE_SELECT:
    ; modo 5 muestra hora
    CPI     R18, 5
    BRNE    T0CHK_0
    RJMP    T0_SHOW_HOUR

T0CHK_0:
    CPI     R18, 0
    BRNE    T0CHK_2
    RJMP    T0_SHOW_HOUR

T0CHK_2:
    CPI     R18, 2
    BRNE    T0CHK_4
    RJMP    T0_SHOW_HOUR

T0CHK_4:
    CPI     R18, 4
    BRNE    T0CHK_DATE
    RJMP    T0_SHOW_ALARM

T0CHK_DATE:
    RJMP    T0_SHOW_DATE

T0_SHOW_HOUR:
    LDS     R16, mux
    CPI     R16, 0
    BREQ    SHOW_H_UM
    CPI     R16, 1
    BREQ    SHOW_H_DM
    CPI     R16, 2
    BREQ    SHOW_H_UH
    RJMP    SHOW_H_DH

SHOW_H_UM:
    LDS     R16, u_min
    RCALL   SEG7_DECODE
    RCALL   SEG7_WRITE
    RCALL   DIGIT_UM_ON
    LDI     R16, 1
    STS     mux, R16
    RJMP    END_T0

SHOW_H_DM:
    LDS     R16, d_min
    RCALL   SEG7_DECODE
    RCALL   SEG7_WRITE
    RCALL   DIGIT_DM_ON
    LDI     R16, 2
    STS     mux, R16
    RJMP    END_T0

SHOW_H_UH:
    LDS     R16, u_hor
    RCALL   SEG7_DECODE
    RCALL   SEG7_WRITE
    RCALL   DIGIT_UH_ON
    LDI     R16, 3
    STS     mux, R16
    RJMP    END_T0

SHOW_H_DH:
    LDS     R16, d_hor
    RCALL   SEG7_DECODE
    RCALL   SEG7_WRITE
    RCALL   DIGIT_DH_ON
    CLR     R16
    STS     mux, R16
    RJMP    END_T0

T0_SHOW_DATE:
    LDS     R16, mux
    CPI     R16, 0
    BREQ    SHOW_F_UM
    CPI     R16, 1
    BREQ    SHOW_F_DM
    CPI     R16, 2
    BREQ    SHOW_F_UH
    RJMP    SHOW_F_DH

SHOW_F_UM:
    LDS     R16, u_mes
    RCALL   SEG7_DECODE
    RCALL   SEG7_WRITE
    RCALL   DIGIT_UM_ON
    LDI     R16, 1
    STS     mux, R16
    RJMP    END_T0

SHOW_F_DM:
    LDS     R16, d_mes
    RCALL   SEG7_DECODE
    RCALL   SEG7_WRITE
    RCALL   DIGIT_DM_ON
    LDI     R16, 2
    STS     mux, R16
    RJMP    END_T0

SHOW_F_UH:
    LDS     R16, u_dia
    RCALL   SEG7_DECODE
    RCALL   SEG7_WRITE
    RCALL   DIGIT_UH_ON
    LDI     R16, 3
    STS     mux, R16
    RJMP    END_T0

SHOW_F_DH:
    LDS     R16, d_dia
    RCALL   SEG7_DECODE
    RCALL   SEG7_WRITE
    RCALL   DIGIT_DH_ON
    CLR     R16
    STS     mux, R16
    RJMP    END_T0

T0_SHOW_ALARM:
    LDS     R16, mux
    CPI     R16, 0
    BREQ    SHOW_A_UM
    CPI     R16, 1
    BREQ    SHOW_A_DM
    CPI     R16, 2
    BREQ    SHOW_A_UH
    RJMP    SHOW_A_DH

SHOW_A_UM:
    LDS     R16, u_min_alarm
    RCALL   SEG7_DECODE
    RCALL   SEG7_WRITE
    RCALL   DIGIT_UM_ON
    LDI     R16, 1
    STS     mux, R16
    RJMP    END_T0

SHOW_A_DM:
    LDS     R16, d_min_alarm
    RCALL   SEG7_DECODE
    RCALL   SEG7_WRITE
    RCALL   DIGIT_DM_ON
    LDI     R16, 2
    STS     mux, R16
    RJMP    END_T0

SHOW_A_UH:
    LDS     R16, u_hor_alarm
    RCALL   SEG7_DECODE
    RCALL   SEG7_WRITE
    RCALL   DIGIT_UH_ON
    LDI     R16, 3
    STS     mux, R16
    RJMP    END_T0

SHOW_A_DH:
    LDS     R16, d_hor_alarm
    RCALL   SEG7_DECODE
    RCALL   SEG7_WRITE
    RCALL   DIGIT_DH_ON
    CLR     R16
    STS     mux, R16
    RJMP    END_T0

END_T0:
    POP     R17
    OUT     SREG, R17
    POP     R18
    POP     R17
    POP     R16
    RETI

/****************************************/
/* ISR Timer1 -> lógica temporal, D8, LEDs de modo y alarma */
/* ISR de Timer1: actualiza parpadeos, LEDs de estado, alarma y avance del reloj. */
TMR1_ISR:
    PUSH    R16
    PUSH    R17
    PUSH    R18
    IN      R17, SREG
    PUSH    R17

    ;-----------------------------------
    ; Toggle blink flag cada 500 ms
    ;-----------------------------------
    LDS     R16, blink_500ms
    CPI     R16, 0
    BREQ    BLINK_SET_1
    CLR     R16
    STS     blink_500ms, R16
    RJMP    BLINK_DONE

BLINK_SET_1:
    LDI     R16, 1
    STS     blink_500ms, R16

BLINK_DONE:
    ;-----------------------------------
    ; D8 según modo
    ; fijo:  modo 1 (fecha), modo 4 (config alarma)
    ; blink: modos 0,2,3,5
    ;-----------------------------------
    LDS     R16, mode_view

    CPI     R16, 1
    BRNE    D8CHK_4
    SBI     PORTB, PORTB0
    RJMP    LED_D8_DONE

D8CHK_4:
    CPI     R16, 4
    BRNE    D8_BLINK_MODES
    SBI     PORTB, PORTB0
    RJMP    LED_D8_DONE

D8_BLINK_MODES:
    LDS     R16, blink_500ms
    CPI     R16, 0
    BRNE    D8_ON_500
    CBI     PORTB, PORTB0
    RJMP    LED_D8_DONE

D8_ON_500:
    SBI     PORTB, PORTB0

LED_D8_DONE:
;-----------------------------------
; LEDs por modo
; 0 = hora            -> TX1 ON
; 1 = fecha           -> A5 ON
; 2 = config hora     -> TX1 ON
; 3 = config fecha    -> A5 ON
; 4 = config alarma   -> TX1 ON + A5 ON
; 5 = apagar alarma   -> no tocar aquí
;-----------------------------------
	LDS     R16, mode_view
	CPI     R16, 5
	BREQ    MODE_LED_DONE

	CBI     PORTD, PORTD1
	CBI     PORTC, PORTC5

	CPI     R16, 0
	BRNE    MODE_LED_1
	SBI     PORTD, PORTD1
	RJMP    MODE_LED_DONE

MODE_LED_1:
	CPI     R16, 1
	BRNE    MODE_LED_2
	SBI     PORTC, PORTC5
	RJMP    MODE_LED_DONE
	
MODE_LED_2:
	CPI     R16, 2
	BRNE    MODE_LED_3
	SBI     PORTD, PORTD1
	RJMP    MODE_LED_DONE

MODE_LED_3:	
	CPI     R16, 3
	BRNE    MODE_LED_4
	SBI     PORTC, PORTC5
	RJMP    MODE_LED_DONE
	
MODE_LED_4:
	CPI     R16, 4
	BRNE    MODE_LED_DONE
	SBI     PORTD, PORTD1
	SBI     PORTC, PORTC5
	
MODE_LED_DONE:
;-----------------------------------
; Alarma latcheada
; - si alarm_enabled = 0 -> no sonar
; - si alarm_on = 1 -> seguir sonando
; - si alarm_on = 0 y la hora coincide -> activar
;-----------------------------------
	LDS     R16, alarm_enabled
	CPI     R16, 0
	BRNE    ALARM_ENABLED_CHECK

; alarma deshabilitada
	CLR     R16
	STS     alarm_on, R16
	CBI     PORTB, PORTB5
	RJMP    BUZZER_DONE

ALARM_ENABLED_CHECK:
; si ya está activa, mantener buzzer
	LDS     R16, alarm_on
	CPI     R16, 1
	BRNE    ALARM_COMPARE_START

	SBI     PORTB, PORTB5
	RJMP    BUZZER_DONE

ALARM_COMPARE_START:
	LDS     R16, u_min
	LDS     R17, u_min_alarm
	CP      R16, R17
	BRNE    BUZZER_OFF_ONLY

	LDS     R16, d_min
	LDS     R17, d_min_alarm
	CP      R16, R17
	BRNE    BUZZER_OFF_ONLY

	LDS     R16, u_hor
	LDS     R17, u_hor_alarm
	CP      R16, R17
	BRNE    BUZZER_OFF_ONLY

	LDS     R16, d_hor
	LDS     R17, d_hor_alarm
	CP      R16, R17
	BRNE    BUZZER_OFF_ONLY

; coincidió: activar y latchear
	LDI     R16, 1
	STS     alarm_on, R16
	SBI     PORTB, PORTB5
	RJMP    BUZZER_DONE

BUZZER_OFF_ONLY:
	CBI     PORTB, PORTB5


BUZZER_DONE:
    ;-----------------------------------
    ; Contador de 500 ms
    ; 120 * 500 ms = 60 s
    ;-----------------------------------
    LDS     R16, sec_cnt
    INC     R16
    CPI     R16, 120
    BRLO    SAVE_HALFSEC_ONLY

    CLR     R16
    STS     sec_cnt, R16
    RJMP    DO_CLOCK_INC

SAVE_HALFSEC_ONLY:
    STS     sec_cnt, R16
    RJMP    END_T1

DO_CLOCK_INC:
    LDS     R18, u_min
    INC     R18
    CPI     R18, 10
    BRLO    SAVE_UMIN

    CLR     R18
    STS     u_min, R18

    LDS     R18, d_min
    INC     R18
    CPI     R18, 6
    BRLO    SAVE_DMIN

    CLR     R18
    STS     d_min, R18

    ; incrementar horas
    LDS     R18, u_hor
    INC     R18

    LDS     R16, d_hor
    CPI     R16, 2
    BRNE    NORMAL_HOUR_CHECK

    CPI     R18, 4
    BRLO    SAVE_UHOR

    ; 23:59 -> 00:00
    CLR     R18
    STS     u_hor, R18
    CLR     R18
    STS     d_hor, R18
    RCALL   INC_DATE
    RJMP    END_T1

NORMAL_HOUR_CHECK:
    CPI     R18, 10
    BRLO    SAVE_UHOR

    CLR     R18
    STS     u_hor, R18

    LDS     R18, d_hor
    INC     R18
    CPI     R18, 3
    BRLO    SAVE_DHOR

    CLR     R18
    STS     d_hor, R18
    RJMP    END_T1

SAVE_DHOR:
    STS     d_hor, R18
    RJMP    END_T1

SAVE_UHOR:
    STS     u_hor, R18
    RJMP    END_T1

SAVE_DMIN:
    STS     d_min, R18
    RJMP    END_T1

SAVE_UMIN:
    STS     u_min, R18

END_T1:
    POP     R17
    OUT     SREG, R17
    POP     R18
    POP     R17
    POP     R16
    RETI

/****************************************/
/* Tabla 7 segmentos ánodo común */
/* Tabla de conversión para display de 7 segmentos de ánodo común. */
TABLA:
    .DB 0x40,0x79,0x24,0x30,0x19,0x12,0x02,0x78
    .DB 0x00,0x10