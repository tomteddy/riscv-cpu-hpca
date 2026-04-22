// ============================================================
// Module : tb_cpu_top_mext_rdcyc
// Project : RV32I Pipelined CPU — Phase 4 testbench
// Description : Reusable benchmark driver for cpu_top_mext_rdcyc.
//
//   Usage:
//     1. Build a benchmark:  tools\build.bat tests\<name>.c
//     2. Copy output to sim working dir:
//          copy tests\<name>.instructions.hex instructions.hex
//          copy tests\<name>.data.hex        data.hex
//     3. Set this module as simulation top in Vivado.
//     4. Run Behavioral Simulation → "Run All".
//     5. Read elapsed cycle count from Tcl console.
//
//   Measurement:
//     - start_cycle = uut.cycle_counter captured right after reset
//     - end_cycle   = uut.cycle_counter captured when halt loop detected
//     - halt loop detected when PC stops changing for HALT_WINDOW cycles
//
//   RDCYC sanity check: verifies cycle_counter increments every clock
//   before releasing reset and starting the benchmark.
//
//   Timeout: 500000 cycles. Matmul (8×8) with 512 multiplies can take
//   ~300K+ cycles due to memory access patterns and pipeline overhead.
// ============================================================

`timescale 1ns / 1ps

module tb_cpu_top_mext_rdcyc;

    parameter HALT_WINDOW = 5;     // cycles with same PC → halt declared
    parameter TIMEOUT     = 500000; // increased for matmul/dotprod (300K+ cycles)

    reg clk, reset;

    cpu_top_mext_rdcyc uut (
        .clk(clk), .reset(reset)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    // ---- Halt detection ----
    // Halt instruction is `beq x0,x0,0` (32'h00000063) in startup.S. We count
    // how many times IF fetches that exact encoding. We don't require the PC
    // to be stable — with BTB disabled, the halt BEQ mispredicts every
    // iteration so PC cycles through 0x08 -> 0x0C -> 0x10 -> 0x08 ... We just
    // need to see the halt instruction enter IF enough times to be confident
    // execution has truly reached the halt loop (not a speculative fetch
    // during _start's jal). Works whether BTB is on or off.
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
        // Load data memory (silently ignored if data.hex doesn't exist)
        $readmemh("data.hex", uut.dmem.mem);
        // instructions.hex auto-loaded by instruction_memory

//        $dumpfile("tb_cpu_top_mext_rdcyc.vcd");
//        $dumpvars(0, tb_cpu_top_mext_rdcyc);

        $display("====================================================");
        $display("  PHASE 4 BENCHMARK DRIVER — cpu_top_mext_rdcyc     ");
        $display("====================================================");

        // ---- RDCYC sanity check (before benchmark) ----
        reset = 1'b1;
        repeat(3) @(posedge clk);
        #1;
        if (uut.cycle_counter !== 32'd0) begin
            $display("FAIL: cycle_counter not 0 during reset (got %0d)", uut.cycle_counter);
            $finish;
        end

        // Check counter increments correctly while still in reset-released mode
        @(negedge clk); reset = 1'b0;
        repeat(4) @(posedge clk); #1;
        if (uut.cycle_counter < 32'd3) begin
            $display("FAIL: cycle_counter not incrementing (got %0d after 4 clocks)", uut.cycle_counter);
            $finish;
        end
        $display("PASS: cycle_counter increments correctly");

        // ---- Reset again for clean benchmark run ----
        reset = 1'b1;
        repeat(5) @(posedge clk);
        @(negedge clk); reset = 1'b0;
        $display("PASS: reset done");

        // Capture start cycle (counter just cleared, pipeline filling)
        @(posedge clk); #1;
        start_cycle = uut.cycle_counter;

        // ---- Run until halt or timeout ----
        cycle_count = 0;
        while (!halted && cycle_count < TIMEOUT) begin
            @(posedge clk); #1;
            cycle_count = cycle_count + 1;
//            $display("  Running... %0d cycles (PC=0x%08h, halt_hits=%0d)", cycle_count, uut.if_pc_out, halt_hits);
            if (cycle_count % 10000 == 0)
                $display("  Running... %0d cycles (PC=0x%08h, halt_hits=%0d)", cycle_count, uut.if_pc_out, halt_hits);
        end

        // ---- Report ----
        $display("====================================================");
        if (!halted) begin
            $display("TIMEOUT: benchmark did not reach halt within %0d cycles", TIMEOUT);
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
