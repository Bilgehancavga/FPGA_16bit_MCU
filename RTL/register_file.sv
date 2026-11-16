module register_file(
    input logic clk,
    input logic [4:0]   read_addr1,
    input logic [4:0]   read_addr2,
    input logic [4:0]   write_addr,
    input logic [15:0]  write_data,
    input logic         write_enable,
    
    output logic [15:0] read_data1,
    output logic [15:0] read_data2
);
    
    
logic [15:0] registers [31:0];

always_ff @(posedge clk) begin
    
    if(write_enable) 
        registers[write_addr] <= write_data;
    
end
    
    
always_comb begin
    read_data1 = registers[read_addr1];
    read_data2 = registers[read_addr2];

end
    
    
    
endmodule
