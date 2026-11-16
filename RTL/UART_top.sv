module UART_top (
    input  logic clk, rst_n,
    input starter,
    input [7:0] data_in,
    input  logic rx_pin,       // External RX input line
    output logic tx_pin,       // External TX output line
    output logic rx_done,          // Status LED: Glows when data is successfully received
    output logic tx_done,
    output logic framing_err,
    output logic [7:0] data_out    // LED output to display either SW status or received data
);
    
    
    // UART Receiver: Obtains incoming serial data from PC
    uart_rx RX (
        .clk(clk),
        .rst_n(rst_n), 
        .rx_in_pin(rx_pin),
        .data(data_out), 
        .framing_err(framing_err),
        .rx_done(rx_done)
    );
    
    // UART Transmitter: Sends data from switches to the PC
    uart_tx TX (
        .clk(clk), 
        .rst_n(rst_n), 
        .starter(starter), 
        .data(data_in),
        .tx_done(tx_done), 
        .tx_out_pin(tx_pin)
    );
    
    // LEDs display Switch values in TX mode, and Received Data in RX mode
    

endmodule