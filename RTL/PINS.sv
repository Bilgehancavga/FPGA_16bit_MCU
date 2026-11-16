module PINS(
    input logic clk,
    input logic rst_n,
    input logic pins_in_enable,
    input logic pins_out_enable,
    input logic direction_enable,
    input logic [15:0] write_data,
    output logic [15:0] read_data, // CPU'ya
  
    inout wire [15:0] pins
    
);

    logic [15:0] direction_reg;
    logic [15:0] output_reg;
    
    
    // Direction 
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            direction_reg <= 16'd0;
        else begin
            if(direction_enable)
                direction_reg <= write_data;
        end
    end
    
    // Output 
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            output_reg <= 16'd0;
        else
            if(pins_out_enable)
                output_reg <= write_data;
    end
    
    genvar i;
    
    generate
        for (i = 0; i < 16; i++) begin: GPIO_GEN

            assign pins[i] =direction_reg[i] ? output_reg[i] : 1'bz;

        end
    endgenerate
    
    //READ 
    always_comb begin
        read_data = 16'd0;
        
        if(pins_in_enable) begin
            for(int j=0; j<16; j++) begin
                if(!direction_reg[j])
                    read_data[j] = pins[j];
                else
                    read_data[j] = 1'b0;
            end
        end 
    end


endmodule
