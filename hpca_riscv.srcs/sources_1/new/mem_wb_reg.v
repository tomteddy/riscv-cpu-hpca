// ============================================================
// Module : mem_wb_reg
// Project : RISC-V 5-Stage Pipelined CPU
// Description : MEM/WB pipeline register.
//               Latches memory read data, ALU result, PC+4,
//               and control signals for the writeback stage.
// ============================================================

`timescale 1ns / 1ps

module mem_wb_reg (
    input         clk,
    input         reset,

    // ----- Control from MEM -----
    input         mem_reg_write,
    input  [1:0]  mem_wb_sel,

    // ----- Data from MEM -----
    input  [31:0] mem_alu_result,
    input  [31:0] mem_read_data,
    input  [31:0] mem_pc_plus4,
    input  [4:0]  mem_rd,

    // ----- Control to WB -----
    output reg        wb_reg_write,
    output reg [1:0]  wb_wb_sel,

    // ----- Data to WB -----
    output reg [31:0] wb_alu_result,
    output reg [31:0] wb_read_data,
    output reg [31:0] wb_pc_plus4,
    output reg [4:0]  wb_rd
);

    always @(posedge clk) begin
        if (reset) begin
            wb_reg_write  <= 1'b0;
            wb_wb_sel     <= 2'b0;
            wb_alu_result <= 32'b0;
            wb_read_data  <= 32'b0;
            wb_pc_plus4   <= 32'b0;
            wb_rd         <= 5'b0;
        end else begin
            wb_reg_write  <= mem_reg_write;
            wb_wb_sel     <= mem_wb_sel;
            wb_alu_result <= mem_alu_result;
            wb_read_data  <= mem_read_data;
            wb_pc_plus4   <= mem_pc_plus4;
            wb_rd         <= mem_rd;
        end
    end

endmodule
