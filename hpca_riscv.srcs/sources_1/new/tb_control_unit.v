`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.04.2026 14:42:32
// Design Name: 
// Module Name: tb_control_unit
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
// Module : tb_control_unit (Testbench for Control Unit)
// Project : RISC-V Single-Cycle CPU
// Description : Tests all 47 RV32I instructions.
//               Note: The control unit only sees the 7-bit
//               opcode. Instructions sharing the same opcode
//               will produce identical control signals.
//               The difference between instructions in the
//               same group (e.g. ADD vs SUB) is handled by
//               alu_control.v using funct3 and funct7.
//
//               This testbench labels every instruction
//               individually so you can clearly see which
//               instruction maps to which opcode and signals.
//
// RV32I Instruction Groups by Opcode:
//   R-type  (0110011): ADD SUB AND OR XOR SLL SRL SRA SLT SLTU
//   I-arith (0010011): ADDI SLTI SLTIU ANDI ORI XORI SLLI SRLI SRAI
//   Load    (0000011): LB LH LW LBU LHU
//   Store   (0100011): SB SH SW
//   Branch  (1100011): BEQ BNE BLT BGE BLTU BGEU
//   LUI     (0110111): LUI
//   AUIPC   (0010111): AUIPC
//   JAL     (1101111): JAL
//   JALR    (1100111): JALR
//
// How to use in Vivado:
//   1. Add control_unit.v and tb_control_unit.v to project
//   2. Set tb_control_unit as top module for simulation
//   3. Run Behavioral Simulation
//   4. Check Tcl Console for PASS/FAIL messages
//   5. Check waveform window for signal traces
// ============================================================

`timescale 1ns / 1ps

module tb_control_unit;

    // --------------------------------------------------------
    // Declare testbench signals
    // --------------------------------------------------------

    reg  [6:0] opcode;      // 7-bit opcode input

    wire       reg_write;   // Register write enable output
    wire       mem_write;   // Memory write enable output
    wire       alu_src;     // ALU B source select output
    wire [1:0] alu_a_sel;   // ALU A source select output
    wire [1:0] wb_sel;      // Writeback source select output
    wire       branch;      // Branch flag output
    wire       jump;        // Jump flag output
    wire [2:0] imm_sel;     // Immediate type select output
    wire [1:0] alu_op;      // ALU operation category output

    // --------------------------------------------------------
    // Counters for test results
    // --------------------------------------------------------

    integer total;          // Total tests run
    integer passed;         // Tests passed
    integer failed;         // Tests failed

    // --------------------------------------------------------
    // Instantiate the control unit module
    // --------------------------------------------------------

    control_unit uut (
        .opcode    (opcode),
        .reg_write (reg_write),
        .mem_write (mem_write),
        .alu_src   (alu_src),
        .alu_a_sel (alu_a_sel),
        .wb_sel    (wb_sel),
        .branch    (branch),
        .jump      (jump),
        .imm_sel   (imm_sel),
        .alu_op    (alu_op)
    );

    // --------------------------------------------------------
    // Task: check_signals
    // Checks ALL control signals at once
    // Prints individual mismatches for easy debugging
    // --------------------------------------------------------

    task check_signals;
        input        exp_reg_write;
        input        exp_mem_write;
        input        exp_alu_src;
        input [1:0]  exp_alu_a_sel;
        input [1:0]  exp_wb_sel;
        input        exp_branch;
        input        exp_jump;
        input [2:0]  exp_imm_sel;
        input [1:0]  exp_alu_op;
        input [31:0] test_id;
        input [8*20:1] test_name;

        reg all_pass;

        begin
            total    = total + 1;
            all_pass = 1'b1;

            if (reg_write !== exp_reg_write) begin
                $display("  MISMATCH reg_write : expected=%b got=%b", exp_reg_write, reg_write);
                all_pass = 1'b0;
            end
            if (mem_write !== exp_mem_write) begin
                $display("  MISMATCH mem_write : expected=%b got=%b", exp_mem_write, mem_write);
                all_pass = 1'b0;
            end
            if (alu_src !== exp_alu_src) begin
                $display("  MISMATCH alu_src   : expected=%b got=%b", exp_alu_src, alu_src);
                all_pass = 1'b0;
            end
            if (alu_a_sel !== exp_alu_a_sel) begin
                $display("  MISMATCH alu_a_sel : expected=%b got=%b", exp_alu_a_sel, alu_a_sel);
                all_pass = 1'b0;
            end
            if (wb_sel !== exp_wb_sel) begin
                $display("  MISMATCH wb_sel    : expected=%b got=%b", exp_wb_sel, wb_sel);
                all_pass = 1'b0;
            end
            if (branch !== exp_branch) begin
                $display("  MISMATCH branch    : expected=%b got=%b", exp_branch, branch);
                all_pass = 1'b0;
            end
            if (jump !== exp_jump) begin
                $display("  MISMATCH jump      : expected=%b got=%b", exp_jump, jump);
                all_pass = 1'b0;
            end
            if (imm_sel !== exp_imm_sel) begin
                $display("  MISMATCH imm_sel   : expected=%b got=%b", exp_imm_sel, imm_sel);
                all_pass = 1'b0;
            end
            if (alu_op !== exp_alu_op) begin
                $display("  MISMATCH alu_op    : expected=%b got=%b", exp_alu_op, alu_op);
                all_pass = 1'b0;
            end

            if (all_pass) begin
                $display("PASS | Test %0d | %-6s | opcode=%b", test_id, test_name, opcode);
                passed = passed + 1;
            end else begin
                $display("FAIL | Test %0d | %-6s | opcode=%b", test_id, test_name, opcode);
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

        opcode = 7'b0000000;

        $dumpfile("tb_control_unit.vcd");
        $dumpvars(0, tb_control_unit);

        $display("=====================================================");
        $display("     CONTROL UNIT TESTBENCH - ALL RV32I INSTR       ");
        $display("=====================================================");
        $display("NOTE: Instructions sharing the same opcode produce");
        $display("      identical control signals. Differences between");
        $display("      them are resolved in alu_control.v via funct3.");
        $display("=====================================================");

        // ------------------------------------------------
        // R-TYPE GROUP (opcode = 0110011)
        // All 10 instructions produce identical signals
        // funct3 + funct7 differentiate them in alu_control
        // ------------------------------------------------
        $display("--- R-TYPE (opcode=0110011) ---");
        opcode = 7'b0110011;    // Set opcode once for whole group
        #10;                    // Wait for outputs to settle

        // ADD: rd = rs1 + rs2
        check_signals(1'b1, 1'b0, 1'b0, 2'b00, 2'b00, 1'b0, 1'b0, 3'b000, 2'b10, 1,  "ADD");
        // SUB: rd = rs1 - rs2
        check_signals(1'b1, 1'b0, 1'b0, 2'b00, 2'b00, 1'b0, 1'b0, 3'b000, 2'b10, 2,  "SUB");
        // AND: rd = rs1 & rs2
        check_signals(1'b1, 1'b0, 1'b0, 2'b00, 2'b00, 1'b0, 1'b0, 3'b000, 2'b10, 3,  "AND");
        // OR: rd = rs1 | rs2
        check_signals(1'b1, 1'b0, 1'b0, 2'b00, 2'b00, 1'b0, 1'b0, 3'b000, 2'b10, 4,  "OR");
        // XOR: rd = rs1 ^ rs2
        check_signals(1'b1, 1'b0, 1'b0, 2'b00, 2'b00, 1'b0, 1'b0, 3'b000, 2'b10, 5,  "XOR");
        // SLL: rd = rs1 << rs2[4:0]
        check_signals(1'b1, 1'b0, 1'b0, 2'b00, 2'b00, 1'b0, 1'b0, 3'b000, 2'b10, 6,  "SLL");
        // SRL: rd = rs1 >> rs2[4:0] logical
        check_signals(1'b1, 1'b0, 1'b0, 2'b00, 2'b00, 1'b0, 1'b0, 3'b000, 2'b10, 7,  "SRL");
        // SRA: rd = rs1 >>> rs2[4:0] arithmetic
        check_signals(1'b1, 1'b0, 1'b0, 2'b00, 2'b00, 1'b0, 1'b0, 3'b000, 2'b10, 8,  "SRA");
        // SLT: rd = (signed rs1 < signed rs2) ? 1 : 0
        check_signals(1'b1, 1'b0, 1'b0, 2'b00, 2'b00, 1'b0, 1'b0, 3'b000, 2'b10, 9,  "SLT");
        // SLTU: rd = (rs1 < rs2 unsigned) ? 1 : 0
        check_signals(1'b1, 1'b0, 1'b0, 2'b00, 2'b00, 1'b0, 1'b0, 3'b000, 2'b10, 10, "SLTU");

        // ------------------------------------------------
        // I-TYPE ARITHMETIC GROUP (opcode = 0010011)
        // All 9 instructions produce identical signals
        // funct3 differentiates them in alu_control
        // ------------------------------------------------
        $display("--- I-TYPE ARITHMETIC (opcode=0010011) ---");
        opcode = 7'b0010011;    // Set opcode once for whole group
        #10;

        // ADDI: rd = rs1 + imm
        check_signals(1'b1, 1'b0, 1'b1, 2'b00, 2'b00, 1'b0, 1'b0, 3'b000, 2'b11, 11, "ADDI");
        // SLTI: rd = (signed rs1 < signed imm) ? 1 : 0
        check_signals(1'b1, 1'b0, 1'b1, 2'b00, 2'b00, 1'b0, 1'b0, 3'b000, 2'b11, 12, "SLTI");
        // SLTIU: rd = (rs1 < imm unsigned) ? 1 : 0
        check_signals(1'b1, 1'b0, 1'b1, 2'b00, 2'b00, 1'b0, 1'b0, 3'b000, 2'b11, 13, "SLTIU");
        // ANDI: rd = rs1 & imm
        check_signals(1'b1, 1'b0, 1'b1, 2'b00, 2'b00, 1'b0, 1'b0, 3'b000, 2'b11, 14, "ANDI");
        // ORI: rd = rs1 | imm
        check_signals(1'b1, 1'b0, 1'b1, 2'b00, 2'b00, 1'b0, 1'b0, 3'b000, 2'b11, 15, "ORI");
        // XORI: rd = rs1 ^ imm
        check_signals(1'b1, 1'b0, 1'b1, 2'b00, 2'b00, 1'b0, 1'b0, 3'b000, 2'b11, 16, "XORI");
        // SLLI: rd = rs1 << imm[4:0]
        check_signals(1'b1, 1'b0, 1'b1, 2'b00, 2'b00, 1'b0, 1'b0, 3'b000, 2'b11, 17, "SLLI");
        // SRLI: rd = rs1 >> imm[4:0] logical
        check_signals(1'b1, 1'b0, 1'b1, 2'b00, 2'b00, 1'b0, 1'b0, 3'b000, 2'b11, 18, "SRLI");
        // SRAI: rd = rs1 >>> imm[4:0] arithmetic
        check_signals(1'b1, 1'b0, 1'b1, 2'b00, 2'b00, 1'b0, 1'b0, 3'b000, 2'b11, 19, "SRAI");

        // ------------------------------------------------
        // LOAD GROUP (opcode = 0000011)
        // All 5 instructions produce identical signals
        // funct3 passed to data_memory directly for width
        // ------------------------------------------------
        $display("--- LOAD (opcode=0000011) ---");
        opcode = 7'b0000011;    // Set opcode once for whole group
        #10;

        // LB: rd = sign_extend(mem[rs1+imm][7:0])
        check_signals(1'b1, 1'b0, 1'b1, 2'b00, 2'b01, 1'b0, 1'b0, 3'b000, 2'b00, 20, "LB");
        // LH: rd = sign_extend(mem[rs1+imm][15:0])
        check_signals(1'b1, 1'b0, 1'b1, 2'b00, 2'b01, 1'b0, 1'b0, 3'b000, 2'b00, 21, "LH");
        // LW: rd = mem[rs1+imm][31:0]
        check_signals(1'b1, 1'b0, 1'b1, 2'b00, 2'b01, 1'b0, 1'b0, 3'b000, 2'b00, 22, "LW");
        // LBU: rd = zero_extend(mem[rs1+imm][7:0])
        check_signals(1'b1, 1'b0, 1'b1, 2'b00, 2'b01, 1'b0, 1'b0, 3'b000, 2'b00, 23, "LBU");
        // LHU: rd = zero_extend(mem[rs1+imm][15:0])
        check_signals(1'b1, 1'b0, 1'b1, 2'b00, 2'b01, 1'b0, 1'b0, 3'b000, 2'b00, 24, "LHU");

        // ------------------------------------------------
        // STORE GROUP (opcode = 0100011)
        // All 3 instructions produce identical signals
        // funct3 passed to data_memory directly for width
        // ------------------------------------------------
        $display("--- STORE (opcode=0100011) ---");
        opcode = 7'b0100011;    // Set opcode once for whole group
        #10;

        // SB: mem[rs1+imm][7:0] = rs2[7:0]
        check_signals(1'b0, 1'b1, 1'b1, 2'b00, 2'b00, 1'b0, 1'b0, 3'b001, 2'b00, 25, "SB");
        // SH: mem[rs1+imm][15:0] = rs2[15:0]
        check_signals(1'b0, 1'b1, 1'b1, 2'b00, 2'b00, 1'b0, 1'b0, 3'b001, 2'b00, 26, "SH");
        // SW: mem[rs1+imm][31:0] = rs2
        check_signals(1'b0, 1'b1, 1'b1, 2'b00, 2'b00, 1'b0, 1'b0, 3'b001, 2'b00, 27, "SW");

        // ------------------------------------------------
        // BRANCH GROUP (opcode = 1100011)
        // All 6 instructions produce identical signals
        // funct3 used in cpu_top to evaluate branch condition
        // ------------------------------------------------
        $display("--- BRANCH (opcode=1100011) ---");
        opcode = 7'b1100011;    // Set opcode once for whole group
        #10;

        // BEQ: if (rs1 == rs2) PC = PC + imm
        check_signals(1'b0, 1'b0, 1'b0, 2'b00, 2'b00, 1'b1, 1'b0, 3'b010, 2'b01, 28, "BEQ");
        // BNE: if (rs1 != rs2) PC = PC + imm
        check_signals(1'b0, 1'b0, 1'b0, 2'b00, 2'b00, 1'b1, 1'b0, 3'b010, 2'b01, 29, "BNE");
        // BLT: if (signed rs1 < signed rs2) PC = PC + imm
        check_signals(1'b0, 1'b0, 1'b0, 2'b00, 2'b00, 1'b1, 1'b0, 3'b010, 2'b01, 30, "BLT");
        // BGE: if (signed rs1 >= signed rs2) PC = PC + imm
        check_signals(1'b0, 1'b0, 1'b0, 2'b00, 2'b00, 1'b1, 1'b0, 3'b010, 2'b01, 31, "BGE");
        // BLTU: if (rs1 < rs2 unsigned) PC = PC + imm
        check_signals(1'b0, 1'b0, 1'b0, 2'b00, 2'b00, 1'b1, 1'b0, 3'b010, 2'b01, 32, "BLTU");
        // BGEU: if (rs1 >= rs2 unsigned) PC = PC + imm
        check_signals(1'b0, 1'b0, 1'b0, 2'b00, 2'b00, 1'b1, 1'b0, 3'b010, 2'b01, 33, "BGEU");

        // ------------------------------------------------
        // LUI (opcode = 0110111)
        // rd = {imm[31:12], 12'b0}
        // ALU computes 0 + imm = imm
        // ------------------------------------------------
        $display("--- LUI (opcode=0110111) ---");
        opcode = 7'b0110111;
        #10;

        check_signals(1'b1, 1'b0, 1'b1, 2'b10, 2'b00, 1'b0, 1'b0, 3'b011, 2'b00, 34, "LUI");

        // ------------------------------------------------
        // AUIPC (opcode = 0010111)
        // rd = PC + {imm[31:12], 12'b0}
        // ------------------------------------------------
        $display("--- AUIPC (opcode=0010111) ---");
        opcode = 7'b0010111;
        #10;

        check_signals(1'b1, 1'b0, 1'b1, 2'b01, 2'b00, 1'b0, 1'b0, 3'b011, 2'b00, 35, "AUIPC");

        // ------------------------------------------------
        // JAL (opcode = 1101111)
        // rd = PC + 4, PC = PC + imm
        // ------------------------------------------------
        $display("--- JAL (opcode=1101111) ---");
        opcode = 7'b1101111;
        #10;

        check_signals(1'b1, 1'b0, 1'b1, 2'b01, 2'b10, 1'b0, 1'b1, 3'b100, 2'b00, 36, "JAL");

        // ------------------------------------------------
        // JALR (opcode = 1100111)
        // rd = PC + 4, PC = (rs1 + imm) & ~1
        // ------------------------------------------------
        $display("--- JALR (opcode=1100111) ---");
        opcode = 7'b1100111;
        #10;

        check_signals(1'b1, 1'b0, 1'b1, 2'b00, 2'b10, 1'b0, 1'b1, 3'b000, 2'b00, 37, "JALR");

        // ------------------------------------------------
        // DEFAULT: Unknown opcode
        // All outputs should be 0 (safe NOP-like state)
        // ------------------------------------------------
        $display("--- DEFAULT UNKNOWN OPCODE ---");
        opcode = 7'b1111111;
        #10;

        check_signals(1'b0, 1'b0, 1'b0, 2'b00, 2'b00, 1'b0, 1'b0, 3'b000, 2'b00, 38, "DEFAULT");

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

        $finish;

    end

endmodule
