`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.04.2026 18:12:51
// Design Name: 
// Module Name: writeback
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
// Module : writeback
// Project : RISC-V Single-Cycle CPU
// Description : Writeback MUX (Multiplexer)
//               Selects what value gets written back into
//               the register file at the end of each
//               instruction cycle.
//
//               Three possible sources:
//               - ALU result    (R-type, I-type, LUI, AUIPC)
//               - Memory data   (LB, LH, LW, LBU, LHU)
//               - PC + 4        (JAL, JALR return address)
//
// Inputs:
//   alu_result  - 32-bit result from ALU
//   mem_data    - 32-bit data read from data memory
//   pc_plus4    - 32-bit value of current PC + 4
//   wb_sel      - 2-bit selector from control unit
//                 00 = select alu_result
//                 01 = select mem_data
//                 10 = select pc_plus4
//
// Output:
//   wb_data     - 32-bit selected value to write to
//                 register file
// ============================================================

module writeback (
    input  [31:0] alu_result,   // Result from ALU
    input  [31:0] mem_data,     // Data read from data memory
    input  [31:0] pc_plus4,     // Current PC + 4
    input  [1:0]  wb_sel,       // Writeback source selector
    output reg [31:0] wb_data   // Selected writeback value
);

    // Always block: combinational
    // Runs whenever any input changes
    always @(*) begin

        case (wb_sel)

            2'b00: begin
                // Select ALU result
                // Used by: ADD, SUB, AND, OR, XOR, SLL, SRL, SRA
                //          SLT, SLTU, ADDI, ANDI, ORI, XORI, SLTI
                //          SLTIU, SLLI, SRLI, SRAI, LUI, AUIPC
                wb_data = alu_result;   // Write ALU output to register
            end

            2'b01: begin
                // Select memory read data
                // Used by: LB, LH, LW, LBU, LHU
                wb_data = mem_data;     // Write loaded value to register
            end

            2'b10: begin
                // Select PC + 4 (return address)
                // Used by: JAL, JALR
                // Saves the address of the next instruction
                // so the program can return after the jump
                wb_data = pc_plus4;     // Write return address to register
            end

            default: begin
                // Default: output 0 for undefined wb_sel
                wb_data = 32'b0;        // Safe default output
            end

        endcase

    end

endmodule