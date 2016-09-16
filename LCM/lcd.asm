.ifndef LCM_LCD
.equ LCM_LCD = 1

.equ lcdpen = PORTC
.equ lcden = PC5
.equ lcdprs = PORTC
.equ lcdrs = PC4
.equ lcdpdat = PORTC
.equ lcdbus = 'l'
.equ lcdlightport = PORTD
.equ lcdlight = PD7

.def curpos = r23


.include "delay.asm"


.macro lcd4comi
    ldi r16, @0
    rcall lcd4com
.endmacro


lcd4ini:
    push r16

    ; Wait first 250ms so we can be sure the LCD has powered up correctly.
    ldi r16, 250
    rcall wait

    ; Send start sequence LCD three times (`0011`). Set at last also
    ; 4-bit-mode (`0010`).
    lcd4comi 0b00110011
    lcd4comi 0b00110010
    ; 4-bit-mode, 1 line.
    lcd4comi 0b00101000
    lcd4comi 0b00001100
    lcd4comi 0b00000110
    lcd4comi 0b00000010
    lcd4comi 0b00000001

    pop r16
    ret


.equ LCD_LIGHT_OFF = 0
.equ LCD_LIGHT_ON = 1


; Controls the background light of the display.
;
; Put LCD_LIGHT_ON or LCD_LIGHT_OFF into r16.
lcd4lightcontrol:
    cpi r16, LCD_LIGHT_ON
    brne _lcd_lcd4lightcontrol_lightoff_case
        sbi lcdlightport, lcdlight
        ret

    _lcd_lcd4lightcontrol_lightoff_case:
        cbi lcdlightport, lcdlight
        ret


; Resets the cursor to first row first column.
lcd4reset_cursor:
    push r16

    lcd4comi 0x01
    clr curpos

    pop r16

    ret


; Send subroutine to LCD display.
;
; The command to send has to be placed into r16.
lcd4com:
    push r16

.if lcdbus == 'l'
    swap r16
.endif

    out lcdpdat, r16
    cbi lcdprs, lcdrs
    sbi lcdpen, lcden
    rcall wait1ms
    cbi lcdpen, lcden
    swap r16

    out lcdpdat, r16
    cbi lcdprs, lcdrs
    sbi lcdpen, lcden
    rcall wait1ms
    cbi lcdpen, lcden
    clr r16
    out lcdpdat, r16

    ldi r16, 10
    rcall wait

    pop r16
    ret


; Send char to LCD display.
;
; The char to send has to be placed in r16.
;
; To properly use this function, the display has to be initialized first (via
; calling lcd4ini).
lcd4put:
    push r16

    .if lcdbus == 'l'
        swap r16
    .endif

    out lcdpdat, r16
    sbi lcdprs, lcdrs
    sbi lcdpen, lcden
    rcall wait1ms
    cbi lcdpen, lcden
    swap r16

    out lcdpdat, r16
    sbi lcdprs, lcdrs
    sbi lcdpen, lcden
    rcall wait1ms
    cbi lcdpen, lcden
    clr r16
    out lcdpdat, r16

    rcall wait1ms

    rcall lcd4cur

    pop r16

    ret


; Send string from program memory to LCD.
;
; The address of the string (in program memory!) has to be passed via the Z
; registers.
;
; To properly use this function, the display has to be initialized first (via
; calling lcd4ini).
lcd4puts:
    push r0
    push r16
    push ZL
    push ZH

    _lcd_lcd4puts_loop:
        lpm
        adiw ZH:ZL, 1
        tst r0
        breq _lcd_lcd4puts_break
        mov r16, r0
        rcall lcd4put
        rjmp _lcd_lcd4puts_loop
    _lcd_lcd4puts_break:

    pop ZH
    pop ZL
    pop r16
    pop r0

    ret


; Updates the cursor position (curpos register) accordingly after a single
; character write.
lcd4cur:
    push r16

    inc curpos

    cpi curpos, 0x10
    breq _ldc_lcd4cur_case1
    cpi curpos, 0x50
    breq _ldc_lcd4cur_case2
    rjmp _ldc_lcd4cur_endif

    _ldc_lcd4cur_case1:
        ldi curpos, 0x40
        lcd4comi 0x80 | 0x40
        rjmp _ldc_lcd4cur_endif

    _ldc_lcd4cur_case2:
        clr curpos
        lcd4comi 0x80 | 0x00

    _ldc_lcd4cur_endif:

    pop r16

    ret

.endif
