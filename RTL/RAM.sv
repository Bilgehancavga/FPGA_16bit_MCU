module RAM(
    input logic clk,
    input logic read_enable,
    input logic write_enable,
    input logic [7:0] address,
    input logic [15:0] write_data,
    output logic [15:0] read_data
);

    logic [15:0] memory [255:0];    // 0x00-0xBF data, 0xC0-0xFF stack
    
    always_ff @(posedge clk) begin
        if(write_enable) begin
           memory[address] <= write_data;
        end
    end

    // async read: data in the same cycle (LOAD, POP, RET)
    always_comb begin
        if(read_enable) begin
            read_data = memory[address];
        end
        else
            read_data = 16'd0;
    
    end

endmodule
