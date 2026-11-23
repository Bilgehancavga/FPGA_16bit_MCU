# Instruction Set Reference

Reference for the 16-bit FPGA microcontroller: registers, instruction format,
every instruction with its opcode and effect, and how assembly maps to machine code.

## Registers

| Register | Width | Reset value | Notes |
|---|---|---|---|
| R0 – R31 | 16 bit | undefined | General purpose; write before reading |
| PC | 11 bit | 11 | Program counter (flash address) |
| SP | 8 bit | 0xFF | Stack pointer (RAM address), grows down, stops at 0xBF |
| Status | 4 bit | 0 | Flags **Z** (zero), **N** (negative), **C** (carry), **V** (overflow) |

## Instruction format

Every instruction is 48 bits. Fields that an instruction does not use are 0.

```
 47     42 41   37 36   32 31   27 26             11 10          0
+---------+-------+-------+-------+-----------------+-------------+
| opcode  |  Rd   |  Rs1  |  Rs2  |  immediate (16) | address (11)|
+---------+-------+-------+-------+-----------------+-------------+
```

- **Rd:** destination register
- **Rs1, Rs2:** source registers
- **immediate:** 16-bit constant
- **address:** flash address (jumps, `CALL`), RAM address (`LOAD`, `STORE`, 8 bits used) or port number (`IN`, `OUT`)

## Instructions

Flags column: a letter means the flag is updated; `0` means it is cleared; `–` means flags are not changed.

### Arithmetic and logic

| Instruction | Opcode | Operation | Flags |
|---|---|---|---|
| `ADD Rd, Rs1, Rs2` | 000111 | Rd ← Rs1 + Rs2 | Z N C V |
| `SUB Rd, Rs1, Rs2` | 001000 | Rd ← Rs1 − Rs2 | Z N C V |
| `ADDI Rd, Rs1, imm` | 001101 | Rd ← Rs1 + imm | Z N C V |
| `SUBI Rd, Rs1, imm` | 001110 | Rd ← Rs1 − imm | Z N C V |
| `INC Rd, Rs1` | 001001 | Rd ← Rs1 + 1 | Z N C V |
| `DEC Rd, Rs1` | 001010 | Rd ← Rs1 − 1 | Z N C V |
| `NEG Rd, Rs1` | 001011 | Rd ← −Rs1 (two's complement) | Z N, C=0, V |
| `CMP Rs1, Rs2` | 001100 | Rs1 − Rs2, result discarded | Z N C V |
| `AND Rd, Rs1, Rs2` | 000010 | Rd ← Rs1 & Rs2 | Z N, C=0, V=0 |
| `OR Rd, Rs1, Rs2` | 000011 | Rd ← Rs1 \| Rs2 | Z N, C=0, V=0 |
| `XOR Rd, Rs1, Rs2` | 000100 | Rd ← Rs1 ^ Rs2 | Z N, C=0, V=0 |
| `NOT Rd, Rs1` | 000001 | Rd ← ~Rs1 | Z N, C=0, V=0 |
| `SHL Rd, Rs1, Rs2` | 000101 | Rd ← Rs1 << Rs2[3:0] | Z N C, V=0 |
| `SHR Rd, Rs1, Rs2` | 000110 | Rd ← Rs1 >> Rs2[3:0] (logical) | Z N C, V=0 |

Flag details:

- **Subtraction** (`SUB`, `SUBI`, `DEC`, `CMP`): **C = 1 means no borrow** (Rs1 ≥ Rs2, unsigned).
- **V** is set on signed overflow: the result does not fit in a signed 16-bit value.
  `NEG` sets V only for 0x8000 (−32768 has no positive 16-bit value).
- **Shifts:** C is the last bit shifted out. A shift by 0 leaves C = 0.

### Data movement

| Instruction | Opcode | Operation | Flags |
|---|---|---|---|
| `MOV Rd, Rs1` | 001111 | Rd ← Rs1 | – |
| `MOVI Rd, imm` | 010000 | Rd ← imm | – |
| `SET Rd` | 010111 | Rd ← 0xFFFF | – |
| `CLR Rd` | 011000 | Rd ← 0x0000 | – |
| `LOAD Rd, addr` | 010001 | Rd ← RAM[addr] | – |
| `STORE Rs1, addr` | 010010 | RAM[addr] ← Rs1 | – |
| `PUSH Rs1` | 010101 | RAM[SP] ← Rs1, SP ← SP − 1 | – |
| `POP Rd` | 010110 | SP ← SP + 1, Rd ← RAM[SP] | – |

`SET` and `CLR` use the same hardware as `MOVI`; the assembler fills in the immediate.

### Input / output

| Instruction | Opcode | Operation | Flags |
|---|---|---|---|
| `IN Rd, port` | 010011 | Rd ← port | – |
| `OUT Rs1, port` | 010100 | port ← Rs1 | – |

Port numbers are listed in the README. The assembler accepts names such as `LEDS`, `SWITCHES` or `SEGMENTS`.

### Jumps

| Instruction | Opcode | Jumps when | Meaning after `CMP A, B` |
|---|---|---|---|
| `JMP addr` | 011001 | always | |
| `JZ addr` | 011011 | Z = 1 | A = B |
| `JNZ addr` | 011100 | Z = 0 | A ≠ B |
| `JC addr` | 011101 | C = 1 | A ≥ B (unsigned) |
| `JNC addr` | 011110 | C = 0 | A < B (unsigned) |
| `JN addr` | 011111 | N = 1 | result negative |
| `JP addr` | 100000 | N = 0 and Z = 0 | result positive |
| `JLE addr` | 100001 | Z = 1 or N ≠ V | A ≤ B (signed) |
| `JGE addr` | 100010 | N = V | A ≥ B (signed) |

`addr` can be a number or a label.

### Subroutines and interrupts

| Instruction | Opcode | Operation |
|---|---|---|
| `CALL addr` | 100011 | Push the address of the next instruction, PC ← addr |
| `RET` | 100100 | PC ← popped address |
| `EI` | 100101 | Enable interrupts |
| `DI` | 100110 | Disable interrupts and drop pending requests |
| `RETI` | 100111 | Return from interrupt handler, allow the next interrupt |

### Other

| Instruction | Opcode | Operation |
|---|---|---|
| `NOP` | 101000 | No operation |
| `STOP` | 101001 | Halt until reset |

Opcode `000000` is reserved: the pipeline uses it internally for flushed slots, and the assembler does not accept it.

## Assembler-only instructions

The assembler turns these into absolute jumps.

| Instruction | Becomes | Target |
|---|---|---|
| `RJMP n` | opcode 011010 (behaves like `JMP`) | skips the next `n` instructions |
| `RJZ n`, `RJNZ n`, `RJC n`, `RJNC n`, `RJN n`, `RJP n`, `RJLE n`, `RJGE n` | the matching `J..` | skips the next `n` instructions if the condition holds |

The target address is computed as `current address + 1 + n`.

## Assembly to machine code

| Assembly | Opcode | Rd | Rs1 | Rs2 | immediate | address | Machine code (hex) |
|---|---|---|---|---|---|---|---|
| `ADD R1, R2, R3` | 000111 | 1 | 2 | 3 | 0 | 0 | `1C22_1800_0000` |
| `MOVI R5, 0x1234` | 010000 | 5 | 0 | 0 | 0x1234 | 0 | `40A0_0091_A000` |
| `OUT R5, LEDS` | 010100 | 0 | 5 | 0 | 0 | 4 | `5005_0000_0004` |

Bit by bit, `ADD R1, R2, R3`:

```
opcode  Rd     Rs1    Rs2    immediate         address
000111  00001  00010  00011  0000000000000000  00000000000
```

= `0x1C22_1800_0000`
