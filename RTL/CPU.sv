module CPU(
    input logic         clk,
    input logic         rst_n,
    
    // LOADER, FLASH MEMORY
    input logic         CPU_enable,
    input logic [47:0]  machine_code,
    
    // RAM
    input  logic [15:0] ram_data,
    output logic        ram_read_en,
    output logic [0:0]  ram_write_en,
    output logic [7:0]  ram_addr,
    output logic [15:0] data_ram_out,
    
    // INTERRUPT_CONTROLLER
    input logic [9:0] irq_id,
    input logic irq_valid, 
    output logic interrupt_enable,
    output logic interrupt_disable,
    output logic irq_active,
    
    // I/O PORTS 
    input logic [15:0] port_data_in,
    output logic [15:0] port_data_out,
    output logic port_enable,
    output logic [10:0] port_addr,
    
    
    //PROGRAM COUNTER 
    output logic  [10:0] PC

    
);

    // INTERMEDIATE SIGNALS 
    
    logic [47:0] instruction_register;
    
    //DECODER
    logic [5:0] op_code;
    logic [4:0] Rd;
    logic [4:0] Rs1;
    logic [4:0] Rs2;
    logic [15:0] Immediate;
    logic [10:0] Address;
    
    // REGISTER_FILE 
    logic [4:0]   addr1_register_file;
    logic [4:0]   addr2_register_file;
    logic [4:0]   write_addr_register_file;
    logic [15:0]  write_data_register_file;
    logic         write_enable_register_file;
    logic [15:0] register_file_read_data1;
    logic [15:0] register_file_read_data2;
    
    // ALU
     logic [3:0]  alu_op;
     logic [15:0] immediate;
     logic        alu_zero;
     logic        alu_neg;
     logic        alu_carry;
     logic        alu_overflow;
     
   // RAM 
    logic [15:0] data_ram;
     
   // WRITE_BACK_MUX 
    logic [15:0] alu_result_to_writeback_mux;
    logic [1:0]  wb_sel;    
    
    // STATUS_REGISTER 
    logic sr_write_enable;
    logic [3:0] status_register;
    
    //STACK POINTER 
    logic push;
    logic pop;
    logic [7:0] sp_value;
   
    
    //PIPELINE_FLASH
    logic pipeline_flush;
    
    // -------------------------------------------
    
    // Instruction Register 
     always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) 
            instruction_register <= 48'd0;
        else begin
            if(pipeline_flush)
                instruction_register <= 48'd0;
            else
                instruction_register <= machine_code;
        end
     end
    
    // Status register
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            status_register <= 4'd0;
        else if(sr_write_enable) begin
            status_register[0] <= alu_zero;
            status_register[1] <= alu_neg;
            status_register[2] <= alu_carry;
            status_register[3] <= alu_overflow;
        end
    
    end


     
     
     // DECODER 
        Decoder Decoder(
        .clk(clk),
        .rst_n(rst_n),
        .pipeline_flush(pipeline_flush),
        .machine_code(instruction_register),
        .op_code(op_code),
        .Rd(Rd),
        .Rs1(Rs1),
        .Rs2(Rs2),
        .Immediate(Immediate),
        .Address(Address)
        
        );
        
     
     
     // Controller 
     controller controller(
        .clk(clk),
        .rst_n(rst_n),
        .CPU_enable(CPU_enable),
   
        .op_code(op_code),
        .Rd(Rd),
        .Rs1(Rs1),
        .Rs2(Rs2),
        .Immediate(Immediate),
        .Address(Address),
        
        .sr_write_enable(sr_write_enable),
        .Z(status_register[0]),
        .N(status_register[1]),
        .C(status_register[2]),
        .V(status_register[3]),
        
        .read_addr1(addr1_register_file),
        .read_addr2(addr2_register_file),
        .write_addr(write_addr_register_file),
        .write_enable(write_enable_register_file),
        
        .ALU_op(alu_op),
        .ALU_imm(immediate),
        
        .wb_sel(wb_sel),
        
        .ram_data(ram_data),
        .ram_read_en(ram_read_en),
        .ram_write_en(ram_write_en),
        .ram_addr(ram_addr),
        .data_ram(data_ram),
        
        .push(push),
        .pop(pop),
        .sp_value(sp_value),
        
        .pipeline_flush(pipeline_flush),
        
        .ir_valid(irq_valid),
        .ir_id(irq_id),
        .irq_active(irq_active),
        .interrupt_enable(interrupt_enable),
        .interrupt_disable(interrupt_disable),
        
        .port_enable(port_enable),
        .port_addr(port_addr),
        
        .PC(PC)
        
     );
        
       
    // REGSTER_FILE
    register_file register_file(
        .clk(clk),
        .read_addr1(addr1_register_file),
        .read_addr2(addr2_register_file),
        .write_addr(write_addr_register_file),
        .write_data(write_data_register_file),
        .write_enable(write_enable_register_file),
        .read_data1(register_file_read_data1),
        .read_data2(register_file_read_data2)
    );
    
    // ALU
    ALU ALU( 
        .alu_op(alu_op),
        .a(register_file_read_data1),
        .b(register_file_read_data2),
        .imm(immediate),
        .result(alu_result_to_writeback_mux),
        .zero(alu_zero),
        .negative(alu_neg),
        .overflow(alu_overflow),
        .carry(alu_carry)
     );
    
    write_back_mux write_back_mux(
        .alu_result(alu_result_to_writeback_mux),
        .memory_data(ram_data),
        .port_data(port_data_in),
        .immediate(Immediate),
        .wb_sel(wb_sel),
        .write_data(write_data_register_file)
    
    );

    // stack_pointer 
    
    stack_pointer stack_pointer(
        .clk(clk),
        .rst_n(rst_n),
        .push(push),
        .pop(pop),
        .sp_value(sp_value)
        
    );
    
    
    assign data_ram_out = (data_ram != 16'd0) ? data_ram : register_file_read_data1;
    assign port_data_out = register_file_read_data1;

endmodule
