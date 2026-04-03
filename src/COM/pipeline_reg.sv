module pipeline_reg #(
    parameter type T = logic,
    parameter T RESET_VALUE = '0
) (
    input  logic i_clk,
    input  logic i_reset_n,
    input  logic i_en,
    input  logic i_flush,
    input  T     i_d,
    output T     o_q
);

    always_ff @(posedge i_clk) begin
        if (!i_reset_n) begin
            o_q <= RESET_VALUE;
        end else if (i_flush) begin
            o_q <= RESET_VALUE;
        end else if (i_en) begin
            o_q <= i_d;
        end
    end

endmodule : pipeline_reg
