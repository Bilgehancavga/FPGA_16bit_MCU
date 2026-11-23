`timescale 1ns / 1ps

// ============================================================================
// mcu_class_tb.sv
//
// Class-based, layered, self-checking testbench for the custom 16-bit MCU.
// (Same building blocks as UVM, written without the UVM library.)
//
//   generator  --(gen2drv)-->  driver  --(drv2scb)-->  scoreboard
//                                |                         ^
//                                v                         |
//                         [ mcu_if / DUT ]  -->  monitor --(mon2scb)
//                                |
//                                +-->  peripheral monitor --> peripheral scoreboard
//
//   1. INTERFACE   mcu_if      : every signal the TB drives or watches
//   2. PACKAGE     mcu_pkg     : transaction, program, generator, driver,
//                                monitors, reference model, scoreboards,
//                                peripheral scenarios, env
//   3. ASSERTIONS  mcu_sva     : rules checked on every clock edge
//   4. TOP         mcu_class_tb: clock, DUT, interface, test
//
// Phase 1 - CPU CORE (reference model):
//   - generator builds programs (directed + constrained-random)
//   - driver writes them into flash, releases reset, waits for STOP
//   - monitor records every register / flag / RAM / port write
//   - reference model runs the same program in software and predicts
//     the same list of writes; scoreboard compares the two lists
//
// Phase 2 - PERIPHERALS (directed scenarios):
//   LED/switch, GPIO pins, BCD + 7-segment, timers, interrupts and their
//   priority, nested interrupts (no preemption), PWM, watchdog, reset
//   sources, buttons + debouncer, interrupts of all five buttons, stack.
//   Timing-dependent results are checked against values or ranges.
//   (UART bootloader is not simulated: it was verified on the board.)
//
// Plusargs:  +NRAND=<n>   number of random programs (default 50)
//            +VERBOSE     print every compared event
// ============================================================================


// ============================================================================
// 1. INTERFACE
// ============================================================================
interface mcu_if (input logic clk);

    // ---- driven by the driver ----------------------------------------------
    logic [10:0] flash_wr_addr = '0;
    logic [47:0] flash_wr_data = '0;
    logic        flash_wr_en   = 1'b0;
    logic        flash_rd_en   = 1'b0;
    logic        cpu_en        = 1'b0;
    logic        rst_n         = 1'b0;
    logic [15:0] sws           = '0;
    logic [4:0]  btn           = '0;      // buttons (D, R, C, L, U)
    logic        btn_reset     = 1'b1;    // reset button, active low
    logic [15:0] pins_drive    = 'z;      // TB side of the GPIO pins
    logic        use_real_reset = 1'b0;   // 1 = Reset_unit drives rst_n

    // ---- watched by the monitor and the assertions ---------------------------
    logic        rf_we;          // register file write enable
    logic [4:0]  rf_waddr;       // register being written
    logic [15:0] rf_wdata;       // value being written
    logic        sr_we;          // status register write enable
    logic [3:0]  alu_flags;      // next flags {V, C, N, Z}
    logic        ram_we;         // RAM write enable
    logic [7:0]  ram_addr;
    logic [15:0] ram_wdata;
    logic        port_en;        // IN or OUT is executing
    logic [10:0] port_addr;
    logic [15:0] port_wdata;     // value written by OUT
    logic [2:0]  state;          // controller FSM state
    logic [10:0] pc;
    logic [7:0]  sp;
    logic        push;
    logic        pop;
    logic [7:0]  anode;

    // ---- peripheral side --------------------------------------------------
    wire  [15:0] regs [0:31];    // register file contents
    logic        dut_rst_n;      // reset actually seen by the MCU
    logic        por_n;          // power-on reset output
    logic        por_early;      // power-on reset sampled right after start
    logic        wd_reset;       // watchdog reset pulse
    logic [9:0]  irq_id;
    logic        irq_active;
    logic        btn_db0;        // debounced pulse of button U
    logic [15:0] led;
    wire  [15:0] pins_val;
    logic [6:0]  seg;
    logic        dp;
    logic        pwm;

endinterface


// ============================================================================
// 2. PACKAGE
// ============================================================================
package mcu_pkg;

    // ------------------------------------------------------------------------
    // Constants (must match controller.sv / Address_Decoder.sv)
    // ------------------------------------------------------------------------
    localparam logic [5:0]
        OP_NOT   = 6'b000001, OP_AND   = 6'b000010, OP_OR    = 6'b000011,
        OP_XOR   = 6'b000100, OP_SHL   = 6'b000101, OP_SHR   = 6'b000110,
        OP_ADD   = 6'b000111, OP_SUB   = 6'b001000, OP_INC   = 6'b001001,
        OP_DEC   = 6'b001010, OP_NEG   = 6'b001011, OP_CMP   = 6'b001100,
        OP_ADDI  = 6'b001101, OP_SUBI  = 6'b001110, OP_MOV   = 6'b001111,
        OP_MOVI  = 6'b010000, OP_LOAD  = 6'b010001, OP_STORE = 6'b010010,
        OP_IN    = 6'b010011, OP_OUT   = 6'b010100, OP_PUSH  = 6'b010101,
        OP_POP   = 6'b010110, OP_SET   = 6'b010111, OP_CLR   = 6'b011000,
        OP_JMP   = 6'b011001, OP_RJMP  = 6'b011010, OP_JZ    = 6'b011011,
        OP_JNZ   = 6'b011100, OP_JC    = 6'b011101, OP_JNC   = 6'b011110,
        OP_JN    = 6'b011111, OP_JP    = 6'b100000, OP_JLE   = 6'b100001,
        OP_JGE   = 6'b100010, OP_CALL  = 6'b100011, OP_RET   = 6'b100100,
        OP_EI    = 6'b100101, OP_DI    = 6'b100110, OP_RETI  = 6'b100111,
        OP_NOP   = 6'b101000, OP_STOP  = 6'b101001;

    localparam logic [10:0]
        PORT_PINS_IN     = 11'd1,  PORT_PINS_OUT    = 11'd2,  PORT_PINS_DIR   = 11'd3,
        PORT_LED         = 11'd4,  PORT_SW          = 11'd5,  PORT_BTN_READ   = 11'd6,
        PORT_BTN_IRQ_EN  = 11'd7,  PORT_BTN_IRQ_DIS = 11'd8,  PORT_DB_EN      = 11'd9,
        PORT_BIN2BCD_IN  = 11'd21, PORT_BIN2BCD_OUT = 11'd22, PORT_BCD2SEG_IN = 11'd23,
        PORT_BCD2SEG_D0  = 11'd24, PORT_BCD2SEG_D1  = 11'd25, PORT_BCD2SEG_D2 = 11'd26,
        PORT_BCD2SEG_D3  = 11'd27, PORT_7SEG_DIGITS = 11'd28, PORT_7SEG_SEGS  = 11'd29,
        PORT_PWM_EN      = 11'd32, PORT_PWM_DIS     = 11'd33, PORT_PWM_PRESC  = 11'd34,
        PORT_PWM_DUTY    = 11'd35,
        PORT_T0_EN       = 11'd36, PORT_T0_DIS      = 11'd37, PORT_T0_IRQ_EN  = 11'd38,
        PORT_T0_PRESC    = 11'd40, PORT_T0_MAX      = 11'd41,
        PORT_T1_EN       = 11'd42, PORT_T1_DIS      = 11'd43, PORT_T1_IRQ_EN  = 11'd44,
        PORT_T1_PRESC    = 11'd46, PORT_T1_MAX      = 11'd47,
        PORT_T2_EN       = 11'd48, PORT_T2_DIS      = 11'd49, PORT_T2_IRQ_EN  = 11'd50,
        PORT_T2_PRESC    = 11'd52, PORT_T2_MAX      = 11'd53,
        PORT_T3_EN       = 11'd54, PORT_T3_IRQ_EN   = 11'd56, PORT_T3_PRESC   = 11'd58,
        PORT_T3_MAX      = 11'd59,
        PORT_T4_EN       = 11'd60, PORT_T4_IRQ_EN   = 11'd62, PORT_T4_PRESC   = 11'd64,
        PORT_T4_MAX      = 11'd65,
        PORT_WD_EN       = 11'd66, PORT_WD_CLEAR    = 11'd67, PORT_WD_PRESC   = 11'd68,
        PORT_WD_MAX      = 11'd69, PORT_IRQ_MASK    = 11'd71,
        PORT_T1_CLEAR    = 11'd73, PORT_T1_READ     = 11'd78,
        PORT_T3_READ     = 11'd80, PORT_T4_READ     = 11'd81;

    localparam int          PROGRAM_START = 11;   // PC after reset
    localparam logic [2:0]  ST_INSTRUCTION = 3'd2, ST_INTERRUPT = 3'd3,
                            ST_WAIT = 3'd4, ST_RET = 3'd5, ST_RETI = 3'd6,
                            ST_STOP = 3'd7;

    // assertion failures (incremented by mcu_sva)
    int sva_errors = 0;

    function automatic void sva_fail(string msg);
        sva_errors++;
        $display("    ASSERTION FAILED  t=%0t  %s", $time, msg);
    endfunction


    // left-aligned text of fixed width (for the report table)
    function automatic string pad(string s, int n);
        while (s.len() < n) s = {s, " "};
        return s;
    endfunction


    // ------------------------------------------------------------------------
    // 2a. TRANSACTION: one instruction
    // ------------------------------------------------------------------------
    class mcu_instr;
        rand bit [5:0]  op;
        rand bit [4:0]  rd, rs1, rs2;
        rand bit [15:0] imm;
        rand bit [10:0] addr;     // jump target / RAM address / port
        rand bit [1:0]  skip;     // forward jump distance (random programs)
        bit      [10:0] pc;       // flash address, set by mcu_program::add()

        // Instruction mix of the random programs (weights)
        constraint c_op {
            op dist {
                OP_ADD  := 8, OP_SUB  := 8, OP_AND  := 4, OP_OR   := 4,
                OP_XOR  := 4, OP_SHL  := 4, OP_SHR  := 4, OP_NOT  := 2,
                OP_INC  := 3, OP_DEC  := 3, OP_NEG  := 2, OP_MOV  := 3,
                OP_CMP  := 8, OP_ADDI := 4, OP_SUBI := 4,
                OP_MOVI := 3, OP_SET  := 1, OP_CLR  := 1,
                OP_LOAD := 4, OP_STORE:= 4, OP_PUSH := 3, OP_POP  := 3,
                OP_IN   := 2, OP_OUT  := 2, OP_NOP  := 1,
                OP_JMP  := 2, OP_JZ   := 2, OP_JNZ  := 2, OP_JC   := 2,
                OP_JNC  := 2, OP_JN   := 2, OP_JP   := 2, OP_JLE  := 2,
                OP_JGE  := 2
            };
        }

        // Random programs use R0..R15 (all initialised in the prologue)
        constraint c_regs { rd < 16; rs1 < 16; rs2 < 16; }

        // Corner values are picked more often than plain random values
        constraint c_imm {
            imm dist { 16'h0000 := 5, 16'h0001 := 5, 16'h7FFF := 5,
                       16'h8000 := 5, 16'hFFFF := 5, [16'h0002:16'hFFFE] :/ 75 };
            (op == OP_SET) -> imm == 16'hFFFF;
            (op == OP_CLR) -> imm == 16'h0000;
        }

        // RAM data area 0..7, IN only from switches, OUT only to LEDs
        // (other ports could start timers / watchdog and break the run)
        constraint c_addr {
            (op inside {OP_LOAD, OP_STORE}) -> addr < 8;
            (op == OP_IN)  -> addr == PORT_SW;
            (op == OP_OUT) -> addr == PORT_LED;
        }

        // Zero the fields this opcode does not use (same as the assembler)
        function void canonicalize();
            case (op)
                OP_ADD, OP_SUB, OP_AND, OP_OR, OP_XOR, OP_SHL, OP_SHR:
                    begin imm = 0; addr = 0; end
                OP_NOT, OP_NEG, OP_INC, OP_DEC, OP_MOV:
                    begin rs2 = 0; imm = 0; addr = 0; end
                OP_ADDI, OP_SUBI:
                    begin rs2 = 0; addr = 0; end
                OP_MOVI, OP_SET, OP_CLR:
                    begin rs1 = 0; rs2 = 0; addr = 0; end
                OP_CMP:
                    begin rd = 0; imm = 0; addr = 0; end
                OP_LOAD, OP_IN:
                    begin rs1 = 0; rs2 = 0; imm = 0; end
                OP_STORE, OP_OUT:
                    begin rd = 0; rs2 = 0; imm = 0; end
                OP_PUSH:
                    begin rd = 0; rs2 = 0; imm = 0; addr = 0; end
                OP_POP:
                    begin rs1 = 0; rs2 = 0; imm = 0; addr = 0; end
                OP_JMP, OP_JZ, OP_JNZ, OP_JC, OP_JNC, OP_JN, OP_JP,
                OP_JLE, OP_JGE, OP_CALL:
                    begin rd = 0; rs1 = 0; rs2 = 0; imm = 0; end
                default:
                    begin rd = 0; rs1 = 0; rs2 = 0; imm = 0; addr = 0; end
            endcase
        endfunction

        function bit is_jump();
            return op inside {OP_JMP, OP_JZ, OP_JNZ, OP_JC, OP_JNC,
                              OP_JN, OP_JP, OP_JLE, OP_JGE};
        endfunction

        // 48-bit machine code: [47:42] op | [41:37] Rd | [36:32] Rs1 |
        //                      [31:27] Rs2 | [26:11] Imm | [10:0] Addr
        function bit [47:0] encode();
            return {op, rd, rs1, rs2, imm, addr};
        endfunction

        // Disassembly, used in error messages
        function string text();
            case (op)
                OP_ADD:  return $sformatf("ADD  R%0d, R%0d, R%0d", rd, rs1, rs2);
                OP_SUB:  return $sformatf("SUB  R%0d, R%0d, R%0d", rd, rs1, rs2);
                OP_AND:  return $sformatf("AND  R%0d, R%0d, R%0d", rd, rs1, rs2);
                OP_OR:   return $sformatf("OR   R%0d, R%0d, R%0d", rd, rs1, rs2);
                OP_XOR:  return $sformatf("XOR  R%0d, R%0d, R%0d", rd, rs1, rs2);
                OP_SHL:  return $sformatf("SHL  R%0d, R%0d, R%0d", rd, rs1, rs2);
                OP_SHR:  return $sformatf("SHR  R%0d, R%0d, R%0d", rd, rs1, rs2);
                OP_NOT:  return $sformatf("NOT  R%0d, R%0d", rd, rs1);
                OP_NEG:  return $sformatf("NEG  R%0d, R%0d", rd, rs1);
                OP_INC:  return $sformatf("INC  R%0d, R%0d", rd, rs1);
                OP_DEC:  return $sformatf("DEC  R%0d, R%0d", rd, rs1);
                OP_MOV:  return $sformatf("MOV  R%0d, R%0d", rd, rs1);
                OP_ADDI: return $sformatf("ADDI R%0d, R%0d, 0x%h", rd, rs1, imm);
                OP_SUBI: return $sformatf("SUBI R%0d, R%0d, 0x%h", rd, rs1, imm);
                OP_MOVI: return $sformatf("MOVI R%0d, 0x%h", rd, imm);
                OP_SET:  return $sformatf("SET  R%0d", rd);
                OP_CLR:  return $sformatf("CLR  R%0d", rd);
                OP_CMP:  return $sformatf("CMP  R%0d, R%0d", rs1, rs2);
                OP_LOAD: return $sformatf("LOAD R%0d, [%0d]", rd, addr);
                OP_STORE:return $sformatf("STORE R%0d, [%0d]", rs1, addr);
                OP_IN:   return $sformatf("IN   R%0d, port %0d", rd, addr);
                OP_OUT:  return $sformatf("OUT  R%0d, port %0d", rs1, addr);
                OP_PUSH: return $sformatf("PUSH R%0d", rs1);
                OP_POP:  return $sformatf("POP  R%0d", rd);
                OP_JMP:  return $sformatf("JMP  %0d", addr);
                OP_JZ:   return $sformatf("JZ   %0d", addr);
                OP_JNZ:  return $sformatf("JNZ  %0d", addr);
                OP_JC:   return $sformatf("JC   %0d", addr);
                OP_JNC:  return $sformatf("JNC  %0d", addr);
                OP_JN:   return $sformatf("JN   %0d", addr);
                OP_JP:   return $sformatf("JP   %0d", addr);
                OP_JLE:  return $sformatf("JLE  %0d", addr);
                OP_JGE:  return $sformatf("JGE  %0d", addr);
                OP_CALL: return $sformatf("CALL %0d", addr);
                OP_RET:  return "RET";
                OP_NOP:  return "NOP";
                OP_STOP: return "STOP";
                default: return $sformatf("op=%b", op);
            endcase
        endfunction

        // Build an instruction directly (directed programs)
        static function mcu_instr make(bit [5:0] op, bit [4:0] rd = 0,
                                       bit [4:0] rs1 = 0, bit [4:0] rs2 = 0,
                                       bit [15:0] imm = 0, bit [10:0] addr = 0);
            mcu_instr t = new();
            t.op = op; t.rd = rd; t.rs1 = rs1; t.rs2 = rs2;
            t.imm = imm; t.addr = addr;
            return t;
        endfunction
    endclass


    // ------------------------------------------------------------------------
    // 2b. PROGRAM: a list of instructions placed from address 11
    // ------------------------------------------------------------------------
    class mcu_program;
        string      name;
        mcu_instr   code[$];      // main program, from address 11
        mcu_instr   extra[$];     // vectors / ISRs at fixed addresses
        bit [15:0]  sws;          // switch value while the program runs
        bit         timed_out;
        int         cycles;

        function new(string name);
            this.name = name;
        endfunction

        // Append an instruction, return its flash address
        function int add(mcu_instr t);
            t.pc = PROGRAM_START + code.size();
            code.push_back(t);
            return t.pc;
        endfunction

        // Put an instruction at a fixed flash address (vector, ISR)
        function void place(int address, mcu_instr t);
            t.pc = address;
            extra.push_back(t);
        endfunction

        function int next_pc();
            return PROGRAM_START + code.size();
        endfunction

        function bit has(int pc);
            return (pc >= PROGRAM_START) && (pc < PROGRAM_START + code.size());
        endfunction

        function mcu_instr at(int pc);
            return code[pc - PROGRAM_START];
        endfunction
    endclass


    // Short builders for directed programs
    function automatic mcu_instr movi(int rd, bit [15:0] v);
        return mcu_instr::make(OP_MOVI, rd, 0, 0, v);
    endfunction
    function automatic mcu_instr outp(int rs, bit [10:0] port);
        return mcu_instr::make(OP_OUT, 0, rs, 0, 0, port);
    endfunction
    function automatic mcu_instr inp(int rd, bit [10:0] port);
        return mcu_instr::make(OP_IN, rd, 0, 0, 0, port);
    endfunction
    function automatic mcu_instr inc(int r);
        return mcu_instr::make(OP_INC, r, r);
    endfunction
    function automatic mcu_instr jmp(int address);
        return mcu_instr::make(OP_JMP, 0, 0, 0, 0, address);
    endfunction
    function automatic mcu_instr push(int rs);
        return mcu_instr::make(OP_PUSH, 0, rs);
    endfunction
    function automatic mcu_instr op0(bit [5:0] op);
        return mcu_instr::make(op);
    endfunction


    // ------------------------------------------------------------------------
    // 2c. EVENT: one write seen on the DUT (monitor) or predicted (model)
    // ------------------------------------------------------------------------
    typedef enum int { EV_REG, EV_FLAGS, EV_RAM, EV_PORT } ev_kind_t;

    class mcu_event;
        ev_kind_t  kind;
        int        where;        // register no. / RAM address / port no.
        bit [15:0] data;         // value (for EV_FLAGS: {V,C,N,Z})
        int        pc;           // only known for predicted events
        string     src;          // instruction text (predicted events)

        function new(ev_kind_t kind, int where, bit [15:0] data,
                     int pc = -1, string src = "");
            this.kind = kind; this.where = where; this.data = data;
            this.pc = pc; this.src = src;
        endfunction

        function string str();
            case (kind)
                EV_REG:   return $sformatf("R%0d <- %h", where, data);
                EV_FLAGS: return $sformatf("VCNZ <- %b", data[3:0]);
                EV_RAM:   return $sformatf("RAM[%0d] <- %h", where, data);
                EV_PORT:  return $sformatf("PORT[%0d] <- %h", where, data);
            endcase
            return "?";
        endfunction

        static function mcu_event mk(ev_kind_t kind, int where, bit [15:0] data,
                                     int pc = -1, string src = "");
            mcu_event e = new(kind, where, data, pc, src);
            return e;
        endfunction

        function bit same(mcu_event o);
            return (kind == o.kind) && (where == o.where) && (data === o.data);
        endfunction
    endclass


    // ------------------------------------------------------------------------
    // 2d. GENERATOR: directed + constrained-random programs
    // ------------------------------------------------------------------------
    class mcu_generator;
        mailbox #(mcu_program) gen2drv;
        int n_random = 50;
        int body_min = 30;
        int body_max = 80;
        int n_total;

        function new(mailbox #(mcu_program) gen2drv);
            this.gen2drv = gen2drv;
        endfunction

        // random 16-bit value, corner values more likely
        function bit [15:0] rand_value();
            case ($urandom_range(0, 9))
                0: return 16'h0000;
                1: return 16'h0001;
                2: return 16'h7FFF;
                3: return 16'h8000;
                4: return 16'hFFFF;
                default: return $urandom;
            endcase
        endfunction

        task run();
            n_total = 3 + n_random;
            gen2drv.put(directed_loop_call());
            gen2drv.put(directed_corners());
            gen2drv.put(directed_stack());
            for (int i = 0; i < n_random; i++)
                gen2drv.put(random_program(i));
        endtask

        // Loop with a backward branch, CALL/RET, OUT, PUSH/POP, STORE/LOAD
        function mcu_program directed_loop_call();
            mcu_program p = new("directed_loop_call");
            int loop_pc, call_idx, sub_pc;
            p.sws = 16'h0000;
            void'(p.add(mcu_instr::make(OP_MOVI, 1, 0, 0, 16'd5)));     // counter
            void'(p.add(mcu_instr::make(OP_MOVI, 2, 0, 0, 16'd0)));     // sum
            void'(p.add(mcu_instr::make(OP_MOVI, 3, 0, 0, 16'd1)));
            void'(p.add(mcu_instr::make(OP_MOVI, 8, 0, 0, 16'd0)));
            loop_pc = p.add(mcu_instr::make(OP_ADD, 2, 2, 1));          // sum += counter
            void'(p.add(mcu_instr::make(OP_SUB, 1, 1, 3)));             // counter--
            void'(p.add(mcu_instr::make(OP_JNZ, 0, 0, 0, 0, loop_pc)));
            call_idx = p.code.size();
            void'(p.add(mcu_instr::make(OP_CALL)));                     // target patched below
            void'(p.add(mcu_instr::make(OP_OUT, 0, 2, 0, 0, PORT_LED)));
            void'(p.add(mcu_instr::make(OP_STORE, 0, 2, 0, 0, 3)));
            void'(p.add(mcu_instr::make(OP_LOAD, 10, 0, 0, 0, 3)));
            void'(p.add(mcu_instr::make(OP_PUSH, 0, 8)));
            void'(p.add(mcu_instr::make(OP_PUSH, 0, 2)));
            void'(p.add(mcu_instr::make(OP_POP, 11)));
            void'(p.add(mcu_instr::make(OP_POP, 12)));
            void'(p.add(mcu_instr::make(OP_STOP)));
            sub_pc = p.add(mcu_instr::make(OP_MOVI, 8, 0, 0, 16'h0011));
            void'(p.add(mcu_instr::make(OP_INC, 8, 8)));
            void'(p.add(mcu_instr::make(OP_RET)));
            p.code[call_idx].addr = sub_pc;
            return p;
        endfunction

        // Flag corner cases (expected values come from the model)
        function mcu_program directed_corners();
            mcu_program p = new("directed_corners");
            bit [15:0] vals[6] = '{16'h0000, 16'h0001, 16'h7FFF,
                                   16'h8000, 16'hFFFF, 16'h000F};
            bit [5:0]  ops[8]  = '{OP_ADD, OP_SUB, OP_AND, OP_OR,
                                   OP_XOR, OP_SHL, OP_SHR, OP_CMP};
            p.sws = 16'hA5C3;
            foreach (vals[i])
                void'(p.add(mcu_instr::make(OP_MOVI, i, 0, 0, vals[i])));
            // every 2-operand op on every pair of corner values
            foreach (ops[k])
                foreach (vals[a])
                    foreach (vals[b]) begin
                        mcu_instr t = mcu_instr::make(ops[k], 10, a, b);
                        t.canonicalize();
                        void'(p.add(t));
                    end
            // 1-operand ops on every corner value
            foreach (vals[a]) begin
                void'(p.add(mcu_instr::make(OP_NOT, 11, a)));
                void'(p.add(mcu_instr::make(OP_NEG, 11, a)));
                void'(p.add(mcu_instr::make(OP_INC, 11, a)));
                void'(p.add(mcu_instr::make(OP_DEC, 11, a)));
                void'(p.add(mcu_instr::make(OP_ADDI, 12, a, 0, 16'h8000)));
                void'(p.add(mcu_instr::make(OP_SUBI, 12, a, 0, 16'h0001)));
            end
            void'(p.add(mcu_instr::make(OP_IN, 13, 0, 0, 0, PORT_SW)));
            void'(p.add(mcu_instr::make(OP_OUT, 0, 13, 0, 0, PORT_LED)));
            void'(p.add(mcu_instr::make(OP_STOP)));
            return p;
        endfunction

        // 70 pushes: SP must stop at 0xBF, then 3 pops
        function mcu_program directed_stack();
            mcu_program p = new("directed_stack_overflow");
            p.sws = 16'h0000;
            void'(p.add(mcu_instr::make(OP_MOVI, 1, 0, 0, 16'd1)));
            repeat (70) begin
                void'(p.add(mcu_instr::make(OP_PUSH, 0, 1)));
                void'(p.add(mcu_instr::make(OP_INC, 1, 1)));
            end
            void'(p.add(mcu_instr::make(OP_POP, 2)));
            void'(p.add(mcu_instr::make(OP_POP, 3)));
            void'(p.add(mcu_instr::make(OP_POP, 4)));
            void'(p.add(mcu_instr::make(OP_STOP)));
            return p;
        endfunction

        // Prologue (defined start state) + random body + STOP
        function mcu_program random_program(int idx);
            mcu_program p = new($sformatf("random_%0d", idx));
            int body_len, stop_pc, target;
            p.sws = rand_value();

            // registers have no reset value: give R0..R15 a value first
            for (int r = 0; r < 16; r++)
                void'(p.add(mcu_instr::make(OP_MOVI, r, 0, 0, rand_value())));

            // RAM 0..7 is the data area. RAM[0] is also what POP reads on an
            // empty stack (SP+1 wraps from 0xFF to 0x00).
            for (int a = 0; a < 8; a++)
                void'(p.add(mcu_instr::make(OP_STORE, 0, a, 0, 0, a)));

            body_len = $urandom_range(body_min, body_max);
            repeat (body_len) begin
                mcu_instr t = new();
                if (!t.randomize())
                    $fatal(1, "randomize() failed");
                t.canonicalize();
                void'(p.add(t));
            end
            stop_pc = p.add(mcu_instr::make(OP_STOP));

            // jumps only go forward (no endless loops): target = pc+1+skip
            foreach (p.code[k])
                if (p.code[k].is_jump()) begin
                    target = p.code[k].pc + 1 + p.code[k].skip;
                    if (target > stop_pc) target = stop_pc;
                    p.code[k].addr = target;
                end
            return p;
        endfunction
    endclass


    // ------------------------------------------------------------------------
    // 2e. DRIVER: load program into flash, run until STOP
    // ------------------------------------------------------------------------
    class mcu_driver;
        virtual mcu_if         vif;
        mailbox #(mcu_program) gen2drv;
        mailbox #(mcu_program) drv2scb;
        int timeout = 5000;      // cycles

        function new(virtual mcu_if vif,
                     mailbox #(mcu_program) gen2drv,
                     mailbox #(mcu_program) drv2scb);
            this.vif = vif; this.gen2drv = gen2drv; this.drv2scb = drv2scb;
        endfunction

        task run();
            mcu_program p;
            forever begin
                gen2drv.get(p);
                load(p);
                execute(p);
                drv2scb.put(p);
            end
        endtask

        // Hold CPU in reset and write every instruction into flash
        task load(mcu_program p);
            mcu_instr all[$];
            vif.rst_n       = 1'b0;
            vif.cpu_en      = 1'b0;
            vif.flash_rd_en = 1'b0;
            vif.flash_wr_en = 1'b0;
            vif.sws         = p.sws;
            repeat (3) @(posedge vif.clk);
            #1;
            all = {p.extra, p.code};
            foreach (all[k]) begin
                vif.flash_wr_addr = all[k].pc;
                vif.flash_wr_data = all[k].encode();
                vif.flash_wr_en   = 1'b1;
                @(posedge vif.clk); #1;
                vif.flash_wr_en   = 1'b0;
                @(posedge vif.clk); #1;
            end
        endtask

        // Same start sequence as on the board: read enable, CPU enable, reset off
        task start();
            vif.flash_rd_en = 1'b1;
            repeat (2) @(posedge vif.clk);
            vif.cpu_en = 1'b1;
            repeat (2) @(posedge vif.clk);
            vif.rst_n = 1'b1;
        endtask

        task execute(mcu_program p);
            start();
            wait_stop(p);
        endtask

        task wait_stop(mcu_program p);
            p.timed_out = 1'b1;
            p.cycles    = 0;
            while (p.cycles < timeout) begin
                @(posedge vif.clk); #1;
                p.cycles++;
                if (vif.state == ST_STOP) begin
                    p.timed_out = 1'b0;
                    break;
                end
            end
            repeat (2) @(posedge vif.clk);   // let the monitor see the last writes
            #1;
        endtask

        task wait_cycles(int n);
            repeat (n) @(posedge vif.clk);
            #1;
        endtask

        // Button press: optional contact bounce, clean press of 'hold' cycles
        task press_button(int idx, bit with_bounce, int hold);
            if (with_bounce) begin
                repeat (3) begin
                    vif.btn[idx] = 1'b1;  repeat (5) @(posedge vif.clk);
                    vif.btn[idx] = 1'b0;  repeat (4) @(posedge vif.clk);
                end
            end
            vif.btn[idx] = 1'b1;
            repeat (hold) @(posedge vif.clk);
            vif.btn[idx] = 1'b0;
            repeat (40) @(posedge vif.clk);
            #1;
        endtask

        // 1: the real Reset_unit drives rst_n (power-on, button, watchdog)
        // 0: the testbench drives rst_n again
        task real_reset(bit on);
            vif.use_real_reset = on;
            #0;
        endtask
    endclass


    // ------------------------------------------------------------------------
    // 2f. MONITOR: turn DUT activity into events
    // Signals are sampled at the falling edge: the writes seen there are
    // committed at the next rising edge.
    // ------------------------------------------------------------------------
    class mcu_monitor;
        virtual mcu_if       vif;
        mailbox #(mcu_event) mon2scb;
        bit                  active = 1;   // 0 during the peripheral phase

        function new(virtual mcu_if vif, mailbox #(mcu_event) mon2scb);
            this.vif = vif; this.mon2scb = mon2scb;
        endfunction

        task run();
            forever begin
                @(negedge vif.clk);
                if (active && vif.rst_n === 1'b1 && vif.cpu_en === 1'b1) begin
                    if (vif.rf_we === 1'b1)
                        mon2scb.put(mcu_event::mk(EV_REG, vif.rf_waddr, vif.rf_wdata));
                    if (vif.sr_we === 1'b1)
                        mon2scb.put(mcu_event::mk(EV_FLAGS, 0, {12'd0, vif.alu_flags}));
                    if (vif.ram_we === 1'b1)
                        mon2scb.put(mcu_event::mk(EV_RAM, vif.ram_addr, vif.ram_wdata));
                    if (vif.port_en === 1'b1 && vif.rf_we !== 1'b1)   // OUT (IN also writes a register)
                        mon2scb.put(mcu_event::mk(EV_PORT, vif.port_addr, vif.port_wdata));
                end
            end
        endtask
    endclass


    // ------------------------------------------------------------------------
    // 2g. REFERENCE MODEL: the instruction set in software
    // Produces the same event list the monitor should see.
    // ------------------------------------------------------------------------
    class mcu_model;
        bit [15:0] R[32];
        bit [3:0]  flags;        // {V, C, N, Z}
        bit [7:0]  sp;
        bit [15:0] ram[256];
        int        max_steps = 20000;

        // ALU, same rules as ALU.sv
        function void alu(bit [5:0] op, bit [15:0] a, bit [15:0] b, bit [15:0] imm,
                          output bit [15:0] res, output bit c, output bit v);
            bit [16:0] ext;
            bit [3:0]  s;
            s = b[3:0];
            res = 0; c = 0; v = 0;
            case (op)
                OP_NOT: res = ~a;
                OP_AND: res = a & b;
                OP_OR:  res = a | b;
                OP_XOR: res = a ^ b;
                OP_ADD: begin
                    ext = {1'b0, a} + {1'b0, b};
                    res = ext[15:0]; c = ext[16];
                    v = ~(a[15] ^ b[15]) & (res[15] ^ a[15]);
                end
                OP_SUB, OP_CMP: begin
                    res = a - b; c = (a >= b);
                    v = (a[15] ^ b[15]) & (res[15] ^ a[15]);
                end
                OP_NEG: begin
                    res = ~a + 16'd1; v = (a == 16'h8000);
                end
                OP_SHL: begin
                    res = a << s;
                    if (s != 0) c = a[16 - s];
                end
                OP_SHR: begin
                    res = a >> s;
                    if (s != 0) c = a[s - 1];
                end
                OP_ADDI: begin
                    ext = {1'b0, a} + {1'b0, imm};
                    res = ext[15:0]; c = ext[16];
                    v = ~(a[15] ^ imm[15]) & (res[15] ^ a[15]);
                end
                OP_SUBI: begin
                    res = a - imm; c = (a >= imm);
                    v = (a[15] ^ imm[15]) & (res[15] ^ a[15]);
                end
                OP_INC: begin
                    ext = {1'b0, a} + 17'd1;
                    res = ext[15:0]; c = ext[16];
                    v = (a == 16'h7FFF);
                end
                OP_DEC: begin
                    res = a - 16'd1; c = (a >= 16'd1);
                    v = (a == 16'h8000);
                end
            endcase
        endfunction

        function bit taken(bit [5:0] op);
            bit z, n, c, v;
            {v, c, n, z} = flags;
            case (op)
                OP_JMP: return 1;
                OP_JZ:  return z;
                OP_JNZ: return !z;
                OP_JC:  return c;
                OP_JNC: return !c;
                OP_JN:  return n;
                OP_JP:  return !n && !z;
                OP_JLE: return z || (n ^ v);
                OP_JGE: return !(n ^ v);
            endcase
            return 0;
        endfunction

        // Run the program; return 0 if it did not reach STOP
        function bit execute(mcu_program p, ref mcu_event exp[$]);
            int pc, steps;
            mcu_instr i;
            bit [15:0] res;
            bit c, v;
            string s;

            flags = 4'b0000;            // status register reset value
            sp    = 8'hFF;              // stack pointer reset value
            pc    = PROGRAM_START;

            for (steps = 0; steps < max_steps; steps++) begin
                if (!p.has(pc)) begin
                    $display("    MODEL: PC=%0d is outside the program", pc);
                    return 0;
                end
                i = p.at(pc);
                s = i.text();

                case (i.op)
                    OP_ADD, OP_SUB, OP_AND, OP_OR, OP_XOR, OP_SHL, OP_SHR,
                    OP_NOT, OP_NEG, OP_INC, OP_DEC, OP_ADDI, OP_SUBI: begin
                        alu(i.op, R[i.rs1], R[i.rs2], i.imm, res, c, v);
                        R[i.rd] = res;
                        flags   = {v, c, res[15], (res == 0)};
                        exp.push_back(mcu_event::mk(EV_REG, i.rd, res, pc, s));
                        exp.push_back(mcu_event::mk(EV_FLAGS, 0, {12'd0, flags}, pc, s));
                        pc++;
                    end
                    OP_CMP: begin
                        alu(i.op, R[i.rs1], R[i.rs2], i.imm, res, c, v);
                        flags = {v, c, res[15], (res == 0)};
                        exp.push_back(mcu_event::mk(EV_FLAGS, 0, {12'd0, flags}, pc, s));
                        pc++;
                    end
                    OP_MOV: begin                     // no flag update
                        R[i.rd] = R[i.rs1];
                        exp.push_back(mcu_event::mk(EV_REG, i.rd, R[i.rd], pc, s));
                        pc++;
                    end
                    OP_MOVI, OP_SET, OP_CLR: begin   // Rd = Immediate field
                        R[i.rd] = i.imm;
                        exp.push_back(mcu_event::mk(EV_REG, i.rd, R[i.rd], pc, s));
                        pc++;
                    end
                    OP_LOAD: begin
                        R[i.rd] = ram[i.addr[7:0]];
                        exp.push_back(mcu_event::mk(EV_REG, i.rd, R[i.rd], pc, s));
                        pc++;
                    end
                    OP_STORE: begin
                        ram[i.addr[7:0]] = R[i.rs1];
                        exp.push_back(mcu_event::mk(EV_RAM, i.addr[7:0], R[i.rs1], pc, s));
                        pc++;
                    end
                    OP_IN: begin                      // only the switch port is used
                        R[i.rd] = p.sws;
                        exp.push_back(mcu_event::mk(EV_REG, i.rd, R[i.rd], pc, s));
                        pc++;
                    end
                    OP_OUT: begin
                        exp.push_back(mcu_event::mk(EV_PORT, i.addr, R[i.rs1], pc, s));
                        pc++;
                    end
                    OP_PUSH: begin                    // write at SP, SP stops at 0xBF
                        ram[sp] = R[i.rs1];
                        exp.push_back(mcu_event::mk(EV_RAM, sp, R[i.rs1], pc, s));
                        if (sp != 8'hBF) sp--;
                        pc++;
                    end
                    OP_POP: begin                     // read SP+1, SP stops at 0xFF
                        R[i.rd] = ram[8'(sp + 8'd1)];
                        exp.push_back(mcu_event::mk(EV_REG, i.rd, R[i.rd], pc, s));
                        if (sp != 8'hFF) sp++;
                        pc++;
                    end
                    OP_CALL: begin                    // push return address
                        ram[sp] = pc + 1;
                        exp.push_back(mcu_event::mk(EV_RAM, sp, pc + 1, pc, s));
                        if (sp != 8'hBF) sp--;
                        pc = i.addr;
                    end
                    OP_RET: begin
                        res = ram[8'(sp + 8'd1)];
                        if (sp != 8'hFF) sp++;
                        pc = res[10:0];
                    end
                    OP_JMP, OP_JZ, OP_JNZ, OP_JC, OP_JNC,
                    OP_JN, OP_JP, OP_JLE, OP_JGE: begin
                        if (taken(i.op)) pc = i.addr;
                        else             pc++;
                    end
                    OP_NOP: pc++;
                    OP_STOP: return 1;
                    default: begin
                        $display("    MODEL: unsupported opcode %b at PC=%0d", i.op, pc);
                        return 0;
                    end
                endcase
            end
            $display("    MODEL: no STOP after %0d steps", max_steps);
            return 0;
        endfunction
    endclass


    // ------------------------------------------------------------------------
    // 2h. SCOREBOARD: expected (model) vs. actual (monitor)
    // ------------------------------------------------------------------------
    class mcu_scoreboard;
        mailbox #(mcu_program) drv2scb;
        mailbox #(mcu_event)   mon2scb;
        mcu_model              model;
        bit                    verbose;

        int programs_done, programs_failed;
        int n_random_programs, n_directed_programs;
        int checked[4];          // per ev_kind_t
        int mismatched[4];
        int missing, extra, timeouts, model_errors;

        function new(mailbox #(mcu_program) drv2scb, mailbox #(mcu_event) mon2scb);
            this.drv2scb = drv2scb; this.mon2scb = mon2scb;
            model = new();
        endfunction

        task run();
            mcu_program p;
            forever begin
                drv2scb.get(p);
                check_program(p);
            end
        endtask

        function void check_program(mcu_program p);
            mcu_event exp[$], got[$], e;
            int errs, shown, n;

            while (mon2scb.try_get(e)) got.push_back(e);   // everything seen for p

            errs = 0; shown = 0;
            if (p.name.substr(0, 5) == "random") n_random_programs++;
            else                                 n_directed_programs++;

            if (p.timed_out) begin
                $display("    TIMEOUT   %s : no STOP within %0d cycles", p.name, p.cycles);
                timeouts++; errs++;
            end

            if (!model.execute(p, exp)) begin
                model_errors++; errs++;
            end

            n = (exp.size() > got.size()) ? exp.size() : got.size();
            for (int k = 0; k < n; k++) begin
                if (k >= got.size()) begin
                    missing++; errs++;
                    if (shown++ < 5)
                        $display("    MISSING   %s  PC=%0d  %s expected %s",
                                 p.name, exp[k].pc, pad(exp[k].src, 22), exp[k].str());
                end
                else if (k >= exp.size()) begin
                    extra++; errs++;
                    if (shown++ < 5)
                        $display("    EXTRA     %s  unexpected %s", p.name, got[k].str());
                end
                else begin
                    checked[exp[k].kind]++;
                    if (!exp[k].same(got[k])) begin
                        mismatched[exp[k].kind]++; errs++;
                        if (shown++ < 5)
                            $display("    MISMATCH  %s  PC=%0d  %s expected %s, got %s",
                                     p.name, exp[k].pc, pad(exp[k].src, 22),
                                     exp[k].str(), got[k].str());
                    end
                    else if (verbose)
                        $display("      ok  PC=%0d  %s %s", exp[k].pc, pad(exp[k].src, 22), exp[k].str());
                end
            end
            if (shown > 5)
                $display("    ... %0d more error(s) in %s", shown - 5, p.name);

            programs_done++;
            if (errs != 0) programs_failed++;
            $display("  %s %s %s instr  %s cycles  %s events  %s",
                     pad($sformatf("%0d", programs_done), 3), pad(p.name, 24),
                     pad($sformatf("%0d", p.code.size()), 4),
                     pad($sformatf("%0d", p.cycles), 5),
                     pad($sformatf("%0d", exp.size()), 5),
                     (errs == 0) ? "PASS" : "FAIL");
        endfunction

        function int total_errors();
            return mismatched[EV_REG] + mismatched[EV_FLAGS] + mismatched[EV_RAM] +
                   mismatched[EV_PORT] + missing + extra + timeouts + model_errors;
        endfunction

        function void report();
            $display(" CPU CORE (reference model + scoreboard)");
            $display(" Programs run        : %0d   (directed %0d, random %0d), %0d failed",
                     programs_done, n_directed_programs, n_random_programs, programs_failed);
            $display(" Register writes     : %0d checked, %0d mismatch", checked[EV_REG],   mismatched[EV_REG]);
            $display(" Flag updates        : %0d checked, %0d mismatch", checked[EV_FLAGS], mismatched[EV_FLAGS]);
            $display(" RAM writes          : %0d checked, %0d mismatch", checked[EV_RAM],   mismatched[EV_RAM]);
            $display(" Port writes         : %0d checked, %0d mismatch", checked[EV_PORT],  mismatched[EV_PORT]);
            $display(" Missing / extra     : %0d / %0d", missing, extra);
            $display(" Timeouts            : %0d", timeouts);
        endfunction
    endclass


    // ------------------------------------------------------------------------
    // 2i. PERIPHERAL MONITOR: counts what happens outside the CPU core
    // Sampled 1 ns after every rising edge.
    // ------------------------------------------------------------------------
    class mcu_periph_monitor;
        virtual mcu_if vif;

        int         isr_entries;   // times the controller entered INTERRUPT
        logic [9:0] irq_order[$];  // irq_id of every interrupt, in service order
        int         min_sp;        // lowest SP seen
        int         wd_pulses;     // watchdog reset pulses
        int         rst_falls;     // rst_n 1 -> 0 transitions
        int         led_writes;    // OUT instructions to the LED port
        int         btn_pulses;    // debounced pulses of button U
        int         pwm_window;    // cycles left in the PWM measurement
        int         pwm_high;      // cycles with pwm_pin = 1 in the window
        int         irq_depth;     // ISRs currently open (INTERRUPT +1, RETI -1)
        int         max_depth;     // deepest nesting seen
        logic       prev_rst_n;

        function new(virtual mcu_if vif);
            this.vif = vif;
            min_sp = 255;
        endfunction

        task run();
            forever begin
                @(posedge vif.clk);
                #1;
                if (vif.dut_rst_n === 1'b1 && vif.cpu_en === 1'b1) begin
                    if (vif.state == ST_INTERRUPT) begin
                        isr_entries++;
                        irq_order.push_back(vif.irq_id);
                        irq_depth++;
                        if (irq_depth > max_depth) max_depth = irq_depth;
                    end
                    if (vif.state == ST_RETI && irq_depth > 0)
                        irq_depth--;
                    if (vif.sp < min_sp)
                        min_sp = vif.sp;
                end

                if (vif.wd_reset === 1'b1)
                    wd_pulses++;

                if (prev_rst_n === 1'b1 && vif.dut_rst_n === 1'b0)
                    rst_falls++;
                prev_rst_n = vif.dut_rst_n;

                if (vif.dut_rst_n === 1'b1 && vif.port_en === 1'b1 && vif.port_addr == PORT_LED)
                    led_writes++;

                if (vif.btn_db0 === 1'b1)
                    btn_pulses++;

                if (pwm_window > 0) begin
                    if (vif.pwm === 1'b1) pwm_high++;
                    pwm_window--;
                end
            end
        endtask
    endclass


    // ------------------------------------------------------------------------
    // 2j. PERIPHERAL SCOREBOARD: values and ranges of each scenario
    // ------------------------------------------------------------------------
    class mcu_periph_scoreboard;
        int    scenarios, scenarios_failed;
        int    checks, errors;
        int    sc_errors;
        string sc_name;

        function void begin_scenario(string name);
            sc_name   = name;
            sc_errors = 0;
            scenarios++;
            $display("");
            $display("  -- SCENARIO %0d: %s", scenarios, name);
        endfunction

        function void end_scenario();
            if (sc_errors == 0)
                $display("     RESULT: PASS");
            else begin
                $display("     RESULT: FAIL (%0d error(s))", sc_errors);
                scenarios_failed++;
            end
        endfunction

        function void fail(string what);
            checks++; errors++; sc_errors++;
            $display("     FAIL  %s", what);
        endfunction

        function void check(string what, logic [15:0] actual, logic [15:0] expected);
            checks++;
            if (actual !== expected) begin
                errors++; sc_errors++;
                $display("     FAIL  %s : got %h, expected %h", what, actual, expected);
            end
            else
                $display("     pass  %s = %h", what, actual);
        endfunction

        function void check_range(string what, int actual, int lo, int hi);
            checks++;
            if (actual < lo || actual > hi) begin
                errors++; sc_errors++;
                $display("     FAIL  %s : got %0d, expected %0d..%0d", what, actual, lo, hi);
            end
            else
                $display("     pass  %s = %0d (expected %0d..%0d)", what, actual, lo, hi);
        endfunction

        function void report();
            $display(" PERIPHERALS (directed scenarios)");
            $display(" Scenarios           : %0d run, %0d failed", scenarios, scenarios_failed);
            $display(" Checks              : %0d, %0d failed", checks, errors);
        endfunction
    endclass


    // ------------------------------------------------------------------------
    // 2k. PERIPHERAL SCENARIOS (the "test" layer for the peripherals)
    // Each scenario: build a program, run it, drive stimulus, check results.
    // ------------------------------------------------------------------------
    class mcu_periph_test;
        virtual mcu_if        vif;
        mcu_driver            drv;
        mcu_periph_monitor    pm;
        mcu_periph_scoreboard ps;

        function new(virtual mcu_if vif, mcu_driver drv,
                     mcu_periph_monitor pm, mcu_periph_scoreboard ps);
            this.vif = vif; this.drv = drv; this.pm = pm; this.ps = ps;
        endfunction

        function logic [15:0] R(int n);
            return vif.regs[n];
        endfunction

        function logic [15:0] SP();
            return {8'h00, vif.sp};
        endfunction

        // load + run until STOP
        task run_program(mcu_program p);
            drv.load(p);
            drv.execute(p);
            if (p.timed_out)
                ps.fail($sformatf("%s : no STOP within %0d cycles", p.name, p.cycles));
        endtask

        task run_all();
            test_io();
            test_pins();
            test_seven_segment();
            test_timer_read();
            test_timer_irq();
            test_irq_disabled();
            test_irq_priority();
            test_pwm();
            test_watchdog();
            test_resets();
            test_buttons();
            test_button_irqs();
            test_nested_irq();
            test_timers_3_4();
            test_stack();
        endtask

        // ---- LED and switches ------------------------------------------------
        task test_io();
            mcu_program p = new("io");
            ps.begin_scenario("I/O (LED OUT, SWITCH IN)");
            p.sws = 16'h5A3C;
            void'(p.add(movi(1, 16'h00F0)));
            void'(p.add(outp(1, PORT_LED)));
            void'(p.add(inp (2, PORT_SW)));
            void'(p.add(op0 (OP_STOP)));
            run_program(p);
            ps.check("LED pins (led_out)", vif.led, 16'h00F0);
            ps.check("IN switches R2    ", R(2),    16'h5A3C);
            ps.end_scenario();
        endtask

        // ---- GPIO pins -------------------------------------------------------
        // dir bit 1 = output, 0 = input
        task pin_case(string name, logic [15:0] dir, logic [15:0] out_val,
                      logic [15:0] ext_val, bit tb_drives, bit check_read);
            mcu_program  p = new("pins");
            logic [15:0] drive, exp_pins, exp_read;

            for (int i = 0; i < 16; i++) begin
                if (dir[i]) begin
                    drive[i]    = 1'bz;
                    exp_pins[i] = out_val[i];
                    exp_read[i] = 1'b0;
                end
                else begin
                    drive[i]    = tb_drives ? ext_val[i] : 1'bz;
                    exp_pins[i] = tb_drives ? ext_val[i] : 1'bz;
                    exp_read[i] = ext_val[i];
                end
            end

            vif.pins_drive = drive;
            void'(p.add(movi(1, dir)));
            void'(p.add(outp(1, PORT_PINS_DIR)));
            void'(p.add(movi(1, out_val)));
            void'(p.add(outp(1, PORT_PINS_OUT)));
            if (check_read) begin                 // floating inputs are not read (X)
                void'(p.add(movi(2, 16'hDEAD)));
                void'(p.add(inp (2, PORT_PINS_IN)));
            end
            void'(p.add(op0(OP_STOP)));
            run_program(p);

            ps.check({name, " pins "}, vif.pins_val, exp_pins);
            if (check_read)
                ps.check({name, " IN R2"}, R(2), exp_read);
            vif.pins_drive = 16'hzzzz;
        endtask

        task test_pins();
            ps.begin_scenario("GPIO PINS (MIXED IN/OUT, HIGH/LOW)");
            //        name                     dir       out       ext       drive check_read
            pin_case("low 8 out, high 8 in ", 16'h00FF, 16'h00A5, 16'h3C00, 1'b1, 1'b1);
            pin_case("even out (high)      ", 16'h5555, 16'hFFFF, 16'hFFFF, 1'b1, 1'b1);
            pin_case("even out (low)       ", 16'h5555, 16'h0000, 16'hAAAA, 1'b1, 1'b1);
            pin_case("nibble mix           ", 16'hF0F0, 16'h3030, 16'h0505, 1'b1, 1'b1);
            pin_case("all out              ", 16'hFFFF, 16'h1234, 16'h0000, 1'b1, 1'b1);
            pin_case("all in (out reg FFFF)", 16'h0000, 16'hFFFF, 16'hABCD, 1'b1, 1'b1);
            pin_case("inputs left floating ", 16'h00FF, 16'h00FF, 16'h0000, 1'b0, 1'b0);
            ps.end_scenario();
        endtask

        // ---- BCD converters and 7-segment --------------------------------------
        task test_seven_segment();
            mcu_program p = new("seven_segment");
            ps.begin_scenario("BCD CONVERTERS AND SEVEN SEGMENT");
            void'(p.add(movi(1, 16'd1234)));
            void'(p.add(outp(1, PORT_BIN2BCD_IN)));
            void'(p.add(inp (2, PORT_BIN2BCD_OUT)));
            void'(p.add(movi(3, 16'h1234)));
            void'(p.add(outp(3, PORT_BCD2SEG_IN)));
            void'(p.add(inp (4, PORT_BCD2SEG_D0)));
            void'(p.add(inp (5, PORT_BCD2SEG_D1)));
            void'(p.add(inp (6, PORT_BCD2SEG_D2)));
            void'(p.add(inp (7, PORT_BCD2SEG_D3)));
            void'(p.add(movi(8, 16'h00FE)));
            void'(p.add(outp(8, PORT_7SEG_DIGITS)));
            void'(p.add(movi(9, 16'h0019)));
            void'(p.add(outp(9, PORT_7SEG_SEGS)));
            void'(p.add(op0 (OP_STOP)));
            run_program(p);
            ps.check("BIN->BCD 1234      ", R(2), 16'h1234);
            ps.check("BCD->7SEG digit '4'", R(4), 16'h0019);
            ps.check("BCD->7SEG digit '3'", R(5), 16'h0030);
            ps.check("BCD->7SEG digit '2'", R(6), 16'h0024);
            ps.check("BCD->7SEG digit '1'", R(7), 16'h0079);
            ps.check("anode output       ", {8'h00, vif.anode}, 16'h00FE);
            ps.check("segment output     ", {9'h000, vif.seg},  16'h0019);
            ps.check("dp output          ", {15'h0000, vif.dp}, 16'h0000);
            ps.end_scenario();
        endtask

        // ---- Timer count / read / clear ----------------------------------------
        task test_timer_read();
            mcu_program p = new("timer_read");
            ps.begin_scenario("TIMER COUNT / READ / CLEAR");
            void'(p.add(movi(1, 16'd1)));
            void'(p.add(outp(1, PORT_T1_PRESC)));       // prescaler 1
            void'(p.add(movi(1, 16'd1000)));
            void'(p.add(outp(1, PORT_T1_MAX)));
            void'(p.add(outp(1, PORT_T1_EN)));
            repeat (10) void'(p.add(op0(OP_NOP)));
            void'(p.add(inp (2, PORT_T1_READ)));
            void'(p.add(outp(1, PORT_T1_CLEAR)));
            void'(p.add(inp (3, PORT_T1_READ)));
            void'(p.add(op0 (OP_STOP)));
            run_program(p);
            ps.check_range("timer value after ~10 cycles", R(2), 7, 13);
            ps.check_range("timer value after clear     ", R(3), 0, 2);
            ps.end_scenario();
        endtask

        // ---- Timer0 interrupt ----------------------------------------------------
        // vector 9 -> ISR at 200: R10++, RETI.  Timer0: prescaler 4, max 5.
        function void add_timer0_irq(mcu_program p);
            p.place(9,   jmp(200));
            p.place(200, inc(10));
            p.place(201, op0(OP_RETI));
            void'(p.add(movi(10, 16'd0)));
            void'(p.add(movi(1,  16'd4)));
            void'(p.add(outp(1,  PORT_T0_PRESC)));
            void'(p.add(movi(1,  16'd5)));
            void'(p.add(outp(1,  PORT_T0_MAX)));
            void'(p.add(movi(1,  16'h0001)));
            void'(p.add(outp(1,  PORT_IRQ_MASK)));      // only timer0
            void'(p.add(outp(1,  PORT_T0_IRQ_EN)));
            void'(p.add(outp(1,  PORT_T0_EN)));
        endfunction

        task test_timer_irq();
            mcu_program p = new("timer0_irq");
            ps.begin_scenario("TIMER0 INTERRUPT (ISR + RETI)");
            add_timer0_irq(p);
            void'(p.add(op0(OP_EI)));
            repeat (120) void'(p.add(op0(OP_NOP)));
            void'(p.add(op0(OP_DI)));
            void'(p.add(op0(OP_NOP)));
            void'(p.add(op0(OP_NOP)));
            void'(p.add(op0(OP_STOP)));
            drv.load(p);
            pm.isr_entries = 0;
            drv.execute(p);
            if (p.timed_out) ps.fail("no STOP");
            ps.check_range("interrupts taken     ", pm.isr_entries, 10, 30);
            ps.check      ("R10 == interrupts    ", R(10), 16'(pm.isr_entries));
            ps.check      ("SP after all RETI    ", SP(), 16'h00FF);
            ps.check      ("irq_active after STOP", {15'h0000, vif.irq_active}, 16'h0000);
            ps.end_scenario();
        endtask

        // ---- EI immediately followed by DI: no interrupt ---------------------------
        task test_irq_disabled();
            mcu_program p = new("irq_disabled");
            ps.begin_scenario("INTERRUPTS DISABLED (DI)");
            add_timer0_irq(p);
            void'(p.add(op0(OP_EI)));
            void'(p.add(op0(OP_DI)));
            repeat (80) void'(p.add(op0(OP_NOP)));
            void'(p.add(op0(OP_STOP)));
            drv.load(p);
            pm.isr_entries = 0;
            drv.execute(p);
            if (p.timed_out) ps.fail("no STOP");
            ps.check("interrupts taken", 16'(pm.isr_entries), 16'h0000);
            ps.check("R10 (ISR count) ", R(10), 16'h0000);
            ps.end_scenario();
        endtask

        // ---- Interrupt priority: timer0 > timer1 > timer2 ------------------------
        // timer2 fires first and has a long ISR; timer1 then timer0 become pending.
        // After RETI timer0 must be served before timer1.
        task test_irq_priority();
            localparam logic [9:0] ID_T0 = 10'b1000000000;
            localparam logic [9:0] ID_T1 = 10'b0100000000;
            localparam logic [9:0] ID_T2 = 10'b0010000000;
            mcu_program p = new("irq_priority");
            int a;
            ps.begin_scenario("INTERRUPT PRIORITY (timer0 > timer1 > timer2)");

            p.place(7, jmp(300));                        // timer2
            p.place(8, jmp(420));                        // timer1
            p.place(9, jmp(400));                        // timer0
            // timer2 ISR at 300: long, so the other two become pending
            p.place(300, outp(1, PORT_T2_DIS));
            p.place(301, inc(12));
            for (a = 302; a < 362; a++) p.place(a, op0(OP_NOP));
            p.place(362, op0(OP_RETI));
            // timer0 ISR at 400
            p.place(400, outp(1, PORT_T0_DIS));
            p.place(401, inc(10));
            p.place(402, op0(OP_RETI));
            // timer1 ISR at 420
            p.place(420, outp(1, PORT_T1_DIS));
            p.place(421, inc(11));
            p.place(422, op0(OP_RETI));

            void'(p.add(movi(10, 16'd0)));
            void'(p.add(movi(11, 16'd0)));
            void'(p.add(movi(12, 16'd0)));
            void'(p.add(movi(1,  16'd10)));
            void'(p.add(outp(1,  PORT_T0_PRESC)));
            void'(p.add(outp(1,  PORT_T1_PRESC)));
            void'(p.add(outp(1,  PORT_T2_PRESC)));
            void'(p.add(movi(1,  16'd4)));
            void'(p.add(outp(1,  PORT_T0_MAX)));         // ~40 cycles
            void'(p.add(movi(1,  16'd3)));
            void'(p.add(outp(1,  PORT_T1_MAX)));         // ~30 cycles
            void'(p.add(movi(1,  16'd2)));
            void'(p.add(outp(1,  PORT_T2_MAX)));         // ~20 cycles
            void'(p.add(movi(1,  16'h0007)));
            void'(p.add(outp(1,  PORT_IRQ_MASK)));
            void'(p.add(outp(1,  PORT_T0_IRQ_EN)));
            void'(p.add(outp(1,  PORT_T1_IRQ_EN)));
            void'(p.add(outp(1,  PORT_T2_IRQ_EN)));
            void'(p.add(op0 (OP_EI)));
            void'(p.add(outp(1,  PORT_T0_EN)));
            void'(p.add(outp(1,  PORT_T1_EN)));
            void'(p.add(outp(1,  PORT_T2_EN)));
            repeat (150) void'(p.add(op0(OP_NOP)));
            void'(p.add(op0(OP_DI)));
            void'(p.add(op0(OP_STOP)));

            drv.load(p);
            pm.irq_order.delete();
            pm.isr_entries = 0;
            drv.execute(p);
            if (p.timed_out) ps.fail("no STOP");

            foreach (pm.irq_order[i])
                $display("     -- served #%0d: irq_id = %b", i + 1, pm.irq_order[i]);
            // timers are periodic, so a few extra (valid) requests are allowed;
            // the ORDER of the first three proves the priority
            ps.check_range("interrupts served", pm.irq_order.size(), 3, 6);
            if (pm.irq_order.size() >= 3) begin
                ps.check("1st served = timer2 (arrived first)  ", {6'd0, pm.irq_order[0]}, {6'd0, ID_T2});
                ps.check("2nd served = timer0 (highest priority)", {6'd0, pm.irq_order[1]}, {6'd0, ID_T0});
                ps.check("3rd served = timer1                   ", {6'd0, pm.irq_order[2]}, {6'd0, ID_T1});
            end
            ps.check_range("timer0 ISR count R10", R(10), 1, 2);
            ps.check_range("timer1 ISR count R11", R(11), 1, 2);
            ps.check_range("timer2 ISR count R12", R(12), 1, 2);
            ps.check      ("R10+R11+R12 == served", R(10) + R(11) + R(12), 16'(pm.irq_order.size()));
            ps.check      ("SP after all RETI    ", SP(), 16'h00FF);
            ps.end_scenario();
        endtask

        // ---- PWM: prescaler 0 -> period 256, high while sawtooth < duty ----------
        task pwm_case(string name, logic [15:0] duty, bit disable_after, int lo, int hi);
            mcu_program p = new("pwm");
            void'(p.add(movi(1, 16'd0)));
            void'(p.add(outp(1, PORT_PWM_PRESC)));
            void'(p.add(movi(1, duty)));
            void'(p.add(outp(1, PORT_PWM_DUTY)));
            void'(p.add(outp(1, PORT_PWM_EN)));
            if (disable_after)
                void'(p.add(outp(1, PORT_PWM_DIS)));
            void'(p.add(op0(OP_STOP)));
            run_program(p);

            pm.pwm_high   = 0;
            pm.pwm_window = 1024;                       // 4 PWM periods
            drv.wait_cycles(1030);
            ps.check_range({name, " high cycles / 1024"}, pm.pwm_high, lo, hi);
        endtask

        task test_pwm();
            ps.begin_scenario("PWM DUTY CYCLE");
            pwm_case("duty 64/256 (25%)", 16'd64,  1'b0, 254,  258);
            pwm_case("duty 255/256     ", 16'd255, 1'b0, 1016, 1024);
            pwm_case("duty 64, disabled", 16'd64,  1'b1, 0,    0);
            ps.end_scenario();
        endtask

        // ---- Watchdog: prescaler 0, max 20 ----------------------------------------
        function void add_watchdog_setup(mcu_program p);
            void'(p.add(movi(1, 16'd0)));
            void'(p.add(outp(1, PORT_WD_PRESC)));
            void'(p.add(movi(1, 16'd20)));
            void'(p.add(outp(1, PORT_WD_MAX)));
            void'(p.add(outp(1, PORT_WD_EN)));
        endfunction

        task test_watchdog();
            mcu_program p1 = new("wd_not_cleared");
            mcu_program p2 = new("wd_cleared");
            ps.begin_scenario("WATCHDOG");

            // nobody clears it -> it must fire (rst_n is held by the TB here,
            // so the pulse is only counted)
            add_watchdog_setup(p1);
            void'(p1.add(op0(OP_STOP)));
            run_program(p1);
            pm.wd_pulses = 0;
            drv.wait_cycles(100);
            ps.check_range("pulses in 100 cycles, not cleared", pm.wd_pulses, 1, 10);

            // cleared every 4 cycles -> it must not fire
            add_watchdog_setup(p2);
            for (int i = 0; i < 15; i++) begin
                void'(p2.add(outp(1, PORT_WD_CLEAR)));
                void'(p2.add(op0(OP_NOP)));
                void'(p2.add(op0(OP_NOP)));
                void'(p2.add(op0(OP_NOP)));
            end
            void'(p2.add(op0(OP_STOP)));
            drv.load(p2);
            pm.wd_pulses = 0;
            drv.execute(p2);
            ps.check("pulses while being cleared", 16'(pm.wd_pulses), 16'h0000);
            ps.end_scenario();
        endtask

        // ---- Reset sources: power-on, button, watchdog ------------------------------
        task test_resets();
            mcu_program p1 = new("reset_button");
            mcu_program p2 = new("reset_watchdog");
            mcu_program p3 = new("reset_watchdog_cleared");
            ps.begin_scenario("RESET SOURCES (POWER-ON, BUTTON, WATCHDOG)");

            ps.check("power-on reset low at start-up", {15'd0, vif.por_early}, 16'h0000);
            ps.check("power-on reset released       ", {15'd0, vif.por_n},     16'h0001);

            // button reset: LED = 1234, one push, loop forever
            void'(p1.add(movi(1, 16'h1234)));            // 11
            void'(p1.add(outp(1, PORT_LED)));            // 12
            void'(p1.add(push(1)));                      // 13
            void'(p1.add(jmp(14)));                      // 14: loop
            drv.load(p1);
            vif.btn_reset = 1'b1;
            drv.start();
            drv.wait_cycles(30);
            ps.check("before reset   : LED  ", vif.led, 16'h1234);
            ps.check("before reset   : SP   ", SP(),    16'h00FE);

            drv.real_reset(1);
            drv.wait_cycles(3);
            ps.check("reset unit idle: rst_n", {15'd0, vif.dut_rst_n}, 16'h0001);

            vif.btn_reset = 1'b0;                        // press
            drv.wait_cycles(3);
            ps.check("button pressed : rst_n", {15'd0, vif.dut_rst_n}, 16'h0000);
            ps.check("button pressed : LED  ", vif.led,                16'h0000);
            ps.check("button pressed : SP   ", SP(),                   16'h00FF);
            ps.check("button pressed : PC   ", {5'd0, vif.pc},         16'd11);

            vif.btn_reset = 1'b1;                        // release
            drv.wait_cycles(30);
            ps.check("after restart  : LED  ", vif.led, 16'h1234);
            ps.check("after restart  : SP   ", SP(),    16'h00FE);
            drv.real_reset(0);

            // watchdog never cleared -> repeated resets, program restarts
            void'(p2.add(movi(1, 16'h1234)));            // 11
            void'(p2.add(outp(1, PORT_LED)));            // 12: marks every (re)start
            add_watchdog_setup(p2);                      // 13-17
            void'(p2.add(jmp(18)));                      // 18: loop
            drv.load(p2);
            drv.start();
            drv.wait_cycles(3);
            drv.real_reset(1);
            pm.rst_falls  = 0;
            pm.led_writes = 0;
            drv.wait_cycles(200);
            ps.check_range("watchdog resets in 200 cycles", pm.rst_falls,  2, 15);
            ps.check_range("program restarts (LED writes)", pm.led_writes, 2, 16);
            drv.real_reset(0);

            // watchdog cleared in a loop -> no reset
            add_watchdog_setup(p3);                      // 11-15
            void'(p3.add(outp(1, PORT_WD_CLEAR)));       // 16
            void'(p3.add(op0(OP_NOP)));                  // 17
            void'(p3.add(jmp(16)));                      // 18
            drv.load(p3);
            drv.start();
            drv.wait_cycles(3);
            drv.real_reset(1);
            pm.rst_falls = 0;
            drv.wait_cycles(200);
            ps.check("watchdog cleared: resets", 16'(pm.rst_falls), 16'h0000);
            drv.real_reset(0);
            ps.end_scenario();
        endtask

        // ---- Buttons, debouncer, button interrupt --------------------------------
        task test_buttons();
            mcu_program p1 = new("button_read");
            mcu_program p2 = new("debouncer");
            mcu_program p3 = new("button_irq");
            ps.begin_scenario("BUTTONS, DEBOUNCER, BUTTON INTERRUPT");

            // a) raw read
            vif.btn = 5'b00100;                          // button C held
            void'(p1.add(movi(2, 16'hDEAD)));
            void'(p1.add(inp (2, PORT_BTN_READ)));
            void'(p1.add(op0 (OP_STOP)));
            run_program(p1);
            ps.check("raw read, button C held", R(2), 16'h0004);
            vif.btn = 5'b00000;

            // b) debouncer: one pulse per press, bounce and short presses ignored
            void'(p2.add(movi(1, 16'd1)));               // 11
            void'(p2.add(outp(1, PORT_DB_EN)));          // 12
            void'(p2.add(jmp(13)));                      // 13: loop
            drv.load(p2);
            drv.start();
            repeat (10) @(posedge vif.clk);
            pm.btn_pulses = 0;
            drv.press_button(0, 1'b1, 60);
            ps.check("bouncy press -> pulses ", 16'(pm.btn_pulses), 16'd1);
            drv.press_button(0, 1'b0, 60);
            ps.check("clean press  -> pulses ", 16'(pm.btn_pulses), 16'd2);
            drv.press_button(0, 1'b0, 10);
            ps.check("short press  -> ignored", 16'(pm.btn_pulses), 16'd2);

            // c) button U interrupt (vector 4 -> 500)
            p3.place(4,   jmp(500));
            p3.place(500, inc(13));
            p3.place(501, op0(OP_RETI));
            void'(p3.add(movi(13, 16'd0)));              // 11
            void'(p3.add(movi(1,  16'd1)));              // 12
            void'(p3.add(outp(1,  PORT_DB_EN)));         // 13
            void'(p3.add(outp(1,  PORT_BTN_IRQ_EN)));    // 14
            void'(p3.add(movi(1,  16'h0020)));           // 15: mask bit 5 = button U
            void'(p3.add(outp(1,  PORT_IRQ_MASK)));      // 16
            void'(p3.add(op0 (OP_EI)));                  // 17
            repeat (4) void'(p3.add(jmp(18)));           // 18-21: loop (+ safety copies)
            drv.load(p3);
            drv.start();
            repeat (30) @(posedge vif.clk);
            pm.isr_entries = 0;
            drv.press_button(0, 1'b1, 60);
            drv.press_button(0, 1'b0, 60);
            drv.wait_cycles(20);
            ps.check("interrupts for 2 presses", 16'(pm.isr_entries), 16'd2);
            ps.check("ISR count R13           ", R(13),               16'd2);
            ps.check("SP after RETI           ", SP(),                16'h00FF);
            ps.end_scenario();
        endtask

        // ---- Interrupts of all five buttons ---------------------------------------
        // Button i is pressed a different number of times (U 1, L 2, C 3, R 4, D 5)
        // and has its own ISR counter, so a wrong vector shows up as a wrong count.
        //   btn_in index : U 0, L 1, C 2, R 3, D 4
        //   vector       : U 4, L 3, C 2, R 1, D 0
        //   IRQ_MASK bit : U 5, L 6, C 7, R 8, D 9
        //   ISR counter  : U R20, L R19, C R18, R R17, D R16
        task test_button_irqs();
            mcu_program p1 = new("button_irqs");
            mcu_program p2 = new("button_irq_disabled");
            logic [9:0] ids[5] = '{10'b0000010000, 10'b0000001000, 10'b0000000100,
                                   10'b0000000010, 10'b0000000001};
            string      names[5] = '{"U", "L", "C", "R", "D"};
            int         k;
            ps.begin_scenario("INTERRUPTS OF ALL FIVE BUTTONS + BTN_INT_DIS");

            for (int b = 0; b < 5; b++) begin
                p1.place(4 - b,         jmp(700 + 10 * b));       // vector
                p1.place(700 + 10 * b,  inc(20 - b));             // ISR: counter++
                p1.place(701 + 10 * b,  op0(OP_RETI));
            end
            for (int r = 16; r <= 20; r++)
                void'(p1.add(movi(r, 16'd0)));
            void'(p1.add(movi(1, 16'd1)));
            void'(p1.add(outp(1, PORT_DB_EN)));
            void'(p1.add(outp(1, PORT_BTN_IRQ_EN)));
            void'(p1.add(movi(1, 16'h03E0)));                     // mask bits 5..9
            void'(p1.add(outp(1, PORT_IRQ_MASK)));
            void'(p1.add(op0 (OP_EI)));
            k = p1.next_pc();
            repeat (4) void'(p1.add(jmp(k)));                     // loop (+ safety copies)

            drv.load(p1);
            drv.start();
            repeat (30) @(posedge vif.clk);
            pm.isr_entries = 0;
            pm.irq_order.delete();
            for (int b = 0; b < 5; b++)
                repeat (b + 1) drv.press_button(b, 1'b0, 60);
            drv.wait_cycles(20);

            for (int b = 0; b < 5; b++)
                ps.check($sformatf("button %s ISR count (R%0d)", names[b], 20 - b),
                         R(20 - b), 16'(b + 1));
            ps.check("total button interrupts   ", 16'(pm.isr_entries), 16'd15);
            k = 0;
            for (int b = 0; b < 5; b++)
                repeat (b + 1) begin
                    if (k < pm.irq_order.size() && pm.irq_order[k] !== ids[b])
                        ps.fail($sformatf("interrupt #%0d: irq_id %b, expected %b (button %s)",
                                          k + 1, pm.irq_order[k], ids[b], names[b]));
                    k++;
                end
            ps.check("SP after all RETI         ", SP(), 16'h00FF);

            // BTN_INT_DIS: button interrupts on, then off again -> no interrupt
            p2.place(4,   jmp(500));
            p2.place(500, inc(13));
            p2.place(501, op0(OP_RETI));
            void'(p2.add(movi(13, 16'd0)));
            void'(p2.add(movi(1,  16'd1)));
            void'(p2.add(outp(1,  PORT_DB_EN)));
            void'(p2.add(outp(1,  PORT_BTN_IRQ_EN)));
            void'(p2.add(movi(1,  16'h0020)));
            void'(p2.add(outp(1,  PORT_IRQ_MASK)));
            void'(p2.add(outp(1,  PORT_BTN_IRQ_DIS)));            // off again
            void'(p2.add(op0 (OP_EI)));
            k = p2.next_pc();
            repeat (4) void'(p2.add(jmp(k)));
            drv.load(p2);
            drv.start();
            repeat (30) @(posedge vif.clk);
            pm.isr_entries = 0;
            drv.press_button(0, 1'b0, 60);
            drv.wait_cycles(20);
            ps.check("BTN_INT_DIS: interrupts   ", 16'(pm.isr_entries), 16'd0);
            ps.check("BTN_INT_DIS: R13          ", R(13),               16'd0);
            ps.end_scenario();
        endtask

        // ---- Nested interrupt: no preemption ---------------------------------------
        // Button D (lowest priority) starts a long ISR. That ISR starts timer0
        // (highest priority), which fires while the D ISR is still running.
        // The design does not nest interrupts: timer0 must wait until the D ISR
        // returns, then be served. Only one return address is ever on the stack.
        task test_nested_irq();
            mcu_program p = new("nested_irq");
            int k;
            ps.begin_scenario("NESTED INTERRUPT (HIGHER PRIORITY WAITS, NO PREEMPTION)");

            p.place(0, jmp(800));                                 // button D
            p.place(9, jmp(900));                                 // timer0
            p.place(800, outp(1, PORT_T0_EN));                    // D ISR: start timer0
            p.place(801, inc(16));
            for (k = 802; k < 882; k++) p.place(k, op0(OP_NOP));  // ~80 cycles
            p.place(882, op0(OP_RETI));
            p.place(900, outp(1, PORT_T0_DIS));                   // timer0 ISR
            p.place(901, inc(10));
            p.place(902, op0(OP_RETI));

            void'(p.add(movi(10, 16'd0)));
            void'(p.add(movi(16, 16'd0)));
            void'(p.add(movi(1,  16'd10)));
            void'(p.add(outp(1,  PORT_T0_PRESC)));
            void'(p.add(movi(1,  16'd3)));
            void'(p.add(outp(1,  PORT_T0_MAX)));                  // fires ~30 cycles after start
            void'(p.add(movi(1,  16'h0201)));                     // mask: timer0 + button D
            void'(p.add(outp(1,  PORT_IRQ_MASK)));
            void'(p.add(outp(1,  PORT_T0_IRQ_EN)));
            void'(p.add(outp(1,  PORT_DB_EN)));
            void'(p.add(outp(1,  PORT_BTN_IRQ_EN)));
            void'(p.add(op0 (OP_EI)));
            k = p.next_pc();
            repeat (4) void'(p.add(jmp(k)));

            drv.load(p);
            drv.start();
            repeat (30) @(posedge vif.clk);
            pm.isr_entries = 0;
            pm.irq_order.delete();
            pm.irq_depth = 0;
            pm.max_depth = 0;
            pm.min_sp    = 255;
            drv.press_button(4, 1'b0, 60);                        // button D
            drv.wait_cycles(200);

            foreach (pm.irq_order[i])
                $display("     -- served #%0d: irq_id = %b", i + 1, pm.irq_order[i]);
            ps.check_range("interrupts served       ", pm.irq_order.size(), 2, 3);
            if (pm.irq_order.size() >= 2) begin
                ps.check("1st served = button D   ", {6'd0, pm.irq_order[0]}, 16'h0001);
                ps.check("2nd served = timer0     ", {6'd0, pm.irq_order[1]}, 16'h0200);
            end
            ps.check      ("max nesting depth       ", 16'(pm.max_depth), 16'd1);
            ps.check      ("lowest SP (1 ret. addr.)", 16'(pm.min_sp),    16'h00FE);
            ps.check      ("button D ISR count R16  ", R(16), 16'd1);
            ps.check_range("timer0 ISR count R10    ", R(10), 1, 2);
            ps.check      ("SP after all RETI       ", SP(),  16'h00FF);
            ps.end_scenario();
        endtask

        // ---- Timer 3 and timer 4 ---------------------------------------------------
        task test_timers_3_4();
            mcu_program p1 = new("timer34_read");
            mcu_program p2 = new("timer34_irq");
            ps.begin_scenario("TIMER 3 AND TIMER 4");

            void'(p1.add(movi(1, 16'd1)));
            void'(p1.add(outp(1, PORT_T3_PRESC)));
            void'(p1.add(outp(1, PORT_T4_PRESC)));
            void'(p1.add(movi(1, 16'd1000)));
            void'(p1.add(outp(1, PORT_T3_MAX)));
            void'(p1.add(outp(1, PORT_T4_MAX)));
            void'(p1.add(outp(1, PORT_T3_EN)));
            void'(p1.add(outp(1, PORT_T4_EN)));
            repeat (10) void'(p1.add(op0(OP_NOP)));
            void'(p1.add(inp(2, PORT_T3_READ)));
            void'(p1.add(inp(3, PORT_T4_READ)));
            void'(p1.add(op0(OP_STOP)));
            run_program(p1);
            ps.check_range("timer3 value after ~10 cycles", R(2), 7, 14);
            ps.check_range("timer4 value after ~10 cycles", R(3), 7, 14);

            p2.place(6,   jmp(600));                     // timer3
            p2.place(5,   jmp(620));                     // timer4
            p2.place(600, inc(14));
            p2.place(601, op0(OP_RETI));
            p2.place(620, inc(15));
            p2.place(621, op0(OP_RETI));
            void'(p2.add(movi(14, 16'd0)));
            void'(p2.add(movi(15, 16'd0)));
            void'(p2.add(movi(1,  16'd10)));
            void'(p2.add(outp(1,  PORT_T3_PRESC)));
            void'(p2.add(outp(1,  PORT_T4_PRESC)));
            void'(p2.add(movi(1,  16'd10)));
            void'(p2.add(outp(1,  PORT_T3_MAX)));
            void'(p2.add(outp(1,  PORT_T4_MAX)));
            void'(p2.add(movi(1,  16'h0018)));
            void'(p2.add(outp(1,  PORT_IRQ_MASK)));
            void'(p2.add(outp(1,  PORT_T3_IRQ_EN)));
            void'(p2.add(outp(1,  PORT_T4_IRQ_EN)));
            void'(p2.add(op0 (OP_EI)));
            void'(p2.add(outp(1,  PORT_T3_EN)));
            void'(p2.add(outp(1,  PORT_T4_EN)));
            repeat (300) void'(p2.add(op0(OP_NOP)));
            void'(p2.add(op0(OP_DI)));
            void'(p2.add(op0(OP_STOP)));
            drv.load(p2);
            pm.isr_entries = 0;
            drv.execute(p2);
            if (p2.timed_out) ps.fail("no STOP");
            ps.check_range("timer3 ISR count R14 ", R(14), 2, 8);
            ps.check_range("timer4 ISR count R15 ", R(15), 2, 8);
            ps.check      ("R14+R15 == interrupts", R(14) + R(15), 16'(pm.isr_entries));
            ps.check      ("SP after all RETI    ", SP(), 16'h00FF);
            ps.end_scenario();
        endtask

        // ---- Stack overflow: SP stops at 0xBF -------------------------------------
        task test_stack();
            mcu_program p = new("stack");
            ps.begin_scenario("STACK OVERFLOW (SP STOPS AT 0xBF)");
            void'(p.add(movi(1, 16'h7777)));
            repeat (70) void'(p.add(push(1)));
            void'(p.add(op0(OP_STOP)));
            drv.load(p);
            pm.min_sp = 255;
            drv.execute(p);
            if (p.timed_out) ps.fail("no STOP");
            ps.check("SP after 70 pushes", SP(),            16'h00BF);
            ps.check("lowest SP seen    ", 16'(pm.min_sp),  16'h00BF);
            ps.end_scenario();
        endtask
    endclass


    // ------------------------------------------------------------------------
    // 2l. ENVIRONMENT: build, connect, run both phases, final report
    // ------------------------------------------------------------------------
    class mcu_env;
        mailbox #(mcu_program) gen2drv;
        mailbox #(mcu_program) drv2scb;
        mailbox #(mcu_event)   mon2scb;

        mcu_generator         gen;
        mcu_driver            drv;
        mcu_monitor           mon;
        mcu_scoreboard        scb;
        mcu_periph_monitor    pmon;
        mcu_periph_scoreboard pscb;
        mcu_periph_test       ptest;

        function new(virtual mcu_if vif);
            gen2drv = new();
            drv2scb = new();
            mon2scb = new();
            gen   = new(gen2drv);
            drv   = new(vif, gen2drv, drv2scb);
            mon   = new(vif, mon2scb);
            scb   = new(drv2scb, mon2scb);
            pmon  = new(vif);
            pscb  = new();
            ptest = new(vif, drv, pmon, pscb);
        endfunction

        task run();
            fork
                gen.run();
                drv.run();
                mon.run();
                scb.run();
                pmon.run();
            join_none

            // ---- phase 1: CPU core ------------------------------------------
            $display("");
            $display(" PHASE 1: CPU CORE (reference model + scoreboard)");
            $display("--------------------------------------------------");
            wait (gen.n_total > 0 && scb.programs_done == gen.n_total);

            // ---- phase 2: peripherals ---------------------------------------
            mon.active = 0;
            $display("");
            $display(" PHASE 2: PERIPHERALS (directed scenarios)");
            $display("--------------------------------------------------");
            ptest.run_all();

            report();
        endtask

        function void report();
            int errs;
            errs = scb.total_errors() + pscb.errors + sva_errors;
            $display("");
            $display("==================================================");
            $display(" SUMMARY");
            $display("==================================================");
            scb.report();
            $display("--------------------------------------------------");
            pscb.report();
            $display("--------------------------------------------------");
            $display(" Assertions          : 9 active, %0d failed", sva_errors);
            $display("--------------------------------------------------");
            if (errs == 0)
                $display(" RESULT: ALL PASSED");
            else
                $display(" RESULT: FAILED (%0d error(s))", errs);
            $display("==================================================");
        endfunction
    endclass

endpackage


// ============================================================================
// 3. ASSERTIONS (SVA): checked on every rising clock edge while out of reset
// ============================================================================
module mcu_sva (mcu_if bus);
    import mcu_pkg::*;

    // A1: the stack pointer never goes below 0xBF
    a_sp_range: assert property (@(posedge bus.clk) disable iff (!bus.dut_rst_n)
        bus.sp >= 8'hBF)
        else sva_fail($sformatf("A1 SP below 0xBF (SP=%h)", bus.sp));

    // A2: push and pop are never active together
    a_push_pop: assert property (@(posedge bus.clk) disable iff (!bus.dut_rst_n)
        !(bus.push && bus.pop))
        else sva_fail("A2 push and pop at the same time");

    // A3: after reset the CPU starts from address 11
    a_reset_pc: assert property (@(posedge bus.clk)
        $rose(bus.dut_rst_n) |-> bus.pc == 11'd11)
        else sva_fail($sformatf("A3 PC after reset = %0d, expected 11", bus.pc));

    // A4: once in STOP, the CPU stays in STOP
    a_stop_sticky: assert property (@(posedge bus.clk) disable iff (!bus.dut_rst_n)
        bus.state == ST_STOP |=> bus.state == ST_STOP)
        else sva_fail("A4 CPU left the STOP state");

    // A5: INTERRUPT / RET / RETI are always followed by WAIT_STATE
    a_wait_after: assert property (@(posedge bus.clk) disable iff (!bus.dut_rst_n)
        bus.state inside {ST_INTERRUPT, ST_RET, ST_RETI} |=> bus.state == ST_WAIT)
        else sva_fail("A5 INTERRUPT/RET/RETI not followed by WAIT_STATE");

    // A6: WAIT_STATE is always followed by INSTRUCTION
    a_wait_to_instr: assert property (@(posedge bus.clk) disable iff (!bus.dut_rst_n)
        bus.state == ST_WAIT |=> bus.state == ST_INSTRUCTION)
        else sva_fail("A6 WAIT_STATE not followed by INSTRUCTION");

    // A7: a register write never has an unknown address or value
    a_rf_known: assert property (@(posedge bus.clk) disable iff (!bus.dut_rst_n)
        bus.rf_we |-> !$isunknown({bus.rf_waddr, bus.rf_wdata}))
        else sva_fail($sformatf("A7 register write with X (R%0d <- %h)",
                                bus.rf_waddr, bus.rf_wdata));

    // A9: no nested interrupts - INTERRUPT is entered only when no ISR is open
    a_no_nesting: assert property (@(posedge bus.clk) disable iff (!bus.dut_rst_n)
        bus.state == ST_INTERRUPT |-> !$past(bus.irq_active))
        else sva_fail("A9 interrupt entered while another ISR was active");

    // A8: at most one 7-segment digit is active (anodes are active low)
    a_one_anode: assert property (@(posedge bus.clk) disable iff (!bus.dut_rst_n)
        !$isunknown(bus.anode) |-> $countones(~bus.anode) <= 1)
        else sva_fail($sformatf("A8 more than one anode active (%b)", bus.anode));

endmodule


// ============================================================================
// 4. TOP
// ============================================================================
module mcu_class_tb;
    import mcu_pkg::*;

    // ---- clock: 100 MHz ----------------------------------------------------
    logic clk;
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // ---- interface ---------------------------------------------------------
    mcu_if bus (clk);

    // ---- DUT ---------------------------------------------------------------
    wire         uart_framing_err;
    tri   [15:0] pins;
    wire  [15:0] led_out;
    wire  [6:0]  seven_segment;
    wire  [7:0]  anode;
    wire         dp;
    wire         pwm_pin;

    MCU_top dut (
        .clk              (clk),
        .button_reset     (bus.btn_reset), // active low
        .uart_rx          (1'b1),          // UART idle (loader bypassed)
        .uart_framing_err (uart_framing_err),
        .pins             (pins),
        .led_out          (led_out),
        .sws              (bus.sws),
        .seven_segment    (seven_segment),
        .anode            (anode),
        .dp               (dp),
        .btn_in           (bus.btn),
        .pwm_pin          (pwm_pin)
    );

    // ---- DUT -> interface (what the monitor and assertions watch) ------------
    assign bus.rf_we      = dut.CPU.write_enable_register_file;
    assign bus.rf_waddr   = dut.CPU.write_addr_register_file;
    assign bus.rf_wdata   = dut.CPU.write_data_register_file;
    assign bus.sr_we      = dut.CPU.sr_write_enable;
    assign bus.alu_flags  = {dut.CPU.alu_overflow, dut.CPU.alu_carry,
                             dut.CPU.alu_neg,      dut.CPU.alu_zero};
    assign bus.ram_we     = dut.CPU.ram_write_en;
    assign bus.ram_addr   = dut.CPU.ram_addr;
    assign bus.ram_wdata  = dut.CPU.data_ram_out;
    assign bus.port_en    = dut.CPU.port_enable;
    assign bus.port_addr  = dut.CPU.port_addr;
    assign bus.port_wdata = dut.CPU.port_data_out;
    assign bus.state      = dut.CPU.controller.current_state;
    assign bus.pc         = dut.CPU.PC;
    assign bus.sp         = dut.CPU.sp_value;
    assign bus.push       = dut.CPU.push;
    assign bus.pop        = dut.CPU.pop;
    assign bus.anode      = anode;

    // peripheral side
    assign pins           = bus.pins_drive;
    assign bus.pins_val   = pins;
    assign bus.led        = led_out;
    assign bus.seg        = seven_segment;
    assign bus.dp         = dp;
    assign bus.pwm        = pwm_pin;
    assign bus.dut_rst_n  = dut.rst_n;
    assign bus.por_n      = dut.power_on_rst_n;
    assign bus.wd_reset   = dut.watchdog_reset;
    assign bus.irq_id     = dut.irq_id;
    assign bus.irq_active = dut.irq_active;
    assign bus.btn_db0    = dut.GPIO_top_inst.debounced_btn[0];

    genvar gi;
    generate
        for (gi = 0; gi < 32; gi++) begin : g_regs
            assign bus.regs[gi] = dut.CPU.register_file.registers[gi];
        end
    endgenerate

    // Simulation-only speed-up: debouncer waits 20 clocks instead of 15,000,000
    defparam dut.GPIO_top_inst.DB_U.WAIT_TIME = 20;
    defparam dut.GPIO_top_inst.DB_L.WAIT_TIME = 20;
    defparam dut.GPIO_top_inst.DB_C.WAIT_TIME = 20;
    defparam dut.GPIO_top_inst.DB_R.WAIT_TIME = 20;
    defparam dut.GPIO_top_inst.DB_D.WAIT_TIME = 20;

    // ---- interface -> DUT: bypass the UART loader -----------------------------
    initial begin
        force dut.flash_write_address = bus.flash_wr_addr;
        force dut.loader_machine_code = bus.flash_wr_data;
        force dut.flash_write_enable  = bus.flash_wr_en;
        force dut.flash_read_enable   = bus.flash_rd_en;
        force dut.CPU_enable          = bus.cpu_en;
        force dut.rst_n               = bus.rst_n;

        repeat (3) @(posedge clk);
        #1;
        bus.por_early = dut.power_on_rst_n;    // must still be in power-on reset
    end

    // Reset scenarios hand rst_n to the real Reset_unit and take it back
    always @(bus.use_real_reset) begin
        if (bus.use_real_reset) release dut.rst_n;
        else                    force   dut.rst_n = bus.rst_n;
    end

    // ---- assertions --------------------------------------------------------
    mcu_sva sva (bus);

    // ---- test --------------------------------------------------------------
    mcu_env env;

    initial begin
        int n;

        $display("");
        $display("==================================================");
        $display(" MCU CLASS-BASED TESTBENCH");
        $display("==================================================");

        env = new(bus);
        if ($value$plusargs("NRAND=%d", n)) env.gen.n_random = n;
        env.scb.verbose = $test$plusargs("VERBOSE");

        repeat (5) @(posedge clk);
        env.run();
        $finish;
    end

    // ---- global safety timeout -----------------------------------------------
    initial begin
        #100_000_000;
        $display("ERROR: GLOBAL TB TIMEOUT");
        $finish;
    end

endmodule