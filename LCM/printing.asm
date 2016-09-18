.ifndef LCM_PRINTING
.equ LCM_PRINTING = 1

.include "float24.asm"
.include "float24printtable.asm"
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


; Prints a dword-value (passed via r15:12) in decimal format to display.
print_decimal_dword_unsigned:
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15
    push r16
    push r17
    push r18
    push r19
    push r20
    push r21

    ; Initialize digits counter.
    clr r20

    ; Load '10' into divisor registers.
    clr r19
    clr r18
    clr r17
    ldi r16, 10

    _printing_print_decimal_dword_unsigned_loop:
        rcall div32u

        ; Initialize with ASCII number offset.
        ldi r21, 0x30
        ; 'given-dword modulo 10' can't be higher than 9, which fits into
        ; a single register. So we just need to take the lowest result byte.
        add r21, r8

        ; And push char on stack, as the numbers need to be reverted for
        ; 'print_char'.
        push r21
        ; Increment digits counter.
        inc r20

        tst r12
        brne _printing_print_decimal_dword_unsigned_loop
        tst r13
        brne _printing_print_decimal_dword_unsigned_loop
        tst r14
        brne _printing_print_decimal_dword_unsigned_loop
        tst r15
        brne _printing_print_decimal_dword_unsigned_loop

    ; Print back stuff:
    _printing_print_decimal_dword_unsigned_print_loop:
        pop r16
        rcall print_char

        dec r20
        brne _printing_print_decimal_dword_unsigned_print_loop

    pop r21
    pop r20
    pop r19
    pop r18
    pop r17
    pop r16
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8

    ret


.equ PRINT_FLOAT24_SUCCESS = 0
.equ PRINT_FLOAT24_OVERFLOW = 1


; Prints a float24 (passed via r18:16) to screen (2 digits rounded).
;
; The non fractional part is converted into a 32bit unsigned integer to be
; represented. This function will return inside r19 PRINT_FLOAT24_SUCCESS (0)
; if everything went fine and the float24 is not too large, otherwise
; PRINT_FLOAT24_OVERFLOW (1). If the float24 is too large, no printing will
; happen to display.
print_float24:
    push r16
    push r17
    push r18
    push r20
    push r21
    push r22
    ; Don't use r23, as this is the reserved register 'curpos' from the
    ; lcd module. As we use printing facilities here, we can't use that
    ; register.
    push r24
    push r25
    push r26

    ; Get sign.
    mov r26, r18
    andi r26, 0b10000000

    ; Get exponent.
    andi r18, 0b01111111
    ldi r19, FLOAT24_BIAS
    sub r18, r19

    clr r25
    clr r24
    clr r22
    ldi r21, 1  ; Implicit '1'
    mov r20, r17
    mov r19, r16

    cpi r18, 0
    breq shifting_done
    brlt negative_shift
        shift_loop:
            ; float24 fraction part.
            lsl r19
            rol r20
            ; Integer part.
            rol r21
            rol r22
            rol r24
            rol r25
            ; If we have a carry over, this means we have an integer overflow
            ; and this algorithm isn't able to print the number.
            brcs _printing_print_float24_overflow

            dec r18
            brne shift_loop

        rjmp shifting_done;

    negative_shift:
        negative_shift_loop:
            lsr r21
            ror r20
            ; No need to shift to r19, the floating table uses only the first
            ; 8 bits of fraction. So everything below r20 will be cut away
            ; anyway.

            inc r18
            brne negative_shift_loop

    shifting_done:

    ; Calculate the 2 most significant digits.
    load_word_address_into_Z float24printtable

    ; As each fractional part is made up of 2 digits, we need to offset the
    ; address by multiplying with 2.
    mov r18, r20
    clr r19
    lsl r18
    rol r19

    ; Get address to correct entry of printtable.
    add ZL, r18
    adc ZH, r19

    ; Load entry.
    lpm r18, Z+
    lpm r19, Z

    ; Start printing.

    push r16
    push r15
    push r14
    push r13
    push r12

    ; Print sign.
    cpi r26, 0b10000000
    brne _printing_print_float24_no_sign
        ldi r16, '-'
        rcall print_char
    _printing_print_float24_no_sign:

    mov r15, r25
    mov r14, r24
    mov r13, r22
    mov r12, r21

    ; Print non-fractional part.
    rcall print_decimal_dword_unsigned

    ; Print comma.
    ldi r16, '.'
    rcall print_char

    ; Print fraction.
    mov r16, r18
    rcall print_char
    mov r16, r19
    rcall print_char

    pop r12
    pop r13
    pop r14
    pop r15
    pop r16

    ldi r19, PRINT_FLOAT24_SUCCESS

    rjmp _printing_print_float24_exit

    _printing_print_float24_overflow:
        ldi r19, PRINT_FLOAT24_OVERFLOW

    _printing_print_float24_exit:

    pop r26
    pop r25
    pop r24
    pop r22
    pop r21
    pop r20
    pop r18
    pop r17
    pop r16

    ret

.endif
