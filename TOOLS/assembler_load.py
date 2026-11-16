#!/usr/bin/env python3
"""Assembler for Bilge's 48-bit FPGA MCU.

Compile-only version.

Usage:
    python assembler.py run program.asm
    python assembler.py run program.asm -o program.hex
    python assembler.py load program.asm
    python assembler.py reload program.asm

UART defaults:
    port = COM3
    baud = 9600

Output lines are 64-bit loader instruction packets:
    [63:59] = 0
    [58:48] = 11-bit Flash address
    [47:0]  = 48-bit machine instruction

This version does not perform UART upload and does not add LOAD/RUN control
packets. Those will be added when load/reload modes are implemented.
"""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional, Sequence, Tuple

START_ADDRESS = 11
MAX_FLASH_ADDRESS = 0x7FF
MAX_REGISTER = 31

DEFAULT_UART_PORT = "COM3"
DEFAULT_BAUD_RATE = 9600
RUN_PACKET = 0xFFFF_FFFF_FFFF_FFFF
LOAD_PACKET = 0x0000_0000_0000_0000

# Current controller opcode map.
OP = {
    "NOP0": 0b000000,   # internal zero/flush opcode; user-facing NOP uses 101000
    "NOT":  0b000001,
    "AND":  0b000010,
    "OR":   0b000011,
    "XOR":  0b000100,
    "SHL":  0b000101,
    "SHR":  0b000110,
    "ADD":  0b000111,
    "SUB":  0b001000,
    "INC":  0b001001,
    "DEC":  0b001010,
    "NEG":  0b001011,
    "CMP":  0b001100,
    "ADDI": 0b001101,
    "SUBI": 0b001110,
    "MOV":  0b001111,
    "MOVI": 0b010000,
    "LOAD": 0b010001,
    "STORE":0b010010,
    "IN":   0b010011,
    "OUT":  0b010100,
    "PUSH": 0b010101,
    "POP":  0b010110,
    "SET":  0b010111,
    "CLR":  0b011000,
    "JMP":  0b011001,
    "RJMP": 0b011010,   # relative jump: assembler computes target from line skip
    "JZ":   0b011011,
    "JNZ":  0b011100,
    "JC":   0b011101,
    "JNC":  0b011110,
    "JN":   0b011111,
    "JP":   0b100000,
    "JLE":  0b100001,
    "JGE":  0b100010,
    "CALL": 0b100011,
    "RET":  0b100100,
    "EI":   0b100101,
    "DI":   0b100110,
    "RETI": 0b100111,
    "NOP":  0b101000,
    "STOP": 0b101001,
}

# Assembler-only relative conditional pseudo-instructions.
# No new hardware opcodes are needed: each RJ* uses the corresponding J* opcode.
RELATIVE_CONDITIONAL_OP = {
    "RJZ":  "JZ",
    "RJNZ": "JNZ",
    "RJC":  "JC",
    "RJNC": "JNC",
    "RJN":  "JN",
    "RJP":  "JP",
    "RJLE": "JLE",
    "RJGE": "JGE",
}


# Peripheral aliases from the current Address_Decoder.
# User-requested board-facing aliases:
#   PORTA = LEDs, PORTB = seven-seg anodes/digits, PORTC = seven-seg segments.
PORTS: Dict[str, int] = {
    "PIN_IN": 1,
    "PIN_OUT": 2,
    "PIN_DIR": 3,

    "PORTA": 4,
    "LEDS": 4,
    "LED": 4,
    "SWITCH": 5,
    "SWITCHES": 5,
    "BUTTON": 6,
    "BUTTONS": 6,
    "BTN_INT_EN": 7,
    "BTN_INT_DIS": 8,
    "DEBOUNCE_EN": 9,
    "DEBOUNCE_DIS": 10,

    "BCD_IN": 21,
    "BCD_OUT": 22,
    "SEGCONV_IN": 23,
    "SEGCONV_OUT0": 24,
    "SEGCONV_OUT1": 25,
    "SEGCONV_OUT2": 26,
    "SEGCONV_OUT3": 27,

    "PORTB": 28,
    "ANODE": 28,
    "ANODES": 28,
    "DIGITS": 28,
    "PORTC": 29,
    "SEVEN_SEGMENT": 29,
    "SEGMENTS": 29,

    "PWM_EN": 32,
    "PWM_DIS": 33,
    "PWM_PRESCALER": 34,
    "PWM_DUTY": 35,

    "TIMER0_EN": 36,
    "TIMER0_DIS": 37,
    "TIMER0_INT_EN": 38,
    "TIMER0_INT_DIS": 39,
    "TIMER0_PRESCALER": 40,
    "TIMER0_MAX": 41,

    "TIMER1_EN": 42,
    "TIMER1_DIS": 43,
    "TIMER1_INT_EN": 44,
    "TIMER1_INT_DIS": 45,
    "TIMER1_PRESCALER": 46,
    "TIMER1_MAX": 47,

    "TIMER2_EN": 48,
    "TIMER2_DIS": 49,
    "TIMER2_INT_EN": 50,
    "TIMER2_INT_DIS": 51,
    "TIMER2_PRESCALER": 52,
    "TIMER2_MAX": 53,

    "TIMER3_EN": 54,
    "TIMER3_DIS": 55,
    "TIMER3_INT_EN": 56,
    "TIMER3_INT_DIS": 57,
    "TIMER3_PRESCALER": 58,
    "TIMER3_MAX": 59,

    "TIMER4_EN": 60,
    "TIMER4_DIS": 61,
    "TIMER4_INT_EN": 62,
    "TIMER4_INT_DIS": 63,
    "TIMER4_PRESCALER": 64,
    "TIMER4_MAX": 65,

    "WDT_EN": 66,
    "WATCHDOG_EN": 66,
    "WDT_CLEAR": 67,
    "WATCHDOG_CLEAR": 67,
    "WDT_PRESCALER": 68,
    "WATCHDOG_PRESCALER": 68,
    "WDT_MAX": 69,
    "WATCHDOG_MAX": 69,
    "WDT_DIS": 70,
    "WATCHDOG_DIS": 70,

    "IRQ_MASK": 71,
    "INTERRUPT_MASK": 71,

    "TIMER0_CLEAR": 72,
    "TIMER1_CLEAR": 73,
    "TIMER2_CLEAR": 74,
    "TIMER3_CLEAR": 75,
    "TIMER4_CLEAR": 76,

    "TIMER0_READ": 77,
    "TIMER1_READ": 78,
    "TIMER2_READ": 79,
    "TIMER3_READ": 80,
    "TIMER4_READ": 81,
}

LABEL_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
REGISTER_RE = re.compile(r"^[Rr](\d+)$")


class AssemblyError(Exception):
    def __init__(self, line_no: int, source: str, message: str):
        self.line_no = line_no
        self.source = source
        self.message = message
        super().__init__(message)

    def pretty(self) -> str:
        return (
            f"ERROR line {self.line_no}:\n"
            f"    {self.source.rstrip()}\n"
            f"{self.message}"
        )


@dataclass
class SourceInstruction:
    line_no: int
    source: str
    text: str
    address: int


@dataclass
class EncodedInstruction:
    line_no: int
    source: str
    address: int
    machine: int

    @property
    def machine_hex(self) -> str:
        return f"{self.machine:012X}"

    @property
    def packet(self) -> int:
        return ((self.address & 0x7FF) << 48) | (self.machine & ((1 << 48) - 1))

    @property
    def packet_hex(self) -> str:
        return f"{self.packet:016X}"


def strip_comment(line: str) -> str:
    # Support ';', '#', and '//' comments.
    cut = len(line)
    for marker in ("//", ";", "#"):
        pos = line.find(marker)
        if pos != -1:
            cut = min(cut, pos)
    return line[:cut].strip()


def parse_number(token: str, line_no: int, source: str) -> int:
    token = token.strip().replace("_", "")
    try:
        # int(..., 0) supports 0x, 0b, 0o, and decimal.
        return int(token, 0)
    except ValueError:
        raise AssemblyError(line_no, source, f"Invalid number: {token}")


def parse_register(token: str, line_no: int, source: str) -> int:
    m = REGISTER_RE.fullmatch(token.strip())
    if not m:
        raise AssemblyError(line_no, source, f"Invalid register: {token}. Expected R0-R31.")
    reg = int(m.group(1))
    if not 0 <= reg <= MAX_REGISTER:
        raise AssemblyError(line_no, source, f"Invalid register: R{reg}. Expected R0-R31.")
    return reg


def parse_imm16(token: str, line_no: int, source: str) -> int:
    value = parse_number(token, line_no, source)
    if value < -32768 or value > 0xFFFF:
        raise AssemblyError(
            line_no,
            source,
            f"Immediate out of range: {value}. Expected -32768..65535.",
        )
    return value & 0xFFFF


def parse_address_value(
    token: str,
    labels: Dict[str, int],
    line_no: int,
    source: str,
    allow_ports: bool = False,
) -> int:
    key = token.strip().upper()

    if allow_ports and key in PORTS:
        value = PORTS[key]
    elif token.strip() in labels:
        value = labels[token.strip()]
    else:
        try:
            value = parse_number(token, line_no, source)
        except AssemblyError:
            if LABEL_RE.fullmatch(token.strip()):
                raise AssemblyError(line_no, source, f"Unknown label or symbol: {token.strip()}")
            raise

    if not 0 <= value <= MAX_FLASH_ADDRESS:
        raise AssemblyError(
            line_no,
            source,
            f"Address out of range: {value}. Expected 0-{MAX_FLASH_ADDRESS}.",
        )
    return value


def split_instruction(text: str) -> Tuple[str, List[str]]:
    parts = text.strip().split(None, 1)
    mnemonic = parts[0].upper()
    if len(parts) == 1:
        return mnemonic, []
    operands = [x.strip() for x in parts[1].split(",")]
    return mnemonic, operands


def require_count(
    mnemonic: str,
    operands: Sequence[str],
    count: int,
    line_no: int,
    source: str,
    syntax: str,
) -> None:
    if len(operands) != count or any(op == "" for op in operands):
        raise AssemblyError(line_no, source, f"Syntax: {syntax}")


def pack_instruction(
    opcode: int,
    rd: int = 0,
    rs1: int = 0,
    rs2: int = 0,
    immediate: int = 0,
    address: int = 0,
) -> int:
    return (
        ((opcode & 0x3F) << 42)
        | ((rd & 0x1F) << 37)
        | ((rs1 & 0x1F) << 32)
        | ((rs2 & 0x1F) << 27)
        | ((immediate & 0xFFFF) << 11)
        | (address & 0x7FF)
    )


def first_pass(lines: Sequence[str]) -> Tuple[List[SourceInstruction], Dict[str, int]]:
    instructions: List[SourceInstruction] = []
    labels: Dict[str, int] = {}
    normal_address = START_ADDRESS
    pending_override: Optional[int] = None
    pending_labels: List[Tuple[str, int, str]] = []
    used_addresses: Dict[int, Tuple[int, str]] = {}

    for line_no, raw in enumerate(lines, start=1):
        text = strip_comment(raw)
        if not text:
            continue

        # Allow one or more labels before an instruction/directive, e.g. foo: bar: NOP
        while ":" in text:
            left, right = text.split(":", 1)
            candidate = left.strip()
            if not LABEL_RE.fullmatch(candidate):
                break
            if candidate in labels or any(candidate == x[0] for x in pending_labels):
                raise AssemblyError(line_no, raw, f"Duplicate label: {candidate}")
            pending_labels.append((candidate, line_no, raw))
            text = right.strip()
            if not text:
                break

        if not text:
            continue

        if text.lower().startswith(".addr"):
            parts = text.split()
            if len(parts) != 2:
                raise AssemblyError(line_no, raw, "Syntax: .addr <0..2047>")
            if pending_override is not None:
                raise AssemblyError(
                    line_no,
                    raw,
                    ".addr already pending. It must be followed by one instruction before another .addr.",
                )
            value = parse_number(parts[1], line_no, raw)
            if not 0 <= value <= MAX_FLASH_ADDRESS:
                raise AssemblyError(
                    line_no,
                    raw,
                    f".addr out of range: {value}. Expected 0-{MAX_FLASH_ADDRESS}.",
                )
            pending_override = value
            continue

        address = pending_override if pending_override is not None else normal_address

        # Labels bind to the next real instruction's EFFECTIVE address, including .addr override.
        for label, label_line, label_src in pending_labels:
            if label in labels:
                raise AssemblyError(label_line, label_src, f"Duplicate label: {label}")
            labels[label] = address
        pending_labels.clear()

        if address in used_addresses:
            prev_line, prev_src = used_addresses[address]
            raise AssemblyError(
                line_no,
                raw,
                f"Flash address {address} is already used by line {prev_line}: {prev_src.strip()}",
            )
        used_addresses[address] = (line_no, raw)

        instructions.append(SourceInstruction(line_no, raw, text, address))

        if pending_override is not None:
            # One-shot override: normal sequential address flow does not change.
            pending_override = None
        else:
            if normal_address >= MAX_FLASH_ADDRESS:
                raise AssemblyError(line_no, raw, "Normal instruction address exceeded Flash range.")
            normal_address += 1

    if pending_override is not None:
        raise AssemblyError(len(lines), lines[-1] if lines else "", ".addr has no following instruction.")

    if pending_labels:
        label, line_no, src = pending_labels[0]
        raise AssemblyError(line_no, src, f"Label '{label}' has no following instruction.")

    return instructions, labels


def encode_one(ins: SourceInstruction, labels: Dict[str, int]) -> EncodedInstruction:
    mnemonic, a = split_instruction(ins.text)
    n = ins.line_no
    src = ins.source

    if (mnemonic not in OP and mnemonic not in RELATIVE_CONDITIONAL_OP) or mnemonic == "NOP0":
        raise AssemblyError(n, src, f"Unknown instruction: {mnemonic}")

    hardware_mnemonic = RELATIVE_CONDITIONAL_OP.get(mnemonic, mnemonic)
    op = OP[hardware_mnemonic]
    rd = rs1 = rs2 = imm = addr = 0

    # Rd, Rs1
    if mnemonic in {"NOT", "INC", "DEC", "NEG", "MOV"}:
        require_count(mnemonic, a, 2, n, src, f"{mnemonic} Rd, Rs1")
        rd = parse_register(a[0], n, src)
        rs1 = parse_register(a[1], n, src)

    # Rd, Rs1, Rs2
    elif mnemonic in {"AND", "OR", "XOR", "SHL", "SHR", "ADD", "SUB"}:
        require_count(mnemonic, a, 3, n, src, f"{mnemonic} Rd, Rs1, Rs2")
        rd = parse_register(a[0], n, src)
        rs1 = parse_register(a[1], n, src)
        rs2 = parse_register(a[2], n, src)

    elif mnemonic == "CMP":
        require_count(mnemonic, a, 2, n, src, "CMP Rs1, Rs2")
        rs1 = parse_register(a[0], n, src)
        rs2 = parse_register(a[1], n, src)

    elif mnemonic in {"ADDI", "SUBI"}:
        require_count(mnemonic, a, 3, n, src, f"{mnemonic} Rd, Rs1, Immediate")
        rd = parse_register(a[0], n, src)
        rs1 = parse_register(a[1], n, src)
        imm = parse_imm16(a[2], n, src)

    elif mnemonic == "MOVI":
        require_count(mnemonic, a, 2, n, src, "MOVI Rd, Immediate")
        rd = parse_register(a[0], n, src)
        imm = parse_imm16(a[1], n, src)

    elif mnemonic == "LOAD":
        require_count(mnemonic, a, 2, n, src, "LOAD Rd, Address")
        rd = parse_register(a[0], n, src)
        addr = parse_address_value(a[1], labels, n, src)
        if addr > 0xFF:
            raise AssemblyError(n, src, f"RAM address out of range: {addr}. Controller RAM address is 8-bit (0-255).")

    elif mnemonic == "STORE":
        require_count(mnemonic, a, 2, n, src, "STORE Rs1, Address")
        rs1 = parse_register(a[0], n, src)
        addr = parse_address_value(a[1], labels, n, src)
        if addr > 0xFF:
            raise AssemblyError(n, src, f"RAM address out of range: {addr}. Controller RAM address is 8-bit (0-255).")

    elif mnemonic == "IN":
        require_count(mnemonic, a, 2, n, src, "IN Rd, Port")
        rd = parse_register(a[0], n, src)
        addr = parse_address_value(a[1], labels, n, src, allow_ports=True)

    elif mnemonic == "OUT":
        require_count(mnemonic, a, 2, n, src, "OUT Rs1, Port")
        rs1 = parse_register(a[0], n, src)
        addr = parse_address_value(a[1], labels, n, src, allow_ports=True)

    elif mnemonic == "PUSH":
        require_count(mnemonic, a, 1, n, src, "PUSH Rs1")
        rs1 = parse_register(a[0], n, src)

    elif mnemonic == "POP":
        require_count(mnemonic, a, 1, n, src, "POP Rd")
        rd = parse_register(a[0], n, src)

    elif mnemonic == "SET":
        require_count(mnemonic, a, 1, n, src, "SET Rd")
        rd = parse_register(a[0], n, src)
        imm = 0xFFFF

    elif mnemonic == "CLR":
        require_count(mnemonic, a, 1, n, src, "CLR Rd")
        rd = parse_register(a[0], n, src)
        imm = 0x0000

    elif mnemonic == "RJMP":
        require_count(mnemonic, a, 1, n, src, "RJMP LinesToSkip")
        skip = parse_number(a[0], n, src)
        # RJMP 1 skips exactly one following instruction:
        # target = current_address + 1 + 1.
        target = ins.address + 1 + skip
        if not 0 <= target <= MAX_FLASH_ADDRESS:
            raise AssemblyError(
                n, src,
                f"Relative jump target out of range: {target}. Expected 0-{MAX_FLASH_ADDRESS}.",
            )
        addr = target

    elif mnemonic in RELATIVE_CONDITIONAL_OP:
        require_count(mnemonic, a, 1, n, src, f"{mnemonic} LinesToSkip")
        skip = parse_number(a[0], n, src)
        # RJC 1, for example, skips one following instruction if C=1.
        target = ins.address + 1 + skip
        if not 0 <= target <= MAX_FLASH_ADDRESS:
            raise AssemblyError(
                n, src,
                f"Relative jump target out of range: {target}. Expected 0-{MAX_FLASH_ADDRESS}.",
            )
        addr = target

    elif mnemonic in {"JMP", "JZ", "JNZ", "JC", "JNC", "JN", "JP", "JLE", "JGE", "CALL"}:
        require_count(mnemonic, a, 1, n, src, f"{mnemonic} AddressOrLabel")
        addr = parse_address_value(a[0], labels, n, src)

    elif mnemonic in {"RET", "EI", "DI", "RETI", "NOP", "STOP"}:
        require_count(mnemonic, a, 0, n, src, mnemonic)

    machine = pack_instruction(op, rd, rs1, rs2, imm, addr)
    return EncodedInstruction(n, src, ins.address, machine)


def assemble(lines: Sequence[str]) -> Tuple[List[EncodedInstruction], Dict[str, int]]:
    source_instructions, labels = first_pass(lines)
    encoded = [encode_one(ins, labels) for ins in source_instructions]
    return encoded, labels


def listing_text(encoded: Sequence[EncodedInstruction], labels: Dict[str, int]) -> str:
    out: List[str] = []
    out.append("ASSEMBLY SUCCESS")
    out.append("")
    if labels:
        out.append("LABELS")
        for name, address in labels.items():
            out.append(f"  {name:<24} = {address}")
        out.append("")
    out.append("ADDR   MACHINE_CODE   PACKET_64BIT       SOURCE")
    out.append("-----  -------------  -----------------  ------------------------------")
    for item in encoded:
        source = strip_comment(item.source)
        out.append(f"{item.address:5d}  {item.machine_hex}   {item.packet_hex}   {source}")
    return "\n".join(out) + "\n"


def hex_output(encoded: Sequence[EncodedInstruction]) -> str:
    # One 64-bit loader instruction packet per line. No LOAD/RUN control packets yet.
    return "\n".join(item.packet_hex for item in encoded) + ("\n" if encoded else "")


def packet_to_uart_bytes(packet: int) -> bytes:
    """Convert one 64-bit loader packet to 8 UART bytes, MSB first."""
    return int(packet & 0xFFFF_FFFF_FFFF_FFFF).to_bytes(8, byteorder="big")


def upload_packets(
    encoded: Sequence[EncodedInstruction],
    port: str,
    baud: int,
    send_load_packet: bool,
) -> None:
    try:
        import serial
    except ImportError:
        raise RuntimeError(
            "pyserial is not installed. Install it with: python -m pip install pyserial"
        )

    try:
        with serial.Serial(
            port=port,
            baudrate=baud,
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            timeout=1,
            write_timeout=5,
        ) as ser:

            if send_load_packet:
                ser.write(packet_to_uart_bytes(LOAD_PACKET))
                ser.flush()

            for item in encoded:
                ser.write(packet_to_uart_bytes(item.packet))

            ser.write(packet_to_uart_bytes(RUN_PACKET))
            ser.flush()

    except Exception as exc:
        raise RuntimeError(
            f"UART upload failed on {port} @ {baud} baud: {exc}"
        ) from exc

def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="48-bit FPGA MCU assembler")
    sub = parser.add_subparsers(dest="command", required=True)

    run = sub.add_parser("run", help="Compile only; do not upload")
    run.add_argument("source", help="Assembly source file (.asm)")
    run.add_argument("-o", "--output", help="64-bit packet output file (default: <source>.hex)")
    run.add_argument("--listing", help="Optional human-readable listing file")

    load = sub.add_parser("load", help="Compile and upload; finish with RUN packet")
    load.add_argument("source", help="Assembly source file (.asm)")
    load.add_argument("--port", default=DEFAULT_UART_PORT)
    load.add_argument("--baud", type=int, default=DEFAULT_BAUD_RATE)

    reload_cmd = sub.add_parser("reload", help="Send LOAD packet, upload, then RUN packet")
    reload_cmd.add_argument("source", help="Assembly source file (.asm)")
    reload_cmd.add_argument("--port", default=DEFAULT_UART_PORT)
    reload_cmd.add_argument("--baud", type=int, default=DEFAULT_BAUD_RATE)

    args = parser.parse_args(argv)

    if args.command in {"run", "load", "reload"}:
        source_path = Path(args.source)
        if not source_path.exists():
            print(f"ERROR: source file not found: {source_path}", file=sys.stderr)
            return 1

        try:
            lines = source_path.read_text(encoding="utf-8").splitlines()
            encoded, labels = assemble(lines)
        except AssemblyError as exc:
            print(exc.pretty(), file=sys.stderr)
            return 1
        except OSError as exc:
            print(f"ERROR: {exc}", file=sys.stderr)
            return 1

        text_listing = listing_text(encoded, labels)

        if args.command == "run":
            output_path = Path(args.output) if args.output else source_path.with_suffix(".hex")
            output_path.write_text(hex_output(encoded), encoding="ascii")
            print(text_listing, end="")
            print(f"Output: {output_path}")

            if args.listing:
                listing_path = Path(args.listing)
                listing_path.write_text(text_listing, encoding="utf-8")
                print(f"Listing: {listing_path}")
            return 0

        try:
            upload_packets(
                encoded,
                args.port,
                args.baud,
                send_load_packet=(args.command == "reload"),
            )
        except RuntimeError as exc:
            print(f"ERROR: {exc}", file=sys.stderr)
            return 1

        print(text_listing, end="")
        if args.command == "load":
            print(
                f"UPLOAD SUCCESS: {len(encoded)} instruction(s) sent to "
                f"{args.port} @ {args.baud} baud, followed by RUN packet."
            )
        else:
            print(
                f"RELOAD SUCCESS: LOAD packet + {len(encoded)} instruction(s) sent to "
                f"{args.port} @ {args.baud} baud, followed by RUN packet."
            )
        return 0

    return 2


if __name__ == "__main__":
    raise SystemExit(main())
