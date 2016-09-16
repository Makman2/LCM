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

        ; TODO Print result accordingly.
        rcall print_result

        ; And continue measuring forever...
        rjmp _main_main_measure


print_welcome_message:
    rcall reset_cursor

    ; FIXME: Use a function that prints a string.
    print_immediate_char ' '
    print_immediate_char ' '
    print_immediate_char 'P'
    print_immediate_char 'R'
    print_immediate_char 'O'
    print_immediate_char 'J'
    print_immediate_char 'E'
    print_immediate_char 'C'
    print_immediate_char 'T'
    print_immediate_char ' '
    print_immediate_char 'L'
    print_immediate_char 'C'
    print_immediate_char 'M'
    print_immediate_char '!'

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
; TODO Currently return in r3:0 the ticks measured.
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

    ; Get according measuring domain.
    mov r16, r18
    rcall calculate_capacitance_from_time_difference

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


; Calculates the capacitance.
;
; Takes as input from r0:3 the measured time of the measuring-circuit, and
; inside r16 the last state of PINB (though only PB0, PB1 and PB2 are relevant)
;
; Returns TODO Currently nothing, just the time difference in r0:3
calculate_capacitance_from_time_difference:
    sbrs r16, PB1
    rjmp _calculate_capacitance_from_time_difference_mF_domain
    sbrs r16, PB2
    rjmp _calculate_capacitance_from_time_difference_microF_domain
        ; else case
        ; nF domain -> PB0 = high
        ; TODO
        rjmp _calculate_capacitance_from_time_difference_endif

    _calculate_capacitance_from_time_difference_mF_domain:
        ; mF domain -> PB1 = high
        ; TODO
        rjmp _calculate_capacitance_from_time_difference_endif

    _calculate_capacitance_from_time_difference_microF_domain:
        ; microF domain -> PB2 = high
        ; TODO

    _calculate_capacitance_from_time_difference_endif:

    ret


; Prints the result from 'measure' to the LCD display.
;
; TODO Currently takes r3:0 with the measured time.
print_result:
    push r16

    rcall reset_cursor

    print_immediate_char '0'
    print_immediate_char 'x'

    mov r16, r3
    rcall print_hexadecimal_value
    mov r16, r2
    rcall print_hexadecimal_value
    mov r16, r1
    rcall print_hexadecimal_value
    mov r16, r0
    rcall print_hexadecimal_value

    pop r16

    ret
