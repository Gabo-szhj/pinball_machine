;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                            ;
;                             TIMER INITIALIZATION                           ;
;                        Timer0 Setup and Interrupts                         ;
;             Microprocessor-Based Pin-Ball Machine (AVR version)            ;
;                                                                            ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; This file configures Timer0 for a 1ms tick and provides the Timer0 compare
; match ISR to drive sensor debounce and display multiplexing. It also
; configures Timer1 for CTC toggle mode on OC1A to generate audio tones.
;
; The public functions included are:
;    InitTimer0                 - Sets Timer0 to CTC mode and enables interrupt.
;    Timer0CompareMatchHandler  - ISR wrapper that debounces sensors and muxes LEDs.
;    InitTimer1                 - Sets Timer1 to CTC toggle mode for sound output.
;
; Local helper labels are used inside the ISR for context save/restore flow.
;
; Revision History:
;    05/26/25  Gabo Zhang               Initial project revision.
;    06/14/25  Gabo Zhang               Added comments and clarifications.
;    12/25/25  Gabo Zhang               Standardized header format.

.cseg

; ------------------------------------------------------------------------------
; InitTimer0
;
; Description:       Initializes Timer0 to generate an interrupt every 1 millisecond.
;                    Called during system startup in Mainloop, this establishes the
;                    1ms timebase required for the multiplexing and debounce ISRs.
;
; Operation:         This function configures Timer0 to operate in Clear Timer on Compare
;                    Match (CTC) mode. It sets the prescaler to 64 and loads the
;                    Output Compare Register (OCR0) with a pre-calculated value
;                    (OCR0_MATCH_VALUE) to achieve a 1ms interrupt interval, assuming
;                    a 8MHz system clock. Finally, it enables the Timer0 Compare
;                    Match interrupt.
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  None.
; Global Variables:  None.
;
; Input:             None.
; Output:            TCCR0 - written
;                    OCR0 - written
;                    TIMSK - written
;
; Error Handling:    None.
;
; Algorithms:        None.
; Data Structures:   None.
; Limitations:       Assumes a 8MHz system clock for 1ms timing accuracy.
; Known Bugs:        None.
; Special Notes:     The constants TCCR0_CTC_PRESC64 and OCR0_MATCH_VALUE must be
;                    defined elsewhere for this function to work correctly.
; Registers Changed: flags, R16, R17
; ------------------------------------------------------------------------------
InitTimer0:
    
    ; Set Timer/Counter Control Register 0 (TCCR0) for CTC mode.
    ; WGM01=1, WGM00=0 selects CTC mode. CS02=1, CS01=0, CS00=0 selects prescaler 64.
    ldi     r16, TCCR0_CTC_PRESC64              
    out     TCCR0, r16

    ; Set the Output Compare Register 0 (OCR0) to the match value.
    ; Formula: (Clock_Freq / (Prescaler * Target_Freq)) - 1
    ; For 8MHz / (64 * 1000Hz) - 1 = 124.
    ldi     r16, OCR0_MATCH_VALUE
    out     OCR0, r16                           

    ; Enable the Output Compare Match Interrupt for Timer0.
    in      r17, TIMSK                          ; Read current Timer Interrupt Mask.
    ori     r17, TIMSK_OCIE0_ENABLE             ; Set the OCIE0 bit.
    out     TIMSK, r17                          ; Write back to enable interrupt.

    ret


; ------------------------------------------------------------------------------
; Timer0CompareMatchHandler
;
; Description:       This is the Interrupt Service Routine (ISR) for the Timer0 Compare
;                    Match event. This ISR is the heartbeat of the main loop system,
;                    periodically yielding control to `SensorDebounceMatrix` and
;                    `LEDMux` to maintain user interface responsiveness.
;
; Operation:         Upon being triggered every 1ms, this handler first saves the context
;                    by pushing the status register (SREG) and several general-purpose
;                    registers onto the stack. It then calls the SensorDebounceMatrix
;                    subroutine. After the subroutine returns, it restores the saved
;                    registers and SREG before returning from the interrupt.
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  This ISR will modify shared variables via the subroutines it calls
;                    (SensorDebounceMatrix).
; Global Variables:  None.
;
; Input:             None.
; Output:            None.
;
; Error Handling:    None.
;
; Algorithms:        None.
; Data Structures:   Stack is used for context saving.
; Limitations:       None.
; Known Bugs:        None.
; Special Notes:     This is an Interrupt Service Routine and is not called directly.
;                    It preserves all registers it uses by saving/restoring them on the stack.
; Registers Changed: flags, R0, R16, R18, R19, ZL, ZH (all are saved and restored)
; ------------------------------------------------------------------------------
Timer0CompareMatchHandler:

StartTimer0OverflowHandler:             ; Context Save
    push r0         ; Save R0 (used by LPM instruction).
    push r16        ; Save working register R16.
    in r16, SREG    ; Read Status Register (flags).
    push r16        ; Save Status Register.
    push r17        ; Save all other potentially used registers.
    push r18
    push r19
    push r20
    push r21
    push r22
    push r23
    push r24
    push r25
    push r30        ; Save Z-pointer (low byte).
    push r31        ; Save Z-pointer (high byte).
    push YL         ; Save Y-pointer (low byte).
    push YH         ; Save Y-pointer (high byte).


DoTiming:                               ; ISR Body
    RCALL   SensorDebounceMatrix        ; Call sensor scanning routine (1ms interval).
    RCALL   LEDMux                      ; Call display multiplexing routine (1ms interval).

    ;RJMP   DoneTimer0CompareMatchHandler  ; (Optional explicit jump).


DoneTimer0CompareMatchHandler:          ; Context Restore
    pop YH          ; Restore registers in reverse order of PUSH.
    pop YL
    pop r31
    pop r30
    pop r25
    pop r24
    pop r23
    pop r22
    pop r21
    pop r20
    pop r19
    pop r18
    pop r17
    pop r16         ; Restore saved Status Register value.
    out SREG, r16   ; Write back to SREG to restore flags.
    pop r16         ; Restore working register R16.
    pop r0          ; Restore R0.
    RETI                                ; Return from Interrupt.



; InitTimer1
;
; Description:       This function initializes Timer/Counter 1 for sound 
;                    generation.
;
; Operation:         Configures Timer 1 for CTC (Clear Timer on Compare) mode and
;                    sets the OC1A pin to toggle on a compare match. It also sets
;                    a prescaler of 8, which starts the timer immediately.However,
;                    since OCR1A is set to 0 no sound will play initially. 
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  None.
; Global Variables:  None.
;
; Input:             None.
; Output:            Timer/Counter 1 registers (TCCR1A, TCCR1B) are configured.
;
; Error Handling:    None.
;
; Algorithms:        None.
; Data Structures:   None.
;
; Registers Changed: flags, R16
;

InitTimer1:
    ; Configure Timer1 Control Register A (TCCR1A)
    ; Clear WGM11 and WGM10 for CTC mode (Mode 4 uses WGM13:0 = 0100).
    ; Set COM1A0 to 1 to Toggle OC1A on Compare Match.
    clr     r16
    ldi     r16, (1 << COM1A0)  ; Toggle OC1A on match.
    out     TCCR1A, r16

    ; Configure Timer1 Control Register B (TCCR1B)
    ; Set WGM12 to 1 for CTC mode.
    ; Set CS11 to 1 for Prescaler = 8.
    ldi     r16, (1 << WGM12) | (1 << CS11)
    out     TCCR1B, r16

    ; Note: OCR1A is not set here; it will be set by PlayNote to control frequency.
    ret
