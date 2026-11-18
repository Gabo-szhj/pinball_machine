;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                            ;
;                             SENSORCONS.INC                                 ;
;                          Sensor and I/O Constants                          ;
;             Microprocessor-Based Pin-Ball Machine (AVR version)            ;
;                                                                            ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; This file contains the global assembly language constants and definitions
; used for sensor matrix scanning and debouncing.
;
; Revision History:
;    5/14/24   Gabo Zhang              Initial revision with all required constants
;    12/19/24  Gabo Zhang              Revised the comments and formatting

; Base Numeric Constants (sensor scope)
; ------------------------------------------------------------------------------
.equ    SENSOR_ZERO       = 0x00    ; Local zero to avoid repeated literals.
.equ    SENSOR_ONE        = 0x01    ; Local one used across sensor settings.
.equ    SENSOR_FF         = 0xFF    ; Local 0xFF value for masks and outputs.
.equ    SENSOR_FALSE      = SENSOR_ZERO
.equ    SENSOR_TRUE       = SENSOR_ONE

; Sensor Matrix Constants
; ------------------------------------------------------------------------------
.equ    N_COLUMNS         = 8       ; Number of columns in the sensor matrix
.equ    N_ROWS            = 5       ; Number of rows in the sensor matrix
.equ    DEBOUNCE_TIME     = 10      ; Number of ms to wait for debouncing
.equ    ROW_START_INDEX   = SENSOR_ONE ; Initial row index when scanning (1-based).
.equ    COL_START_INDEX   = SENSOR_ONE ; Initial column index when scanning (1-based).
.equ    DEBOUNCE_ACTIVE   = SENSOR_ONE ; Flag value indicating debounce is in progress.

; Port Definitions
; ------------------------------------------------------------------------------
.equ    INPUT_PORT        = PINE    ; Port E - Input for reading sensor columns
.equ    OUTPUT_PORT       = PORTG   ; Port G - Output for driving sensor rows
.equ    PORT_INPUT        = SENSOR_ZERO ; All bits as input (0)
.equ    PORT_OUTPUT       = SENSOR_FF   ; All bits as output (1)

; Row Mask Constants
; ------------------------------------------------------------------------------
.equ    FIRST_ROW_MASK    = 0b11111110  ; First row active (bit 0 low)
.equ    LAST_ROW_MASK     = 0b11101111  ; Last row active (bit 4 low, for 5 rows: 0b11101111)
.equ    NEXT_ROW_MASK     = 0b11111110  ; Next row mask (wraps to first)
.equ    ALL_ROWS_HIGH     = SENSOR_FF   ; All rows inactive (no key pressed)

; Special Sensor Codes
; ------------------------------------------------------------------------------
; NOTE: These codes map to actual physical buttons on the 5x8 matrix (0-39)
; Choose which physical sensor you want to use for each function
; Example mappings (adjust based on your hardware):
.equ    START_BTN_CODE    = 0       ; Normalized index: row 1, column 1
.equ    TILT_CODE         = 38      ; Normalized index: row 5, column 7
.equ    BALL_OUT_CODE     = 39      ; Normalized index: row 5, column 8

; Timing and Limits
; ------------------------------------------------------------------------------
.equ    START_DELAY_OUTER = 250   ; Outer loop for start button window
.equ    START_DELAY_INNER = 255   ; Inner loop for delays
.equ    NO_SENSOR_DELAY   = 10    ; Short delay when no sensor found
.equ    SOLENOID_DELAY    = 100   ; Delay loop for solenoid activation
.equ    SCORE_MAP_OFFSET  = 9     ; Offset to map sensor code to score index
.equ    SCORE_MAP_LIMIT   = 40    ; Upper bound for valid score sensor codes
.equ    BALLS_PER_GAME    = 3
