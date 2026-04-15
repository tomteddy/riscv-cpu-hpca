`timescale 1ns / 1ps
// ============================================================
// branch_unit : Evaluates whether a branch is taken.
//   Expects ALU to have already performed the correct compare:
//     BEQ/BNE   -> SUB (inspect zero flag)
//     BLT/BGE   -> SLT   (inspect alu_result[0])
//     BLTU/BGEU -> SLTU  (inspect alu_result[0])
// ============================================================

module branch_unit (
    input            branch,        // 1 = this is a branch instruction
    input      [2:0] funct3,
    input            zero,          // ALU zero flag (SUB result == 0)
    input      [0:0] alu_lt,        // alu_result[0] for SLT/SLTU results
    output reg       branch_taken
);

    always @(*) begin
        branch_taken = 1'b0;
        if (branch) begin
            case (funct3)
                3'b000: branch_taken =  zero;    // BEQ
                3'b001: branch_taken = ~zero;    // BNE
                3'b100: branch_taken =  alu_lt;  // BLT
                3'b101: branch_taken = ~alu_lt;  // BGE
                3'b110: branch_taken =  alu_lt;  // BLTU
                3'b111: branch_taken = ~alu_lt;  // BGEU
                default: branch_taken = 1'b0;
            endcase
        end
    end

endmodule
