`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.04.2026 13:20:03
// Design Name: 
// Module Name: instruction_memory
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


// ============================================================
// Module : instruction_memory
// Project : RISC-V Single-Cycle CPU
// Description : Read-only instruction memory (ROM)
//               Holds the program loaded from a .hex file.
//               - 4096 words x 32-bit = 16KB memory
//               - Loads instructions from "instructions.hex"
//               - Takes byte address (PC value) as input
//               - Converts byte address to word index internally
//               - Outputs the 32-bit instruction at that address
//               - If address is out of range, outputs 32'hXXXXXXXX
//
// Inputs:
//   pc       - 32-bit byte address (current Program Counter)
//
// Outputs:
//   instr    - 32-bit instruction at the given PC address
//
// Notes on .hex file format:
//   - Each line in the .hex file is one 32-bit instruction
//   - Values are in hexadecimal (no 0x prefix needed)
//   - Example line: 00500093   (means ADDI x1, x0, 5)
//   - Place instructions.hex in your Vivado project directory
//
// Address conversion:
//   PC = 0  ? memory[0]   (first instruction)
//   PC = 4  ? memory[1]   (second instruction)
//   PC = 8  ? memory[2]   (third instruction)
//   word_index = PC / 4 = PC >> 2
// ============================================================

module instruction_memory (
    input  [31:0] pc,       // Byte address from Program Counter
    output [31:0] instr     // 32-bit instruction output
);

    // --------------------------------------------------------
    // Declare memory array
    // 4096 locations, each 32 bits wide = 16KB total
    // --------------------------------------------------------

    reg [31:0] mem [0:4095];    // 4096 x 32-bit memory array

    // --------------------------------------------------------
    // Load instructions from hex file at simulation start
    // $readmemh reads hexadecimal values from the file
    // Each line in the file fills one 32-bit memory location
    // --------------------------------------------------------

    initial begin
        $readmemh("instructions.hex", mem);     // Load hex file into memory
    end

    // --------------------------------------------------------
    // Word address calculation
    // PC is a byte address, memory is word addressed
    // Divide PC by 4 to get word index (right shift by 2)
    // pc[31:2] gives the upper 30 bits = PC / 4
    // --------------------------------------------------------

    wire [29:0] word_addr;                      // 30-bit word index
    assign word_addr = pc[31:2];                // Shift right by 2 = divide by 4

    // --------------------------------------------------------
    // Output the instruction at the word address
    // If word_addr is within range (0 to 4095), output mem[word_addr]
    // If word_addr is out of range, output 32'hXXXXXXXX (undefined)
    // This makes out-of-bounds bugs visible in waveform
    // --------------------------------------------------------

    assign instr = (word_addr < 4096) ? mem[word_addr] : 32'hXXXXXXXX;
    // If word address is valid   ? return instruction from memory
    // If word address is invalid ? return undefined (X) to flag the bug

endmodule