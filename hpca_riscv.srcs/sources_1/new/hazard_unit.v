// ============================================================
// Module : hazard_unit
// Project : RISC-V 5-Stage Pipelined CPU
// Description : Detects pipeline hazards and generates
//               stall/flush control signals.
//
//   1. Load-use hazard: EX-stage is a load (wb_sel==01) and
//      ID-stage reads its destination. Response: stall PC and
//      IF/ID for 1 cycle, flush ID/EX (insert NOP bubble).
//      After the stall, MEM-to-EX forwarding delivers the
//      loaded value.
//
//   2. Branch/jump flush: When a branch is taken or a jump
//      executes in EX, the 2 instructions fetched after it
//      (in IF and ID) are wrong. Response: flush both IF/ID
//      and ID/EX (2-cycle penalty).
// ============================================================

`timescale 1ns / 1ps

module hazard_unit (
    // ----- Load-use detection -----
    input  [4:0] id_rs1,          // rs1 of instruction in ID stage
    input  [4:0] id_rs2,          // rs2 of instruction in ID stage
    input  [4:0] ex_rd,           // rd of instruction in EX stage
    input  [1:0] ex_wb_sel,       // wb_sel of EX-stage instruction (01 = load)

    // ----- Branch/jump detection -----
    input        branch_taken,    // branch resolved as taken in EX
    input        ex_jump,         // jump instruction in EX stage

    // ----- Outputs -----
    output       stall,           // 1 = stall PC and IF/ID (hold values)
    output       flush_if_id,     // 1 = flush IF/ID register (insert NOP)
    output       flush_id_ex      // 1 = flush ID/EX register (insert NOP)
);

    // Load-use hazard: EX-stage is a load AND ID-stage reads its destination
    wire load_use = (ex_wb_sel == 2'b01) && (ex_rd != 5'd0) &&
                    ((ex_rd == id_rs1) || (ex_rd == id_rs2));

    // Branch/jump hazard: control flow change resolved in EX
    wire branch_flush = branch_taken || ex_jump;

    // Stall: freeze PC and IF/ID for load-use hazard only
    assign stall = load_use;

    // Flush IF/ID: kill instruction in ID on branch/jump
    assign flush_if_id = branch_flush;

    // Flush ID/EX: insert bubble on load-use stall OR branch/jump
    assign flush_id_ex = load_use || branch_flush;

endmodule
