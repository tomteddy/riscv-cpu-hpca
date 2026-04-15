`timescale 1ns / 1ps
// ============================================================
// cpu_top : Single-cycle RV32I top-level.
//   Wires pc, imem, control, alu_control, imm_gen, regfile,
//   alu, branch_unit, dmem, writeback together.
// ============================================================

module cpu_top (
    input clk,
    input reset
);

    // ---- PC ----
    wire [31:0] pc_out, pc_plus4, pc_branch, pc_jalr, pc_next;

    // ---- Instruction & fields ----
    wire [31:0] instruction;
    wire [6:0]  opcode = instruction[6:0];
    wire [4:0]  rd     = instruction[11:7];
    wire [2:0]  funct3 = instruction[14:12];
    wire [4:0]  rs1    = instruction[19:15];
    wire [4:0]  rs2    = instruction[24:20];
    wire [6:0]  funct7 = instruction[31:25];

    // ---- Control ----
    wire       reg_write, mem_write, alu_src, branch, jump;
    wire [1:0] alu_a_sel, wb_sel, alu_op;
    wire [2:0] imm_sel;
    wire [3:0] alu_ctrl;

    // ---- Datapath ----
    wire [31:0] imm_out;
    wire [31:0] rs1_data, rs2_data;
    wire [31:0] alu_a, alu_b, alu_result;
    wire        zero;
    wire [31:0] mem_read_data;
    wire [31:0] wb_data;
    wire        branch_taken;

    // ---- PC arithmetic ----
    assign pc_plus4  = pc_out + 32'd4;
    assign pc_branch = pc_out + imm_out;
    assign pc_jalr   = (rs1_data + imm_out) & 32'hFFFFFFFE;

    // ---- Next-PC MUX  (priority: JALR > JAL > branch > PC+4) ----
    assign pc_next =
        (jump && opcode == 7'b1100111) ? pc_jalr   :   // JALR
        (jump && opcode == 7'b1101111) ? pc_branch :   // JAL
        (branch_taken)                 ? pc_branch :   // Branch taken
                                         pc_plus4;

    // ---- ALU operand MUXes ----
    assign alu_a = (alu_a_sel == 2'b01) ? pc_out :
                   (alu_a_sel == 2'b10) ? 32'b0  :
                                          rs1_data;

    assign alu_b = alu_src ? imm_out : rs2_data;

    // ====== Module instances ======
    pc pc_reg (
        .clk(clk), .reset(reset), .pc_next(pc_next), .pc_out(pc_out)
    );

    instruction_memory imem (
        .pc(pc_out), .instr(instruction)
    );

    control_unit ctrl (
        .opcode(opcode),
        .reg_write(reg_write), .mem_write(mem_write),
        .alu_src(alu_src), .alu_a_sel(alu_a_sel), .wb_sel(wb_sel),
        .branch(branch), .jump(jump),
        .imm_sel(imm_sel), .alu_op(alu_op)
    );

    alu_control alu_ctrl_unit (
        .alu_op(alu_op), .funct3(funct3), .funct7(funct7),
        .alu_ctrl(alu_ctrl)
    );

    immediate_gen imm_gen (
        .instruction(instruction), .imm_sel(imm_sel), .imm_out(imm_out)
    );

    register_file reg_file (
        .clk(clk), .reg_write(reg_write),
        .rs1(rs1), .rs2(rs2), .rd(rd),
        .write_data(wb_data),
        .read_data1(rs1_data), .read_data2(rs2_data)
    );

    alu alu_unit (
        .a(alu_a), .b(alu_b), .alu_ctrl(alu_ctrl),
        .result(alu_result), .zero(zero)
    );

    branch_unit br (
        .branch(branch), .funct3(funct3),
        .zero(zero), .alu_lt(alu_result[0]),
        .branch_taken(branch_taken)
    );

    data_memory dmem (
        .clk(clk), .mem_write(mem_write),
        .addr(alu_result), .write_data(rs2_data),
        .func3(funct3), .read_data(mem_read_data)
    );

    writeback wb (
        .alu_result(alu_result), .mem_data(mem_read_data),
        .pc_plus4(pc_plus4), .wb_sel(wb_sel),
        .wb_data(wb_data)
    );

endmodule
