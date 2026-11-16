module Reset_unit(
    input clk,
    input watchdog_reset,
    input power_on_reset,
    input button_reset,
    input loader_reset,
    output rst_n
);

    logic reset_n;
    
    always_ff @(posedge clk) begin 
        reset_n <= ~(loader_reset || watchdog_reset || !power_on_reset || !button_reset);
    end
    
    
    assign rst_n = reset_n;

endmodule
