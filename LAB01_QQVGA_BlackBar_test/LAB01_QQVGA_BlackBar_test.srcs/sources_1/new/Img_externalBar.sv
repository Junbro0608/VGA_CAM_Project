`timescale 1ns / 1ps

module Img_externalBar #(
    parameter int H_BORDER_Y   = 80,   // 가로 border 시작 row
    parameter int V_BORDER1_X  = 35,   // 세로 border 1 시작 column
    parameter int V_BORDER2_X  = 70,   // 세로 border 2 시작 column
    parameter int BORDER_THICK = 1     // border 두께(px)
)(
    input  logic [3:0] i_r,
    input  logic [3:0] i_g,
    input  logic [3:0] i_b,

    input  logic [9:0] x_pixel,
    input  logic [9:0] y_pixel,

    output logic [3:0] o_r,
    output logic [3:0] o_g,
    output logic [3:0] o_b
);

    logic display_area;
    logic is_outer_border;
    logic is_h_border;
    logic is_v_border;
    logic is_border;

    // 106x120 이미지 영역 안에서만 border 적용
    assign display_area = (x_pixel < 106) && (y_pixel < 120);

    // 이미지 외곽 테두리(사진 프레임)
    assign is_outer_border = (x_pixel == 0) || (x_pixel == 105) ||
                              (y_pixel == 0) || (y_pixel == 119);

    // 가로 구분선 (상단/하단 경계)
    assign is_h_border = (y_pixel >= H_BORDER_Y) &&
                          (y_pixel <  H_BORDER_Y + BORDER_THICK);

    // 세로 구분선 (하단 3분할, 가로선 아래에서만)
    assign is_v_border = (y_pixel >= H_BORDER_Y + BORDER_THICK) &&
                          (((x_pixel >= V_BORDER1_X) && (x_pixel < V_BORDER1_X + BORDER_THICK)) ||
                           ((x_pixel >= V_BORDER2_X) && (x_pixel < V_BORDER2_X + BORDER_THICK)));

    assign is_border = display_area && (is_outer_border || is_h_border || is_v_border);

    assign o_r = is_border ? 4'hF : i_r;
    assign o_g = is_border ? 4'h0 : i_g;
    assign o_b = is_border ? 4'h0 : i_b;

endmodule