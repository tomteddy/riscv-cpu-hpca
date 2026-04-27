// ============================================================
// Module : cpu_top_mext_rdcyc
// Project : RV32I Pipelined CPU — Phase 4 (RDCYC + Benchmarks)
// Description : Extends Phase 3 (cpu_top_mext) with:
//                 - RDCYC (custom-0 opcode 0001011, funct3=010)
//                   Reads a 32-bit free-running cycle counter into rd.
//                 - 32-bit cycle_counter register (increments every
//                   clock after reset; readable from TB via hierarchical
//                   reference uut.cycle_counter).
//
//   ex_op encoding (widened to 3 bits):
//     000 = use ALU result
//     001 = MUL   (result = rs1*rs2)
//     010 = MAC   (result = rd + rs1*rs2)   �? 3-operand (Phase 4)
//     011 = RELU  (result = max(rs1, 0))
//     100 = RDCYC (result = cycle_counter)
//
//   RDCYC decode: opcode=0001011, funct3=010
//   Encoding: 0000000_00000_00000_010_rd_0001011
//   control_unit already sets reg_write=1 for opcode 0001011.
//   EX result mux selects cycle_counter; flows to WB via alu_result.
//
//   All other logic (forwarding, hazards, BTB) unchanged.
// ============================================================

`timescale 1ns / 1ps

module cpu_top_mext_rdcyc #(
    parameter USE_BTB = 1   // 1 = BTB active; 0 = always-not-taken (for benchmark comparison)
) (
    input  wire        clk,
    input  wire        reset,
    output wire [31:0] o_pc,           // current PC (IF stage)
    output wire [31:0] o_cycle_counter, // cycle counter (for RDCYC)
    output wire [31:0] o_wb_data,       // writeback data (keeps pipeline logic alive)
    output wire [31:0] o_instr_retired  // committed instruction count (for CPI)
);

    // ================================================================
    //  32-bit cycle counter — increments every clock after reset
    // ================================================================
    reg [31:0] cycle_counter;
    always @(posedge clk) begin
        if (reset) cycle_counter <= 32'd0;
        else       cycle_counter <= cycle_counter + 32'd1;
    end

    // ================================================================
    //  Hazard / forwarding control
    //  *_raw = from hazard_unit (unchanged Phase 1 module)
    //  plain names = augmented with Phase 4 MAC-rs3 load-use detection
    // ================================================================
    wire        stall_raw, flush_if_id_raw, flush_id_ex_raw;
    wire        rs3_load_use;            // MAC in ID reads rs3 == load in EX's rd
    wire        stall        = stall_raw || rs3_load_use;
    wire        flush_if_id  = flush_if_id_raw;   // no change: don't need to flush IF/ID on rs3 stall
    wire        flush_id_ex  = flush_id_ex_raw || rs3_load_use;
    wire [1:0]  forward_a, forward_b;
    wire [1:0]  forward_c;                  // Phase 4: forward for MAC rs3 input
    reg  [4:0]  ex_rs3_reg;                 // latched rs3 index in EX (for forward_c lookup)

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
    // When USE_BTB=0, always force predict-not-taken (Option-A disable).
    reg id_predicted_taken;
    always @(posedge clk) begin
        if (reset || flush_if_id) id_predicted_taken <= 1'b0;
        else if (!stall)          id_predicted_taken <= USE_BTB ? if_btb_predict_taken : 1'b0;
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

    // ---- Phase 3/4: decode ex_op for MUL / MAC / RELU / RDCYC ----
    wire id_is_mul   = (id_opcode == 7'b0110011) && (id_funct7 == 7'b0000001) && (id_funct3 == 3'b000);
    wire id_is_mac   = (id_opcode == 7'b0001011) && (id_funct3 == 3'b000);
    wire id_is_relu  = (id_opcode == 7'b0001011) && (id_funct3 == 3'b001);
    wire id_is_rdcyc = (id_opcode == 7'b0001011) && (id_funct3 == 3'b010);

    wire [2:0] id_ex_op =
        id_is_mul   ? 3'b001 :
        id_is_mac   ? 3'b010 :
        id_is_relu  ? 3'b011 :
        id_is_rdcyc ? 3'b100 :
                      3'b000;

    wire [31:0] id_imm;
    immediate_gen imm_gen (
        .instruction(id_instr),
        .imm_sel(id_imm_sel),
        .imm_out(id_imm)
    );

    wire [31:0] id_rs1_data_raw, id_rs2_data_raw, id_rs3_data_raw;
    wire [31:0] id_rs1_data, id_rs2_data, id_rs3_data;

    wire        wb_reg_write;
    wire [4:0]  wb_rd;
    wire [31:0] wb_data;

    // Phase 4: 3-port regfile. rs3 is wired to id_rd so MAC can read its
    // accumulator. Non-MAC instructions drive rs3 too (dead read, harmless).
    register_file_3p reg_file (
        .clk(clk),
        .reg_write(wb_reg_write),
        .rs1(id_rs1), .rs2(id_rs2), .rs3(id_rd),
        .rd(wb_rd),
        .write_data(wb_data),
        .read_data1(id_rs1_data_raw),
        .read_data2(id_rs2_data_raw),
        .read_data3(id_rs3_data_raw)
    );

    assign id_rs1_data = (wb_reg_write && wb_rd != 5'd0 && wb_rd == id_rs1) ? wb_data : id_rs1_data_raw;
    assign id_rs2_data = (wb_reg_write && wb_rd != 5'd0 && wb_rd == id_rs2) ? wb_data : id_rs2_data_raw;
    assign id_rs3_data = (wb_reg_write && wb_rd != 5'd0 && wb_rd == id_rd ) ? wb_data : id_rs3_data_raw;

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

    // Inline registers: propagate predicted_taken, ex_op, and the MAC
    // accumulator (rs3) value through ID -> EX. ex_rs3_reg is the rs3
    // register index (= id_rd of the MAC) latched for forward_c lookup.
    reg        ex_predicted_taken;
    reg [2:0]  ex_op;
    reg [31:0] ex_rs3_data;
    always @(posedge clk) begin
        if (reset || flush_id_ex) begin
            ex_predicted_taken <= 1'b0;
            ex_op              <= 3'b000;
            ex_rs3_data        <= 32'b0;
            ex_rs3_reg         <= 5'b0;
        end else begin
            ex_predicted_taken <= id_predicted_taken;
            ex_op              <= id_ex_op;
            ex_rs3_data        <= id_rs3_data;
            ex_rs3_reg         <= id_rd;       // MAC accumulator reg index = id_rd
        end
    end

    // Phase 4: forward_c — forwarding mux for the MAC accumulator (rs3).
    // Same logic as forwarding_unit's forward_a/b, just keyed on ex_rs3_reg.
    assign forward_c =
        (mem_reg_write && (mem_rd != 5'd0) && (mem_rd == ex_rs3_reg)) ? 2'b01 :
        (wb_reg_write  && (wb_rd  != 5'd0) && (wb_rd  == ex_rs3_reg)) ? 2'b10 :
                                                                        2'b00;

    // Phase 4: rs3 load-use hazard. Only applies to MAC (id_is_mac), since
    // non-MAC instructions don't actually consume ex_rs3_data.
    assign rs3_load_use = id_is_mac && (ex_wb_sel == 2'b01) && (ex_rd != 5'd0) && (ex_rd == id_rd);

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

    // Phase 4: MAC accumulator (rs3) with forwarding.
    wire [31:0] ex_rs3_fwd =
        (forward_c == 2'b01) ? mem_alu_result :
        (forward_c == 2'b10) ? wb_data        :
                               ex_rs3_data;

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
    // Pass ex_op[1:0]: for RDCYC (3'b100), lower bits are 2'b00 → mul outputs 0, unused.
    wire [31:0] ex_mul_result;
    mul_unit mul (
        .a      (ex_rs1_fwd),
        .b      (ex_rs2_fwd),
        .c      (ex_rs3_fwd),         // Phase 4: 3-operand MAC — rd = rd + rs1*rs2
        .ex_op  (ex_op[1:0]),
        .result (ex_mul_result)
    );

    // ---- Phase 4: result mux — RDCYC overrides everything ----
    wire [31:0] ex_result_final =
        (ex_op == 3'b100) ? cycle_counter :
        (ex_op == 3'b000) ? ex_alu_result :
                            ex_mul_result;

    // // ---- Branch unit (uses ALU result, not muxed result) ----
    // wire branch_taken;
    // branch_unit br (
    //     .branch(ex_branch),
    //     .funct3(ex_funct3),
    //     .zero(ex_zero),
    //     .alu_lt(ex_alu_result[0]),
    //     .branch_taken(branch_taken)
    // );


    wire branch_taken_from_unit;
    branch_unit br (
        .branch(ex_branch),
        .funct3(ex_funct3),
        .zero(ex_zero),
        .alu_lt(ex_alu_result[0]),
        .branch_taken(branch_taken_from_unit)
    );

    // Bypass the glitchy 'zero' for BEQ/BNE by using ex_alu_result directly
    wire branch_taken = ex_branch && (
        (ex_funct3 == 3'b000) ? (ex_alu_result == 32'b0) :   // BEQ
        (ex_funct3 == 3'b001) ? (ex_alu_result != 32'b0) :   // BNE
        // For all other branch types, use the branch unit's output
        branch_taken_from_unit
    );

    wire [31:0] ex_pc_plus4      = ex_pc + 32'd4;
    wire [31:0] ex_branch_target = ex_pc + ex_imm;
    wire [31:0] ex_jalr_target   = (ex_rs1_fwd + ex_imm) & 32'hFFFFFFFE;

    wire branch_mispredict = ex_branch && (branch_taken != ex_predicted_taken);
    wire btb_update_en     = USE_BTB ? ex_branch : 1'b0;  // don't train when BTB disabled
    wire control_redirect  = branch_mispredict || ex_jump;

    wire [31:0] ex_correct_pc =
        (ex_jump && ex_opcode == 7'b1100111) ? ex_jalr_target   :
        (ex_jump && ex_opcode == 7'b1101111) ? ex_branch_target :
        branch_taken                         ? ex_branch_target :
                                               ex_pc_plus4;   // predicted-taken but not-taken → fall through branch

    assign pc_next =
        control_redirect                        ? ex_correct_pc         :
        (USE_BTB && if_btb_predict_taken)       ? if_btb_predict_target :
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
    //  EX/MEM REGISTER — receives muxed result as alu_result
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
        .ex_alu_result(ex_result_final),
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
    //  FORWARDING + HAZARD — unchanged from Phase 3
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
        .branch_taken(branch_mispredict),
        .ex_jump(ex_jump),
        .stall(stall_raw),
        .flush_if_id(flush_if_id_raw),
        .flush_id_ex(flush_id_ex_raw)
    );

    // ---- Output port connections (prevent logic trimming during synthesis) ----
    assign o_pc            = if_pc_out;
    assign o_cycle_counter = cycle_counter;
    assign o_wb_data       = wb_data;

    // ================================================================
    //  Instructions-retired counter (Phase 4 validation harness)
    //
    //  Tracks a "valid" bit alongside each pipeline stage. A bubble
    //  inserted by stall or flush has valid=0 and is not counted at WB.
    // ================================================================
    reg id_valid, ex_valid, mem_valid, wb_valid;
    always @(posedge clk) begin
        if (reset) begin
            id_valid  <= 1'b0;
            ex_valid  <= 1'b0;
            mem_valid <= 1'b0;
            wb_valid  <= 1'b0;
        end else begin
            // IF/ID: a stall freezes the same valid bit; a flush kills it;
            // otherwise IF always produces a valid instruction.
            if (flush_if_id)      id_valid <= 1'b0;
            else if (!stall)      id_valid <= 1'b1;
            // ID/EX: flush => bubble; stall => bubble (instr held in IF/ID)
            if (flush_id_ex)      ex_valid <= 1'b0;
            else if (stall)       ex_valid <= 1'b0;
            else                  ex_valid <= id_valid;
            // EX -> MEM -> WB: never flushed
            mem_valid <= ex_valid;
            wb_valid  <= mem_valid;
        end
    end

    reg [31:0] instr_retired;
    always @(posedge clk) begin
        if (reset)         instr_retired <= 32'd0;
        else if (wb_valid) instr_retired <= instr_retired + 32'd1;
    end

    assign o_instr_retired = instr_retired;

endmodule
