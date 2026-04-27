// ============================================================
// Module : tb_cpu_top_sc_rdcyc
// Project : RV32I Single-Cycle CPU — Phase 4 validation testbench
//
// Same validation logic as tb_cpu_top_mext_rdcyc but instantiates
// cpu_top_sc_rdcyc. Reads the validate_write() block at DMEM[0x3F00],
// looks up expected results by benchmark id, compares, prints summary,
// and appends a row to results.csv.
// ============================================================

`timescale 1ns / 1ps

module tb_cpu_top_sc_rdcyc;

    parameter HALT_WINDOW = 5;
    parameter TIMEOUT     = 2000000;
    localparam VALIDATE_BASE_BYTE = 32'h00003F00;

    reg clk, reset;

    cpu_top_sc_rdcyc uut (
        .clk(clk), .reset(reset),
        .o_pc(), .o_cycle_counter(), .o_wb_data(), .o_instr_retired()
    );

    initial clk = 0;
    always #5 clk = ~clk;

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

    localparam MAX_RESULTS = 32;
    reg [31:0]  expected   [1:9][0:MAX_RESULTS-1];
    integer     exp_count  [1:9];
    reg [255:0] bench_name [1:9];

    integer ti;
    initial begin
        for (ti = 1; ti <= 9; ti = ti + 1) begin
            exp_count[ti]  = 0;
            bench_name[ti] = "unknown";
        end
        bench_name[1] = "fib_20";              exp_count[1] = 1; expected[1][0] = 32'd6765;
        bench_name[2] = "dotprod_16";          exp_count[2] = 1; expected[2][0] = 32'd1496;
        bench_name[3] = "dotprod_16_nocust";   exp_count[3] = 1; expected[3][0] = 32'd1496;

        bench_name[4] = "matmul_8x8";          exp_count[4] = 8;
        expected[4][0]=32'd8;  expected[4][1]=32'd16; expected[4][2]=32'd24; expected[4][3]=32'd32;
        expected[4][4]=32'd40; expected[4][5]=32'd48; expected[4][6]=32'd56; expected[4][7]=32'd64;

        bench_name[5] = "matmul_8x8_nocust";   exp_count[5] = 8;
        expected[5][0]=32'd8;  expected[5][1]=32'd16; expected[5][2]=32'd24; expected[5][3]=32'd32;
        expected[5][4]=32'd40; expected[5][5]=32'd48; expected[5][6]=32'd56; expected[5][7]=32'd64;

        bench_name[6] = "relu_32";             exp_count[6] = 32;
        for (ti = 0;  ti < 16; ti = ti + 1) expected[6][ti] = 32'd0;
        for (ti = 16; ti < 32; ti = ti + 1) expected[6][ti] = ti - 16;

        bench_name[7] = "relu_32_nocust";      exp_count[7] = 32;
        for (ti = 0;  ti < 16; ti = ti + 1) expected[7][ti] = 32'd0;
        for (ti = 16; ti < 32; ti = ti + 1) expected[7][ti] = ti - 16;

        bench_name[8] = "grad_descent";        exp_count[8] = 4;
        expected[8][0]=32'd2; expected[8][1]=32'd2; expected[8][2]=32'd2; expected[8][3]=32'd2;

        bench_name[9] = "grad_descent_nocust"; exp_count[9] = 4;
        expected[9][0]=32'd2; expected[9][1]=32'd2; expected[9][2]=32'd2; expected[9][3]=32'd2;
    end

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

    integer cycle_count, fd, k;
    reg [31:0] start_cycle, end_cycle;
    reg [31:0] start_retired, end_retired;
    reg [31:0] elapsed_cycles, elapsed_retired;
    reg [31:0] magic, id, n_results, actual, expv;
    reg        all_ok;

    initial begin
        load_data_hex();

        $display("============================================================");
        $display("  PHASE 4 VALIDATION TB — single-cycle");
        $display("============================================================");

        reset = 1'b1;
        repeat(3) @(posedge clk); #1;
        if (uut.cycle_counter !== 32'd0) begin
            $display("FAIL: cycle_counter not 0 during reset");
            $finish;
        end
        @(negedge clk); reset = 1'b0;
        repeat(4) @(posedge clk); #1;
        if (uut.cycle_counter < 32'd3) begin
            $display("FAIL: cycle_counter not incrementing");
            $finish;
        end
        $display("PASS: cycle_counter increments correctly");

        reset = 1'b1;
        repeat(5) @(posedge clk);
        @(negedge clk); reset = 1'b0;

        @(posedge clk); #1;
        start_cycle   = uut.cycle_counter;
        start_retired = uut.o_instr_retired;

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
        end_retired     = uut.o_instr_retired;
        elapsed_cycles  = end_cycle   - start_cycle;
        elapsed_retired = end_retired - start_retired;

        magic     = dmem_word(VALIDATE_BASE_BYTE);
        n_results = dmem_word(VALIDATE_BASE_BYTE + 4);

        if (magic[31:16] !== 16'hBEEF) begin
            $display("ERROR: validation block magic invalid (0x%08h)", magic);
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

        fd = $fopen("results.csv", "a");
        if (fd) begin
            $fwrite(fd, "%0s,%0s,%0d,%0d,%0d,%0s\n",
                bench_name[id], "single_cycle",
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
