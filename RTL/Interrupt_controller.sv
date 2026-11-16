module Interrupt_controller(
    input logic clk,
    input logic rst_n,
    input logic interrupt_enable,
    input logic interrupt_disable,
    input logic [15:0] interrupt_register,
    input logic interrupt_register_enable,
    input logic timer0,
    input logic timer1,
    input logic timer2,
    input logic timer3,
    input logic timer4,
    input logic btn_u,
    input logic btn_l,
    input logic btn_c,
    input logic btn_r,
    input logic btn_d,
    input logic irq_active,
    output logic [9:0] irq_id,
    output logic irq_valid
);
    
    logic [15:0] interrupt_reg;
    logic [9:0] interrupt_pending;
    logic       interrupt_flag;
    logic       irq_valid_r;      // YENÝ
    logic [9:0] irq_id_r;         // YENÝ
    
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            interrupt_flag <= 1'b0;
        else begin
            if(interrupt_enable)
                interrupt_flag <= 1'b1;
            else if(interrupt_disable)
                interrupt_flag <= 1'b0;
        end
    end
    
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            interrupt_reg <= 16'd0;
        else if(interrupt_register_enable)
            interrupt_reg <= interrupt_register;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            interrupt_pending <= 10'd0;
            irq_id_r          <= 10'b0;
            irq_valid_r       <= 1'b0;
        end
        else begin
            if(interrupt_flag) begin

                if (timer0 && interrupt_reg[0]) interrupt_pending[9] <= 1'b1; 
                if (timer1 && interrupt_reg[1]) interrupt_pending[8] <= 1'b1;
                if (timer2 && interrupt_reg[2]) interrupt_pending[7] <= 1'b1;
                if (timer3 && interrupt_reg[3]) interrupt_pending[6] <= 1'b1;
                if (timer4 && interrupt_reg[4]) interrupt_pending[5] <= 1'b1;
                if (btn_u  && interrupt_reg[5]) interrupt_pending[4] <= 1'b1;
                if (btn_l  && interrupt_reg[6]) interrupt_pending[3] <= 1'b1;
                if (btn_c  && interrupt_reg[7]) interrupt_pending[2] <= 1'b1;
                if (btn_r  && interrupt_reg[8]) interrupt_pending[1] <= 1'b1;
                if (btn_d  && interrupt_reg[9]) interrupt_pending[0] <= 1'b1;

                if(!irq_active && !irq_valid_r) begin      // DEÐÝÞTÝ

                    if(interrupt_pending[9]) begin
                        irq_id_r <= 10'b1000000000;
                        irq_valid_r <= 1'b1;
                        interrupt_pending[9] <= 1'b0; 
                    end
                    else if(interrupt_pending[8]) begin
                        irq_id_r <= 10'b0100000000;
                        irq_valid_r <= 1'b1;
                        interrupt_pending[8] <= 1'b0; 
                    end
                    else if(interrupt_pending[7]) begin
                        irq_id_r <= 10'b0010000000;
                        irq_valid_r <= 1'b1;
                        interrupt_pending[7] <= 1'b0; 
                    end
                    else if(interrupt_pending[6]) begin
                        irq_id_r <= 10'b0001000000;
                        irq_valid_r <= 1'b1;
                        interrupt_pending[6] <= 1'b0; 
                    end
                    else if(interrupt_pending[5]) begin
                        irq_id_r <= 10'b0000100000;
                        irq_valid_r <= 1'b1;
                        interrupt_pending[5] <= 1'b0; 
                    end
                    else if(interrupt_pending[4]) begin
                        irq_id_r <= 10'b0000010000;
                        irq_valid_r <= 1'b1;
                        interrupt_pending[4] <= 1'b0; 
                    end
                    else if(interrupt_pending[3]) begin
                        irq_id_r <= 10'b0000001000;
                        irq_valid_r <= 1'b1;
                        interrupt_pending[3] <= 1'b0; 
                    end
                    else if(interrupt_pending[2]) begin
                        irq_id_r <= 10'b0000000100;
                        irq_valid_r <= 1'b1;
                        interrupt_pending[2] <= 1'b0; 
                    end
                    else if(interrupt_pending[1]) begin
                        irq_id_r <= 10'b0000000010;
                        irq_valid_r <= 1'b1;
                        interrupt_pending[1] <= 1'b0; 
                    end
                    else if(interrupt_pending[0]) begin
                        irq_id_r <= 10'b0000000001;
                        irq_valid_r <= 1'b1;
                        interrupt_pending[0] <= 1'b0; 
                    end
                end
                else if(irq_active) begin
                    irq_id_r    <= 10'd0;
                    irq_valid_r <= 1'b0;
                end
            end 
            else begin
                interrupt_pending <= 10'd0;  
                irq_id_r          <= 10'd0;
                irq_valid_r       <= 1'b0;
            end
        end
    end

    // YENÝ: DI sonrasý CPU kesmeyi görmesin
    assign irq_valid = irq_valid_r && interrupt_flag;
    assign irq_id    = irq_id_r;

endmodule