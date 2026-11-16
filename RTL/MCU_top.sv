module MCU_top(
    input  logic        clk,
    input  logic        button_reset,

    // UART
    input  logic uart_rx,
    output logic uart_framing_err,

    // PINS
    inout  wire [15:0]  pins,

    // LED
    output logic [15:0] led_out,

    // SWITCHES
    input  logic [15:0] sws,

    // SEVEN SEGMENT 
    output logic [6:0]  seven_segment,
    output logic [7:0]  anode,
    output logic        dp,

    // BUTTONS
    input  logic [4:0]  btn_in,

    // PWM
    output logic        pwm_pin
);
    
    
    // CPU
    logic CPU_enable;
    logic [47:0] machine_code;
    logic [10:0] PC;
    
    
    // LOADER 
    logic        UART_done;
    logic [7:0]  uart_data;
    logic        flash_write_enable;
    logic        flash_read_enable;
    logic [10:0] flash_write_address;
    logic [47:0] loader_machine_code;
    
    logic        loader_reset;
    
    
    // RAM 
    logic [15:0] ram_data;
    logic        ram_read_en;
    logic [0:0]  ram_write_en;
    logic [7:0]  ram_addr;
    logic [15:0] data_ram_out;
    
    
    // GPIO_top 
    logic [15:0] port_data_out;
    logic [15:0] port_data_in;
    logic        port_enable;
    logic [10:0] port_addr;
    
    logic [4:0] button_interrupt_data;
    
    logic timer0_interrupt;
    logic timer1_interrupt;
    logic timer2_interrupt;
    logic timer3_interrupt;
    logic timer4_interrupt;
    
    logic interrupt_register_enable;
    logic watchdog_reset;
    
    
    // INTERRUPT CONTROLLER
    logic        interrupt_enable;
    logic        interrupt_disable;
    logic        irq_active;
    
    logic [9:0]  irq_id;
    logic        irq_valid;
        
    
    // Power_On_Reset 
    logic power_on_rst_n;
    
    
    // Reset_Unit 
    logic rst_n;
    
    
    // UART Rx 
    uart_rx UART_RX_UNIT (
        .clk         (clk),
        .rst_n       (rst_n),
        .rx_in_pin   (uart_rx),
        .data        (uart_data),
        .framing_err (uart_framing_err),
        .rx_done     (UART_done)
    );

    // CPU 
    CPU CPU(
        .clk(clk),
        .rst_n(rst_n),
    
        .CPU_enable(CPU_enable),
        .machine_code(machine_code),
    
        .ram_data(ram_data),
        .ram_read_en(ram_read_en),
        .ram_write_en(ram_write_en),
        .ram_addr(ram_addr),
        .data_ram_out(data_ram_out),
    
        .irq_id(irq_id),
        .irq_valid(irq_valid),
        .interrupt_enable(interrupt_enable),
        .interrupt_disable(interrupt_disable),
        .irq_active(irq_active),
    
        .port_data_in(port_data_in),
        .port_data_out(port_data_out),
        .port_enable(port_enable),
        .port_addr(port_addr),
    
        .PC(PC)
        
    );
    
    
    LOADER LOADER_inst (
        .clk(clk),
                
        .loader_reset(loader_reset),
    
        .UART_done(UART_done),
        .uart_data(uart_data),
    
        .CPU_enable(CPU_enable),
    
        .flash_write_enable(flash_write_enable),
        .flash_read_enable(flash_read_enable),
        .flash_write_address(flash_write_address),
    
        .machine_code(loader_machine_code)
    );
    
    // FLASH MEMORY
    Flash_memory Flash_memory(
        .clk(clk),
    
        .flash_write_enable(flash_write_enable),
        .flash_read_enable(flash_read_enable),
    
        .machine_code(loader_machine_code),

        .flash_write_address(flash_write_address),
        .flash_read_address(PC),
        
        .program_data(machine_code)
        
    );
    
   
    // RAM
    RAM RAM(
        .clk(clk),
    
        .read_enable(ram_read_en),
        .write_enable(ram_write_en),
    
        .address(ram_addr),
        .write_data(data_ram_out),
    
        .read_data(ram_data)
    );
    
    
    // GPIO_top 
    GPIO_top GPIO_top_inst (
        .clk(clk),
        .rst_n(rst_n),
    
        .port_enable(port_enable),
        .port_addr(port_addr),
    
        .write_data(port_data_out),
        .read_data(port_data_in),
    
        .pins(pins),
    
        .led_out(led_out),
    
        .sws(sws),
   
        .data_out(seven_segment),
        .anode(anode),
        .dp(dp),
    
        .btn_in(btn_in),
        .button_interrupt_data(button_interrupt_data),
    
        .timer0_interrupt_out(timer0_interrupt),
        .timer1_interrupt_out(timer1_interrupt),
        .timer2_interrupt_out(timer2_interrupt),
        .timer3_interrupt_out(timer3_interrupt),
        .timer4_interrupt_out(timer4_interrupt),
    
        .interrupt_register_enable_out(interrupt_register_enable),
    
        .pwm_pin(pwm_pin),
    
        .watchdog_reset(watchdog_reset)
    );
    
    // INTERRUPT CONTROLLER 
    Interrupt_controller Interrupt_controller(
        .clk(clk),
        .rst_n(rst_n),
    
        .interrupt_enable(interrupt_enable),
        .interrupt_disable(interrupt_disable),
    
        .interrupt_register(port_data_out),
        .interrupt_register_enable(interrupt_register_enable),
    
        .timer0(timer0_interrupt),
        .timer1(timer1_interrupt),
        .timer2(timer2_interrupt),
        .timer3(timer3_interrupt),
        .timer4(timer4_interrupt),
    
        .btn_u(button_interrupt_data[0]),
        .btn_l(button_interrupt_data[1]),
        .btn_c(button_interrupt_data[2]),
        .btn_r(button_interrupt_data[3]),
        .btn_d(button_interrupt_data[4]),
    
        .irq_active(irq_active),
    
        .irq_id(irq_id),
        .irq_valid(irq_valid)
    );

    // Power_On_Reset
    power_on_reset power_on_reset (
        .clk(clk),
        .rst_n(power_on_rst_n)
    );
    
    // Reset Unit 
    Reset_unit Reset_unit_inst (
        .clk(clk),
        .loader_reset(loader_reset),
        .watchdog_reset(watchdog_reset),
        .power_on_reset(power_on_rst_n),
        .button_reset(button_reset),
        .rst_n(rst_n)
    );



endmodule
