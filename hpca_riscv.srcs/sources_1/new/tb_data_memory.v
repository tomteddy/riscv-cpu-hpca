`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.04.2026 13:42:01
// Design Name: 
// Module Name: tb_data_memory
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
// Module : tb_data_memory (Testbench for Data Memory)
// Project : RISC-V Single-Cycle CPU
// Description : Tests all key behaviors of data memory:
//               - SW / LW  (store and load word)
//               - SH / LH  (store and load halfword signed)
//               - SB / LB  (store and load byte signed)
//               - LBU      (load byte unsigned)
//               - LHU      (load halfword unsigned)
//               - Little-endian byte ordering
//               - Write enable blocked (mem_write = 0)
//               - Sign extension for signed loads
//               - Zero extension for unsigned loads
//
// How to use in Vivado:
//   1. Add data_memory.v and tb_data_memory.v to project
//   2. Set tb_data_memory as top module for simulation
//   3. Run Behavioral Simulation
//   4. Check Tcl Console for PASS/FAIL messages
//   5. Check waveform window for signal traces
// ============================================================

`timescale 1ns / 1ps   // Time unit = 1ns, precision = 1ps

module tb_data_memory;

    // --------------------------------------------------------
    // Declare testbench signals
    // --------------------------------------------------------

    reg         clk;            // Clock signal
    reg         mem_write;      // Write enable flag
    reg  [31:0] addr;           // Byte address input
    reg  [31:0] write_data;     // Data to write
    reg  [2:0]  func3;          // Access type selector
    wire [31:0] read_data;      // Data read from memory

    // --------------------------------------------------------
    // Counters for test results
    // --------------------------------------------------------

    integer total;              // Total tests run
    integer passed;             // Tests passed
    integer failed;             // Tests failed

    // --------------------------------------------------------
    // Instantiate the data memory module
    // --------------------------------------------------------

    data_memory uut (
        .clk        (clk),          // Connect clock
        .mem_write  (mem_write),     // Connect write enable
        .addr       (addr),          // Connect address
        .write_data (write_data),    // Connect write data
        .func3      (func3),         // Connect access type
        .read_data  (read_data)      // Connect read output
    );

    // --------------------------------------------------------
    // Clock generation: toggles every 5ns = 10ns period
    // --------------------------------------------------------

    initial begin
        clk = 0;                // Start clock low
    end

    always #5 clk = ~clk;      // Toggle every 5ns

    // --------------------------------------------------------
    // Task: check_read
    // Compares read_data with expected value
    // Prints PASS or FAIL with details
    // --------------------------------------------------------

    task check_read;
        input [31:0] expected;      // Expected read value
        input [31:0] test_id;       // Test number
        input [8*30:1] test_name;   // Test name string
        begin
            total = total + 1;      // Increment total count

            if (read_data === expected) begin
                $display("PASS | Test %0d | %s | addr=0x%h | read_data=0x%h",
                    test_id, test_name, addr, read_data);
                passed = passed + 1;
            end else begin
                $display("FAIL | Test %0d | %s | addr=0x%h | expected=0x%h | got=0x%h",
                    test_id, test_name, addr, expected, read_data);
                failed = failed + 1;
            end
        end
    endtask

    // --------------------------------------------------------
    // Main simulation block
    // --------------------------------------------------------

    initial begin

        // Initialize counters
        total     = 0;
        passed    = 0;
        failed    = 0;

        // Initialize all inputs to safe defaults
        mem_write  = 1'b0;          // Write disabled
        addr       = 32'b0;         // Address = 0
        write_data = 32'b0;         // Write data = 0
        func3      = 3'b010;        // Default to word access

        // Setup waveform dump for Vivado
        $dumpfile("tb_data_memory.vcd");    // Waveform output file
        $dumpvars(0, tb_data_memory);       // Dump all signals

        // Print header
        $display("============================================");
        $display("   DATA MEMORY TESTBENCH - RISC-V CPU      ");
        $display("============================================");

        // Wait for 2 clock cycles before starting
        @(posedge clk); #1;
        @(posedge clk); #1;

        // ------------------------------------------------
        // TEST GROUP 1: SW and LW (Store Word / Load Word)
        // Write a full 32-bit word then read it back
        // ------------------------------------------------
        $display("--- SW / LW (WORD) ---");

        // Store 0x12345678 at address 0
        mem_write  = 1'b1;              // Enable write
        addr       = 32'h00000000;      // Address = 0
        write_data = 32'h12345678;      // Data to write
        func3      = 3'b010;            // SW = word store
        @(posedge clk); #1;             // Wait for write to latch

        // Load word back from address 0
        mem_write = 1'b0;               // Disable write
        addr      = 32'h00000000;       // Same address
        func3     = 3'b010;             // LW = word load
        #1;                             // Wait for combinational read
        check_read(32'h12345678, 1, "SW LW BASIC"); // Expected: same value back

        // Store max value at address 4
        mem_write  = 1'b1;
        addr       = 32'h00000004;      // Address = 4
        write_data = 32'hFFFFFFFF;      // All 1s
        func3      = 3'b010;            // SW
        @(posedge clk); #1;

        // Load back
        mem_write = 1'b0;
        addr      = 32'h00000004;
        func3     = 3'b010;             // LW
        #1;
        check_read(32'hFFFFFFFF, 2, "SW LW MAX VALUE"); // Expected: 0xFFFFFFFF

        // Store 0 at address 8
        mem_write  = 1'b1;
        addr       = 32'h00000008;      // Address = 8
        write_data = 32'h00000000;      // Zero
        func3      = 3'b010;            // SW
        @(posedge clk); #1;

        mem_write = 1'b0;
        addr      = 32'h00000008;
        func3     = 3'b010;             // LW
        #1;
        check_read(32'h00000000, 3, "SW LW ZERO"); // Expected: 0

        // ------------------------------------------------
        // TEST GROUP 2: Little-endian byte ordering
        // Store a word and verify individual bytes are
        // stored in little-endian order in memory
        // ------------------------------------------------
        $display("--- LITTLE-ENDIAN BYTE ORDER ---");

        // Store 0xAABBCCDD at address 16
        // Little-endian means:
        //   mem[16] = 0xDD (least significant byte)
        //   mem[17] = 0xCC
        //   mem[18] = 0xBB
        //   mem[19] = 0xAA (most significant byte)
        mem_write  = 1'b1;
        addr       = 32'h00000010;      // Address = 16
        write_data = 32'hAABBCCDD;      // Test value
        func3      = 3'b010;            // SW
        @(posedge clk); #1;

        // Read byte at address 16 ? should be 0xDD (lowest byte)
        mem_write = 1'b0;
        addr      = 32'h00000010;       // Address = 16
        func3     = 3'b100;             // LBU (unsigned to see raw byte)
        #1;
        check_read(32'h000000DD, 4, "LITTLE-ENDIAN BYTE 0"); // Expected: 0xDD

        // Read byte at address 17 ? should be 0xCC
        addr  = 32'h00000011;           // Address = 17
        func3 = 3'b100;                 // LBU
        #1;
        check_read(32'h000000CC, 5, "LITTLE-ENDIAN BYTE 1"); // Expected: 0xCC

        // Read byte at address 18 ? should be 0xBB
        addr  = 32'h00000012;           // Address = 18
        func3 = 3'b100;                 // LBU
        #1;
        check_read(32'h000000BB, 6, "LITTLE-ENDIAN BYTE 2"); // Expected: 0xBB

        // Read byte at address 19 ? should be 0xAA
        addr  = 32'h00000013;           // Address = 19
        func3 = 3'b100;                 // LBU
        #1;
        check_read(32'h000000AA, 7, "LITTLE-ENDIAN BYTE 3"); // Expected: 0xAA

        // ------------------------------------------------
        // TEST GROUP 3: SB and LB (Store Byte / Load Byte)
        // Signed byte access with sign extension
        // ------------------------------------------------
        $display("--- SB / LB (BYTE SIGNED) ---");

        // Store positive byte 0x7F (127) at address 32
        mem_write  = 1'b1;
        addr       = 32'h00000020;      // Address = 32
        write_data = 32'h0000007F;      // Byte value = 127
        func3      = 3'b000;            // SB = store byte
        @(posedge clk); #1;

        // Load byte signed ? positive, no sign extension needed
        mem_write = 1'b0;
        addr      = 32'h00000020;
        func3     = 3'b000;             // LB = load byte signed
        #1;
        check_read(32'h0000007F, 8, "LB POSITIVE"); // Expected: 0x0000007F

        // Store negative byte 0x80 (-128) at address 33
        // 0x80 = 1000 0000 in binary, sign bit = 1
        mem_write  = 1'b1;
        addr       = 32'h00000021;      // Address = 33
        write_data = 32'h00000080;      // Byte value = 0x80
        func3      = 3'b000;            // SB
        @(posedge clk); #1;

        // Load byte signed ? sign extend 0x80 to 32 bits = 0xFFFFFF80
        mem_write = 1'b0;
        addr      = 32'h00000021;
        func3     = 3'b000;             // LB
        #1;
        check_read(32'hFFFFFF80, 9, "LB NEGATIVE SIGN EXT"); // Expected: sign extended

        // Store 0xFF (-1 signed) at address 34
        mem_write  = 1'b1;
        addr       = 32'h00000022;
        write_data = 32'h000000FF;      // 0xFF = -1 signed byte
        func3      = 3'b000;            // SB
        @(posedge clk); #1;

        mem_write = 1'b0;
        addr      = 32'h00000022;
        func3     = 3'b000;             // LB
        #1;
        check_read(32'hFFFFFFFF, 10, "LB 0xFF SIGN EXT"); // Expected: 0xFFFFFFFF

        // ------------------------------------------------
        // TEST GROUP 4: LBU (Load Byte Unsigned)
        // Zero extension instead of sign extension
        // ------------------------------------------------
        $display("--- LBU (BYTE UNSIGNED) ---");

        // Read 0x80 stored at address 33 as unsigned
        // Should zero extend instead of sign extend
        mem_write = 1'b0;
        addr      = 32'h00000021;       // Address = 33 (0x80 stored earlier)
        func3     = 3'b100;             // LBU = load byte unsigned
        #1;
        check_read(32'h00000080, 11, "LBU ZERO EXT 0x80"); // Expected: 0x00000080

        // Read 0xFF stored at address 34 as unsigned
        addr  = 32'h00000022;           // Address = 34 (0xFF stored earlier)
        func3 = 3'b100;                 // LBU
        #1;
        check_read(32'h000000FF, 12, "LBU ZERO EXT 0xFF"); // Expected: 0x000000FF

        // ------------------------------------------------
        // TEST GROUP 5: SH / LH (Store Halfword / Load Halfword)
        // Signed halfword access with sign extension
        // ------------------------------------------------
        $display("--- SH / LH (HALFWORD SIGNED) ---");

        // Store positive halfword 0x1234 at address 48
        mem_write  = 1'b1;
        addr       = 32'h00000030;      // Address = 48
        write_data = 32'h00001234;      // Halfword = 0x1234
        func3      = 3'b001;            // SH = store halfword
        @(posedge clk); #1;

        // Load halfword signed ? positive, no sign extension
        mem_write = 1'b0;
        addr      = 32'h00000030;
        func3     = 3'b001;             // LH = load halfword signed
        #1;
        check_read(32'h00001234, 13, "LH POSITIVE"); // Expected: 0x00001234

        // Store negative halfword 0x8000 at address 50
        // 0x8000 = sign bit set = negative in signed 16-bit
        mem_write  = 1'b1;
        addr       = 32'h00000032;      // Address = 50
        write_data = 32'h00008000;      // Halfword = 0x8000
        func3      = 3'b001;            // SH
        @(posedge clk); #1;

        // Load halfword signed ? sign extend to 32 bits
        mem_write = 1'b0;
        addr      = 32'h00000032;
        func3     = 3'b001;             // LH
        #1;
        check_read(32'hFFFF8000, 14, "LH NEGATIVE SIGN EXT"); // Expected: sign extended

        // ------------------------------------------------
        // TEST GROUP 6: LHU (Load Halfword Unsigned)
        // Zero extension instead of sign extension
        // ------------------------------------------------
        $display("--- LHU (HALFWORD UNSIGNED) ---");

        // Read 0x8000 stored at address 50 as unsigned
        mem_write = 1'b0;
        addr      = 32'h00000032;       // Address = 50
        func3     = 3'b101;             // LHU = load halfword unsigned
        #1;
        check_read(32'h00008000, 15, "LHU ZERO EXT 0x8000"); // Expected: 0x00008000

        // ------------------------------------------------
        // TEST GROUP 7: Write enable blocked
        // mem_write = 0 should prevent any write
        // ------------------------------------------------
        $display("--- WRITE ENABLE BLOCKED ---");

        // First write a known value at address 64
        mem_write  = 1'b1;
        addr       = 32'h00000040;      // Address = 64
        write_data = 32'hCAFEBABE;      // Known value
        func3      = 3'b010;            // SW
        @(posedge clk); #1;

        // Try to overwrite with write enable off
        mem_write  = 1'b0;              // Write disabled
        addr       = 32'h00000040;      // Same address
        write_data = 32'hDEADBEEF;      // Different value (should NOT be written)
        func3      = 3'b010;            // SW
        @(posedge clk); #1;             // Clock edge passes but write is disabled

        // Read back - should still be 0xCAFEBABE
        mem_write = 1'b0;
        addr      = 32'h00000040;
        func3     = 3'b010;             // LW
        #1;
        check_read(32'hCAFEBABE, 16, "WRITE ENABLE BLOCKED"); // Expected: unchanged

        // ------------------------------------------------
        // TEST GROUP 8: Multiple addresses independent
        // Verify different addresses don't interfere
        // ------------------------------------------------
        $display("--- ADDRESS INDEPENDENCE ---");

        // Write different values to 3 different addresses
        mem_write  = 1'b1;
        addr       = 32'h00000080;      // Address = 128
        write_data = 32'h11111111;
        func3      = 3'b010;            // SW
        @(posedge clk); #1;

        addr       = 32'h00000084;      // Address = 132
        write_data = 32'h22222222;
        func3      = 3'b010;            // SW
        @(posedge clk); #1;

        addr       = 32'h00000088;      // Address = 136
        write_data = 32'h33333333;
        func3      = 3'b010;            // SW
        @(posedge clk); #1;

        mem_write = 1'b0;               // Disable write for reads

        // Verify all three are independent
        addr  = 32'h00000080;
        func3 = 3'b010;                 // LW
        #1;
        check_read(32'h11111111, 17, "ADDR INDEPENDENT 128"); // Expected: 0x11111111

        addr  = 32'h00000084;
        func3 = 3'b010;                 // LW
        #1;
        check_read(32'h22222222, 18, "ADDR INDEPENDENT 132"); // Expected: 0x22222222

        addr  = 32'h00000088;
        func3 = 3'b010;                 // LW
        #1;
        check_read(32'h33333333, 19, "ADDR INDEPENDENT 136"); // Expected: 0x33333333

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
