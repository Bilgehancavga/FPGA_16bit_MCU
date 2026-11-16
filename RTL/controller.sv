module controller(
    input logic clk,
    input logic rst_n,
    input logic CPU_enable,
    
    input logic [5:0] op_code,  
    input logic [4:0] Rd,
    input logic [4:0] Rs1,
    input logic [4:0] Rs2,
    input logic [15:0] Immediate,
    input logic [10:0] Address,    
    
    
    
    // Status Register 
    input logic Z,
    input logic N,
    input logic C,
    input logic V,  
    output logic sr_write_enable,
   

    // Interrupt
    input logic ir_valid,
    input logic [9:0] ir_id, 
    output logic irq_active,
    output logic interrupt_enable,
    output logic interrupt_disable,
    
    //Register_file
    output logic [4:0]  read_addr1,
    output logic [4:0]  read_addr2,
    output logic [4:0]  write_addr,
    output logic        write_enable,
    
    // ALu
    output logic [3:0]  ALU_op,
    output logic [15:0] ALU_imm,
    
    //Write_back_mux
    output logic [1:0] wb_sel,
    
    //Ram
    input  logic [15:0] ram_data,
    output logic        ram_read_en,
    output logic [0:0]  ram_write_en,
    output logic [7:0]  ram_addr,
    output logic [15:0] data_ram,    
    
    // I/O Ports
    output logic port_enable,
    output logic [10:0] port_addr,
    
    // Stack pointer 
    input  logic [7:0] sp_value,
    output logic push,
    output logic pop,
    
    // pipeline flush 
    output logic pipeline_flush,
    
    //Program Counter 
    output logic [10:0] PC 
);
    
    
    // program counter 
    logic [10:0] PC_next;
    
    // CPU COPY
    logic cpu_en_d;


    
   
   
   
   //------------------------------
   
   // FSM
    typedef enum logic [2:0] {
        RESET_WAIT,
        RESET_WAIT2,
        INSTRUCTION,
        INTERRUPT,
        WAIT_STATE,
        RET,
        RETI,
        STOP
    
    } states;
    
    states current_state, next_state;
    
    // PC
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            PC <= 11'd11;
        else 
            PC <= PC_next;
    end
    
    
    // states
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            if(CPU_enable)
                current_state <= RESET_WAIT; // INSTRUCTION 
            else 
                current_state <= INSTRUCTION;
        else 
            current_state <= next_state;
    end
    
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) 
            cpu_en_d <= 1'b0;
        else       
            cpu_en_d <= CPU_enable;
    end
    
    always_latch begin
        if(!rst_n)
            irq_active = 1'b0;
        else begin
            if(current_state == INTERRUPT)
                 irq_active = 1'b1;
            else if(current_state == RETI)
                 irq_active = 1'b0;
         end
    end
   
   
    // Controller;
    always_comb begin
        PC_next = PC;
        ALU_op = 4'd0;
        ALU_imm = 16'd0;
        
        wb_sel = 2'd0;
        
        read_addr1 = 5'd0;
        read_addr2 = 5'd0;
        write_addr = 5'd0;
       
        ram_addr   = 8'd0;
        data_ram   = 16'd0;
        
        port_addr  = 11'd0;
        
        interrupt_enable  = 1'b0;
        interrupt_disable = 1'b0;
    
        write_enable    = 1'b0;
        ram_read_en     = 1'b0;
        ram_write_en    = 1'b0;
        port_enable     = 1'b0;
        sr_write_enable = 1'b0;
        
        push            = 1'b0;
        pop             = 1'b0;
        pipeline_flush  = 1'b0;
                
        next_state = INSTRUCTION;
        
        case(current_state)
            RESET_WAIT: begin
                pipeline_flush = 1'b1;
                PC_next = PC;
                next_state = RESET_WAIT2;
            end
            
            RESET_WAIT2: begin
                pipeline_flush = 1'b1;
                PC_next = PC+1;
                next_state = INSTRUCTION;
            end
        
            INTERRUPT: begin
                pipeline_flush = 1'b1; 
                push = 1'b1;
                ram_write_en = 1'b1; 
                ram_addr = sp_value;
                data_ram = {5'b00000, PC-3};
                
                case(ir_id)
                    10'b0000000001: PC_next = 11'd0;
                    10'b0000000010: PC_next = 11'd1;
                    10'b0000000100: PC_next = 11'd2;
                    10'b0000001000: PC_next = 11'd3;
                    10'b0000010000: PC_next = 11'd4;
                    10'b0000100000: PC_next = 11'd5;
                    10'b0001000000: PC_next = 11'd6;
                    10'b0010000000: PC_next = 11'd7;
                    10'b0100000000: PC_next = 11'd8;
                    10'b1000000000: PC_next = 11'd9;

                    default:       PC_next = 11'd0;
                endcase
                next_state = WAIT_STATE;
            end
   
                        
            WAIT_STATE: begin
                pipeline_flush = 1'b1;
                PC_next        = PC+1;
                next_state     = INSTRUCTION;
                        
            end
            
            RET: begin 
                pipeline_flush = 1'b1; 
                pop = 1'b1;
                ram_addr = sp_value+1;
                ram_read_en = 1'b1;
                PC_next = ram_data[10:0];
                
                next_state =  WAIT_STATE;
                
            end 
            RETI: begin
                pipeline_flush = 1'b1; 
                pop         = 1'b1;
                ram_addr    = sp_value + 1'b1;
                ram_read_en = 1'b1;
                PC_next     = ram_data[10:0];
            
                next_state  = WAIT_STATE;
                
            end
            STOP: begin
                next_state = STOP;
            
            end
        
        INSTRUCTION: begin
            if (CPU_enable && !cpu_en_d) begin      // RUN'a yeni geçildi
                pipeline_flush = 1'b1;
                PC_next        = 11'd11;
                next_state     = RESET_WAIT2;
            end
            else if(CPU_enable) begin 
                if(ir_valid && op_code != 6'b000000) begin
                    next_state = INTERRUPT;
                end
                else begin
                            
                    case(op_code)       
                        // FLUSH sonrasý için 
                        6'b000000: begin
                            PC_next = PC_next + 1;
                        end
                        
                        //not 
                        6'b000001: begin 
                            ALU_op = 4'b0000;
                            read_addr1 = Rs1;
                            wb_sel     = 2'b00;
                            write_enable   = 1'b1;
                            write_addr = Rd;  
                            sr_write_enable = 1'b1;
                            
                            PC_next = PC_next + 1;
                        end
                        
                        // AND
                        6'b000010: begin
                            ALU_op          = 4'b0001;
                            read_addr1      = Rs1;
                            read_addr2      = Rs2;
                            wb_sel          = 2'b00;
                            write_enable    = 1'b1;
                            write_addr      = Rd;
                            sr_write_enable = 1'b1;
                            
                            PC_next = PC_next + 1;
                        end
                        
                        // OR
                        6'b000011: begin
                            ALU_op          = 4'b0010;
                            read_addr1      = Rs1;
                            read_addr2      = Rs2;
                            wb_sel          = 2'b00;
                            write_enable    = 1'b1;
                            write_addr      = Rd;
                            sr_write_enable = 1'b1;
                            
                            PC_next = PC_next + 1;
                        end
                        
                        //XOR
                        6'b000100: begin
                            ALU_op          = 4'b0011;
                            read_addr1      = Rs1;
                            read_addr2      = Rs2;
                            wb_sel          = 2'b00;
                            write_enable    = 1'b1;
                            write_addr      = Rd;
                            sr_write_enable = 1'b1;
                            
                            PC_next = PC_next + 1;
                        end
                        
                        // SHL
                        6'b000101: begin
                            ALU_op          = 4'b1000;
                            read_addr1      = Rs1;
                            read_addr2      = Rs2;
                            wb_sel          = 2'b00;
                            write_enable    = 1'b1;
                            write_addr      = Rd;
                            sr_write_enable = 1'b1;  
                            
                            PC_next = PC_next + 1;     
                        end
                        
                        // SHR
                        6'b000110: begin
                            ALU_op          = 4'b1001;
                            read_addr1      = Rs1;
                            read_addr2      = Rs2;
                            wb_sel          = 2'b00;
                            write_enable    = 1'b1;
                            write_addr      = Rd;
                            sr_write_enable = 1'b1;
                            
                            PC_next = PC_next + 1;
                        end
                        
                        // ADD
                        6'b000111: begin
                            ALU_op          = 4'b0100;
                            read_addr1      = Rs1;
                            read_addr2      = Rs2;
                            wb_sel          = 2'b00;
                            write_enable    = 1'b1;
                            write_addr      = Rd;
                            sr_write_enable = 1'b1;
                            
                            PC_next = PC_next + 1;
                        end
                        
                        // SUB
                        6'b001000: begin
                            ALU_op          = 4'b0101;
                            read_addr1      = Rs1;
                            read_addr2      = Rs2;
                            wb_sel          = 2'b00;
                            write_enable    = 1'b1;
                            write_addr      = Rd;
                            sr_write_enable = 1'b1;
                            
                            PC_next = PC_next + 1;
                        end
                        
                        // INC
                        6'b001001: begin
                            ALU_op = 4'b1101;
                            read_addr1      = Rs1;
                            wb_sel          = 2'b00;
                            write_enable    = 1'b1;
                            write_addr      = Rd;
                            sr_write_enable = 1'b1;
                            PC_next         = PC_next + 1;
                        end
                        
                        // DEC
                        6'b001010: begin
                            ALU_op = 4'b1110;
                            read_addr1 = Rs1;
                            wb_sel          = 2'b00;
                            write_enable    = 1'b1;
                            write_addr      = Rd;
                            sr_write_enable = 1'b1;
                            PC_next         = PC_next + 1;
                        end
                        
                        // NEG
                        6'b001011: begin
                            ALU_op          = 4'b0111;
                            read_addr1      = Rs1;
                            wb_sel          = 2'b00;
                            write_enable    = 1'b1;
                            write_addr      = Rd;
                            sr_write_enable = 1'b1;
                            
                            PC_next = PC_next + 1;
                        end
                        
                        // CMP
                        6'b001100: begin
                            ALU_op          = 4'b0110;
                            read_addr1      = Rs1;
                            read_addr2      = Rs2;
                            sr_write_enable = 1'b1;
                            
                            PC_next = PC_next + 1;
                        end
                        
                        // ADDI
                        6'b001101: begin
                            ALU_op          = 4'b1011;
                            read_addr1      = Rs1;
                            ALU_imm         = Immediate;
                            wb_sel          = 2'b00;
                            write_enable    = 1'b1;
                            write_addr      = Rd;
                            sr_write_enable = 1'b1;
                            PC_next         = PC_next + 1;
                            
                        end
                        
                        // SUBI
                        6'b001110: begin
                            ALU_op = 4'b1100;
                            read_addr1      = Rs1;
                            ALU_imm         = Immediate;
                            wb_sel          = 2'b00;
                            write_enable    = 1'b1;
                            write_addr      = Rd;
                            sr_write_enable = 1'b1;
                            PC_next         = PC + 1;
                        end
                        
                        // MOV
                        6'b001111: begin
                            ALU_op       = 4'b1010;
                            read_addr1   = Rs1;
                            wb_sel       = 2'b00;
                            write_enable = 1'b1;
                            write_addr   = Rd;
                            
                            PC_next = PC_next + 1;
                        end
                        
                        // MOVI
                        6'b010000: begin
                            
                            wb_sel       = 2'b11; 
                            write_enable = 1'b1;
                            write_addr   = Rd;
                            
                            PC_next = PC_next + 1;
                        end
                        
                        // LOAD
                        6'b010001: begin
                            wb_sel       = 2'b01;
                            ram_read_en  = 1'b1;
                            ram_addr     = Address; 
                            write_enable = 1'b1;
                            write_addr   = Rd;
                                        
                            PC_next = PC_next + 1;  
                        end
                        
                        // STORE
                        6'b010010: begin
                            read_addr1   = Rs1;
                            ram_write_en = 1'b1;
                            ram_addr     = Address;
                            
                            PC_next = PC_next + 1;
                        end
                        
                        // IN
                        6'b010011: begin
                            wb_sel       = 2'b10;
                            port_enable  = 1'b1;
                            port_addr    = Address;
                            write_enable = 1'b1;
                            write_addr   = Rd;
                            
                            PC_next = PC_next + 1;
                        end
                        
                        // OUT
                        6'b010100: begin
                            port_enable = 1'b1;
                            port_addr   = Address;
                            read_addr1  = Rs1;
                            
                            PC_next = PC_next + 1;
                        end
                        
                        // PUSH 
                        6'b010101: begin
                            read_addr1   = Rs1;
                            ram_write_en = 1'b1;
                            ram_addr     = sp_value;
                            push         = 1'b1;
                            
                            PC_next = PC_next + 1;
                        end
                        
                        // POP
                        6'b010110: begin
                            wb_sel       = 2'b01;
                            ram_read_en  = 1'b1;
                            ram_addr     = sp_value + 1;
                            pop          = 1'b1;
                            write_enable = 1'b1;
                            write_addr   = Rd;
                            
                            PC_next = PC_next + 1;
                        end
                        
                        // SET
                        6'b010111: begin
                            wb_sel       = 2'b11;
                            write_enable = 1'b1;
                            write_addr   = Rd;                   
                            
                            PC_next = PC_next + 1;
                        end
                        
                        // CLR
                        6'b011000: begin
                            wb_sel       = 2'b11;
                            write_enable = 1'b1;
                            write_addr   = Rd; 
                            
                            PC_next = PC_next + 1;
                        end
                        
                        // JMP
                        6'b011001: begin
                            pipeline_flush  = 1'b1;
                            PC_next         = Address;
                            next_state      = WAIT_STATE; 
                        end
                        
                        // RJMP
                        6'b011010: begin
                            pipeline_flush = 1'b1;
                            PC_next        = Address;
                            next_state     = WAIT_STATE; 
                        end
                        
                        // JZ 
                        6'b011011: begin
                            if(Z == 1) begin
                                pipeline_flush  = 1'b1;
                                PC_next         = Address;
                                next_state      = WAIT_STATE; 
                            end 
                            else
                                PC_next = PC_next + 1;
                        end
                        
                        // JNZ 
                        6'b011100: begin
                            if(Z == 0) begin
                                pipeline_flush = 1'b1;
                                PC_next        = Address;
                                next_state     = WAIT_STATE; 
                            end 
                            else
                                PC_next = PC_next + 1;                      
                        end
                        
                        // JC 
                        6'b011101: begin
                            if(C == 1) begin
                                pipeline_flush  = 1'b1;
                                PC_next         = Address;
                                next_state      = WAIT_STATE; 
                            end 
                            else
                                PC_next = PC_next + 1; 
                        end
                        
                        // JNC
                        6'b011110: begin
                            if(C == 0) begin
                                pipeline_flush  = 1'b1;
                                PC_next         = Address;
                                next_state      = WAIT_STATE; 
                            end 
                            else
                                PC_next = PC_next + 1; 
                        end
                        
                        // JN
                        6'b011111: begin
                            if(N == 1) begin
                                pipeline_flush  = 1'b1;
                                PC_next         = Address;
                                next_state      = WAIT_STATE; 
                            end 
                            else
                                PC_next = PC_next + 1; 
                        
                        end
                        
                        // JP
                        6'b100000: begin
                            if(N == 0 && Z == 0) begin
                                pipeline_flush  = 1'b1;
                                PC_next         = Address;
                                next_state      = WAIT_STATE; 
                            end 
                            else
                                PC_next = PC_next + 1; 
                        
                        end
                        
                        // JLE
                        6'b100001: begin
                            if(Z || (N ^ V)) begin
                                pipeline_flush  = 1'b1;
                                PC_next         = Address;
                                next_state      = WAIT_STATE; 
                            end 
                            else
                                PC_next = PC_next + 1; 
                        end
                        
                        // JGE
                        6'b100010: begin
                            if(!(N ^ V)) begin
                                pipeline_flush  = 1'b1;
                                PC_next         = Address;
                                next_state      = WAIT_STATE; 
                            end 
                            else
                                PC_next = PC_next + 1; 
                        end
                        
                        // CALL
                        6'b100011: begin
                            pipeline_flush  = 1'b1; 
                            push            = 1'b1;
                            ram_write_en    = 1'b1; 
                            ram_addr        = sp_value;
                            data_ram        = {5'b00000, PC-11'd2};
                            PC_next         = Address;
                            next_state      = WAIT_STATE; 
                            
                        end
                        
                        // RET
                        6'b100100: begin
                            next_state = RET;
                        end
                        
                        // EI
                        6'b100101: begin
                            interrupt_enable = 1'b1;
                            PC_next = PC_next + 1;
                        end
                        
                        //DI
                        6'b100110: begin
                            interrupt_disable = 1'b1;
                            PC_next = PC_next + 1;
                        end
                        
                        //RETI
                        6'b100111: begin
                            next_state = RETI; 
                        end
                        
                        //NOP
                        6'b101000: begin
                            PC_next = PC_next + 1;
                        end
                        
                        //STOP
                        6'b101001: begin
                            pipeline_flush = 1'b1;
                            next_state = STOP;
                        end
                        
                    endcase     
                end
           end  
           end 
       endcase
       
    end
    

endmodule
