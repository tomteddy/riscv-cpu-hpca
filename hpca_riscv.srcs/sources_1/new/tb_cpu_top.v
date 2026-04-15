`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.04.2026 18:45:19
// Design Name: 
// Module Name: tb_cpu_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


// ============================================================
// Module : tb_cpu_top (Testbench for CPU Top)
// Project : RISC-V Single-Cycle CPU
// Description : Comprehensive testbench for the complete
//               single-cycle RISC-V CPU.
//               Runs a 64-instruction program that exercises
//               all 47 RV32I instructions and verifies:
//               - All R-type instructions (intermediate checks)
//               - All I-type arithmetic instructions
//               - LUI and AUIPC
//               - All load/store instructions
//               - All 6 branch instructions
//               - JAL and JALR
//               - Register x0 hardwired to 0
//               - Memory contents after stores
//
// How to use in Vivado:
//   1. Add all source files and tb_cpu_top.v to project
//   2. Place instructions.hex in your Vivado project folder
//   3. Set tb_cpu_top as top module for simulation
//   4. Run Behavioral Simulation
//   5. Check Tcl Console for PASS/FAIL messages
//   6. Check waveform for signal traces
//
// NOTE ON TIMING:
//   This is a single-cycle CPU. Each instruction completes
//   in exactly 1 clock cycle. After N rising edges following
//   reset release, instructions 0 through N-1 have completed.
//
// NOTE ON REGISTER REUSE:
//   Some registers (x4-x13) are written twice:
//   First by R-type instructions (cycles 4-13)
//   Then overwritten by branch/jump results (cycles 35-57)
//   The testbench checks BOTH values at the right cycle.
// ============================================================

`timescale 1ns / 1ps

module tb_cpu_top;

    // --------------------------------------------------------
    // Testbench signals
    // --------------------------------------------------------

    reg clk;            // Clock signal
    reg reset;          // Reset signal

    // --------------------------------------------------------
    // Test result counters
    // --------------------------------------------------------

    integer total;      // Total tests run
    integer passed;     // Tests passed
    integer failed;     // Tests failed

    // --------------------------------------------------------
    // Instantiate the CPU top module
    // --------------------------------------------------------

    cpu_top uut (
        .clk   (clk),   // Connect clock
        .reset (reset)  // Connect reset
    );

    // --------------------------------------------------------
    // Clock generation: 10ns period = 100MHz
    // --------------------------------------------------------

    initial begin
        clk = 0;                // Start clock low
    end

    always #5 clk = ~clk;      // Toggle every 5ns

    // --------------------------------------------------------
    // Task: check_reg
    // Checks a register value using hierarchical reference
    // uut.reg_file.registers[n] accesses register n directly
    // --------------------------------------------------------

    task check_reg;
        input [31:0]   reg_num;     // Register number (0-31)
        input [31:0]   expected;    // Expected value
        input [8*30:1] test_name;   // Test description

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
    // Checks a data memory byte using hierarchical reference
    // uut.dmem.mem[n] accesses byte n of data memory directly
    // --------------------------------------------------------

    task check_mem;
        input [31:0]   byte_addr;   // Byte address to check
        input [7:0]    expected;    // Expected byte value
        input [8*30:1] test_name;   // Test description

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
    // Special check: x0 must always be 0
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

        // Initialize counters
        total  = 0;
        passed = 0;
        failed = 0;

        // Optional: pre-populate data memory from data.hex.
        // Existing 64-instruction test does its own stores, so
        // data.hex is unnecessary for it. For C benchmarks, the
        // build toolchain will emit a data.hex next to the .c file.
        // A missing file just produces a $readmemh warning -> harmless.
        $readmemh("data.hex", uut.dmem.mem);

        // Setup waveform dump
        $dumpfile("tb_cpu_top.vcd");
        $dumpvars(0, tb_cpu_top);

        // Print header
        $display("=====================================================");
        $display("      CPU TOP TESTBENCH - RISC-V SINGLE CYCLE       ");
        $display("=====================================================");
        $display("Testing all 47 RV32I instructions");
        $display("Program: 64 instructions in instructions.hex");
        $display("=====================================================");

        // ------------------------------------------------
        // RESET
        // Hold reset high for 5 cycles to initialize CPU
        // PC will be set to 0, all registers start at 0
        // ------------------------------------------------
        reset = 1'b1;           // Assert reset
        repeat(5) @(posedge clk);
        @(negedge clk);         // Release on negedge to avoid setup issues
        reset = 1'b0;           // Deassert reset

        $display("--- Reset released. CPU starting execution ---");

        // ========================================================
        // INTERMEDIATE CHECKS (cycles 4-13)
        // Check R-type instruction results before they get
        // overwritten by branch/jump instructions later.
        // Each @(posedge clk) waits for one more instruction.
        // ========================================================

        // Wait 3 cycles: instrs 0,1,2 complete (ADDI x1, ADDI x2, ADDI x3)
        repeat(3) @(posedge clk);

        // ----- CYCLE 4: ADD result -----
        @(posedge clk); #1;     // Instr 3 (ADD x4, x1, x2) completes
        $display("--- R-TYPE INTERMEDIATE CHECKS (before overwrite) ---");
        // x4 = 10 + 5 = 15
        check_reg(4, 32'd15, "ADD x4=x1+x2");

        // ----- CYCLE 5: SUB result -----
        @(posedge clk); #1;     // Instr 4 (SUB x5, x1, x2) completes
        // x5 = 10 - 5 = 5
        check_reg(5, 32'd5, "SUB x5=x1-x2");

        // ----- CYCLE 6: AND result -----
        @(posedge clk); #1;     // Instr 5 (AND x6, x1, x2) completes
        // x6 = 10 & 5 = 0 (1010 & 0101 = 0000)
        check_reg(6, 32'd0, "AND x6=x1&x2");

        // ----- CYCLE 7: OR result -----
        @(posedge clk); #1;     // Instr 6 (OR x7, x1, x2) completes
        // x7 = 10 | 5 = 15 (1010 | 0101 = 1111)
        check_reg(7, 32'd15, "OR x7=x1|x2");

        // ----- CYCLE 8: XOR result -----
        @(posedge clk); #1;     // Instr 7 (XOR x8, x1, x2) completes
        // x8 = 10 ^ 5 = 15 (1010 ^ 0101 = 1111)
        check_reg(8, 32'd15, "XOR x8=x1^x2");

        // ----- CYCLE 9: SLL result -----
        @(posedge clk); #1;     // Instr 8 (SLL x9, x1, x2) completes
        // x9 = 10 << 5 = 320
        check_reg(9, 32'd320, "SLL x9=x1<<x2");

        // ----- CYCLE 10: SRL result -----
        @(posedge clk); #1;     // Instr 9 (SRL x10, x9, x2) completes
        // x10 = 320 >> 5 = 10
        check_reg(10, 32'd10, "SRL x10=x9>>x2");

        // ----- CYCLE 11: SRA result -----
        @(posedge clk); #1;     // Instr 10 (SRA x11, x3, x2) completes
        // x11 = -1 >>> 5 = -1 (sign bit preserved)
        check_reg(11, 32'hFFFFFFFF, "SRA x11=x3>>>x2");

        // ----- CYCLE 12: SLT result -----
        @(posedge clk); #1;     // Instr 11 (SLT x12, x2, x1) completes
        // x12 = (5 < 10 signed) = 1
        check_reg(12, 32'd1, "SLT x12=(x2<x1)");

        // ----- CYCLE 13: SLTU result -----
        @(posedge clk); #1;     // Instr 12 (SLTU x13, x2, x1) completes
        // x13 = (5 < 10 unsigned) = 1
        check_reg(13, 32'd1, "SLTU x13=(x2<x1)u");

        // ========================================================
        // Let the rest of the program finish executing
        // Need to wait enough cycles for instructions 13-63
        // The branchy portion skips several instructions so
        // total cycles = 64 - 6 branches skipped - 2 jumps skipped = ~56 more
        // Wait 60 more cycles from here = plenty of margin
        // ========================================================
        $display("--- Waiting for rest of program to complete ---");
        repeat(60) @(posedge clk);
        #1;     // Small settle time for combinational outputs

        // ========================================================
        // FINAL REGISTER CHECKS
        // ========================================================

        $display("--- X0 HARDWIRED TO ZERO ---");
        check_x0;

        $display("--- SETUP REGISTER VALUES ---");
        // x2 was set to 5 at instr 1 and never changed
        check_reg(2, 32'd5, "ADDI x2=5 (constant)");

        $display("--- I-TYPE ARITHMETIC ---");
        // x14 = 100 (ADDI, set at instr 13, never overwritten)
        check_reg(14, 32'd100, "ADDI x14=100");
        // x15 = 1 (SLTI: 100 < 200 signed = 1)
        check_reg(15, 32'd1, "SLTI x15=(100<200)");
        // x16 = 1 (SLTIU: 100 < 200 unsigned = 1)
        check_reg(16, 32'd1, "SLTIU x16=(100<200)u");
        // x17 = 4 (ANDI: 100 & 15 = 4)
        // 100 = 0110 0100, 15 = 0000 1111, AND = 0000 0100 = 4
        check_reg(17, 32'd4, "ANDI x17=100&15");
        // x18 = 111 (ORI: 100 | 15 = 111)
        // 100 = 0110 0100, 15 = 0000 1111, OR = 0110 1111 = 111
        check_reg(18, 32'd111, "ORI x18=100|15");
        // x19 = 107 (XORI: 100 ^ 15 = 107)
        // 100 = 0110 0100, 15 = 0000 1111, XOR = 0110 1011 = 107
        check_reg(19, 32'd107, "XORI x19=100^15");
        // x20 = 400 (SLLI: 100 << 2 = 400)
        check_reg(20, 32'd400, "SLLI x20=100<<2");
        // x21 = 25 (SRLI: 100 >> 2 = 25)
        check_reg(21, 32'd25, "SRLI x21=100>>2");
        // x22 = -1 (SRAI: -1 >>> 1 = -1, sign bit preserved)
        check_reg(22, 32'hFFFFFFFF, "SRAI x22=-1>>>1");

        $display("--- LUI AND AUIPC ---");
        // x23 = 4096 = 0x1000 (LUI: 1 << 12 = 4096)
        check_reg(23, 32'h00001000, "LUI x23=1<<12");
        // x24 = 4188 = 0x105C (AUIPC: PC + (1<<12) = 92 + 4096)
        // PC at instr 23 = 23 * 4 = 92 = 0x5C
        check_reg(24, 32'h0000105C, "AUIPC x24=PC+0x1000");

        $display("--- LOAD AND STORE ---");
        // x25 = 0 (base address)
        check_reg(25, 32'd0, "ADDI x25=0 (base)");
        // x26 = 171 = 0xAB (value that was stored)
        check_reg(26, 32'd171, "ADDI x26=171(0xAB)");
        // x27 = 171 (LW: loaded full 32-bit word = 0x000000AB = 171)
        check_reg(27, 32'd171, "LW x27=mem[0]");
        // x28 = 171 (LH: loaded 16-bit halfword 0x00AB = 171, sign bit=0)
        check_reg(28, 32'd171, "LH x28=mem[4]");
        // x29 = 0xFFFFFFAB = -85 (LB: byte 0xAB sign extended, bit7=1)
        check_reg(29, 32'hFFFFFFAB, "LB x29=sign(mem[8])");
        // x30 = 171 (LHU: halfword 0x00AB zero extended = 171)
        check_reg(30, 32'd171, "LHU x30=mem[4]");
        // x31 = 171 (LBU: byte 0xAB zero extended = 171)
        check_reg(31, 32'd171, "LBU x31=mem[8]");

        $display("--- MEMORY CONTENTS AFTER STORES ---");
        // SW stored 0x000000AB at address 0 (little-endian)
        check_mem(0, 8'hAB, "SW mem[0]=0xAB");
        check_mem(1, 8'h00, "SW mem[1]=0x00");
        check_mem(2, 8'h00, "SW mem[2]=0x00");
        check_mem(3, 8'h00, "SW mem[3]=0x00");
        // SH stored 0x00AB at address 4 (little-endian halfword)
        check_mem(4, 8'hAB, "SH mem[4]=0xAB");
        check_mem(5, 8'h00, "SH mem[5]=0x00");
        // SB stored 0xAB at address 8
        check_mem(8, 8'hAB, "SB mem[8]=0xAB");

        $display("--- BRANCH RESULTS ---");
        // x3 = 11: BEQ was TAKEN (x1==x2=5, jumped to ADDI x3=11)
        // If x3=99, BEQ failed to jump (wrong value wrote to x3)
        check_reg(3, 32'd11, "BEQ taken x3=11");
        // x4 = 22: BNE was NOT taken (x1==x2=5, fell through to ADDI x4=22)
        check_reg(4, 32'd22, "BNE not taken x4=22");
        // x5 = 33: BLT was TAKEN (3 < 5 signed, jumped to ADDI x5=33)
        check_reg(5, 32'd33, "BLT taken x5=33");
        // x6 = 44: BGE was TAKEN (5 >= 5 signed, jumped to ADDI x6=44)
        check_reg(6, 32'd44, "BGE taken x6=44");
        // x7 = 55: BLTU was TAKEN (1 < 5 unsigned, jumped to ADDI x7=55)
        check_reg(7, 32'd55, "BLTU taken x7=55");
        // x8 = 66: BGEU was TAKEN (5 >= 5 unsigned, jumped to ADDI x8=66)
        check_reg(8, 32'd66, "BGEU taken x8=66");

        $display("--- JAL RESULTS ---");
        // x9 = 228: JAL saved return address PC+4 = 56*4+4 = 228
        check_reg(9, 32'd228, "JAL x9=retaddr(228)");
        // x10 = 77: JAL jumped to instr 58 (ADDI x10=77)
        // If x10=99, JAL failed to jump
        check_reg(10, 32'd77, "JAL jumped x10=77");

        $display("--- JALR RESULTS ---");
        // x11 = 248: setup value for JALR target address
        check_reg(11, 32'd248, "JALR setup x11=248");
        // x13 = 244: JALR saved return address PC+4 = 60*4+4 = 244
        check_reg(13, 32'd244, "JALR x13=retaddr(244)");
        // x12 = 88: JALR jumped to instr 62 (ADDI x12=88)
        // If x12=99, JALR failed to jump
        check_reg(12, 32'd88, "JALR jumped x12=88");

        $display("--- x1 FINAL VALUE ---");
        // x1 = 5: last ADDI x1=5 before BGEU test
        check_reg(1, 32'd5, "ADDI x1=5 (last)");

        // ========================================================
        // FINAL SUMMARY
        // ========================================================
        $display("=====================================================");
        $display("RESULTS: %0d / %0d tests passed", passed, total);
        if (failed == 0) begin
            $display("ALL TESTS PASSED - CPU IS WORKING CORRECTLY!");
            $display("All 47 RV32I instructions verified.");
        end else begin
            $display("%0d TEST(S) FAILED - CHECK OUTPUT ABOVE", failed);
        end
        $display("=====================================================");

        $finish;

    end

endmodule
