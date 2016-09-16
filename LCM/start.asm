; Reset handler
.org 0x0000
    rjmp start
; Timer handler needed for timing module.
.org OVF1addr
    rjmp handle_timer_overflow_interrupt


.include "main.asm"
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

    ; Initialize timing.
    rcall initialize_timing

    ; Enable global interrupts.
    sei

    ret
