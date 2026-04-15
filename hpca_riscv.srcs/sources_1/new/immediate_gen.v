`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.04.2026 13:04:42
// Design Name: 
// Module Name: immediate_gen
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
// Module : immediate_gen
// Project : RISC-V Single-Cycle CPU
// Description : Extracts and sign-extends immediates from
//               32-bit RISC-V instructions.
//               Supports all 5 RV32I immediate formats:
//               I-type, S-type, B-type, U-type, J-type
//
// Inputs:
//   instruction - Full 32-bit instruction from memory
//   imm_sel     - 3-bit selector from control unit
//                 tells us which format to decode
//
// Output:
//   imm_out     - 32-bit sign-extended immediate value
//
// Immediate Type Selector Encoding (imm_sel):
//   000 = I-type
//   001 = S-type
//   010 = B-type
//   011 = U-type
//   100 = J-type
//
// RV32I Immediate Bit Layouts:
//
//   I-type: imm[11:0]  = inst[31:20]
//
//   S-type: imm[11:5]  = inst[31:25]
//           imm[4:0]   = inst[11:7]
//
//   B-type: imm[12]    = inst[31]
//           imm[10:5]  = inst[30:25]
//           imm[4:1]   = inst[11:8]
//           imm[11]    = inst[7]
//           imm[0]     = always 0 (byte aligned)
//
//   U-type: imm[31:12] = inst[31:12]
//           imm[11:0]  = always 0
//
//   J-type: imm[20]    = inst[31]
//           imm[10:1]  = inst[30:21]
//           imm[11]    = inst[20]
//           imm[19:12] = inst[19:12]
//           imm[0]     = always 0 (byte aligned)
// ============================================================

module immediate_gen (
    input  [31:0] instruction,  // Full 32-bit instruction
    input  [2:0]  imm_sel,      // Immediate type selector from control unit
    output reg [31:0] imm_out   // Sign-extended 32-bit immediate output
);

    // Always block: combinational, runs whenever inputs change
    always @(*) begin

        case (imm_sel)

            // ------------------------------------------------
            // I-type immediate
            // Used by: ADDI, SLTI, SLTIU, ANDI, ORI, XORI,
            //          SLLI, SRLI, SRAI, LW, LH, LB, LHU,
            //          LBU, JALR
            //
            // Bits: inst[31:20] = imm[11:0]
            // Sign extend: replicate bit 31 across bits 31:12
            // ------------------------------------------------
            3'b000: begin
                imm_out = {{20{instruction[31]}},   // Sign extend bit 31 x20
                            instruction[31:20]};    // imm[11:0] from inst[31:20]
            end

            // ------------------------------------------------
            // S-type immediate
            // Used by: SW, SH, SB
            //
            // Bits: inst[31:25] = imm[11:5]
            //       inst[11:7]  = imm[4:0]
            // Sign extend: replicate bit 31 across bits 31:12
            // ------------------------------------------------
            3'b001: begin
                imm_out = {{20{instruction[31]}},   // Sign extend bit 31 x20
                            instruction[31:25],     // imm[11:5] from inst[31:25]
                            instruction[11:7]};     // imm[4:0]  from inst[11:7]
            end

            // ------------------------------------------------
            // B-type immediate
            // Used by: BEQ, BNE, BLT, BGE, BLTU, BGEU
            //
            // Bits are scattered across the instruction:
            //   inst[31]    = imm[12]
            //   inst[7]     = imm[11]
            //   inst[30:25] = imm[10:5]
            //   inst[11:8]  = imm[4:1]
            //   imm[0]      = 0 (branches always jump to even addresses)
            // Sign extend: replicate bit 31 across bits 31:13
            // ------------------------------------------------
            3'b010: begin
                imm_out = {{19{instruction[31]}},   // Sign extend bit 31 x19
                            instruction[31],        // imm[12]
                            instruction[7],         // imm[11]
                            instruction[30:25],     // imm[10:5]
                            instruction[11:8],      // imm[4:1]
                            1'b0};                  // imm[0] = 0 always
            end

            // ------------------------------------------------
            // U-type immediate
            // Used by: LUI, AUIPC
            //
            // Bits: inst[31:12] = imm[31:12]
            //       imm[11:0]   = 0 (lower 12 bits always 0)
            // No sign extension needed, upper bits come directly
            // ------------------------------------------------
            3'b011: begin
                imm_out = {instruction[31:12],      // imm[31:12] from inst[31:12]
                           12'b0};                  // imm[11:0] = 0 always
            end

            // ------------------------------------------------
            // J-type immediate
            // Used by: JAL
            //
            // Bits are scattered:
            //   inst[31]    = imm[20]
            //   inst[19:12] = imm[19:12]
            //   inst[20]    = imm[11]
            //   inst[30:21] = imm[10:1]
            //   imm[0]      = 0 (jumps always to even addresses)
            // Sign extend: replicate bit 31 across bits 31:21
            // ------------------------------------------------
            3'b100: begin
                imm_out = {{11{instruction[31]}},   // Sign extend bit 31 x11
                            instruction[31],        // imm[20]
                            instruction[19:12],     // imm[19:12]
                            instruction[20],        // imm[11]
                            instruction[30:21],     // imm[10:1]
                            1'b0};                  // imm[0] = 0 always
            end

            // ------------------------------------------------
            // Default: output 0 for undefined selector
            // ------------------------------------------------
            default: begin
                imm_out = 32'b0;                    // Safe default output
            end

        endcase

    end

endmodule
