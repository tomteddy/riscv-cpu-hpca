`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.04.2026 12:53:40
// Design Name: 
// Module Name: register_file
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
// Module : register_file
// Project : RISC-V Single-Cycle CPU
// Description : 32 x 32-bit general purpose register file
//               Follows standard RV32I specification:
//               - 2 combinational read ports (rs1, rs2)
//               - 1 synchronous write port (rd)
//               - x0 is hardwired to 0, writes to x0 ignored
//               - Write happens on rising clock edge
//               - Write enable signal controls when to write
//
// Inputs:
//   clk        - Clock signal
//   reg_write  - Write enable: 1 = write allowed, 0 = no write
//   rs1        - Address of first register to read (5-bit)
//   rs2        - Address of second register to read (5-bit)
//   rd         - Address of register to write to (5-bit)
//   write_data - 32-bit data to write into rd
//
// Outputs:
//   read_data1 - 32-bit data read from rs1
//   read_data2 - 32-bit data read from rs2
// ============================================================

module register_file (
    input         clk,          // Clock signal
    input         reg_write,    // Write enable flag
    input  [4:0]  rs1,          // Read address 1 (5-bit = 0 to 31)
    input  [4:0]  rs2,          // Read address 2 (5-bit = 0 to 31)
    input  [4:0]  rd,           // Write address (5-bit = 0 to 31)
    input  [31:0] write_data,   // Data to write into rd
    output [31:0] read_data1,   // Data read from rs1
    output [31:0] read_data2    // Data read from rs2
);

    // --------------------------------------------------------
    // Declare 32 registers, each 32 bits wide
    // registers[0] = x0, registers[1] = x1, ... registers[31] = x31
    // --------------------------------------------------------

    reg [31:0] registers [0:31];    // Array of 32 registers, each 32-bit wide

    // --------------------------------------------------------
    // Initialize all registers to 0 at the start
    // This is for simulation purposes
    // --------------------------------------------------------

    integer i;  // Loop variable for initialization

    initial begin
        for (i = 0; i < 32; i = i + 1) begin
            registers[i] = 32'b0;   // Set every register to 0
        end
    end

    // --------------------------------------------------------
    // READ PORT 1 (combinational)
    // Instantly outputs the value of register rs1
    // If rs1 is 0, always output 0 (x0 hardwired to 0)
    // --------------------------------------------------------

    assign read_data1 = (rs1 == 5'b00000) ? 32'b0 : registers[rs1];
    // If rs1 address is 0, return 0
    // Otherwise return the value stored in registers[rs1]

    // --------------------------------------------------------
    // READ PORT 2 (combinational)
    // Instantly outputs the value of register rs2
    // If rs2 is 0, always output 0 (x0 hardwired to 0)
    // --------------------------------------------------------

    assign read_data2 = (rs2 == 5'b00000) ? 32'b0 : registers[rs2];
    // If rs2 address is 0, return 0
    // Otherwise return the value stored in registers[rs2]

    // --------------------------------------------------------
    // WRITE PORT (synchronous - happens on rising clock edge)
    // Only writes if reg_write is 1
    // Writes to x0 (address 0) are silently ignored
    // --------------------------------------------------------

    always @(posedge clk) begin         // Trigger on rising clock edge

        if (reg_write == 1'b1) begin    // Only write if write enable is high

            if (rd != 5'b00000) begin   // Ignore writes to x0
                registers[rd] <= write_data;    // Write data into register rd
                // <= is non-blocking assignment, correct for sequential logic
            end

        end

    end

endmodule
