.ifndef LCM_DELAY
.equ LCM_DELAY = 1

.equ CLOCK = 16000000  ; 16MHz

.ifdef DEBUG
    ; Debugging is done in simulator, and even an 1ms wait takes way too long.
    wait1ms:
        ret
.else
    ; Delays execution by 1ms.
    wait1ms:
        push r24
        push r25
        ldi r24, LOW(CLOCK / 4000)
        ldi r25, HIGH(CLOCK / 4000)

        _delay_wait1ms_delayloop:
            sbiw r24, 1
            brne _delay_wait1ms_delayloop

        nop

        pop r25
        pop r24

        ret
.endif


; Delays execution by a certain amount of time.
;
; The amount of time to wait (in milliseconds!) is passed via r16.
wait:
    push r16

    _delay_wait_did_not_wait_enough:
        rcall wait1ms
        dec r16
        brne _delay_wait_did_not_wait_enough

    pop r16

    ret

.endif
