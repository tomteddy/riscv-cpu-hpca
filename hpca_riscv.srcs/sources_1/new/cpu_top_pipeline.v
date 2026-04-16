// ============================================================
// Module : cpu_top_pipeline
// Project : RISC-V 5-Stage Pipelined CPU
// Description : Pipelined RV32I top-level.
//               5 stages: IF / ID / EX / MEM / WB
//               Features:
//               - Data forwarding (EX->EX, MEM->EX, WB->ID)
//               - Load-use stall (1-cycle bubble)
//               - Branch/jump flush (2-cycle penalty, resolve in EX)
//               - Always predict not-taken
//
//               Reuses all Phase 0 modules unchanged:
//               pc, instruction_memory, control_unit, alu_control,
//               immediate_gen, register_file, alu, branch_unit,
//               data_memory, writeback
// ============================================================

`timescale 1ns / 1ps

module cpu_top_pipeline (
    input clk,
    input reset
);

    // ================================================================
    //  WIRES — organized by pipeline stage
    // ================================================================

    // ---- Hazard / forwarding control ----
    wire        stall;
    wire        flush_if_id, flush_id_ex;
    wire [1:0]  forward_a, forward_b;

    // ================================================================
    //  IF STAGE
    // ================================================================

    wire [31:0] if_pc_out;       // current PC
    wire [31:0] if_pc_plus4;     // PC + 4
    wire [31:0] if_instr;        // instruction from IMEM
    wire [31:0] pc_next;         // next PC value (computed in EX)
    wire [31:0] pc_next_final;   // after stall gating

    assign if_pc_plus4 = if_pc_out + 32'd4;

    // PC stall: feed pc_out back when stalling (avoids modifying pc.v)
    assign pc_next_final = stall ? if_pc_out : pc_next;

    pc pc_reg (
        .clk(clk), .reset(reset),
        .pc_next(pc_next_final),
        .pc_out(if_pc_out)
    );

    instruction_memory imem (
        .pc(if_pc_out),
        .instr(if_instr)
    );

    // ================================================================
    //  IF/ID PIPELINE REGISTER
    // ================================================================

    wire [31:0] id_pc, id_instr;

    if_id_reg if_id (
        .clk(clk), .reset(reset),
        .stall(stall),
        .flush(flush_if_id),
        .if_pc(if_pc_out),
        .if_instr(if_instr),
        .id_pc(id_pc),
        .id_instr(id_instr)
    );

    // ================================================================
    //  ID STAGE
    // ================================================================

    // ---- Instruction field extraction ----
    wire [6:0] id_opcode = id_instr[6:0];
    wire [4:0] id_rd     = id_instr[11:7];
    wire [2:0] id_funct3 = id_instr[14:12];
    wire [4:0] id_rs1    = id_instr[19:15];
    wire [4:0] id_rs2    = id_instr[24:20];
    wire [6:0] id_funct7 = id_instr[31:25];

    // ---- Control unit ----
    wire       id_reg_write, id_mem_write, id_alu_src, id_branch, id_jump;
    wire [1:0] id_alu_a_sel, id_wb_sel, id_alu_op;
    wire [2:0] id_imm_sel;

    control_unit ctrl (
        .opcode(id_opcode),
        .reg_write(id_reg_write), .mem_write(id_mem_write),
        .alu_src(id_alu_src), .alu_a_sel(id_alu_a_sel), .wb_sel(id_wb_sel),
        .branch(id_branch), .jump(id_jump),
        .imm_sel(id_imm_sel), .alu_op(id_alu_op)
    );

    // ---- Immediate generator ----
    wire [31:0] id_imm;

    immediate_gen imm_gen (
        .instruction(id_instr),
        .imm_sel(id_imm_sel),
        .imm_out(id_imm)
    );

    // ---- Register file ----
    // Write port driven by WB stage; read ports used by ID stage
    wire [31:0] id_rs1_data_raw, id_rs2_data_raw;  // raw regfile reads
    wire [31:0] id_rs1_data, id_rs2_data;           // after WB->ID forwarding

    // WB stage signals (declared here for register file write port)
    wire        wb_reg_write;
    wire [4:0]  wb_rd;
    wire [31:0] wb_data;

    register_file reg_file (
        .clk(clk),
        .reg_write(wb_reg_write),
        .rs1(id_rs1), .rs2(id_rs2),
        .rd(wb_rd),
        .write_data(wb_data),
        .read_data1(id_rs1_data_raw),
        .read_data2(id_rs2_data_raw)
    );

    // ---- WB->ID forwarding (same-cycle write-read bypass) ----
    // Register file writes on posedge, reads combinationally.
    // If WB writes the same register ID reads, the read gets the OLD value.
    // This explicit bypass fixes that.
    assign id_rs1_data = (wb_reg_write && wb_rd != 5'd0 && wb_rd == id_rs1)
                         ? wb_data : id_rs1_data_raw;
    assign id_rs2_data = (wb_reg_write && wb_rd != 5'd0 && wb_rd == id_rs2)
                         ? wb_data : id_rs2_data_raw;

    // ================================================================
    //  ID/EX PIPELINE REGISTER
    // ================================================================

    wire        ex_reg_write, ex_mem_write, ex_alu_src, ex_branch, ex_jump;
    wire [1:0]  ex_alu_a_sel, ex_wb_sel, ex_alu_op;
    wire [31:0] ex_pc, ex_rs1_data, ex_rs2_data, ex_imm;
    wire [2:0]  ex_funct3;
    wire [6:0]  ex_funct7, ex_opcode;
    wire [4:0]  ex_rd, ex_rs1, ex_rs2;

    id_ex_reg id_ex (
        .clk(clk), .reset(reset),
        .flush(flush_id_ex),
        // Control
        .id_reg_write(id_reg_write), .id_mem_write(id_mem_write),
        .id_alu_src(id_alu_src), .id_alu_a_sel(id_alu_a_sel),
        .id_wb_sel(id_wb_sel), .id_branch(id_branch), .id_jump(id_jump),
        .id_alu_op(id_alu_op),
        // Data
        .id_pc(id_pc),
        .id_rs1_data(id_rs1_data), .id_rs2_data(id_rs2_data),
        .id_imm(id_imm),
        .id_funct3(id_funct3), .id_funct7(id_funct7),
        .id_rd(id_rd), .id_rs1(id_rs1), .id_rs2(id_rs2),
        .id_opcode(id_opcode),
        // Outputs
        .ex_reg_write(ex_reg_write), .ex_mem_write(ex_mem_write),
        .ex_alu_src(ex_alu_src), .ex_alu_a_sel(ex_alu_a_sel),
        .ex_wb_sel(ex_wb_sel), .ex_branch(ex_branch), .ex_jump(ex_jump),
        .ex_alu_op(ex_alu_op),
        .ex_pc(ex_pc),
        .ex_rs1_data(ex_rs1_data), .ex_rs2_data(ex_rs2_data),
        .ex_imm(ex_imm),
        .ex_funct3(ex_funct3), .ex_funct7(ex_funct7),
        .ex_rd(ex_rd), .ex_rs1(ex_rs1), .ex_rs2(ex_rs2),
        .ex_opcode(ex_opcode)
    );

    // ================================================================
    //  EX STAGE
    // ================================================================

    // ---- Forwarding muxes ----
    // MEM-stage signals (from EX/MEM register, declared ahead for forwarding)
    wire [31:0] mem_alu_result;
    wire [4:0]  mem_rd;
    wire        mem_reg_write;

    // Forwarded rs1 value
    wire [31:0] ex_rs1_fwd =
        (forward_a == 2'b01) ? mem_alu_result :  // EX-to-EX (from EX/MEM)
        (forward_a == 2'b10) ? wb_data        :  // MEM-to-EX (from WB mux)
                               ex_rs1_data;       // no forwarding

    // Forwarded rs2 value
    wire [31:0] ex_rs2_fwd =
        (forward_b == 2'b01) ? mem_alu_result :
        (forward_b == 2'b10) ? wb_data        :
                               ex_rs2_data;

    // ---- ALU operand A mux (uses forwarded rs1) ----
    wire [31:0] ex_alu_a =
        (ex_alu_a_sel == 2'b01) ? ex_pc      :  // AUIPC
        (ex_alu_a_sel == 2'b10) ? 32'b0      :  // LUI
                                   ex_rs1_fwd;   // default: forwarded rs1

    // ---- ALU operand B mux (uses forwarded rs2) ----
    wire [31:0] ex_alu_b = ex_alu_src ? ex_imm : ex_rs2_fwd;

    // ---- ALU control ----
    wire [3:0] ex_alu_ctrl;

    alu_control alu_ctrl_unit (
        .alu_op(ex_alu_op),
        .funct3(ex_funct3),
        .funct7(ex_funct7),
        .alu_ctrl(ex_alu_ctrl)
    );

    // ---- ALU ----
    wire [31:0] ex_alu_result;
    wire        ex_zero;

    alu alu_unit (
        .a(ex_alu_a), .b(ex_alu_b),
        .alu_ctrl(ex_alu_ctrl),
        .result(ex_alu_result),
        .zero(ex_zero)
    );

    // ---- Branch unit ----
    wire branch_taken;

    branch_unit br (
        .branch(ex_branch),
        .funct3(ex_funct3),
        .zero(ex_zero),
        .alu_lt(ex_alu_result[0]),
        .branch_taken(branch_taken)
    );

    // ---- Branch / jump target computation ----
    wire [31:0] ex_pc_plus4     = ex_pc + 32'd4;
    wire [31:0] ex_branch_target = ex_pc + ex_imm;
    wire [31:0] ex_jalr_target   = (ex_rs1_fwd + ex_imm) & 32'hFFFFFFFE;

    // ---- Next-PC MUX (priority: JALR > JAL > branch_taken > PC+4) ----
    wire branch_or_jump = branch_taken || ex_jump;

    assign pc_next =
        (ex_jump && ex_opcode == 7'b1100111) ? ex_jalr_target   :  // JALR
        (ex_jump && ex_opcode == 7'b1101111) ? ex_branch_target :  // JAL
        (branch_taken)                       ? ex_branch_target :  // Branch taken
                                               if_pc_plus4;        // PC+4

    // ================================================================
    //  EX/MEM PIPELINE REGISTER
    // ================================================================

    wire        mem_mem_write;
    wire [1:0]  mem_wb_sel;
    wire [2:0]  mem_funct3;
    wire [31:0] mem_rs2_data;
    wire [31:0] mem_pc_plus4;

    ex_mem_reg ex_mem (
        .clk(clk), .reset(reset),
        // Control
        .ex_reg_write(ex_reg_write), .ex_mem_write(ex_mem_write),
        .ex_wb_sel(ex_wb_sel), .ex_funct3(ex_funct3),
        // Data
        .ex_alu_result(ex_alu_result),
        .ex_rs2_data_fwd(ex_rs2_fwd),  // forwarded rs2 for stores
        .ex_pc_plus4(ex_pc_plus4),
        .ex_rd(ex_rd),
        // Outputs
        .mem_reg_write(mem_reg_write), .mem_mem_write(mem_mem_write),
        .mem_wb_sel(mem_wb_sel), .mem_funct3(mem_funct3),
        .mem_alu_result(mem_alu_result),
        .mem_rs2_data(mem_rs2_data),
        .mem_pc_plus4(mem_pc_plus4),
        .mem_rd(mem_rd)
    );

    // ================================================================
    //  MEM STAGE
    // ================================================================

    wire [31:0] mem_read_data;

    data_memory dmem (
        .clk(clk),
        .mem_write(mem_mem_write),
        .addr(mem_alu_result),
        .write_data(mem_rs2_data),
        .func3(mem_funct3),
        .read_data(mem_read_data)
    );

    // ================================================================
    //  MEM/WB PIPELINE REGISTER
    // ================================================================

    wire [1:0]  wb_wb_sel;
    wire [31:0] wb_alu_result, wb_read_data, wb_pc_plus4;

    mem_wb_reg mem_wb (
        .clk(clk), .reset(reset),
        // Control
        .mem_reg_write(mem_reg_write), .mem_wb_sel(mem_wb_sel),
        // Data
        .mem_alu_result(mem_alu_result),
        .mem_read_data(mem_read_data),
        .mem_pc_plus4(mem_pc_plus4),
        .mem_rd(mem_rd),
        // Outputs
        .wb_reg_write(wb_reg_write), .wb_wb_sel(wb_wb_sel),
        .wb_alu_result(wb_alu_result),
        .wb_read_data(wb_read_data),
        .wb_pc_plus4(wb_pc_plus4),
        .wb_rd(wb_rd)
    );

    // ================================================================
    //  WB STAGE
    // ================================================================

    writeback wb_mux (
        .alu_result(wb_alu_result),
        .mem_data(wb_read_data),
        .pc_plus4(wb_pc_plus4),
        .wb_sel(wb_wb_sel),
        .wb_data(wb_data)
    );

    // wb_data, wb_rd, wb_reg_write feed back to:
    //   1. register_file write port (in ID stage)
    //   2. WB->ID forwarding bypass (in ID stage)
    //   3. forwarding_unit MEM-to-EX path (forward_a/b == 10)

    // ================================================================
    //  FORWARDING UNIT
    // ================================================================

    forwarding_unit fwd (
        .ex_rs1(ex_rs1),
        .ex_rs2(ex_rs2),
        .mem_rd(mem_rd),
        .mem_reg_write(mem_reg_write),
        .wb_rd(wb_rd),
        .wb_reg_write(wb_reg_write),
        .forward_a(forward_a),
        .forward_b(forward_b)
    );

    // ================================================================
    //  HAZARD UNIT
    // ================================================================

    hazard_unit hzd (
        .id_rs1(id_rs1),
        .id_rs2(id_rs2),
        .ex_rd(ex_rd),
        .ex_wb_sel(ex_wb_sel),
        .branch_taken(branch_taken),
        .ex_jump(ex_jump),
        .stall(stall),
        .flush_if_id(flush_if_id),
        .flush_id_ex(flush_id_ex)
    );

endmodule
