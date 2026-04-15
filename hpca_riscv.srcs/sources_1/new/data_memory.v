`timescale 1ns / 1ps
// ============================================================
// data_memory : 16KB byte-addressable RAM, little-endian
//   Combinational reads, synchronous writes.
//   func3 encoding:
//     000=LB/SB  001=LH/SH  010=LW/SW  100=LBU  101=LHU
// ============================================================

module data_memory (
    input             clk,
    input             mem_write,
    input      [31:0] addr,
    input      [31:0] write_data,
    input      [2:0]  func3,
    output reg [31:0] read_data
);

    parameter MEM_BYTES = 16384;        // 16 KB
    localparam AW       = 14;           // log2(16384)

    reg [7:0] mem [0:MEM_BYTES-1];

    // Mask to physical memory width — prevents out-of-range access
    wire [AW-1:0] a  = addr[AW-1:0];
    wire [AW-1:0] a1 = a + 14'd1;
    wire [AW-1:0] a2 = a + 14'd2;
    wire [AW-1:0] a3 = a + 14'd3;

    integer i;
    initial begin
        for (i = 0; i < MEM_BYTES; i = i + 1) mem[i] = 8'b0;
    end

    // ---- Combinational read ----
    always @(*) begin
        case (func3)
            3'b000: read_data = {{24{mem[a][7]}},  mem[a]};                     // LB
            3'b001: read_data = {{16{mem[a1][7]}}, mem[a1], mem[a]};            // LH
            3'b010: read_data = {mem[a3], mem[a2], mem[a1], mem[a]};            // LW
            3'b100: read_data = {24'b0, mem[a]};                                 // LBU
            3'b101: read_data = {16'b0, mem[a1], mem[a]};                        // LHU
            default: read_data = 32'b0;
        endcase
    end

    // ---- Synchronous write ----
    always @(posedge clk) begin
        if (mem_write) begin
            case (func3)
                3'b000: begin                                                    // SB
                    mem[a] <= write_data[7:0];
                end
                3'b001: begin                                                    // SH
                    mem[a]  <= write_data[7:0];
                    mem[a1] <= write_data[15:8];
                end
                3'b010: begin                                                    // SW
                    mem[a]  <= write_data[7:0];
                    mem[a1] <= write_data[15:8];
                    mem[a2] <= write_data[23:16];
                    mem[a3] <= write_data[31:24];
                end
            endcase
        end
    end

endmodule
