;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                            ;
;                          SENSOR INITIALIZATION                             ;
;                      Sensor Initialization Functions                       ;
;             Microprocessor-Based Pin-Ball Machine (AVR version)            ;
;                                                                            ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; This file contains the functions for initializing the sensor routine variable
; and I/O ports. The public functions included are:
;    InitSensors  - initialize the sensor routine variables
;    Init_IO_Port - initialize  the I/O ports  
;
; Revision History:
;    5/14/25    Gabo Zhang           Initial Revision
;    5/15/25    Gabo Zhang           Corrected port initialization
;    5/16/25    Gabo Zhang           Added InitSensors
;    6/14/25    Gabo Zhang           Added comments


;get the definitions for the device
;.include  "m64def.inc"

; local include files
;.include  "SensorCons.inc"


.cseg

; ------------------------------------------------------------------------------
; InitSensors
;
; Description:       This function initializes the sensor input system. In the main
;                    loop system, this ensures the sensor matrix variables are ready
;                    before the Timer0 ISR begins debouncing switches.
;
; Operation:         This function initializes variables used for sensor 
;					 debouncing and state tracking. It clears flags,
;                    resets counters, and sets the initial state for sensor 
;					 input handling.
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  debounced_sensor_code - written, 8 bit
;                    sensor_available - written, 1 if sensor is debounced and ready, 0 otherwise
;                    rowcount - written, maximum 5 rows
;                    debouncing - written, 1 if debouncing is in progress, 0 otherwise
;                    debounce_counter - written,  maximum 10, for debouncing logic
;                    prev_input - written, 8 bit
; Global Variables:  None.
;
; Input:             None.
; Output:            None.
;
; Error Handling:    None.
;
; Algorithms:        None.
; Data Structures:   None.
; Limitations:  None
; Known Bugs:   None
; Special Notes:    None
; Registers Changed: flags, R16
; ------------------------------------------------------------------------------


InitSensors:

    ldi     r16, SENSOR_ZERO         ; Load r16 with 0 to initialize variables.

    ; --- Initialize all variables to a 0/FALSE ---
    sts     debounced_sensor_code, r16 ; Reset the last valid key code to 0.
    sts     sensor_available, r16       ; Clear the flag that signals a new key is ready.
    ldi     r16, ROW_START_INDEX        ; Row counter starts at 1 (rows are 1-5).
    sts     rowcount, r16               ; Initialize row scan counter to 1.
    ldi     r16, SENSOR_ZERO           
    sts     debouncing, r16         ; Clear the 'debouncing' state flag (0 = idle).

    ; --- Set up the debounce counter ---
    ldi     r16, DEBOUNCE_TIME      ; Load the debounce duration (e.g., 10ms) constant.
    sts     debounce_counter, r16   ; Store it as the initial countdown value.

    ; Initialize the previous input state to 'ALL_ROWS_HIGH' (typically 0xFF).
    ; This represents the state where all column inputs are high (pull-ups active, no key pressed).
    ldi     r16, ALL_ROWS_HIGH      
    sts     prev_input, r16         ; Set previous input to "no keys pressed" for comparison.
    
    clr     r16                     ; Clear r16 (redundant safety clear).
    ret                             ; Return from the initialization subroutine.




; ------------------------------------------------------------------------------
; Init_IO_Port()
; Description:  This procedure initializes the I/O ports for the system. Called by
;               Reset in Mainloop, it configures Port E for input (rows/cols) and
;               other ports to drive the matrix, ensuring hardware is ready for scanning.
; Operational Description:
;       The direction bits are set appropriately for the ports and first row
;       switches are turned on.
; Arguments:    None
; Return Value: None
; Local Variables:  None
; Shared Variables: None
; Input:    None 
; Output:   The I/O ports are initialized and first row switches are turned on.
; Error Handling:   None
; Algorithms:   None
; Data Structures:  None
; Limitations:  None
; Known Bugs:   None
; Special Notes:    None
; Registers Changed: R16
; ------------------------------------------------------------------------------

Init_IO_Port:

    ; Configure Port E as Input for reading sensor columns.
    ldi     r16,  PORT_INPUT           ; Load input configuration (0x00).
    out     DDRE, r16                  ; Write to Data Direction Register E.

    ; Configure Port G as Output for driving sensor rows.
    ldi     r16, PORT_OUTPUT            ; Load output configuration (0xFF).
    sts     DDRG, r16                   ; Write to DDRG (Extended I/O space requires STS).
    
    ; Initialize Port G to activate the first row.
    ; Rows are active low, so we write a 0 to the bit corresponding to row 1.
    ldi     r16 , FIRST_ROW_MASK        ; Load mask (e.g., 0b11111110).
    sts     PORTG, r16                  ; Write to PORTG to drive Row 1 low.
    
    clr     r16                         ; Clear register for return.
    ret                                 ; Return from the initialization subroutine.
