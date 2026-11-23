; counter_leds.asm
;
; Seconds counter on the 7-segment display + running light on the LEDs.
; Everything runs from interrupts; the main loop does nothing.
;
; Buttons:
;   C (center) : start counter
;   U (up)     : stop counter
;   D (down)   : reset counter to 0000
;   L (left)   : LED runs left  / change direction / off if already left
;   R (right)  : LED runs right / change direction / off if already right
;
; Interrupts used:
;   Timer0 (1 s)    : counter + 1
;   Timer1 (1 ms)   : 7-segment digit scan (software multiplexing)
;   Timer2 (0.2 s)  : LED step
;   5 buttons       : debounced, one interrupt per press
;
; Registers:
;   R0  = 0           R20 = 1          R21 = 0x8000
;   R23 = 0x0080      R24 = 2          R31 = 0x00FF
;   R1  = counter (binary)
;   R2  = 1 while the counter is running
;   R3  = LED pattern (one bit set)
;   R4  = LED direction: 0 off, 1 left, 2 right
;   R5  = digit being scanned (0-3)
;   R26-R29 = segment patterns of digits 0-3
;   R6, R7, R13 = temporaries
;
; Interrupts do not nest and do not save registers, so every handler
; uses its own registers and the main loop uses none.
; ============================================================

; ---------------- interrupt vectors ----------------
.addr 0
        JMP  btn_d_isr          ; button down  : reset
.addr 1
        JMP  btn_r_isr          ; button right : LEDs right
.addr 2
        JMP  btn_c_isr          ; button center: start
.addr 3
        JMP  btn_l_isr          ; button left  : LEDs left
.addr 4
        JMP  btn_u_isr          ; button up    : stop
.addr 5
        RETI                    ; timer4 (unused)
.addr 6
        RETI                    ; timer3 (unused)
.addr 7
        JMP  t2_isr             ; timer2: LED step
.addr 8
        JMP  t1_isr             ; timer1: display scan
.addr 9
        JMP  t0_isr             ; timer0: 1 s tick

; ---------------- start (address 11) ----------------
start:
        DI
        CLR  R0
        MOVI R20, 1
        MOVI R21, 0x8000
        MOVI R23, 0x0080        ; dp bit, 1 = off (active-low)
        MOVI R24, 2
        MOVI R31, 0x00FF        ; all digits off (active-low)

        CLR  R1                 ; counter = 0
        CLR  R2                 ; stopped
        CLR  R3                 ; LEDs off
        CLR  R4
        CLR  R5
        OUT  R3, LEDS
        CALL update_display

        ; Timer0: 10000 x 10000 clocks = 1 s at 100 MHz
        MOVI R13, 10000
        OUT  R13, TIMER0_PRESCALER
        OUT  R13, TIMER0_MAX
        ; Timer1: 100 x 1000 clocks = 1 ms
        MOVI R13, 100
        OUT  R13, TIMER1_PRESCALER
        MOVI R13, 1000
        OUT  R13, TIMER1_MAX
        ; Timer2: 1000 x 20000 clocks = 0.2 s
        MOVI R13, 1000
        OUT  R13, TIMER2_PRESCALER
        MOVI R13, 20000
        OUT  R13, TIMER2_MAX

        OUT  R0, TIMER0_INT_EN
        OUT  R0, TIMER1_INT_EN
        OUT  R0, TIMER2_INT_EN
        OUT  R0, TIMER0_EN
        OUT  R0, TIMER1_EN
        OUT  R0, TIMER2_EN

        OUT  R0, DEBOUNCE_EN
        OUT  R0, BTN_INT_EN

        MOVI R13, 0x03E7        ; mask: timer0-2 (bits 0-2) + all buttons (bits 5-9)
        OUT  R13, IRQ_MASK
        EI

main:
        JMP  main               ; idle, all work is done in interrupts

; ---------------- timer0: 1 s ----------------
t0_isr:
        CMP  R2, R0             ; running?
        JZ   t0_end
        INC  R1, R1
        MOVI R13, 10000         ; wrap 9999 -> 0
        CMP  R1, R13
        JNZ  t0_show
        CLR  R1
t0_show:
        CALL update_display
t0_end:
        RETI

; ---------------- timer1: show the next digit ----------------
t1_isr:
        OUT  R31, DIGITS        ; blank first, avoids ghosting
        CMP  R5, R0
        JZ   scan_0
        CMP  R5, R20
        JZ   scan_1
        CMP  R5, R24
        JZ   scan_2
scan_3:
        OUT  R29, SEGMENTS
        MOVI R7, 0x00F7         ; digit 3 on
        OUT  R7, DIGITS
        CLR  R5
        RETI
scan_0:
        OUT  R26, SEGMENTS
        MOVI R7, 0x00FE         ; digit 0 (rightmost) on
        OUT  R7, DIGITS
        INC  R5, R5
        RETI
scan_1:
        OUT  R27, SEGMENTS
        MOVI R7, 0x00FD
        OUT  R7, DIGITS
        INC  R5, R5
        RETI
scan_2:
        OUT  R28, SEGMENTS
        MOVI R7, 0x00FB
        OUT  R7, DIGITS
        INC  R5, R5
        RETI

; ---------------- timer2: LED step ----------------
t2_isr:
        CMP  R4, R20
        JZ   step_left
        CMP  R4, R24
        JZ   step_right
        RETI                    ; LEDs off
step_left:
        CMP  R3, R21            ; at LED15?
        JZ   wrap_left
        SHL  R3, R3, R20
        OUT  R3, LEDS
        RETI
wrap_left:
        MOV  R3, R20            ; back to LED0
        OUT  R3, LEDS
        RETI
step_right:
        CMP  R3, R20            ; at LED0?
        JZ   wrap_right
        SHR  R3, R3, R20
        OUT  R3, LEDS
        RETI
wrap_right:
        MOV  R3, R21            ; back to LED15
        OUT  R3, LEDS
        RETI

; ---------------- buttons ----------------
btn_c_isr:                      ; start
        MOV  R2, R20
        OUT  R0, TIMER0_CLEAR   ; first step comes a full second later
        RETI

btn_u_isr:                      ; stop
        CLR  R2
        RETI

btn_d_isr:                      ; reset
        CLR  R1
        OUT  R0, TIMER0_CLEAR
        CALL update_display
        RETI

btn_l_isr:
        CMP  R4, R20            ; already running left?
        JZ   leds_off
        MOV  R4, R20            ; direction = left
        CMP  R3, R0             ; was off?
        JNZ  btn_l_end
        MOV  R3, R20            ; start at LED0
        OUT  R3, LEDS
btn_l_end:
        RETI

btn_r_isr:
        CMP  R4, R24            ; already running right?
        JZ   leds_off
        MOV  R4, R24            ; direction = right
        CMP  R3, R0             ; was off?
        JNZ  btn_r_end
        MOV  R3, R21            ; start at LED15
        OUT  R3, LEDS
btn_r_end:
        RETI

leds_off:
        CLR  R4
        CLR  R3
        OUT  R3, LEDS
        RETI

; ---------------- counter -> 4 segment patterns ----------------
; binary -> BCD -> 7-segment, using the hardware converters
update_display:
        OUT  R1, BCD_IN
        IN   R6, BCD_OUT
        OUT  R6, SEGCONV_IN
        IN   R26, SEGCONV_OUT0
        OR   R26, R26, R23      ; dp off
        IN   R27, SEGCONV_OUT1
        OR   R27, R27, R23
        IN   R28, SEGCONV_OUT2
        OR   R28, R28, R23
        IN   R29, SEGCONV_OUT3
        OR   R29, R29, R23
        RET