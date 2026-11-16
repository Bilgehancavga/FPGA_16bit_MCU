module Binary_to_BCD(
    input logic clk,
    input logic rst_n,
    input logic enable_in,
    input logic enable_out,
    input logic [15:0] binary_in,
    output logic [15:0] bcd_out
);
    
    logic [15:0] bcd_register;
    logic [15:0] bcd;

    logic [35:0] shift;
    integer i;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            bcd_register <= 16'd0;    
        end
        else begin
            if(enable_in) 
                bcd_register <= bcd;
            
        end
    
    end
    
    
    always_comb begin
        shift = 36'd0;
        
        if(enable_in) begin
        
            shift[15:0] = binary_in;
            
            for(i=0; i<16; i=i+1) begin
                if(shift[19:16] >= 4'd5)
                   shift[19:16] = shift[19:16] + 4'd3;   
                
                if(shift[23:20] >= 4'd5)
                   shift[23:20] = shift[23:20] + 4'd3;
                   
                if(shift[27:24] >= 4'd5)
                   shift[27:24] = shift[27:24] + 4'd3;     
            
                if(shift[31:28] >= 4'd5)
                   shift[31:28] = shift[31:28] + 4'd3;
                   
                if(shift[35:32] >= 4'd5)
                   shift[35:32] = shift[35:32] + 4'd3;
                
                shift = shift << 1;
            end
            bcd = shift[31:16];
        end
        else
            bcd = 16'd0;
       
    end
    
    assign bcd_out = (enable_out) ? bcd_register : 16'd0;
    

endmodule
