`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.04.2026 13:24:24
// Design Name: 
// Module Name: tb_instruction_memory
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
// Module : tb_instruction_memory (Testbench for Instruction Memory)
// Project : RISC-V Single-Cycle CPU
// Description : Tests all key behaviors of instruction memory:
//               - Correct instruction fetch at valid addresses
//               - Byte to word address conversion (PC / 4)
//               - Sequential instruction fetch (PC+4 each time)
//               - Out of bounds address outputs undefined (X)
//
// How to use in Vivado:
//   1. Add instruction_memory.v and tb_instruction_memory.v
//   2. Create a file called "instructions.hex" in your
//      Vivado project directory with the following content:
//
//      DEADBEEF
//      12345678
//      AABBCCDD
//      00000013
//      FEEDC0DE
//
//   3. Set tb_instruction_memory as top module for simulation
//   4. Run Behavioral Simulation
//   5. Check Tcl Console for PASS/FAIL messages
//   6. Check waveform window for signal traces
// ============================================================

`timescale 1ns / 1ps   // Time unit = 1ns, precision = 1ps

module tb_instruction_memory;

    // --------------------------------------------------------
    // Declare testbench signals
    // --------------------------------------------------------

    reg  [31:0] pc;         // Program counter (byte address input)
    wire [31:0] instr;      // Instruction output from memory

    // --------------------------------------------------------
    // Counters for test results
    // --------------------------------------------------------

    integer total;          // Total tests run
    integer passed;         // Tests passed
    integer failed;         // Tests failed

    // --------------------------------------------------------
    // Instantiate the instruction memory module
    // --------------------------------------------------------

    instruction_memory uut (
        .pc    (pc),        // Connect PC input
        .instr (instr)      // Connect instruction output
    );

    // --------------------------------------------------------
    // Task: check_instr
    // Compares instruction output with expected value
    // Prints PASS or FAIL with details
    // --------------------------------------------------------

    task check_instr;
        input [31:0] expected;      // Expected instruction value
        input [31:0] test_id;       // Test number
        input [8*30:1] test_name;   // Test name string
        begin
            total = total + 1;      // Increment total test count

            if (instr === expected) begin
                $display("PASS | Test %0d | %s | PC=0x%h | instr=0x%h",
                    test_id, test_name, pc, instr);
                passed = passed + 1;
            end else begin
                $display("FAIL | Test %0d | %s | PC=0x%h | expected=0x%h | got=0x%h",
                    test_id, test_name, pc, expected, instr);
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

        // Initialize PC to 0
        pc = 32'b0;

        // Setup waveform dump for Vivado
        $dumpfile("tb_instruction_memory.vcd");     // Waveform output file
        $dumpvars(0, tb_instruction_memory);        // Dump all signals

        // Print header
        $display("============================================");
        $display(" INSTRUCTION MEMORY TESTBENCH - RISC-V CPU ");
        $display("============================================");
        $display("NOTE: Make sure instructions.hex is present");
        $display("      with these 5 lines in order:");
        $display("      DEADBEEF");
        $display("      12345678");
        $display("      AABBCCDD");
        $display("      00000013");
        $display("      FEEDC0DE");
        $display("============================================");

        // Small delay to allow $readmemh to load
        #10;

        // ------------------------------------------------
        // TEST GROUP 1: Basic instruction fetch
        // Each word is 4 bytes apart in byte addressing
        // PC = 0  ? mem[0] = DEADBEEF
        // PC = 4  ? mem[1] = 12345678
        // PC = 8  ? mem[2] = AABBCCDD
        // PC = 12 ? mem[3] = 00000013
        // PC = 16 ? mem[4] = FEEDC0DE
        // ------------------------------------------------
        $display("--- BASIC INSTRUCTION FETCH ---");

        pc = 32'h00000000;          // PC = 0, word index = 0
        #10;                        // Wait for output to settle
        check_instr(32'hDEADBEEF, 1, "FETCH PC=0"); // Expected: mem[0]

        pc = 32'h00000004;          // PC = 4, word index = 1
        #10;
        check_instr(32'h12345678, 2, "FETCH PC=4"); // Expected: mem[1]

        pc = 32'h00000008;          // PC = 8, word index = 2
        #10;
        check_instr(32'hAABBCCDD, 3, "FETCH PC=8"); // Expected: mem[2]

        pc = 32'h0000000C;          // PC = 12, word index = 3
        #10;
        check_instr(32'h00000013, 4, "FETCH PC=12"); // Expected: mem[3]

        pc = 32'h00000010;          // PC = 16, word index = 4
        #10;
        check_instr(32'hFEEDC0DE, 5, "FETCH PC=16"); // Expected: mem[4]

        // ------------------------------------------------
        // TEST GROUP 2: Sequential fetch simulation
        // Simulates CPU stepping through instructions
        // one by one, PC incrementing by 4 each cycle
        // ------------------------------------------------
        $display("--- SEQUENTIAL FETCH SIMULATION ---");

        pc = 32'h00000000;          // Start at PC = 0
        #10;
        check_instr(32'hDEADBEEF, 6, "SEQ STEP 1"); // Step 1

        pc = pc + 4;                // PC = 4 (next instruction)
        #10;
        check_instr(32'h12345678, 7, "SEQ STEP 2"); // Step 2

        pc = pc + 4;                // PC = 8
        #10;
        check_instr(32'hAABBCCDD, 8, "SEQ STEP 3"); // Step 3

        pc = pc + 4;                // PC = 12
        #10;
        check_instr(32'h00000013, 9, "SEQ STEP 4"); // Step 4

        pc = pc + 4;                // PC = 16
        #10;
        check_instr(32'hFEEDC0DE, 10, "SEQ STEP 5"); // Step 5

        // ------------------------------------------------
        // TEST GROUP 3: Byte to word address conversion
        // Verifies that PC/4 conversion is correct
        // PC = 0,4,8,12 should map to words 0,1,2,3
        // Also checks that lower 2 bits of PC are ignored
        // ------------------------------------------------
        $display("--- BYTE TO WORD CONVERSION ---");

        // PC = 0 and PC = 1 and PC = 2 and PC = 3
        // All should map to word 0 (lower 2 bits ignored)
        pc = 32'h00000000;          // PC = 0 ? word 0
        #10;
        check_instr(32'hDEADBEEF, 11, "WORD ALIGN PC=0"); // Expected: mem[0]

        pc = 32'h00000001;          // PC = 1 ? word 0 (lower bits ignored)
        #10;
        check_instr(32'hDEADBEEF, 12, "WORD ALIGN PC=1"); // Expected: still mem[0]

        pc = 32'h00000002;          // PC = 2 ? word 0 (lower bits ignored)
        #10;
        check_instr(32'hDEADBEEF, 13, "WORD ALIGN PC=2"); // Expected: still mem[0]

        pc = 32'h00000003;          // PC = 3 ? word 0 (lower bits ignored)
        #10;
        check_instr(32'hDEADBEEF, 14, "WORD ALIGN PC=3"); // Expected: still mem[0]

        pc = 32'h00000005;          // PC = 5 ? word 1 (lower bits ignored)
        #10;
        check_instr(32'h12345678, 15, "WORD ALIGN PC=5"); // Expected: mem[1]

        // ------------------------------------------------
        // TEST GROUP 4: Out of bounds address
        // PC beyond 4096 words (16384 bytes) should
        // output undefined (X) value
        // Note: === checks including X states
        // ------------------------------------------------
        $display("--- OUT OF BOUNDS ADDRESS ---");

        pc = 32'hFFFFFFFF;          // PC = max value, way out of bounds
        #10;
        // Check that output is undefined (X)
        total = total + 1;
        if (^instr === 1'bx) begin
            // ^ is reduction XOR, if any bit is X the result is X
            $display("PASS | Test 16 | OUT OF BOUNDS | PC=0xFFFFFFFF | instr is undefined (X) as expected");
            passed = passed + 1;
        end else begin
            $display("FAIL | Test 16 | OUT OF BOUNDS | PC=0xFFFFFFFF | expected undefined X | got=0x%h", instr);
            failed = failed + 1;
        end

        pc = 32'h00010000;          // PC = 65536 = word 16384 (out of 4096 range)
        #10;
        total = total + 1;
        if (^instr === 1'bx) begin
            $display("PASS | Test 17 | OUT OF BOUNDS | PC=0x00010000 | instr is undefined (X) as expected");
            passed = passed + 1;
        end else begin
            $display("FAIL | Test 17 | OUT OF BOUNDS | PC=0x00010000 | expected undefined X | got=0x%h", instr);
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
