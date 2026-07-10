`timescale 1ns / 1ps

module top_VGA (
    input  logic       clk,
    input  logic       reset,
    input  logic [5:0] sw_icon,
    output logic       h_sync,
    output logic       v_sync,
    output logic [3:0] port_red,
    output logic [3:0] port_green,
    output logic [3:0] port_blue
);

    logic [                  9:0] x_pixel;
    logic [                  9:0] y_pixel;
    logic                         de;

    logic [$clog2(106*120) - 1:0] addr;
    logic [                 15:0] imgPxlData;

    logic [                  3:0] img_red;
    logic [                  3:0] img_green;
    logic [                  3:0] img_blue;

    logic [                 11:0] img_rgb;
    logic [                 11:0] final_rgb;

    VGA_Decoder U_VGA_Decoder (
        .clk    (clk),
        .reset  (reset),
        .h_sync (h_sync),
        .v_sync (v_sync),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .de     (de)
    );

    ImgRomReader U_ImgRomReader (
        .de        (de),
        .x_pixel   (x_pixel),
        .y_pixel   (y_pixel),
        .addr      (addr),
        .imgPxlData(imgPxlData),
        .port_red  (img_red),
        .port_green(img_green),
        .port_blue (img_blue)
    );

    ImgROM U_ImgROM (
        .addr(addr),
        .data(imgPxlData)
    );

    assign img_rgb = {img_red, img_green, img_blue};

    Icon_Filter U_IconFilter (
        .clk       (clk),
        .de        (de),
        .x_pixel   (x_pixel),
        .y_pixel   (y_pixel),
        .sw_icon   (sw_icon),
        .input_rgb (img_rgb),
        .output_rgb(final_rgb)
    );

    assign {port_red, port_green, port_blue} = final_rgb;

endmodule

// module mux_2x1 (
//     input  logic        sel,
//     input  logic [11:0] x0,
//     input  logic [11:0] x1,
//     output logic [11:0] y
// );

//     assign y = sel ? x1 : x0;

// endmodule
