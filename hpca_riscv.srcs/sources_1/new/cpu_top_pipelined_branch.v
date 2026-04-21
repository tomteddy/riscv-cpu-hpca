// ============================================================
// Module : cpu_top_pipelined_branch
// Project : RISC-V 5-Stage Pipelined CPU — Phase 2
// Description : Extends cpu_top_pipeline with a 16-entry BTB
//               and 2-bit saturating branch predictor in IF.
//
//   Changes vs Phase 1 (cpu_top_pipeline.v):
//   - BTB instantiated in IF stage; predicts taken/target
//   - pc_next uses BTB target when predict_taken, else PC+4
//   - predicted_taken propagated through IF/ID → ID/EX as
//     inline registers (Phase 1 pipeline reg modules unchanged)
//   - Flush only on MISPREDICT (not all taken branches)
//     mispredict = ex_branch && (branch_taken != ex_predicted)
//   - Jumps (JAL/JALR) still flush 2 cycles (EX resolution)
//   - BTB updated in EX on every branch resolution
//
//   Reuses all Phase 0 and Phase 1 modules unchanged:
//   pc, instruction_memory, control_unit, alu_control,
//   immediate_gen, register_file, alu, branch_unit,
//   data_memory, writeback, if_id_reg, id_ex_reg,
//   ex_mem_reg, mem_wb_reg, forwarding_unit, hazard_unit
// ============================================================

`timescale 1ns / 1ps

module cpu_top_pipelined_branch (
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

    wire [31:0] if_pc_out;
    wire [31:0] if_pc_plus4;
    wire [31:0] if_instr;
    wire [31:0] pc_next;
    wire [31:0] pc_next_final;

    assign if_pc_plus4 = if_pc_out + 32'd4;

    // ---- BTB prediction outputs (driven by btb instance below, after EX) ----
    wire        if_btb_predict_taken;
    wire [31:0] if_btb_predict_target;

    // PC stall: freeze when load-use stall
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

    // ---- Propagate prediction bit: IF → ID (inline register) ----
    // Cleared on flush (mispredict/jump) or reset; held on stall.
    reg id_predicted_taken;
    always @(posedge clk) begin
        if (reset || flush_if_id)      id_predicted_taken <= 1'b0;
        else if (!stall)               id_predicted_taken <= if_btb_predict_taken;
        // stall: hold current value
    end

    // ================================================================
    //  ID STAGE
    // ================================================================

    wire [6:0] id_opcode = id_instr[6:0];
    wire [4:0] id_rd     = id_instr[11:7];
    wire [2:0] id_funct3 = id_instr[14:12];
    wire [4:0] id_rs1    = id_instr[19:15];
    wire [4:0] id_rs2    = id_instr[24:20];
    wire [6:0] id_funct7 = id_instr[31:25];

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

    wire [31:0] id_imm;

    immediate_gen imm_gen (
        .instruction(id_instr),
        .imm_sel(id_imm_sel),
        .imm_out(id_imm)
    );

    wire [31:0] id_rs1_data_raw, id_rs2_data_raw;
    wire [31:0] id_rs1_data, id_rs2_data;

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

    // WB->ID forwarding bypass (same-cycle write-read)
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
        .id_reg_write(id_reg_write), .id_mem_write(id_mem_write),
        .id_alu_src(id_alu_src), .id_alu_a_sel(id_alu_a_sel),
        .id_wb_sel(id_wb_sel), .id_branch(id_branch), .id_jump(id_jump),
        .id_alu_op(id_alu_op),
        .id_pc(id_pc),
        .id_rs1_data(id_rs1_data), .id_rs2_data(id_rs2_data),
        .id_imm(id_imm),
        .id_funct3(id_funct3), .id_funct7(id_funct7),
        .id_rd(id_rd), .id_rs1(id_rs1), .id_rs2(id_rs2),
        .id_opcode(id_opcode),
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

    // ---- Propagate prediction bit: ID → EX (inline register) ----
    reg ex_predicted_taken;
    always @(posedge clk) begin
        if (reset || flush_id_ex) ex_predicted_taken <= 1'b0;
        else                      ex_predicted_taken <= id_predicted_taken;
    end

    // ================================================================
    //  EX STAGE
    // ================================================================

    wire [31:0] mem_alu_result;
    wire [4:0]  mem_rd;
    wire        mem_reg_write;

    wire [31:0] ex_rs1_fwd =
        (forward_a == 2'b01) ? mem_alu_result :
        (forward_a == 2'b10) ? wb_data        :
                               ex_rs1_data;

    wire [31:0] ex_rs2_fwd =
        (forward_b == 2'b01) ? mem_alu_result :
        (forward_b == 2'b10) ? wb_data        :
                               ex_rs2_data;

    wire [31:0] ex_alu_a =
        (ex_alu_a_sel == 2'b01) ? ex_pc   :
        (ex_alu_a_sel == 2'b10) ? 32'b0   :
                                   ex_rs1_fwd;

    wire [31:0] ex_alu_b = ex_alu_src ? ex_imm : ex_rs2_fwd;

    wire [3:0] ex_alu_ctrl;

    alu_control alu_ctrl_unit (
        .alu_op(ex_alu_op),
        .funct3(ex_funct3),
        .funct7(ex_funct7),
        .alu_ctrl(ex_alu_ctrl)
    );

    wire [31:0] ex_alu_result;
    wire        ex_zero;

    alu alu_unit (
        .a(ex_alu_a), .b(ex_alu_b),
        .alu_ctrl(ex_alu_ctrl),
        .result(ex_alu_result),
        .zero(ex_zero)
    );

    wire branch_taken;

    branch_unit br (
        .branch(ex_branch),
        .funct3(ex_funct3),
        .zero(ex_zero),
        .alu_lt(ex_alu_result[0]),
        .branch_taken(branch_taken)
    );

    wire [31:0] ex_pc_plus4      = ex_pc + 32'd4;
    wire [31:0] ex_branch_target = ex_pc + ex_imm;
    wire [31:0] ex_jalr_target   = (ex_rs1_fwd + ex_imm) & 32'hFFFFFFFE;

    // ---- Branch mispredict detection ----
    // A mispredict occurs when the branch outcome differs from the IF-stage prediction.
    wire branch_mispredict = ex_branch && (branch_taken != ex_predicted_taken);

    // ---- BTB update: fired on every branch resolution ----
    wire btb_update_en = ex_branch;

    // ---- BTB instance (placed here so all EX wires are in scope) ----
    btb #(.ENTRIES(16)) branch_predictor (
        .clk            (clk),
        .reset          (reset),
        .lookup_pc      (if_pc_out),
        .predict_taken  (if_btb_predict_taken),
        .predict_target (if_btb_predict_target),
        .update_en      (btb_update_en),
        .update_pc      (ex_pc),
        .update_taken   (branch_taken),
        .update_target  (ex_branch_target)
    );

    // ---- PC redirect from EX (overrides BTB prediction) ----
    // Fires on mispredict or any jump (jumps not predicted by BTB).
    wire control_redirect = branch_mispredict || ex_jump;

    // EX-computed correct PC (used on redirect)
    wire [31:0] ex_correct_pc =
        (ex_jump && ex_opcode == 7'b1100111) ? ex_jalr_target   :  // JALR
        (ex_jump && ex_opcode == 7'b1101111) ? ex_branch_target :  // JAL
        branch_taken                         ? ex_branch_target :  // branch taken (was mispredicted)
                                               if_pc_plus4;        // branch not-taken (was mispredicted)

    // ---- Next-PC MUX ----
    // Priority: EX redirect > BTB prediction > PC+4
    assign pc_next =
        control_redirect      ? ex_correct_pc        :  // EX overrides
        if_btb_predict_taken  ? if_btb_predict_target :  // BTB predicts taken
                                if_pc_plus4;             // fall-through (predict not-taken)

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
        .ex_reg_write(ex_reg_write), .ex_mem_write(ex_mem_write),
        .ex_wb_sel(ex_wb_sel), .ex_funct3(ex_funct3),
        .ex_alu_result(ex_alu_result),
        .ex_rs2_data_fwd(ex_rs2_fwd),
        .ex_pc_plus4(ex_pc_plus4),
        .ex_rd(ex_rd),
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
        .mem_reg_write(mem_reg_write), .mem_wb_sel(mem_wb_sel),
        .mem_alu_result(mem_alu_result),
        .mem_read_data(mem_read_data),
        .mem_pc_plus4(mem_pc_plus4),
        .mem_rd(mem_rd),
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

    // ================================================================
    //  FORWARDING UNIT  (unchanged from Phase 1)
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
    //  HAZARD UNIT — reused with branch_mispredict replacing branch_taken
    //
    //  In Phase 1: flush on any branch_taken.
    //  In Phase 2: flush only on mispredict (correctly predicted taken
    //              branches need no flush — pipeline has the right instr).
    //  Jumps: still always flush (not BTB-predicted).
    // ================================================================

    hazard_unit hzd (
        .id_rs1(id_rs1),
        .id_rs2(id_rs2),
        .ex_rd(ex_rd),
        .ex_wb_sel(ex_wb_sel),
        .branch_taken(branch_mispredict),   // Phase 2: only flush on mispredict
        .ex_jump(ex_jump),
        .stall(stall),
        .flush_if_id(flush_if_id),
        .flush_id_ex(flush_id_ex)
    );

endmodule
