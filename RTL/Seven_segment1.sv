module Seven_segment(
    input logic clk,
    input logic rst_n,
    input logic digits_enable,
    input logic segments_enable,
    input logic [15:0] data_in,
    output logic [6:0] data_out,
    output logic [7:0] anode,
    output logic dp
);

    logic [7:0] anode_register;
    logic [7:0] segment_register;
    
    
    
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            anode_register   <= 8'hff;
            segment_register <= 8'hff;
        end
        else begin
            if(digits_enable) 
                anode_register <= data_in[7:0];  
            
            if(segments_enable)
                segment_register <= data_in[7:0];
        
        end
    end
       
    
    assign anode    = anode_register;
    assign data_out = segment_register[6:0];
    assign dp       = segment_register[7];



endmodule
