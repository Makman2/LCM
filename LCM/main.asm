.equ PIN_IN = 0
.equ PIN_OUT = 1
.equ TURN_SWITCH_MASK = (1 << PB0) | (1 << PB1) | (1 << PB2)
.equ MEASURE_SUCCESSFUL = 0
.equ MEASURE_INTERRUPTED = 1

.equ UPPER_MOSFET = PD2
.equ BOTTOM_MOSFET = PD3

.equ DISCHARGE_CIRCUIT = 0x0
.equ MEASURING_CIRCUIT = 0x1

; Reset handler
.org 0x0000
    rjmp start
; Timer handler needed for timing module.
.org OVF1addr
    rjmp handle_timer_overflow_interrupt


.include "arithmetic.asm"
.include "lcd.asm"
.include "timing.asm"


start:
    ; Initialize stack pointer (= write the highest available address into the
    ; stack register).
    ldi r16, low(RAMEND)
    out SPL, r16
    ldi r16, high(RAMEND)
    out SPH, r16

    rcall initialize

    rjmp main


; Initializes pins, timers, interrupt handlers etc.
initialize:
    ; Set the pins PB0-2 as input pins (these are connected to the switch that
    ; selects the measurement domain) and PB3 too (TODO).
    ldi r16, 0b11110000
    out DDRB, r16

    ; Set PC0-5 as output, as this is where the display is connected.
    ldi r16, 0b00111111
    out DDRC, r16

    ; Set the pins PD2-3 as output pins (connected to the charge/discharge-
    ; circuit-selector transistor switches). And also PD7, this is the
    ; background light control of the LCD display.
    ldi r16, 0b10001100
    out DDRD, r16

    ; Setups the Analog Comparator.
    ldi r16, (1 << ACBG)
    out ACSR, r16

    ; Initialize LCD display at PORTC.
    rcall lcd4ini

    ; Turn on display light.
    ldi r16, LCD_LIGHT_ON
    rcall lcd4lightcontrol

    ; Initialize timing.
    rcall initialize_timing

    ; Enable global interrupts.
    sei

    ret


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


.macro print_char
    ldi r16, @0
    rcall lcd4put
.endmacro


print_welcome_message:
    push r16

    rcall lcd4reset_cursor

    print_char ' '
    print_char ' '
    print_char 'P'
    print_char 'R'
    print_char 'O'
    print_char 'J'
    print_char 'E'
    print_char 'C'
    print_char 'T'
    print_char ' '
    print_char 'L'
    print_char 'C'
    print_char 'M'
    print_char '!'

    pop r16

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


; Returns the hexadecimal digit (via r16) representing the lower nibble of the
; given value (via r16).
get_hexadecimal_digit:
    andi r16, 0b00001111

    ; FIXME Can be made faster and easier using a jumptable.
    cpi r16, 0x0
    breq _main_get_hexadecimal_digit0
    cpi r16, 0x1
    breq _main_get_hexadecimal_digit1
    cpi r16, 0x2
    breq _main_get_hexadecimal_digit2
    cpi r16, 0x3
    breq _main_get_hexadecimal_digit3
    cpi r16, 0x4
    breq _main_get_hexadecimal_digit4
    cpi r16, 0x5
    breq _main_get_hexadecimal_digit5
    cpi r16, 0x6
    breq _main_get_hexadecimal_digit6
    cpi r16, 0x7
    breq _main_get_hexadecimal_digit7
    cpi r16, 0x8
    breq _main_get_hexadecimal_digit8
    cpi r16, 0x9
    breq _main_get_hexadecimal_digit9
    cpi r16, 0xA
    breq _main_get_hexadecimal_digitA
    cpi r16, 0xB
    breq _main_get_hexadecimal_digitB
    cpi r16, 0xC
    breq _main_get_hexadecimal_digitC
    cpi r16, 0xD
    breq _main_get_hexadecimal_digitD
    cpi r16, 0xE
    breq _main_get_hexadecimal_digitE
    cpi r16, 0xF
    breq _main_get_hexadecimal_digitF

    _main_get_hexadecimal_digit0:
        ldi r16, '0'
        rjmp _main_get_hexadecimal_digit_endif
    _main_get_hexadecimal_digit1:
        ldi r16, '1'
        rjmp _main_get_hexadecimal_digit_endif
    _main_get_hexadecimal_digit2:
        ldi r16, '2'
        rjmp _main_get_hexadecimal_digit_endif
    _main_get_hexadecimal_digit3:
        ldi r16, '3'
        rjmp _main_get_hexadecimal_digit_endif
    _main_get_hexadecimal_digit4:
        ldi r16, '4'
        rjmp _main_get_hexadecimal_digit_endif
    _main_get_hexadecimal_digit5:
        ldi r16, '5'
        rjmp _main_get_hexadecimal_digit_endif
    _main_get_hexadecimal_digit6:
        ldi r16, '6'
        rjmp _main_get_hexadecimal_digit_endif
    _main_get_hexadecimal_digit7:
        ldi r16, '7'
        rjmp _main_get_hexadecimal_digit_endif
    _main_get_hexadecimal_digit8:
        ldi r16, '8'
        rjmp _main_get_hexadecimal_digit_endif
    _main_get_hexadecimal_digit9:
        ldi r16, '9'
        rjmp _main_get_hexadecimal_digit_endif
    _main_get_hexadecimal_digitA:
        ldi r16, 'A'
        rjmp _main_get_hexadecimal_digit_endif
    _main_get_hexadecimal_digitB:
        ldi r16, 'B'
        rjmp _main_get_hexadecimal_digit_endif
    _main_get_hexadecimal_digitC:
        ldi r16, 'C'
        rjmp _main_get_hexadecimal_digit_endif
    _main_get_hexadecimal_digitD:
        ldi r16, 'D'
        rjmp _main_get_hexadecimal_digit_endif
    _main_get_hexadecimal_digitE:
        ldi r16, 'E'
        rjmp _main_get_hexadecimal_digit_endif
    _main_get_hexadecimal_digitF:
        ldi r16, 'F'

    _main_get_hexadecimal_digit_endif:

    ret


; Prints a value (passed via r16) in hexadecimal form to display.
print_hexadecimal_value:
    push r16
    push r17

    mov r17, r16

    ; Get higher nibble.
    lsr r16
    lsr r16
    lsr r16
    lsr r16
    rcall get_hexadecimal_digit
    rcall lcd4put

    ; As the function only takes the lower nibble of a complete 8bit value
    ; already, we just pass the given r16 itself.
    mov r16, r17
    rcall get_hexadecimal_digit
    rcall lcd4put

    pop r17
    pop r16

    ret


; Prints a value (passed via r16) in binary form to display.
print_binary_value:
    push r16
    push r17
    push r18

    mov r17, r16

    ldi r18, 8
    _main_print_binary_value_loop:
        mov r16, r17
        andi r16, 0b10000000
        brne _main_print_binary_value_msb_set
            ldi r16, '0'
            rjmp _main_print_binary_value_endif
        _main_print_binary_value_msb_set:
            ldi r16, '1'
        _main_print_binary_value_endif:
        rcall lcd4put
        lsl r17

        dec r18
        brne _main_print_binary_value_loop

    pop r18
    pop r17
    pop r16

    ret


; Prints the result from 'measure' to the LCD display.
;
; TODO Currently takes r3:0 with the measured time.
print_result:
    push r16

    rcall lcd4reset_cursor

    ldi r16, '0'
    rcall lcd4put
    ldi r16, 'x'
    rcall lcd4put

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
