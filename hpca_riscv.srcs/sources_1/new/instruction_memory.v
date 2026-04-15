`timescale 1ns / 1ps
// ============================================================
// instruction_memory : 16 KB byte-addressable ROM.
//   Initialized from "instructions.hex" (Verilog @-addressed
//   byte format, e.g. produced by `objcopy -O verilog`).
//   Combinational word read: little-endian assembly of 4 bytes.
// ============================================================

module instruction_memory (
    input  [31:0] pc,
    output [31:0] instr
);

    parameter MEM_BYTES = 16384;        // 16 KB
    localparam AW       = 14;

    reg [7:0] mem [0:MEM_BYTES-1];

    initial begin
        $readmemh("instructions.hex", mem);
    end

    wire [AW-1:0] a  = pc[AW-1:0];
    assign instr = {mem[a+3], mem[a+2], mem[a+1], mem[a]};

endmodule
