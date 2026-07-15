`timescale 1ns / 1ps

module text_filter (
    input logic [3:0] i_r,
    input logic [3:0] i_g,
    input logic [3:0] i_b,
    input logic [9:0] x_pixel,
    input logic [9:0] y_pixel,

    output logic [12:0] addr,
    input  logic        data_rom,

    output logic [3:0] o_r,
    output logic [3:0] o_g,
    output logic [3:0] o_b
);

    localparam int LABEL_W = 30;
    localparam int LABEL_H = 16;

    localparam int COL0_X = 3;
    localparam int COL1_X = 38;
    localparam int COL2_X = 73;
    localparam int ROW_Y = 92;

    logic [1:0] cell_idx;
    logic in_col0, in_col1, in_col2;
    logic [4:0] rel_x;
    logic [3:0] rel_y;
    logic       is_label_area;
    logic       is_text;

    assign in_col0 = (x_pixel >= COL0_X) && (x_pixel < COL0_X + LABEL_W);
    assign in_col1 = (x_pixel >= COL1_X) && (x_pixel < COL1_X + LABEL_W);
    assign in_col2 = (x_pixel >= COL2_X) && (x_pixel < COL2_X + LABEL_W);

    always_comb begin
        if (in_col0) cell_idx = 2'd0;
        else if (in_col1) cell_idx = 2'd1;
        else if (in_col2) cell_idx = 2'd2;
        else cell_idx = 2'd0;
    end

    assign is_label_area = (in_col0 || in_col1 || in_col2) && (y_pixel >= ROW_Y) && (y_pixel < ROW_Y + LABEL_H);

    assign rel_x = in_col0 ? (x_pixel - COL0_X) :
                   in_col1 ? (x_pixel - COL1_X) :
                             (x_pixel - COL2_X);
    assign rel_y = y_pixel - ROW_Y;

    assign addr = is_label_area ? (cell_idx * (LABEL_W * LABEL_H) + rel_y * LABEL_W + rel_x) : '0;
    assign is_text = is_label_area && (data_rom == 1'b1);

    assign o_r = is_text ? 4'h0 : i_r;
    assign o_g = is_text ? 4'h0 : i_g;
    assign o_b = is_text ? 4'h0 : i_b;

endmodule

