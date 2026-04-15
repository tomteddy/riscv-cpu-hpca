`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.04.2026 14:29:06
// Design Name: 
// Module Name: control_unit
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
// Module : control_unit
// Project : RISC-V Single-Cycle CPU
// Description : Main control unit for the RISC-V CPU.
//               Decodes the 7-bit opcode from the instruction
//               and generates all control signals needed by
//               every other module in the CPU.
//
// Input:
//   opcode     - 7-bit opcode field from instruction[6:0]
//
// Outputs:
//   reg_write  - 1-bit: 1 = write to register file
//   mem_write  - 1-bit: 1 = write to data memory
//   alu_src    - 1-bit: 0 = ALU B input is rs2
//                       1 = ALU B input is immediate
//   alu_a_sel  - 2-bit: 00 = ALU A input is rs1
//                       01 = ALU A input is PC (for AUIPC, JAL)
//                       10 = ALU A input is 0  (for LUI)
//   wb_sel     - 2-bit: 00 = writeback ALU result
//                       01 = writeback memory read data
//                       10 = writeback PC + 4 (for JAL, JALR)
//   branch     - 1-bit: 1 = this is a branch instruction
//   jump       - 1-bit: 1 = this is JAL or JALR
//   imm_sel    - 3-bit: immediate format selector for imm gen
//                       000 = I-type
//                       001 = S-type
//                       010 = B-type
//                       011 = U-type
//                       100 = J-type
//   alu_op     - 2-bit: tells alu_control what category
//                       00 = force ADD (loads, stores, LUI, AUIPC)
//                       01 = branch comparison (use funct3)
//                       10 = R-type (use funct3 + funct7)
//                       11 = I-type arithmetic (use funct3)
//
// RV32I Opcodes:
//   0110011 = R-type  (ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU)
//   0010011 = I-type  (ADDI, SLTI, ANDI, ORI, XORI, SLLI, SRLI, SRAI)
//   0000011 = Load    (LB, LH, LW, LBU, LHU)
//   0100011 = Store   (SB, SH, SW)
//   1100011 = Branch  (BEQ, BNE, BLT, BGE, BLTU, BGEU)
//   0110111 = LUI
//   0010111 = AUIPC
//   1101111 = JAL
//   1100111 = JALR
// ============================================================

module control_unit (
    input  [6:0] opcode,        // 7-bit opcode from instruction[6:0]
    output reg        reg_write, // Register file write enable
    output reg        mem_write, // Data memory write enable
    output reg        alu_src,   // ALU B input select
    output reg [1:0]  alu_a_sel, // ALU A input select
    output reg [1:0]  wb_sel,    // Writeback source select
    output reg        branch,    // Branch instruction flag
    output reg        jump,      // Jump instruction flag
    output reg [2:0]  imm_sel,   // Immediate type selector
    output reg [1:0]  alu_op     // ALU operation category
);

    // Always block: combinational, runs when opcode changes
    always @(*) begin

        // Set safe default values for all signals
        // This prevents unintended latches in synthesis
        reg_write = 1'b0;           // No register write by default
        mem_write = 1'b0;           // No memory write by default
        alu_src   = 1'b0;           // Default ALU B = rs2
        alu_a_sel = 2'b00;          // Default ALU A = rs1
        wb_sel    = 2'b00;          // Default writeback = ALU result
        branch    = 1'b0;           // Not a branch by default
        jump      = 1'b0;           // Not a jump by default
        imm_sel   = 3'b000;         // Default I-type immediate
        alu_op    = 2'b00;          // Default force ADD

        case (opcode)

            // ------------------------------------------------
            // R-TYPE: ADD, SUB, AND, OR, XOR,
            //         SLL, SRL, SRA, SLT, SLTU
            // Format: rd = rs1 op rs2
            // ------------------------------------------------
            7'b0110011: begin
                reg_write = 1'b1;   // Write result to rd
                mem_write = 1'b0;   // No memory write
                alu_src   = 1'b0;   // ALU B = rs2 (not immediate)
                alu_a_sel = 2'b00;  // ALU A = rs1
                wb_sel    = 2'b00;  // Writeback = ALU result
                branch    = 1'b0;   // Not a branch
                jump      = 1'b0;   // Not a jump
                imm_sel   = 3'b000; // No immediate needed (don't care)
                alu_op    = 2'b10;  // R-type: use funct3 + funct7
            end

            // ------------------------------------------------
            // I-TYPE ARITHMETIC: ADDI, SLTI, SLTIU,
            //                    ANDI, ORI, XORI,
            //                    SLLI, SRLI, SRAI
            // Format: rd = rs1 op immediate
            // ------------------------------------------------
            7'b0010011: begin
                reg_write = 1'b1;   // Write result to rd
                mem_write = 1'b0;   // No memory write
                alu_src   = 1'b1;   // ALU B = immediate
                alu_a_sel = 2'b00;  // ALU A = rs1
                wb_sel    = 2'b00;  // Writeback = ALU result
                branch    = 1'b0;   // Not a branch
                jump      = 1'b0;   // Not a jump
                imm_sel   = 3'b000; // I-type immediate
                alu_op    = 2'b11;  // I-type: use funct3 only
            end

            // ------------------------------------------------
            // LOAD: LB, LH, LW, LBU, LHU
            // Format: rd = mem[rs1 + immediate]
            // ------------------------------------------------
            7'b0000011: begin
                reg_write = 1'b1;   // Write loaded value to rd
                mem_write = 1'b0;   // No memory write (this is a read)
                alu_src   = 1'b1;   // ALU B = immediate (for address calc)
                alu_a_sel = 2'b00;  // ALU A = rs1 (base address)
                wb_sel    = 2'b01;  // Writeback = memory read data
                branch    = 1'b0;   // Not a branch
                jump      = 1'b0;   // Not a jump
                imm_sel   = 3'b000; // I-type immediate
                alu_op    = 2'b00;  // Force ADD (compute address = rs1 + imm)
            end

            // ------------------------------------------------
            // STORE: SB, SH, SW
            // Format: mem[rs1 + immediate] = rs2
            // ------------------------------------------------
            7'b0100011: begin
                reg_write = 1'b0;   // No register write (store to memory)
                mem_write = 1'b1;   // Write to data memory
                alu_src   = 1'b1;   // ALU B = immediate (for address calc)
                alu_a_sel = 2'b00;  // ALU A = rs1 (base address)
                wb_sel    = 2'b00;  // Writeback doesn't matter (no reg write)
                branch    = 1'b0;   // Not a branch
                jump      = 1'b0;   // Not a jump
                imm_sel   = 3'b001; // S-type immediate
                alu_op    = 2'b00;  // Force ADD (compute address = rs1 + imm)
            end

            // ------------------------------------------------
            // BRANCH: BEQ, BNE, BLT, BGE, BLTU, BGEU
            // Format: if (rs1 op rs2) PC = PC + immediate
            // ------------------------------------------------
            7'b1100011: begin
                reg_write = 1'b0;   // No register write
                mem_write = 1'b0;   // No memory write
                alu_src   = 1'b0;   // ALU B = rs2 (compare with rs2)
                alu_a_sel = 2'b00;  // ALU A = rs1
                wb_sel    = 2'b00;  // Writeback doesn't matter
                branch    = 1'b1;   // This IS a branch instruction
                jump      = 1'b0;   // Not a jump
                imm_sel   = 3'b010; // B-type immediate (for branch target)
                alu_op    = 2'b01;  // Branch: use funct3 for comparison type
            end

            // ------------------------------------------------
            // LUI: Load Upper Immediate
            // Format: rd = immediate (upper 20 bits)
            // ALU computes: 0 + immediate = immediate
            // ------------------------------------------------
            7'b0110111: begin
                reg_write = 1'b1;   // Write result to rd
                mem_write = 1'b0;   // No memory write
                alu_src   = 1'b1;   // ALU B = immediate
                alu_a_sel = 2'b10;  // ALU A = 0 (so result = 0 + imm = imm)
                wb_sel    = 2'b00;  // Writeback = ALU result
                branch    = 1'b0;   // Not a branch
                jump      = 1'b0;   // Not a jump
                imm_sel   = 3'b011; // U-type immediate
                alu_op    = 2'b00;  // Force ADD (0 + immediate)
            end

            // ------------------------------------------------
            // AUIPC: Add Upper Immediate to PC
            // Format: rd = PC + immediate (upper 20 bits)
            // ------------------------------------------------
            7'b0010111: begin
                reg_write = 1'b1;   // Write result to rd
                mem_write = 1'b0;   // No memory write
                alu_src   = 1'b1;   // ALU B = immediate
                alu_a_sel = 2'b01;  // ALU A = PC (so result = PC + imm)
                wb_sel    = 2'b00;  // Writeback = ALU result
                branch    = 1'b0;   // Not a branch
                jump      = 1'b0;   // Not a jump
                imm_sel   = 3'b011; // U-type immediate
                alu_op    = 2'b00;  // Force ADD (PC + immediate)
            end

            // ------------------------------------------------
            // JAL: Jump and Link
            // Format: rd = PC + 4, PC = PC + immediate
            // Saves return address, jumps to PC-relative target
            // ------------------------------------------------
            7'b1101111: begin
                reg_write = 1'b1;   // Write return address to rd
                mem_write = 1'b0;   // No memory write
                alu_src   = 1'b1;   // ALU B = immediate (for jump target)
                alu_a_sel = 2'b01;  // ALU A = PC (target = PC + imm)
                wb_sel    = 2'b10;  // Writeback = PC + 4 (return address)
                branch    = 1'b0;   // Not a branch
                jump      = 1'b1;   // This IS a jump
                imm_sel   = 3'b100; // J-type immediate
                alu_op    = 2'b00;  // Force ADD (PC + immediate = jump target)
            end

            // ------------------------------------------------
            // JALR: Jump and Link Register
            // Format: rd = PC + 4, PC = (rs1 + immediate) & ~1
            // Saves return address, jumps to register-relative target
            // ------------------------------------------------
            7'b1100111: begin
                reg_write = 1'b1;   // Write return address to rd
                mem_write = 1'b0;   // No memory write
                alu_src   = 1'b1;   // ALU B = immediate (for jump target)
                alu_a_sel = 2'b00;  // ALU A = rs1 (target = rs1 + imm)
                wb_sel    = 2'b10;  // Writeback = PC + 4 (return address)
                branch    = 1'b0;   // Not a branch
                jump      = 1'b1;   // This IS a jump
                imm_sel   = 3'b000; // I-type immediate
                alu_op    = 2'b00;  // Force ADD (rs1 + immediate = jump target)
            end

            // ------------------------------------------------
            // Default: unknown opcode
            // Output all zeros = safe NOP-like state
            // ------------------------------------------------
            default: begin
                reg_write = 1'b0;   // No writes
                mem_write = 1'b0;   // No writes
                alu_src   = 1'b0;   // Don't care
                alu_a_sel = 2'b00;  // Don't care
                wb_sel    = 2'b00;  // Don't care
                branch    = 1'b0;   // Not a branch
                jump      = 1'b0;   // Not a jump
                imm_sel   = 3'b000; // Don't care
                alu_op    = 2'b00;  // Don't care
            end

        endcase

    end

endmodule
