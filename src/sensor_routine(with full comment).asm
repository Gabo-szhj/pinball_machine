;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                            ;
;                               SENSOR ROUTINES                              ;
;                           Sensor Matrix Debounce                           ;
;             Microprocessor-Based Pin-Ball Machine (AVR version)            ;
;                                                                            ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; This file contains the functions for scanning and debouncing the sensor
; matrix, and for retrieving validated sensor presses.
;
; The public functions included are:
;    SensorDebounceMatrix - periodic matrix scan and debounce routine (called by timer)
;    GetSensor            - waits for and returns the code of a debounced sensor
;    
;
; The local functions included are:
;    HaveSensor           - checks if a new debounced sensor event is available
;
; Revision History:
;    5/14/25    Gabo Zhang           Initial Revision
;    5/15/25    Gabo Zhang           Revised GetSensor and HaveSensor
;    5/16/25    Gabo Zhang           Added SensorDebounce
;    5/19/25    Gabo Zhang           Revised SensorDebounce to avoid auto-repeat
;    6/14/25    Gabo Zhang           Added comments
;    1/03/25    Gabo Zhang           Revised comments


;get the definitions for the device
;.include  "m64def.inc"

; local include files
;.include  "SensorCons.inc"



.cseg
; ------------------------------------------------------------------------------
; SensorDebounceMatrix
;
; Description:       This procedure debounces all the sensors in the sensor array.
;                    It handles the low-level scanning of the switch matrix. In the
;                    main system, this function is called periodically (every 1ms)
;                    by the Timer0 ISR (`Timer0CompareMatchHandler`) to filter noise
;                    and provide stable input events to the game logic in `Mainloop`.
;
; Operation:         This function activates one matrix row at a time via OUTPUT_PORT
;                    and reads the column states from INPUT_PORT. If no keys are
;                    pressed, it rotates to the next row. When a key press is detected,
;                    it enters a debouncing state, waiting for the input to remain 
;                    stable for a number of cycles. The debounce counter is reset to
;                    the debounce time (10) if the sensor is deactivated and then
;                    decremented if the sensor is triggered. If the counter reaches
;                    negative, a continuous press is detected (no autorepeat). When
;                    the counter reaches 0, the sensor code is calculated (row*8+col)
;                    and stored, and the available flag is set.
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  Debounced_sensor_code - written (8-bit calculated code).
;                    Sensor_available      - written (1=ready, 0=not).
;                    Debounce_counter      - read/written (debounce timer).
;                    Debouncing            - read/written (state flag).
;                    prev_input            - read/written (stability check).
;                    rowcount              - read/written (active row 1-5).
; Global Variables:  None.
;
; Input:             Reading from INPUT_PORT (8 bit column reading).
; Output:            None.
;
; Error Handling:    None.
;
; Algorithms:        Debounce integration/counter.
; Data Structures:   None.
; Limitations:       None.
; Known Bugs:        None.
; Special Notes:     Critical code, assumes interrupts disabled (called from ISR).
; Registers Changed: r18, r19, r20, r21, r22, r23, r24, r25, r0, r1
; ------------------------------------------------------------------------------



SensorDebounceMatrix:
    
    in      r18, INPUT_PORT         ; Read input from the hardware port connected 
                                    ; to the switch matrix.

    
    lds     r19, debouncing         
    cpi     r19, DEBOUNCE_ACTIVE    
    brne    CheckStartDebounce      ; Check if a debounce sequence is already in 
                                    ; progress. If the debouncing flag is not 1, no 
                                    ; key was recently pressed, so jump to check for 
                                    ; a new press.

    ; --------------------------
    ; Already debouncing: A switch was pressed, and we're waiting for the signal to stabilize.
    ; --------------------------
    lds     r20, prev_input         
    cp      r18, r20                ; Compare the current input (r18) with the previous 
                                    ; input (r20).
    brne    InputChangedDuringDebounce ; If they don't match, the input is noisy or another 
                                    ; key was pressed; jump to reset the debounce timer.

    ; --- Input is stable; continue counting down---
    ; Note that r21 was compared to 0 two times to avoid decrementing a continuous hold 
    ; until it wraps to a positive number again
    lds     r21, debounce_counter   ; Load the remaining debounce time (counter) into r21.
    cpi     r21, SENSOR_ZERO               
    brlt    DebounceContinue        ; If the counter is negative (from a continuous hold), 
                                    ; return and don't debounce the same swtich.
    dec     r21                     
    sts     debounce_counter, r21   ; Decrement the debounce counter
    cpi     r21, SENSOR_ZERO               ; Check if the counter has just reached zero.
    brlt    ContinuousHold          ; If the counter went below zero, it means a continuous 
                                    ; press is detected.
    brne    DebounceContinue        ; If the counter is still not zero and positive, return 
                                    ; and debounce again when the interrupt is called

    ; --------------------------
    ; Debounced! The switch press is valid. Now, find which column was pressed.
    ; --------------------------
    lds     r22, rowcount           ; Load the current active row number (e.g., 0-7) into r22.
    ldi     r23, COL_START_INDEX    ; Initialize the column counter (r23) to 1.

DetectCol:                          ; detect the switch's column to find the sensor_code
    bst     r18, 0                  ; Store bit 0 of the input register (r18) into the T flag 
                                    ; of the status register.
    brtc    ColFound                ; If the T flag is clear (0), the key in this column is 
                                    ; pressed then branch calculate the sensor_code.
    lsr     r18                     ; If not pressed, shift the input bits right to check 
                                    ; the next column.
    inc     r23                     ; Increment the column counter.
    cpi     r23, N_COLUMNS          ; Compare column count to the total number of columns to 
                                    ; prevent an infinite loop if no key is found
    brlt    DetectCol               ; If we haven't checked all columns, loop back.

    ; This code is reached only if the loop finishes without finding a pressed key, which 
    ; indicates an error state.
    ldi     r20, DEBOUNCE_TIME      ; Load the full debounce time value into r20.
    sts     debounce_counter, r20   ; Reset the debounce counter.
    rjmp    DebounceDone            ; Jump to the end.

ContinuousHold:                     ; If a continuous hold is detected
    clr     r25                     
    sts     sensor_available, r25   ; Clear the 'sensor_available' flag to 0, indicating no 
                                    ; new key press is ready.
    rjmp    DebounceDone            ; Jump to return

ColFound:                           ; A pressed key was located at the current 'rowcount' 
                                    ; then find the column where it is pressed

    ; Match the tested routine behavior:
    ; SensorCode = rowcount * 8 + colcount
    ; Where rowcount is 1..5 and colcount is 1..8, producing codes 0x09..0x30.
    ldi     r24, N_COLUMNS          ; Load the number of columns (8) into r24 for multiplication.
    mul     r22, r24                ; Multiply rowcount (r22) by 8. The 16-bit result is in r1:r0.
    add     r0, r23                 ; Add the column count (r23) to the low byte of the result.
    sts     debounced_sensor_code, r0 ; Store the calculated sensor code in debounced_sensor_code.

    ldi     r25, SENSOR_ONE               
    sts     sensor_available, r25   ; Set the 'sensor_available' flag to 1 (true) to signal a 
                                    ; switch is debounced and ready.
    clr     r19                    
    sts     debouncing, r19         ; Clear the 'debouncing' flag; this switch press has been 
                                    ; debounced, don't stay in the debounced state

    rjmp    DebounceDone            ; Jump to the end of the routine.

InputChangedDuringDebounce:         ; The input changed while waiting, so the signal is unstable. 
                                    ; Reset the process.
    ldi     r20, DEBOUNCE_TIME      
    sts     debounce_counter, r20   ; Reset the counter to full debounce wait time
    sts     prev_input, r18         ; Save the new, changed input as the previous state to check 
                                    ; for stability in the next interrupt
    clr     r19                     
    sts     debouncing, r19         ; Reset the 'debouncing' flag to 0 to restart the process 
                                    ; on the next pass.

DebounceContinue:
    rjmp    DebounceDone            ; Jump to the end of the function for this cycle.

CheckStartDebounce:                 ; This section runs if no debounce was in progress. It checks 
                                    ; for a new key press through the loops.
    ; The check `cpi r18, ALL_ROWS_HIGH correctly determines if any key on the active row is pressed.
    cpi     r18, ALL_ROWS_HIGH     ; Compare the input with the value for "no keys pressed" (0xFF).
    breq    RotateRow               ; If the values are equal (no key pressed), branch to activate 
                                    ; the next row.
    
    ; --- A new key press is detected ---
    ldi     r19, DEBOUNCE_ACTIVE    
    sts     debouncing, r19         ; Set the 'debouncing' flag to true.
    sts     prev_input, r18         ; Save the current input state as the one to verify against 
                                    ; during debouncing.
    rjmp    DebounceDone            ; Return for this cycle; debouncing will continue on the 
                                    ; next interrupt.

RotateRow:
    ; --------------------------
    ; No keys are pressed on the current row, so activate the next row.
    ; --------------------------
    lds     r18, OUTPUT_PORT        ; Read the current state of the row output pins.
    cpi     r18, LAST_ROW_MASK      ; Compare the current row pattern to the first row pattern 
                                    ; to see if the current row is the last row (5th)
    breq    FirstRow                ; If it's the last row, branch to wrap around to the first row.

    ; --- General rotate to the next row ---
    lds     r19, rowcount           
    sec                             ; Set carry for rotation
    rol     r18                     ; Rotate the bits in r18 left through the Carry flag. 
                                    ; (ex. 0b11111110 -> 0b11111101)
    sts     OUTPUT_PORT, r18        ; Send the new pattern to the output port, activating 
                                    ; the next row.
    inc     r19                     
    cpi     r19, N_ROWS + 1         ; Check if we've exceeded the number of rows
    brlo    StoreRowCount            ; If not, store the incremented value
    ldi     r19, ROW_START_INDEX    ; Wrap around to row 1
StoreRowCount:
    sts     rowcount, r19           ; Store the row counter.
    rjmp    DebounceDone            ; Jump to return

FirstRow:                           ; This handles wrapping around from the last row back 
                                    ; to the first.
    ldi     r18, NEXT_ROW_MASK      
    sts     OUTPUT_PORT, r18        ; Activate the first row by loading the bitmask for the 
                                    ; first row (0b11111110)
    ldi     r19, ROW_START_INDEX    
    sts     rowcount, r19           ; Reset the row counter to 1.
    rjmp    DebounceDone            ; Jump return.

DebounceDone:
    ret                             ; Return from the subroutine.



; ------------------------------------------------------------------------------
; GetSensor
;
; Description:       Blocking function that waits for and returns the code of a
;                    debounced sensor. While the Mainloop typically uses non-blocking
;                    polling of `sensor_available`, this function provides a synchronous
;                    input mechanism for test modes or states requiring user input
;                    before proceeding.
;
; Operation:         The procedure loops calling `HaveSensor` until `sensor_available`
;                    is TRUE. It then disables interrupts, retrieves `debounced_sensor_code`
;                    into R16, clears `sensor_available`, restores interrupts, and returns.
;
; Arguments:         None.
; Return Value:      R16 - Debounced sensor code.
;
; Local Variables:   None.
; Shared Variables:  Sensor_available      - read/written (cleared to 0).
;                    Debounced_sensor_code - read.
; Global Variables:  None.
;
; Input:             None.
; Output:            R16 with sensor code.
;
; Error Handling:    None.
;
; Algorithms:        None.
; Data Structures:   None.
; Limitations:       Blocking wait.
; Known Bugs:        None.
; Special Notes:     None.
; Registers Changed: r16, r17, R0, Flags.
; ------------------------------------------------------------------------------

GetSensor:
WaitLoop:                               ; Waiting for a debounced sensor to return its code

	rcall	HaveSensor
    breq    WaitLoop                    ; Check if the sensor_available flag is set in a 
                                        ; loop to see if a sensor is debounced

	in 		R0, SREG			        ; save the flags before critical code 
    cli                                 ; Disable interrupts (critical section)

    lds     r16, debounced_sensor_code  ; Load the sensor_code for the current debounced 
                                        ; sensor calculated in the debouncing function 
    ldi     r17, FALSE
    sts     sensor_available, r17       ; Clear the sensor_available flag to show that 
                                        ; the last debounced sensor is read 
	sts		debounced_sensor_code, r17  ; clear the debounced_sensor_code to prep for 
                                        ; the next sensor reading
    
	out		SREG, R0                    ; restore the flags after the critical code          
    ret



; ------------------------------------------------------------------------------
; HaveSensor
;
; Description:       Checks if a new debounced sensor event is available without
;                    blocking. It inspects the `sensor_available` flag managed by
;                    the ISR-driven `SensorDebounceMatrix`. Used by polling loops
;                    in `Mainloop` or helper functions to detect input readiness.
;
; Operation:         Reads the `sensor_available` flag. If it is non-zero (TRUE),
;                    the Zero flag in SREG is cleared. If zero (FALSE), the Zero
;                    flag is set.
;
; Arguments:         None.
; Return Value:      None (Status via Flags).
;
; Local Variables:   None.
; Shared Variables:  Sensor_available - read.
; Global Variables:  None.
;
; Input:             None.
; Output:            Zero flag in SREG (0 = Sensor Ready, 1 = No Sensor).
;
; Error Handling:    None.
;
; Algorithms:        None.
; Data Structures:   None.
; Limitations:       Does not return the sensor code, only status.
; Known Bugs:        None.
; Special Notes:     None.
; Registers Changed: r16, Flags.
; ------------------------------------------------------------------------------

HaveSensor:                 ; check if there is a debounced sensor available
    lds     r16, sensor_available
    cpi     r16, SENSOR_FALSE      ; Zero flag = 1 if r16 == 0
                            ; Zero flag used in the GetSensor() function to 
                            ; break the waiting loop
    ret






.DSEG                   ; Start data segment for all Sensor routines

debounce_counter:      .BYTE 1   ; Countdown timer for debounce check

debouncing:            .BYTE 1   ; Flag: 1 if currently debouncing, 0 otherwise

prev_input:            .BYTE 1   ; Stores previous PORTE read

rowcount:              .BYTE 1   ; Currently active row index (0-7)
;sensor_available:      .BYTE 1   ; Flag: 1 if debounced sensor is ready, 0 otherwise

;debounced_sensor_code: .BYTE 1   ; Code for debounced sensor (row * 8 + col) 8 bit value




.cseg

; ==============================================================================
; SCORE & SOUND TABLE
; Format per entry: .dw POINTS, FREQUENCY
; Each entry is 4 bytes. 40 entries total.
; Moved to SystemTables.asm
; ==============================================================================
