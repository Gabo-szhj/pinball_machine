;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                            ;
;                               SENSOR ROUTINES                              ;
;                           Sensor Matrix Debounce                           ;
;             Microprocessor-Based Pin-Ball Machine (AVR version)            ;
;                                                                            ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; This file contains the routines for debouncing the switch matrix and reporting
; sensor activations to the rest of the system.
;
; The public functions included are:
;    SensorDebounceMatrix  - Debounces the sensor matrix and stores codes.
;
; Revision History:
;    5/14/25   Gabo Zhang              initial revision
;
;
.cseg
; ------------------------------------------------------------------------------
; SensorDebounceMatrix
;
; Description:  This procedure debounces all the sensors in the sensor array.
;               It doesn’t handle auto-repeat for those same sensors, since every
;               activation can only count towards the score once. It is expected to
;               be called approximately once every millisecond. In the context of the
;               main loop, this function is called periodically (e.g., every 1ms by
;               Timer0 ISR) to filter switch noise and update the shared 
;               `debounced_sensor_code` and `sensor_available` flags for foreground
;               routines.
;
; Operation:    The sensors are debounced after activation. The debounce counter
;               is reset if the sensor is deactivated and then incremented if the
;               sensor is triggered with the ball. When the counter reaches the
;               debounce threshold, the appropriate flag is set and the sensor code
;               is stored in the shared variables for the other functions. This is
;               done with interrupts disabled (critical code).
;
; Arguments:    None
; Return Value: None
;
; Local Variables:  None
; Shared Variables: 
;       Debounced_sensor_code – read and written as the shared variable of the debounced sensor
;       Debounce_counter[] – read and written for each sensor
;       Sensor_available – written to indicate that a sensor is debounced 
;       Sensor_array[] – read; contains all the sensor activations
;       DEBOUNCE_TIME – read; constant for the initial debounce array value
; Global Variables:  None.
;
; Input:    Sensor_array[i], code_of sensor, to find when a sensor is activated and the code of that sensor 
; Output:   None
;
; Error Handling:   None
;
; Algorithms:   None
; Data Structures:  None
; Limitations:  None
; Known Bugs:   None
; Special Notes:    None
; ------------------------------------------------------------------------------



SensorDebounceMatrix:
    
    in      r18, INPUT_PORT         ; Read input from the hardware port connected to the switch matrix.

    
    lds     r19, debouncing         
    cpi     r19, DEBOUNCE_ACTIVE    
    brne    CheckStartDebounce      ; Check if a debounce sequence is already in progress. If the debouncing flag is not 1, no key was recently pressed, so jump to check for a new press.

    ; --------------------------
    ; Already debouncing: A switch was pressed, and we're waiting for the signal to stabilize.
    ; --------------------------
    lds     r20, prev_input         
    cp      r18, r20                ; Compare the current input (r18) with the previous input (r20).
    brne    InputChangeDuringDebounce ; If they don't match, the input is noisy or another key was pressed; jump to reset the debounce timer.

    ; --- Input is stable; continue counting down---
    ; Note that r21 was compared to 0 two times to avoid decrementing a continuous hold until it wraps to a positive number again
    lds     r21, debounce_counter   ; Load the remaining debounce time (counter) into r21.
    cpi     r21, SENSOR_ZERO               
    brlt    DebounceContinue        ; If the counter is negative (from a continuous hold), return and don't debounce the same swtich.
    dec     r21                     
    sts     debounce_counter, r21   ; Decrement the debounce counter
    cpi     r21, SENSOR_ZERO               ; Check if the counter has just reached zero.
    brlt    ContinuousHold          ; If the counter went below zero, it means a continuous press is detected.
    brne    DebounceContinue        ; If the counter is still not zero and positive, return and debounce again when the interrupt is called

    ; --------------------------
    ; Debounced! The switch press is valid. Now, find which column was pressed.
    ; --------------------------
    lds     r22, rowcount           ; Load the current active row number (e.g., 0-7) into r22.
    ldi     r23, COL_START_INDEX    ; Initialize the column counter (r23) to 1.

DetectCol:                          ; detect the switch's column to find the sensor_code
    bst     r18, 0                  ; Store bit 0 of the input register (r18) into the T flag of the status register.
    brtc    ColFound                ; If the T flag is clear (0), the key in this column is pressed; branch calculate the sensor_code.
    lsr     r18                     ; If not pressed, shift the input bits right to check the next column.
    inc     r23                     ; Increment the column counter.
    cpi     r23, N_COLUMNS          ; Compare column count to the total number of columns to prevent an infinite loop if no key is found
    brlt    DetectCol               ; If we haven't checked all columns, loop back.

    ; This code is reached only if the loop finishes without finding a pressed key, which indicates an error state.
    ldi     r20, DEBOUNCE_TIME      ; Load the full debounce time value into r20.
    sts     debounce_counter, r20   ; Reset the debounce counter.
    rjmp    DebounceDone            ; Jump to the end.

ContinuousHold:                     ; If a continuous hold is detected
    clr     r25                     
    sts     sensor_available, r25   ; Clear the 'sensor_available' flag to 0, indicating no new key press is ready.
    rjmp    DebounceDone            ; Jump to return

ColFound:                           ; A pressed key was located at the current 'rowcount' and 'colcount' 
    ; Calculate a unique code for the key using the formula: row * 8 + column.
    ldi     r24, N_COLUMNS          ; Load the number of columns (8) into r24 for multiplication.
    mul     r22, r24                ; Multiply rowcount (r22) by 8. The 16-bit result is in r1:r0.
    add     r0, r23                 ; Add the column count (r23) to the low byte of the result.
    sts     debounced_sensor_code, r0 ; Store the final calculated key code in debounced_sensor_code.

    ldi     r25, SENSOR_ONE               
    sts     sensor_available, r25   ; Set the 'sensor_available' flag to 1 (true) to signal a switch is debounced and ready.
    clr     r19                    
    sts     debouncing, r19         ; Clear the 'debouncing' flag; this switch press has been debounced, don't stay in the debounced state.
    ldi     r23, COL_START_INDEX    ; MAYBE GET RID OF THIS?
    rjmp    DebounceDone            ; Jump to the end of the routine.

InputChangedDuringDebounce:         ; The input changed while waiting, so the signal is unstable. Reset the process.
    ldi     r20, DEBOUNCE_TIME      
    sts     debounce_counter, r20   ; Reset the counter to full debounce wait time
    sts     prev_input, r18         ; Save the new, changed input as the previous state to check for stability in the next interrupt
    clr     r19                     
    sts     debouncing, r19         ; Reset the 'debouncing' flag to 0 to restart the process on the next pass.

DebounceContinue:
    rjmp    DebounceDone            ; Jump to the end of the function for this cycle.

CheckStartDebounce:                 ; This section runs if no debounce was in progress. It checks for a new key press through the loops.
    ; The check `cpi r18, INPUT_RELEASED` correctly determines if any key on the active row is pressed.
    cpi     r18, INPUT_RELEASED     ; Compare the input with the value for "no keys pressed" (0xFF).
    breq    RotateRow               ; If the values are equal (no key pressed), branch to activate the next row.
    
    ; --- A new key press is detected ---
    ldi     r19, ROW_START_INDEX    
    sts     debouncing, r19         ; Set the 'debouncing' flag to true.
    sts     prev_input, r18         ; Save the current input state as the one to verify against during debouncing.
    rjmp    DebounceDone            ; Return for this cycle; debouncing will continue on the next interrupt.

RotateRow:
    ; --------------------------
    ; No keys are pressed on the current row, so activate the next row.
    ; --------------------------
    ldi     r20, SENSOR_ZERO              
    sts     sensor_available, r20   ; Clear the 'sensor_available' flag since we are moving to a new row.

    lds     r18, OUTPUT_PORT        ; Read the current state of the row output pins.
    cpi     r18, LAST_ROW_MASK     ; Compare the current row pattern to the first row pattern to see if the current row is the last row (5th)
    breq    FirstRow                ; If it's the last row, branch to wrap around to the first row.

    ; --- General rotate to the next row ---
    lds     r19, rowcount           
    sec                             
    rol     r18                     ; Rotate the bits in r18 left through the Carry flag. (e.g., 0b11111110 -> 0b11111101)
    sts     OUTPUT_PORT, r18        ; Send the new pattern to the output port, activating the next row.
    inc     r19                     
    sts     rowcount, r19           ; Increment the row counter.
    rjmp    DebounceDone            ; Jump to return

FirstRow:                           ; This handles wrapping around from the last row back to the first.
    ldi     r18, FIRST_ROW_MASK      
    sts     OUTPUT_PORT, r18        ; Activate the first row by loading the bitmask for the first row (0b11111110)
    ldi     r19, ROW_START_INDEX
    sts     rowcount, r19           ; Reset the row counter to 1.
    rjmp    DebounceDone            ; Jump return.

DebounceDone:
    ret                             ; Return from the subroutine.



; ------------------------------------------------------------------------------
; GetSensor()
; Description:  This function returns with the code of the debounced sensor activation from the sensor array in register R16 
;               and clears the sensor_available flag. It will stay idle if no sensor is activated and debounced.
; Operational Description:
;       The procedure loops while sensor_available is FALSE, staying idle. Once it becomes TRUE, 
;       moves the debounced_sensor_code into register R16, clears sensor_available, and exits. 
;       This is done with interrupts disabled (critical code).
; Arguments:    None
; Return Value: None
; Local Variables:  None
; Shared Variables: 
;       Sensor_available – read and written to indicate that a sensor is debounced 
;       Debounced_sensor_code – read the code of the last debounced sensor
; Input:    None 
; Output:   R16 with debounced sensor code
; Error Handling:   None
; Algorithms:   None
; Data Structures:  None
; Limitations:  None
; Known Bugs:   None
; Special Notes:    None
; ------------------------------------------------------------------------------

GetSensor:
WaitLoop:                       ; Waiting for a debounced sensor to return its code

	rcall	HaveSensor
    breq    WaitLoop            ; Check if the sensor_available flag is set in a loop to see if a sensor is debounced

	in 		R0, SREG			; save the flags before critical code 
    cli                         ; Disable interrupts (critical section)

    lds     r16, debounced_sensor_code ;Load the sensor_code for the current debounced sensor calculated in the debouncing function 
    ldi     r17, SENSOR_FALSE
    sts     sensor_available, r17      ; Clear the sensor_available flag to show that the last debounced sensor is read 
	sts		debounced_sensor_code, r17 ; clear the debounced_sensor_code to prep for the next sensor reading
    
	out		SREG, R0             ; restore the flags after the critical code          
    ret



; ------------------------------------------------------------------------------
; HaveSensor()
; Description:  This function checks to see if a new debounced sensor event is available. 
;               Resets the Zero flag when such event is available.
; Operational Description:
;       Reads the sensor_available flag and clears the Zero flag if the sensor_available flag is on. 
;       This is done with interrupts disabled (critical code).
; Arguments:    None
; Return Value: Zero Flag
; Local Variables:  None
; Shared Variables: 
;       Sensor_available – read to indicate that a sensor is debounced 
; Input:    None 
; Output:   Zero flag in the status register
; Error Handling:   None
; Algorithms:   None
; Data Structures:  None
; Limitations:  Doesn’t return actual sensor code, just checks presence of debounced sensors
; Known Bugs:   None
; Special Notes:    None
; ------------------------------------------------------------------------------

HaveSensor:                 ; check if there is a debounced sensor available
    lds     r16, sensor_available
    cpi     r16, FALSE          ; Zero flag = 1 if r16 == 0
                            ; Zero flag used in the GetSensor() function to break the waiting loop
    ret






.DSEG                   ; Start data segment NEED TO DECLARE THESE IN INITSENSOR?

debounce_counter:      .BYTE 1   ; Countdown timer for debounce check

debouncing:            .BYTE 1   ; Flag: 1 if currently debouncing

prev_input:            .BYTE 1   ; Stores previous PORTE read

rowcount:              .BYTE 1   ; Currently active row index (0-7)
sensor_available:      .BYTE 1   ; Flag: 1 if debounced sensor is ready

debounced_sensor_code: .BYTE 1   ; Code for debounced sensor (row * 8 + col)
