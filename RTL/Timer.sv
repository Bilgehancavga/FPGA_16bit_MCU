module Timer(
    input logic clk,
    input logic rst_n,
    input logic timer_clear,
    input logic timer_enable, //Timer'ý açmak için 
    input logic timer_disable, // Timer'ý kapatmak için 
    input logic interrupt_enable,  // Interrupt'ý açmak için 
    input logic interrupt_disable, // Interrupt'ý kapatmak için 
    input logic prescaler_enable, // Prescaler'ýn adresi 
    input logic max_value_enable, // Max_value adresi 
    input logic  [15:0] write_data, 
    input logic read_enable,
    output logic [15:0] timer_value,
    output logic timer_interrupt
);

    logic [15:0] ticks;
    logic [15:0] value;
    logic        value_enable;
    logic        timer_flag;
    logic        interrupt;
    logic        interrupt_flag;
    logic [15:0] prescaler;
    logic [15:0] max_value;
    
    
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            timer_flag <= 1'b0;
        else begin
            if(timer_enable)
                timer_flag <= 1'b1;
            else if(timer_disable)
                timer_flag <= 1'b0;
        end
    end
    
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            interrupt_flag <= 1'b0;
        end
        else begin
            if(interrupt_enable)
                interrupt_flag <= 1'b1;
            else if(interrupt_disable)
                interrupt_flag <= 1'b0;
        end
    end
    
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            prescaler <= 0;
        else begin
            if(prescaler_enable)
                prescaler <= write_data;
        end
    end
    
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            max_value <= 0;
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
        else if(timer_clear) begin
            ticks <= 0;
            value_enable <= 1'b0;
        end
        else begin
            value_enable <= 1'b0;
            if(timer_flag) begin
                if(ticks == prescaler-1) begin
                    ticks <= 16'b0;
                    value_enable <= 1'b1;
                end
                else
                    ticks <= ticks +1;
            end
        end 
    end
    
    
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            value <= 16'b0;
            interrupt <= 1'b0;
        end
        else if(timer_clear) begin
            value <= 16'b0;
            interrupt <= 1'b0;
        end
        else begin
            interrupt <= 1'b0;
            if(value_enable) begin
                if(value==max_value-1) begin
                    value <= 16'b0;
                    if(interrupt_flag)
                        interrupt <= 1'b1;
                end
                else
                    value <= value+1; 
            end
        end
    
    end
    
    assign timer_value = read_enable ? value : 16'd0;
    assign timer_interrupt = interrupt;
   

endmodule
