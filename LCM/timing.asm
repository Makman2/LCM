; When using this module, place this piece of code to your .ORG directives!
;
; .org OVF1addr
;     rjmp handle_timer_overflow_interrupt

.ifndef LCM_TIMING
.equ LCM_TIMING = 1


.message "--------------------------------------------------------------------"
.message "To properly use the timing module, place this piece of code to"
.message "your ORG directives of the main script!"
.message ""
.message "(dot)org OVF1addr"
.message "    rjmp handle_timer_overflow_interrupt"
.message "--------------------------------------------------------------------"


.include "arithmetic.asm"

.equ ON = 1
.equ OFF = 0

.equ CMI_DONT_USE_PC1 = 0b00
.equ CMI_INVERT_PC1 = 0b01
.equ CMI_SET_PC1_LOW = 0b10
.equ CMI_SET_PC1_HIGH = 0b11

.equ TPWM_DISABLED = 0b00
.equ TPWM_8BIT_ACTIVE = 0b01
.equ TPWM_9BIT_ACTIVE = 0b10
.equ TPWM_10BIT_ACTIVE = 0b11

.equ CS_STOPPED = 0b000
.equ CS_CPU_CLOCK = 0b001
.equ CS_CPU_CLOCK_DIVIDED_BY_8 = 0b010
.equ CS_CPU_CLOCK_DIVIDED_BY_64 = 0b011
.equ CS_CPU_CLOCK_DIVIDED_BY_256 = 0b100
.equ CS_CPU_CLOCK_DIVIDED_BY_1024 = 0b101


; Reserve 16bit for timer overflow counter.
.dseg
v_timer_overflow_counter: .BYTE 2
.cseg

; Loads the current timer value from TCNT1 and the overflow counter.
;
; Returns a 4-byte integer in r3:0.
;
; Note that this function disables interrupts for a short time while reading
; the timer values.
load_current_timer_value:
    push r16
    push ZL
    push ZH

    in r16, SREG

    ldi ZL, low(v_timer_overflow_counter)
    ldi ZH, high(v_timer_overflow_counter)

    ; Disable all interrupts for a while so our timer doesn't increment the
    ; overflow counter suddenly.
    cli
    ; Load current timer value from TCNT1.
    in r0, TCNT1L
    in r1, TCNT1H
    ; Load current overflow counter.
    ld r2, Z
    ldd r3, Z+1

    ; Reenable global interrupts again (if they were previously enabled).
    out SREG, r16

    pop ZH
    pop ZL
    pop r16

    ret


; Handles a timer interrupt.
;
; This is an ISR (Interrupt Service Routine)!
handle_timer_overflow_interrupt:
    push r24
    push r25
    push ZL
    push ZH

    ; Load Z register with the 16bit address of v_timer_overflow_counter and
    ; then load the overflow counter value itself.
    ldi ZL, low(v_timer_overflow_counter)
    ldi ZH, high(v_timer_overflow_counter)
    ld r24, Z
    ldd r25, Z+1
    ; Increment 16bit current timer value.
    adiw r24, 1
    ; Write it back to memory.
    st Z, r24
    std Z+1, r25

    pop ZH
    pop ZL
    pop r25
    pop r24

    reti


initialize_timing:
    push r16
    push ZL
    push ZH

    ldi ZL, low(v_timer_overflow_counter)
    ldi ZH, high(v_timer_overflow_counter)

    ; Reset overflow counter.
    clr r16
    st Z, r16
    std Z+1, r16

    ; Use Timer1 with 16 bit resolution (and deactivate Timer0 (TOE10) as it
    ; only has 8 bit resolution).
    ; - Deactivate overflow interrupts for Timer0 (TOIE0).
    ; - Activate overflow interrupts for Timer1 (TOIE1).
    ; - Disable "Compare Match Interrupts" (OC1E1A).
    ; - Disable "Input Capture Interrupts" (TICIE1).
    ldi r16, (OFF << TOIE0) | \
             (ON << TOIE1) | \
             (OFF << OCIE1A) | \
             (OFF << TICIE1)
    out TIMSK, r16

    ; - Disable automatic pin control on PC1 from "Compare Match Interrupts"
    ;   (COM1A0).
    ; - Disable PWM mode (WGM10).
    ldi r16, (CMI_DONT_USE_PC1 << COM1A0) | \
             (TPWM_DISABLED << WGM10)
    out TCCR1A, r16

    ; - Disable setting the 16-bit data register TCNT1 to 0 if compare value
    ;   in OCR1 is reached, as we don't need that (CTC1).
    ; - Use CPU clock (without prescaling) for timer register (-> TCNT1)
    ;   counting (CS1).
    ldi r16, (OFF << WGM12) | \
             (CS_CPU_CLOCK << CS10)
    out TCCR1B, r16

    pop ZH
    pop ZL
    pop r16

    ret

; Creates and starts (!) a new timer object and pushes it back on the stack.
;
; This function takes in inside the Z register (r30-31) the pointer to the
; stack location where to create the object. The Z register will be modified
; and not restored back to original state.
;
; The memory layout of the timer object is as follows:
; 0x0000 -> 0x0003 : [cycles]
;                    Unsigned 32-bit current timer value (written from TCNT1
;                    and combined with v_timer_overflow_counter).
;
; A timer object allows to measure up to 2**32 cycles. For example with 16MHz
; clock frequency this allows to measure up to 268 seconds (roughly 4.5
; minutes).
;
; This object is primitive, thus it doesn't need explicit destruction (via
; `destroy_timer`). Just abandon the object.
timer_create:
    push r0
    push r1
    push r2
    push r3
    push r16

    rcall load_current_timer_value

    ; Store the timer value at 0x0000.
    stdword Z, r0, r1, r2, r3

    pop r16
    pop r3
    pop r2
    pop r1
    pop r0

    ret


; Returns the number of cycles elapsed as a 32bit number (TODO signed or unsigned? -> I think unsigned).
;
; The result is placed into the registers r0-3.
;
; This function takes in the address of a timer object via the Z register
; (r30-31). The Z register will be modified and not restored back to original
; state.
timer_get_time:
    push r4
    push r5
    push r6
    push r7
    push r16

    rcall load_current_timer_value

    ; Load the [cycles] field of timer object.
    lddword r4, r5, r6, r7, Z

    ; Calculate time difference from our last timestamp saved in the passed
    ; timer object.
    subdw r0, r1, r2, r3, r4, r5, r6, r7

    ; FIXME Can be improved: To compensate computation overhead, subtract fixed
    ;       cycle count.

    pop r16
    pop r7
    pop r6
    pop r5
    pop r4

    ret

.endif
