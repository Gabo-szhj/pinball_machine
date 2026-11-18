;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                            ;
;                             DISPLAYCONS.INC                                ;
;                         Display and I/O Constants                          ;
;             Microprocessor-Based Pin-Ball Machine (AVR version)            ;
;                                                                            ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; This file contains the global assembly language constants and definitions
; used across the pinball game project.

; Revision History:
;    05/26/25  Gabo Zhang               Initial revision.
;    05/30/25  Gabo Zhang               Added LED and display constants.
;    06/17/25  Gabo Zhang               Added comments and False constant.
;    01/03/26  Gabo Zhang               Added game logic and startup constants.



; Base Numeric Constants (used to avoid repeated literals)
; ------------------------------------------------------------------------------
.equ    CONST_ZERO      = 0
.equ    CONST_ONE       = 1
.equ    CONST_TWO       = 2
.equ    CONST_BYTE_MAX  = 0xFF

; Display and LED Constants
; ------------------------------------------------------------------------------
.equ    MAX_LIGHT_INDEX = 64                ; Total number of individually addressable LEDs.
.equ    NUM_DIG         = 16                ; Total number of multiplexed display_buffer bytes.
.equ    HEX_DIG         = 4                 ; Number of digits in the hexadecimal score display.
.equ    Player1_Index   = 8                 ; Disp_buffer offset for Player 1's score.
.equ    Player2_Index   = 12                ; Disp_buffer offset for Player 2's score.
.equ    Max_players     = CONST_TWO         ; Maximum number of players supported.
.equ    INIT_SEG_PATT   = CONST_ONE
.equ    STARTUP_PATT_BYTE = 0x88            ; Common startup pattern byte ("8" segments on)
.equ    STARTUP_PATT_L  = STARTUP_PATT_BYTE ; Low byte for "8888"
.equ    STARTUP_PATT_H  = STARTUP_PATT_BYTE ; High byte for "8888"


; General Purpose and Masking Constants
; ------------------------------------------------------------------------------
.equ    FALSE     = CONST_ZERO     ; General purpose boolean false value.
.equ    ZERO      = CONST_ZERO     ; General purpose zero value.
.equ    HexMask   = 0x0F           ; Mask to isolate a 4-bit nybble.
.equ    ModMask   = 0x07           ; Mask for modulo-8 operations.
.equ    TRUE      = CONST_ONE      ; General purpose boolean true value.
.equ    BYTE_MAX  = CONST_BYTE_MAX ; Max 8-bit value, useful for delay loops.


; Game Logic Constants
; ------------------------------------------------------------------------------
.equ    PLAYER_1_ID         = CONST_ONE ; ID for Player 1
.equ    PLAYER_2_ID         = CONST_TWO ; ID for Player 2
.equ    SINGLE_PLAYER_COUNT = CONST_ONE ; Single-player selection return value
.equ    DEFAULT_PLAYERS     = CONST_TWO ; Default number of players
.equ    PLAYER_TOGGLE_MASK  = CONST_ONE ; Mask to toggle player ID (0->1, 1->0)
.equ    INITIAL_PLAYER_IDX  = CONST_ZERO ; Initial player index (0 for Player 1)

; Math/Utility Constants
; ------------------------------------------------------------------------------
.equ    DIV24_BITCOUNT      = 24  ; Bit iterations for 24-bit dividend division.


; Timer0 Configuration Constants
; ------------------------------------------------------------------------------
; Value for 1ms tick @ 8MHz w/ prescaler 64 -> (8M / 64 / 1k) - 1 = 124
.EQU    OCR0_MATCH_VALUE      = 124                ; Calculated match value for Timer0.
.EQU TCCR0_CTC_PRESC64      = (1<<WGM01)|(1<<CS02) ; CTC mode + prescaler 64
.EQU TIMSK_OCIE0_ENABLE     = (1<<OCIE0)            ; Enable Timer0 Compare Match interrupt
