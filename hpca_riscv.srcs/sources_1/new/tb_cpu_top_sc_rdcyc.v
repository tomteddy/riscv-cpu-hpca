// ============================================================
// Module : tb_cpu_top_sc_rdcyc
// Project : RV32I Single-Cycle CPU — Phase 4 benchmark driver
// Description : Same driver as tb_cpu_top_mext_rdcyc but runs
//               cpu_top_sc_rdcyc (single-cycle baseline).
//
//   Usage: identical to tb_cpu_top_mext_rdcyc —
//     1. Build: tools\build.bat tests\<name>.c
//     2. Copy .hex files to sim dir as instructions.hex / data.hex
//     3. Set this module as simulation top in Vivado.
//     4. Run Behavioral Simulation → "Run All".
//     5. Read elapsed cycle count from Tcl console.
//
//   Halt detection: counts IF fetches of the halt instruction
//   32'h00000063 (beq x0,x0,0). Works without BTB/pipeline.
// ============================================================

`timescale 1ns / 1ps

module tb_cpu_top_sc_rdcyc;

    parameter HALT_WINDOW = 5;      // halt-instr fetch hits before declaring halt
    parameter TIMEOUT     = 2000000; // single-cycle is ~4-5× slower in cycles than pipelined

    reg clk, reset;

    cpu_top_sc_rdcyc uut (
        .clk(clk), .reset(reset)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    // ---- Halt detection (instruction-based, same as pipelined TB) ----
    localparam [31:0] HALT_INSTR = 32'h00000063;
    integer halt_hits;
    reg     halted;

    always @(posedge clk) begin
        if (reset) begin
            halt_hits <= 0;
            halted    <= 1'b0;
        end else if (!halted) begin
            if (uut.if_instr === HALT_INSTR)
                halt_hits <= halt_hits + 1;
            if (halt_hits >= HALT_WINDOW - 1)
                halted <= 1'b1;
        end
    end

    // ---- Main flow ----
    integer cycle_count;
    reg [31:0] start_cycle, end_cycle;

    initial begin
        $readmemh("data.hex", uut.dmem.mem);

        $display("====================================================");
        $display("  PHASE 4 BENCHMARK DRIVER — cpu_top_sc_rdcyc       ");
        $display("====================================================");

        // ---- RDCYC sanity check ----
        reset = 1'b1;
        repeat(3) @(posedge clk);
        #1;
        if (uut.cycle_counter !== 32'd0) begin
            $display("FAIL: cycle_counter not 0 during reset (got %0d)", uut.cycle_counter);
            $finish;
        end

        @(negedge clk); reset = 1'b0;
        repeat(4) @(posedge clk); #1;
        if (uut.cycle_counter < 32'd3) begin
            $display("FAIL: cycle_counter not incrementing (got %0d after 4 clocks)", uut.cycle_counter);
            $finish;
        end
        $display("PASS: cycle_counter increments correctly");

        // ---- Reset for clean benchmark run ----
        reset = 1'b1;
        repeat(5) @(posedge clk);
        @(negedge clk); reset = 1'b0;
        $display("PASS: reset done");

        @(posedge clk); #1;
        start_cycle = uut.cycle_counter;

        // ---- Run until halt or timeout ----
        cycle_count = 0;
        while (!halted && cycle_count < TIMEOUT) begin
            @(posedge clk); #1;
            cycle_count = cycle_count + 1;
            if (cycle_count % 10000 == 0)
                $display("  Running... %0d cycles (PC=0x%08h, halt_hits=%0d)", cycle_count, uut.if_pc_out, halt_hits);
        end

        // ---- Report ----
        $display("====================================================");
        if (!halted) begin
            $display("TIMEOUT: benchmark did not halt within %0d cycles", TIMEOUT);
        end else begin
            end_cycle = uut.cycle_counter;
            $display("BENCHMARK COMPLETE");
            $display("  Counter at start : %0d", start_cycle);
            $display("  Counter at halt  : %0d", end_cycle);
            $display("  Elapsed cycles   : %0d", end_cycle - start_cycle);
            $display("  (PC held at      : 0x%08h)", uut.if_pc_out);
        end
        $display("====================================================");

        $finish;
    end

endmodule
