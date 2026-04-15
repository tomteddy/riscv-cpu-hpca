`timescale 1ns / 1ps
// ============================================================
// writeback : MUX that picks what gets written to the regfile.
//   wb_sel = 00 -> alu_result     (R/I/LUI/AUIPC)
//            01 -> mem_data       (loads)
//            10 -> pc_plus4       (JAL/JALR return address)
// ============================================================

module writeback (
    input      [31:0] alu_result,
    input      [31:0] mem_data,
    input      [31:0] pc_plus4,
    input      [1:0]  wb_sel,
    output reg [31:0] wb_data
);

    always @(*) begin
        case (wb_sel)
            2'b00:   wb_data = alu_result;
            2'b01:   wb_data = mem_data;
            2'b10:   wb_data = pc_plus4;
            default: wb_data = 32'b0;
        endcase
    end

endmodule
