module write_back_mux(
    input logic [15:0] alu_result,
    input logic [15:0] memory_data,
    input logic [15:0] port_data,
    input logic [15:0] immediate,
    input logic [1:0]  wb_sel,
    output logic [15:0] write_data
);

always_comb begin
    case(wb_sel)
        2'b00: write_data = alu_result;
        2'b01: write_data = memory_data;
        2'b10: write_data = port_data;
        2'b11: write_data = immediate;
        default: write_data = 16'd0;
    endcase
end


endmodule
