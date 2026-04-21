// ============================================================
// Module : btb (Branch Target Buffer)
// Project : RISC-V Pipelined CPU — Phase 2
// Description : 16-entry direct-mapped BTB with 2-bit
//               saturating counters. Sits in the IF stage.
//
//   Index  : PC[5:2]  (4 bits → 16 entries)
//   Tag    : PC[31:6] (26 bits, to detect aliasing)
//   Counter: 00=strong-not-taken, 01=weak-not-taken,
//            10=weak-taken, 11=strong-taken
//            MSB=1 → predict taken
//
//   Lookup (combinational): hit = valid && tag match
//   predict_taken = hit && counter[1]
//
//   Update (sequential, EX stage): only on branches.
//   Allocates entry on first encounter. Updates counter
//   using actual outcome. Updates target on taken.
// ============================================================

`timescale 1ns / 1ps

module btb #(parameter ENTRIES = 16) (
    input         clk,
    input         reset,

    // ---- Lookup port (IF stage, combinational) ----
    input  [31:0] lookup_pc,
    output        predict_taken,
    output [31:0] predict_target,

    // ---- Update port (EX stage, on branch resolution) ----
    input         update_en,      // 1 when a branch resolves in EX
    input  [31:0] update_pc,      // PC of the branch instruction
    input         update_taken,   // actual branch outcome
    input  [31:0] update_target   // actual branch target (PC + imm)
);

    localparam IDX_BITS = 4;  // log2(ENTRIES)
    localparam TAG_BITS = 26; // 32 - IDX_BITS - 2 (lower 2 bits always 0)

    reg              valid   [0:ENTRIES-1];
    reg [TAG_BITS-1:0] tag   [0:ENTRIES-1];
    reg [31:0]       target  [0:ENTRIES-1];
    reg [1:0]        counter [0:ENTRIES-1];

    // ---- Lookup ----
    wire [IDX_BITS-1:0] lu_idx = lookup_pc[5:2];
    wire [TAG_BITS-1:0] lu_tag = lookup_pc[31:6];

    wire lu_hit = valid[lu_idx] && (tag[lu_idx] == lu_tag);

    assign predict_taken  = lu_hit && counter[lu_idx][1];
    assign predict_target = target[lu_idx];

    // ---- Update ----
    wire [IDX_BITS-1:0] up_idx = update_pc[5:2];
    wire [TAG_BITS-1:0] up_tag = update_pc[31:6];

    integer i;
    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < ENTRIES; i = i + 1) begin
                valid[i]   <= 1'b0;
                tag[i]     <= {TAG_BITS{1'b0}};
                target[i]  <= 32'b0;
                counter[i] <= 2'b01; // weak not-taken (biased conservative)
            end
        end else if (update_en) begin
            valid[up_idx]  <= 1'b1;
            tag[up_idx]    <= up_tag;
            // Only update target when branch is taken (keep last-taken target)
            if (update_taken)
                target[up_idx] <= update_target;
            // 2-bit saturating counter
            if (update_taken) begin
                if (counter[up_idx] != 2'b11)
                    counter[up_idx] <= counter[up_idx] + 1'b1;
            end else begin
                if (counter[up_idx] != 2'b00)
                    counter[up_idx] <= counter[up_idx] - 1'b1;
            end
        end
    end

endmodule
