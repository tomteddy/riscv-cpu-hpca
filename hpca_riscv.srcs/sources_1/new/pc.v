`timescale 1ns / 1ps
// ============================================================
// pc : Program Counter register. Synchronous reset to 0.
// ============================================================

module pc (
    input             clk,
    input             reset,
    input      [31:0] pc_next,
    output reg [31:0] pc_out
);

    always @(posedge clk) begin
        if (reset) pc_out <= 32'h00000000;
        else       pc_out <= pc_next;
    end

endmodule
