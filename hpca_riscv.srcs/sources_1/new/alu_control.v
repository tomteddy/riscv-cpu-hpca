`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.04.2026 17:59:30
// Design Name: 
// Module Name: alu_control
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
// Module : alu_control
// Project : RISC-V Single-Cycle CPU
// Description : Second level control unit.
//               Takes alu_op from control unit + funct3 +
//               funct7 from the instruction and generates
//               the 4-bit alu_ctrl signal for the ALU.
//
// Inputs:
//   alu_op   - 2-bit category from control unit
//              00 = force ADD (loads, stores, LUI, AUIPC)
//              01 = branch comparison (use funct3)
//              10 = R-type (use funct3 + funct7[5])
//              11 = I-type arithmetic (use funct3 only)
//   funct3   - 3-bit field from instruction[14:12]
//   funct7   - 7-bit field from instruction[31:25]
//
// Output:
//   alu_ctrl - 4-bit ALU operation selector (goes to alu.v)
//              0000 = ADD
//              0001 = SUB
//              0010 = AND
//              0011 = OR
//              0100 = XOR
//              0101 = SLL
//              0110 = SRL
//              0111 = SRA
//              1000 = SLT
//              1001 = SLTU
//
// funct3 encoding for R-type and I-type:
//   000 = ADD/SUB/ADDI        (funct7[5] decides ADD vs SUB)
//   001 = SLL/SLLI
//   010 = SLT/SLTI
//   011 = SLTU/SLTIU
//   100 = XOR/XORI
//   101 = SRL/SRA/SRLI/SRAI   (funct7[5] decides SRL vs SRA)
//   110 = OR/ORI
//   111 = AND/ANDI
//
// funct3 encoding for Branch (alu_op = 01):
//   000 = BEQ  (use SUB, check zero flag)
//   001 = BNE  (use SUB, check not zero)
//   100 = BLT  (use SLT, signed)
//   101 = BGE  (use SLT, signed, inverted)
//   110 = BLTU (use SLTU, unsigned)
//   111 = BGEU (use SLTU, unsigned, inverted)
// ============================================================

module alu_control (
    input  [1:0] alu_op,    // Operation category from control unit
    input  [2:0] funct3,    // funct3 field from instruction[14:12]
    input  [6:0] funct7,    // funct7 field from instruction[31:25]
    output reg [3:0] alu_ctrl  // 4-bit ALU operation selector
);

    // --------------------------------------------------------
    // Extract only bit 5 of funct7
    // This is the only bit that matters in RV32I
    // funct7[5] = 0 ? ADD, SRL (normal operation)
    // funct7[5] = 1 ? SUB, SRA (alternate operation)
    // --------------------------------------------------------

    wire funct7_bit5;               // Single bit extracted from funct7
    assign funct7_bit5 = funct7[5]; // Only bit 5 is relevant in RV32I

    // --------------------------------------------------------
    // Always block: combinational
    // Runs whenever any input changes
    // --------------------------------------------------------

    always @(*) begin

        // Safe default output
        alu_ctrl = 4'b0000;         // Default to ADD

        case (alu_op)

            // --------------------------------------------
            // alu_op = 00: Force ADD
            // Used by: LW, LH, LB, LHU, LBU (address calc)
            //          SW, SH, SB (address calc)
            //          LUI  (0 + immediate)
            //          AUIPC (PC + immediate)
            //          JAL, JALR (target address calc)
            // No need to check funct3 or funct7
            // --------------------------------------------
            2'b00: begin
                alu_ctrl = 4'b0000; // Always ADD
            end

            // --------------------------------------------
            // alu_op = 01: Branch comparison
            // Used by: BEQ, BNE, BLT, BGE, BLTU, BGEU
            // funct3 selects the type of comparison
            // The actual branch decision (take or not)
            // is made in cpu_top.v using the ALU result
            // --------------------------------------------
            2'b01: begin
                case (funct3)

                    3'b000: begin
                        // BEQ: branch if rs1 == rs2
                        // Use SUB: if result is 0 then equal
                        alu_ctrl = 4'b0001; // SUB
                    end

                    3'b001: begin
                        // BNE: branch if rs1 != rs2
                        // Use SUB: if result is not 0 then not equal
                        alu_ctrl = 4'b0001; // SUB
                    end

                    3'b100: begin
                        // BLT: branch if rs1 < rs2 (signed)
                        // Use SLT: result is 1 if rs1 < rs2
                        alu_ctrl = 4'b1000; // SLT
                    end

                    3'b101: begin
                        // BGE: branch if rs1 >= rs2 (signed)
                        // Use SLT: branch if SLT result is 0
                        alu_ctrl = 4'b1000; // SLT
                    end

                    3'b110: begin
                        // BLTU: branch if rs1 < rs2 (unsigned)
                        // Use SLTU: result is 1 if rs1 < rs2
                        alu_ctrl = 4'b1001; // SLTU
                    end

                    3'b111: begin
                        // BGEU: branch if rs1 >= rs2 (unsigned)
                        // Use SLTU: branch if SLTU result is 0
                        alu_ctrl = 4'b1001; // SLTU
                    end

                    default: begin
                        alu_ctrl = 4'b0000; // Default ADD
                    end

                endcase
            end

            // --------------------------------------------
            // alu_op = 10: R-type instructions
            // Used by: ADD SUB AND OR XOR SLL SRL SRA SLT SLTU
            // funct3 selects the base operation
            // funct7[5] distinguishes between:
            //   ADD (funct7[5]=0) vs SUB (funct7[5]=1)
            //   SRL (funct7[5]=0) vs SRA (funct7[5]=1)
            // --------------------------------------------
            2'b10: begin
                case (funct3)

                    3'b000: begin
                        // ADD or SUB depending on funct7[5]
                        if (funct7_bit5 == 1'b0) begin
                            alu_ctrl = 4'b0000; // ADD (funct7=0000000)
                        end else begin
                            alu_ctrl = 4'b0001; // SUB (funct7=0100000)
                        end
                    end

                    3'b001: begin
                        // SLL: shift left logical
                        // funct7 is always 0000000 for SLL
                        alu_ctrl = 4'b0101; // SLL
                    end

                    3'b010: begin
                        // SLT: set less than signed
                        alu_ctrl = 4'b1000; // SLT
                    end

                    3'b011: begin
                        // SLTU: set less than unsigned
                        alu_ctrl = 4'b1001; // SLTU
                    end

                    3'b100: begin
                        // XOR: bitwise XOR
                        alu_ctrl = 4'b0100; // XOR
                    end

                    3'b101: begin
                        // SRL or SRA depending on funct7[5]
                        if (funct7_bit5 == 1'b0) begin
                            alu_ctrl = 4'b0110; // SRL (funct7=0000000)
                        end else begin
                            alu_ctrl = 4'b0111; // SRA (funct7=0100000)
                        end
                    end

                    3'b110: begin
                        // OR: bitwise OR
                        alu_ctrl = 4'b0011; // OR
                    end

                    3'b111: begin
                        // AND: bitwise AND
                        alu_ctrl = 4'b0010; // AND
                    end

                    default: begin
                        alu_ctrl = 4'b0000; // Default ADD
                    end

                endcase
            end

            // --------------------------------------------
            // alu_op = 11: I-type arithmetic instructions
            // Used by: ADDI SLTI SLTIU ANDI ORI XORI
            //          SLLI SRLI SRAI
            // Same as R-type but funct7[5] only matters
            // for SRLI vs SRAI (shift right instructions)
            // ADDI has no SUB equivalent (no SUBI exists)
            // --------------------------------------------
            2'b11: begin
                case (funct3)

                    3'b000: begin
                        // ADDI: always ADD, no subtract variant
                        alu_ctrl = 4'b0000; // ADD
                    end

                    3'b001: begin
                        // SLLI: shift left logical immediate
                        // funct7 is always 0000000 for SLLI
                        alu_ctrl = 4'b0101; // SLL
                    end

                    3'b010: begin
                        // SLTI: set less than immediate signed
                        alu_ctrl = 4'b1000; // SLT
                    end

                    3'b011: begin
                        // SLTIU: set less than immediate unsigned
                        alu_ctrl = 4'b1001; // SLTU
                    end

                    3'b100: begin
                        // XORI: bitwise XOR immediate
                        alu_ctrl = 4'b0100; // XOR
                    end

                    3'b101: begin
                        // SRLI or SRAI depending on funct7[5]
                        // This is the only I-type where funct7 matters
                        if (funct7_bit5 == 1'b0) begin
                            alu_ctrl = 4'b0110; // SRLI (funct7=0000000)
                        end else begin
                            alu_ctrl = 4'b0111; // SRAI (funct7=0100000)
                        end
                    end

                    3'b110: begin
                        // ORI: bitwise OR immediate
                        alu_ctrl = 4'b0011; // OR
                    end

                    3'b111: begin
                        // ANDI: bitwise AND immediate
                        alu_ctrl = 4'b0010; // AND
                    end

                    default: begin
                        alu_ctrl = 4'b0000; // Default ADD
                    end

                endcase
            end

            default: begin
                alu_ctrl = 4'b0000;         // Safe default: ADD
            end

        endcase

    end

endmodule
