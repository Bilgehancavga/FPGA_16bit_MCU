module debouncer_edgedetector #(parameter int WAIT_TIME = 15_000_000)    // 150 ms at 100 MHz
    (
    input  logic clk,
    input  logic rst_n,
    input  logic db_enable,
    input  logic db_disable,
    input  logic btn_in,
    output logic btn_out
);


    typedef enum logic [1:0] {
        IDLE = 2'b00,
        COUNTING = 2'b01,
        DEBOUNCED = 2'b10
    
    } states;
    
    states current_state;
    
    logic pulse, btn_sync_0, btn_sync_1;
    logic db_flag;
    logic [$clog2(WAIT_TIME)-1:0] counter;
    
    
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            db_flag <= 1'b0;
        else begin
            if(db_enable) 
                db_flag <= 1'b1;
            else if(db_disable)
                db_flag <= 1'b0;                
        end
    end

    // 2-FF synchronizer
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            btn_sync_0 <= 1'b0;
            btn_sync_1 <= 1'b0;
        end
        else begin
            btn_sync_0 <= btn_in;
            btn_sync_1 <= btn_sync_0;
        end
    end
    
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            current_state <= IDLE;
            counter       <= 0;
            pulse         <= 1'b0;
        end
        else begin
            pulse <= 1'b0;
            
            if(db_flag) begin
                case(current_state)
                    IDLE: begin
                        if(btn_sync_1)
                            current_state <= COUNTING;
                        else
                            counter <= 0;
                    end 
                    COUNTING: begin    // must stay pressed for WAIT_TIME clocks
                        if(btn_sync_1) begin
                            if(counter == WAIT_TIME) begin
                                current_state <= DEBOUNCED;
                                pulse         <= 1'b1;
                            end
                            else
                                counter <= counter + 1;
                        end
                        else begin
                            current_state <= IDLE;
                            counter       <= 0;
                        end
                    end 
                    DEBOUNCED: begin     // one pulse per press, wait for release
                        if(btn_sync_1) 
                            current_state <= DEBOUNCED;  
                        else begin
                            current_state <= IDLE;
                            counter       <= 0;
                        end
                    end
                    
                    default: begin
                        current_state <= IDLE;
                        counter       <= 0;
                    end
                    
                endcase
            end
            else begin
                current_state <= IDLE;
                counter       <= 0;
            end
        end
    
    end

    // debouncer off: synchronized raw level
    assign btn_out = db_flag ? pulse : btn_sync_1;


endmodule
