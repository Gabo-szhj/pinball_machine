;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                            ;
;                                SPI.ASM                                     ;
;                             SPI Hardware Interface                         ;
;             Microprocessor-Based Pin-Ball Machine (AVR version)            ;
;                                                                            ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; This file contains the low-level functions for initializing and operating
; the SPI hardware interface. These routines are primarily used for communicating
; with a serial EEPROM.
;
; The public functions included are:
;    RxTxSPI            - Transmits and receives a single byte via SPI.
;    Init_SPI           - Initializes the SPI hardware for master mode.
;
; Revision History:
;    06/06/25  Gabo Zhang               Initial project revision. Set up file structure,
;                                          defined constants, and implemented core sensor
;                                          and timer initialization routines.
;    06/17/25  Gabo Zhang               Completed core feature development and initial
;                                          documentation pass.
;    09/19/25  Gabo Zhang               Created and documented the low-level SPI
;                                          driver for EEPROM communication.

.cseg

; --------------------------------------------------------------------------------
; Function:          RxTxSPI
;
; Description:       Performs a single, blocking, full-duplex SPI byte transaction.
;                    A low-level primitive used by `ReadEEROM` and `WriteEEROM` to
;                    exchange data with the EEPROM, enabling high-score persistence
;                    for the main loop.
;
; Operation:         The function writes the byte from the argument register (R18)
;                    to the SPI Data Register (SPDR), which initiates the transfer.
;                    It then polls the SPI Transfer Complete flag (SPIF) until the
;                    8-bit transfer is finished. Finally, it reads the byte that was
;                    simultaneously received from the slave device out of SPDR and
;                    returns it in the same register.
;
; Arguments:         R18 - The byte to be transmitted over the SPI bus.
;
; Return Values:     R18 - The byte received from the SPI slave during the transaction.
;
; Local Variables:   None.
; Shared Variables:  SPDR - SPI Data Register (read and written).
;                    SPSR - SPI Status Register (read).
; Global Variables:  None.
;
; Input:             Byte to transmit in R18.
; Output:            Received byte returned in R18.
;
; Error Handling:    None.
;
; Algorithms:        Uses a hardware polling loop to wait for the transaction to complete.
; Data Structures:   None.
;
; Known Bugs:        None.
;
; Limitations:       This function is blocking and will hang if the SPI clock is not
;                    running or if the SPIF flag never gets set for any reason.
;
; Special Notes:     Reading from SPDR after a transfer is a required step to clear
;                    the SPIF flag, allowing future transactions.
;
; Registers Changed: Flags, R18.
; --------------------------------------------------------------------------------
RxTxSPI:
    ; Write the byte in R18 to the SPI Data Register (SPDR).
    ; This action automatically starts the clock generator and shifts the data out.
    OUT     SPDR, R18

; Loop to wait for the transmission to complete.
Wait_SPIF:
    ; Poll the SPI Status Register (SPSR).
    ; SBIS checks the SPI Interrupt Flag (SPIF) and skips the next instruction if set.
    SBIS    SPSR, SPIF
    ; If flag is 0 (not done), jump back to poll again.
    RJMP    Wait_SPIF

    ; The transfer is complete. The received byte is now in SPDR.
    ; Read SPDR to get the data and to clear the SPIF flag (required step).
    IN      R18, SPDR
    RET

; --------------------------------------------------------------------------------
; Function:          Init_SPI
;
; Description:       Initializes the AVR's SPI hardware for master mode and enables
;                    writes on an attached serial EEPROM. Called by Mainloop initialization
;                    to configure the SPI master interface, allowing subsequent high-score
;                    retrieval and storage.
;
; Operation:         First, it configures the necessary Port B pins (MOSI, SCK, CS) as
;                    outputs. It then writes to the SPI Control Register (SPCR) to
;                    enable the SPI peripheral as a master device and sets the clock
;                    rate. Finally, it sends the EWEN (Enable Write) command sequence
;                    to the attached EEPROM to allow subsequent write operations.
;
; Arguments:         None.
;
; Return Values:     None.
;
; Local Variables:   R16, R18.
; Shared Variables:  DDRB, PORTB, SPCR - I/O registers for hardware configuration.
; Global Variables:  None.
;
; Input:             None.
; Output:            The SPI hardware is configured and the EEPROM is write-enabled.
;
; Error Handling:    None.
;
; Algorithms:        None.
; Data Structures:   None.
;
; Known Bugs:        None.
;
; Limitations:       The SPI clock rate and mode are hardcoded. The EWEN command is
;                    specific to certain models of serial EEPROMs.
;
; Special Notes:     This function must be called once during system initialization
;                    before any SPI communication with the EEPROM can occur.
;
; Registers Changed: Flags, R16, R18, and registers used by the RxTxSPI subroutine.
; --------------------------------------------------------------------------------
Init_SPI:
    ; --- Configure SPI Pin Directions ---
    ; Set MOSI (Master Out Slave In) and SCK (Serial Clock) as outputs.
    ; Set SS/CS (Slave Select/Chip Select) as output.
    ; MISO (Master In Slave Out) is automatically configured as input by enabling SPI.
    SBI     DDRB, SPI_MOSI_BIT  ; Set MOSI as output.
    SBI     DDRB, SPI_SCK_BIT   ; Set SCK as output.
    SBI     DDRB, SPI_CS_BIT    ; Set CS as output.

    ; --- Set Initial Pin States ---
    ; De-select the slave device by setting Chip Select high (inactive state).
    SBI     PORTB, SPI_CS_BIT

    ; --- Configure SPI Control Register (SPCR) ---
    ; Enable SPI (SPE=1), set as Master (MSTR=1).
    ; Set Clock Rate to Fosc/128 (SPR1=1, SPR0=1) for conservative timing.
    LDI     R16, (1<<SPE)|(1<<MSTR)|(1<<SPR1)|(1<<SPR0)
    OUT     SPCR, R16

    ; --- Enable Writes on the EEPROM ---
    ; The specific EEPROM requires a WREN (Write Enable) command before any writes.
    SBI     PORTB, SPI_CS_BIT   ; Assert Chip Select (CS high for this device).
    
    ; Send the EWEN command opcode (defined in constants).
    LDI     R18, EWcode
    RCALL   RxTxSPI             ; Transmit first part.
    
    ; Send dummy bits/address if required by the protocol.
    CLR     R18                 
    RCALL   RxTxSPI             ; Transmit second part.
    
    CBI     PORTB, SPI_CS_BIT   ; De-assert Chip Select (CS low) to execute command.

    RET
