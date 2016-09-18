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

.endif
