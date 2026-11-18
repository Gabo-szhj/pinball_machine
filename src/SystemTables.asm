;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                            ;
;                               SYSTEMTABLES.ASM                             ;
;                      Lookup Tables for Display and Logic                   ;
;             Microprocessor-Based Pin-Ball Machine (AVR version)            ;
;                                                                            ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; This file contains all the lookup tables used by the system for data conversion,
; hardware control, and game logic mapping.
;
; The public tables included are:
;    HexTable           - Maps 4-bit values to 7-segment display patterns.
;    MaskTable          - Maps indices 0-7 to single-bit masks.
;    DigitTable         - Maps digit indices to port enables.
;    ScoreTable         - Maps sensor indices to score/sound data.
;
; Revision History:
;    12/26/25  Gabo Zhang               Initial creation, moved tables from
;                                       display_routine.asm and sensor_routine.asm.
;    01/03/26  Gabo Zhang               Added standardized file header.

.cseg

; ------------------------------------------------------------------------------
; HexTable
;
; Description:      This table maps a 4-bit hexadecimal value (0-15) to its
;                   corresponding 8-bit, active-high 7-segment display pattern.
;                   It defines patterns for the characters 0-9, A, b, C, d, E, and F.
;                   The decimal point segment is not used in any pattern.
;
; Notes:            Read-only tables should always be in the code segment so
;                   that in a standalone system they will be located in ROM.
; ------------------------------------------------------------------------------
HexTable:
    ;        DB       gfeedcba    gfeedcba   ; Hex Digit
    .DB     0b01111111, 0b00000110   ; 0, 1
    .DB     0b10111011, 0b10001111   ; 2, 3
    .DB     0b11000110, 0b11001101   ; 4, 5
    .DB     0b11111101, 0b00000111   ; 6, 7
    .DB     0b11111111, 0b11000111   ; 8, 9
    .DB     0b11110111, 0b11111100   ; A, b
    .DB     0b01111001, 0b10111110   ; C, d
    .DB     0b11111001, 0b11110001   ; E, F


; ------------------------------------------------------------------------------
; MaskTable
;
; Description:      This table provides 8-bit masks, each with a single bit set.
;                   It is used to isolate or test a specific bit within a byte.
;                   The table maps an index (0-7) to a unique bit position, useful
;                   for controlling individual LEDs in a matrix column or for
;                   other bitwise operations.
; ------------------------------------------------------------------------------
MaskTable:
    ;        DB     Binary mask  		     ; LED mask number
    .DB     0b10000000, 0b01000000   ; 0, 1
    .DB     0b00100000, 0b00010000   ; 2, 3
    .DB     0b00001000, 0b00000100   ; 4, 5
    .DB     0b00000010, 0b00000001   ; 6, 7


; ------------------------------------------------------------------------------
; DigitTable
;
; Description:      This table contains the 16-bit digit-enable patterns required
;                   for display multiplexing. Each entry in the table corresponds to
;                   a single display digit (or LED row). The pattern has only one
;                   bit set across the two output ports (PORTA and PORTD), which
;                   ensures only one digit driver is active at any given time.
;
; Notes:            Each entry is functionally 16 bits wide, composed of a byte
;                   for PORTA and a byte for PORTD.
; ------------------------------------------------------------------------------
DigitTable:
    ;        DB     PORTA  		PORTD		 ; Buffer Index to Output
    .DB     0b00000001, 0b00000000   ; 0
    .DB     0b00000010, 0b00000000   ; 1
    .DB     0b00000100, 0b00000000   ; 2
    .DB     0b00001000, 0b00000000   ; 3
    .DB		0b00010000, 0b00000000   ; 4
    .DB     0b00100000, 0b00000000   ; 5
    .DB     0b01000000, 0b00000000   ; 6
    .DB     0b10000000, 0b00000000 	 ; 7
    .DB     0b00000000, 0b00001000   ; 8
    .DB     0b00000000, 0b00000100   ; 9
    .DB     0b00000000, 0b00000010   ; A
    .DB     0b00000000, 0b00000001   ; B
    .DB     0b00000000, 0b10000000   ; C
    .DB     0b00000000, 0b01000000   ; D
    .DB     0b00000000, 0b00100000   ; E
    .DB     0b00000000, 0b00010000   ; F


; ------------------------------------------------------------------------------
; ScoreTable
;
; Description:      This table defines the points awarded and sound frequency
;                   played for each sensor index.
;                   Format per entry: .dw POINTS, FREQUENCY
;                   Each entry is 4 bytes. 40 entries total.
; ------------------------------------------------------------------------------
ScoreTable:
    ; --- Column 0 (Sensors 0-7) ---
    .dw 10, 261     ; Sens 0:  10 pts, Middle C
    .dw 10, 293     ; Sens 1:  10 pts, D
    .dw 10, 329     ; Sens 2:  10 pts, E
    .dw 10, 349     ; Sens 3:  10 pts, F
    .dw 10, 392     ; Sens 4:  10 pts, G
    .dw 10, 440     ; Sens 5:  10 pts, A
    .dw 10, 493     ; Sens 6:  10 pts, B
    .dw 10, 523     ; Sens 7:  10 pts, High C

    ; --- Column 1 (Sensors 8-15) - Bumpers (Higher Score/Pitch) ---
    .dw 100, 880    ; Sens 8:  100 pts, High A
    .dw 100, 987    ; Sens 9:  100 pts, High B
    .dw 100, 1046   ; Sens 10: 100 pts, C6
    .dw 100, 1174   ; Sens 11: 100 pts, D6
    .dw 100, 1318   ; Sens 12: 100 pts, E6
    .dw 100, 1396   ; Sens 13: 100 pts, F6
    .dw 100, 1567   ; Sens 14: 100 pts, G6
    .dw 100, 1760   ; Sens 15: 100 pts, A6

    ; --- Column 2 (Sensors 16-23) - Targets (Medium Score) ---
    .dw 50, 523     ; Sens 16: 50 pts, C5
    .dw 50, 587     ; Sens 17: 50 pts, D5
    .dw 50, 659     ; Sens 18: 50 pts, E5
    .dw 50, 698     ; Sens 19: 50 pts, F5
    .dw 50, 783     ; Sens 20: 50 pts, G5
    .dw 50, 880     ; Sens 21: 50 pts, A5
    .dw 50, 987     ; Sens 22: 50 pts, B5
    .dw 50, 1046    ; Sens 23: 50 pts, C6

    ; --- Column 3 (Sensors 24-31) - Ramps (High Score) ---
    .dw 500, 1000   ; Sens 24: 500 pts, 1kHz
    .dw 500, 1200   ; Sens 25: 500 pts, 1.2kHz
    .dw 500, 1400   ; Sens 26: 500 pts, 1.4kHz
    .dw 500, 1600   ; Sens 27: 500 pts, 1.6kHz
    .dw 500, 1800   ; Sens 28: 500 pts, 1.8kHz
    .dw 500, 2000   ; Sens 29: 500 pts, 2kHz
    .dw 500, 2200   ; Sens 30: 500 pts, 2.2kHz
    .dw 500, 2400   ; Sens 31: 500 pts, 2.4kHz

    ; --- Column 4 (Sensors 32-39) - Special/Drain ---
    .dw 1000, 200   ; Sens 32: 1000 pts, Low Buzz (Bonus)
    .dw 1000, 250   ; Sens 33: 1000 pts
    .dw 0, 100      ; Sens 34: 0 pts (Out lane?)
    .dw 0, 100      ; Sens 35: 0 pts
    .dw 0, 100      ; Sens 36: 0 pts
    .dw 0, 100      ; Sens 37: 0 pts
    .dw 0, 100      ; Sens 38: 0 pts
    .dw 0, 100      ; Sens 39: 0 pts

