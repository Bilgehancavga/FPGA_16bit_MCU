module PWM(
    input logic clk,
    input logic rst_n,
    input logic pwm_enable,
    input logic pwm_disable,
    input logic pwm_prescaler_enable,
    input logic pwm_duty_cycle_enable,
    input logic [15:0] write_data,
    output pin
);
    
    logic        pwm_flag;
    logic [15:0] counter;
    logic [7:0]  sawtooth;
    logic        sawtooth_flag;
    
    logic [15:0] prescaler;
    logic [15:0] duty_cycle;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
           prescaler <= 16'd0;
           duty_cycle <= 16'd0;
        end
        else begin
            if(pwm_prescaler_enable)
                prescaler <= write_data;
            if(pwm_duty_cycle_enable)
                duty_cycle <= write_data;
        end
    end
    
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            pwm_flag <= 1'b0;
        end
        else begin
            if(pwm_enable)
                pwm_flag <= 1'b1;
            else if (pwm_disable)
                pwm_flag <= 1'b0;
                
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 16'd0;
            sawtooth_flag <= 1'b0;
        end
        else begin
            if(pwm_flag) begin
                if(counter == prescaler) begin
                    counter <= 16'd0;
                    sawtooth_flag <= 1'b1;
                end
                else begin
                    counter <= counter +1;
                    sawtooth_flag <= 1'b0;
                end 
            end
            else begin
                counter <= 16'd0;
                sawtooth_flag <= 1'b0;
            end
        end
    end
    
    
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            sawtooth <= 0;
        end
        else begin
            if(pwm_flag) begin
                if(sawtooth_flag) begin
                  if(sawtooth == 255)
                    sawtooth <= 0;
                  else
                    sawtooth <= sawtooth +1; 
                end
            end
            else begin
                sawtooth <= 0;
            end
        end
    
    end
    
    assign pin = (pwm_flag && (sawtooth < duty_cycle[7:0])) ? 1'b1 : 1'b0;

endmodule
