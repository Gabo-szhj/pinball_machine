;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                       ;
;                           DISPLAY INITIALIZATION                      ;
;                    Port & Hardware Initialization Functions           ;
;             Microprocessor-Based Pin-Ball Machine (AVR version)       ;
;                                                                       ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; This file contains the functions for initializing the hardware I/O ports and
; the display system variables.
;
; The public functions included are:
;    InitIOPort           - Initializes the data direction for all required ports.
;    InitDisplay          - Initializes the display buffer and multiplexing 
;                           variables.
;
; Revision History:
;    5/26/25    Gabo Zhang           Initial revision and formatting.
;    5/28/25    Gabo Zhang           Revised InitDisplay
;    6/14/25    Gabo Zhang           Updated comments


;get the definitions for the device
;.include  "m64def.inc"

; local include files
;.include  "DisplayCons.inc"


.cseg
; ------------------------------------------------------------------------------
; InitIOPort
;
; Description:       This procedure initializes the I/O ports for the system. In the
;                    main loop, this is critical for setting up Ports A, C, and D to
;                    drive the 7-segment displays and LEDs before any multiplexing occurs.
;
; Operation:         The Data Direction Register (DDR) for Ports A, C, and D are
;                    configured to set all their pins as outputs. All port outputs
;                    are then cleared to 0 to ensure they start in a known-off 
;                    state.
;
; Arguments:         None.
; Return Value:      None.
; Local Varaibles:   None. 
; Shared Variables:  None.
; Global Variables:  None.
; Input:             None.
; Output:            None.
; Error Handling:    None.
; Algorithms:        None.
; Data Structures:   None.
;
; Registers Changed: R16
; ------------------------------------------------------------------------------
InitIOPort:
    ; Configure Port C (segments), Port D (digits), and Port A (LEDs) as outputs
    ldi     r16, PORT_OUTPUT        ; Load register with all 1s for output 
                                    ; direction
    out     DDRC, r16               ; Set Port C direction to all outputs
    out     DDRD, r16               ; Set Port D direction to all outputs
    out     DDRA, r16               ; Set Port A direction to all outputs

    ; Clear all port outputs to ensure a known starting state (all off)
    ldi     r16, PORT_INPUT         ; Load register with all 0s
    out     PORTC, r16              ; Clear all segment outputs
    out     PORTD, r16              ; Clear all digit select outputs
    out     PORTA, r16              ; Clear all general LED outputs

    ret


; ------------------------------------------------------------------------------
; InitDisplay
;
; Description:       Initializes the display buffer and multiplexing variables. This
;                    must be called once at startup. Used by Mainloop to clear the
;                    visual output buffer and reset multiplexing counters so the
;                    Timer0 ISR starts with a known blank state.
;
; Operation:         A 16-byte buffer in memory ('disp_buffer') is cleared to all
;                    zeros. The multiplexing state variables 'curMuxSeg' and
;                    'curMuxSegPatt' are then initialized to their starting 
;                    values.
;
; Arguments:         None.
; Return Value:      None.
; Local Varaibles:   None. 
;
; Shared Variables:  disp_buffer    - Written (cleared to all 0s).
;                    curMuxSeg      - Written (set to 0).
;                    curMuxSegPatt  - Written (set to INIT_SEG_PATT).
; Global Variables:  None.
; Input:             None.
; Output:            None.
; Error Handling:    None.
; Algorithms:        None.
; Data Structures:   None.
;
; Registers Changed: R16, R17, Z (R31:R30)
; ------------------------------------------------------------------------------
InitDisplay:
    ; --- Clear disp_buffer (16 bytes) to all zeros ---
    ldi     r16, ZERO               ; Value to write (0)
    ldi     r17, NUM_DIG            ; Loop counter for 16 bytes
    ldi     ZL, low(disp_buffer)    ; Point Z to the start of the display buffer
    ldi     ZH, high(disp_buffer)

ClearDispBuf_Loop:
    st      Z+, r16                 ; Store 0 into buffer and increment pointer
    dec     r17                     
    brne    ClearDispBuf_Loop       ; Continue until all 16 bytes are cleared

    ; --- Initialize multiplexing variables ---
    sts     curMuxSeg, r16          ; Set curMuxSeg = 0

    ldi     r16, INIT_SEG_PATT      ; Load the initial multiplexing pattern
    sts     curMuxSegPatt, r16      ; Store it to the shared variable

    ret