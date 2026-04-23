// ============================================================
// Module : cpu_top_mext
// Project : RV32I Pipelined CPU — Phase 3 (M extension + ML)
// Description : Extends Phase 2 (BTB) with:
//                 - MUL  (R-type opcode 0110011, funct7=0000001, funct3=000)
//                 - MAC  (custom-0 opcode 0001011, funct3=000)
//                 - RELU (custom-0 opcode 0001011, funct3=001)
//
//   All three use a single-cycle mul_unit in the EX stage.
//   The result mux selects mul_unit output vs ALU output based
//   on ex_op (decoded in ID, propagated inline through ID/EX).
//
//   ex_op encoding:
//     00 = use ALU result
//     01 = MUL   (result = rs1*rs2)
//     10 = MAC   (result = rs1 + rs1*rs2 → rd)
//     11 = RELU  (result = max(rs1, 0))
//
//   Forwarding, hazards, BTB: all unchanged — the existing
//   forwarding unit handles MUL/MAC/RELU rd writes naturally
//   because it keys off mem_rd/wb_rd regardless of op type.
//
//   Reuses Phase 0/1/2 modules; control_unit was extended
//   to recognize opcode 0001011.
// ============================================================

`timescale 1ns / 1ps

module cpu_top_mext (
    input clk,
    input reset
);

    // ================================================================
    //  Hazard / forwarding control
    // ================================================================
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

    wire        if_btb_predict_taken;
    wire [31:0] if_btb_predict_target;

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
    //  IF/ID REGISTER
    // ================================================================
    wire [31:0] id_pc, id_instr;

    if_id_reg if_id (
        .clk(clk), .reset(reset),
        .stall(stall), .flush(flush_if_id),
        .if_pc(if_pc_out), .if_instr(if_instr),
        .id_pc(id_pc), .id_instr(id_instr)
    );

    // Inline register: propagate BTB prediction IF -> ID
    reg id_predicted_taken;
    always @(posedge clk) begin
        if (reset || flush_if_id)      id_predicted_taken <= 1'b0;
        else if (!stall)               id_predicted_taken <= if_btb_predict_taken;
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

    // ---- Phase 3: decode ex_op for MUL / MAC / RELU ----
    wire id_is_mul  = (id_opcode == 7'b0110011) && (id_funct7 == 7'b0000001) && (id_funct3 == 3'b000);
    wire id_is_mac  = (id_opcode == 7'b0001011) && (id_funct3 == 3'b000);
    wire id_is_relu = (id_opcode == 7'b0001011) && (id_funct3 == 3'b001);

    wire [1:0] id_ex_op =
        id_is_mul  ? 2'b01 :
        id_is_mac  ? 2'b10 :
        id_is_relu ? 2'b11 :
                     2'b00;

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

    assign id_rs1_data = (wb_reg_write && wb_rd != 5'd0 && wb_rd == id_rs1) ? wb_data : id_rs1_data_raw;
    assign id_rs2_data = (wb_reg_write && wb_rd != 5'd0 && wb_rd == id_rs2) ? wb_data : id_rs2_data_raw;

    // ================================================================
    //  ID/EX REGISTER
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

    // Inline registers: propagate predicted_taken and ex_op through ID -> EX
    reg       ex_predicted_taken;
    reg [1:0] ex_op;
    always @(posedge clk) begin
        if (reset || flush_id_ex) begin
            ex_predicted_taken <= 1'b0;
            ex_op              <= 2'b00;
        end else begin
            ex_predicted_taken <= id_predicted_taken;
            ex_op              <= id_ex_op;
        end
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

    // ---- Phase 3: mul_unit (single-cycle, combinational) ----
    wire [31:0] ex_mul_result;
    mul_unit mul (
        .a      (ex_rs1_fwd),
        .b      (ex_rs2_fwd),
        .c      (ex_rs1_fwd),         // Phase 3: MAC c-input = rs1 (preserves old rd = rs1 + rs1*rs2 semantics)
        .ex_op  (ex_op),
        .result (ex_mul_result)
    );

    // ---- Result mux: mul_unit overrides ALU when ex_op != 00 ----
    wire [31:0] ex_result_final = (ex_op == 2'b00) ? ex_alu_result : ex_mul_result;

    // ---- Branch unit (uses ALU result, not muxed result) ----
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

    wire branch_mispredict = ex_branch && (branch_taken != ex_predicted_taken);
    wire btb_update_en     = ex_branch;
    wire control_redirect  = branch_mispredict || ex_jump;

    wire [31:0] ex_correct_pc =
        (ex_jump && ex_opcode == 7'b1100111) ? ex_jalr_target   :
        (ex_jump && ex_opcode == 7'b1101111) ? ex_branch_target :
        branch_taken                         ? ex_branch_target :
                                               if_pc_plus4;

    assign pc_next =
        control_redirect      ? ex_correct_pc         :
        if_btb_predict_taken  ? if_btb_predict_target :
                                if_pc_plus4;

    // ---- BTB instance (placed after EX wires exist) ----
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

    // ================================================================
    //  EX/MEM REGISTER — receives the muxed result as alu_result
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
        .ex_alu_result(ex_result_final),     // <-- muxed (ALU or mul_unit)
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
    //  MEM/WB REGISTER
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
    //  FORWARDING + HAZARD — unchanged from Phase 2
    // ================================================================
    forwarding_unit fwd (
        .ex_rs1(ex_rs1), .ex_rs2(ex_rs2),
        .mem_rd(mem_rd), .mem_reg_write(mem_reg_write),
        .wb_rd(wb_rd),   .wb_reg_write(wb_reg_write),
        .forward_a(forward_a), .forward_b(forward_b)
    );

    hazard_unit hzd (
        .id_rs1(id_rs1), .id_rs2(id_rs2),
        .ex_rd(ex_rd), .ex_wb_sel(ex_wb_sel),
        .branch_taken(branch_mispredict),   // Phase 2 semantic: flush on mispredict only
        .ex_jump(ex_jump),
        .stall(stall),
        .flush_if_id(flush_if_id),
        .flush_id_ex(flush_id_ex)
    );

endmodule
