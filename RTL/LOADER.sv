module LOADER(
    input  logic        clk,
    input  logic        UART_done,
    input  logic [7:0]  uart_data,
    
    output logic        loader_reset,
    output logic        CPU_enable,
    output logic        flash_write_enable,
    output logic        flash_read_enable,
    output logic [10:0] flash_write_address,
    output logic [47:0] machine_code
);

    localparam logic [63:0] RUN_PACKET  = 64'hFFFF_FFFF_FFFF_FFFF;
    localparam logic [63:0] LOAD_PACKET = 64'h0000_0000_0000_0000;

    typedef enum logic {
        LOAD,
        RUN
    } state_t;

    state_t current_state;

    logic [63:0] packet;
    logic [3:0]  packet_sequence;
    logic [63:0] complete_packet;

    assign complete_packet = {packet[55:0], uart_data};

    initial begin
            loader_reset        = 1'b0;
            current_state       = LOAD;
            packet              = 64'd0;
            packet_sequence     = 4'd0;
            CPU_enable          = 1'b0;
            flash_write_enable  = 1'b0;
            flash_read_enable   = 1'b0;
            flash_write_address = 11'd0;
            machine_code        = 48'd0;

        end



    always @(posedge clk) begin
            
            flash_write_enable <= 1'b0;

            case (current_state)

                LOAD: begin
                    loader_reset      <= 1'b0;
                    CPU_enable        <= 1'b0;
                    flash_read_enable <= 1'b0;

                    if (UART_done) begin
                        packet <= complete_packet;
                        packet_sequence <= packet_sequence + 1'b1;
                    end
                    
                    if (packet_sequence == 4'd8) begin
                        packet_sequence <= 4'd0;
                        packet          <= 64'd0;
   
                        if (packet == RUN_PACKET) begin
                            current_state <= RUN;

                        end
                        else begin
                            flash_write_address <= packet[58:48];
                            machine_code        <= packet[47:0];
                            flash_write_enable  <= 1'b1;
                        end                         
                    end
                end


           
                RUN: begin

                    CPU_enable        <= 1'b1;
                    flash_read_enable <= 1'b1;

                    if (UART_done) begin
                        packet <= complete_packet;
                        packet_sequence <= packet_sequence + 1'b1;
                    end

                    if (packet_sequence == 4'd8) begin
                        packet_sequence <= 4'd0;
                        packet          <= 64'd0;
                           
                        if (packet == LOAD_PACKET) begin
                            loader_reset <= 1'b1;
                            CPU_enable   <= 1'b0;
                            current_state <= LOAD; 
                        end
                    end
                        
                end


                default: begin
                    current_state   <= LOAD;
                    packet          <= 64'd0;
                    packet_sequence <= 4'd0;
                    CPU_enable         <= 1'b0;
                    flash_read_enable  <= 1'b0;
                    flash_write_enable <= 1'b0;
                end

            endcase
        end
    

endmodule