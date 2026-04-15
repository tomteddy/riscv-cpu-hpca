`timescale 1ns / 1ps
// ============================================================
// immediate_gen : Extracts & sign-extends RV32I immediates.
//   imm_sel : 000=I  001=S  010=B  011=U  100=J
// ============================================================

module immediate_gen (
    input      [31:0] instruction,
    input      [2:0]  imm_sel,
    output reg [31:0] imm_out
);

    always @(*) begin
        case (imm_sel)
            // I-type : inst[31:20]
            3'b000: imm_out = {{20{instruction[31]}}, instruction[31:20]};

            // S-type : inst[31:25] | inst[11:7]
            3'b001: imm_out = {{20{instruction[31]}},
                               instruction[31:25], instruction[11:7]};

            // B-type : inst[31] | inst[7] | inst[30:25] | inst[11:8] | 0
            3'b010: imm_out = {{19{instruction[31]}},
                               instruction[31], instruction[7],
                               instruction[30:25], instruction[11:8], 1'b0};

            // U-type : inst[31:12] | 12'b0
            3'b011: imm_out = {instruction[31:12], 12'b0};

            // J-type : inst[31] | inst[19:12] | inst[20] | inst[30:21] | 0
            3'b100: imm_out = {{11{instruction[31]}},
                               instruction[31], instruction[19:12],
                               instruction[20], instruction[30:21], 1'b0};

            default: imm_out = 32'b0;
        endcase
    end

endmodule
