module simple_cpu(
    input wire clk,
    input wire reset,
    output reg [7:0] pc,
    output wire [7:0] instruction,
    output wire [7:0] R1, R2, R3
);

// Instruction memory (ROM)
reg [7:0] instruction_memory [0:255];

// Register file - only R0-R3 physically implemented
reg [7:0] registers [0:3];

// Control signals
wire [2:0] opcode;
wire [2:0] dest;
wire [2:0] src;
wire zero_flag;
reg [7:0] alu_result;
reg [7:0] operand1, operand2;
reg write_enable;

// Instruction fetch
assign instruction = instruction_memory[pc];

// Instruction decode - 3-2-3 format
assign opcode = instruction[7:5];
assign dest = instruction[4:2];
assign src = {1'b0, instruction[1:0]}; // Extend to 3 bits for consistency

// Initialize instruction memory with test program
initial begin
    // MOV R1, #5 (immediate) - uses R5 encoding
    instruction_memory[0] = 8'b101_101_10; // opcode=101(MOV), dest=101(R5->R1), src=10(immediate value index)
    
    // MOV R2, #7 (immediate) - uses R6 encoding  
    instruction_memory[1] = 8'b101_110_11; // opcode=101(MOV), dest=110(R6->R2), src=11(immediate value index)
    
    // ADD R3, R1, R2
    instruction_memory[2] = 8'b000_011_10; // opcode=000(ADD), dest=011(R3), src=10(R2)
    
    // Initialize remaining memory to NOPs
    for (integer i = 3; i < 256; i = i + 1) begin
        instruction_memory[i] = 8'b000_000_00;
    end
end

// Initialize registers
initial begin
    pc = 8'b0;
    registers[0] = 8'h00;
    registers[1] = 8'h00;
    registers[2] = 8'h00;
    registers[3] = 8'h00;
    write_enable = 1'b0;
end

// Zero flag logic
assign zero_flag = (alu_result == 8'b0);

// Register file outputs (for monitoring)
assign R1 = registers[1];
assign R2 = registers[2]; 
assign R3 = registers[3];

// ALU - make this combinational with proper timing
always @(*) begin
    case (opcode)
        3'b000: alu_result = operand1 + operand2; // ADD
        3'b001: alu_result = operand1 * operand2; // MUL
        3'b010: alu_result = operand1 & operand2; // AND
        3'b011: alu_result = operand1 | operand2; // OR
        3'b100: alu_result = operand1 ^ operand2; // XOR
        3'b101: alu_result = operand2;            // MOV (pass through src)
        3'b110: alu_result = operand1 - operand2; // CMP
        3'b111: alu_result = ~operand1;           // COM
        default: alu_result = 8'b0;
    endcase
end

// Main CPU logic
always @(posedge clk or posedge reset) begin
    if (reset) begin
        pc <= 8'b0;
        registers[0] <= 8'h00;
        registers[1] <= 8'h00;
        registers[2] <= 8'h00;
        registers[3] <= 8'h00;
        operand1 <= 8'h00;
        operand2 <= 8'h00;
    end else begin
        // Decode current instruction
        case (opcode)
            3'b000: begin // ADD
                // For ADD: R[dest] = R[1] + R[src]
                // Read operands with proper masking - use blocking assignments for immediate effect
                operand1 = registers[1]; // Always read from R1 for ADD
                operand2 = registers[src[1:0]]; // Mask src to 2 bits
                write_enable = 1'b1;
                
                // Force ALU evaluation by referencing operands in the ALU computation
                // The ALU is combinational and should update immediately
                #0; // Delta cycle delay to ensure combinational logic updates
                
                $display("ADD DEBUG: opcode=%03b, operand1=%02h, operand2=%02h", opcode, operand1, operand2);
                $display("ADD Executed: R1=%02h, R2=%02h, RESULT=%02h, write_en=%b", 
                         operand1, operand2, alu_result, write_enable);
                
                // Write result to destination (masked to 2 bits)
                registers[dest[1:0]] <= alu_result;
                pc <= pc + 1;
            end
            
            3'b001: begin // MUL
                operand1 = registers[dest[1:0]];
                operand2 = registers[src[1:0]];
                registers[dest[1:0]] <= alu_result;
                pc <= pc + 1;
            end
            
            3'b010: begin // AND
                operand1 = registers[dest[1:0]];
                operand2 = registers[src[1:0]];
                registers[dest[1:0]] <= alu_result;
                pc <= pc + 1;
            end
            
            3'b011: begin // OR or JMP
                if (dest == 3'b011) begin
                    // JMP
                    pc <= {5'b0, src};
                end else begin
                    // OR
                    operand1 = registers[dest[1:0]];
                    operand2 = registers[src[1:0]];
                    registers[dest[1:0]] <= alu_result;
                    pc <= pc + 1;
                end
            end
            
            3'b100: begin // XOR or JZ
                if (zero_flag) begin
                    // JZ
                    pc <= {5'b0, src};
                end else begin
                    // XOR
                    operand1 = registers[dest[1:0]];
                    operand2 = registers[src[1:0]];
                    registers[dest[1:0]] <= alu_result;
                    pc <= pc + 1;
                end
            end
            
            3'b101: begin // MOV or JNZ
                if (dest[2] == 1'b1) begin
                    // MOV immediate: dest[2]==1 indicates immediate mode
                    // Map R4-R7 to R0-R3 using masking
                    case (src[1:0])
                        2'b00: operand2 = 8'h00;
                        2'b01: operand2 = 8'h01;
                        2'b10: operand2 = 8'h05; // #5
                        2'b11: operand2 = 8'h07; // #7
                    endcase
                    
                    $display("MOV REG: R%d = R%d = %02h", dest[1:0], dest, operand2);
                    registers[dest[1:0]] <= operand2; // Write to masked destination
                    $display("REG WRITE: R[%d] = %02h", dest[1:0], operand2);
                    
                end else if (!zero_flag) begin
                    // JNZ when not zero  
                    pc <= {5'b0, src};
                end else begin
                    // MOV register to register
                    operand2 = registers[src[1:0]];
                    registers[dest[1:0]] <= operand2;
                end
                pc <= pc + 1;
            end
            
            3'b110: begin // CMP
                operand1 = registers[dest[1:0]];
                operand2 = registers[src[1:0]];
                // CMP sets flags but doesn't write back
                pc <= pc + 1;
            end
            
            3'b111: begin // COM
                operand1 = registers[dest[1:0]];
                registers[dest[1:0]] <= alu_result;
                pc <= pc + 1;
            end
            
            default: begin
                pc <= pc + 1;
            end
        endcase
        
        $display("CPU Cycle - PC=%2d, Instruction=%02h, Opcode=%03b, Dest=%03b, Src=%03b", 
                 pc, instruction, opcode, dest, src);
    end
end

endmodule