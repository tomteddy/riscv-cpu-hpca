`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.04.2026 18:09:30
// Design Name: 
// Module Name: pc
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
// Module : pc (Program Counter)
// Project : RISC-V Single-Cycle CPU
// Description : Holds the current Program Counter value.
//               Updates to pc_next on every rising clock edge.
//               Resets to 0x00000000 when reset is high.
//               All branch/jump decision logic lives in
//               cpu_top.v which computes pc_next and feeds
//               it here. This module is intentionally simple.
//
// Inputs:
//   clk      - Clock signal
//   reset    - Synchronous reset: 1 = reset PC to 0
//   pc_next  - 32-bit next PC value (computed in cpu_top.v)
//              This is one of:
//              - PC + 4         (sequential)
//              - PC + immediate (branch taken or JAL)
//              - rs1 + immediate (JALR)
//
// Output:
//   pc_out   - 32-bit current PC value
//              Sent to instruction memory and other modules
// ============================================================

module pc (
    input         clk,      // Clock signal
    input         reset,    // Synchronous reset signal
    input  [31:0] pc_next,  // Next PC value from cpu_top.v
    output reg [31:0] pc_out // Current PC value output
);

    // --------------------------------------------------------
    // Always block: runs on rising clock edge
    // On reset: PC goes back to 0x00000000
    // Otherwise: PC takes the next value from cpu_top.v
    // --------------------------------------------------------

    always @(posedge clk) begin

        if (reset == 1'b1) begin
            // Synchronous reset: set PC to start of memory
            pc_out <= 32'h00000000;     // Reset to address 0
        end else begin
            // Normal operation: advance to next PC value
            pc_out <= pc_next;          // Load next PC value
        end

    end

endmodule
