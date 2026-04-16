// ============================================================
// Module : ex_mem_reg
// Project : RISC-V 5-Stage Pipelined CPU
// Description : EX/MEM pipeline register.
//               Latches ALU result, store data (forwarded),
//               and control signals needed by MEM and WB stages.
//               No flush input — branches resolve in EX, so
//               only IF/ID and ID/EX need flushing.
// ============================================================

`timescale 1ns / 1ps

module ex_mem_reg (
    input         clk,
    input         reset,

    // ----- Control from EX -----
    input         ex_reg_write,
    input         ex_mem_write,
    input  [1:0]  ex_wb_sel,
    input  [2:0]  ex_funct3,     // for LB/LH/LW/SB/SH/SW in data_memory

    // ----- Data from EX -----
    input  [31:0] ex_alu_result,
    input  [31:0] ex_rs2_data_fwd,  // forwarded rs2 for stores
    input  [31:0] ex_pc_plus4,
    input  [4:0]  ex_rd,

    // ----- Control to MEM -----
    output reg        mem_reg_write,
    output reg        mem_mem_write,
    output reg [1:0]  mem_wb_sel,
    output reg [2:0]  mem_funct3,

    // ----- Data to MEM -----
    output reg [31:0] mem_alu_result,
    output reg [31:0] mem_rs2_data,
    output reg [31:0] mem_pc_plus4,
    output reg [4:0]  mem_rd
);

    always @(posedge clk) begin
        if (reset) begin
            mem_reg_write  <= 1'b0;
            mem_mem_write  <= 1'b0;
            mem_wb_sel     <= 2'b0;
            mem_funct3     <= 3'b0;
            mem_alu_result <= 32'b0;
            mem_rs2_data   <= 32'b0;
            mem_pc_plus4   <= 32'b0;
            mem_rd         <= 5'b0;
        end else begin
            mem_reg_write  <= ex_reg_write;
            mem_mem_write  <= ex_mem_write;
            mem_wb_sel     <= ex_wb_sel;
            mem_funct3     <= ex_funct3;
            mem_alu_result <= ex_alu_result;
            mem_rs2_data   <= ex_rs2_data_fwd;
            mem_pc_plus4   <= ex_pc_plus4;
            mem_rd         <= ex_rd;
        end
    end

endmodule
