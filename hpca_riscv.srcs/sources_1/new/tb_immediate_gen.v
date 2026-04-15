`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.04.2026 13:08:16
// Design Name: 
// Module Name: tb_immediate_gen
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
// Module : tb_immediate_gen (Testbench for Immediate Generator)
// Project : RISC-V Single-Cycle CPU
// Description : Tests all 5 RV32I immediate types:
//               I-type, S-type, B-type, U-type, J-type
//               Includes positive, negative, and edge cases.
//               Prints PASS/FAIL in console.
//               Waveform friendly for Vivado.
//
// How to use in Vivado:
//   1. Add immediate_gen.v and tb_immediate_gen.v to project
//   2. Set tb_immediate_gen as top module for simulation
//   3. Run Behavioral Simulation
//   4. Check Tcl Console for PASS/FAIL messages
//   5. Check waveform window for signal traces
// ============================================================

`timescale 1ns / 1ps   // Time unit = 1ns, precision = 1ps

module tb_immediate_gen;

    // --------------------------------------------------------
    // Declare testbench signals
    // --------------------------------------------------------

    reg  [31:0] instruction;    // Full 32-bit instruction input
    reg  [2:0]  imm_sel;        // Immediate type selector input
    wire [31:0] imm_out;        // Sign-extended immediate output

    // --------------------------------------------------------
    // Counters for test results
    // --------------------------------------------------------

    integer total;              // Total tests run
    integer passed;             // Tests passed
    integer failed;             // Tests failed

    // --------------------------------------------------------
    // Instantiate the immediate generator module
    // --------------------------------------------------------

    immediate_gen uut (
        .instruction (instruction), // Connect instruction input
        .imm_sel     (imm_sel),     // Connect selector input
        .imm_out     (imm_out)      // Connect immediate output
    );

    // --------------------------------------------------------
    // Task: check_imm
    // Compares imm_out with expected value
    // Prints PASS or FAIL with details
    // --------------------------------------------------------

    task check_imm;
        input [31:0] expected;      // Expected immediate value
        input [31:0] test_id;       // Test number
        input [8*20:1] test_name;   // Test name string
        begin
            total = total + 1;      // Increment total test count

            if (imm_out === expected) begin
                $display("PASS | Test %0d | %s | imm_out=%0d (0x%h)",
                    test_id, test_name, $signed(imm_out), imm_out);
                passed = passed + 1;
            end else begin
                $display("FAIL | Test %0d | %s | expected=%0d (0x%h) | got=%0d (0x%h)",
                    test_id, test_name,
                    $signed(expected), expected,
                    $signed(imm_out),  imm_out);
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

        // Initialize inputs to safe defaults
        instruction = 32'b0;
        imm_sel     = 3'b0;

        // Setup waveform dump for Vivado
        $dumpfile("tb_immediate_gen.vcd");  // Waveform output file
        $dumpvars(0, tb_immediate_gen);     // Dump all signals

        // Print header
        $display("============================================");
        $display("  IMMEDIATE GEN TESTBENCH - RISC-V CPU     ");
        $display("============================================");

        // ------------------------------------------------
        // I-TYPE TESTS (imm_sel = 000)
        // Bits: instruction[31:20] = imm[11:0]
        // Sign extended from bit 31
        // Used by: ADDI, LW, JALR, etc.
        // ------------------------------------------------
        $display("--- I-TYPE ---");

        imm_sel = 3'b000;   // Select I-type

        // Test 1: Positive immediate = 5
        // instruction[31:20] = 000000000101
        // All other bits = 0 (don't care for immediate extraction)
        instruction = {12'b000000000101, 20'b0};
        // instruction[31:20] = 5, sign bit = 0, so no sign extension
        #10;
        check_imm(32'd5, 1, "I-TYPE POS"); // Expected: 5

        // Test 2: Negative immediate = -1
        // instruction[31:20] = 111111111111 (all 1s = -1 in 12-bit signed)
        instruction = {12'b111111111111, 20'b0};
        // Sign bit = 1, so upper 20 bits all become 1
        #10;
        check_imm(32'hFFFFFFFF, 2, "I-TYPE NEG -1"); // Expected: -1

        // Test 3: Max positive I-type immediate = 2047
        // instruction[31:20] = 011111111111
        instruction = {12'b011111111111, 20'b0};
        // Sign bit = 0, no sign extension
        #10;
        check_imm(32'd2047, 3, "I-TYPE MAX POS"); // Expected: 2047

        // Test 4: Max negative I-type immediate = -2048
        // instruction[31:20] = 100000000000
        instruction = {12'b100000000000, 20'b0};
        // Sign bit = 1, upper 20 bits become 1
        #10;
        check_imm(32'hFFFFF800, 4, "I-TYPE MAX NEG"); // Expected: -2048

        // ------------------------------------------------
        // S-TYPE TESTS (imm_sel = 001)
        // Bits: instruction[31:25] = imm[11:5]
        //       instruction[11:7]  = imm[4:0]
        // Sign extended from bit 31
        // Used by: SW, SH, SB
        // ------------------------------------------------
        $display("--- S-TYPE ---");

        imm_sel = 3'b001;   // Select S-type

        // Test 5: Positive immediate = 4
        // imm = 4 = 000000000100
        // imm[11:5] = 0000000, imm[4:0] = 00100
        // instruction[31:25] = 0000000
        // instruction[11:7]  = 00100
        // All other bits = 0
        instruction = {7'b0000000,      // inst[31:25] = imm[11:5]
                       5'b00000,         // inst[24:20] = rs2 (don't care)
                       5'b00000,         // inst[19:15] = rs1 (don't care)
                       3'b000,           // inst[14:12] = funct3 (don't care)
                       5'b00100,         // inst[11:7]  = imm[4:0]
                       7'b0000000};      // inst[6:0]   = opcode (don't care)
        #10;
        check_imm(32'd4, 5, "S-TYPE POS 4"); // Expected: 4

        // Test 6: Negative immediate = -4
        // imm = -4 = 111111111100
        // imm[11:5] = 1111111, imm[4:0] = 11100
        instruction = {7'b1111111,       // inst[31:25] = imm[11:5]
                       5'b00000,         // rs2 (don't care)
                       5'b00000,         // rs1 (don't care)
                       3'b000,           // funct3 (don't care)
                       5'b11100,         // inst[11:7] = imm[4:0]
                       7'b0000000};      // opcode (don't care)
        #10;
        check_imm(32'hFFFFFFFC, 6, "S-TYPE NEG -4"); // Expected: -4

        // Test 7: Positive immediate = 31 (max lower bits set)
        // imm = 31 = 000000011111
        // imm[11:5] = 0000000, imm[4:0] = 11111
        instruction = {7'b0000000,       // inst[31:25] = imm[11:5]
                       5'b00000,
                       5'b00000,
                       3'b000,
                       5'b11111,         // inst[11:7] = imm[4:0]
                       7'b0000000};
        #10;
        check_imm(32'd31, 7, "S-TYPE POS 31"); // Expected: 31

        // ------------------------------------------------
        // B-TYPE TESTS (imm_sel = 010)
        // Bits are scattered:
        //   instruction[31]    = imm[12]
        //   instruction[7]     = imm[11]
        //   instruction[30:25] = imm[10:5]
        //   instruction[11:8]  = imm[4:1]
        //   imm[0] = always 0
        // Sign extended from bit 31
        // Used by: BEQ, BNE, BLT, BGE, BLTU, BGEU
        // ------------------------------------------------
        $display("--- B-TYPE ---");

        imm_sel = 3'b010;   // Select B-type

        // Test 8: Positive offset = 8
        // imm = 8 = 0_0000000_1000 (13-bit)
        // imm[12]=0, imm[11]=0, imm[10:5]=000000, imm[4:1]=0100, imm[0]=0
        instruction = {1'b0,            // inst[31]   = imm[12] = 0
                       6'b000000,        // inst[30:25] = imm[10:5] = 000000
                       5'b00000,         // inst[24:20] = rs2 (don't care)
                       5'b00000,         // inst[19:15] = rs1 (don't care)
                       3'b000,           // inst[14:12] = funct3 (don't care)
                       4'b0100,          // inst[11:8]  = imm[4:1] = 0100
                       1'b0,             // inst[7]     = imm[11] = 0
                       7'b0000000};      // inst[6:0]   = opcode (don't care)
        #10;
        check_imm(32'd8, 8, "B-TYPE POS 8"); // Expected: 8

        // Test 9: Negative offset = -8
        // imm = -8 (13-bit two's complement, bit 0 = 0)
        // imm[12]=1, imm[11]=1, imm[10:5]=111111, imm[4:1]=1100, imm[0]=0
        instruction = {1'b1,            // inst[31]    = imm[12] = 1
                       6'b111111,        // inst[30:25] = imm[10:5] = 111111
                       5'b00000,         // rs2 (don't care)
                       5'b00000,         // rs1 (don't care)
                       3'b000,           // funct3 (don't care)
                       4'b1100,          // inst[11:8]  = imm[4:1] = 1100
                       1'b1,             // inst[7]     = imm[11] = 1
                       7'b0000000};      // opcode (don't care)
        #10;
        check_imm(32'hFFFFFFF8, 9, "B-TYPE NEG -8"); // Expected: -8

        // Test 10: Check imm[0] is always 0 (even if bits suggest otherwise)
        // imm[12]=0, imm[11]=0, imm[10:5]=000000, imm[4:1]=0010 ? imm = 4
        instruction = {1'b0,
                       6'b000000,
                       5'b00000,
                       5'b00000,
                       3'b000,
                       4'b0010,          // imm[4:1] = 0010 ? imm = 4
                       1'b0,
                       7'b0000000};
        #10;
        check_imm(32'd4, 10, "B-TYPE ALIGN CHECK"); // Expected: 4 (not 5, bit 0 = 0)

        // ------------------------------------------------
        // U-TYPE TESTS (imm_sel = 011)
        // Bits: instruction[31:12] = imm[31:12]
        //       imm[11:0] = always 0
        // No sign extension needed (upper bits taken directly)
        // Used by: LUI, AUIPC
        // ------------------------------------------------
        $display("--- U-TYPE ---");

        imm_sel = 3'b011;   // Select U-type

        // Test 11: Upper immediate = 0x12345
        // instruction[31:12] = 20'h12345
        // Expected: 0x12345000 (lower 12 bits forced to 0)
        instruction = {20'h12345, 12'b0};   // Upper 20 bits set, lower 12 = 0
        #10;
        check_imm(32'h12345000, 11, "U-TYPE 0x12345"); // Expected: 0x12345000

        // Test 12: Upper immediate = all 1s
        // instruction[31:12] = 20'hFFFFF
        // Expected: 0xFFFFF000
        instruction = {20'hFFFFF, 12'b0};
        #10;
        check_imm(32'hFFFFF000, 12, "U-TYPE ALL ONES"); // Expected: 0xFFFFF000

        // Test 13: Lower 12 bits of instruction should be ignored
        // instruction[31:12] = 20'hABCDE, instruction[11:0] = 12'hFFF
        // Lower bits should NOT appear in output
        instruction = {20'hABCDE, 12'hFFF};    // Lower 12 bits set to all 1s
        #10;
        check_imm(32'hABCDE000, 13, "U-TYPE LOWER IGNORED"); // Expected: lower bits cleared

        // ------------------------------------------------
        // J-TYPE TESTS (imm_sel = 100)
        // Bits are scattered:
        //   instruction[31]    = imm[20]
        //   instruction[30:21] = imm[10:1]
        //   instruction[20]    = imm[11]
        //   instruction[19:12] = imm[19:12]
        //   imm[0] = always 0
        // Sign extended from bit 31
        // Used by: JAL
        // ------------------------------------------------
        $display("--- J-TYPE ---");

        imm_sel = 3'b100;   // Select J-type

        // Test 14: Positive jump offset = 8
        // imm = 8 (21-bit), imm[0] = 0
        // imm[20]=0, imm[19:12]=00000000, imm[11]=0, imm[10:1]=0000000100
        instruction = {1'b0,            // inst[31]    = imm[20] = 0
                       10'b0000000100,   // inst[30:21] = imm[10:1]
                       1'b0,             // inst[20]    = imm[11] = 0
                       8'b00000000,      // inst[19:12] = imm[19:12] = 0
                       5'b00000,         // inst[11:7]  = rd (don't care)
                       7'b0000000};      // inst[6:0]   = opcode (don't care)
        #10;
        check_imm(32'd8, 14, "J-TYPE POS 8"); // Expected: 8

        // Test 15: Negative jump offset = -8
        // imm = -8 (21-bit two's complement, bit 0 = 0)
        // imm[20]=1, imm[19:12]=11111111, imm[11]=1, imm[10:1]=1111111100
        instruction = {1'b1,            // inst[31]    = imm[20] = 1
                       10'b1111111100,   // inst[30:21] = imm[10:1]
                       1'b1,             // inst[20]    = imm[11] = 1
                       8'b11111111,      // inst[19:12] = imm[19:12]
                       5'b00000,         // rd (don't care)
                       7'b0000000};      // opcode (don't care)
        #10;
        check_imm(32'hFFFFFFF8, 15, "J-TYPE NEG -8"); // Expected: -8

        // Test 16: Check imm[0] is always 0 for J-type
        // imm[10:1] = 0000000010 ? imm = 4, not 5
        instruction = {1'b0,
                       10'b0000000010,   // imm[10:1] = 0000000010 ? imm = 4
                       1'b0,
                       8'b00000000,
                       5'b00000,
                       7'b0000000};
        #10;
        check_imm(32'd4, 16, "J-TYPE ALIGN CHECK"); // Expected: 4 (bit 0 = 0 always)

        // ------------------------------------------------
        // DEFAULT CASE TEST
        // Undefined imm_sel should output 0
        // ------------------------------------------------
        $display("--- DEFAULT CASE ---");

        imm_sel     = 3'b111;           // Undefined selector
        instruction = 32'hFFFFFFFF;     // All 1s instruction
        #10;
        check_imm(32'b0, 17, "DEFAULT ZERO"); // Expected: 0

        // ------------------------------------------------
        // Print final summary
        // ------------------------------------------------
        $display("============================================");
        $display("RESULTS: %0d / %0d tests passed", passed, total);
        if (failed == 0)
            $display("ALL TESTS PASSED!");
        else
            $display("%0d TEST(S) FAILED!", failed);
        $display("============================================");

        $finish;    // End simulation

    end

endmodule
