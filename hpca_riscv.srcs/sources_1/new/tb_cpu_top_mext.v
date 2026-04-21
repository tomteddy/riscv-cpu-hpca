// ============================================================
// Module : tb_cpu_top_mext
// Project : RV32I Pipelined CPU — Phase 3 testbench
// Description : Self-contained test for MUL / MAC / RELU.
//               Loads a small hand-assembled program directly
//               into uut.imem.mem (word-addressed) — no hex file.
//
// Program (byte address on the left):
//   0x00  ADDI x1,  x0, 5         ; x1 = 5
//   0x04  ADDI x2,  x0, 6         ; x2 = 6
//   0x08  MUL  x3,  x1, x2        ; x3 = 30
//   0x0C  MAC  x4,  x1, x2        ; x4 = 5 + 5*6 = 35   (rd=4, rs1=1, rs2=2)
//   0x10  ADDI x5,  x0, -7        ; x5 = -7
//   0x14  RELU x6,  x5            ; x6 = 0
//   0x18  RELU x7,  x1            ; x7 = 5
//   0x1C  MUL  x8,  x1, x1        ; x8 = 25
//   0x20  ADD  x9,  x3, x4        ; x9 = 30+35 = 65  (forward from MUL/MAC)
//   0x24  ADDI x10, x0, -100      ; x10 = -100
//   0x28  MUL  x11, x10, x2       ; x11 = -600 (signed)
//   0x2C  ADDI x12, x0, -8        ; x12 = -8
//   0x30  MAC  x13, x12, x2       ; x13 = -8 + -48 = -56
//   (rest filled with NOPs = ADDI x0, x0, 0)
// ============================================================

`timescale 1ns / 1ps

module tb_cpu_top_mext;

    reg clk;
    reg reset;

    integer total, passed, failed;
    integer i;

    cpu_top_mext uut (
        .clk(clk), .reset(reset)
    );

    initial clk = 0;
    always #5 clk = ~clk;

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

    // imem is byte-addressed, little-endian. Store a 32-bit word as 4 bytes.
    task write_word;
        input integer byte_addr;
        input [31:0]  word;
        begin
            uut.imem.mem[byte_addr + 0] = word[7:0];
            uut.imem.mem[byte_addr + 1] = word[15:8];
            uut.imem.mem[byte_addr + 2] = word[23:16];
            uut.imem.mem[byte_addr + 3] = word[31:24];
        end
    endtask

    initial begin
        total = 0; passed = 0; failed = 0;

        // #1 ensures these writes run AFTER imem's internal $readmemh.
        #1;

        // ---- Load hand-assembled program (byte addresses) ----
        write_word( 0, 32'h00500093); // ADDI x1, x0, 5
        write_word( 4, 32'h00600113); // ADDI x2, x0, 6
        write_word( 8, 32'h022081B3); // MUL  x3, x1, x2
        write_word(12, 32'h0020820B); // MAC  x4, x1, x2
        write_word(16, 32'hFF900293); // ADDI x5, x0, -7
        write_word(20, 32'h0002930B); // RELU x6, x5
        write_word(24, 32'h0000938B); // RELU x7, x1
        write_word(28, 32'h02108433); // MUL  x8, x1, x1
        write_word(32, 32'h004184B3); // ADD  x9, x3, x4
        write_word(36, 32'hF9C00513); // ADDI x10, x0, -100
        write_word(40, 32'h022505B3); // MUL  x11, x10, x2
        write_word(44, 32'hFF800613); // ADDI x12, x0, -8
        write_word(48, 32'h0026068B); // MAC  x13, x12, x2
        // NOP-fill the rest of the program region (bytes 52..4095)
        for (i = 52; i < 4096; i = i + 4)
            write_word(i, 32'h00000013);

        $dumpfile("tb_cpu_top_mext.vcd");
        $dumpvars(0, tb_cpu_top_mext);

        $display("=====================================================");
        $display("  CPU TOP TESTBENCH - PHASE 3: M EXTENSION + ML     ");
        $display("=====================================================");
        $display("Testing MUL, MAC, RELU (single-cycle, in EX)");
        $display("=====================================================");

        reset = 1'b1;
        repeat(5) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;

        // 13 instructions + pipeline drain + BTB/forwarding margin
        repeat(40) @(posedge clk);
        #1;

        $display("--- SCALAR SETUP ---");
        check_reg(1,  32'd5,        "ADDI x1=5");
        check_reg(2,  32'd6,        "ADDI x2=6");

        $display("--- MUL / MAC / RELU ---");
        check_reg(3,  32'd30,       "MUL  x3=5*6=30");
        check_reg(4,  32'd35,       "MAC  x4=5+5*6=35");
        check_reg(5,  32'hFFFFFFF9, "ADDI x5=-7");
        check_reg(6,  32'd0,        "RELU x6=max(-7,0)=0");
        check_reg(7,  32'd5,        "RELU x7=max(5,0)=5");

        $display("--- FORWARDING THROUGH MUL ---");
        check_reg(8,  32'd25,       "MUL  x8=5*5=25");
        check_reg(9,  32'd65,       "ADD  x9=30+35=65");

        $display("--- SIGNED MUL / MAC ---");
        check_reg(10, 32'hFFFFFF9C, "ADDI x10=-100");
        check_reg(11, 32'hFFFFFDA8, "MUL  x11=-100*6=-600");
        check_reg(12, 32'hFFFFFFF8, "ADDI x12=-8");
        check_reg(13, 32'hFFFFFFC8, "MAC  x13=-8+-48=-56");

        $display("=====================================================");
        $display("RESULTS: %0d / %0d tests passed", passed, total);
        if (failed == 0) begin
            $display("ALL TESTS PASSED - MUL / MAC / RELU WORKING!");
        end else begin
            $display("%0d TEST(S) FAILED", failed);
        end
        $display("=====================================================");

        $finish;
    end

endmodule
