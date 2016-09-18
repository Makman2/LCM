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

.endif
