module BUTTON(
    input clk, 
    input rst_n,
    input logic button_enable,
    input logic button_interrupt_enable,
    input logic button_interrupt_disable,
    input logic [4:0] btn_in,
    output logic [4:0] btn_out,
    output logic [4:0] btn_interrupt_out
);

    logic btn_interrupt_flag;

always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        btn_interrupt_flag <= 1'b0;
    else begin
       if(button_interrupt_enable)
            btn_interrupt_flag <= 1'b1;
        else if(button_interrupt_disable)
            btn_interrupt_flag <= 1'b0;
    end
end

always_comb begin
    if(button_enable) 
        btn_out = btn_in;
    else
        btn_out = 5'd0;
end

always_comb begin
    if(btn_interrupt_flag) begin
        btn_interrupt_out = btn_in;
    end
    else
        btn_interrupt_out = 5'd0;
end


endmodule
