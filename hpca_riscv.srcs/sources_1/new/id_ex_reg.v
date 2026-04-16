// ============================================================
// Module : id_ex_reg
// Project : RISC-V 5-Stage Pipelined CPU
// Description : ID/EX pipeline register.
//               Latches all decoded control signals, register
//               data, immediate, PC, and register addresses.
//               Flush inserts a NOP (zeros all control signals)
//               for load-use stalls and branch/jump flushes.
// ============================================================

`timescale 1ns / 1ps

module id_ex_reg (
    input         clk,
    input         reset,
    input         flush,        // 1 = insert bubble (load-use stall or branch flush)

    // ----- Control signals from ID -----
    input         id_reg_write,
    input         id_mem_write,
    input         id_alu_src,
    input  [1:0]  id_alu_a_sel,
    input  [1:0]  id_wb_sel,
    input         id_branch,
    input         id_jump,
    input  [1:0]  id_alu_op,

    // ----- Data from ID -----
    input  [31:0] id_pc,
    input  [31:0] id_rs1_data,
    input  [31:0] id_rs2_data,
    input  [31:0] id_imm,
    input  [2:0]  id_funct3,
    input  [6:0]  id_funct7,
    input  [4:0]  id_rd,
    input  [4:0]  id_rs1,
    input  [4:0]  id_rs2,
    input  [6:0]  id_opcode,

    // ----- Control signals to EX -----
    output reg        ex_reg_write,
    output reg        ex_mem_write,
    output reg        ex_alu_src,
    output reg [1:0]  ex_alu_a_sel,
    output reg [1:0]  ex_wb_sel,
    output reg        ex_branch,
    output reg        ex_jump,
    output reg [1:0]  ex_alu_op,

    // ----- Data to EX -----
    output reg [31:0] ex_pc,
    output reg [31:0] ex_rs1_data,
    output reg [31:0] ex_rs2_data,
    output reg [31:0] ex_imm,
    output reg [2:0]  ex_funct3,
    output reg [6:0]  ex_funct7,
    output reg [4:0]  ex_rd,
    output reg [4:0]  ex_rs1,
    output reg [4:0]  ex_rs2,
    output reg [6:0]  ex_opcode
);

    always @(posedge clk) begin
        if (reset || flush) begin
            // Zero all control signals — no side effects
            ex_reg_write <= 1'b0;
            ex_mem_write <= 1'b0;
            ex_alu_src   <= 1'b0;
            ex_alu_a_sel <= 2'b0;
            ex_wb_sel    <= 2'b0;
            ex_branch    <= 1'b0;
            ex_jump      <= 1'b0;
            ex_alu_op    <= 2'b0;
            // Zero data fields
            ex_pc        <= 32'b0;
            ex_rs1_data  <= 32'b0;
            ex_rs2_data  <= 32'b0;
            ex_imm       <= 32'b0;
            ex_funct3    <= 3'b0;
            ex_funct7    <= 7'b0;
            ex_rd        <= 5'b0;
            ex_rs1       <= 5'b0;
            ex_rs2       <= 5'b0;
            ex_opcode    <= 7'b0;
        end else begin
            ex_reg_write <= id_reg_write;
            ex_mem_write <= id_mem_write;
            ex_alu_src   <= id_alu_src;
            ex_alu_a_sel <= id_alu_a_sel;
            ex_wb_sel    <= id_wb_sel;
            ex_branch    <= id_branch;
            ex_jump      <= id_jump;
            ex_alu_op    <= id_alu_op;
            ex_pc        <= id_pc;
            ex_rs1_data  <= id_rs1_data;
            ex_rs2_data  <= id_rs2_data;
            ex_imm       <= id_imm;
            ex_funct3    <= id_funct3;
            ex_funct7    <= id_funct7;
            ex_rd        <= id_rd;
            ex_rs1       <= id_rs1;
            ex_rs2       <= id_rs2;
            ex_opcode    <= id_opcode;
        end
    end

endmodule
