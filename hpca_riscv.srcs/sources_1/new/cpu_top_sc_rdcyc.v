// ============================================================
// Module : cpu_top_sc_rdcyc
// Project : RV32I Single-Cycle CPU — Phase 4 variant
// Description : Single-cycle baseline with full Phase 4 ISA support:
//   - MUL (M extension), MAC (3-operand: rd = rd + rs1*rs2), RELU,
//     RDCYC (reads 32-bit free-running cycle counter).
//   - register_file_3p (3 read ports) for MAC accumulator read.
//   - No pipeline, no forwarding, no BTB.  Each instruction
//     completes in exactly 1 clock cycle.
//
//   Signals exposed for tb_cpu_top_sc_rdcyc (match pipelined names):
//     if_pc_out     — current PC (combinational)
//     if_instr      — instruction fetched this cycle
//     cycle_counter — free-running 32-bit counter
//     dmem.mem      — data memory array
//
//   op encoding (internal, same as cpu_top_mext_rdcyc):
//     000 = use ALU result
//     001 = MUL   (rs1 * rs2)
//     010 = MAC   (rd  + rs1*rs2)   ← 3-operand
//     011 = RELU  (max(rs1, 0))
//     100 = RDCYC (cycle_counter)
// ============================================================

`timescale 1ns / 1ps

module cpu_top_sc_rdcyc (
    input clk,
    input reset
);

    // ================================================================
    //  32-bit cycle counter
    // ================================================================
    reg [31:0] cycle_counter;
    always @(posedge clk) begin
        if (reset) cycle_counter <= 32'd0;
        else       cycle_counter <= cycle_counter + 32'd1;
    end

    // ================================================================
    //  PC
    // ================================================================
    wire [31:0] if_pc_out;
    wire [31:0] pc_plus4   = if_pc_out + 32'd4;
    wire [31:0] pc_branch  = if_pc_out + imm_out;
    wire [31:0] pc_jalr    = (rs1_data + imm_out) & 32'hFFFFFFFE;
    wire [31:0] pc_next;

    pc pc_reg (
        .clk(clk), .reset(reset),
        .pc_next(pc_next),
        .pc_out(if_pc_out)
    );

    // ================================================================
    //  Instruction memory
    // ================================================================
    wire [31:0] if_instr;

    instruction_memory imem (
        .pc(if_pc_out),
        .instr(if_instr)
    );

    // ---- Instruction fields ----
    wire [6:0] opcode = if_instr[6:0];
    wire [4:0] rd     = if_instr[11:7];
    wire [2:0] funct3 = if_instr[14:12];
    wire [4:0] rs1    = if_instr[19:15];
    wire [4:0] rs2    = if_instr[24:20];
    wire [6:0] funct7 = if_instr[31:25];

    // ================================================================
    //  Control unit
    // ================================================================
    wire       reg_write, mem_write, alu_src, branch, jump;
    wire [1:0] alu_a_sel, wb_sel, alu_op;
    wire [2:0] imm_sel;

    control_unit ctrl (
        .opcode(opcode),
        .reg_write(reg_write), .mem_write(mem_write),
        .alu_src(alu_src), .alu_a_sel(alu_a_sel), .wb_sel(wb_sel),
        .branch(branch), .jump(jump),
        .imm_sel(imm_sel), .alu_op(alu_op)
    );

    // ---- Phase 4: decode op for MUL / MAC / RELU / RDCYC ----
    wire is_mul   = (opcode == 7'b0110011) && (funct7 == 7'b0000001) && (funct3 == 3'b000);
    wire is_mac   = (opcode == 7'b0001011) && (funct3 == 3'b000);
    wire is_relu  = (opcode == 7'b0001011) && (funct3 == 3'b001);
    wire is_rdcyc = (opcode == 7'b0001011) && (funct3 == 3'b010);

    wire [2:0] sc_op =
        is_mul   ? 3'b001 :
        is_mac   ? 3'b010 :
        is_relu  ? 3'b011 :
        is_rdcyc ? 3'b100 :
                   3'b000;

    // ================================================================
    //  Immediate generator
    // ================================================================
    wire [31:0] imm_out;

    immediate_gen imm_gen (
        .instruction(if_instr),
        .imm_sel(imm_sel),
        .imm_out(imm_out)
    );

    // ================================================================
    //  Register file (3-port for MAC accumulator read)
    //  rs3 = rd: MAC reads its own destination as accumulator source.
    //  Single-cycle: register reads are combinational → rs3 gives the
    //  value from the *previous* cycle's write, which is correct.
    // ================================================================
    wire [31:0] rs1_data, rs2_data, rs3_data;
    wire [31:0] wb_data;

    register_file_3p reg_file (
        .clk(clk),
        .reg_write(reg_write),
        .rs1(rs1), .rs2(rs2), .rs3(rd),
        .rd(rd),
        .write_data(wb_data),
        .read_data1(rs1_data),
        .read_data2(rs2_data),
        .read_data3(rs3_data)
    );

    // ================================================================
    //  ALU
    // ================================================================
    wire [3:0] alu_ctrl;

    alu_control alu_ctrl_unit (
        .alu_op(alu_op), .funct3(funct3), .funct7(funct7),
        .alu_ctrl(alu_ctrl)
    );

    wire [31:0] alu_a = (alu_a_sel == 2'b01) ? if_pc_out :
                        (alu_a_sel == 2'b10) ? 32'b0     :
                                               rs1_data;
    wire [31:0] alu_b = alu_src ? imm_out : rs2_data;

    wire [31:0] alu_result;
    wire        zero;

    alu alu_unit (
        .a(alu_a), .b(alu_b),
        .alu_ctrl(alu_ctrl),
        .result(alu_result),
        .zero(zero)
    );

    // ================================================================
    //  Branch unit
    // ================================================================
    wire branch_taken;

    branch_unit br (
        .branch(branch), .funct3(funct3),
        .zero(zero), .alu_lt(alu_result[0]),
        .branch_taken(branch_taken)
    );

    // ================================================================
    //  mul_unit (MUL / MAC / RELU)
    //  c = rs3_data: the MAC accumulator (rd read as source)
    // ================================================================
    wire [31:0] mul_result;

    mul_unit mul (
        .a     (rs1_data),
        .b     (rs2_data),
        .c     (rs3_data),    // MAC accumulator = rd read
        .ex_op (sc_op[1:0]),
        .result(mul_result)
    );

    // ================================================================
    //  Data memory
    // ================================================================
    wire [31:0] mem_read_data;

    data_memory dmem (
        .clk(clk), .mem_write(mem_write),
        .addr(alu_result), .write_data(rs2_data),
        .func3(funct3), .read_data(mem_read_data)
    );

    // ================================================================
    //  Write-back mux
    //  Priority: RDCYC > mul/mac/relu > mem > PC+4 > ALU
    // ================================================================
    assign wb_data =
        (sc_op == 3'b100) ? cycle_counter :
        (sc_op != 3'b000) ? mul_result    :
        (wb_sel == 2'b01) ? mem_read_data :
        (wb_sel == 2'b10) ? pc_plus4      :
                            alu_result;

    // ================================================================
    //  Next-PC MUX  (priority: JALR > JAL > branch > PC+4)
    // ================================================================
    assign pc_next =
        (jump && opcode == 7'b1100111) ? pc_jalr   :
        (jump && opcode == 7'b1101111) ? pc_branch :
        branch_taken                   ? pc_branch :
                                         pc_plus4;

endmodule
