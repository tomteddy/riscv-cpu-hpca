// ============================================================
// Module : mul_unit
// Project : RV32I Pipelined CPU — Phase 3 (M extension + ML)
// Description : Single-cycle multiplier and ML op unit.
//   Vivado infers a DSP48 slice for signed 32x32 multiply.
//   Only the lower 32 bits of the product are used.
//
//   ex_op encoding:
//     00 = pass-through (not used — caller selects ALU)
//     01 = MUL   : result = (a * b)[31:0]
//     10 = MAC   : result = a + (a * b)         (rd = rs1 + rs1*rs2)
//     11 = RELU  : result = (a[31]) ? 0 : a     (unary, b ignored)
// ============================================================

`timescale 1ns / 1ps

module mul_unit (
    input  [31:0] a,        // rs1
    input  [31:0] b,        // rs2
    input  [1:0]  ex_op,
    output reg [31:0] result
);

    wire [31:0] product = $signed(a) * $signed(b);  // lower 32 bits of signed product

    always @(*) begin
        case (ex_op)
            2'b01: result = product;                     // MUL
            2'b10: result = a + product;                 // MAC: rs1 + rs1*rs2
            2'b11: result = a[31] ? 32'b0 : a;           // RELU
            default: result = 32'b0;
        endcase
    end

endmodule
