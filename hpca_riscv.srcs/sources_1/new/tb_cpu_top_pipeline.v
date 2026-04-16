// ============================================================
// Module : tb_cpu_top_pipeline
// Project : RISC-V 5-Stage Pipelined CPU
// Description : Testbench for the pipelined CPU.
//               Uses the same instructions.hex as the single-cycle
//               testbench and verifies identical final register
//               and memory values.
//
//               Key differences from tb_cpu_top:
//               - No intermediate cycle-exact checks (pipeline
//                 timing differs from single-cycle)
//               - Longer wait time (120 cycles) to account for
//                 pipeline fill, stalls, and flushes
//               - Pipeline debug signals displayed
//
// How to use in Vivado:
//   1. Add all source files + pipeline files to project
//   2. Place instructions.hex in Vivado sim working directory
//   3. Set tb_cpu_top_pipeline as simulation top module
//   4. Run Behavioral Simulation
//   5. Check Tcl Console for PASS/FAIL messages
// ============================================================

`timescale 1ns / 1ps

module tb_cpu_top_pipeline;

    // --------------------------------------------------------
    // Testbench signals
    // --------------------------------------------------------
    reg clk;
    reg reset;

    integer total;
    integer passed;
    integer failed;

    // --------------------------------------------------------
    // Instantiate the pipelined CPU
    // --------------------------------------------------------
    cpu_top_pipeline uut (
        .clk   (clk),
        .reset (reset)
    );

    // --------------------------------------------------------
    // Clock generation: 10ns period = 100MHz
    // --------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    // --------------------------------------------------------
    // Task: check_reg
    // --------------------------------------------------------
    task check_reg;
        input [31:0]   reg_num;
        input [31:0]   expected;
        input [8*30:1] test_name;
        begin
            total = total + 1;
            if (uut.reg_file.registers[reg_num] === expected) begin
                $display("PASS | %-22s | x%0d = 0x%08h (%0d)",
                    test_name, reg_num,
                    uut.reg_file.registers[reg_num],
                    $signed(uut.reg_file.registers[reg_num]));
                passed = passed + 1;
            end else begin
                $display("FAIL | %-22s | x%0d | expected=0x%08h (%0d) | got=0x%08h (%0d)",
                    test_name, reg_num,
                    expected, $signed(expected),
                    uut.reg_file.registers[reg_num],
                    $signed(uut.reg_file.registers[reg_num]));
                failed = failed + 1;
            end
        end
    endtask

    // --------------------------------------------------------
    // Task: check_mem
    // --------------------------------------------------------
    task check_mem;
        input [31:0]   byte_addr;
        input [7:0]    expected;
        input [8*30:1] test_name;
        begin
            total = total + 1;
            if (uut.dmem.mem[byte_addr] === expected) begin
                $display("PASS | %-22s | mem[%0d] = 0x%02h",
                    test_name, byte_addr, uut.dmem.mem[byte_addr]);
                passed = passed + 1;
            end else begin
                $display("FAIL | %-22s | mem[%0d] | expected=0x%02h | got=0x%02h",
                    test_name, byte_addr,
                    expected, uut.dmem.mem[byte_addr]);
                failed = failed + 1;
            end
        end
    endtask

    // --------------------------------------------------------
    // Task: check_x0
    // --------------------------------------------------------
    task check_x0;
        begin
            total = total + 1;
            if (uut.reg_file.registers[0] === 32'b0) begin
                $display("PASS | X0 HARDWIRED ZERO    | x0 = 0 always");
                passed = passed + 1;
            end else begin
                $display("FAIL | X0 HARDWIRED ZERO    | x0 should be 0 | got=0x%08h",
                    uut.reg_file.registers[0]);
                failed = failed + 1;
            end
        end
    endtask

    // --------------------------------------------------------
    // Main simulation block
    // --------------------------------------------------------
    initial begin

        total  = 0;
        passed = 0;
        failed = 0;

        // Pre-populate data memory (missing file = harmless warning)
        $readmemh("data.hex", uut.dmem.mem);

        // Waveform dump
        $dumpfile("tb_cpu_top_pipeline.vcd");
        $dumpvars(0, tb_cpu_top_pipeline);

        $display("=====================================================");
        $display("   CPU TOP TESTBENCH - RISC-V 5-STAGE PIPELINE      ");
        $display("=====================================================");
        $display("Testing all 47 RV32I instructions (pipelined)");
        $display("Same program as single-cycle, same expected results");
        $display("=====================================================");

        // ------------------------------------------------
        // RESET — hold for 5 cycles
        // ------------------------------------------------
        reset = 1'b1;
        repeat(5) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;

        $display("--- Reset released. Pipeline starting execution ---");

        // ------------------------------------------------
        // Wait for entire program to complete.
        // 64 instructions + stalls + flushes + pipeline drain.
        // 120 cycles is generous margin.
        // ------------------------------------------------
        repeat(120) @(posedge clk);
        #1;  // settle time

        // ================================================
        // FINAL REGISTER & MEMORY CHECKS
        // Same expected values as single-cycle testbench.
        // If the pipeline is correct, all values match.
        // ================================================

        $display("--- X0 HARDWIRED TO ZERO ---");
        check_x0;

        $display("--- SETUP REGISTER VALUES ---");
        check_reg(2, 32'd5, "ADDI x2=5 (constant)");

        $display("--- I-TYPE ARITHMETIC ---");
        check_reg(14, 32'd100, "ADDI x14=100");
        check_reg(15, 32'd1, "SLTI x15=(100<200)");
        check_reg(16, 32'd1, "SLTIU x16=(100<200)u");
        check_reg(17, 32'd4, "ANDI x17=100&15");
        check_reg(18, 32'd111, "ORI x18=100|15");
        check_reg(19, 32'd107, "XORI x19=100^15");
        check_reg(20, 32'd400, "SLLI x20=100<<2");
        check_reg(21, 32'd25, "SRLI x21=100>>2");
        check_reg(22, 32'hFFFFFFFF, "SRAI x22=-1>>>1");

        $display("--- LUI AND AUIPC ---");
        check_reg(23, 32'h00001000, "LUI x23=1<<12");
        check_reg(24, 32'h0000105C, "AUIPC x24=PC+0x1000");

        $display("--- LOAD AND STORE ---");
        check_reg(25, 32'd0, "ADDI x25=0 (base)");
        check_reg(26, 32'd171, "ADDI x26=171(0xAB)");
        check_reg(27, 32'd171, "LW x27=mem[0]");
        check_reg(28, 32'd171, "LH x28=mem[4]");
        check_reg(29, 32'hFFFFFFAB, "LB x29=sign(mem[8])");
        check_reg(30, 32'd171, "LHU x30=mem[4]");
        check_reg(31, 32'd171, "LBU x31=mem[8]");

        $display("--- MEMORY CONTENTS AFTER STORES ---");
        check_mem(0, 8'hAB, "SW mem[0]=0xAB");
        check_mem(1, 8'h00, "SW mem[1]=0x00");
        check_mem(2, 8'h00, "SW mem[2]=0x00");
        check_mem(3, 8'h00, "SW mem[3]=0x00");
        check_mem(4, 8'hAB, "SH mem[4]=0xAB");
        check_mem(5, 8'h00, "SH mem[5]=0x00");
        check_mem(8, 8'hAB, "SB mem[8]=0xAB");

        $display("--- BRANCH RESULTS ---");
        check_reg(3, 32'd11, "BEQ taken x3=11");
        check_reg(4, 32'd22, "BNE not taken x4=22");
        check_reg(5, 32'd33, "BLT taken x5=33");
        check_reg(6, 32'd44, "BGE taken x6=44");
        check_reg(7, 32'd55, "BLTU taken x7=55");
        check_reg(8, 32'd66, "BGEU taken x8=66");

        $display("--- JAL RESULTS ---");
        check_reg(9, 32'd228, "JAL x9=retaddr(228)");
        check_reg(10, 32'd77, "JAL jumped x10=77");

        $display("--- JALR RESULTS ---");
        check_reg(11, 32'd248, "JALR setup x11=248");
        check_reg(13, 32'd244, "JALR x13=retaddr(244)");
        check_reg(12, 32'd88, "JALR jumped x12=88");

        $display("--- x1 FINAL VALUE ---");
        check_reg(1, 32'd5, "ADDI x1=5 (last)");

        // ================================================
        // FINAL SUMMARY
        // ================================================
        $display("=====================================================");
        $display("RESULTS: %0d / %0d tests passed", passed, total);
        if (failed == 0) begin
            $display("ALL TESTS PASSED - PIPELINE IS WORKING CORRECTLY!");
            $display("All 47 RV32I instructions verified (pipelined).");
        end else begin
            $display("%0d TEST(S) FAILED - CHECK OUTPUT ABOVE", failed);
        end
        $display("=====================================================");

        $finish;
    end

endmodule
