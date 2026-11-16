module LED(
    input logic clk,
    input logic rst_n,
    input logic led_enable,
    input logic [15:0] write_data,
    output logic [15:0] led_out
);

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            led_out <= 16'd0;
        else if (led_enable)
            led_out <= write_data;
    
    end



endmodule
