;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                            ;
;                              DISPLAY ROUTINES                              ;
;                          Display Control Functions                         ;
;             Microprocessor-Based Pin-Ball Machine (AVR version)            ;
;                                                                            ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; This file contains the core functions for controlling the display hardware
; (7-segment displays and individual LEDs) for the pinball game.
;
; The public functions included are:
;    ClearDisplay       - Clear the entire display buffer to turn off all outputs.
;    DisplayHex         - Display a 16-bit value on a 4-digit 7-segment display.
;    DisplayLight       - Control a single LED in the LED matrix.
;    LEDMux             - Perform one cycle of the display multiplexing routine.
;
; The local functions included are:
;    None.
;
; Revision History:
;    05/26/25  Gabo Zhang               Initial project revision. 
;    05/30/25  Gabo Zhang               Added DisplayLight for single LED control and the
;                                       LEDMux function for multiplexing the display.               
;    06/04/25  Gabo Zhang               Implemented DisplayHex for score display and created
;                                       the corresponding HexTable for 7-segment mapping.
;    06/17/25  Gabo Zhang               Completed comments

; chip definitions
;.include "m328pdef.inc"         

; local include files
;.include "DisplayCons.inc"    


; --------------------------------------------------------------------------------
; Function:          DisplayHex
;
; Description:       Converts a 16-bit value into a 4-digit hexadecimal string and
;                    places the corresponding 7-segment display codes into the
;                    correct player's section of the shared display buffer.
;                    Called by `UpdateScore` in Helper.asm to update player scores
;                    on the screen.
;
; Operation:         The function first validates the player index in r18 is valid (1 or 2).
;                    It then determines the base offset into Disp_buffer for the specified
;                    player. The 16-bit value from r17:r16 is copied into r25:r24.
;                    The function then loops four times. In each iteration, it isolates the
;                    lowest 4 bits (nybble) of the value, looks up the corresponding
;                    7-segment pattern from the HexTable, and stores that pattern in the
;                    display buffer at the correct offset (base + loop_index). The 16-bit
;                    value is then shifted right by 4 bits to process the next nybble.
;
; Arguments:         r17:r16 - The 16-bit value to be displayed.
;                    r18     - The player index (must be 1 or 2).
;
; Return Value:      None.
;
; Local Variables:   r19 - Holds the base address offset for the player's display buffer.
;                    r20 - Used as a temporary register and for holding the nybble value.
;                    r21 - Loop counter (0 to 3).
;                    r22 - Holds the nybble value and later the 7-segment code from the table.
;                    r23 - Used as a temporary register for address calculations.
;                    r25:r24 - A working copy of the 16-bit value to be displayed.
;
; Shared Variables:  Disp_buffer - written to. The 4 bytes corresponding to the selected
;                    player's display are updated with new 7-segment codes.
;
; Global Variables:  None.
;
; Input:             None.
;
; Output:            Updates 4 bytes in the global Disp_buffer.
;
; Error Handling:    If the player index in r18 is not 1 or 2, the function
;                    exits immediately without modifying the Disp_buffer.
;
; Algorithms:        Uses a lookup table for hex-to-7-segment conversion.
;
; Data Structures:   Disp_buffer - A byte array used as the display memory.
;                    HexTable    - A program memory lookup table.
;
; Limitations:       Supports exactly two players. Assumes player display buffer sections
;                    are defined by Player1_Index and Player2_Index.
;
; Known Bugs:        None.
;
; Special Notes:     This function only updates the buffer in memory. A separate multiplexing
;                    routine (LEDMux) is required to visually render the buffer's
;                    contents on the physical 7-segment displays.
;
; Registers Changed: flags, r19, r20, r21, r22, r23, r24, r25, Y (YH:YL), Z (ZH:ZL)
; --------------------------------------------------------------------------------

.cseg

DisplayHex:
    ; --- Validate Player Index ---
    ; Check if player index is valid (1 or 2).
    cpi     r18, Max_players - 1    ; Compare with lower bound (1).
    brlo    DisplayHex_Done         ; If index < 1, return.
    cpi     r18, Max_players + 1    ; Compare with upper bound (2).
    brsh    DisplayHex_Done         ; If index > 2, return.

    ; --- Compute base address offset in disp_buffer for the player ---
    ldi     r19, Player1_Index      ; Load default offset for Player 1 (e.g., 8).
    cpi     r18, Max_players        ; Check if the request is for Player 2 (index 2).
    brne    skip_base_add           ; If not equal, it's Player 1; use default.
    ldi     r19, Player2_Index      ; Load offset for Player 2 (e.g., 12).
skip_base_add:

    ; --- Loop through 4 nybbles (from digit 0 to 3) ---
    ldi     r21, False              ; Initialize loop counter 'i' to 0.
    movw    r25:r24, r17:r16        ; Copy 16-bit value to r25:r24 for processing.

DisplayHex_Loop:
    ; Isolate the current nybble (lower 4 bits of the working value).
    mov     r22, r24                ; Copy the low byte of the value.
    andi    r22, HexMask            ; Mask out high nibble (keep bits 0-3).
    mov     r20, r22                ; Save index for lookup.
    clr     r23                     ; Clear register for carry.

    ; Look up the 7-segment code from the program memory HexTable.
    ; HexTable uses .DB, so addresses are byte-aligned in Program Memory.
    ; Z-pointer addresses are word-aligned for LPM, so we multiply by 2.
    ldi     ZH, high(2*HexTable)    ; Load base address High Byte.
    ldi     ZL, low(2*HexTable)     ; Load base address Low Byte.
    add     ZL, r20                 ; Add offset to Z-Low.
    adc     ZH, r23                 ; Add carry to Z-High.
    lpm     r22, Z                  ; Load 7-segment code from flash.

    ; Compute the final index into Disp_buffer = base_offset + loop_counter.
    mov     r23, r19                ; Copy base offset.
    add     r23, r21                ; Add loop counter.
    clr     r20                     ; Clear for carry.

    ; Store the 7-segment code at &disp_buffer[index].
    ldi     YH, high(disp_buffer)   ; Load buffer base address High.
    ldi     YL, low(disp_buffer)    ; Load buffer base address Low.
    add     YL, r23                 ; Add calculated index.
    adc     YH, r20                 ; Add carry.
    st      Y, r22                  ; Store the pattern.

    ; Perform a 16-bit logical right shift by 4 bits to process the next nybble.
    ; This moves the next digit into the lower 4 bits.
    lsr     r25                     ; Shift high byte right (bit 7->0, bit 0->C).
    ror     r24                     ; Rotate low byte right through carry.
    lsr     r25
    ror     r24
    lsr     r25
    ror     r24
    lsr     r25
    ror     r24

    ; Increment loop counter and check exit condition.
    inc     r21                     ; i++.
    cpi     r21, HEX_DIG            ; Check if i < 4.
    brlo    DisplayHex_Loop         ; If so, process next digit.

DisplayHex_Done:
    ret                             ; Return from subroutine.




; --------------------------------------------------------------------------------
; Function:          DisplayLight
;
; Description:       Turns a single, specified LED on or off by setting or clearing the
;                    corresponding bit within the shared Disp_buffer array. Used by
;                    `UpdateLEDPattern` in Helper.asm to create visual effects during
;                    gameplay.
;
; Operation:         The function first validates that the 1-based light index 'l' (in r16)
;                    is within the valid range. It then converts 'l' to a 0-based index
;                    by decrementing it. The 0-based index is used to calculate a 'row'
;                    index by dividing by 8 (via bit shifts) and a 'col' index using a
;                    modulo 8 operation (via a bitwise AND). The 'col' index is used to
;                    look up a bitmask from MaskTable. This will ensure that changing the
;                    state of one LED does not affect the rest. The function then loads the byte
;                    from Disp_buffer[row]. Based on the state 's' (in r17), it either
;                    ORs the mask to turn the light on or ANDs the inverted mask to turn
;                    it off, before storing the result back into the buffer.
;
; Arguments:         r16 - The 1-based index 'l' of the light to control.
;                    r17 - The desired state 's' (0 for OFF, non-zero for ON).
;
; Return Value:      None.
;
; Local Variables:   r19 - Holds the calculated row index.
;                    r20, r21 - Used to hold the address of the LED_row variable.
;                    r22 - Holds the calculated column index.
;                    r23 - Holds the bitmask retrieved from MaskTable.
;                    r24 - Holds the byte read from/written to Disp_buffer.
;                    r27 - Used as a zero-value register for 16-bit addition.
;
; Shared Variables:  Disp_buffer - The target byte within this buffer is read and written to.
;                    LED_row     - written to, but not used further within this function.
;
; Global Variables:  None.
;
; Input:             MaskTable - A program memory lookup table that maps a column index (0-7)
;                                to a single-bit mask (e.g., 0x01, 0x02, 0x04...).
;
; Output:            Modifies one byte in the global Disp_buffer.
;
; Error Handling:    If the light index 'l' is outside the valid range (1 to MAX_LIGHT_INDEX),
;                    the function returns immediately with no action.
;
; Algorithms:        Uses integer division and modulo (implemented with bit shifts and ANDs)
;                    to map a linear index to a 2D matrix location. Uses a lookup table
;                    for bitmask retrieval.
;
; Data Structures:   Disp_buffer - A byte array representing the state of all LEDs.
;
; Limitations:       Assumes an 8-digit LED matrix. The write to the global 'LED_row'
;                    variable appears redundant to the primary goal of this function.
;
; Known Bugs:        None.
;
; Special Notes:     This function only updates the buffer in memory. A separate multiplexing
;                    routine (LEDMux) is required to visually render the buffer's
;                    contents on the physical LEDs.
;
; Registers Changed: flags, r19, r20, r21, r22, r23, r24, r27, Y (YH:YL), Z (ZH:ZL)
; --------------------------------------------------------------------------------
DisplayLight:
    ; Check if light index 'l' is greater than the maximum allowed index.
    cpi     r16, MAX_LIGHT_INDEX + 1
    brsh    DisplayLight_Done       ; If (l > MAX_LIGHT_INDEX(64)), return.

    ; --- Calculate Row and Column from 1-Based Index 'l' ---
    dec     r16                     ; Convert 'l' to a 0-based index for calculations (l-1).

    ; Calculate row = (l-1) / 8.
    mov     r19, r16                ; Copy (l-1) to r19 for row calculation.
    lsr     r19                     ; Left-shift 1 bit  (divide by 2)
    lsr     r19                     ; Left-shift 2 bits (divide by 4)
    lsr     r19                     ; Left-shift 3 bits (divide by 8)

    ; Store the calculated row index. Note: This seems redundant for this function's purpose.
    ; sts     LED_row, r19


    ; Calculate col = (l-1) % 8. The original value of (l-1) is still in r16.
    andi    r16, ModMask               ; col = (l-1) & 0b00000111
    mov     r22, r16                ; Store first 3 bits (result of % 8) in r22 for lookup.

    ; --- Retrieve the column bitmask from MaskTable so the LED can be updated without affecting other LEDs ---
    clr     r23                     ; Zero r23 for use in 16-bit address addition (adc).
    mov     r24, r22                ; Copy column index to r24 for the lookup.

    ldi     ZL, low(2 * MaskTable)  ; Load Z pointer with the base address of MaskTable.
    ldi     ZH, high(2 * MaskTable)
    add     ZL, r24                 ; Add the column index as an offset to the table address.
    adc     ZH, r23
    lpm     r23, Z                  ; Load the column bitmask from program memory into r23.

    ; --- Calculate the address of disp_buffer[row] ---
    ldi     YL, low(disp_buffer)    ; Load Y pointer with the base address of the display buffer.
    ldi     YH, high(disp_buffer)
    add     YL, r19                 ; Add the row index to the buffer's base address.
    clr     r27                     ; Clear a register to use for the carry.
    adc     YH, r27                 ; Add carry to the high byte of the address.

    ; Load the current byte from the display buffer.
    ld      r24, Y

    ; --- Modify the buffer byte based on the desired state 's' ---
    tst     r17                     ; Check if state 's' (in r17) is zero.
    breq    DisplayLight_Off        ; If s == 0, branch to turn the light off.

DisplayLight_On:
    ; Turn the light ON by setting the bit.
    or      r24, r23                ; OR the buffer byte with the mask to turn on the LED at the calculated bit.
    st      Y, r24                  ; Store the modified byte back into the buffer.
    rjmp    DisplayLight_Done       ; Skip the 'Off' logic.

DisplayLight_Off:
    ; Turn the light OFF by clearing the bit.
    com     r23                     ; Invert the mask (e.g., 0x01 becomes 0xFE).
    and     r24, r23                ; AND the buffer byte with the inverted mask to turn the LED off at calculated bit.
    st      Y, r24                  ; Store the modified byte back into the buffer.

DisplayLight_Done:
    ret



; --------------------------------------------------------------------------------
; Function:          ClearDisplay
;
; Description:       Clears the entire 16-byte Disp_buffer by writing zero to every byte.
;                    This effectively turns off all connected LEDs and blanks all
;                    7-segment display digits. Called during initialization in Mainloop
;                    to ensure a clean visual state at startup.
;
; Operation:         The function initializes the Z-pointer to the start of the Disp_buffer.
;                    It then enters a loop that executes 16 times for 16 1-byte digits. In each iteration,
;                    it stores a zero value at the memory location pointed to by Z and
;                    then increments the pointer to the next byte. This process continues
;                    until all 16 bytes of the buffer have been cleared.
;
; Arguments:         None.
;
; Return Value:      None.
;
; Local Variables:   r16 - Holds the zero value (constant 'Clear') to write into the buffer.
;                    r17 - Serves as the loop counter, iterating from 0 to 15.
;                    Z (ZH:ZL) - A pointer that traverses the Disp_buffer from start to end.
;
; Shared Variables:  Disp_buffer - All 16 bytes of this buffer are written to (cleared).
;
; Global Variables:  None.
;
; Input:             None.
;
; Output:            Writes 0x00 to all 16 bytes of the Disp_buffer.
;
; Error Handling:    None.
;
; Algorithms:        Uses a simple counting loop to iterate through a memory buffer.
;
; Data Structures:   Disp_buffer - A 16-byte array in SRAM.
;
; Limitations:       The function is hardcoded to clear exactly 16 bytes. If the size
;                    of Disp_buffer changes, this function must be updated.
;
; Known Bugs:        None.
;
; Special Notes:     This is a utility function that should be called at the start of a
;                    game or any time the displays need to be reset. The visual effect
;                    is not immediate and depends on a separate display multiplexing
;                    routine (LEDMux).
;
; Registers Changed: flags, r16, r17, Z (ZH:ZL)
; --------------------------------------------------------------------------------

; Clears the 16-byte Disp_buffer by writing zero to each byte.
ClearDisplay:
    ; --- Initialization ---
    ldi     r16, False                  ; Load r16 with the value to write (0). 
    ldi     r17, False                  ; Initialize loop counter (r17) to 0.

    ; Load Z-pointer with the starting address of the display buffer.
    ldi     ZL, low(disp_buffer)
    ldi     ZH, high(disp_buffer)

; --- Main Clear Loop ---
; Loop 16 times to clear each byte of the buffer.
ClearLoop:
    ; Store zero at the current buffer location and advance the pointer.
    st      Z+, r16                 ; Disp_buffer[i] = 0; Z points to next byte.

    ; Check loop condition.
    inc     r17                     ; Increment loop counter.
    cpi     r17, NUM_DIG            ; Compare counter with the total size of the buffer.
    brlo    ClearLoop             ; If not all 16 bytes cleared, continue loop.
    ; If all bytes cleared, exit the loop.

    ret





; --------------------------------------------------------------------------------
; Function:          LEDMux
;
; Description:       Performs one step of the display multiplexing routine. This function
;                    is designed to be called every 1ms by a timer interrupt to refresh
;                    the 7-segment displays and LEDs.
;
; Operation:         On each call, this function refreshes a single digit of the display.
;                    1. It first disables all digit and segment drivers to prevent ghosting.
;                    2. It reads the current digit index from the shared variable 'curMuxDigit'.
;                    3. It fetches the corresponding 7-segment pattern for that digit from
;                       the 'disp_buffer'.
;                    4. It outputs this pattern to the 7-segment driver port (PORTC).
;                    5. It looks up the 16-bit digit-enable pattern for the current digit
;                       from the 'DigitTable' and outputs it to the digit-driver ports
;                       (PORTA and PORTD), activating only the current digit.
;                    6. It increments the digit index and saves it back to 'curMuxDigit'
;                       for the next call, wrapping around to 0 after the last digit.
;
; Arguments:         None.
;
; Return Value:      None.
;
; Local Variables:   r0  - Holds data for I/O operations (segment patterns, digit patterns).
;                    r18 - Holds the current digit index.
;                    r19 - Used as a zero-value register for 16-bit address calculations.
;                    r23 - Used as a temporary register for address calculations.
;                    Y (YH:YL) - Pointer to traverse the 'disp_buffer'.
;                    Z (ZH:ZL) - Pointer to traverse the 'DigitTable'.
;
; Shared Variables:  disp_buffer  - read from. Contains the 7-segment patterns to display.
;                    curMuxDigit  - read from and written to. Stores the index of the
;                                   digit to be refreshed in the next cycle. Maximum 16.
;
; Global Variables:  None.
;
; Input:             DigitTable - A program memory lookup table containing the 16-bit
;                                 patterns used to enable each individual digit driver.
;
; Output:            Writes patterns to hardware ports PORTA, PORTC, and PORTD to drive
;                    the physical display for one cycle.
;
; Error Handling:    None.
;
; Algorithms:        Uses time-division multiplexing to create the illusion of a fully lit,
;                    persistent display by rapidly cycling through each digit.
;
; Data Structures:   disp_buffer - An array in SRAM holding display data.
;                    DigitTable  - A lookup table in program memory for hardware control.
;
; Limitations:       The number of digits multiplexed is determined by the 'NUM_DIG'
;                    constant. Assumes a specific hardware wiring for PORTA, PORTC, PORTD.
;
; Known Bugs:        None 
;
; Special Notes:     This function is not intended to be called directly in a loop; it
;                    relies on a periodic interrupt for stable display brightness.
;
; Registers Changed: flags, r0, r18, r19, r23, Y (YH:YL), Z (ZH:ZL)
; --------------------------------------------------------------------------------

LEDMux:


StartLEDMux:                            ; Entry point for the multiplexing routine.
    ; First, turn off all LED drivers to prevent ghosting during the transition.
    LDI R18, False                      ; Load 0 (all segments off).
    OUT PORTD, R18                      ; Disable Digit Drivers on PORTD.
    OUT PORTA, R18                      ; Disable Digit Drivers on PORTA.

    CLR R19                             ; Clear high-byte register for 16-bit address math.
    LDS R18, curMuxSeg                  ; Load the current digit index (0 to 15).

MuxLED:                                 ; Main logic to drive one segment/digit.
    ; Get the segment pattern for the current digit from the display buffer.
    LDI YL, LOW(disp_buffer)            ; Load buffer base address.
    LDI YH, HIGH(disp_buffer)
    ADD YL, R18                         ; Add current digit index.
    ADC YH, R19                         ; Add carry.

    LD  R0, Y                           ; Load the segment pattern (e.g., 'A' for digit 0).
    OUT PORTC, R0                       ; Drive the segments on PORTC.

    ; Look up the digit-enable pattern from the DigitTable.
    MOV R23, R18                        ; Copy index.
    LSL R23                             ; Multiply by 2 (2 bytes per entry).

    LDI  ZL, LOW(2 * DigitTable)        ; Load DigitTable base address.
    LDI  ZH, HIGH(2 * DigitTable)

    ADD  ZL, R23                        ; Add offset.
    CLR  R23
    ADC  ZH, R23                        ; Add carry.

    ; Load and output the 16-bit digit-enable pattern.
    LPM R0, Z+                          ; Load Low Byte (PORTA pattern).
    OUT PORTA, R0                       ; Activate corresponding digit line on PORTA.
    LPM R0, Z                           ; Load High Byte (PORTD pattern).
    OUT PORTD, R0                       ; Activate corresponding digit line on PORTD.


    ; Update the segment/digit index for the next call.
    INC     R18                         ; Increment index.
    CPI R18, NUM_DIG                    ; Check if we wrapped around (>= 16).
    BRLO    UpdateSegmentCnt            ; If < 16, save it.
    
    ; If we get here, R18 >= NUM_DIG, so reset to 0
    CLR     R18                         ; Reset to 0.

UpdateSegmentCnt:                       ; Logic to save the new state.
    STS curMuxSeg, R18                  ; Save updated index.


EndLEDMux:                              ; End of the multiplexing routine.
    RET                                 ; Return from the subroutine.





; HexTable
; Moved to SystemTables.asm


; MaskTable
; Moved to SystemTables.asm


; DigitTable
; Moved to SystemTables.asm



.dseg

;Disp_buffer:    .byte NUM_DIG       ; 16-byte display buffer for 4 digits and 8 LEDs rows
;LED_row:        .byte 1             ; storage for LED row number in displaylight function
;curMuxSeg:      .BYTE   1           ;current digit number being multiplexed
curMuxSegPatt:  .BYTE   1       ;current digit output pattern
