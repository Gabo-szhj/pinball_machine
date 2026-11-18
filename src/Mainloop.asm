;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                            ;
;                                   MAINLOOP                                 ;
;                         Pinball Controller Main Code                       ;
;                   Microprocessor-Based Pin-Ball Machine (AVR)              ;
;                                                                            ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; This file contains the main loop that coordinates the entire pinball system
; operations. It begins by initializing the stack, configuring I/O ports for
; displays and sensors, setting up sound PWM, and enabling the SPI interface
; for EEPROM communication.
;
; Operating as a microprocessor-based pinball machine, the system begins by
; initializing all components before entering an infinite main loop. It waits
; for a start button press to initialize the game state. During gameplay, it
; continuously debounces sensors to update scores and play sounds while
; monitoring for tilt conditions. When a ball drains, the count decrements
; and turns switch if in 2-player mode. Upon game completion, final scores
; are displayed, and if a new high score is achieved, it is saved to EEPROM.
;
; The public functions included are:
;    Reset              - System entry point; initializes hardware and state.
;    InPlayLoop         - Main infinite loop for game execution and event handling.
;    HandleTilt         - Processes tilt sensor events and penalizes the player.
;    HandleBallOut      - Manages ball loss and turn logic.
;    CheckNextTurn      - Determines if player switch or game end is needed.
;    LoopToStart        - Checks ball counts to decide game continuation.
;    EndGame            - Handles high score checks and return to attract mode.
;
; Revision History:
;    05/26/25  Gabo Zhang               Initial project revision.
;    06/02/25  Gabo Zhang               Basic loop with display muxing working.
;    06/15/25  Gabo Zhang               Integrated sensor debounce ISR.
;    09/20/25  Gabo Zhang               Added high score loading and saving.
;    12/18/25  Gabo Zhang               Implemented multi-player logic and turn handling.
;    12/23/25  Gabo Zhang               Fixed ball counting and end-game transition bugs.
;    12/25/25  Gabo Zhang               Standardized and detailed header.
;    01/04/26  Gabo Zhang               Revised header format to match system standard.

;set the device
;.device  ATMEGA64




;get the definitions for the device
.include  "m64def.inc"

;include all the .inc files since all .asm files are needed here (no linker)
.include "DisplayCons.inc"
.include "SpeakerEEROMCons.inc"
.include "SensorCons.inc"

.cseg





;setup the vector area

.org    $0000

        JMP     Reset                   ;reset vector
        JMP     PC                      ;external interrupt 0
        JMP     PC                      ;external interrupt 1
        JMP     PC                      ;external interrupt 2
        JMP     PC                      ;external interrupt 3
        JMP     PC                      ;external interrupt 4
        JMP     PC                      ;external interrupt 5
        JMP     PC                      ;external interrupt 6
        JMP     PC                      ;external interrupt 7
        JMP     PC                      ;timer 2 compare match
        JMP     PC                      ;timer 2 overflow
        JMP     PC                      ;timer 1 capture
        JMP     PC                      ;timer 1 compare match A
        JMP     PC                      ;timer 1 compare match B
        JMP     PC                      ;timer 1 overflow
        JMP     Timer0CompareMatchHandler                      ;timer 0 compare match
        JMP     PC                      ;timer 0 overflow
        JMP     PC                      ;SPI transfer complete
        JMP     PC                      ;UART 0 Rx complete
        JMP     PC                      ;UART 0 Tx empty
        JMP     PC                      ;UART 0 Tx complete
        JMP     PC                      ;ADC conversion complete
        JMP     PC                      ;EEPROM ready
        JMP     PC                      ;analog comparator
        JMP     PC                      ;timer 1 compare match C
        JMP     PC                      ;timer 3 capture
        JMP     PC                      ;timer 3 compare match A
        JMP     PC                      ;timer 3 compare match B
        JMP     PC                      ;timer 3 compare match C
        JMP     PC                      ;timer 3 overflow
        JMP     PC                      ;UART 1 Rx complete
        JMP     PC                      ;UART 1 Tx empty
        JMP     PC                      ;UART 1 Tx complete
        JMP     PC                      ;Two-wire serial interface
        JMP     PC                      ;store program memory ready



; ------------------------------------------------------------------------------
; Reset
;
; Description:       System entry point after a hardware reset. Initializes the
;                    stack pointer, configures all peripheral hardware (ports,
;                    timers, display, sensors, sound, SPI), loads the high score
;                    from EEPROM, and runs a startup LED test pattern. Finally,
;                    it enables global interrupts and initializes game state variables
;                    before dropping into the main attract/game loop.
;
; Operation:         The Stack Pointer (SPL/SPH) is initialized to the end of SRAM to prepare for
;                    subroutine calls. Hardware initialization routines are then called to configure
;                    I/O ports, the display buffer, sensor variables, sound hardware, the SPI interface,
;                    and Timers 0 and 1. The system attempts to read the stored high score from the
;                    EEPROM; if this fails, execution continues non-blockingly. A startup pattern
;                    ("8888") is briefly displayed on both player screens to verify display functionality,
;                    followed by a quick priming loop for the multiplexer. Finally, global interrupts
;                    are enabled, and the core game state variables (players, scores, ball counts) are
;                    reset to their initial values before transitioning to the main game loop.
;
; Arguments:         None.
; Return Value:      Does not return (jumps to MainLoop).
;
; Local Variables:   r16, r17, r18, r20 (used for init values and loops).
; Shared Variables:  All system state variables are initialized here.
; Global Variables:  None.
;
; Input:             None.
; Output:            System hardware configured and ready.
;
; Error Handling:    None.
;
; Algorithms:        Linear initialization sequence.
; Data Structures:   None.
; Limitations:       None.
; Known Bugs:        None.
; Special Notes:     This is the reset vector handler.
; Registers Changed: All (System Init).
; ------------------------------------------------------------------------------
Reset:
    ; 1. Initialize Stack Pointer to the end of SRAM to enable subroutine calls and interrupts.
    ldi r16, low(RAMEND)
    out SPL, r16
    ldi r16, high(RAMEND)
    out SPH, r16

    ; 2. Initialize Hardware [cite: 24-29]
    call InitIOPort    ; Configure display ports (A, C, D) as outputs and clear them.
    call Init_IO_Port  ; Configure sensor ports (E as input, G as output).
    call InitDisplay   ; Clear the SRAM display buffer.
    call InitSensors   ; Initialize sensor matrix variables (debounce counters, flags).
    call Init_Sound     ; Configure the speaker pin (PB5) as output.
    call Init_SPI      ; Setup SPI hardware for EEPROM communication.
    call InitTimer0    ; Configure Timer0 for 1ms system tick interrupts.
    call InitTimer1    ; Configure Timer1 for sound generation (CTC mode).
    
    ; 3. Initialize High Score from EEROM (try to read, don't block if fails)
    ldi r16, HIGHSCORE_SIZE ; Prepare to read 2 bytes (High Score is 16-bit).
    ldi r17, HIGHSCORE_ADDR ; Set starting EEPROM address to 0.
    ldi YL, low(HighScore_L) ; Set Y-pointer to the SRAM address for the High Score variable.
    ldi YH, high(HighScore_L)
    call ReadEEROM          ; Execute the read operation.
    
    ; 4. Display startup pattern using DisplayHex ("8888" on both players)
    ldi r16, STARTUP_PATT_L ; Load 0x88 into arguments to display "88".
    ldi r17, STARTUP_PATT_H ; Load 0x88.
    ldi r18, PLAYER_1_ID    ; Select Player 1 display.
    rcall DisplayHex        ; Update Player 1 buffer.
    ldi r18, PLAYER_2_ID    ; Select Player 2 display.
    rcall DisplayHex        ; Update Player 2 buffer.
    
    ; Prime the display before interrupts start multiplexing
    ldi r20, MAX_LIGHT_INDEX             ; Initialize loop counter for a quick display test.
StartupMuxLoop:
    rcall LEDMux            ; Manually cycle the display multiplexer.
    dec r20                 ; Decrement counter.
    brne StartupMuxLoop     ; Loop until test is complete.
    
    ; 5. Enable Global Interrupts (timer will now update display continuously)
    sei                ; Enable Global Interrupts (I-bit in SREG).

    ; --- Initialize Game State (always running, no start button) ---
    ldi r16, DEFAULT_PLAYERS ; Set default number of players.
    sts NumPlayers, r16
    ldi r16, INITIAL_PLAYER_IDX ; Initialize CurrentPlayer to 0 (Player 1).
    sts CurrentPlayer, r16
    sts Score_P1_L, r16 ; Reset Player 1 Score Low Byte.
    sts Score_P1_H, r16 ; Reset Player 1 Score High Byte.
    sts Score_P2_L, r16 ; Reset Player 2 Score Low Byte.
    sts Score_P2_H, r16 ; Reset Player 2 Score High Byte.
    sts led_idx_curr, r16 ; Reset LED pattern index.
    sts led_idx_prev, r16
    sts sensor_available, r16 ; Clear sensor ready flag.
    sts debounced_sensor_code, r16 ; Clear last sensor reading.
    
    ; Show initial zero scores
    ldi r16, ZERO
    ldi r17, ZERO
    ldi r18, PLAYER_1_ID
    rcall DisplayHex        ; Display "0000" for Player 1.
    ldi r18, PLAYER_2_ID
    rcall DisplayHex        ; Display "0000" for Player 2.

; ------------------------------------------------------------------------------
; InPlayLoop
;
; Description:       The primary infinite loop for the pinball system. It manages
;                    the high-level game flow, specifically the "Attract Mode"
;                    or "In-Play" state (currently implemented as an always-on
;                    game loop). It continuously checks for sensor events, updates
;                    scores, controls LED patterns, and handles player switching
;                    logic.
;
; Operation:         The loop continuously refreshes the score display for both players by reading
;                    current score variables and updating the display buffer. It then polls the
;                    `sensor_available` flag; if no sensor event is pending, it repeats the display
;                    refresh. When a sensor event occurs, the `debounced_sensor_code` is read atomically
;                    (with interrupts briefly disabled) and the flag is cleared. The code is validated against
;                    range limits, and if valid, it is used to calculate an index into the `ScoreTable` to
;                    retrieve the corresponding point value. The `UpdateScore` routine is called to add these
;                    points to the current player's score, and `UpdateLEDPattern` is called to provide
;                    visual feedback. Finally, if the game is in 2-player mode, the current player is toggled
;                    before the loop repeats.
;
; Arguments:         None.
; Return Value:      None (Infinite Loop).
;
; Local Variables:   r16, r17, r18, r19, r30, r31.
; Shared Variables:  Score_Px_L/H, CurrentPlayer, NumPlayers, sensor_available.
; Global Variables:  None.
;
; Input:             User sensor inputs via ISR.
; Output:            Updates Display and Game State.
;
; Error Handling:    None.
;
; Algorithms:        Polling loop with event handling.
; Data Structures:   ScoreTable (Lookup).
; Limitations:       Currently bypasses "Start Button" logic for immediate play.
; Known Bugs:        None.
; Special Notes:     None.
; Registers Changed: r16-r19, Z (ZH:ZL).
; ------------------------------------------------------------------------------

InPlayLoop:
    ; Continuously refresh the score display buffer from current variables
    lds r16, Score_P1_L     ; Load Player 1 score low byte.
    lds r17, Score_P1_H     ; Load Player 1 score high byte.
    ldi r18, PLAYER_1_ID    ; Select Player 1.
    rcall DisplayHex        ; Update Player 1 display buffer.
    lds r16, Score_P2_L     ; Load Player 2 score low byte.
    lds r17, Score_P2_H     ; Load Player 2 score high byte.
    ldi r18, PLAYER_2_ID    ; Select Player 2.
    rcall DisplayHex        ; Update Player 2 display buffer.

    ; Check if a new sensor event has been flagged by the ISR
    lds r16, sensor_available
    tst r16
    breq InPlayLoop         ; If 0 (no sensor), loop back and wait.

    ; New sensor detected: Read the code safely
    cli                     ; Disable interrupts to ensure atomic access to shared variables.
    lds r16, debounced_sensor_code ; Read the validated sensor code.
    ldi r17, ZERO
    sts sensor_available, r17      ; Clear the flag to acknowledge the event.
    sei                     ; Re-enable interrupts.

    ; The tested sensor routine produces codes 0x09..0x30 (row*8 + col, with row/col starting at 1).
    ; Convert to a 0..39 index for ScoreTable: idx = code - 9.
    subi r16, SCORE_MAP_OFFSET
    brcs InPlayLoop            ; If code < 9 (carry set), ignore as invalid.
    cpi  r16, SCORE_MAP_LIMIT
    brsh InPlayLoop            ; If >= 40 (same or higher), ignore as invalid.

    ; Look up points (all sensors count) from ScoreTable in Program Memory
    mov r30, r16            ; Move index to Z-pointer low byte register.
    clr r31                 ; Clear Z-pointer high byte.
    lsl r30                 ; Multiply index by 4 (each entry is 4 bytes).
    rol r31                 ; Shift high bits into high byte.
    lsl r30
    rol r31                 
    ldi r18, low(2*ScoreTable) ; Load base address of ScoreTable (byte address).
    ldi r19, high(2*ScoreTable)
    add r30, r18            ; Add base address to offset.
    adc r31, r19
    lpm r16, Z+             ; Load Points Low Byte.
    lpm r17, Z+             ; Load Points High Byte.

    ; Update score for current player with the points retrieved
    rcall UpdateScore

    ; Update the LED pattern for visual feedback
    rcall UpdateLEDPattern

    ; Toggle player turn if in 2-player mode
    lds r18, NumPlayers     ; Load number of players.
    cpi r18, Max_players    ; Check if 2 players are active.
    brne InPlayLoop         ; If not, stay with current player.
    lds r16, CurrentPlayer  ; Load current player index (0 or 1).
    ldi r17, PLAYER_TOGGLE_MASK
    eor r16, r17            ; Toggle bit 0 (0->1, 1->0).
    sts CurrentPlayer, r16  ; Save new player index.

    rjmp InPlayLoop         ; Continue the main loop.

; ------------------------------------------------------------------------------
; HandleTilt
;
; Description:       Handles the "Tilt" condition when the tilt sensor is triggered.
;                    Plays a specific warning sound and then penalizes the player
;                    by treating it as a "Ball Out" event (ending the current ball).
;
; Operation:         The necessary frequency and duration parameters for the tilt sound are loaded
;                    into registers. The `PlayNote` function is then called to generate the auditory
;                    warning. Immediately after starting the sound, control is transferred to the
;                    `HandleBallOut` routine, effectively ending the current ball as a penalty.
;
; Arguments:         None.
; Return Value:      None (Jumps).
;
; Local Variables:   r16, r17.
; Shared Variables:  None direct.
; Global Variables:  None.
;
; Input:             None.
; Output:            Sound output.
;
; Error Handling:    None.
;
; Algorithms:        None.
; Data Structures:   None.
; Limitations:       None.
; Known Bugs:        None.
; Special Notes:     None.
; Registers Changed: r16, r17.
; ------------------------------------------------------------------------------
HandleTilt:
    ldi r16, TILT_FREQ             ; Load Tilt Sound Frequency (defined in constants).
    ldi r17, TILT_DUR              ; Load Tilt Sound Duration.
    call PlayNote                  ; Generate the sound.
    rjmp HandleBallOut             ; Tilt results in immediate loss of ball.

; ------------------------------------------------------------------------------
; HandleBallOut
;
; Description:       Processes the end of a ball (turn). Decrements the ball count
;                    for the current player and determines if the game should
;                    continue to the next player or end.
;
; Operation:         The routine first checks the `CurrentPlayer` variable to identify who is currently
;                    playing. Based on this index, it selects the appropriate ball count variable
;                    (`BallCount_P1` or `BallCount_P2`). The selected counter is decremented by one
;                    and updated in memory. Execution then flows directly into `CheckNextTurn` to
;                    determine the subsequent game state.
;
; Arguments:         None.
; Return Value:      None (Flow continues to CheckNextTurn).
;
; Local Variables:   r16, r17.
; Shared Variables:  BallCount_P1, BallCount_P2, CurrentPlayer.
; Global Variables:  None.
;
; Input:             None.
; Output:            Updates ball counts.
;
; Error Handling:    None.
;
; Algorithms:        None.
; Data Structures:   None.
; Limitations:       None.
; Known Bugs:        None.
; Special Notes:     None.
; Registers Changed: r16, r17.
; ------------------------------------------------------------------------------
HandleBallOut:
    ; --- End of Ball Logic ---
    ; Decrement ball count for current player
    lds r16, CurrentPlayer      ; Load current player index.
    cpi r16, INITIAL_PLAYER_IDX ; Check if Player 1.
    breq DecP1                  ; If so, branch to decrement P1's balls.
    
    ; Decrement Player 2's ball count
    lds r17, BallCount_P2
    dec r17
    sts BallCount_P2, r17
    rjmp CheckNextTurn          ; Done with decrement, check next state.

DecP1:
    ; Decrement Player 1's ball count
    lds r17, BallCount_P1
    dec r17
    sts BallCount_P1, r17

; ------------------------------------------------------------------------------
; CheckNextTurn
;
; Description:       Determines the next state after a ball is lost. Switches
;                    players if in 2-player mode, or checks if the game is over
;                    (both players out of balls).
;
; Operation:         The total number of players is loaded from `NumPlayers` and checked; if the game is
;                    in single-player mode, the logic branches directly to `LoopToStart` to check ball counts.
;                    If in two-player mode, the `CurrentPlayer` index is toggled (0 to 1 or 1 to 0) to pass
;                    the turn to the other player. Control then falls through to `LoopToStart`.
;
; Arguments:         None.
; Return Value:      None (Jumps).
;
; Local Variables:   r16, r17.
; Shared Variables:  NumPlayers, CurrentPlayer, BallCount_P1/P2.
; Global Variables:  None.
;
; Input:             None.
; Output:            Updates CurrentPlayer.
;
; Error Handling:    None.
;
; Algorithms:        None.
; Data Structures:   None.
; Limitations:       None.
; Known Bugs:        None.
; Special Notes:     None.
; Registers Changed: r16, r17.
; ------------------------------------------------------------------------------
CheckNextTurn:
    ; --- Player Switching Logic  ---
    lds r16, NumPlayers         ; Load total number of players.
    cpi r16, Max_players        ; Check if in 2-player mode.
    brne LoopToStart            ; If 1 player, skip toggle and check start conditions.
    
    ; Toggle Player (0 -> 1, 1 -> 0) to give the other player a turn
    lds r16, CurrentPlayer
    ldi r17, PLAYER_TOGGLE_MASK
    eor r16, r17                ; Exclusive OR with 1 flips the LSB.
    sts CurrentPlayer, r16      ; Update the current player variable.

; ------------------------------------------------------------------------------
; LoopToStart
;
; Description:       Checks whether the game should continue or end. It examines the
;                    ball counts for both players. If both players have exhausted their
;                    balls, it transitions to the `EndGame` state. Otherwise, it loops
;                    back to `StartPlaying` to begin the next ball/turn.
;
; Operation:         The ball counters for both Player 1 and Player 2 are loaded from memory. A bitwise OR
;                    operation is performed on these two values; if the result is zero, it indicates that
;                    both players have no balls remaining. In this case, the program branches to `EndGame`.
;                    Otherwise, if at least one player still has balls, the system jumps back to `StartPlaying`
;                    to begin the next turn.
;
; Arguments:         None.
; Return Value:      None (Jumps).
;
; Local Variables:   r16, r17.
; Shared Variables:  BallCount_P1, BallCount_P2.
; Global Variables:  None.
;
; Input:             None.
; Output:            None.
;
; Error Handling:    None.
;
; Algorithms:        None.
; Data Structures:   None.
; Limitations:       None.
; Known Bugs:        None.
; Special Notes:     None.
; Registers Changed: r16, r17.
; ------------------------------------------------------------------------------
LoopToStart:
    ; Check if BOTH players are out of balls
    lds r16, BallCount_P1       ; Load P1 ball count.
    lds r17, BallCount_P2       ; Load P2 ball count.
    or r16, r17                 ; OR them together. If both are 0, result is 0.
    breq EndGame                ; If result is 0, game is over.
    rjmp StartPlaying           ; Otherwise, continue to next ball/turn.

; ------------------------------------------------------------------------------
; EndGame
;
; Description:       Handles the end-of-game sequence. Checks for new high scores
;                    and returns the system to the main attract loop. This block
;                    is reached when both players have zero balls remaining.
;
; Operation:         The `CheckHighScore` subroutine is called to compare the current session's scores
;                    against the stored high score and update the EEPROM if necessary. After handling the
;                    high score logic, the program jumps back to `MainLoop` to reset the game state and
;                    return to attract mode.
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  None.
; Global Variables:  None.
;
; Input:             None.
; Output:            None.
;
; Error Handling:    None.
;
; Algorithms:        None.
; Data Structures:   None.
; Limitations:       None.
; Known Bugs:        None.
; Special Notes:     None.
; Registers Changed: None (via subroutines).
; ------------------------------------------------------------------------------
EndGame:
    ; --- C. End Game [cite: 1, 56] ---
    call CheckHighScore      ; Compare scores to EEROM
    rjmp MainLoop            ; Go back to attract mode





.dseg
; ==============================================================================
; GLOBAL VARIABLES
; Justification:
; These variables represent the core state of the system that must persist across
; the entire lifecycle of the game or be shared between the Main Loop and ISRs.
; - Game State: Scores, player turn, and ball counts must persist.
; - Shared I/O: ISRs update sensor/display state buffers that Main Loop reads/writes.
; ==============================================================================

; Game State Variables
CurrentPlayer:  .byte 1     ; 0 = Player 1, 1 = Player 2
NumPlayers:     .byte 1     ; 1 or 2
BallCount_P1:   .byte 1     ; Balls remaining for P1
BallCount_P2:   .byte 1     ; Balls remaining for P2
Score_P1_L:     .byte 1     ; Score Low Byte
Score_P1_H:     .byte 1     ; Score High Byte
Score_P2_L:     .byte 1     ; Score Low Byte
Score_P2_H:     .byte 1     ; Score High Byte
HighScore_L:    .byte 1
HighScore_H:    .byte 1
led_idx_curr:   .byte 1
led_idx_prev:   .byte 1

; Shared variables required by provided helpers 
disp_buffer:            .byte 16
curMuxSeg:              .byte 1
debounced_sensor_code:  .byte 1
sensor_available:       .byte 1


; since don't have a linker, include all the .asm files

.include "Init_Display.asm"
.include "InitTimer.asm"
.include "display_routine.asm"
.include "EEROM.asm"
.include "Helper.asm"
.include "sensor_routine(with full comment).asm"
.include "sound.asm"
.include "SPI.asm"
.include "util.asm"
.include "Init_Sensor.asm"
.include "SystemTables.asm"

