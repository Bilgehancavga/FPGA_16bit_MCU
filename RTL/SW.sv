module SW(
    input logic sw_enable,
    input logic [15:0] sws,
    output logic [15:0] sw_data
);

always_comb begin
    if(sw_enable)
       sw_data = sws;
    else
        sw_data = 16'd0;
end

endmodule
