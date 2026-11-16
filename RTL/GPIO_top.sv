module GPIO_top(
    input logic clk,
    input logic rst_n,
    input logic port_enable,
    input logic [10:0] port_addr,
    
    // COMMON i/o
    input  logic [15:0] write_data,
    output logic [15:0] read_data,
    
    // PINS 
    inout wire [15:0] pins,
    
    // LED 
    output logic [15:0] led_out,
    
    //Switches 
    input logic [15:0] sws,
    
    //Seven_segments 
    output logic [6:0] data_out,
    output logic [7:0] anode,
    output logic       dp,
    
    //BUTTONS 
    input  logic [4:0] btn_in,
    output logic [4:0] button_interrupt_data,
    
    // TIMER
    output logic timer0_interrupt_out,
    output logic timer1_interrupt_out,
    output logic timer2_interrupt_out,
    output logic timer3_interrupt_out,
    output logic timer4_interrupt_out,
    output logic interrupt_register_enable_out,
    
    // PWM 
    output logic pwm_pin,
    
    // WATCHDOG 
    output logic watchdog_reset

);

    //PINS
    logic pins_in_enable;
    logic pins_out_enable;
    logic direction_enable;
    logic [15:0] pins_read_data;
    
    //LEDS 
    logic leds_enable;
    
    //SW 
    logic sw_enable;
    logic [15:0] switches_read_data;
    
    // BUTTON
    logic button_enable;
    logic button_interrupt_enable;
    logic button_interrupt_disable;
    logic [4:0] button_data;
    
    //DEBOUNCER 
    logic debouncer_enable;
    logic debouncer_disable;
    logic [4:0] debounced_btn;

    
    //BINARY_TO_BCD 
    logic binary_to_bcd_in_enable;
    logic binary_to_bcd_out_enable;
    logic [15:0] binary_to_bcd_read_data;
    
    // BCD_TO_SEVENSEGMENT (CONVERTER)
    logic converter_in_enable;
    logic converter_out_0_enable;
    logic converter_out_1_enable;
    logic converter_out_2_enable;
    logic converter_out_3_enable;
    logic [15:0] converter_read_data;
    
    // SEVEN_SEGMENTS
    logic digits_enable;
    logic segments_enable;
    
    // PWM 
    logic pwm_enable;
    logic pwm_disable;
    logic pwm_prescaler_enable;
    logic pwm_duty_cycle_enable;
    
    // TIMER 
    logic timer0_enable;
    logic timer0_disable;
    logic timer0_interrupt_enable;
    logic timer0_interrupt_disable;
    logic timer0_prescaler_enable;
    logic timer0_max_value_enable;
    logic timer0_clear;
    logic [15:0] timer0_value;
    logic        timer0_interrupt;
    logic timer0_read_enable;   
    
    
    logic timer1_enable;
    logic timer1_disable; 
    logic timer1_interrupt_enable; 
    logic timer1_interrupt_disable;
    logic timer1_prescaler_enable;
    logic timer1_max_value_enable;
    logic [15:0] timer1_value;
    logic timer1_interrupt;
    
    logic timer1_read_enable;
    
    logic timer2_enable;
    logic timer2_disable; 
    logic timer2_interrupt_enable;
    logic timer2_interrupt_disable;
    logic timer2_prescaler_enable;
    logic timer2_max_value_enable;
    logic [15:0] timer2_value;
    logic timer2_interrupt;
    
    logic timer2_read_enable;
    
    logic timer3_enable;
    logic timer3_disable; 
    logic timer3_interrupt_enable;
    logic timer3_interrupt_disable;
    logic timer3_prescaler_enable;
    logic timer3_max_value_enable;
    logic [15:0] timer3_value;
    logic timer3_interrupt;
    
    logic timer3_read_enable;

    logic timer4_enable;
    logic timer4_disable; 
    logic timer4_interrupt_enable;
    logic timer4_interrupt_disable;
    logic timer4_prescaler_enable;
    logic timer4_max_value_enable;
    logic [15:0] timer4_value;
    logic timer4_interrupt;
    
    logic timer4_read_enable;
    
    logic timer1_clear;
    logic timer2_clear;
    logic timer3_clear;
    logic timer4_clear;
     
    // Watchdog
    logic watchdog_enable;
    logic watchdog_disable;
    logic watchdog_clear;
    logic watchdog_prescaler_enable;
    logic watchdog_max_value_enable;
    
    // INTERRUPT
    logic interrupt_register_enable;
    
    
    // ------- MODULES

    Address_Decoder Address_Decoder(
        .port_enable(port_enable),
        .port_addr(port_addr),

        // PINS
        .pins_in_enable(pins_in_enable),
        .pins_out_enable(pins_out_enable),
        .direction_enable(direction_enable),

        // LEDS
        .leds_enable(leds_enable),

        // SWITCHES
        .sw_enable(sw_enable),

        // BUTTONS
        .button_enable(button_enable),
        .button_interrupt_enable(button_interrupt_enable),
        .button_interrupt_disable(button_interrupt_disable),
        
        // DEBOUNCER
        .debouncer_enable(debouncer_enable),
        .debouncer_disable(debouncer_disable),

        // BINARY TO BCD
        .binary_to_bcd_in_enable(binary_to_bcd_in_enable),
        .binary_to_bcd_out_enable(binary_to_bcd_out_enable),

        // BCD TO SEVEN SEGMENT
        .converter_in_enable(converter_in_enable),
        .converter_out_0_enable(converter_out_0_enable),
        .converter_out_1_enable(converter_out_1_enable),
        .converter_out_2_enable(converter_out_2_enable),
        .converter_out_3_enable(converter_out_3_enable),

        // SEVEN SEGMENT
        .digits_enable(digits_enable),
        .segments_enable(segments_enable),

        // PWM
        .pwm_enable(pwm_enable),
        .pwm_disable(pwm_disable),
        .pwm_prescaler_enable(pwm_prescaler_enable),
        .pwm_duty_cycle_enable(pwm_duty_cycle_enable),

        // TIMER 0
        .timer0_enable(timer0_enable),
        .timer0_disable(timer0_disable),
        .timer0_interrupt_enable(timer0_interrupt_enable),
        .timer0_interrupt_disable(timer0_interrupt_disable),
        .timer0_prescaler_enable(timer0_prescaler_enable),
        .timer0_max_value_enable(timer0_max_value_enable),
        .timer0_clear(timer0_clear),
        .timer0_read_enable(timer0_read_enable),
        

        // TIMER 1
        .timer1_enable(timer1_enable),
        .timer1_disable(timer1_disable),
        .timer1_interrupt_enable(timer1_interrupt_enable),
        .timer1_interrupt_disable(timer1_interrupt_disable),
        .timer1_prescaler_enable(timer1_prescaler_enable),
        .timer1_max_value_enable(timer1_max_value_enable),
        .timer1_clear(timer1_clear),
        .timer1_read_enable(timer1_read_enable),

        // TIMER 2
        .timer2_enable(timer2_enable),
        .timer2_disable(timer2_disable),
        .timer2_interrupt_enable(timer2_interrupt_enable),
        .timer2_interrupt_disable(timer2_interrupt_disable),
        .timer2_prescaler_enable(timer2_prescaler_enable),
        .timer2_max_value_enable(timer2_max_value_enable),
        .timer2_clear(timer2_clear),
        .timer2_read_enable(timer2_read_enable),


        // TIMER 3
        .timer3_enable(timer3_enable),
        .timer3_disable(timer3_disable),
        .timer3_interrupt_enable(timer3_interrupt_enable),
        .timer3_interrupt_disable(timer3_interrupt_disable),
        .timer3_prescaler_enable(timer3_prescaler_enable),
        .timer3_max_value_enable(timer3_max_value_enable),
        .timer3_clear(timer3_clear),
        .timer3_read_enable(timer3_read_enable),

        // TIMER 4
        .timer4_enable(timer4_enable),
        .timer4_disable(timer4_disable),
        .timer4_interrupt_enable(timer4_interrupt_enable),
        .timer4_interrupt_disable(timer4_interrupt_disable),
        .timer4_prescaler_enable(timer4_prescaler_enable),
        .timer4_max_value_enable(timer4_max_value_enable),
        .timer4_clear(timer4_clear),
        .timer4_read_enable(timer4_read_enable),
        
        // WATCHDOG
        .watchdog_enable(watchdog_enable),
        .watchdog_disable(watchdog_disable),
        .watchdog_clear(watchdog_clear),
        .watchdog_prescaler_enable(watchdog_prescaler_enable),
        .watchdog_max_value_enable(watchdog_max_value_enable),

        // INTERRUPT
        .interrupt_register_enable(interrupt_register_enable)
    );

        // PINS 
        PINS PINS(
            .clk(clk),
            .rst_n(rst_n),
        
            .pins_in_enable(pins_in_enable),
            .pins_out_enable(pins_out_enable),
            .direction_enable(direction_enable),
        
            .write_data(write_data),
            .read_data(pins_read_data),
        
            .pins(pins)
        );

        // LED 
        LED LED(
            .clk(clk),
            .rst_n(rst_n),
    
            .led_enable(leds_enable),
            .write_data(write_data),
    
            .led_out(led_out)
        );
            
        // SWITCHES 
        SW SW(
            .sw_enable(sw_enable),
            .sws(sws),
            .sw_data(switches_read_data)    
        );
        
        // Seven_segment
        Seven_segment Seven_segment(
            .clk(clk),
            .rst_n(rst_n),
        
            .digits_enable(digits_enable),
            .segments_enable(segments_enable),
        
            .data_in(write_data),
        
            .data_out(data_out),
            .anode(anode),
            .dp(dp)
        ); 
       
        
        // BINARY_TO_BCD (Converter)
         BCD_to_sevensegment BCD_to_sevensegment(
            .clk(clk),
            .rst_n(rst_n),
        
            .converter_in(converter_in_enable),
            .converter_out_0(converter_out_0_enable),
            .converter_out_1(converter_out_1_enable),
            .converter_out_2(converter_out_2_enable),
            .converter_out_3(converter_out_3_enable),
        
            .bcd(write_data),
            .digit(converter_read_data)
         );
         
         Binary_to_BCD Binary_to_BCD(
            .clk(clk),
            .rst_n(rst_n),
        
            .enable_in(binary_to_bcd_in_enable),
            .enable_out(binary_to_bcd_out_enable),
        
            .binary_in(write_data),
            .bcd_out(binary_to_bcd_read_data)
        );
        
        BUTTON BUTTON(
            .clk(clk),
            .rst_n(rst_n),
        
            .button_enable(button_enable),
            .button_interrupt_enable(button_interrupt_enable),
            .button_interrupt_disable(button_interrupt_disable),
        
            .btn_in(debounced_btn),
        
            .btn_out(button_data),  
            .btn_interrupt_out(button_interrupt_data)
        );
        
        

        debouncer_edgedetector DB_U (
            .clk(clk),
            .rst_n(rst_n),
            .db_enable(debouncer_enable),
            .db_disable(debouncer_disable),
            .btn_in(btn_in[0]),
            .btn_out(debounced_btn[0])
        );
        
        debouncer_edgedetector DB_L (
            .clk(clk),
            .rst_n(rst_n),
            .db_enable(debouncer_enable),
            .db_disable(debouncer_disable),
            .btn_in(btn_in[1]),
            .btn_out(debounced_btn[1])
        );
        
        debouncer_edgedetector DB_C(
            .clk(clk),
            .rst_n(rst_n),
            .db_enable(debouncer_enable),
            .db_disable(debouncer_disable),
            .btn_in(btn_in[2]),
            .btn_out(debounced_btn[2])
        );
        
        debouncer_edgedetector DB_R(
            .clk(clk),
            .rst_n(rst_n),
            .db_enable(debouncer_enable),
            .db_disable(debouncer_disable),
            .btn_in(btn_in[3]),
            .btn_out(debounced_btn[3])
        );
        
        debouncer_edgedetector DB_D(
            .clk(clk),
            .rst_n(rst_n),
            .db_enable(debouncer_enable),
            .db_disable(debouncer_disable),
            .btn_in(btn_in[4]),
            .btn_out(debounced_btn[4])
        );
        
        // TIMER 0
        Timer Timer0(
            .clk(clk),
            .rst_n(rst_n),
        
            .timer_clear(timer0_clear),
            .timer_enable(timer0_enable),
            .timer_disable(timer0_disable),
        
            .interrupt_enable(timer0_interrupt_enable),
            .interrupt_disable(timer0_interrupt_disable),
        
            .prescaler_enable(timer0_prescaler_enable),
            .max_value_enable(timer0_max_value_enable),
        
            .write_data(write_data),
        
            .timer_value(timer0_value),
            .timer_interrupt(timer0_interrupt),
            
            .read_enable(timer0_read_enable)
        );


        // TIMER 1
        Timer Timer1(
            .clk(clk),
            .rst_n(rst_n),
        
            .timer_clear(timer1_clear),
            .timer_enable(timer1_enable),
            .timer_disable(timer1_disable),
        
            .interrupt_enable(timer1_interrupt_enable),
            .interrupt_disable(timer1_interrupt_disable),
        
            .prescaler_enable(timer1_prescaler_enable),
            .max_value_enable(timer1_max_value_enable),
        
            .write_data(write_data),
        
            .timer_value(timer1_value),
            .timer_interrupt(timer1_interrupt),
            
            .read_enable(timer1_read_enable)
        );
        
        
        // TIMER 2
        Timer Timer2(
            .clk(clk),
            .rst_n(rst_n),
        
            .timer_clear(timer2_clear),
            .timer_enable(timer2_enable),
            .timer_disable(timer2_disable),
        
            .interrupt_enable(timer2_interrupt_enable),
            .interrupt_disable(timer2_interrupt_disable),
        
            .prescaler_enable(timer2_prescaler_enable),
            .max_value_enable(timer2_max_value_enable),
        
            .write_data(write_data),
        
            .timer_value(timer2_value),
            .timer_interrupt(timer2_interrupt),
            
            .read_enable(timer2_read_enable)
            
        );
        
        
        // TIMER 3
        Timer Timer3(
            .clk(clk),
            .rst_n(rst_n),
        
            .timer_clear(timer3_clear),
            .timer_enable(timer3_enable),
            .timer_disable(timer3_disable),
        
            .interrupt_enable(timer3_interrupt_enable),
            .interrupt_disable(timer3_interrupt_disable),
        
            .prescaler_enable(timer3_prescaler_enable),
            .max_value_enable(timer3_max_value_enable),
        
            .write_data(write_data),
        
            .timer_value(timer3_value),
            .timer_interrupt(timer3_interrupt),
            
            .read_enable(timer3_read_enable)
        );
        
        
        // TIMER 4
        Timer Timer4(
            .clk(clk),
            .rst_n(rst_n),
        
            .timer_clear(timer4_clear),
            .timer_enable(timer4_enable),
            .timer_disable(timer4_disable),
        
            .interrupt_enable(timer4_interrupt_enable),
            .interrupt_disable(timer4_interrupt_disable),
        
            .prescaler_enable(timer4_prescaler_enable),
            .max_value_enable(timer4_max_value_enable),
        
            .write_data(write_data),
        
            .timer_value(timer4_value),
            .timer_interrupt(timer4_interrupt),
            
            .read_enable(timer4_read_enable)
        );   
        
        
        // PWM
        PWM PWM(
            .clk(clk),
            .rst_n(rst_n),
        
            .pwm_enable(pwm_enable),
            .pwm_disable(pwm_disable),
            .pwm_prescaler_enable(pwm_prescaler_enable),
            .pwm_duty_cycle_enable(pwm_duty_cycle_enable),
        
            .write_data(write_data),
        
            .pin(pwm_pin)
        );
        
        // WATCHDOG
        Watchdog Watchdog(
            .clk(clk),
            .rst_n(rst_n),
        
            .watchdog_enable(watchdog_enable),
            .watchdog_disable(watchdog_disable),
            .watchdog_clear(watchdog_clear),
        
            .prescaler_enable(watchdog_prescaler_enable),
            .max_value_enable(watchdog_max_value_enable),
        
            .write_data(write_data),
        
            .reset(watchdog_reset)
        );
        
        always_comb begin
            read_data = 16'd0;
        
            if (pins_in_enable)
                read_data = pins_read_data;
        
            else if (sw_enable)
                read_data = switches_read_data;
        
            else if (button_enable)
                read_data = {11'd0, button_data};
        
            else if (binary_to_bcd_out_enable)
                read_data = binary_to_bcd_read_data;
        
            else if (converter_out_0_enable ||
                     converter_out_1_enable ||
                     converter_out_2_enable ||
                     converter_out_3_enable)
                read_data = converter_read_data;
        
            else if (timer0_read_enable)
                read_data = timer0_value;
        
            else if (timer1_read_enable)
                read_data = timer1_value;
        
            else if (timer2_read_enable)
                read_data = timer2_value;
        
            else if (timer3_read_enable)
                read_data = timer3_value;
        
            else if (timer4_read_enable)
                read_data = timer4_value;
        
            else
                read_data = 16'd0;
        end


    assign timer0_interrupt_out = timer0_interrupt;
    assign timer1_interrupt_out = timer1_interrupt;
    assign timer2_interrupt_out = timer2_interrupt;
    assign timer3_interrupt_out = timer3_interrupt;
    assign timer4_interrupt_out = timer4_interrupt;
    
    assign interrupt_register_enable_out = interrupt_register_enable;
        
        
endmodule
