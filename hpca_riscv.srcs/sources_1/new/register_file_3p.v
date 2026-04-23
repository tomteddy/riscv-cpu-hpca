// ============================================================
// register_file_3p : 32 x 32-bit GPRs with 3 read ports.
//
//   Used only by Phase 4 tops (cpu_top_mext_rdcyc,
//   cpu_top_sc_rdcyc) to support the 3-operand MAC instruction
//   `rd = rd + rs1*rs2` — rs3 is wired to the instruction's rd
//   field so MAC can read its own accumulator. Non-MAC
//   instructions also drive rs3 (harmless dead read).
//
//   Phase 0-3 tops continue using the 2-port `register_file`.
//
//   - 3 combinational read ports, 1 synchronous write port
//   - x0 hardwired to 0 (writes to x0 are ignored)
// ============================================================

`timescale 1ns / 1ps

module register_file_3p (
    input         clk,
    input         reg_write,
    input  [4:0]  rs1,
    input  [4:0]  rs2,
    input  [4:0]  rs3,
    input  [4:0]  rd,
    input  [31:0] write_data,
    output [31:0] read_data1,
    output [31:0] read_data2,
    output [31:0] read_data3
);

    reg [31:0] registers [0:31];

    integer i;
    initial begin
        for (i = 0; i < 32; i = i + 1) registers[i] = 32'b0;
    end

    assign read_data1 = (rs1 == 5'd0) ? 32'b0 : registers[rs1];
    assign read_data2 = (rs2 == 5'd0) ? 32'b0 : registers[rs2];
    assign read_data3 = (rs3 == 5'd0) ? 32'b0 : registers[rs3];

    always @(posedge clk) begin
        if (reg_write && rd != 5'd0)
            registers[rd] <= write_data;
    end

endmodule
