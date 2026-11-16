module uart_rx #(parameter clk_freq = 100_000_000, parameter baud_rate = 9600) // system clock frequency(100 MHz), Target communication speed (Baud rate)

    (
    input logic clk,
    input logic rst_n,
    input logic rx_in_pin,      // Physical RX input pin
    output logic [7:0] data,    // Received 8-bit parallel data
    output logic rx_done,       // Pulse signal indicating data reception is complete
    output logic framing_err    // High if Stop Bit is not Logic 1
    );
    
// 16x Oversampling: Each bit is divided into 16 ticks for stable sampling
localparam counter_max = (clk_freq / baud_rate)/16; 

typedef enum logic[1:0]  {

    IDLE = 2'b00,
    START = 2'b01,
    DATA = 2'b10,
    STOP = 2'b11 
} states; 

states current_state;

logic ticks;
logic [$clog2(counter_max)-1:0] counter;
logic [4:0] counter2; // Tick counter (0 to 15) to track bit center
logic [7:0] bit_sequence;   // Index for the 8 data bits
logic [7:0] data_packet;    // Buffer for incoming bits
logic [3:0] bit_sample;     // Storage for 3 samples to perform majority voting

// Double Registering to prevent metastability
logic rx_in1, rx_in2;
always_ff @(posedge clk) begin

    rx_in1 <= rx_in_pin;
    rx_in2 <= rx_in1;

end

// Tick Generator for 16x Oversampling
always_ff @(posedge clk or negedge rst_n) begin

    if(!rst_n) begin
        counter <= 0;
        ticks <= 0;
    end

    else begin
        if (current_state == IDLE)
            counter <= 0;
        else if (counter == counter_max-1) begin
            ticks <= 1;
            counter <= 0;
        end
        else begin
            ticks <= 0;
            counter <= counter + 1;
        end
    end
end    


// Tick Counter: Tracks our position (0-15) within a single bit period
always @(posedge clk or negedge rst_n) begin

    if(!rst_n) begin
        counter2 <= 0;
    end
    else begin
        if(current_state == IDLE)
            counter2 <= 0;     
            
       else if(ticks) begin
       
            if (counter2 == 15)
                counter2 <= 0;
            else 
                counter2 <= counter2 + 1;
        end
    end
end

// UART RX Finite State Machine
always_ff @(posedge clk or negedge rst_n) begin

    if(!rst_n) begin

        current_state <= IDLE;
        bit_sequence <= 0;
        data_packet <= 0;
        data <= 0;
        rx_done <= 0;
        framing_err <= 0;
        
    end

    else begin 

        case(current_state)

            IDLE: begin

                bit_sequence <= 0;
                rx_done <= 0;
                if(!rx_in2) // Start bit detection (Falling edge)
                    current_state <= START;

            end

            START: begin
                // Wait for the end of the Start Bit to align timing
                if(ticks == 1 && counter2 == 15) 
                    current_state <= DATA;
            end

            DATA: begin
                // Sampling at the 6th, 7th, and 8th ticks (near the bit center)
                if (ticks == 1 && counter2 == 6)
                    bit_sample[0] <= rx_in2; 

                else if (ticks == 1 && counter2 == 7)
                    bit_sample[1] <= rx_in2;

                   
                else if(ticks == 1 && counter2 == 8)
                    bit_sample[2] <= rx_in2;

               // At the end of the bit period, decide the bit value and store it
                if (ticks == 1 && counter2 == 15)  begin
                   data_packet[bit_sequence] <= bit_sample[3]; 
                      
                    if (bit_sequence == 7)
                        current_state <= STOP;
                        
                    else begin
                        bit_sequence <= bit_sequence + 1;
                    
                    end 
                end
            end

                

            

            STOP: begin

                if(ticks == 1 && counter2 == 15) begin
                    if(rx_in2 == 1'b1) begin    // Check if Stop Bit is valid (Logic 1)
                        data <= data_packet;
                        rx_done <= 1'b1;
                        framing_err <= 1'b0;

                   end

                   else begin
                        rx_done <= 1'b0;
                        framing_err <= 1'b1;    // Stop Bit error detected
                   end  
                        current_state <= IDLE;
               end
           end
            default: current_state <= IDLE;

        endcase
    end

end    

// Majority Voting for sampling bit
assign bit_sample[3] = (bit_sample[0] & bit_sample[1]) | (bit_sample[0] & bit_sample[2]) | (bit_sample[2] & bit_sample[1]);

    

endmodule