; ATmega64 register subset used by this controller (I/O offsets unless noted).
; AVRA 1.3 has no ATmega64 entry; ATmega128 provides the same instruction core,
; SRAM origin/size and vector layout. Flash bounds are checked in Mainloop.asm.
.device ATmega128

.equ RAMEND = 0x10ff
.equ FLASHEND = 0x7fff
.equ PORTG = 0x65               ; Data-space address (extended I/O).
.equ DDRG = 0x64                ; Data-space address (extended I/O).
.equ SREG = 0x3f
.equ SPH = 0x3e
.equ SPL = 0x3d
.equ TIMSK = 0x37
.equ TCCR0 = 0x33
.equ OCR0 = 0x31
.equ TCCR1A = 0x2f
.equ TCCR1B = 0x2e
.equ OCR1AH = 0x2b
.equ OCR1AL = 0x2a
.equ PORTA = 0x1b
.equ DDRA = 0x1a
.equ PORTB = 0x18
.equ DDRB = 0x17
.equ PINB = 0x16
.equ PORTC = 0x15
.equ DDRC = 0x14
.equ PORTD = 0x12
.equ DDRD = 0x11
.equ SPDR = 0x0f
.equ SPSR = 0x0e
.equ SPCR = 0x0d
.equ DDRE = 0x02
.equ PINE = 0x01

.equ SPIF = 7
.equ SPR0 = 0
.equ SPR1 = 1
.equ MSTR = 4
.equ SPE = 6
.equ CS02 = 2
.equ WGM01 = 3
.equ OCIE0 = 1
.equ COM1A0 = 6
.equ CS11 = 1
.equ WGM12 = 3

.def XL = r26
.def XH = r27
.def YL = r28
.def YH = r29
.def ZL = r30
.def ZH = r31
