module Decoder(
    input  logic clk,
    input  logic rst_n,
    input  logic pipeline_flush,
    input  logic [47:0] machine_code,
    output logic [5:0] op_code,
    output logic [4:0] Rd,
    output logic [4:0] Rs1,
    output logic [4:0] Rs2,
    output logic [15:0] Immediate,
    output logic [10:0] Address
);
    
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            op_code           <= 0;
            Rd                <= 0;
            Rs1               <= 0;
            Rs2               <= 0;
            Immediate         <= 0;
            Address           <= 0;
        end 
        else begin
            if(pipeline_flush) begin
                op_code           <= 0;
                Rd                <= 0;
                Rs1               <= 0;
                Rs2               <= 0;
                Immediate         <= 0;
                Address           <= 0;
            end 
            else begin
                op_code           <= machine_code[47:42];
                Rd                <= machine_code[41:37];
                Rs1               <= machine_code[36:32];
                Rs2               <= machine_code[31:27];
                Immediate         <= machine_code[26:11];
                Address           <= machine_code[10:0];
            end
        end
    end
    
endmodule
