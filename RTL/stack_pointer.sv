module stack_pointer(
    input logic clk,
    input logic rst_n,
    input logic push,
    input logic pop,
    output logic [7:0] sp_value
);

always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        sp_value <= 8'hFF;
    
    end
    
    else if(push && sp_value != 8'hBF)
        sp_value <= sp_value - 8'd1;
        
    else if(pop && sp_value != 8'hFF)
        sp_value <= sp_value + 8'd1;

end


endmodule
