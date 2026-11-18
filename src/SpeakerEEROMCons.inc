;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                            ;
;                            SPEAKEREEROMCONS.INC                            ;
;                       EEPROM Command and Constant Definitions              ;
;             Microprocessor-Based Pin-Ball Machine (AVR version)            ;
;                                                                            ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file contains the constant definitions required for the EEPROM interface
; routines, including command opcodes and general-purpose values.

; Revision History:
;    06/04/25  Gabo Zhang               Initial revision and added read command
;										constants
;    06/17/25  Gabo Zhang               Added write command constants
;    09/19/25  Gabo Zhang               Revised comments
;    01/03/26  Gabo Zhang               Added HIGHSCORE_SIZE constant.




; EEPROM Command Opcodes
; ------------------------------------------------------------------------------
; These constants define the instruction bytes sent to the serial EEPROM to
; initiate read and write operations.
; --- Write Command ---
.equ    WriteCom1   = 0b00000001  ; First byte of the WRITE command sequence (Start Bit).
.equ    WriteCom2   = 0b01000000  ; Second byte of the WRITE command (Opcode), 
								  ; address is or'ed with this.

; --- Read Command ---
.equ    ReadCom1    = 0b00000011  ; First byte of the READ command sequence 
								  ; (Start Bit + Opcode).

; --- SPI Constants ---
.equ    EWcode 		= 0b10011000  ; The EWEN code for SPI transmission

; Game Constants
; ------------------------------------------------------------------------------
.equ    HIGHSCORE_ADDR = 0        ; EEPROM address for high score
.equ    HIGHSCORE_SIZE = 2        ; Size of high score in bytes
.equ    SOLENOID_BIT   = 7        ; Bit index for solenoid control on PORTA
.equ    TILT_FREQ      = 100      ; Frequency param for tilt sound
.equ    TILT_DUR       = 10       ; Duration param for tilt sound
.equ    SOUND_PWM_CONST = 500000     ; Constant for sound frequency calculation (F_CPU / 16)

; EEPROM / SPI Pin and Mask Constants
; ------------------------------------------------------------------------------
.equ    EEPROM_CS_BIT      = 0    ; Chip Select bit on PORTB for EEPROM
.equ    EEPROM_READY_BIT   = 3    ; Ready/Busy status bit on PINB
.equ    EEPROM_LSB_MASK    = 0x01 ; Mask to test odd/even address bit
.equ    EEPROM_ADDR_MASK   = 0x3F ; Mask for 6-bit EEPROM address field
.equ    SPI_MOSI_BIT       = 2    ; MOSI pin bit (PORTB)
.equ    SPI_SCK_BIT        = 1    ; SCK pin bit (PORTB)
.equ    SPI_CS_BIT         = EEPROM_CS_BIT ; SPI chip-select bit (shares EEPROM CS)
