// ============================================================
// Module : mul_unit
// Project : RV32I Pipelined CPU — Phase 3/4 (M extension + ML)
// Description : Single-cycle multiplier and ML op unit.
//   Vivado infers a DSP48 slice for signed 32x32 multiply.
//   Only the lower 32 bits of the product are used.
//
//   ex_op encoding:
//     00 = pass-through (not used — caller selects ALU)
//     01 = MUL   : result = (a * b)[31:0]
//     10 = MAC   : result = c + (a * b)         (3-operand)
//     11 = RELU  : result = (a[31]) ? 0 : a     (unary, b ignored)
//
//   MAC accumulator input `c` (Phase 4):
//     - Phase 4 pipelined top (`cpu_top_mext_rdcyc`) wires c = rs3
//       (the instruction's rd read as a source), giving classical
//       3-operand MAC: `rd = rd + rs1*rs2`.
//     - Phase 3 top (`cpu_top_mext`) wires c = a (i.e. rs1),
//       preserving the old 2-operand MAC semantics:
//       `rd = rs1 + rs1*rs2`. This keeps tb_cpu_top_mext passing.
// ============================================================

`timescale 1ns / 1ps

module mul_unit (
    input  [31:0] a,        // rs1
    input  [31:0] b,        // rs2
    input  [31:0] c,        // MAC accumulator input (rs3 in Phase 4, rs1 in Phase 3)
    input  [1:0]  ex_op,
    output reg [31:0] result
);

    wire [31:0] product = $signed(a) * $signed(b);  // lower 32 bits of signed product

    always @(*) begin
        case (ex_op)
            2'b01: result = product;                     // MUL
            2'b10: result = c + product;                 // MAC: c + a*b
            2'b11: result = a[31] ? 32'b0 : a;           // RELU
            default: result = 32'b0;
        endcase
    end

endmodule
