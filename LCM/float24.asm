.ifndef LCM_FLOAT24
.equ LCM_FLOAT24 = 1

; The float24 format is IEEE conform (regarding behaviour and special cases)
; EXCEPT for the subnormal domain. Instead the lowest exponent is treated like
; any normal-number-case. +/- Infinity and (+/-) zero do exist.
;
; See also https://www.wikiwand.com/en/IEEE_floating_point
;
; The float24 contains a sign-bit (s), 7 exponent bits (e), biased
; with 63. And at last 16 fraction bits (f).
; s eeeeeee ffffffffffffffff
;
; The maximum number is (2 - 2^-16) * 2^64 = 3.69E-19
; The minimum number is 2^-62 = 2.17E-19
; The relative precision is 1.526E-05 (so about 4-5 digits)


.equ FLOAT24_EXPONENT_BITS = 7
.equ FLOAT24_FRACTION_BITS = 16
.equ FLOAT24_BIAS = 63


; Converts a 32bit int (passed via r19:16) into a float24 (returned in r18:16).
float24_from_unsigned_int32:
    push r19
    push r20
    push r21

    tst r19
    brne _float24_float24_from_unsigned_int32_not_zero
    tst r18
    brne _float24_float24_from_unsigned_int32_not_zero
    tst r17
    brne _float24_float24_from_unsigned_int32_not_zero
    tst r16
    brne _float24_float24_from_unsigned_int32_not_zero

    ; Need to catch this special case as this would fall into the subnormal
    ; domain of floats. In this case just return, because the representations
    ; for floats and unsigned ints for 0 is the same.
    rjmp _float24_float24_from_unsigned_int32_return

    _float24_float24_from_unsigned_int32_not_zero:

    ; We convert a *32bit* int, so we start with 32-1.
    ldi r20, 31
    _float24_float24_from_unsigned_int32_loop:
        mov r21, r19
        andi r21, 0b10000000
        brne _float24_float24_from_unsigned_int32_break

        lsl r16
        rol r17
        rol r18
        rol r19

        dec r20
        rjmp _float24_float24_from_unsigned_int32_loop
    _float24_float24_from_unsigned_int32_break:

    ; Due to the implicit '1' in the IEEE notation, we shift once again.
    lsl r16
    rol r17
    rol r18
    rol r19
    ; No need to decrement the counter again, that's why we started above
    ; with 32-*1*.

    ; Assemble float16.
    mov r16, r18
    mov r17, r19
    ; No need to check for overflow-cases, an int32 fits into a float24 always.
    ldi r18, FLOAT24_BIAS
    add r18, r20

    _float24_float24_from_unsigned_int32_return:

    pop r21
    pop r20
    pop r19

    ret


; Multiplies two float24's.
;
; The first factor is placed into r18:16 and the second one into r22:20.
; The result is placed into r18:16.
float24_mul:
    push r19
    push r23
    push r24

    ; Extract and compute sign.
    mov r19, r18
    andi r19, (1 << 7)
    mov r23, r22
    andi r23, (1 << 7)

    eor r19, r23

    ; Handle case when one of the operands is zero.
    tst r18
    brne _float24_float24_mul_operand1_not_zero
    tst r17
    brne _float24_float24_mul_operand1_not_zero
    tst r16
    brne _float24_float24_mul_operand1_not_zero
        ; Operand1 is zero!
        ; As r18:16 is already 0 and these are our return registers, not much
        ; to do. Just reuse the already computed sign.
        mov r18, r19
        rjmp _float24_float24_mul_exit

    _float24_float24_mul_operand1_not_zero:

    tst r22
    brne _float24_float24_mul_operand2_not_zero
    tst r21
    brne _float24_float24_mul_operand2_not_zero
    tst r20
    brne _float24_float24_mul_operand2_not_zero
        ; Operand2 is zero!
        mov r18, r19
        clr r17
        clr r16
        rjmp _float24_float24_mul_exit

    _float24_float24_mul_operand2_not_zero:

    ; Extract and compute exponent.
    mov r23, r18
    andi r23, 0b01111111
    mov r24, r22
    andi r24, 0b01111111

    add r23, r24
    ; The -1 is needed to compensate the shifting on both operands together
    ; when computing fraction.
    ldi r24, FLOAT24_BIAS - 1
    sub r23, r24

    ; Check for underflow
    brcc _float24_float24_mul_no_underflow
        ; Underflow occurred. Set to 0.
        clr r16
        clr r17
        clr r18

        rjmp _float24_float24_mul_exit

    _float24_float24_mul_no_underflow:

    ; Check for overflow.
    cpi r23, EXP2(FLOAT24_EXPONENT_BITS) - 1
    brlo _float24_float24_mul_no_overflow
        ; Overflow occurred. Set to +/- infinite.
        clr r16
        clr r17
        ldi r18, 0b01111111
        or r18, r19

        rjmp _float24_float24_mul_exit

    _float24_float24_mul_no_overflow:

    push r19
    push r20
    push r21

    ; Compute fraction.
    mov r19, r21
    mov r18, r20
    ; Shift-in the implicit '1'.
    sec
    ror r19
    ror r18
    ; The same for the other number.
    sec
    ror r17
    ror r16
    ; Multiplicand is already placed into r17:16, multiplier inside r19:18.
    ; Result will reside at r21:18.
    rcall mul16u

    ; Move two highest bytes into new float24, the less significant ones don't
    ; fit into a float24 due to precision.
    mov r17, r21
    mov r16, r20

    ; Normalize again.
    mov r20, r17
    andi r20, 0b10000000
    brne single_norm_shift
        ; Double normalization shift needed. But more than two shifts aren't
        ; needed for any case.
        lsl r19
        rol r16
        rol r17
        dec r23
    single_norm_shift:
    lsl r19
    rol r16
    rol r17

    pop r21
    pop r20
    pop r19

    ; Assemble sign + exponent.
    or r19, r23
    mov r18, r19

    _float24_float24_mul_exit:

    pop r24
    pop r23
    pop r19

    ret


; Checks if the given float24 (r18:16) is infinite.
; If so, r19 = 1, else r19 = 0.
float24_isinf:
    push r16
    push r17
    push r18

    tst r16
    brne _float24_float24_isinf_false
    tst r17
    brne _float24_float24_isinf_false
    andi r18, 0b01111111
    cpi r18, 0b01111111
    brne _float24_float24_isinf_false

    ldi r19, 1
    rjmp _float24_float24_isinf_exit

    _float24_float24_isinf_false:

    clr r19

    _float24_float24_isinf_exit:

    pop r18
    pop r17
    pop r16

    ret


; Loads a float24 immediately from given numeric representation.
;
; Example:
; ; Loads the float24 constant '400.0'
; load_float24 r18, r17, r16, 0x479000
;
; This is the same as:
; ldi r18, 0x47
; ldi r17, 0x90
; ldi r16, 0x00
.macro load_float24
    ldi @0, BYTE3(@3)
    ldi @1, BYTE2(@3)
    ldi @2, LOW(@3)
.endmacro

.endif
