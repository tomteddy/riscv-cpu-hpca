`timescale 1ns / 1ps
// ============================================================
// register_file : 32 x 32-bit GPRs.
//   - 2 combinational read ports, 1 synchronous write port
//   - x0 hardwired to 0 (writes to x0 are ignored)
// ============================================================

module register_file (
    input         clk,
    input         reg_write,
    input  [4:0]  rs1,
    input  [4:0]  rs2,
    input  [4:0]  rd,
    input  [31:0] write_data,
    output [31:0] read_data1,
    output [31:0] read_data2
);

    reg [31:0] registers [0:31];

    integer i;
    initial begin
        for (i = 0; i < 32; i = i + 1) registers[i] = 32'b0;
    end

    assign read_data1 = (rs1 == 5'd0) ? 32'b0 : registers[rs1];
    assign read_data2 = (rs2 == 5'd0) ? 32'b0 : registers[rs2];

    always @(posedge clk) begin
        if (reg_write && rd != 5'd0)
            registers[rd] <= write_data;
    end

endmodule
