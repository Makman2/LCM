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


; Sets the display cursor (position has to be passed via r16).
;
; The display has two lines with 16 chars each, so the range is from
; 0x00-0x1F. Values outside of this range are ignored.
lcd4setcur:
    push r16
    push r17
    push r18

    ; Divide r16 by 16 (0x10).
    mov r17, r16
    lsr r17
    lsr r17
    lsr r17
    lsr r17

    ; Load the row base address for line number.
    breq _lcd_lcd4setcur_case0
    cpi r17, 1
    ; else case when branching: Invalid position specified,
    ; ignore call.
    brne _lcd_lcd4setcur_return
        ; case r17 == 1
        ldi r18, 0x40
        rjmp _lcd_lcd4setcur_endif
    _lcd_lcd4setcur_case0:
        ; case r17 == 0
        clr r18
    _lcd_lcd4setcur_endif:

    ; Get column address.
    andi r16, 0xF

    ; Assemble complete address.
    add r16, r18

    ; Set global cursor position.
    mov curpos, r16

    ; Assemble display command.
    ori r16, 0x80
    rcall lcd4com

    _lcd_lcd4setcur_return:

    pop r18
    pop r17
    pop r16

    ret

.endif
