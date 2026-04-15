`timescale 1ns / 1ps
// ============================================================
// alu_control : (alu_op, funct3, funct7[5]) -> 4-bit alu_ctrl
//
// alu_op:
//   00 force ADD (loads/stores/LUI/AUIPC/JAL/JALR)
//   01 branch   (funct3 picks SUB vs SLT vs SLTU)
//   10 R-type   (funct3 + funct7[5])
//   11 I-arith  (funct3 + funct7[5] for SRLI/SRAI)
// ============================================================

module alu_control (
    input      [1:0] alu_op,
    input      [2:0] funct3,
    input      [6:0] funct7,
    output reg [3:0] alu_ctrl
);

    wire f7 = funct7[5];   // 0 = ADD/SRL, 1 = SUB/SRA

    always @(*) begin
        alu_ctrl = 4'b0000;
        case (alu_op)
            2'b00: alu_ctrl = 4'b0000;                 // force ADD

            2'b01: case (funct3)                       // branch
                3'b000, 3'b001: alu_ctrl = 4'b0001;    // BEQ/BNE  -> SUB
                3'b100, 3'b101: alu_ctrl = 4'b1000;    // BLT/BGE  -> SLT
                3'b110, 3'b111: alu_ctrl = 4'b1001;    // BLTU/BGEU-> SLTU
                default:        alu_ctrl = 4'b0000;
            endcase

            2'b10: case (funct3)                       // R-type
                3'b000: alu_ctrl = f7 ? 4'b0001 : 4'b0000;   // SUB / ADD
                3'b001: alu_ctrl = 4'b0101;                   // SLL
                3'b010: alu_ctrl = 4'b1000;                   // SLT
                3'b011: alu_ctrl = 4'b1001;                   // SLTU
                3'b100: alu_ctrl = 4'b0100;                   // XOR
                3'b101: alu_ctrl = f7 ? 4'b0111 : 4'b0110;   // SRA / SRL
                3'b110: alu_ctrl = 4'b0011;                   // OR
                3'b111: alu_ctrl = 4'b0010;                   // AND
                default: alu_ctrl = 4'b0000;
            endcase

            2'b11: case (funct3)                       // I-arith
                3'b000: alu_ctrl = 4'b0000;                   // ADDI
                3'b001: alu_ctrl = 4'b0101;                   // SLLI
                3'b010: alu_ctrl = 4'b1000;                   // SLTI
                3'b011: alu_ctrl = 4'b1001;                   // SLTIU
                3'b100: alu_ctrl = 4'b0100;                   // XORI
                3'b101: alu_ctrl = f7 ? 4'b0111 : 4'b0110;   // SRAI / SRLI
                3'b110: alu_ctrl = 4'b0011;                   // ORI
                3'b111: alu_ctrl = 4'b0010;                   // ANDI
                default: alu_ctrl = 4'b0000;
            endcase
        endcase
    end

endmodule
