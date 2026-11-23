module Flash_memory(
    input logic clk,
    input logic flash_write_enable,
    input logic flash_read_enable,
    input logic [47:0] machine_code,
    input logic [10:0] flash_write_address,
    input logic [10:0] flash_read_address,
    output logic [47:0] program_data
);

    logic [47:0] memory [2047:0];     // block RAM, filled by the loader (lost at power-off) 

    initial begin
        memory[0] = 48'd0;
    end

    
    
    
    always_ff @(posedge clk) begin
        if(flash_write_enable) 
            memory[flash_write_address] <= machine_code;
        
         if(flash_read_enable)
            program_data <= memory[flash_read_address];    // registered read: 1-cycle fetch latency
            
    end
    
    
endmodule
