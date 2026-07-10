`timescale 1ns / 1ps

module Tile_filter #(
    parameter int H_BORDER_Y   = 80,  // 가로 border 시작 row
    parameter int V_BORDER1_X  = 35,  // 세로 border 1 시작 column
    parameter int V_BORDER2_X  = 70,  // 세로 border 2 시작 column
    parameter int BORDER_THICK = 1,   // 검정 border 두께(px)
    parameter int GREEN_THICK  = 2    // 초록 border 두께(px)
) (
    input logic [3:0] i_r,
    input logic [3:0] i_g,
    input logic [3:0] i_b,

    input logic [9:0] x_pixel,
    input logic [9:0] y_pixel,

    input logic [2:0] sw,

    output logic [3:0] o_r,
    output logic [3:0] o_g,
    output logic [3:0] o_b
);

    logic display_area;
    logic is_outer_border;
    logic is_h_border;
    logic is_v_border;
    logic is_border;

    // ---- 검정 테두리 (고정) ----
    assign display_area = (x_pixel < 106) && (y_pixel < 120);

    assign is_outer_border = (x_pixel == 0) || (x_pixel == 105) ||
                              (y_pixel == 0) || (y_pixel == 119);

    assign is_h_border = (y_pixel >= H_BORDER_Y) &&
                          (y_pixel <  H_BORDER_Y + BORDER_THICK);

    assign is_v_border = (y_pixel >= H_BORDER_Y + BORDER_THICK) &&
                          (((x_pixel >= V_BORDER1_X) && (x_pixel < V_BORDER1_X + BORDER_THICK)) ||
                           ((x_pixel >= V_BORDER2_X) && (x_pixel < V_BORDER2_X + BORDER_THICK)));

    assign is_border = display_area && (is_outer_border || is_h_border || is_v_border);

    // ---- 초록 테두리 (검정 테두리 안쪽, sw로 선택, 두께 GREEN_THICK) ----
    // 컬럼별 사용 가능한 내부 영역(검정 라인 제외) 좌표
    localparam int COL0_XMIN = 0           + BORDER_THICK;      // 1
    localparam int COL0_XMAX = V_BORDER1_X - BORDER_THICK;      // 34
    localparam int COL1_XMIN = V_BORDER1_X + BORDER_THICK;      // 36
    localparam int COL1_XMAX = V_BORDER2_X - BORDER_THICK;      // 69
    localparam int COL2_XMIN = V_BORDER2_X + BORDER_THICK;      // 71
    localparam int COL2_XMAX = 105         - BORDER_THICK;      // 104

    localparam int ROW_YMIN  = H_BORDER_Y  + BORDER_THICK;      // 81
    localparam int ROW_YMAX  = 119         - BORDER_THICK;      // 118

    logic is_green0, is_green1, is_green2, is_green;

    // 사각형 프레임(두께 GREEN_THICK)을 그리는 공통 조건: 좌/우/상/하 밴드
    assign is_green0 = sw[0] &&
        ((x_pixel >= COL0_XMIN)              && (x_pixel <  COL0_XMIN + GREEN_THICK) && (y_pixel >= ROW_YMIN) && (y_pixel <= ROW_YMAX) ||
         (x_pixel >  COL0_XMAX - GREEN_THICK) && (x_pixel <= COL0_XMAX)               && (y_pixel >= ROW_YMIN) && (y_pixel <= ROW_YMAX) ||
         (y_pixel >= ROW_YMIN)                && (y_pixel <  ROW_YMIN + GREEN_THICK)  && (x_pixel >= COL0_XMIN) && (x_pixel <= COL0_XMAX) ||
         (y_pixel >  ROW_YMAX - GREEN_THICK)  && (y_pixel <= ROW_YMAX)                && (x_pixel >= COL0_XMIN) && (x_pixel <= COL0_XMAX));

    assign is_green1 = sw[1] &&
        ((x_pixel >= COL1_XMIN)              && (x_pixel <  COL1_XMIN + GREEN_THICK) && (y_pixel >= ROW_YMIN) && (y_pixel <= ROW_YMAX) ||
         (x_pixel >  COL1_XMAX - GREEN_THICK) && (x_pixel <= COL1_XMAX)               && (y_pixel >= ROW_YMIN) && (y_pixel <= ROW_YMAX) ||
         (y_pixel >= ROW_YMIN)                && (y_pixel <  ROW_YMIN + GREEN_THICK)  && (x_pixel >= COL1_XMIN) && (x_pixel <= COL1_XMAX) ||
         (y_pixel >  ROW_YMAX - GREEN_THICK)  && (y_pixel <= ROW_YMAX)                && (x_pixel >= COL1_XMIN) && (x_pixel <= COL1_XMAX));

    assign is_green2 = sw[2] &&
        ((x_pixel >= COL2_XMIN)              && (x_pixel <  COL2_XMIN + GREEN_THICK) && (y_pixel >= ROW_YMIN) && (y_pixel <= ROW_YMAX) ||
         (x_pixel >  COL2_XMAX - GREEN_THICK) && (x_pixel <= COL2_XMAX)               && (y_pixel >= ROW_YMIN) && (y_pixel <= ROW_YMAX) ||
         (y_pixel >= ROW_YMIN)                && (y_pixel <  ROW_YMIN + GREEN_THICK)  && (x_pixel >= COL2_XMIN) && (x_pixel <= COL2_XMAX) ||
         (y_pixel >  ROW_YMAX - GREEN_THICK)  && (y_pixel <= ROW_YMAX)                && (x_pixel >= COL2_XMIN) && (x_pixel <= COL2_XMAX));

    assign is_green = display_area && (is_green0 || is_green1 || is_green2);

    // ---- 최종 출력: 검정 border 최우선 > 초록 border > 원본 이미지 ----
    assign o_r = is_border ? 4'h0 : (is_green ? 4'h0 : i_r);
    assign o_g = is_border ? 4'h0 : (is_green ? 4'hF : i_g);
    assign o_b = is_border ? 4'h0 : (is_green ? 4'h0 : i_b);

endmodule