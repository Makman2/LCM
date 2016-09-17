.ifndef LCM_PRINTING
.equ LCM_PRINTING = 1

.include "lcd.asm"


; Prints a char (passed via r16) to display.
print_char:
    rjmp lcd4put


; Prints a (null-terminated) string to display.
;
; The address of the string (in program memory!) has to be passed via the Z
; registers.
;
; Example:
; .db string "HELLO WORLD", 0
; ldi ZL, low(string << 1)
; ldi ZH, high(string << 1)
; rcall print_string
print_string:
    push r0
    push r16
    push ZL
    push ZH

    _printing_print_string_loop:
        lpm
        adiw ZH:ZL, 1
        tst r0
        breq _printing_print_string_break
        mov r16, r0
        rcall print_char
        rjmp _printing_print_string_loop
    _printing_print_string_break:

    pop ZH
    pop ZL
    pop r16
    pop r0

    ret


; Prints a char passed as an immediate value.
.macro print_immediate_char
    push r16

    ldi r16, @0
    rcall print_char

    pop r16
.endmacro


; Resets the cursor to beginning of the display.
reset_cursor:
    rjmp lcd4reset_cursor


; Sets the display cursor (position has to be passed via r16).
;
; The display has two lines with 16 chars each, so the range is from
; 0x00-0x1F. Values outside of this range are ignored.
set_cursor:
    rjmp lcd4setcur


; Prints a value (passed via r16) in binary form to display.
print_binary_value:
    push r16
    push r17
    push r18

    mov r17, r16

    ldi r18, 8
    _printing_print_binary_value_loop:
        mov r16, r17
        andi r16, 0b10000000
        brne _printing_print_binary_value_msb_set
            ldi r16, '0'
            rjmp _printing_print_binary_value_endif
        _printing_print_binary_value_msb_set:
            ldi r16, '1'
        _printing_print_binary_value_endif:
        rcall print_char
        lsl r17

        dec r18
        brne _printing_print_binary_value_loop

    pop r18
    pop r17
    pop r16

    ret


; Returns the hexadecimal digit (via r16) representing the lower nibble of the
; given value (via r16).
get_hexadecimal_digit:
    andi r16, 0b00001111

    ; FIXME Can be made faster and easier using a jumptable.
    cpi r16, 0x0
    breq _printing_get_hexadecimal_digit0
    cpi r16, 0x1
    breq _printing_get_hexadecimal_digit1
    cpi r16, 0x2
    breq _printing_get_hexadecimal_digit2
    cpi r16, 0x3
    breq _printing_get_hexadecimal_digit3
    cpi r16, 0x4
    breq _printing_get_hexadecimal_digit4
    cpi r16, 0x5
    breq _printing_get_hexadecimal_digit5
    cpi r16, 0x6
    breq _printing_get_hexadecimal_digit6
    cpi r16, 0x7
    breq _printing_get_hexadecimal_digit7
    cpi r16, 0x8
    breq _printing_get_hexadecimal_digit8
    cpi r16, 0x9
    breq _printing_get_hexadecimal_digit9
    cpi r16, 0xA
    breq _printing_get_hexadecimal_digitA
    cpi r16, 0xB
    breq _printing_get_hexadecimal_digitB
    cpi r16, 0xC
    breq _printing_get_hexadecimal_digitC
    cpi r16, 0xD
    breq _printing_get_hexadecimal_digitD
    cpi r16, 0xE
    breq _printing_get_hexadecimal_digitE
    cpi r16, 0xF
    breq _printing_get_hexadecimal_digitF

    _printing_get_hexadecimal_digit0:
        ldi r16, '0'
        rjmp _printing_get_hexadecimal_digit_endif
    _printing_get_hexadecimal_digit1:
        ldi r16, '1'
        rjmp _printing_get_hexadecimal_digit_endif
    _printing_get_hexadecimal_digit2:
        ldi r16, '2'
        rjmp _printing_get_hexadecimal_digit_endif
    _printing_get_hexadecimal_digit3:
        ldi r16, '3'
        rjmp _printing_get_hexadecimal_digit_endif
    _printing_get_hexadecimal_digit4:
        ldi r16, '4'
        rjmp _printing_get_hexadecimal_digit_endif
    _printing_get_hexadecimal_digit5:
        ldi r16, '5'
        rjmp _printing_get_hexadecimal_digit_endif
    _printing_get_hexadecimal_digit6:
        ldi r16, '6'
        rjmp _printing_get_hexadecimal_digit_endif
    _printing_get_hexadecimal_digit7:
        ldi r16, '7'
        rjmp _printing_get_hexadecimal_digit_endif
    _printing_get_hexadecimal_digit8:
        ldi r16, '8'
        rjmp _printing_get_hexadecimal_digit_endif
    _printing_get_hexadecimal_digit9:
        ldi r16, '9'
        rjmp _printing_get_hexadecimal_digit_endif
    _printing_get_hexadecimal_digitA:
        ldi r16, 'A'
        rjmp _printing_get_hexadecimal_digit_endif
    _printing_get_hexadecimal_digitB:
        ldi r16, 'B'
        rjmp _printing_get_hexadecimal_digit_endif
    _printing_get_hexadecimal_digitC:
        ldi r16, 'C'
        rjmp _printing_get_hexadecimal_digit_endif
    _printing_get_hexadecimal_digitD:
        ldi r16, 'D'
        rjmp _printing_get_hexadecimal_digit_endif
    _printing_get_hexadecimal_digitE:
        ldi r16, 'E'
        rjmp _printing_get_hexadecimal_digit_endif
    _printing_get_hexadecimal_digitF:
        ldi r16, 'F'

    _printing_get_hexadecimal_digit_endif:

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
    rcall print_char

    pop r17
    pop r16

    ret

.endif
