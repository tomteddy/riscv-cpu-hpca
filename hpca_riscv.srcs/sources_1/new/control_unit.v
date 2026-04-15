`timescale 1ns / 1ps
// ============================================================
// control_unit : opcode -> all top-level control signals.
//
// Opcode table (RV32I):
//   0110011 R-type      0010011 I-type arith
//   0000011 Load        0100011 Store
//   1100011 Branch      0110111 LUI
//   0010111 AUIPC       1101111 JAL
//   1100111 JALR
//
// Signal meanings:
//   alu_a_sel : 00=rs1  01=PC  10=zero
//   alu_src   :  0=rs2  1=imm
//   wb_sel    : 00=alu  01=mem 10=pc+4
//   imm_sel   : 000=I 001=S 010=B 011=U 100=J
//   alu_op    : 00=force ADD  01=branch  10=R-type  11=I-arith
// ============================================================

module control_unit (
    input      [6:0]  opcode,
    output reg        reg_write,
    output reg        mem_write,
    output reg        alu_src,
    output reg [1:0]  alu_a_sel,
    output reg [1:0]  wb_sel,
    output reg        branch,
    output reg        jump,
    output reg [2:0]  imm_sel,
    output reg [1:0]  alu_op
);

    always @(*) begin
        // Safe defaults (prevents latches)
        reg_write = 1'b0; mem_write = 1'b0;
        alu_src   = 1'b0; alu_a_sel = 2'b00;
        wb_sel    = 2'b00;
        branch    = 1'b0; jump      = 1'b0;
        imm_sel   = 3'b000; alu_op  = 2'b00;

        case (opcode)
            7'b0110011: begin                                  // R-type
                reg_write = 1'b1; alu_op = 2'b10;
            end
            7'b0010011: begin                                  // I-type arith
                reg_write = 1'b1; alu_src = 1'b1;
                imm_sel = 3'b000; alu_op = 2'b11;
            end
            7'b0000011: begin                                  // Load
                reg_write = 1'b1; alu_src = 1'b1;
                wb_sel = 2'b01; imm_sel = 3'b000;
            end
            7'b0100011: begin                                  // Store
                mem_write = 1'b1; alu_src = 1'b1;
                imm_sel = 3'b001;
            end
            7'b1100011: begin                                  // Branch
                branch = 1'b1; imm_sel = 3'b010; alu_op = 2'b01;
            end
            7'b0110111: begin                                  // LUI
                reg_write = 1'b1; alu_src = 1'b1;
                alu_a_sel = 2'b10; imm_sel = 3'b011;
            end
            7'b0010111: begin                                  // AUIPC
                reg_write = 1'b1; alu_src = 1'b1;
                alu_a_sel = 2'b01; imm_sel = 3'b011;
            end
            7'b1101111: begin                                  // JAL
                reg_write = 1'b1; alu_src = 1'b1;
                alu_a_sel = 2'b01; wb_sel = 2'b10;
                jump = 1'b1; imm_sel = 3'b100;
            end
            7'b1100111: begin                                  // JALR
                reg_write = 1'b1; alu_src = 1'b1;
                wb_sel = 2'b10; jump = 1'b1; imm_sel = 3'b000;
            end
            default: ;   // all defaults already set above
        endcase
    end

endmodule
