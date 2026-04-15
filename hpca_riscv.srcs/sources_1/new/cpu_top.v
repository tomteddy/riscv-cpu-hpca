`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.04.2026 18:21:04
// Design Name: 
// Module Name: cpu_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


// ============================================================
// Module : cpu_top
// Project : RISC-V Single-Cycle CPU
// Description : Top level module. Wires all CPU modules
//               together to form a complete single-cycle
//               RV32I processor.
//
// Modules instantiated:
//   1. pc               - Program Counter register
//   2. instruction_memory - Fetches instruction at PC
//   3. control_unit     - Decodes opcode ? control signals
//   4. alu_control      - Decodes funct3/funct7 ? alu_ctrl
//   5. immediate_gen    - Extracts sign-extended immediate
//   6. register_file    - 32 general purpose registers
//   7. alu              - Arithmetic Logic Unit
//   8. data_memory      - Load/Store memory
//   9. writeback        - Selects value to write to register
//
// Inputs:
//   clk   - Clock signal
//   reset - Synchronous reset: resets PC to 0
//
// Internal data flow per instruction cycle:
//   1. PC sends address to instruction memory
//   2. Instruction memory outputs 32-bit instruction
//   3. Control unit decodes opcode ? control signals
//   4. ALU control decodes funct3/funct7 ? alu_ctrl
//   5. Immediate gen extracts immediate from instruction
//   6. Register file reads rs1 and rs2
//   7. ALU A MUX selects: rs1 or PC or 0
//   8. ALU B MUX selects: rs2 or immediate
//   9. ALU performs operation ? result + zero flag
//  10. Branch logic evaluates whether to take branch
//  11. PC next MUX selects: PC+4, PC+imm, or rs1+imm
//  12. Data memory reads or writes if needed
//  13. Writeback MUX selects: ALU result, mem data, PC+4
//  14. Register file writes writeback value to rd
// ============================================================

module cpu_top (
    input clk,      // Clock signal
    input reset     // Synchronous reset signal
);

    // ========================================================
    // WIRE DECLARATIONS
    // All internal signals connecting modules together
    // ========================================================

    // --------------------------------------------------------
    // PC wires
    // --------------------------------------------------------
    wire [31:0] pc_out;         // Current PC value (output of PC register)
    wire [31:0] pc_plus4;       // PC + 4 (next sequential instruction)
    wire [31:0] pc_branch;      // PC + immediate (branch/JAL target)
    wire [31:0] pc_jalr;        // (rs1 + imm) & ~1 (JALR target)
    wire [31:0] pc_next;        // Final next PC value fed into PC register

    // --------------------------------------------------------
    // Instruction memory wires
    // --------------------------------------------------------
    wire [31:0] instruction;    // 32-bit instruction fetched from memory

    // --------------------------------------------------------
    // Instruction field wires
    // These are just named slices of the instruction
    // --------------------------------------------------------
    wire [6:0]  opcode;         // instruction[6:0]   opcode field
    wire [4:0]  rd;             // instruction[11:7]  destination register
    wire [2:0]  funct3;         // instruction[14:12] funct3 field
    wire [4:0]  rs1;            // instruction[19:15] source register 1
    wire [4:0]  rs2;            // instruction[24:20] source register 2
    wire [6:0]  funct7;         // instruction[31:25] funct7 field

    // --------------------------------------------------------
    // Control unit output wires
    // --------------------------------------------------------
    wire        reg_write;      // Register file write enable
    wire        mem_write;      // Data memory write enable
    wire        alu_src;        // ALU B source: 0=rs2, 1=immediate
    wire [1:0]  alu_a_sel;      // ALU A source: 00=rs1, 01=PC, 10=zero
    wire [1:0]  wb_sel;         // Writeback source selector
    wire        branch;         // Branch instruction flag
    wire        jump;           // Jump instruction flag
    wire [2:0]  imm_sel;        // Immediate type selector
    wire [1:0]  alu_op;         // ALU operation category

    // --------------------------------------------------------
    // ALU control wire
    // --------------------------------------------------------
    wire [3:0]  alu_ctrl;       // 4-bit ALU operation selector

    // --------------------------------------------------------
    // Immediate generator wire
    // --------------------------------------------------------
    wire [31:0] imm_out;        // Sign-extended immediate value

    // --------------------------------------------------------
    // Register file wires
    // --------------------------------------------------------
    wire [31:0] read_data1;     // Value read from rs1
    wire [31:0] read_data2;     // Value read from rs2

    // --------------------------------------------------------
    // ALU input and output wires
    // --------------------------------------------------------
    wire [31:0] alu_a;          // ALU input A (after MUX)
    wire [31:0] alu_b;          // ALU input B (after MUX)
    wire [31:0] alu_result;     // ALU result output
    wire        zero;           // ALU zero flag

    // --------------------------------------------------------
    // Data memory wire
    // --------------------------------------------------------
    wire [31:0] mem_read_data;  // Data read from data memory

    // --------------------------------------------------------
    // Writeback wire
    // --------------------------------------------------------
    wire [31:0] wb_data;        // Final value written to register file

    // --------------------------------------------------------
    // Branch logic wire
    // --------------------------------------------------------
    wire        branch_taken;   // 1 if branch condition is met

    // ========================================================
    // INSTRUCTION FIELD EXTRACTION
    // Slice the 32-bit instruction into named fields
    // ========================================================

    assign opcode = instruction[6:0];   // Bits [6:0]   = opcode
    assign rd     = instruction[11:7];  // Bits [11:7]  = destination register
    assign funct3 = instruction[14:12]; // Bits [14:12] = funct3
    assign rs1    = instruction[19:15]; // Bits [19:15] = source register 1
    assign rs2    = instruction[24:20]; // Bits [24:20] = source register 2
    assign funct7 = instruction[31:25]; // Bits [31:25] = funct7

    // ========================================================
    // PC COMPUTATIONS
    // ========================================================

    // PC + 4: next sequential instruction address
    assign pc_plus4 = pc_out + 32'd4;

    // PC + immediate: branch target or JAL target
    assign pc_branch = pc_out + imm_out;

    // JALR target: rs1 + immediate, LSB forced to 0
    // As per RISC-V spec: target = (rs1 + imm) & ~1
    // & ~1 clears bit 0 (forces even address alignment)
    assign pc_jalr = (read_data1 + imm_out) & 32'hFFFFFFFE;

    // ========================================================
    // BRANCH LOGIC
    // Evaluates whether the branch condition is met
    // based on funct3 and ALU result/zero flag
    // ========================================================

    reg branch_taken_reg;   // Registered branch taken signal

    always @(*) begin
        branch_taken_reg = 1'b0;    // Default: branch not taken

        if (branch == 1'b1) begin   // Only evaluate if this is a branch

            case (funct3)

                3'b000: begin
                    // BEQ: branch if rs1 == rs2
                    // ALU performed SUB, zero=1 means equal
                    branch_taken_reg = zero;
                end

                3'b001: begin
                    // BNE: branch if rs1 != rs2
                    // ALU performed SUB, zero=0 means not equal
                    branch_taken_reg = ~zero;
                end

                3'b100: begin
                    // BLT: branch if rs1 < rs2 (signed)
                    // ALU performed SLT, result=1 means less than
                    branch_taken_reg = alu_result[0];
                end

                3'b101: begin
                    // BGE: branch if rs1 >= rs2 (signed)
                    // ALU performed SLT, result=0 means not less than
                    branch_taken_reg = ~alu_result[0];
                end

                3'b110: begin
                    // BLTU: branch if rs1 < rs2 (unsigned)
                    // ALU performed SLTU, result=1 means less than
                    branch_taken_reg = alu_result[0];
                end

                3'b111: begin
                    // BGEU: branch if rs1 >= rs2 (unsigned)
                    // ALU performed SLTU, result=0 means not less than
                    branch_taken_reg = ~alu_result[0];
                end

                default: begin
                    branch_taken_reg = 1'b0;    // Unknown branch = not taken
                end

            endcase
        end
    end

    assign branch_taken = branch_taken_reg; // Assign to wire

    // ========================================================
    // PC NEXT MUX
    // Selects the next PC value based on instruction type
    // Priority: JALR > JAL > branch taken > sequential
    // ========================================================

    assign pc_next =
        // JALR: jump to rs1 + imm (LSB cleared)
        (jump == 1'b1 && opcode == 7'b1100111) ? pc_jalr  :
        // JAL: jump to PC + imm
        (jump == 1'b1 && opcode == 7'b1101111) ? pc_branch :
        // Branch taken: jump to PC + imm
        (branch_taken == 1'b1)                 ? pc_branch :
        // Default: sequential execution PC + 4
                                                 pc_plus4;

    // ========================================================
    // ALU A MUX
    // Selects the first ALU operand
    // ========================================================

    assign alu_a =
        (alu_a_sel == 2'b00) ? read_data1 :  // rs1 value
        (alu_a_sel == 2'b01) ? pc_out     :  // current PC (AUIPC, JAL)
        (alu_a_sel == 2'b10) ? 32'b0      :  // zero (LUI: 0 + imm)
                               read_data1;   // default: rs1

    // ========================================================
    // ALU B MUX
    // Selects the second ALU operand
    // ========================================================

    assign alu_b =
        (alu_src == 1'b0) ? read_data2 :     // rs2 value (R-type)
                            imm_out;          // immediate value (I,S,B,U,J)

    // ========================================================
    // MODULE INSTANTIATIONS
    // ========================================================

    // --------------------------------------------------------
    // 1. Program Counter
    // Holds current PC, updates on clock edge
    // --------------------------------------------------------
    pc pc_reg (
        .clk     (clk),         // Clock input
        .reset   (reset),       // Reset input
        .pc_next (pc_next),     // Next PC value from MUX above
        .pc_out  (pc_out)       // Current PC value output
    );

    // --------------------------------------------------------
    // 2. Instruction Memory
    // Fetches instruction at current PC address
    // Loads program from instructions.hex file
    // --------------------------------------------------------
    instruction_memory imem (
        .pc    (pc_out),        // Byte address from PC
        .instr (instruction)    // 32-bit instruction output
    );

    // --------------------------------------------------------
    // 3. Control Unit
    // Decodes opcode and generates all control signals
    // --------------------------------------------------------
    control_unit ctrl (
        .opcode    (opcode),    // 7-bit opcode from instruction
        .reg_write (reg_write), // Register write enable
        .mem_write (mem_write), // Memory write enable
        .alu_src   (alu_src),   // ALU B source select
        .alu_a_sel (alu_a_sel), // ALU A source select
        .wb_sel    (wb_sel),    // Writeback source select
        .branch    (branch),    // Branch flag
        .jump      (jump),      // Jump flag
        .imm_sel   (imm_sel),   // Immediate type select
        .alu_op    (alu_op)     // ALU operation category
    );

    // --------------------------------------------------------
    // 4. ALU Control
    // Decodes funct3/funct7 ? 4-bit alu_ctrl for ALU
    // --------------------------------------------------------
    alu_control alu_ctrl_unit (
        .alu_op   (alu_op),     // Category from control unit
        .funct3   (funct3),     // funct3 from instruction
        .funct7   (funct7),     // funct7 from instruction
        .alu_ctrl (alu_ctrl)    // 4-bit ALU operation selector
    );

    // --------------------------------------------------------
    // 5. Immediate Generator
    // Extracts and sign-extends immediate from instruction
    // --------------------------------------------------------
    immediate_gen imm_gen (
        .instruction (instruction), // Full 32-bit instruction
        .imm_sel     (imm_sel),     // Immediate type from control
        .imm_out     (imm_out)      // Sign-extended immediate
    );

    // --------------------------------------------------------
    // 6. Register File
    // 32 x 32-bit registers, x0 hardwired to 0
    // 2 read ports, 1 write port
    // --------------------------------------------------------
    register_file reg_file (
        .clk        (clk),          // Clock for synchronous write
        .reg_write  (reg_write),    // Write enable from control unit
        .rs1        (rs1),          // Read address 1 from instruction
        .rs2        (rs2),          // Read address 2 from instruction
        .rd         (rd),           // Write address from instruction
        .write_data (wb_data),      // Data to write (from writeback)
        .read_data1 (read_data1),   // Value of rs1
        .read_data2 (read_data2)    // Value of rs2
    );

    // --------------------------------------------------------
    // 7. ALU
    // Performs arithmetic and logic operations
    // --------------------------------------------------------
    alu alu_unit (
        .a        (alu_a),      // First operand (after A MUX)
        .b        (alu_b),      // Second operand (after B MUX)
        .alu_ctrl (alu_ctrl),   // Operation selector
        .result   (alu_result), // Operation result
        .zero     (zero)        // Zero flag for branches
    );

    // --------------------------------------------------------
    // 8. Data Memory
    // Handles load and store instructions
    // --------------------------------------------------------
    data_memory dmem (
        .clk        (clk),          // Clock for synchronous write
        .mem_write  (mem_write),    // Write enable from control unit
        .addr       (alu_result),   // Address = ALU result (rs1+imm)
        .write_data (read_data2),   // Data to store = rs2 value
        .func3      (funct3),       // Access width selector
        .read_data  (mem_read_data) // Data loaded from memory
    );

    // --------------------------------------------------------
    // 9. Writeback MUX
    // Selects what gets written back to register file
    // --------------------------------------------------------
    writeback wb (
        .alu_result (alu_result),   // ALU result
        .mem_data   (mem_read_data),// Data from memory
        .pc_plus4   (pc_plus4),     // Return address for JAL/JALR
        .wb_sel     (wb_sel),       // Selector from control unit
        .wb_data    (wb_data)       // Final value to register file
    );

endmodule