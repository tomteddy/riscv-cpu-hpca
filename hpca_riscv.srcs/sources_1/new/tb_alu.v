`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.04.2026 12:42:47
// Design Name: 
// Module Name: tb_alu
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
// Module : tb_alu (Testbench for ALU)
// Project : RISC-V Single-Cycle CPU
// Description : Tests all 10 ALU operations with multiple
//               test cases each. Prints PASS/FAIL for each
//               test in the console. Also waveform-friendly
//               for Vivado simulation.
//
// How to use in Vivado:
//   1. Add both alu.v and tb_alu.v to your project
//   2. Set tb_alu as the top module for simulation
//   3. Run Behavioral Simulation
//   4. Check console for PASS/FAIL messages
//   5. Check waveform window for signal traces
// ============================================================

`timescale 1ns / 1ps   // Time unit = 1ns, precision = 1ps

module tb_alu;

    // --------------------------------------------------------
    // Declare testbench signals
    // These connect to the ALU inputs and outputs
    // --------------------------------------------------------

    reg  [31:0] a;          // First operand input
    reg  [31:0] b;          // Second operand input
    reg  [3:0]  alu_ctrl;   // Operation selector input
    wire [31:0] result;     // Result output from ALU
    wire        zero;       // Zero flag output from ALU

    // --------------------------------------------------------
    // Integer to count total tests, passes, and failures
    // --------------------------------------------------------

    integer total;          // Total number of tests run
    integer passed;         // Number of tests that passed
    integer failed;         // Number of tests that failed

    // --------------------------------------------------------
    // Instantiate the ALU module
    // Connect testbench signals to ALU ports
    // --------------------------------------------------------

    alu uut (
        .a        (a),          // Connect a to ALU input a
        .b        (b),          // Connect b to ALU input b
        .alu_ctrl (alu_ctrl),   // Connect control signal
        .result   (result),     // Connect result output
        .zero     (zero)        // Connect zero flag output
    );

    // --------------------------------------------------------
    // Task: check_result
    // Reusable task to compare result with expected value
    // Prints PASS or FAIL with details
    // --------------------------------------------------------

    task check_result;
        input [31:0] expected;      // Expected result value
        input [63:0] test_id;       // Test number for display
        input [127:0] op_name;      // Operation name for display
        begin
            total = total + 1;      // Increment total test count

            if (result === expected) begin
                // === checks for exact match including X and Z states
                $display("PASS | Test %0d | %s | a=%0d b=%0d | result=%0d | zero=%0b",
                    test_id, op_name, $signed(a), $signed(b), $signed(result), zero);
                passed = passed + 1;    // Increment pass count
            end else begin
                $display("FAIL | Test %0d | %s | a=%0d b=%0d | expected=%0d | got=%0d",
                    test_id, op_name, $signed(a), $signed(b), $signed(expected), $signed(result));
                failed = failed + 1;    // Increment fail count
            end
        end
    endtask

    // --------------------------------------------------------
    // Main simulation block
    // --------------------------------------------------------

    initial begin

        // Initialize counters to zero
        total  = 0;
        passed = 0;
        failed = 0;

        // Print header in console
        $display("============================================");
        $display("        ALU TESTBENCH - RISC-V CPU         ");
        $display("============================================");

        // Add waveform dump for Vivado
        // This makes all signals visible in the waveform window
        $dumpfile("tb_alu.vcd");    // Output waveform file name
        $dumpvars(0, tb_alu);       // Dump all variables in this module

        // ------------------------------------------------
        // ADD tests (alu_ctrl = 0000)
        // ------------------------------------------------
        $display("--- ADD ---");

        alu_ctrl = 4'b0000;         // Set operation to ADD
        a = 32'd10;                 // a = 10
        b = 32'd20;                 // b = 20
        #10;                        // Wait 10ns for result to settle
        check_result(32'd30, 1, "ADD"); // Expected: 10 + 20 = 30

        a = 32'd0;                  // a = 0
        b = 32'd0;                  // b = 0
        #10;                        // Wait 10ns
        check_result(32'd0, 2, "ADD"); // Expected: 0 + 0 = 0 (zero flag test)

        a = 32'hFFFFFFFF;           // a = max unsigned (all 1s)
        b = 32'd1;                  // b = 1
        #10;                        // Wait 10ns
        check_result(32'd0, 3, "ADD"); // Expected: overflow wraps to 0

        // ------------------------------------------------
        // SUB tests (alu_ctrl = 0001)
        // ------------------------------------------------
        $display("--- SUB ---");

        alu_ctrl = 4'b0001;         // Set operation to SUB
        a = 32'd30;                 // a = 30
        b = 32'd10;                 // b = 10
        #10;                        // Wait 10ns
        check_result(32'd20, 4, "SUB"); // Expected: 30 - 10 = 20

        a = 32'd10;                 // a = 10
        b = 32'd10;                 // b = 10
        #10;                        // Wait 10ns
        check_result(32'd0, 5, "SUB"); // Expected: 10 - 10 = 0 (zero flag test)

        a = 32'd5;                  // a = 5
        b = 32'd10;                 // b = 10
        #10;                        // Wait 10ns
        check_result(32'hFFFFFFFB, 6, "SUB"); // Expected: 5 - 10 = -5 (twos complement)

        // ------------------------------------------------
        // AND tests (alu_ctrl = 0010)
        // ------------------------------------------------
        $display("--- AND ---");

        alu_ctrl = 4'b0010;         // Set operation to AND
        a = 32'hFF00FF00;           // a = 1111 1111 0000 0000 ...
        b = 32'h0F0F0F0F;           // b = 0000 1111 0000 1111 ...
        #10;                        // Wait 10ns
        check_result(32'h0F000F00, 7, "AND"); // Expected: AND of above

        a = 32'hFFFFFFFF;           // a = all 1s
        b = 32'h00000000;           // b = all 0s
        #10;                        // Wait 10ns
        check_result(32'h00000000, 8, "AND"); // Expected: all 0s

        // ------------------------------------------------
        // OR tests (alu_ctrl = 0011)
        // ------------------------------------------------
        $display("--- OR ---");

        alu_ctrl = 4'b0011;         // Set operation to OR
        a = 32'hFF00FF00;           // a = 1111 1111 0000 0000 ...
        b = 32'h00FF00FF;           // b = 0000 0000 1111 1111 ...
        #10;                        // Wait 10ns
        check_result(32'hFFFFFFFF, 9, "OR "); // Expected: all 1s

        a = 32'h00000000;           // a = all 0s
        b = 32'h00000000;           // b = all 0s
        #10;                        // Wait 10ns
        check_result(32'h00000000, 10, "OR "); // Expected: all 0s

        // ------------------------------------------------
        // XOR tests (alu_ctrl = 0100)
        // ------------------------------------------------
        $display("--- XOR ---");

        alu_ctrl = 4'b0100;         // Set operation to XOR
        a = 32'hFFFFFFFF;           // a = all 1s
        b = 32'hFFFFFFFF;           // b = all 1s
        #10;                        // Wait 10ns
        check_result(32'h00000000, 11, "XOR"); // Expected: all 0s (same inputs)

        a = 32'hAAAAAAAA;           // a = 1010 1010 ...
        b = 32'h55555555;           // b = 0101 0101 ...
        #10;                        // Wait 10ns
        check_result(32'hFFFFFFFF, 12, "XOR"); // Expected: all 1s (opposite bits)

        // ------------------------------------------------
        // SLL tests (alu_ctrl = 0101)
        // Shift Left Logical
        // ------------------------------------------------
        $display("--- SLL ---");

        alu_ctrl = 4'b0101;         // Set operation to SLL
        a = 32'd1;                  // a = 0000...0001
        b = 32'd4;                  // b = shift by 4
        #10;                        // Wait 10ns
        check_result(32'd16, 13, "SLL"); // Expected: 1 << 4 = 16

        a = 32'd1;                  // a = 1
        b = 32'd31;                 // b = shift by 31 (max shift)
        #10;                        // Wait 10ns
        check_result(32'h80000000, 14, "SLL"); // Expected: 1 shifted to MSB

        // ------------------------------------------------
        // SRL tests (alu_ctrl = 0110)
        // Shift Right Logical
        // ------------------------------------------------
        $display("--- SRL ---");

        alu_ctrl = 4'b0110;         // Set operation to SRL
        a = 32'd16;                 // a = 16
        b = 32'd4;                  // b = shift by 4
        #10;                        // Wait 10ns
        check_result(32'd1, 15, "SRL"); // Expected: 16 >> 4 = 1

        a = 32'h80000000;           // a = MSB set (negative if signed)
        b = 32'd1;                  // b = shift by 1
        #10;                        // Wait 10ns
        check_result(32'h40000000, 16, "SRL"); // Expected: MSB fills with 0 (logical)

        // ------------------------------------------------
        // SRA tests (alu_ctrl = 0111)
        // Shift Right Arithmetic
        // ------------------------------------------------
        $display("--- SRA ---");

        alu_ctrl = 4'b0111;         // Set operation to SRA
        a = 32'h80000000;           // a = most negative 32-bit number
        b = 32'd1;                  // b = shift by 1
        #10;                        // Wait 10ns
        check_result(32'hC0000000, 17, "SRA"); // Expected: sign bit preserved (fills with 1)

        a = 32'd16;                 // a = 16 (positive)
        b = 32'd2;                  // b = shift by 2
        #10;                        // Wait 10ns
        check_result(32'd4, 18, "SRA"); // Expected: 16 >>> 2 = 4 (positive, same as SRL)

        // ------------------------------------------------
        // SLT tests (alu_ctrl = 1000)
        // Set Less Than (signed)
        // ------------------------------------------------
        $display("--- SLT ---");

        alu_ctrl = 4'b1000;         // Set operation to SLT
        a = 32'd5;                  // a = 5
        b = 32'd10;                 // b = 10
        #10;                        // Wait 10ns
        check_result(32'd1, 19, "SLT"); // Expected: 5 < 10 = 1

        a = 32'd10;                 // a = 10
        b = 32'd5;                  // b = 5
        #10;                        // Wait 10ns
        check_result(32'd0, 20, "SLT"); // Expected: 10 < 5 = 0

        a = 32'hFFFFFFFF;           // a = -1 in signed
        b = 32'd1;                  // b = 1
        #10;                        // Wait 10ns
        check_result(32'd1, 21, "SLT"); // Expected: -1 < 1 = 1 (signed)

        // ------------------------------------------------
        // SLTU tests (alu_ctrl = 1001)
        // Set Less Than Unsigned
        // ------------------------------------------------
        $display("--- SLTU ---");

        alu_ctrl = 4'b1001;         // Set operation to SLTU
        a = 32'd5;                  // a = 5
        b = 32'd10;                 // b = 10
        #10;                        // Wait 10ns
        check_result(32'd1, 22, "SLTU"); // Expected: 5 < 10 = 1

        a = 32'hFFFFFFFF;           // a = max unsigned value
        b = 32'd1;                  // b = 1
        #10;                        // Wait 10ns
        check_result(32'd0, 23, "SLTU"); // Expected: max > 1 = 0 (unsigned)

        a = 32'd1;                  // a = 1
        b = 32'hFFFFFFFF;           // b = max unsigned value
        #10;                        // Wait 10ns
        check_result(32'd1, 24, "SLTU"); // Expected: 1 < max = 1 (unsigned)

        // ------------------------------------------------
        // Zero flag tests
        // ------------------------------------------------
        $display("--- ZERO FLAG ---");

        alu_ctrl = 4'b0001;         // Set operation to SUB
        a = 32'd42;                 // a = 42
        b = 32'd42;                 // b = 42
        #10;                        // Wait 10ns
        // Check zero flag specifically
        total = total + 1;
        if (zero === 1'b1) begin
            $display("PASS | Test 25 | ZERO FLAG | a=42 b=42 | zero=%0b (SUB result is 0)", zero);
            passed = passed + 1;
        end else begin
            $display("FAIL | Test 25 | ZERO FLAG | a=42 b=42 | expected zero=1 | got zero=%0b", zero);
            failed = failed + 1;
        end

        alu_ctrl = 4'b0000;         // Set operation to ADD
        a = 32'd1;                  // a = 1
        b = 32'd1;                  // b = 1
        #10;                        // Wait 10ns
        total = total + 1;
        if (zero === 1'b0) begin
            $display("PASS | Test 26 | ZERO FLAG | a=1 b=1 | zero=%0b (ADD result is 2, not zero)", zero);
            passed = passed + 1;
        end else begin
            $display("FAIL | Test 26 | ZERO FLAG | a=1 b=1 | expected zero=0 | got zero=%0b", zero);
            failed = failed + 1;
        end

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