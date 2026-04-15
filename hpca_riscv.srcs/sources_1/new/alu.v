`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.04.2026 12:27:22
// Design Name: 
// Module Name: alu
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
// Module : alu
// Project : RISC-V Single-Cycle CPU
// Description : Arithmetic Logic Unit (ALU)
//               Performs all arithmetic and logic operations
//               required by the RV32I instruction set.
//
// Inputs:
//   a         - First 32-bit operand
//   b         - Second 32-bit operand
//   alu_ctrl  - 4-bit control signal to select operation
//
// Outputs:
//   result    - 32-bit result of the operation
//   zero      - 1 if result is zero (used for branch instructions)
//
// ALU Control Signal Encoding:
//   0000 = ADD
//   0001 = SUB
//   0010 = AND
//   0011 = OR
//   0100 = XOR
//   0101 = SLL  (Shift Left Logical)
//   0110 = SRL  (Shift Right Logical)
//   0111 = SRA  (Shift Right Arithmetic)
//   1000 = SLT  (Set Less Than, signed)
//   1001 = SLTU (Set Less Than, unsigned)
// ============================================================

module alu (
    input  [31:0] a,          // First operand (32-bit)
    input  [31:0] b,          // Second operand (32-bit)
    input  [3:0]  alu_ctrl,   // Operation selector (4-bit)
    output reg [31:0] result, // Result of the operation (32-bit)
    output zero               // Zero flag: 1 if result == 0
);

    // Zero flag: result is zero when all bits are 0
    assign zero = (result == 32'b0);

    // Always block: runs whenever inputs change (combinational logic)
    always @(*) begin

        case (alu_ctrl)

            4'b0000: begin
                // ADD: add both operands
                result = a + b;
            end

            4'b0001: begin
                // SUB: subtract b from a
                result = a - b;
            end

            4'b0010: begin
                // AND: bitwise AND of a and b
                result = a & b;
            end

            4'b0011: begin
                // OR: bitwise OR of a and b
                result = a | b;
            end

            4'b0100: begin
                // XOR: bitwise XOR of a and b
                result = a ^ b;
            end

            4'b0101: begin
                // SLL: shift a left by the lower 5 bits of b
                // Only lower 5 bits used because max shift for 32-bit = 31
                result = a << b[4:0];
            end

            4'b0110: begin
                // SRL: shift a right logically by lower 5 bits of b
                // Fills vacated bits with 0
                result = a >> b[4:0];
            end

            4'b0111: begin
                // SRA: shift a right arithmetically by lower 5 bits of b
                // Fills vacated bits with the sign bit (bit 31)
                // $signed() tells Verilog to treat a as a signed number
                result = $signed(a) >>> b[4:0];
            end

            4'b1000: begin
                // SLT: set result to 1 if a < b (signed comparison)
                // $signed() used for correct signed comparison
                result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            end

            4'b1001: begin
                // SLTU: set result to 1 if a < b (unsigned comparison)
                result = (a < b) ? 32'd1 : 32'd0;
            end

            default: begin
                // Default: output 0 for any undefined control signal
                result = 32'b0;
            end

        endcase

    end

endmodule
