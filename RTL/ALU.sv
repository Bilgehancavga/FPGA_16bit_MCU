module ALU(
    input logic [15:0] a,
    input logic [15:0] b,
    input logic [3:0] alu_op,
    input logic [15:0] imm,
    output logic [15:0] result,
    output logic zero,
    output logic negative,
    output logic carry,
    output logic overflow
);

localparam logic [3:0]
    ALU_NOT = 4'b0000,
    ALU_AND = 4'b0001,
    ALU_OR  = 4'b0010,
    ALU_XOR = 4'b0011,
    ADD     = 4'b0100,
    SUB     = 4'b0101,
    CMP     = 4'b0110,
    NEG     = 4'b0111,
    SHL     = 4'b1000,
    SHR     = 4'b1001,
    PASS    = 4'b1010,
    ADDI    = 4'b1011,
    SUBI    = 4'b1100,
    INC     = 4'b1101,
    DEC     = 4'b1110;
    
    
    logic [16:0] extended_result;
    logic [3:0] shift_amount;
    
    always_comb begin
        result = 16'd0;
        extended_result = 17'd0;
        carry = 1'b0;
        overflow = 1'b0;
        
        shift_amount = b[3:0];
        
        
        case(alu_op)
        
            ALU_NOT: begin
                result = ~a;
            
            end
            
            ALU_AND: begin
                result  = a&b;
            
            end
            
            ALU_OR: begin
                result = a | b;
            
            end
            
            ALU_XOR: begin
                result = a^b;
            
            end
            
            
            
            ADD: begin
                extended_result = {1'b0,a} + {1'b0,b};
                result          = extended_result[15:0];
                carry           = extended_result[16];
                
                overflow = (~(a[15] ^ b[15])) & (result[15] ^ a[15]);    // signed overflow
            
            end
            
            SUB: begin
                result = a-b;              
                carry = (a >= b);                                        // C=1: no borrow
                overflow = (a[15]^b[15]) & (result[15]^a[15]);           // signed overflow
            
            end
            
            CMP: begin           // flags only
                result = a-b;
                
                carry = (a >= b);
                
                overflow = (a[15] ^ b[15]) & (result[15] ^ a[15]);
            
            end
            
            NEG: begin
                result = (~a) + 16'd1;
                
                overflow = (a == 16'h8000);                             // -32768 can't be negated
            
            end
            
            SHL: begin
                result = a << shift_amount;
                
                if(shift_amount != 0)
                   carry = a[16 - shift_amount];                        // shifted-out bit
            
            end
            
            SHR: begin
                result = a >> shift_amount;
                
                if(shift_amount != 0)
                    carry = a[shift_amount - 1];                        // shifted-out bit
            
            end
            
            PASS: begin
                result = a;
            end
            
            ADDI: begin
                {carry, result} = {1'b0, a} + {1'b0, imm};
                overflow = (~(a[15] ^ imm[15])) & (result[15] ^ a[15]);
            end 
            
            SUBI: begin
                result = a - imm;
                carry = (a >= imm);
                overflow = (a[15] ^ imm[15]) & (result[15] ^ a[15]);
            end
            
            INC: begin
                 {carry, result} = {1'b0, a} + 17'd1;
                  overflow = (a == 16'h7FFF);
            end 
            
            DEC: begin 
            
            result = a - 16'd1;
            carry = (a >= 16'd1);
            overflow = (a == 16'h8000);
            
            end
            
            default: begin
                result = 16'd0;
                carry = 1'b0;
                overflow = 1'b0;
            
            end
            
        
        
        endcase
    end
    
    
    always_comb begin
        zero = (result == 16'd0);
        negative = result[15];
    end
    
    

endmodule
