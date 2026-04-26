`timescale 1ns / 1ps
// ============================================================
// instruction_memory : 16 KB byte-addressable ROM.
//   Loaded from "instructions.hex" (byte-format $readmemh).
//   Combinational word read, little-endian assembly.
//
//   Implementation: 4 parallel byte-banks indexed by word address
//   (canonical FPGA pattern, synthesizable as distributed RAM).
//   PC is always word-aligned in RV32I, so addr[1:0] = 00 always.
// ============================================================

module instruction_memory (
    input  [31:0] pc,
    output [31:0] instr
);

    parameter MEM_BYTES = 16384;
    localparam NWORDS   = MEM_BYTES / 4;
    localparam WAW      = 12;

    (* ram_style = "distributed" *) reg [7:0] mem0 [0:NWORDS-1];
    (* ram_style = "distributed" *) reg [7:0] mem1 [0:NWORDS-1];
    (* ram_style = "distributed" *) reg [7:0] mem2 [0:NWORDS-1];
    (* ram_style = "distributed" *) reg [7:0] mem3 [0:NWORDS-1];

    // Load via temporary flat byte array, then distribute to banks.
    // This preserves the existing instructions.hex byte format.
    reg [7:0] tmp [0:MEM_BYTES-1];
    integer i;
    initial begin
        for (i = 0; i < MEM_BYTES; i = i + 1) tmp[i] = 8'b0;
        $readmemh("instructions.hex", tmp);
        for (i = 0; i < NWORDS; i = i + 1) begin
            mem0[i] = tmp[4*i + 0];
            mem1[i] = tmp[4*i + 1];
            mem2[i] = tmp[4*i + 2];
            mem3[i] = tmp[4*i + 3];
        end
    end

    wire [WAW-1:0] wa = pc[WAW+1:2];
    assign instr = {mem3[wa], mem2[wa], mem1[wa], mem0[wa]};

endmodule
