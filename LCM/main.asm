.include "arithmetic.asm"
.include "lcd.asm"
.include "printing.asm"
.include "timing.asm"


.equ PIN_IN = 0
.equ PIN_OUT = 1
.equ TURN_SWITCH_MASK = (1 << PB0) | (1 << PB1) | (1 << PB2)
.equ MEASURE_SUCCESSFUL = 0
.equ MEASURE_INTERRUPTED = 1

.equ UPPER_MOSFET = PD2
.equ BOTTOM_MOSFET = PD3

.equ DISCHARGE_CIRCUIT = 0x0
.equ MEASURING_CIRCUIT = 0x1


main:
    ; Turn on display light.
    ldi r16, LCD_LIGHT_ON
    rcall lcd4lightcontrol

    rcall print_welcome_message
    ; No need to wait here, the discharge_capacitor function below
    ; does this implicitly (for a second).

    _main_main_measure:
        rcall discharge_capacitor
        ; Measure until measuring was successful.
        ldi r17, MEASURE_SUCCESSFUL
        _main_main_retry_measure:
            rcall measure
            cpse r16, r17
            rjmp _main_main_retry_measure

        ; Calculate real capacitance.
        rcall calculate_capacitance_from_time_difference

        ; Print result.
        rcall print_result

        ; And continue measuring forever...
        rjmp _main_main_measure


; Manual termination with 0, 0 is needed, to get an even number of bytes and
; to terminate string with 0. Plus: Print "konnichiwa!" in katakana :)
welcome_message: .db "  PROJECT LCM!  ", \
                     "     ", 0xBA, 0xDD, 0xC6, 0xC1, 0xDC, "!     ", \
                     0, 0


; Prints the welcome message.
print_welcome_message:
    push ZL
    push ZH

    rcall reset_cursor

    load_word_address_into_Z welcome_message
    rcall print_string

    pop ZH
    pop ZL

    ret


; Enables either the `DISCHARGE_CIRCUIT` or the `MEASURING_CIRCUIT`.
;
; One of the above constants need to be passed via r16.
;
; For example this will turn on the discharge-circuit:
; ```
; ldi r16, DISCHARGE_CIRCUIT
; rcall enable_circuit
; ```
enable_circuit:
    cpi r16, DISCHARGE_CIRCUIT

    brne _main_enable_circuit_else_case
        sbi PORTD, UPPER_MOSFET
        sbi PORTD, BOTTOM_MOSFET
        ret

    _main_enable_circuit_else_case:
        ; There are only two circuits we can enable (other combinations are not
        ; meaningful), so no need for another compare.
        cbi PORTD, BOTTOM_MOSFET
        cbi PORTD, UPPER_MOSFET
        ret


; Triggers and waits for capacitor-discharge.
discharge_capacitor:
    push r16

    ; Enable discharge circuit.
    ldi r16, DISCHARGE_CIRCUIT
    rcall enable_circuit

    ; By convention we consider a capacitor as discharged if we wait about one
    ; second. If a capacitance is too high and discharges too slowly, bad luck,
    ; not possible to distinguish that with this convention.
    ;
    ; And not that you wonder why I just don't do:
    ;   ldi r16, 1000
    ;   rcall wait
    ; We are 8-bit, 1000 does not fit into 8-bit.
    ldi r16, 250
    rcall wait
    ldi r16, 250
    rcall wait
    ldi r16, 250
    rcall wait
    ldi r16, 250
    rcall wait

    pop r16

    ret

; Starts capacitor-charging and capacitance measuring.
;
; Returns the time in ticks/cycles measured (inside r3:0).
measure:
    push r17
    push r18
    push XL
    push XH
    push ZL
    push ZH

    ; Load stack register.
    in ZL, SPL
    in ZH, SPH
    ; Allocate stack space.
    ; 0x4    Timer object
    movw X, Z
    subiw ZL, ZH, 0x0004
    out SPL, ZL
    out SPH, ZH

    ; Save current turn-switch state. If it changes during measurement, we want
    ; to restart measure.
    in r17, PINB
    andi r17, TURN_SWITCH_MASK

    ; Enable measuring circuit.
    ldi r16, MEASURING_CIRCUIT
    rcall enable_circuit

    ; Create a new timer and start.
    adiw Z, 1
    rcall timer_create

    ; Poll the Analog-Comparator-Status-Register and check if the comparation
    ; is high.
    _main_measure_loop_start:
        sbic ACSR, ACO
        jmp _main_measure_loop_start

    ; Get time difference (resides at r0:3).
    rcall timer_get_time

    ; Check old turn-switch state with new one.
    in r18, PINB
    andi r18, TURN_SWITCH_MASK
    cp r17, r18
    breq _main_measure_turn_switch_did_not_change
        ; Oh oh, someone turned the switch.
        ldi r16, MEASURE_INTERRUPTED
        rjmp _main_measure_exit
    _main_measure_turn_switch_did_not_change:

    ; Reset stack.
    out SPL, XL
    out SPH, XH

    ldi r16, MEASURE_SUCCESSFUL

    _main_measure_exit:
    pop ZH
    pop ZL
    pop XH
    pop XL
    pop r18
    pop r17

    ret


.equ DOMAIN_F = 0
.equ DOMAIN_mF = 1
.equ DOMAIN_microF = 2
.equ DOMAIN_nF = 3
.equ DOMAIN_pF = 4


; Calculates the capacitance.
;
; Takes as input from r0:3 the measured time of the measuring-circuit.
;
; Returns the float24 result representing the capacity inside r18:16 and inside
; r19 the domain.
calculate_capacitance_from_time_difference:
    push r20
    push r21
    push r22

    ; Convert measured time into a float24 (lying in r18:16).
    mov r19, r3
    mov r18, r2
    mov r17, r1
    mov r16, r0
    rcall float24_from_unsigned_int32

    sbic PINB, PB1
    rjmp _main_calculate_capacitance_from_time_difference_microF_domain
    sbic PINB, PB0
    rjmp _main_calculate_capacitance_from_time_difference_mF_domain
        ; else case
        ; nF domain -> PB2 = high

        ; zeta = 0.0005644062008674696
        load_float24 r22, r21, r20, 0x3427E9
        ldi r19, DOMAIN_nF

        rjmp _main_calculate_capacitance_from_time_difference_endif

    _main_calculate_capacitance_from_time_difference_microF_domain:
        ; microF domain -> PB1 = high

        ; zeta = 0.0002233905780124494
        load_float24 r22, r21, r20, 0x32D47B
        ldi r19, DOMAIN_microF

        rjmp _main_calculate_capacitance_from_time_difference_endif

    _main_calculate_capacitance_from_time_difference_mF_domain:
        ; mF domain -> PB0 = high

        ; zeta = 7.705908372886626e-05
        load_float24 r22, r21, r20, 0x314335
        ldi r19, DOMAIN_mF

    _main_calculate_capacitance_from_time_difference_endif:

    rcall float24_mul

    pop r22
    pop r21
    pop r20

    ret


DOMAIN_STRING_F: .db "F", 0
DOMAIN_STRING_mF: .db "mF", 0, 0
DOMAIN_STRING_microF: .db 0xE4, "F", 0, 0
DOMAIN_STRING_nF: .db "nF", 0, 0
DOMAIN_STRING_pF: .db "pF", 0, 0
STRING_NOT_PRINTABLE: .db "TOO BIG", 0


; Prints the result from 'measure' to the LCD display.
;
; Takes in the float24 value to print into r18:16. The measuring domain is
; accepted via r19.
print_result:
    push r19
    push r20
    push ZL
    push ZH

    rcall reset_cursor

    ; print_float24 below uses r19 as return value register.
    mov r20, r19

    ; Print actually measured value.
    rcall print_float24

    ; Check error code of print_float24
    cpi r19, PRINT_FLOAT24_SUCCESS
    brne _main_print_result_not_printable

        ; Load the unit suffix string.
        cpi r20, DOMAIN_pF
        breq _main_print_result_DOMAIN_pF
        cpi r20, DOMAIN_nF
        breq _main_print_result_DOMAIN_nF
        cpi r20, DOMAIN_microF
        breq _main_print_result_DOMAIN_microF
        cpi r20, DOMAIN_mF
        breq _main_print_result_DOMAIN_mF
            ; else case -> r19 = DOMAIN_F
            load_word_address_into_Z DOMAIN_STRING_F
            rjmp _main_print_result_DOMAIN_endif

        _main_print_result_DOMAIN_pF:
            load_word_address_into_Z DOMAIN_STRING_pF
            rjmp _main_print_result_DOMAIN_endif

        _main_print_result_DOMAIN_nF:
            load_word_address_into_Z DOMAIN_STRING_nF
            rjmp _main_print_result_DOMAIN_endif

        _main_print_result_DOMAIN_microF:
            load_word_address_into_Z DOMAIN_STRING_microF
            rjmp _main_print_result_DOMAIN_endif

        _main_print_result_DOMAIN_mF:
            load_word_address_into_Z DOMAIN_STRING_mF
            rjmp _main_print_result_DOMAIN_endif

        _main_print_result_DOMAIN_endif:

        ; Print the unit suffix string.
        rcall print_string

        rjmp _main_print_result_exit

    _main_print_result_not_printable:
        ; Return value of print_float24 is PRINT_FLOAT24_OVERFLOW.
        load_word_address_into_Z STRING_NOT_PRINTABLE
        rcall print_string

    _main_print_result_exit:

    pop ZH
    pop ZL
    pop r20
    pop r19

    ret
