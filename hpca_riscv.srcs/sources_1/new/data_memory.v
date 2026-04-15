`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.04.2026 13:39:57
// Design Name: 
// Module Name: data_memory
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
// Module : data_memory
// Project : RISC-V Single-Cycle CPU
// Description : Read/Write data memory (RAM)
//               Byte-addressable, little-endian storage
//               following RISC-V standard.
//               - 16384 bytes = 16KB total
//               - Combinational reads (instant)
//               - Synchronous writes (on rising clock edge)
//               - Supports byte, halfword, and word access
//               - Write controlled by mem_write enable signal
//
// Inputs:
//   clk        - Clock signal
//   mem_write  - Write enable: 1 = write, 0 = read only
//   addr       - 32-bit byte address (from ALU result)
//   write_data - 32-bit data to write into memory
//   func3      - 3-bit function code to select access type
//                000 = LB  / SB  (byte, signed load)
//                001 = LH  / SH  (halfword, signed load)
//                010 = LW  / SW  (word)
//                100 = LBU       (byte, unsigned load)
//                101 = LHU       (halfword, unsigned load)
//
// Outputs:
//   read_data  - 32-bit data read from memory
//
// Little-endian layout example:
//   Storing 0x12345678 at address 0:
//   mem[0] = 0x78  (least significant byte)
//   mem[1] = 0x56
//   mem[2] = 0x34
//   mem[3] = 0x12  (most significant byte)
// ============================================================

module data_memory (
    input         clk,          // Clock signal
    input         mem_write,    // Write enable flag
    input  [31:0] addr,         // Byte address (from ALU)
    input  [31:0] write_data,   // Data to write
    input  [2:0]  func3,        // Access type selector
    output reg [31:0] read_data // Data read from memory
);

    // --------------------------------------------------------
    // Declare byte-addressable memory
    // 16384 bytes = 16KB
    // Stored as individual bytes for correct little-endian access
    // --------------------------------------------------------

    reg [7:0] mem [0:16383];    // 16384 x 8-bit byte array

    // --------------------------------------------------------
    // Initialize all memory to 0 at simulation start
    // --------------------------------------------------------

    integer i;                  // Loop variable

    initial begin
        for (i = 0; i < 16384; i = i + 1) begin
            mem[i] = 8'b0;      // Set every byte to 0
        end
    end

    // --------------------------------------------------------
    // COMBINATIONAL READ
    // Reads happen instantly, no clock needed
    // func3 selects how many bytes to read and
    // whether to sign-extend or zero-extend
    // --------------------------------------------------------

    always @(*) begin

        case (func3)

            3'b000: begin
                // LB: Load Byte (signed)
                // Read 1 byte from mem[addr]
                // Sign extend bit 7 across upper 24 bits
                read_data = {{24{mem[addr][7]}},    // Sign extend from bit 7
                              mem[addr]};            // 1 byte at addr
            end

            3'b001: begin
                // LH: Load Halfword (signed)
                // Read 2 bytes: mem[addr] = low byte, mem[addr+1] = high byte
                // Little-endian: lower address = less significant byte
                // Sign extend bit 15 across upper 16 bits
                read_data = {{16{mem[addr+1][7]}},  // Sign extend from bit 15
                              mem[addr+1],           // High byte (addr+1)
                              mem[addr]};            // Low byte  (addr)
            end

            3'b010: begin
                // LW: Load Word (32-bit)
                // Read 4 bytes, little-endian order
                // mem[addr]   = bits [7:0]   (least significant)
                // mem[addr+1] = bits [15:8]
                // mem[addr+2] = bits [23:16]
                // mem[addr+3] = bits [31:24] (most significant)
                read_data = {mem[addr+3],           // bits [31:24]
                             mem[addr+2],            // bits [23:16]
                             mem[addr+1],            // bits [15:8]
                             mem[addr]};             // bits [7:0]
            end

            3'b100: begin
                // LBU: Load Byte Unsigned
                // Read 1 byte from mem[addr]
                // Zero extend (fill upper 24 bits with 0)
                read_data = {24'b0,                 // Zero extend upper 24 bits
                              mem[addr]};            // 1 byte at addr
            end

            3'b101: begin
                // LHU: Load Halfword Unsigned
                // Read 2 bytes, little-endian
                // Zero extend (fill upper 16 bits with 0)
                read_data = {16'b0,                 // Zero extend upper 16 bits
                              mem[addr+1],           // High byte (addr+1)
                              mem[addr]};            // Low byte  (addr)
            end

            default: begin
                // Default: output 0 for undefined func3
                read_data = 32'b0;
            end

        endcase

    end

    // --------------------------------------------------------
    // SYNCHRONOUS WRITE
    // Writes happen on rising clock edge only
    // mem_write must be 1 for any write to occur
    // func3 selects how many bytes to write
    // --------------------------------------------------------

    always @(posedge clk) begin

        if (mem_write == 1'b1) begin    // Only write if write enable is high

            case (func3)

                3'b000: begin
                    // SB: Store Byte
                    // Write only the lowest byte of write_data
                    // into mem[addr]
                    mem[addr] <= write_data[7:0];   // Store 1 byte
                end

                3'b001: begin
                    // SH: Store Halfword
                    // Write lower 2 bytes of write_data
                    // Little-endian: low byte to lower address
                    mem[addr]   <= write_data[7:0];  // Low byte  ? addr
                    mem[addr+1] <= write_data[15:8]; // High byte ? addr+1
                end

                3'b010: begin
                    // SW: Store Word
                    // Write all 4 bytes of write_data
                    // Little-endian: least significant byte first
                    mem[addr]   <= write_data[7:0];   // bits [7:0]   ? addr
                    mem[addr+1] <= write_data[15:8];  // bits [15:8]  ? addr+1
                    mem[addr+2] <= write_data[23:16]; // bits [23:16] ? addr+2
                    mem[addr+3] <= write_data[31:24]; // bits [31:24] ? addr+3
                end

                // No default needed for writes
                // Undefined func3 simply does nothing

            endcase

        end

    end

endmodule
