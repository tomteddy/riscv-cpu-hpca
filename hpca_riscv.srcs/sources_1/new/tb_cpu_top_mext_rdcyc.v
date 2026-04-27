// ============================================================
// Module : tb_cpu_top_mext_rdcyc
// Project : RV32I Pipelined CPU — Phase 4 validation testbench
//
// One TB drives any of the 9 instrumented benchmarks. Each benchmark's
// main() calls validate_write(id, results, n) (see tests/validate.h)
// which writes a structured block at DMEM[0x3F00..]:
//
//   word 0 : magic = 0xBEEF0000 | id
//   word 1 : n  (number of result words)
//   word 2+: result[0..n-1]
//
// At halt the TB reads this block, identifies the benchmark by id,
// looks up its expected results in a hardcoded table, compares each
// word, and prints a summary plus appends a row to results.csv.
//
// CSV columns:
//   benchmark, config, cycles, instr_retired, cpi, pass
//
// Usage (per benchmark):
//   1. tools\build.bat tests\<name>.c
//   2. copy tests\<name>.instructions.hex instructions.hex
//      copy tests\<name>.data.hex        data.hex
//   3. Set this TB as simulation top, Run All.
//
// USE_BTB = 1 default. To run pipeline-no-BTB: set USE_BTB = 0.
// ============================================================

`timescale 1ns / 1ps

module tb_cpu_top_mext_rdcyc;

    parameter HALT_WINDOW = 5;
    parameter TIMEOUT     = 500000;
    parameter USE_BTB     = 1;
    localparam VALIDATE_BASE_BYTE = 32'h00003F00;
    localparam VALIDATE_BASE_WORD = VALIDATE_BASE_BYTE >> 2; // word index in DMEM

    reg clk, reset;

    cpu_top_mext_rdcyc #(.USE_BTB(USE_BTB)) uut (
        .clk(clk), .reset(reset),
        .o_pc(), .o_cycle_counter(), .o_wb_data(), .o_instr_retired()
    );

    initial clk = 0;
    always #5 clk = ~clk;

    // ---- Halt detection: count IF fetches of `beq x0,x0,0` (32'h00000063) ----
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

    // ================================================================
    //  Expected-results table.
    //  Indexed by benchmark id (1..9). expected[id][k] = expected word k.
    //  count[id] = number of result words.
    // ================================================================
    localparam MAX_RESULTS = 32;
    reg [31:0]  expected   [1:9][0:MAX_RESULTS-1];
    integer     exp_count  [1:9];
    reg [255:0] bench_name [1:9];   // up to 32 chars

    integer ti;
    initial begin
        // --- defaults ---
        for (ti = 1; ti <= 9; ti = ti + 1) begin
            exp_count[ti]  = 0;
            bench_name[ti] = "unknown";
        end

        // 1: fib_20 → fib(20) = 6765
        bench_name[1] = "fib_20";
        exp_count[1]  = 1;
        expected[1][0] = 32'd6765;

        // 2: dotprod_16 → 1496
        bench_name[2] = "dotprod_16";
        exp_count[2]  = 1;
        expected[2][0] = 32'd1496;

        // 3: dotprod_16_nocustom
        bench_name[3] = "dotprod_16_nocust";
        exp_count[3]  = 1;
        expected[3][0] = 32'd1496;

        // 4: matmul_8x8 → C[0][0..7] = {8,16,24,32,40,48,56,64}
        bench_name[4] = "matmul_8x8";
        exp_count[4]  = 8;
        expected[4][0] = 32'd8;  expected[4][1] = 32'd16;
        expected[4][2] = 32'd24; expected[4][3] = 32'd32;
        expected[4][4] = 32'd40; expected[4][5] = 32'd48;
        expected[4][6] = 32'd56; expected[4][7] = 32'd64;

        // 5: matmul_8x8_nocustom — same expected
        bench_name[5] = "matmul_8x8_nocust";
        exp_count[5]  = 8;
        expected[5][0] = 32'd8;  expected[5][1] = 32'd16;
        expected[5][2] = 32'd24; expected[5][3] = 32'd32;
        expected[5][4] = 32'd40; expected[5][5] = 32'd48;
        expected[5][6] = 32'd56; expected[5][7] = 32'd64;

        // 6: relu_32 → first 16 zeros, then 0..15
        bench_name[6] = "relu_32";
        exp_count[6]  = 32;
        for (ti = 0;  ti < 16; ti = ti + 1) expected[6][ti] = 32'd0;
        for (ti = 16; ti < 32; ti = ti + 1) expected[6][ti] = ti - 16;

        // 7: relu_32_nocustom — same expected
        bench_name[7] = "relu_32_nocust";
        exp_count[7]  = 32;
        for (ti = 0;  ti < 16; ti = ti + 1) expected[7][ti] = 32'd0;
        for (ti = 16; ti < 32; ti = ti + 1) expected[7][ti] = ti - 16;

        // 8: grad_descent → w = [2,2,2,2]
        bench_name[8] = "grad_descent";
        exp_count[8]  = 4;
        expected[8][0] = 32'd2; expected[8][1] = 32'd2;
        expected[8][2] = 32'd2; expected[8][3] = 32'd2;

        // 9: grad_descent_nocustom — same
        bench_name[9] = "grad_descent_nocust";
        exp_count[9]  = 4;
        expected[9][0] = 32'd2; expected[9][1] = 32'd2;
        expected[9][2] = 32'd2; expected[9][3] = 32'd2;
    end

    // ================================================================
    //  Helper: read a 32-bit word from data_memory at byte address `b`.
    //  data_memory is 4 byte-banks indexed by word address.
    // ================================================================
    function [31:0] dmem_word;
        input [31:0] byte_addr;
        reg   [11:0] wa;
        begin
            wa = byte_addr[13:2];
            dmem_word = { uut.dmem.mem3[wa],
                          uut.dmem.mem2[wa],
                          uut.dmem.mem1[wa],
                          uut.dmem.mem0[wa] };
        end
    endfunction

    // ================================================================
    //  Pre-load data.hex into the byte banks.
    //  We use a temp byte array (matching instruction_memory's pattern)
    //  to preserve the existing byte-format data.hex layout.
    // ================================================================
    reg [7:0] data_tmp [0:16383];
    integer di;
    task load_data_hex;
        begin
            for (di = 0; di < 16384; di = di + 1) data_tmp[di] = 8'b0;
            $readmemh("data.hex", data_tmp);
            for (di = 0; di < 4096; di = di + 1) begin
                uut.dmem.mem0[di] = data_tmp[4*di + 0];
                uut.dmem.mem1[di] = data_tmp[4*di + 1];
                uut.dmem.mem2[di] = data_tmp[4*di + 2];
                uut.dmem.mem3[di] = data_tmp[4*di + 3];
            end
        end
    endtask

    // ================================================================
    //  Main flow
    // ================================================================
    integer cycle_count, fd, k;
    reg [31:0] start_cycle, end_cycle;
    reg [31:0] start_retired, end_retired;
    reg [31:0] elapsed_cycles, elapsed_retired;
    reg [31:0] magic, id, n_results, actual, expv;
    reg        all_ok;
    reg [255:0] config_str;

    initial begin
        load_data_hex();

        $display("============================================================");
        $display("  PHASE 4 VALIDATION TB — pipeline (USE_BTB=%0d)", USE_BTB);
        $display("============================================================");

        // ---- RDCYC sanity check ----
        reset = 1'b1;
        repeat(3) @(posedge clk); #1;
        if (uut.cycle_counter !== 32'd0) begin
            $display("FAIL: cycle_counter not 0 during reset (got %0d)", uut.cycle_counter);
            $finish;
        end
        @(negedge clk); reset = 1'b0;
        repeat(4) @(posedge clk); #1;
        if (uut.cycle_counter < 32'd3) begin
            $display("FAIL: cycle_counter not incrementing");
            $finish;
        end
        $display("PASS: cycle_counter increments correctly");

        // ---- Reset for clean run ----
        reset = 1'b1;
        repeat(5) @(posedge clk);
        @(negedge clk); reset = 1'b0;

        @(posedge clk); #1;
        start_cycle   = uut.cycle_counter;
        start_retired = uut.instr_retired;

        cycle_count = 0;
        while (!halted && cycle_count < TIMEOUT) begin
            @(posedge clk); #1;
            cycle_count = cycle_count + 1;
            if (cycle_count % 20000 == 0)
                $display("  ... %0d cycles (PC=0x%08h)", cycle_count, uut.if_pc_out);
        end

        $display("============================================================");
        if (!halted) begin
            $display("TIMEOUT after %0d cycles", TIMEOUT);
            $finish;
        end

        end_cycle       = uut.cycle_counter;
        end_retired     = uut.instr_retired;
        elapsed_cycles  = end_cycle   - start_cycle;
        elapsed_retired = end_retired - start_retired;

        // ---- Read validation block ----
        magic     = dmem_word(VALIDATE_BASE_BYTE);
        n_results = dmem_word(VALIDATE_BASE_BYTE + 4);

        if (magic[31:16] !== 16'hBEEF) begin
            $display("ERROR: validation block magic invalid (0x%08h)", magic);
            $display("       — benchmark may not have called validate_write()");
            $finish;
        end
        id = magic & 32'h0000FFFF;
        if (id < 1 || id > 9) begin
            $display("ERROR: unknown benchmark id %0d", id);
            $finish;
        end

        $display("Benchmark         : %0s  (id=%0d)", bench_name[id], id);
        $display("Cycles elapsed    : %0d", elapsed_cycles);
        $display("Instr retired     : %0d", elapsed_retired);
        if (elapsed_retired > 0)
            $display("CPI (×1000)       : %0d", (elapsed_cycles * 1000) / elapsed_retired);

        // ---- Compare results ----
        $display("");
        $display("  idx |   expected |    actual  | status");
        $display("  ----+------------+------------+-------");
        all_ok = 1'b1;
        if (n_results !== exp_count[id]) begin
            $display("WARN: result count mismatch — got %0d, expected %0d", n_results, exp_count[id]);
            all_ok = 1'b0;
        end
        for (k = 0; k < n_results && k < MAX_RESULTS; k = k + 1) begin
            actual = dmem_word(VALIDATE_BASE_BYTE + 4*(2 + k));
            expv   = expected[id][k];
            if (actual === expv)
                $display("  %3d | %10d | %10d | PASS", k, $signed(expv), $signed(actual));
            else begin
                $display("  %3d | %10d | %10d | FAIL", k, $signed(expv), $signed(actual));
                all_ok = 1'b0;
            end
        end

        $display("");
        if (all_ok) $display("RESULT: PASS");
        else        $display("RESULT: FAIL");
        $display("============================================================");

        // ---- Append to results.csv ----
        config_str = (USE_BTB) ? "pipeline_btb" : "pipeline_nobtb";
        fd = $fopen("results.csv", "a");
        if (fd) begin
            // Header isn't auto-written (append mode). Document column order:
            // benchmark,config,cycles,instr_retired,cpi_x1000,pass
            $fwrite(fd, "%0s,%0s,%0d,%0d,%0d,%0s\n",
                bench_name[id], config_str,
                elapsed_cycles, elapsed_retired,
                (elapsed_retired > 0) ? (elapsed_cycles * 1000) / elapsed_retired : 0,
                all_ok ? "PASS" : "FAIL");
            $fclose(fd);
            $display("Appended to results.csv");
        end else begin
            $display("WARN: could not open results.csv for append");
        end

        $finish;
    end

endmodule
