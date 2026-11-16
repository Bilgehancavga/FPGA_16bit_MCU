module Address_Decoder(
    input logic port_enable,
    input logic [10:0] port_addr,
    
    //PINS
    output logic pins_in_enable,
    output logic pins_out_enable,
    output logic direction_enable,
    
    //LEDS 
    output logic leds_enable,
    
    //SW 
    output logic sw_enable,
    
    //BUTTONS 
    output logic button_enable,
    output logic button_interrupt_enable,
    output logic button_interrupt_disable,

    // DEBOUNCER
    output logic debouncer_enable,
    output logic debouncer_disable,
    
    //BINARY_TO_BCD 
    output logic binary_to_bcd_in_enable,
    output logic binary_to_bcd_out_enable,
    
    // BCD_TO_SEVENSEGMENT (CONVERTER)
    output logic converter_in_enable,
    output logic converter_out_0_enable,
    output logic converter_out_1_enable,
    output logic converter_out_2_enable,
    output logic converter_out_3_enable,
    
    // SEVEN_SEGMENTS
    output logic digits_enable,
    output logic segments_enable,
    
    // PWM 
    output logic pwm_enable,
    output  logic pwm_disable,
    output  logic pwm_prescaler_enable,
    output  logic pwm_duty_cycle_enable,
    
    // TIMER 
    output logic timer0_enable, 
    output logic timer0_disable, 
    output logic timer0_interrupt_enable,  
    output logic timer0_interrupt_disable,
    output logic timer0_prescaler_enable, 
    output logic timer0_max_value_enable,
    output logic timer0_clear,
    
    output logic timer1_enable, 
    output logic timer1_disable, 
    output logic timer1_interrupt_enable,  
    output logic timer1_interrupt_disable,
    output logic timer1_prescaler_enable, 
    output logic timer1_max_value_enable,
    output logic timer1_clear,
    
    output logic timer2_enable, 
    output logic timer2_disable, 
    output logic timer2_interrupt_enable,  
    output logic timer2_interrupt_disable,
    output logic timer2_prescaler_enable, 
    output logic timer2_max_value_enable,
    output logic timer2_clear,
    
    output logic timer3_enable, 
    output logic timer3_disable, 
    output logic timer3_interrupt_enable,  
    output logic timer3_interrupt_disable,
    output logic timer3_prescaler_enable, 
    output logic timer3_max_value_enable,
    output logic timer3_clear,
    
    output logic timer4_enable, 
    output logic timer4_disable, 
    output logic timer4_interrupt_enable,  
    output logic timer4_interrupt_disable,
    output logic timer4_prescaler_enable, 
    output logic timer4_max_value_enable,
    output logic timer4_clear,
    
    // Watchdog
    output logic watchdog_enable,
    output logic watchdog_disable,
    output logic watchdog_clear,
    output logic watchdog_prescaler_enable,
    output logic watchdog_max_value_enable,
    
    output logic timer0_read_enable,
    output logic timer1_read_enable,
    output logic timer2_read_enable,
    output logic timer3_read_enable,
    output logic timer4_read_enable,
    
    // INTERRUPT
    output logic interrupt_register_enable
    
    //SPI 
    
);

logic [6:0] addr;

assign addr = port_addr[6:0];

always_comb begin
    
        pins_in_enable = 1'b0;
        pins_out_enable = 1'b0;
        direction_enable = 1'b0;
    
        leds_enable = 1'b0;
        sw_enable = 1'b0;
    
        button_enable            = 1'b0;
        button_interrupt_enable  = 1'b0;
        button_interrupt_disable = 1'b0;
        
        debouncer_enable         = 1'b0;
        debouncer_disable        = 1'b0;
    
        binary_to_bcd_in_enable = 1'b0;
        binary_to_bcd_out_enable = 1'b0;
    
        converter_in_enable = 1'b0;
        converter_out_0_enable = 1'b0;
        converter_out_1_enable = 1'b0;
        converter_out_2_enable = 1'b0;
        converter_out_3_enable = 1'b0;
    
        digits_enable = 1'b0;
        segments_enable = 1'b0;
    
        pwm_enable = 1'b0;
        pwm_disable = 1'b0;
        pwm_prescaler_enable = 1'b0;
        pwm_duty_cycle_enable = 1'b0;
    
        timer0_enable = 1'b0;
        timer0_disable = 1'b0;
        timer0_interrupt_enable = 1'b0;
        timer0_interrupt_disable = 1'b0;
        timer0_prescaler_enable = 1'b0;
        timer0_max_value_enable = 1'b0;
        
        timer1_enable = 1'b0;
        timer1_disable = 1'b0;
        timer1_interrupt_enable = 1'b0;
        timer1_interrupt_disable = 1'b0;
        timer1_prescaler_enable = 1'b0;
        timer1_max_value_enable = 1'b0;
        
        timer2_enable = 1'b0;
        timer2_disable = 1'b0;
        timer2_interrupt_enable = 1'b0;
        timer2_interrupt_disable = 1'b0;
        timer2_prescaler_enable = 1'b0;
        timer2_max_value_enable = 1'b0;
        
        timer3_enable = 1'b0;
        timer3_disable = 1'b0;
        timer3_interrupt_enable = 1'b0;
        timer3_interrupt_disable = 1'b0;
        timer3_prescaler_enable = 1'b0;
        timer3_max_value_enable = 1'b0;
        
        timer4_enable = 1'b0;
        timer4_disable = 1'b0;
        timer4_interrupt_enable = 1'b0;
        timer4_interrupt_disable = 1'b0;
        timer4_prescaler_enable = 1'b0;
        timer4_max_value_enable = 1'b0;
        
        timer0_clear = 1'b0;
        timer1_clear = 1'b0;
        timer2_clear = 1'b0;
        timer3_clear = 1'b0;
        timer4_clear = 1'b0;
        
        timer0_read_enable = 1'b0;
        timer1_read_enable = 1'b0;
        timer2_read_enable = 1'b0;
        timer3_read_enable = 1'b0;
        timer4_read_enable = 1'b0;
        
        watchdog_enable = 1'b0;
        watchdog_disable = 1'b0;
        watchdog_clear  = 1'b0;
        watchdog_prescaler_enable = 1'b0;
        watchdog_max_value_enable = 1'b0;
        
        interrupt_register_enable = 1'b0;
    
        if(port_enable) begin
        
            case(addr)       
               //PINS 
               7'b0000001:  pins_in_enable   = 1'b1;
               7'b0000010:  pins_out_enable  = 1'b1;
               7'b0000011:  direction_enable = 1'b1;
               
               //LEDS 
               7'b0000100:  leds_enable = 1'b1;
               
               //SW 
               7'b0000101:  sw_enable = 1'b1;
               
               //BUTTONS 
               7'd6:  button_enable            = 1'b1;
               7'd7:  button_interrupt_enable  = 1'b1;
               7'd8:  button_interrupt_disable = 1'b1;
                
               7'd9:  debouncer_enable         = 1'b1;
               7'd10: debouncer_disable        = 1'b1;
               
               //BINARY_TO_BCD 
               7'b0010101: binary_to_bcd_in_enable = 1'b1;
               7'b0010110: binary_to_bcd_out_enable = 1'b1;
               
               // BCD_TO_SEVENSEGMENT (CONVERTER)
               7'b0010111: converter_in_enable = 1'b1;
               7'b0011000: converter_out_0_enable = 1'b1;
               7'b0011001: converter_out_1_enable = 1'b1;
               7'b0011010: converter_out_2_enable = 1'b1;
               7'b0011011: converter_out_3_enable = 1'b1;
               
               //SEVEN_SEGMENT 
               7'b0011100: digits_enable = 1'b1;
               7'b0011101: segments_enable = 1'b1;
               
               // PWM
               7'b0100000: pwm_enable = 1'b1;
               7'b0100001: pwm_disable = 1'b1;
               7'b0100010: pwm_prescaler_enable = 1'b1;
               7'b0100011: pwm_duty_cycle_enable = 1'b1;
               
               // TIMER 0
                7'b0100100: timer0_enable             = 1'b1; // 36
                7'b0100101: timer0_disable            = 1'b1; // 37
                7'b0100110: timer0_interrupt_enable   = 1'b1; // 38
                7'b0100111: timer0_interrupt_disable  = 1'b1; // 39
                7'b0101000: timer0_prescaler_enable   = 1'b1; // 40
                7'b0101001: timer0_max_value_enable   = 1'b1; // 41
                
                // TIMER 1
                7'b0101010: timer1_enable             = 1'b1; // 42
                7'b0101011: timer1_disable            = 1'b1; // 43
                7'b0101100: timer1_interrupt_enable   = 1'b1; // 44
                7'b0101101: timer1_interrupt_disable  = 1'b1; // 45
                7'b0101110: timer1_prescaler_enable   = 1'b1; // 46
                7'b0101111: timer1_max_value_enable   = 1'b1; // 47
                
                // TIMER 2
                7'b0110000: timer2_enable             = 1'b1; // 48
                7'b0110001: timer2_disable            = 1'b1; // 49
                7'b0110010: timer2_interrupt_enable   = 1'b1; // 50
                7'b0110011: timer2_interrupt_disable  = 1'b1; // 51
                7'b0110100: timer2_prescaler_enable   = 1'b1; // 52
                7'b0110101: timer2_max_value_enable   = 1'b1; // 53
                
                // TIMER 3
                7'b0110110: timer3_enable             = 1'b1; // 54
                7'b0110111: timer3_disable            = 1'b1; // 55
                7'b0111000: timer3_interrupt_enable   = 1'b1; // 56
                7'b0111001: timer3_interrupt_disable  = 1'b1; // 57
                7'b0111010: timer3_prescaler_enable   = 1'b1; // 58
                7'b0111011: timer3_max_value_enable   = 1'b1; // 59
                
                // TIMER 4
                7'b0111100: timer4_enable             = 1'b1; // 60
                7'b0111101: timer4_disable            = 1'b1; // 61
                7'b0111110: timer4_interrupt_enable   = 1'b1; // 62
                7'b0111111: timer4_interrupt_disable  = 1'b1; // 63
                7'b1000000: timer4_prescaler_enable   = 1'b1; // 64
                7'b1000001: timer4_max_value_enable   = 1'b1; // addr 
                
                // Watchdog 
                7'b1000010: watchdog_enable            = 1'b1;
                7'b1000011: watchdog_clear             = 1'b1;
                7'b1000100: watchdog_prescaler_enable  = 1'b1;
                7'b1000101: watchdog_max_value_enable  = 1'b1;
                7'b1000110: watchdog_disable           = 1'b1;
                
                // INTERRUPT 
                7'b1000111: interrupt_register_enable = 1'b1;
                
                7'd72: timer0_clear = 1'b1;
                7'd73: timer1_clear = 1'b1;
                7'd74: timer2_clear = 1'b1;
                7'd75: timer3_clear = 1'b1;
                7'd76: timer4_clear = 1'b1;
                
                7'd77: timer0_read_enable = 1'b1;
                7'd78: timer1_read_enable = 1'b1;
                7'd79: timer2_read_enable = 1'b1;
                7'd80: timer3_read_enable = 1'b1;
                7'd81: timer4_read_enable = 1'b1;
                       
                       
       
            endcase
        end
end

endmodule
