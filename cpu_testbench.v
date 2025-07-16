`timescale 1ps/1ps

module cpu_testbench();

// Testbench signals
reg clk;
reg reset;
wire [7:0] pc;
wire [7:0] instruction;
wire [7:0] R1, R2, R3;

// Instantiate the CPU
simple_cpu cpu_inst (
    .clk(clk),
    .reset(reset),
    .pc(pc),
    .instruction(instruction),
    .R1(R1),
    .R2(R2),
    .R3(R3)
);

// Clock generation
initial begin
    clk = 0;
    forever #50000 clk = ~clk; // 100ps period
end

// Test sequence
initial begin
    // Initialize VCD dump
    $dumpfile("cpu.vcd");
    $dumpvars(0, cpu_testbench);
    
    // Initialize
    reset = 1;
    #100000;
    reset = 0;
    
    // Let the CPU run through the test program
    // Instruction 0: MOV R1, #5 (R5 -> R1)
    // Instruction 1: MOV R2, #7 (R6 -> R2) 
    // Instruction 2: ADD R3, R1, R2
    
    // Run for enough cycles to complete the program
    repeat(10) @(posedge clk);
    
    // Display final state
    $display("Final PC = %d", pc);
    $display("R1 = %02h", R1);
    $display("R2 = %02h", R2);
    $display("R3 = %02h", R3);
    
    $finish;
end

// Monitor changes
initial begin
    $monitor("Time=%0t: PC=%d, Instruction=%02h, R1=%02h, R2=%02h, R3=%02h", 
             $time, pc, instruction, R1, R2, R3);
end

endmodule