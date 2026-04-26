`timescale 1ns / 1ps
// ============================================================
// data_memory : 16KB byte-addressable RAM, little-endian
//   Combinational reads, synchronous writes.
//   Synthesizable on Xilinx FPGAs (Zynq Z-7020 etc.)
//
//   Implementation: 4 parallel byte-banks indexed by word address.
//   This is the canonical FPGA-friendly pattern that Vivado can
//   recognize and infer as distributed RAM.
//
//   Assumes naturally-aligned accesses (RV32I + GCC always aligned):
//     - LW/SW : addr[1:0] = 00
//     - LH/SH : addr[0]   = 0
//     - LB/SB : any byte
//
//   func3 encoding:
//     000=LB/SB  001=LH/SH  010=LW/SW  100=LBU  101=LHU
//
//   $readmemh compatibility: testbench can preserve byte-stream
//   loading by initializing through a flat byte view (see initial block).
// ============================================================

module data_memory (
    input             clk,
    input             mem_write,
    input      [31:0] addr,
    input      [31:0] write_data,
    input      [2:0]  func3,
    output reg [31:0] read_data
);

    parameter MEM_BYTES = 16384;
    localparam NWORDS   = MEM_BYTES / 4;       // 4096 words
    localparam WAW      = 12;                  // log2(NWORDS)

    // 4 parallel byte banks, indexed by word address
    (* ram_style = "distributed" *) reg [7:0] mem0 [0:NWORDS-1];  // byte 0 (LSB)
    (* ram_style = "distributed" *) reg [7:0] mem1 [0:NWORDS-1];  // byte 1
    (* ram_style = "distributed" *) reg [7:0] mem2 [0:NWORDS-1];  // byte 2
    (* ram_style = "distributed" *) reg [7:0] mem3 [0:NWORDS-1];  // byte 3

    wire [WAW-1:0] wa  = addr[WAW+1:2];        // word address
    wire [1:0]     bsel = addr[1:0];           // byte-in-word select

    // Load each bank's selected word
    wire [7:0] b0 = mem0[wa];
    wire [7:0] b1 = mem1[wa];
    wire [7:0] b2 = mem2[wa];
    wire [7:0] b3 = mem3[wa];
    wire [31:0] word = {b3, b2, b1, b0};

    // Byte selection for LB/LBU
    reg [7:0] sel_byte;
    always @(*) begin
        case (bsel)
            2'b00: sel_byte = b0;
            2'b01: sel_byte = b1;
            2'b10: sel_byte = b2;
            2'b11: sel_byte = b3;
        endcase
    end

    // Half-word selection for LH/LHU (assumes aligned: bsel = 00 or 10)
    wire [15:0] sel_half = bsel[1] ? {b3, b2} : {b1, b0};

    integer i;
    initial begin
        for (i = 0; i < NWORDS; i = i + 1) begin
            mem0[i] = 8'b0;
            mem1[i] = 8'b0;
            mem2[i] = 8'b0;
            mem3[i] = 8'b0;
        end
    end

    // ---- Combinational read ----
    always @(*) begin
        case (func3)
            3'b000: read_data = {{24{sel_byte[7]}}, sel_byte};       // LB
            3'b001: read_data = {{16{sel_half[15]}}, sel_half};      // LH
            3'b010: read_data = word;                                // LW
            3'b100: read_data = {24'b0, sel_byte};                   // LBU
            3'b101: read_data = {16'b0, sel_half};                   // LHU
            default: read_data = 32'b0;
        endcase
    end

    // ---- Synchronous write ----
    always @(posedge clk) begin
        if (mem_write) begin
            case (func3)
                3'b000: begin                                        // SB
                    case (bsel)
                        2'b00: mem0[wa] <= write_data[7:0];
                        2'b01: mem1[wa] <= write_data[7:0];
                        2'b10: mem2[wa] <= write_data[7:0];
                        2'b11: mem3[wa] <= write_data[7:0];
                    endcase
                end
                3'b001: begin                                        // SH (aligned)
                    if (bsel[1] == 1'b0) begin
                        mem0[wa] <= write_data[7:0];
                        mem1[wa] <= write_data[15:8];
                    end else begin
                        mem2[wa] <= write_data[7:0];
                        mem3[wa] <= write_data[15:8];
                    end
                end
                3'b010: begin                                        // SW
                    mem0[wa] <= write_data[7:0];
                    mem1[wa] <= write_data[15:8];
                    mem2[wa] <= write_data[23:16];
                    mem3[wa] <= write_data[31:24];
                end
            endcase
        end
    end

endmodule
