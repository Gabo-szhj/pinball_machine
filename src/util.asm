;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                            ;
;                                UTIL.ASM                                    ;
;                          Multi-Byte Math Utilities                         ;
;             Microprocessor-Based Pin-Ball Machine (AVR version)            ;
;                                                                            ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; This file contains multi-byte arithmetic utility functions that are not
; natively supported by the AVR instruction set, such as 24-by-16 bit division.
;
; The public functions included are:
;    Div24by16U         - Performs 24-by-16 bit unsigned integer division.
;
; Revision History:
;    06/04/25  Gabo Zhang               Initial project revision. Attempted a 
;                                       Div24by16U through GenAI
;    06/17/25  Gabo Zhang               Completed the function through example
;                                       on the course website
;    09/19/25  Gabo Zhang               Revised comments

.cseg

; --------------------------------------------------------------------------------
; Function:          Div24by16U
;
; Description:       Performs 24-by-16 bit unsigned integer division. Utilized by
;                    the `PlayNote` routine (called from Mainloop logic) to calculate
;                    PWM frequencies for sound generation.
;
; Operation:         This function implements a bit-serial restoring division algorithm.
;                    It iterates 24 times, effectively performing a 40-bit left shift
;                    across the combined dividend and remainder registers in each step.
;                    After each shift, it compares the 16-bit remainder to the divisor.
;                    If the remainder is greater or equal, the divisor is subtracted.
;                    The carry flag resulting from this comparison is shifted into the
;                    LSB of the dividend register, which gradually builds the quotient.
;
; Arguments:         r20:r19:r18 - The 24-bit unsigned dividend.
;                    r17:r16     - The 16-bit unsigned divisor.
;
; Return Values:     r20:r19:r18 - The 24-bit unsigned quotient.
;                    r4:r3       - The 16-bit unsigned remainder.
;
; Local Variables:   r22         - number of bits left in division
; Shared Variables:  None
; Global Variables:  None
;
; Input:             Dividend and divisor in specified registers.
; Output:            Quotient and remainder in specified registers.
;
; Error Handling:    None
;
; Algorithms:        Restoring division
; Data Structures:   None
;
; Known Bugs:        None
;
; Limitations:       Performs unsigned division only. Passing a divisor of zero might
;                    result in an infinite loop.
;
; Special Notes:     None
;
; Registers Changed: Flags, r3, r4, r18, r19, r20, r22.
; --------------------------------------------------------------------------------
Div24by16U:
    ; --- Initialization ---
    ldi     r22, DIV24_BITCOUNT ; Set bit loop counter for 24 bits (size of dividend).
    clr     r4                  ; Clear Remainder Low Byte.
    clr     r3                  ; Clear Remainder High Byte.

; --- Division Loop ---
; Uses Restoring Division algorithm.
Div24by16Loop:
    ; Shift the entire 40-bit working register (Dividend + Remainder) left by 1.
    ; This moves the MSB of the Dividend into the LSB of the Remainder.
    rol     r18                 ; Rotate Dividend LSB left through Carry.
    rol     r19                 ; Rotate Dividend Mid.
    rol     r20                 ; Rotate Dividend MSB.
    rol     r3                  ; Rotate Remainder Low (Carry from Div moves in).
    rol     r4                  ; Rotate Remainder High.

    ; Compare the current 16-bit Remainder (r4:r3) with the 16-bit Divisor (r17:r16).
    cp      r3, r16             ; Compare Low Bytes.
    cpc     r4, r17             ; Compare High Bytes with Carry.

    ; If Carry is set (Remainder < Divisor), we cannot subtract.
    brcs    Div24by16SkipSub    

    ; If Carry is clear (Remainder >= Divisor), subtract Divisor from Remainder.
    sub     r3, r16             ; Subtract Low Byte.
    sbc     r4, r17             ; Subtract High Byte with Carry.

Div24by16SkipSub:
    ; The Carry flag now essentially contains the inverted quotient bit.
    ; If we subtracted (C=0), bit is 1. If we skipped (C=1), bit is 0.
    ; This will be handled by the 'com' instructions at the end.

    dec     r22                 ; Decrement bit counter.
    brne    Div24by16Loop       ; Loop until all 24 bits processed.

    ; Shift the final Carry (inverted last bit) into the quotient.
    rol     r18                 
    rol     r19
    rol     r20

    ; Invert the quotient registers to get the correct result.
    ; Because 'rol' shifts in Carry, and Carry=1 means "too small" (0),
    ; the result is bit-inverted.
    com     r18                 ; Invert Low Byte.
    com     r19                 ; Invert Middle Byte.
    com     r20                 ; Invert High Byte.

    ; Result: Quotient in r20:r19:r18, Remainder in r4:r3.
    ret
