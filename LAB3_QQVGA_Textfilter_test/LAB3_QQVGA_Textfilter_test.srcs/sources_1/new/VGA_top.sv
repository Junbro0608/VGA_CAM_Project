`timescale 1ns / 1ps

module VGA_top (
    input  logic       clk,
    input  logic       reset,
    input  logic [2:0] sw,
    input  logic [2:0] sw_text,
    output logic       h_sync,
    output logic       v_sync,
    output logic [3:0] port_red,
    output logic [3:0] port_green,
    output logic [3:0] port_blue
);

    logic [                9:0] x_pixel;
    logic [                9:0] y_pixel;
    logic                       de;

    logic [$clog2(106*120)-1:0] addr;
    logic [               15:0] imgPxlData;

    logic [                3:0] qqvga_red;
    logic [                3:0] qqvga_green;
    logic [                3:0] qqvga_blue;

    logic [                3:0] tile_r;
    logic [                3:0] tile_g;
    logic [                3:0] tile_b;

    logic [               12:0] text_addr;
    logic                       text_data;


    VGA_Decoder U_VGA_DECODER (
        .clk    (clk),
        .reset  (reset),
        .h_sync (h_sync),
        .v_sync (v_sync),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .de     (de)
    );

    ImgRomReader U_ROMREADER (
        .de        (de),
        .x_pixel   (x_pixel),
        .y_pixel   (y_pixel),
        .addr      (addr),
        .imgPxlData(imgPxlData),
        .port_red  (qqvga_red),
        .port_green(qqvga_green),
        .port_blue (qqvga_blue)
    );

    ImgROM U_IMGROM (
        .addr(addr),
        .data(imgPxlData)
    );

    Tile_filter #(
        .H_BORDER_Y  (80),  // 가로 border 시작 row
        .V_BORDER1_X (35),  // 세로 border 1 시작 column
        .V_BORDER2_X (70),  // 세로 border 2 시작 column
        .BORDER_THICK(1),
        .GREEN_THICK (2)    // border 두께(px)
    ) U_TILE_FILETER (
        .i_r    (qqvga_red),
        .i_g    (qqvga_green),
        .i_b    (qqvga_blue),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .sw     (sw),
        .o_r    (tile_r),
        .o_g    (tile_g),
        .o_b    (tile_b)
    );

    TextFilter U_TILEFILTER (
        .i_r    (tile_r),
        .i_g    (tile_g),
        .i_b    (tile_b),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .sw_text(sw_text),
        .addr   (text_addr),
        .data   (text_data),
        .o_r    (port_red),
        .o_g    (port_green),
        .o_b    (port_blue)
    );  

    Text_Rom U_TEXT_ROM (
        .addr(text_addr),
        .data(text_data)
    );
endmodule
