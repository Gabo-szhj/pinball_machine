;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                            ;
;                               EEROM.ASM                                    ;
;                         Serial EEROM SPI Interface                         ;
;             Microprocessor-Based Pin-Ball Machine (AVR version)            ;
;                                                                            ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; This file contains the functions for interfacing with a serial EEROM
; using the SPI protocol. It provides routines for reading and writing data,
; as well as polling the EEROM's busy status.
;
; The public functions included are:
;    WriteEEROM         - Writes a buffer of one or more bytes to the EEPROM.
;    SPIWrite           - Low-level helper to send a write command and data.
;    ReadEEROM          - Reads a sequence of bytes from the EEROM into a buffer.
;    SPIRead            - Low-level helper to send a read command and get data.
;    WaitEEROMrdy       - Polls a hardware pin to wait for the EEROM to be ready.
;
; Revision History:
;    06/04/25  Gabo Zhang               Initial Revision, developed WaitEERomrdy. 
;    06/10/25  Gabo Zhang               Programmed initial structure for Read/WriteEEROM functions.
;    06/13/25  Gabo Zhang               Corrected to align byte order for Read and Write functions.
;    09/19/25  Gabo Zhang               Completed final documentation pass and revised comment.

.cseg

; --------------------------------------------------------------------------------
; WriteEEROM
;
; Description:       Writes a sequence of bytes from an SRAM buffer to the EEROM at a
;                    given starting address. Used by the main loop and `CheckHighScore`
;                    helper to persist new high scores when game records are broken.
;
; Operation:         This function manages writing multiple bytes. It checks if the
;                    start address is odd or even to determine the write strategy.
;                    If the start address is odd, it will read the address at EEROM
;                    then only modify one byte of data then writes back to EEROM.
;                    If the starting address is even and there is more than one byte
;                    left in the SRAM, then the function will write two bytes to EEROM.
;                    Finally, it uses recursive calls to process the entire buffer.
;
; Arguments:         r16 - Number of bytes to write.
;                    r17 - Starting EEPROM address.
;                    Y (YH:YL) - Pointer to source data buffer in SRAM.
;
; Return Values:     None.
;
; Local Variables:   r18 - start address odd/even check
;                    r19 - first data byte to be written through SPI 
;                    r20 - second data byte to be written through SPI
; Shared Variables:  None.
; Global Variables:  None.
;
; Input:             Data from the SRAM buffer pointed to by Y.
; Output:            Data is sent to the EEPROM via helper functions.
;
; Error Handling:    None. Relies on helper functions.
;
; Algorithms:        Uses recursion and address-parity checks to manage writes.
; Data Structures:   None.
;
; Known Bugs:        None.
;
; Limitations:       Recursion can lead to stack overflow on very large writes.
;
; Special Notes:     None.
;
; Registers Changed: Flags, r16, r17, r18, r19, r20, Y, and registers
;                    used by subroutines.
; --------------------------------------------------------------------------------
WriteEEROM:
    ; Exit if there are no bytes left to write.
    CPI     R16, CONST_ZERO
    BREQ    WriteDone           ; If count is 0, return.

    ; Check if the starting address in R17 is odd or even.
    MOV     R18, R17
    ANDI    R18, EEPROM_LSB_MASK ; Check LSB: 1 = odd, 0 = even.
    BREQ    EvenAddress         ; If even, jump to optimized even write.

; Path for an odd starting address.
OddAddressPath:
    ; EEROM writes are 16-bit word aligned. To write to an odd address,
    ; we must read the full word, modify the low byte (odd byte), and write back.
    RCALL   SPIRead             ; Read existing word at (Address - 1).
    LD      R20, Y+             ; Load new data byte from SRAM buffer.
    RCALL   SPIWrite            ; Write combined word (Existing High + New Low) back.
    INC     R17                 ; Increment address (next byte will be even).
    DEC     R16                 ; Decrement count.
    RJMP    WriteEEROM          ; Recurse/Loop to process remaining bytes.

EvenAddress:
    ; Path for an even starting address.
    CPI     R16, CONST_ONE
    BREQ    OneByteOnly         ; If only 1 byte left, use RMW cycle.
    LD      R19, Y+             ; Load High Byte from SRAM.
    LD      R20, Y+             ; Load Low Byte from SRAM.

TwoByteWrite:
    ; Perform a full 16-bit word write operation.
    RCALL   SPIWrite            ; Write R19:R20 to EEROM.
    INC     R17                 ; Increment Address by 2.
    INC     R17                 
    DEC     R16                 ; Decrement Count by 2.
    DEC     R16                 
    RJMP    WriteEEROM          ; Recurse/Loop.

OneByteOnly:
    ; Path to write a single remaining byte to an even address.
    ; We must read the word to preserve the odd byte (which we aren't changing).
    RCALL   SPIRead             ; Read existing word.
    LD      R19, Y+             ; Load new High Byte data from SRAM.
    RCALL   SPIWrite            ; Write combined word (New High + Existing Low) back.
    INC     R17                 ; Increment address.
    DEC     R16                 ; Decrement count.
    RJMP    WriteEEROM          ; Loop to exit.

WriteDone:
    RET                         ; Return.

; --------------------------------------------------------------------------------
; SPIWrite
;
; Description:       A low-level helper function that sends the WRITE command and
;                    16 bits of data to the EEROM via SPI. Invoked by `WriteEEROM`
;                    to handle the protocol-specific details of committing data
;                    to the persistent storage.
;
; Operation:         Asserts Chip Select (CS), sends the EEPROM WRITE command and
;                    address, transmits 16 bits of data, de-asserts CS, and waits
;                    for the EEPROM's internal write cycle to complete.
;
; Arguments:         r17 - The target EEPROM address.
;                    r19 - The first (high) data byte to write.
;                    r20 - The second (low) data byte to write.
;
; Return Values:     None.
;
; Local Variables:   r18, r21
; Shared Variables:  PORTB (for Chip Select), SPI hardware registers (via RxTxSPI).
; Global Variables:  None.
;
; Input:             Arguments passed in registers R19 and R20.
; Output:            Serial data sent on the SPI bus.
;
; Error Handling:    None.
;
; Algorithms:        Implements the specific command sequence for an EEROM write.
; Data Structures:   None.
;
; Known Bugs:        None known.
;
; Limitations:       Dependent on RxTxSPI and WaitEEROMrdy helper functions.
;
; Special Notes:     The exact command format is specific to the target EEROM.
;
; Registers Changed: Flags, r18, r19, r20, r21, and registers clobbered by subroutines.
; --------------------------------------------------------------------------------
SPIWrite:
    ; --- Start SPI Transaction ---
    SBI     PORTB, EEPROM_CS_BIT ; Set Chip Select (CS) high to select the EEROM.

    ; --- Send Write Command and Address ---
    LDI     R18, WriteCom1      ; Load command start bit.
    RCALL   RxTxSPI             ; Transmit.
    MOV     R21, R17            ; Copy Address.
    LSR     R21                 ; Convert Byte Address to Word Address (Div by 2).
    LDI     R18, WriteCom2      ; Load Write Opcode base.
    ANDI    R21, EEPROM_ADDR_MASK ; Mask address to 6 bits (size of EEROM).
    OR      R18, R21            ; Combine Opcode and Address.
    RCALL   RxTxSPI             ; Transmit Command/Address byte.

WordSPIWrite:
    ; --- Send 16-bit Data Word ---
    MOV     R18, R19            ; Load High Byte.
    RCALL   RxTxSPI             ; Transmit High Byte.
    MOV     R18, R20            ; Load Low Byte.
    RCALL   RxTxSPI             ; Transmit Low Byte.

    ; --- End SPI Transaction ---
    CBI     PORTB, EEPROM_CS_BIT ; Set CS low to initiate internal write cycle.
    RCALL   WaitEEROMrdy        ; Wait for EEPROM to finish writing.
    RET

; --------------------------------------------------------------------------------
; ReadEEROM
;
; Description:       Reads a sequence of bytes from the EEROM into an SRAM buffer.
;                    Called at startup by Mainloop and during gameplay by `CheckHighScore`
;                    to retrieve the stored high score for display or comparison.
;
; Operation:         This function reads data in 16-bit words using the SPIRead
;                    helper. It then stores these words as individual bytes into
;                    the destination buffer.
;
; Arguments:         r16 - Number of bytes to read.
;                    r17 - Starting EEPROM address.
;                    Y (YH:YL) - Pointer to destination data buffer in SRAM.
;
; Return Values:     None.
;
; Local Variables:   r19, r20, r21
; Shared Variables:  None.
; Global Variables:  None.
;
; Input:             Data from the EEROM.
; Output:            Data written to the SRAM buffer pointed to by Y.
;
; Error Handling:    None.
;
; Algorithms:        Loops through the read-and-store process until the byte
;                    count is exhausted.
; Data Structures:   None.
;
; Known Bugs:        None 
;
; Limitations:       No bounds checking on EEPROM address or SRAM buffer.
;
; Special Notes:     Uses recursive calls for cleaner code.
;
; Registers Changed: Flags, r16, r17, r19, r20, r21, Y, and registers
;                    clobbered by subroutines.
; --------------------------------------------------------------------------------
ReadEEROM:
    CPI     R16, CONST_ZERO
    BREQ    ReadDone            ; Exit if byte count is 0.

ReadLoop:
    ; Read a 16-bit word from the EEROM.
    RCALL   SPIRead             ; Returns R19 (High Byte), R20 (Low Byte).

    ; Check if the current target address is even or odd.
    MOV     R21, R17
    ANDI    R21, EEPROM_LSB_MASK
    BRNE    AddrOdd             ; If 1 (Odd), jump to store Low Byte.

AddrEven:
    ; For an even address, we want the High Byte of the word.
    ST      Y+, R19             ; Store High Byte to SRAM buffer.
    DEC     R16                 ; Decrement count.
    INC     R17                 ; Increment address (next is odd).
    CPI     R16, CONST_ZERO      ; Check if done.
    BREQ    ReadDone

AddrOdd:
    ; For an odd address, we want the Low Byte of the word.
    ST      Y+, R20             ; Store Low Byte to SRAM buffer.
    DEC     R16                 ; Decrement count.
    INC     R17                 ; Increment address (next is even).
    CPI     R16, CONST_ZERO      ; Check if done.
    BRNE    ReadLoop            ; If not, loop to read next word.

ReadDone:
    RET

; --------------------------------------------------------------------------------
; SPIRead
;
; Description:       A low-level helper function that reads a 16-bit word from the
;                    EEPROM at a specified address. Used exclusively by `ReadEEROM`
;                    to fetch data blocks.
;
; Operation:         Asserts CS, sends the READ command and address, performs two
;                    8-bit SPI transactions to receive a 16-bit word, then
;                    de-asserts CS.
;
; Arguments:         r17 - The EEPROM address to read from.
;
; Return Values:     r19 - High byte of the 16-bit word read.
;                    r20 - Low byte of the 16-bit word read.
;
; Local Variables:   r18
; Shared Variables:  PORTB (for Chip Select), SPI hardware registers (via RxTxSPI).
; Global Variables:  None.
;
; Input:             Serial data from the EEPROM.
; Output:            Returns read data in r19 and r20.
;
; Error Handling:    None.
;
; Algorithms:        Implements the specific command sequence for an EEROM read.
; Data Structures:   None.
;
; Known Bugs:        None known.
;
; Limitations:       Dependent on the RxTxSPI helper function.
;
; Special Notes:     The exact command format is specific to the target EEROM.
;
; Registers Changed: Flags, r18, r19, r20, and registers clobbered by subroutines.
; --------------------------------------------------------------------------------
SPIRead:
    ; --- Start SPI Transaction ---
    SBI     PORTB, EEPROM_CS_BIT ; Set CS high to enable EEROM.

    ; --- Send Read Command and Address ---
    LDI     R18, ReadCom1       ; Load Command Start Bit.
    RCALL   RxTxSPI             ; Transmit.
    MOV     R20, R17            ; Copy Address.
    LSR     R20                 ; Convert to Word Address (Div by 2).
    LSL     R20                 ; Shift left to position bits for Read Opcode.
    MOV     R18, R20            ; Load formatted address.
    RCALL   RxTxSPI             ; Transmit Command/Address.

    ; --- Receive 16-bit Data Word ---
    CLR     R18                 ; Send dummy byte (0x00) to clock out data.
    RCALL   RxTxSPI             
    MOV     R19, R18            ; Save received High Byte.
    CLR     R18                 ; Send dummy byte (0x00).
    RCALL   RxTxSPI             
    MOV     R20, R18            ; Save received Low Byte.

    ; --- End SPI Transaction ---
    CBI     PORTB, EEPROM_CS_BIT ; Set CS low to disable EEROM.
    RET

; --------------------------------------------------------------------------------
; WaitEEROMrdy
;
; Description:       Waits for the EEPROM to signal it is ready by polling a
;                    dedicated hardware ready/busy pin. Ensures that write operations
;                    have physically completed before the main loop attempts further
;                    access.
;
; Operation:         This blocking function asserts Chip Select (CS), then enters a 
;                    loop that continuously checks the status of PINB, bit 3. It
;                    waits for this pin to go high which means EEROM transmission
;                    is done, then de-asserts CS.
;
; Arguments:         None.
; Return Values:     None.
;
; Local Variables:   None.
; Shared Variables:  PORTB, PINB (for Chip Select and status polling).
; Global Variables:  None.
;
; Input:             The state of the hardware pin PINB, bit 3.
; Output:            None.
;
; Error Handling:    None.
;
; Algorithms:        Hardware status polling loop.
; Data Structures:   None.
;
; Known Bugs:        None known.
;
; Limitations:       This function relies on a direct hardware connection for the
;                    ready/busy signal. It will hang indefinitely if the pin
;                    never goes high (e.g., due to a hardware fault).
;
; Special Notes:     Blocking function.
;
; Registers Changed: Flags.
; --------------------------------------------------------------------------------
WaitEEROMrdy:
    ; Small delay before polling.
    NOP
    NOP

    ; Enable the EEPROM to check its status line.
    SBI     PORTB, EEPROM_CS_BIT ; Set CS high.

CheckDout:
    ; Wait in a tight loop until PINB, bit 3 goes high.
    NOP
    NOP
    SBIS    PINB, EEPROM_READY_BIT ; Skip next instruction if Bit in I/O SREG is set.
    RJMP    CheckDout           ; If pin is low, jump back and check again.

    ; Disable the EEPROM.
    CBI     PORTB, EEPROM_CS_BIT ; Set CS low.
    RET
