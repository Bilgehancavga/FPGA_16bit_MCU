module BCD_to_sevensegment(
    input logic clk,
    input logic rst_n,
    input logic converter_in,
    input logic converter_out_0,
    input logic converter_out_1,
    input logic converter_out_2,
    input logic converter_out_3,
    input logic [15:0] bcd,
    output logic [15:0] digit
    
);

    logic [15:0] bcd_in;
    logic [15:0]  digit_0;
    logic [15:0]  digit_1;
    logic [15:0]  digit_2;
    logic [15:0]  digit_3;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            bcd_in <= 16'd0;
        end
        else begin
            if(converter_in)
                bcd_in <= bcd;
        end
    end
   
    
    always_comb begin
        
        digit_0 = bcd_to_seg(bcd_in[3:0]);
        digit_1 = bcd_to_seg(bcd_in[7:4]);
        digit_2 = bcd_to_seg(bcd_in[11:8]);
        digit_3 = bcd_to_seg(bcd_in[15:12]);
    
    end
    
    always_comb begin
        digit = 16'd0;
        
        if(converter_out_0)
            digit = digit_0;
        
        else if(converter_out_1)
            digit = digit_1;
            
        else if(converter_out_2)
            digit = digit_2;
            
        else if(converter_out_3)
            digit = digit_3;
    
    end
    
    function logic [15:0] bcd_to_seg(input logic [3:0] bcd_in);
        begin
            case(bcd_in)
                4'd0: bcd_to_seg = 16'b0000000001000000;
                4'd1: bcd_to_seg = 16'b0000000001111001;
                4'd2: bcd_to_seg = 16'b0000000000100100; 
                4'd3: bcd_to_seg = 16'b0000000000110000; 
                4'd4: bcd_to_seg = 16'b0000000000011001;
                4'd5: bcd_to_seg = 16'b0000000000010010; 
                4'd6: bcd_to_seg = 16'b0000000000000010; 
                4'd7: bcd_to_seg = 16'b0000000001111000; 
                4'd8: bcd_to_seg = 16'b0000000000000000; 
                4'd9: bcd_to_seg = 16'b0000000000010000;
                default: bcd_to_seg = 16'h007F;
            endcase
        end
     endfunction
     
     
     

endmodule
