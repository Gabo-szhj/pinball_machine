;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                            ;
;                                 HELPER.ASM                                 ;
;                       Game Flow & Support Routines                         ;
;             Microprocessor-Based Pin-Ball Machine (AVR version)            ;
;                                                                            ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; This file contains helper routines for game flow control and score handling.
; It manages attract-mode display, player start selection, score updates,
; LED pattern changes, ball dispensing, and high-score checks.
;
; The public functions included are:
;    ShowAttractMode        - Displays high score during attract mode.
;    WaitForStartButton     - Blocking start button handler (1P/2P select).
;    UpdateScore            - Updates player scores and checks thresholds.
;    UpdateLEDPattern       - Updates LED pattern based on game state.
;    DispenseBall           - Controls ball launch timing.
;    CheckHighScore         - Compares and stores high scores.
;
; Local helper labels are used within the above routines for flow control.
;
; Revision History:
;    05/26/25  Gabo Zhang               Initial project revision.
;    06/04/25  Gabo Zhang               Added DisplayHex support and update logic.
;    06/17/25  Gabo Zhang               Implemented UpdateLEDPattern and DispenseBall.
;    09/19/25  Gabo Zhang               Refined high score logic and EEROM interaction.
;    12/20/25  Gabo Zhang               Added WaitForStartButton with debounce.
;    12/22/25  Gabo Zhang               Debugged player switching and score carry.
;    12/25/25  Gabo Zhang               Standardized header format.

.cseg

; ------------------------------------------------------------------------------
; ShowAttractMode
;
; Description:       Displays the stored high score on both player displays to
;                    indicate the system is idle and ready for a new game. This is
;                    the default state of the main loop when no game is active.
;
; Operation:         Reads the 2-byte high score from EEPROM (address 0) using
;                    `ReadEEROM`. Then calls `DisplayHex` twice to render this
;                    value onto the 7-segment displays for Player 1 and Player 2.
;                    Note that `ReadEEROM` is blocking as it waits for SPI transfer completion.
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   r16, r17 (High Score value), r18 (Player Index).
; Shared Variables:  HighScore_L, HighScore_H (updated from EEPROM).
; Global Variables:  None.
;
; Input:             EEPROM contents at address 0.
; Output:            Updates the display buffer with the high score.
;
; Error Handling:    None.
;
; Algorithms:        None.
; Data Structures:   None.
; Limitations:       None.
; Known Bugs:        None.
; Special Notes:     None.
; Registers Changed: Flags, r16, r17, r18, Y (YH:YL), Z (ZH:ZL).
; ------------------------------------------------------------------------------
ShowAttractMode:
    ; Display high score in attract mode to show system is working
    push r16
    push r17
    push r18
    push r30
    push r31
    
    ; Read high score from EEROM (non-blocking if EEROM not ready)
    ldi r16, HIGHSCORE_SIZE ; Prepare to read 2 bytes.
    ldi r17, HIGHSCORE_ADDR ; Set address to 0.
    ldi YL, low(HighScore_L) ; Point Y to destination buffer.
    ldi YH, high(HighScore_L)
    call ReadEEROM          ; Execute Read.
    
    ; Display high score on Player 1 display
    lds r16, HighScore_L    ; Load High Score Low Byte.
    lds r17, HighScore_H    ; Load High Score High Byte.
    ldi r18, PLAYER_1_ID    ; Select Player 1 display.
    call DisplayHex         ; Update display buffer.
    
    ; Display same on Player 2 display (or could show "READY")
    lds r16, HighScore_L    ; Load High Score Low Byte.
    lds r17, HighScore_H    ; Load High Score High Byte.
    ldi r18, PLAYER_2_ID    ; Select Player 2 display.
    call DisplayHex         ; Update display buffer.
    
    ; Pop all the used registers so it doesnt affect the rest of the system
    pop r31
    pop r30
    pop r18
    pop r17
    pop r16
    ret


; ------------------------------------------------------------------------------
; WaitForStartButton
;
; Description:       Checks for a start button press to begin a game. It implements
;                    logic to distinguish between a single press (1 Player) and a
;                    double press (2 Players). This function is called repeatedly
;                    by the main loop while in attract mode.
;
; Operation:         Polls the `sensor_available` flag. If the start button is
;                    detected, it enters a blocking delay loop (~500ms) to wait for a
;                    potential second press. If a second press occurs within this window,
;                    it returns 2 (for 2 players); otherwise, it returns 1. If no button
;                    is pressed, it performs a short blocking delay to allow background tasks
;                    (ISR) to run and loops. This function blocks until a start button press is detected.
;
; Arguments:         None.
; Return Value:      r16 - Number of players (1 or 2).
;
; Local Variables:   r16, r17, r18, r19, r20 (Counters and sensor codes).
; Shared Variables:  sensor_available, debounced_sensor_code (read/cleared).
; Global Variables:  None.
;
; Input:             Sensor inputs via shared variables.
; Output:            None.
;
; Error Handling:    None.
;
; Algorithms:        Polling with timeout window for double-click detection.
; Data Structures:   None.
; Limitations:       Blocking during the delay window (though ISRs still fire).
; Known Bugs:        None.
; Special Notes:     None.
; Registers Changed: Flags, r16.
; ------------------------------------------------------------------------------
WaitForStartButton:
    ; Output: R16 = 1 (1 Player) or 2 (2 Players)
    ; Non-blocking: checks sensor and returns, allowing display to update
    push r17
    push r18
    push r19
    
WaitStart_Loop:
    ; Check if sensor is available (non-blocking)
    lds r16, sensor_available
    tst r16
    breq WaitStart_NoSensor  ; If no sensor event (0), continue loop to refresh display.
    
    ; Sensor detected - check if it's start button
    cli                         ; Disable interrupts for atomic access.
    lds r16, debounced_sensor_code ; Load sensor code.
    ldi r17, ZERO
    sts sensor_available, r17   ; Clear flag.
    sei                         ; Enable interrupts.
    
    subi r16, SCORE_MAP_OFFSET
    cpi r16, START_BTN_CODE     ; Compare with Start Button Code.
    brne WaitStart_Loop         ; If not start button, keep waiting.
    
    ; Start button pressed. Wait for potential second press to select 2 players.
    ; First press detected. Wait short window (~500ms) to check for double press.
    ldi r18, START_DELAY_OUTER            ; Initialize outer loop counter.
DelayWindow:
    ldi r19, START_DELAY_INNER            ; Initialize inner loop counter.
DelayInner:
    ldi r20, START_DELAY_INNER            ; Initialize inner-most loop counter.
DelayInner2:
    dec r20
    brne DelayInner2
    dec r19
    brne DelayInner
    
    ; During this delay, check for second press of the start button
    lds r17, sensor_available
    tst r17
    breq ContinueDelay          ; If no input, continue waiting.
    
    ; Second press detected
    cli                         ; read the sensor code for the second press
    lds r16, debounced_sensor_code
    ldi r17, ZERO
    sts sensor_available, r17
    sei
    subi r16, SCORE_MAP_OFFSET
    cpi r16, START_BTN_CODE     ; Check if input is Start Button.
    breq TwoPlayerMode          ; If so, valid double-press: Start 2 Player Game.
    
ContinueDelay:
    dec r18                     ; Decrement outer loop.
    brne DelayWindow            ; Continue window if time remains.
    
    ; Time expired, no second press - 1 player mode
    ldi r16, SINGLE_PLAYER_COUNT ; Return 1.
    pop r19
    pop r18
    pop r17
    ret
    
TwoPlayerMode:
    ldi r16, DEFAULT_PLAYERS    ; Return 2.
    pop r19
    pop r18
    pop r17
    ret
    
WaitStart_NoSensor:
    ; No sensor yet - allow display to update by returning briefly
    ; This allows the timer interrupt to update the display
    ; Use a small delay to prevent spinning
    ldi r18, NO_SENSOR_DELAY
WaitDelay:
    ldi r19, START_DELAY_INNER
WaitDelayInner:
    dec r19
    brne WaitDelayInner
    dec r18
    brne WaitDelay
    
    ; Check again
    rjmp WaitStart_Loop



; ------------------------------------------------------------------------------
; UpdateScore
;
; Description:       Adds points to the current player's score and updates the
;                    display. Called by the main loop whenever a valid playfield
;                    sensor is triggered during gameplay.
;
; Operation:         Determines the active player (Player 1 or 2) using `CurrentPlayer`.
;                    Adds the 16-bit points argument to that player's score variables
;                    (Score_Px_L/H), handling carry. Then calls `DisplayHex` to
;                    refresh the visual score for that player. This function is
;                    synchronous and non-blocking (returns immediately after calculation).
;
; Arguments:         r17:r16 - Points to add (16-bit value).
;
; Return Value:      None.
;
; Local Variables:   r18, r20, r21.
; Shared Variables:  CurrentPlayer, Score_P1_L/H, Score_P2_L/H.
; Global Variables:  None.
;
; Input:             None.
; Output:            Updates score variables and display buffer.
;
; Error Handling:    None.
;
; Algorithms:        16-bit addition with carry.
; Data Structures:   None.
; Limitations:       None.
; Known Bugs:        None.
; Special Notes:     None.
; Registers Changed: Flags, r16, r17, r18, r19, r20, r21, Z (ZH:ZL), Y (YH:YL).
; ------------------------------------------------------------------------------
UpdateScore:
    ; Arguments: r17:r16 = Points to add (16-bit)
    ;            Uses CurrentPlayer to determine which score to update
    push r16
    push r17
    push r18
    push r19
    push r20
    push r21
    push r30
    push r31

    ; --- Get Current Player and Score Address ---
    ldi YL, low(Score_P1_L)
    ldi YH, high(Score_P1_L)
    
    lds r18, CurrentPlayer  ; 0 or 1
    tst r18
    breq DoUpdate           ; If 0 (P1), Y is correct
    
    adiw YL, 2              ; If 1 (P2), advance Y by 2 bytes
    
DoUpdate:
    ld r20, Y               ; Load Score Low
    ldd r21, Y+1            ; Load Score High
    
    add r20, r16            ; Add points low
    adc r21, r17            ; Add points high
    
    st Y, r20               ; Store Score Low
    std Y+1, r21            ; Store Score High
    
    ; Update Display
    mov r16, r20            ; Pass score to DisplayHex
    mov r17, r21
    inc r18                 ; Convert 0/1 to 1/2 for DisplayHex
    call DisplayHex
    
    rjmp UpdateScoreDone

UpdateScoreDone:
    pop r31
    pop r30
    pop r21
    pop r20
    pop r19
    pop r18
    pop r17
    pop r16
    ret


; ------------------------------------------------------------------------------
; UpdateLEDPattern
;
; Description:       Cycles through the LED matrix to create a visual effect.
;                    Called by the main loop during specific game events to
;                    animate the playfield lights.
;
; Operation:         Increments the current LED index (`led_idx_curr`). Turns off
;                    the LED at the previous index (`led_idx_prev`) and turns on
;                    the LED at the new index using `DisplayLight`. Wraps around
;                    from LED 64 to 1. This function is synchronous and non-blocking.
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   r16, r17.
; Shared Variables:  led_idx_curr, led_idx_prev (read/written).
; Global Variables:  None.
;
; Input:             None.
; Output:            Modifies display buffer via `DisplayLight`.
;
; Error Handling:    None.
;
; Algorithms:        Circular buffer indexing.
; Data Structures:   None.
; Limitations:       None.
; Known Bugs:        None.
; Special Notes:     None.
; Registers Changed: Flags, r16, r17, r18, r19.
; ------------------------------------------------------------------------------
UpdateLEDPattern:
    push r16
    push r17
    push r18
    push r19

    ; Load previous index to turn off the old LED
    lds r16, led_idx_prev   ; Load index of the previously lit LED.
    tst r16                 ; Check if it is 0 (initial state).
    breq SkipPrevOff        ; If 0, no LED to turn off.
    ldi r17, ZERO              ; Set state = OFF.
    rcall DisplayLight      ; Call helper to update buffer: r16=index, r17=state.
SkipPrevOff:

    ; Increment current index to advance the pattern
    lds r16, led_idx_curr   ; Load current index.
    inc r16                 ; Increment index.
    cpi r16, MAX_LIGHT_INDEX + 1 ; Check if index exceeds max (64).
    brlo NoWrap             ; If less than 65, continue.
    ldi r16, SINGLE_PLAYER_COUNT ; Wrap around to 1.
NoWrap:
    sts led_idx_curr, r16   ; Save new current index.
    sts led_idx_prev, r16   ; Save as previous for next cycle.

    ; Turn on current LED
    ldi r17, TRUE             ; Set state = ON.
    rcall DisplayLight      ; Call helper to update buffer: r16=index, r17=state.

    pop r19
    pop r18
    pop r17
    pop r16
    ret


; ------------------------------------------------------------------------------
; DispenseBall
;
; Description:       Activates the ball release solenoid for a fixed duration to
;                    put a ball into play. Called by the main loop at the start of
;                    a turn.
;
; Operation:         Sets a specific bit on PORTA (Bit 7) high to energize the
;                    solenoid. Enters a blocking software delay loop to hold the solenoid
;                    active for approximately 1 second. Then clears the bit to
;                    de-energize the solenoid. This function blocks execution during the delay.
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   r20, r21, r22 (Delay counters).
; Shared Variables:  PORTA (Bit 7 modified).
; Global Variables:  None.
;
; Input:             None.
; Output:            Toggles physical output pin.
;
; Error Handling:    None.
;
; Algorithms:        Software delay loop.
; Data Structures:   None.
; Limitations:       Blocking delay pauses main loop logic (but ISRs continue).
; Known Bugs:        None.
; Special Notes:     Assumes Solenoid is on PORTA, Bit 7.
; Registers Changed: Flags, r20, r21, r22.
; ------------------------------------------------------------------------------
DispenseBall:
    ; Turn ON Solenoid (Assumes specific Port/Pin, e.g., PORTA, Bit 7)
    sbi PORTA, SOLENOID_BIT     ; Set bit to energize solenoid.
    
    ; Wait ~1 Second to ensure ball is released
    ldi r20, SOLENOID_DELAY    ; Initialize outer loop counter.
DispenseDelay:
    ldi r21, BYTE_MAX          ; Initialize middle loop.
    ldi r22, BYTE_MAX          ; Initialize inner loop.
DelayLoop:
    dec r22                    ; Decrement inner.
    brne DelayLoop             
    dec r21                    ; Decrement middle.
    brne DelayLoop
    dec r20                    ; Decrement outer.
    brne DispenseDelay
    
    ; Turn OFF Solenoid to prevent overheating
    cbi PORTA, SOLENOID_BIT    ; Clear bit to de-energize.
    ret


; ------------------------------------------------------------------------------
; CheckHighScore
;
; Description:       Compares the current players' scores against the stored high
;                    score. If a new record is set, it updates the EEPROM. Called
;                    at the end of a game by the main loop.
;
; Operation:         Reads the current high score from EEPROM (blocking operation). Compares
;                    the larger of the two player scores with the stored record. A strictly
;                    larger score is written to EEPROM once (blocking operation).
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   r16, r17, r18, r19, r20, r21.
; Shared Variables:  Score_P1_L/H, Score_P2_L/H, HighScore_L/H.
; Global Variables:  None.
;
; Input:             Scores from variables and EEPROM.
; Output:            Updates EEPROM if a score is beaten.
;
; Error Handling:    None.
;
; Algorithms:        16-bit comparison.
; Data Structures:   None.
; Limitations:       None.
; Known Bugs:        None.
; Special Notes:     None.
; Registers Changed: Flags, r16-r21, Z, Y.
; ------------------------------------------------------------------------------
CheckHighScore:
    ; Compare current player scores with high score stored in EEROM
    ; If any player beats the high score, update EEROM
    push r16
    push r17
    push r18
    push r19
    push r20
    push r21
    push r30
    push r31
    
    ; --- Read High Score from EEROM (address 0) ---
    ldi r16, HIGHSCORE_SIZE ; Read 2 bytes
    ldi r17, HIGHSCORE_ADDR ; Starting address 0
    ldi YL, low(HighScore_L)
    ldi YH, high(HighScore_L)
    call ReadEEROM          ; Read high score from EEROM
    
    ; Select the larger unsigned player score.
    lds r18, Score_P1_L
    lds r19, Score_P1_H
    lds r20, Score_P2_L
    lds r21, Score_P2_H
    cp r18, r20
    cpc r19, r21
    brsh CompareStoredScore
    mov r18, r20
    mov r19, r21

CompareStoredScore:
    lds r20, HighScore_L
    lds r21, HighScore_H
    cp r20, r18
    cpc r21, r19
    brsh CheckHighScoreDone

FoundNewHighScore:
    ; New high score detected (in r18:r19)
    sts HighScore_L, r18
    sts HighScore_H, r19
    
    ; Write to EEROM
    ldi r16, HIGHSCORE_SIZE ; Write 2 bytes
    ldi r17, HIGHSCORE_ADDR ; Address 0
    ldi YL, low(HighScore_L)
    ldi YH, high(HighScore_L)
    call WriteEEROM
    rjmp CheckHighScoreDone

CheckHighScoreDone:
    pop r31
    pop r30
    pop r21
    pop r20
    pop r19
    pop r18
    pop r17
    pop r16
    ret