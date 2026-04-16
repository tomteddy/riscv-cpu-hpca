// ============================================================
// Module : if_id_reg
// Project : RISC-V 5-Stage Pipelined CPU
// Description : IF/ID pipeline register.
//               Latches PC and instruction between Fetch and
//               Decode stages. Supports stall (hold) for
//               load-use hazards and flush (NOP insert) for
//               branch/jump mispredicts.
// ============================================================

`timescale 1ns / 1ps

module if_id_reg (
    input         clk,
    input         reset,
    input         stall,       // 1 = hold current value (load-use hazard)
    input         flush,       // 1 = insert NOP bubble (branch taken / jump)
    input  [31:0] if_pc,       // PC from IF stage
    input  [31:0] if_instr,    // Instruction from IMEM
    output reg [31:0] id_pc,
    output reg [31:0] id_instr
);

    always @(posedge clk) begin
        if (reset || flush) begin
            id_pc    <= 32'b0;
            id_instr <= 32'h00000013;  // NOP: ADDI x0, x0, 0
        end else if (!stall) begin
            id_pc    <= if_pc;
            id_instr <= if_instr;
        end
        // stall: hold current values (do nothing)
    end

endmodule
