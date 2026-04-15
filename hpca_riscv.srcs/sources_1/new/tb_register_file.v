`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.04.2026 12:56:01
// Design Name: 
// Module Name: tb_register_file
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
// Module : tb_register_file (Testbench for Register File)
// Project : RISC-V Single-Cycle CPU
// Description : Tests all key behaviors of the register file:
//               - Basic read and write operations
//               - x0 hardwired to 0 (writes ignored)
//               - Write enable = 0 prevents writing
//               - Reading and writing same register same cycle
//               - Multiple register read/write combinations
//
// How to use in Vivado:
//   1. Add register_file.v and tb_register_file.v to project
//   2. Set tb_register_file as top module for simulation
//   3. Run Behavioral Simulation
//   4. Check Tcl Console for PASS/FAIL messages
//   5. Check waveform window for signal traces
// ============================================================

`timescale 1ns / 1ps   // Time unit = 1ns, precision = 1ps

module tb_register_file;

    // --------------------------------------------------------
    // Declare testbench signals
    // These connect to the register file inputs and outputs
    // --------------------------------------------------------

    reg         clk;            // Clock signal
    reg         reg_write;      // Write enable flag
    reg  [4:0]  rs1;            // Read address 1
    reg  [4:0]  rs2;            // Read address 2
    reg  [4:0]  rd;             // Write address
    reg  [31:0] write_data;     // Data to write
    wire [31:0] read_data1;     // Data read from rs1
    wire [31:0] read_data2;     // Data read from rs2

    // --------------------------------------------------------
    // Counters for test results
    // --------------------------------------------------------

    integer total;              // Total tests run
    integer passed;             // Tests passed
    integer failed;             // Tests failed

    // --------------------------------------------------------
    // Instantiate the register file module
    // --------------------------------------------------------

    register_file uut (
        .clk        (clk),          // Connect clock
        .reg_write  (reg_write),    // Connect write enable
        .rs1        (rs1),          // Connect read address 1
        .rs2        (rs2),          // Connect read address 2
        .rd         (rd),           // Connect write address
        .write_data (write_data),   // Connect write data
        .read_data1 (read_data1),   // Connect read output 1
        .read_data2 (read_data2)    // Connect read output 2
    );

    // --------------------------------------------------------
    // Clock generation
    // Clock toggles every 5ns = 10ns period = 100MHz
    // --------------------------------------------------------

    initial begin
        clk = 0;                // Start clock at 0
    end

    always #5 clk = ~clk;      // Toggle clock every 5ns

    // --------------------------------------------------------
    // Task: check_read1
    // Checks read_data1 against expected value
    // --------------------------------------------------------

    task check_read1;
        input [31:0] expected;      // Expected value
        input [31:0] test_id;       // Test number
        input [8*20:1] test_name;   // Test name string
        begin
            total = total + 1;      // Increment total count

            if (read_data1 === expected) begin
                $display("PASS | Test %0d | %s | rs1=x%0d | read_data1=%0d",
                    test_id, test_name, rs1, read_data1);
                passed = passed + 1;
            end else begin
                $display("FAIL | Test %0d | %s | rs1=x%0d | expected=%0d | got=%0d",
                    test_id, test_name, rs1, expected, read_data1);
                failed = failed + 1;
            end
        end
    endtask

    // --------------------------------------------------------
    // Task: check_read2
    // Checks read_data2 against expected value
    // --------------------------------------------------------

    task check_read2;
        input [31:0] expected;      // Expected value
        input [31:0] test_id;       // Test number
        input [8*20:1] test_name;   // Test name string
        begin
            total = total + 1;      // Increment total count

            if (read_data2 === expected) begin
                $display("PASS | Test %0d | %s | rs2=x%0d | read_data2=%0d",
                    test_id, test_name, rs2, read_data2);
                passed = passed + 1;
            end else begin
                $display("FAIL | Test %0d | %s | rs2=x%0d | expected=%0d | got=%0d",
                    test_id, test_name, rs2, expected, read_data2);
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

        // Initialize all inputs to safe default values
        reg_write  = 0;             // Write disabled at start
        rs1        = 5'd0;          // Read address 1 = x0
        rs2        = 5'd0;          // Read address 2 = x0
        rd         = 5'd0;          // Write address = x0
        write_data = 32'd0;         // Write data = 0

        // Setup waveform dump for Vivado
        $dumpfile("tb_register_file.vcd");  // Waveform output file
        $dumpvars(0, tb_register_file);     // Dump all signals

        // Print header
        $display("============================================");
        $display("   REGISTER FILE TESTBENCH - RISC-V CPU    ");
        $display("============================================");

        // Wait for 2 clock cycles before starting tests
        @(posedge clk); #1;         // Wait for rising edge + 1ns settle time
        @(posedge clk); #1;         // Wait one more cycle

        // ------------------------------------------------
        // TEST GROUP 1: Basic write and read
        // Write a value to a register, then read it back
        // ------------------------------------------------
        $display("--- BASIC WRITE AND READ ---");

        // Write 100 into register x1
        reg_write  = 1'b1;          // Enable write
        rd         = 5'd1;          // Write to x1
        write_data = 32'd100;       // Data = 100
        @(posedge clk); #1;         // Wait for rising edge to latch write

        // Read back from x1 using port 1
        rs1 = 5'd1;                 // Read x1 on port 1
        #1;                         // Small delay for combinational read to settle
        check_read1(32'd100, 1, "BASIC WRITE READ"); // Expected: 100

        // Write 200 into register x2
        rd         = 5'd2;          // Write to x2
        write_data = 32'd200;       // Data = 200
        @(posedge clk); #1;         // Wait for rising edge

        // Read x2 on port 2
        rs2 = 5'd2;                 // Read x2 on port 2
        #1;                         // Settle time
        check_read2(32'd200, 2, "BASIC WRITE READ"); // Expected: 200

        // Write large value into x3
        rd         = 5'd3;          // Write to x3
        write_data = 32'hDEADBEEF;  // Data = 0xDEADBEEF
        @(posedge clk); #1;         // Wait for rising edge

        // Read x3 on port 1
        rs1 = 5'd3;                 // Read x3
        #1;                         // Settle time
        check_read1(32'hDEADBEEF, 3, "BASIC WRITE READ"); // Expected: 0xDEADBEEF

        // ------------------------------------------------
        // TEST GROUP 2: Simultaneous read from 2 ports
        // Read two different registers at the same time
        // ------------------------------------------------
        $display("--- SIMULTANEOUS TWO PORT READ ---");

        // x1 = 100, x2 = 200 already written above
        // Disable write so we are purely reading
        reg_write = 1'b0;           // Disable write

        rs1 = 5'd1;                 // Read x1 on port 1
        rs2 = 5'd2;                 // Read x2 on port 2
        #1;                         // Settle time

        check_read1(32'd100, 4, "TWO PORT READ");  // Expected: x1 = 100
        check_read2(32'd200, 5, "TWO PORT READ");  // Expected: x2 = 200

        // ------------------------------------------------
        // TEST GROUP 3: x0 hardwired to 0
        // Writing to x0 should be ignored, reads return 0
        // ------------------------------------------------
        $display("--- X0 HARDWIRED TO ZERO ---");

        // Try to write a non-zero value into x0
        reg_write  = 1'b1;          // Enable write
        rd         = 5'd0;          // Write address = x0
        write_data = 32'hFFFFFFFF;  // Try to write all 1s
        @(posedge clk); #1;         // Wait for rising edge

        // Read x0 on both ports, should still be 0
        rs1 = 5'd0;                 // Read x0 on port 1
        rs2 = 5'd0;                 // Read x0 on port 2
        #1;                         // Settle time

        check_read1(32'd0, 6, "X0 WRITE IGNORED"); // Expected: 0 (write ignored)
        check_read2(32'd0, 7, "X0 WRITE IGNORED"); // Expected: 0 (write ignored)

        // ------------------------------------------------
        // TEST GROUP 4: Write enable = 0 prevents writing
        // Data should not change when reg_write is low
        // ------------------------------------------------
        $display("--- WRITE ENABLE BLOCKED ---");

        // First write a known value into x5
        reg_write  = 1'b1;          // Enable write
        rd         = 5'd5;          // Write to x5
        write_data = 32'd555;       // Write 555
        @(posedge clk); #1;         // Latch the write

        // Now disable write and try to overwrite x5
        reg_write  = 1'b0;          // Disable write
        rd         = 5'd5;          // Still pointing to x5
        write_data = 32'd999;       // New data = 999 (should NOT be written)
        @(posedge clk); #1;         // Clock edge passes but write is disabled

        // Read x5, should still be 555
        rs1 = 5'd5;                 // Read x5 on port 1
        #1;                         // Settle time
        check_read1(32'd555, 8, "WRITE ENABLE OFF"); // Expected: still 555

        // ------------------------------------------------
        // TEST GROUP 5: Read and write same register same cycle
        // Write to x7 while reading x7
        // Expected: read gets OLD value (write hasn't happened yet)
        // because write is synchronous but read is combinational
        // ------------------------------------------------
        $display("--- READ WRITE SAME REGISTER SAME CYCLE ---");

        // First write a known value into x7
        reg_write  = 1'b1;          // Enable write
        rd         = 5'd7;          // Write to x7
        write_data = 32'd77;        // Write 77 into x7
        @(posedge clk); #1;         // Latch write

        // Now set up read of x7 and a new write to x7 at the same time
        rd         = 5'd7;          // Write address = x7
        write_data = 32'd999;       // New value to write = 999
        rs1        = 5'd7;          // Also reading x7 on port 1
        #1;                         // Combinational read settles immediately

        // At this point clock has NOT risen yet
        // Read should see OLD value (77) because write is synchronous
        check_read1(32'd77, 9, "READ BEFORE WRITE EDGE"); // Expected: 77 (old value)

        @(posedge clk); #1;         // Now clock rises, 999 gets written

        // Read again after clock edge, should now see new value
        rs1 = 5'd7;                 // Read x7 again
        #1;                         // Settle time
        check_read1(32'd999, 10, "READ AFTER WRITE EDGE"); // Expected: 999 (new value)

        // ------------------------------------------------
        // TEST GROUP 6: Write to multiple registers
        // and verify all retain their values independently
        // ------------------------------------------------
        $display("--- MULTIPLE REGISTER INDEPENDENCE ---");

        // Write unique values into x10, x11, x12
        reg_write  = 1'b1;          // Enable write

        rd         = 5'd10;         // Write to x10
        write_data = 32'd1010;      // Value = 1010
        @(posedge clk); #1;

        rd         = 5'd11;         // Write to x11
        write_data = 32'd1111;      // Value = 1111
        @(posedge clk); #1;

        rd         = 5'd12;         // Write to x12
        write_data = 32'd1212;      // Value = 1212
        @(posedge clk); #1;

        reg_write = 1'b0;           // Disable write for reads

        // Verify x10
        rs1 = 5'd10;                // Read x10
        #1;
        check_read1(32'd1010, 11, "MULTI REG x10"); // Expected: 1010

        // Verify x11
        rs1 = 5'd11;                // Read x11
        #1;
        check_read1(32'd1111, 12, "MULTI REG x11"); // Expected: 1111

        // Verify x12
        rs1 = 5'd12;                // Read x12
        #1;
        check_read1(32'd1212, 13, "MULTI REG x12"); // Expected: 1212

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
