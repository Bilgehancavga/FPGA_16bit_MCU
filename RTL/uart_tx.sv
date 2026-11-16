module uart_tx #( parameter clk_freq = 100_000_000, parameter baud_rate = 9600 // system clock frequency(100 MHz), Target communication speed (Baud rate)
)(
   input logic clk, 
   input logic rst_n,                //Asynchronous active-low reset
   input logic starter,              // Pulse signal to initiate data transmission
   input logic [7:0] data,           // 8-bit parallel data input
   output logic tx_done,
   output logic tx_out_pin          // Serial TX output pin
);

localparam int counter_max = clk_freq/baud_rate;


typedef enum logic [1:0] {
    
    IDLE = 2'b00,   // Waiting for start signal
    START = 2'b01,  // Sending Start Bit (Logic 0)
    DATA = 2'b10,   // Serializing 8-bit data
    STOP = 2'b11    // Sending Stop Bit (Logic 1)

} states;

states current_state;

   logic ticks;                                     // Timing signal that indicates a full bit period has passed
   logic [$clog2(counter_max)-1:0] counter;         // Counter for the time 1 bit passes
   logic [2:0] bit_sequence;                        // Index tracker for the bit being transmitted (0 to 7)
   logic [7:0] data_packet;                         // Internal logic to store input data during transmission
   logic tx_out;
   
   
   // Baud Rate Generator: Generates a 'tick' signal at the  end of each bit duration
   always_ff @(posedge clk or negedge rst_n) begin
  // Reset and synchronize counter when transmission starts from IDLE
        if(!rst_n) begin
            counter <= 0;
            ticks <= 0;
        end
        else begin

            if (current_state == IDLE && starter) begin
                counter <= 0;
                ticks <= 0;
            end
            else if(counter == counter_max - 1) begin
                ticks <= 1;
                counter <= 0;            
            end
            else begin
                ticks <= 0;
                counter <= counter + 1;
            end
        end
   end
   
   
   // Main UART TX Control Logic (FSM)
   always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        current_state <= IDLE;
        bit_sequence <= 0;
        tx_done <= 1'b0;
        tx_out <= 1'b1; // UART transmitter pin must be Logic 1 (High) when idle
    end
    else begin
       case(current_state)
            IDLE: begin
                tx_out <= 1'b1; 
                bit_sequence <= 0;
                tx_done <= 1'b0;
                if(starter) begin
                    data_packet <= data;     // Buffer input data to prevent corruption during TX
                    current_state <= START;
                end
            end

            START: begin
                tx_out <= 1'b0; // Transmission starts with a Logic 0 (Start Bit)
                if(ticks) begin
                    current_state <= DATA; 
                end
            end

            DATA: begin
                tx_out <= data_packet[bit_sequence];  // Transmitting data bits (LSB First)
                
                if(ticks) begin
                    if(bit_sequence == 7) begin
                        current_state <= STOP;
                    end
                    else begin
                        bit_sequence <= bit_sequence + 1;
                    end
                end
            end

            STOP: begin
                tx_out <= 1'b1;      // Transmission ends with a Logic 1 (Stop Bit)
                if(ticks) begin
                    tx_done <= 1'b1;
                    current_state <= IDLE;
                end
            end
        endcase
    end
end

   assign tx_out_pin = tx_out;   // assigning internal signal to the output pin

endmodule