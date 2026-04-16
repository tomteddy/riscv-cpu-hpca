// ============================================================
// Module : forwarding_unit
// Project : RISC-V 5-Stage Pipelined CPU
// Description : Detects RAW data hazards and outputs mux
//               selects to bypass the register file.
//
//               Two forwarding paths:
//               - EX-to-EX (01): MEM-stage result → EX ALU input
//               - MEM-to-EX (10): WB-stage result → EX ALU input
//
//               Priority: EX-to-EX (newer instruction) wins
//               over MEM-to-EX when both match.
//
//               forward_a/b encoding:
//                 00 = use register file value (no hazard)
//                 01 = use EX/MEM alu_result (1-instr-ago result)
//                 10 = use WB writeback data  (2-instr-ago result)
// ============================================================

`timescale 1ns / 1ps

module forwarding_unit (
    input  [4:0] ex_rs1,           // source reg 1 of EX-stage instruction
    input  [4:0] ex_rs2,           // source reg 2 of EX-stage instruction
    input  [4:0] mem_rd,           // destination of MEM-stage instruction
    input        mem_reg_write,    // does MEM-stage instruction write a register?
    input  [4:0] wb_rd,            // destination of WB-stage instruction
    input        wb_reg_write,     // does WB-stage instruction write a register?
    output reg [1:0] forward_a,    // mux select for ALU input A / rs1
    output reg [1:0] forward_b     // mux select for ALU input B / rs2
);

    // ----- Forward A (rs1 path) -----
    always @(*) begin
        if (mem_reg_write && (mem_rd != 5'd0) && (mem_rd == ex_rs1))
            forward_a = 2'b01;    // EX-to-EX: forward from EX/MEM
        else if (wb_reg_write && (wb_rd != 5'd0) && (wb_rd == ex_rs1))
            forward_a = 2'b10;    // MEM-to-EX: forward from MEM/WB
        else
            forward_a = 2'b00;    // no forwarding
    end

    // ----- Forward B (rs2 path) -----
    always @(*) begin
        if (mem_reg_write && (mem_rd != 5'd0) && (mem_rd == ex_rs2))
            forward_b = 2'b01;    // EX-to-EX: forward from EX/MEM
        else if (wb_reg_write && (wb_rd != 5'd0) && (wb_rd == ex_rs2))
            forward_b = 2'b10;    // MEM-to-EX: forward from MEM/WB
        else
            forward_b = 2'b00;    // no forwarding
    end

endmodule
