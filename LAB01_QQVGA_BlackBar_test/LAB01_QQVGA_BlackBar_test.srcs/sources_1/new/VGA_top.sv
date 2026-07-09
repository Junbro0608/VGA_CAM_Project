`timescale 1ns / 1ps

module VGA_top (
    input  logic       clk,
    input  logic       reset,
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

    Img_externalBar#(
        .H_BORDER_Y   (80),  // 가로 border 시작 row
        .V_BORDER1_X  (35),  // 세로 border 1 시작 column
        .V_BORDER2_X  (70),  // 세로 border 2 시작 column
        .BORDER_THICK (1)    // border 두께(px)
    ) (
        .i_r(qqvga_red),
        .i_g(qqvga_green),
        .i_b(qqvga_blue),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .o_r(port_red),
        .o_g(port_green),
        .o_b(port_blue)
    );
endmodule
