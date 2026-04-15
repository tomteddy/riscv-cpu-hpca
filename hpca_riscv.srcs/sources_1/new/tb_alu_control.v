`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.04.2026 18:02:49
// Design Name: 
// Module Name: tb_alu_control
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
// Module : tb_alu_control (Testbench for ALU Control)
// Project : RISC-V Single-Cycle CPU
// Description : Tests all combinations of alu_op, funct3,
//               and funct7[5] for all RV32I instructions.
//               Verifies the correct 4-bit alu_ctrl output
//               for every instruction the ALU control handles.
//               Prints PASS/FAIL in console.
//               Waveform friendly for Vivado.
//
// How to use in Vivado:
//   1. Add alu_control.v and tb_alu_control.v to project
//   2. Set tb_alu_control as top module for simulation
//   3. Run Behavioral Simulation
//   4. Check Tcl Console for PASS/FAIL messages
//   5. Check waveform window for signal traces
// ============================================================

`timescale 1ns / 1ps

module tb_alu_control;

    // --------------------------------------------------------
    // Declare testbench signals
    // --------------------------------------------------------

    reg  [1:0] alu_op;      // Operation category input
    reg  [2:0] funct3;      // funct3 field input
    reg  [6:0] funct7;      // funct7 field input
    wire [3:0] alu_ctrl;    // 4-bit ALU control output

    // --------------------------------------------------------
    // Counters for test results
    // --------------------------------------------------------

    integer total;          // Total tests run
    integer passed;         // Tests passed
    integer failed;         // Tests failed

    // --------------------------------------------------------
    // Instantiate the ALU control module
    // --------------------------------------------------------

    alu_control uut (
        .alu_op   (alu_op),     // Connect alu_op input
        .funct3   (funct3),     // Connect funct3 input
        .funct7   (funct7),     // Connect funct7 input
        .alu_ctrl (alu_ctrl)    // Connect alu_ctrl output
    );

    // --------------------------------------------------------
    // Task: check_ctrl
    // Compares alu_ctrl output with expected value
    // Prints PASS or FAIL with full details
    // --------------------------------------------------------

    task check_ctrl;
        input [3:0]    expected;    // Expected alu_ctrl value
        input [31:0]   test_id;     // Test number
        input [8*20:1] test_name;   // Instruction name

        begin
            total = total + 1;      // Increment total count

            if (alu_ctrl === expected) begin
                $display("PASS | Test %0d | %-6s | alu_op=%b funct3=%b funct7[5]=%b | alu_ctrl=%b",
                    test_id, test_name,
                    alu_op, funct3, funct7[5],
                    alu_ctrl);
                passed = passed + 1;
            end else begin
                $display("FAIL | Test %0d | %-6s | alu_op=%b funct3=%b funct7[5]=%b | expected=%b got=%b",
                    test_id, test_name,
                    alu_op, funct3, funct7[5],
                    expected, alu_ctrl);
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
        alu_op = 2'b00;
        funct3 = 3'b000;
        funct7 = 7'b0000000;

        // Setup waveform dump for Vivado
        $dumpfile("tb_alu_control.vcd");    // Waveform output file
        $dumpvars(0, tb_alu_control);       // Dump all signals

        // Print header
        $display("=====================================================");
        $display("     ALU CONTROL TESTBENCH - RISC-V CPU             ");
        $display("=====================================================");
        $display("alu_ctrl encoding:");
        $display("  0000=ADD 0001=SUB 0010=AND 0011=OR  0100=XOR");
        $display("  0101=SLL 0110=SRL 0111=SRA 1000=SLT 1001=SLTU");
        $display("=====================================================");

        // ------------------------------------------------
        // TEST GROUP 1: alu_op = 00 (Force ADD)
        // Used by loads, stores, LUI, AUIPC, JAL, JALR
        // funct3 and funct7 are irrelevant - always ADD
        // ------------------------------------------------
        $display("--- ALU_OP=00 FORCE ADD ---");

        alu_op = 2'b00;             // Force ADD mode

        // Test with funct3=000, funct7=0000000
        funct3 = 3'b000;
        funct7 = 7'b0000000;
        #10;
        check_ctrl(4'b0000, 1, "FORCE ADD"); // Expected: ADD

        // Test with funct3=010, funct7=0100000
        // Even though these would mean SUB in R-type,
        // force ADD mode ignores them completely
        funct3 = 3'b010;
        funct7 = 7'b0100000;
        #10;
        check_ctrl(4'b0000, 2, "FORCE ADD"); // Expected: still ADD

        // Test with all funct3 and funct7 bits set
        funct3 = 3'b111;
        funct7 = 7'b1111111;
        #10;
        check_ctrl(4'b0000, 3, "FORCE ADD"); // Expected: still ADD

        // ------------------------------------------------
        // TEST GROUP 2: alu_op = 01 (Branch)
        // BEQ, BNE use SUB to check equality via zero flag
        // BLT, BGE use SLT for signed comparison
        // BLTU, BGEU use SLTU for unsigned comparison
        // ------------------------------------------------
        $display("--- ALU_OP=01 BRANCH ---");

        alu_op = 2'b01;             // Branch mode
        funct7 = 7'b0000000;        // funct7 irrelevant for branches

        // BEQ: funct3 = 000 ? SUB (check zero flag after)
        funct3 = 3'b000;
        #10;
        check_ctrl(4'b0001, 4, "BEQ"); // Expected: SUB

        // BNE: funct3 = 001 ? SUB (check not zero flag after)
        funct3 = 3'b001;
        #10;
        check_ctrl(4'b0001, 5, "BNE"); // Expected: SUB

        // BLT: funct3 = 100 ? SLT (signed less than)
        funct3 = 3'b100;
        #10;
        check_ctrl(4'b1000, 6, "BLT"); // Expected: SLT

        // BGE: funct3 = 101 ? SLT (branch if SLT result = 0)
        funct3 = 3'b101;
        #10;
        check_ctrl(4'b1000, 7, "BGE"); // Expected: SLT

        // BLTU: funct3 = 110 ? SLTU (unsigned less than)
        funct3 = 3'b110;
        #10;
        check_ctrl(4'b1001, 8, "BLTU"); // Expected: SLTU

        // BGEU: funct3 = 111 ? SLTU (branch if SLTU result = 0)
        funct3 = 3'b111;
        #10;
        check_ctrl(4'b1001, 9, "BGEU"); // Expected: SLTU

        // ------------------------------------------------
        // TEST GROUP 3: alu_op = 10 (R-type)
        // All 10 R-type instructions
        // funct3 selects base operation
        // funct7[5] distinguishes ADD/SUB and SRL/SRA
        // ------------------------------------------------
        $display("--- ALU_OP=10 R-TYPE ---");

        alu_op = 2'b10;             // R-type mode

        // ADD: funct3=000, funct7[5]=0
        funct3 = 3'b000;
        funct7 = 7'b0000000;        // funct7[5] = 0
        #10;
        check_ctrl(4'b0000, 10, "ADD"); // Expected: ADD

        // SUB: funct3=000, funct7[5]=1
        funct3 = 3'b000;
        funct7 = 7'b0100000;        // funct7[5] = 1
        #10;
        check_ctrl(4'b0001, 11, "SUB"); // Expected: SUB

        // SLL: funct3=001, funct7[5]=0
        funct3 = 3'b001;
        funct7 = 7'b0000000;        // funct7[5] = 0
        #10;
        check_ctrl(4'b0101, 12, "SLL"); // Expected: SLL

        // SLT: funct3=010, funct7[5]=0
        funct3 = 3'b010;
        funct7 = 7'b0000000;
        #10;
        check_ctrl(4'b1000, 13, "SLT"); // Expected: SLT

        // SLTU: funct3=011, funct7[5]=0
        funct3 = 3'b011;
        funct7 = 7'b0000000;
        #10;
        check_ctrl(4'b1001, 14, "SLTU"); // Expected: SLTU

        // XOR: funct3=100, funct7[5]=0
        funct3 = 3'b100;
        funct7 = 7'b0000000;
        #10;
        check_ctrl(4'b0100, 15, "XOR"); // Expected: XOR

        // SRL: funct3=101, funct7[5]=0
        funct3 = 3'b101;
        funct7 = 7'b0000000;        // funct7[5] = 0
        #10;
        check_ctrl(4'b0110, 16, "SRL"); // Expected: SRL

        // SRA: funct3=101, funct7[5]=1
        funct3 = 3'b101;
        funct7 = 7'b0100000;        // funct7[5] = 1
        #10;
        check_ctrl(4'b0111, 17, "SRA"); // Expected: SRA

        // OR: funct3=110, funct7[5]=0
        funct3 = 3'b110;
        funct7 = 7'b0000000;
        #10;
        check_ctrl(4'b0011, 18, "OR"); // Expected: OR

        // AND: funct3=111, funct7[5]=0
        funct3 = 3'b111;
        funct7 = 7'b0000000;
        #10;
        check_ctrl(4'b0010, 19, "AND"); // Expected: AND

        // ------------------------------------------------
        // TEST GROUP 4: alu_op = 11 (I-type arithmetic)
        // All 9 I-type arithmetic instructions
        // Same as R-type but no SUB variant for funct3=000
        // Only funct3=101 (SRLI/SRAI) checks funct7[5]
        // ------------------------------------------------
        $display("--- ALU_OP=11 I-TYPE ARITHMETIC ---");

        alu_op = 2'b11;             // I-type arithmetic mode

        // ADDI: funct3=000 ? always ADD (no SUBI in RISC-V)
        funct3 = 3'b000;
        funct7 = 7'b0000000;        // funct7[5] = 0 (irrelevant for ADDI)
        #10;
        check_ctrl(4'b0000, 20, "ADDI"); // Expected: ADD

        // ADDI with funct7[5]=1: still ADD (unlike R-type SUB)
        funct3 = 3'b000;
        funct7 = 7'b0100000;        // funct7[5] = 1 (should still be ADD)
        #10;
        check_ctrl(4'b0000, 21, "ADDI NO SUB"); // Expected: ADD (not SUB)

        // SLLI: funct3=001, funct7[5]=0
        funct3 = 3'b001;
        funct7 = 7'b0000000;
        #10;
        check_ctrl(4'b0101, 22, "SLLI"); // Expected: SLL

        // SLTI: funct3=010
        funct3 = 3'b010;
        funct7 = 7'b0000000;
        #10;
        check_ctrl(4'b1000, 23, "SLTI"); // Expected: SLT

        // SLTIU: funct3=011
        funct3 = 3'b011;
        funct7 = 7'b0000000;
        #10;
        check_ctrl(4'b1001, 24, "SLTIU"); // Expected: SLTU

        // XORI: funct3=100
        funct3 = 3'b100;
        funct7 = 7'b0000000;
        #10;
        check_ctrl(4'b0100, 25, "XORI"); // Expected: XOR

        // SRLI: funct3=101, funct7[5]=0
        funct3 = 3'b101;
        funct7 = 7'b0000000;        // funct7[5] = 0 ? logical shift
        #10;
        check_ctrl(4'b0110, 26, "SRLI"); // Expected: SRL

        // SRAI: funct3=101, funct7[5]=1
        funct3 = 3'b101;
        funct7 = 7'b0100000;        // funct7[5] = 1 ? arithmetic shift
        #10;
        check_ctrl(4'b0111, 27, "SRAI"); // Expected: SRA

        // ORI: funct3=110
        funct3 = 3'b110;
        funct7 = 7'b0000000;
        #10;
        check_ctrl(4'b0011, 28, "ORI"); // Expected: OR

        // ANDI: funct3=111
        funct3 = 3'b111;
        funct7 = 7'b0000000;
        #10;
        check_ctrl(4'b0010, 29, "ANDI"); // Expected: AND

        // ------------------------------------------------
        // TEST GROUP 5: Default case
        // Undefined alu_op should output ADD safely
        // ------------------------------------------------
        $display("--- DEFAULT CASE ---");

        alu_op = 2'bxx;             // Undefined alu_op
        funct3 = 3'b000;
        funct7 = 7'b0000000;
        #10;
        check_ctrl(4'b0000, 30, "DEFAULT"); // Expected: ADD (safe default)

        // ------------------------------------------------
        // Print final summary
        // ------------------------------------------------
        $display("=====================================================");
        $display("RESULTS: %0d / %0d tests passed", passed, total);
        if (failed == 0)
            $display("ALL TESTS PASSED!");
        else
            $display("%0d TEST(S) FAILED!", failed);
        $display("=====================================================");

        $finish;    // End simulation

    end

endmodule
