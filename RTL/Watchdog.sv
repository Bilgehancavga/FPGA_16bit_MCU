module Watchdog(
    input logic clk,
    input logic rst_n,
    input logic watchdog_enable,
    input logic watchdog_disable,
    input logic watchdog_clear,
    input logic prescaler_enable,
    input logic max_value_enable,
    input logic [15:0] write_data,
    output logic reset
);

    logic [15:0] ticks;
    logic [15:0] counter;
    logic        enable_flag;
    logic        value_enable;
    logic        watchdog_reset;
    logic [15:0] prescaler_value;
    logic [15:0] max_value;
    
    
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) 
            enable_flag <= 1'b0;
        else begin
            if(watchdog_enable)
                enable_flag <= 1'b1;
            else if (watchdog_disable)
                enable_flag <= 1'b0;
        end
    end
    
    
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            prescaler_value <= 16'd0;
        else begin
            if(prescaler_enable) 
               prescaler_value <= write_data;
        end
    end
    
    
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            max_value <= 16'd0;
        else begin
            if(max_value_enable) 
               max_value <= write_data;
        end
    end
    
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            ticks <= 0;
            value_enable <= 1'b0;
        end
        else if(watchdog_clear) begin
            ticks <= 0;
            value_enable <= 1'b0;
        end
        else begin
            if(enable_flag) begin
                value_enable <= 1'b0;
                if(ticks==prescaler_value) begin
                    value_enable <= 1'b1;
                    ticks <= 0;
                end
                else 
                    ticks <= ticks+1;
            end
            else begin
                ticks <= 0;
                value_enable <= 1'b0;
            end    
        
        end
    
    end
    
    
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            counter <= 0;
            watchdog_reset <= 1'b0;
        end
        else if (watchdog_clear) begin
            counter <= 0;
            watchdog_reset <= 1'b0;
        end
        else if (!enable_flag) begin
            counter <=  0;
            watchdog_reset <= 1'b0;
        end
        else begin
            watchdog_reset <= 1'b0;
            if(value_enable) begin
                if(counter == max_value) begin
                    watchdog_reset <= 1'b1;
                    counter <= 0;
                end
                else
                    counter <= counter+1;
            end
        end
    end
    
    assign reset = watchdog_reset;
    
endmodule
