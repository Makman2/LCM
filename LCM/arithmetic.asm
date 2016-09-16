.ifndef LCM_ARITHMETIC
.equ LCM_ARITHMETIC = 1


; Adds a 16bit value to another 16bit value.
;
; The first two register parameters are the first operand and target of the
; assignment, the last two the second operand.
.macro addw
    add @0, @2
    adc @1, @3
.endmacro


; Subtracts an immediate 16bit value from a register.
;
; The first two register parameters are the first operand and target of the
; assignment, the last parameter is a 16bit immediate value.
;
; For example
; `subiw r0, r1, 0xA001`
; subtracts the decimal value 40961 from the register pair r1:0.
.macro subiw
    subi @0, low(@2)
    sbci @1, high(@2)
.endmacro


; Subtracts a 16bit value from another one.
;
; The first two register parameters are the first operand and target of the
; assignment, the last two the second operand.
.macro subw
    sub @0, @2
    sbc @1, @3
.endmacro


; Adds a 32bit value to another one.
;
; The first four register parameters are the first operand and target of the
; assignment, the last four the second operand.
.macro adddw
    add @0, @4
    adc @1, @5
    adc @2, @6
    adc @3, @7
.endmacro


; Subtracts an unsigned double word from another one.
;
; The first four parameters are the registers to the first number that is
; subtracted from (and also the target of the result). The following four
; parameters are the registers that subtract.
;
; This macro follow Little-Endian order, meaning earlier parameters have less
; numeric significance than later supplied parameters.
.macro subdw
    sub @0, @4
    sbc @1, @5
    sbc @2, @6
    sbc @3, @7
.endmacro


; Stores a 32bit value to memory.
;
; The first parameter can be either the X, Y, or Z register. It needs to
; contain the address where to store the double-word.
;
; The last 4 parameters are registers which contain the double-word to store.
;
; For example:
; ```
; my_variable: .BYTE 4
; ldi ZL, low(my_variable)
; ldi ZH, high(my_variable)
; ldi r0, 0x00
; ldi r1, 0xCA
; ldi r2, 0x9A
; ldi r3, 0x3B
; stdword Z, r0, r1, r2, r3
; ```
; r3:0 contain now the (unsigned) integer 1,000,000,000.
.macro stdword
    st @0, @1
    std @0+1, @2
    std @0+2, @3
    std @0+3, @4
.endmacro


; Loads a 32bit value into registers.
;
; The first parameter can be either the Y or Z register (X is not supported).
; It needs to contain the address where to load the double-word from.
;
; The last 4 parameters are registers which will be loaded with the
; double-word.
.macro lddword
    ld @0, @4
    ldd @1, @4+1
    ldd @2, @4+2
    ldd @3, @4+3
.endmacro

.endif
