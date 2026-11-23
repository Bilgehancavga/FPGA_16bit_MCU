module power_on_reset(
    input logic clk,
    output logic rst_n
);

logic [2:0] counter;

// no reset input: this module creates the reset, values come from the bitstream
initial begin
    counter = 3'd0;
    rst_n = 1'b0;
end

// hold reset low for 7 clocks after power-up
always @(posedge clk) begin
    if(counter != 3'b111) begin
        counter <= counter +1;
        rst_n <= 1'b0;
    end
    else
        rst_n <= 1'b1;
    
end


endmodule
