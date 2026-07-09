`timescale 1ns / 1ps

module top_VGA (
    input  logic       clk,
    input  logic       reset,
    input  logic       sw_mode,
    input logic        sw_gray,
    // input  logic       sw_r,
    // input  logic       sw_g,
    // input  logic       sw_b,
    // input  logic [3:0] sw_red,
    // input  logic [3:0] sw_green,
    // input  logic [3:0] sw_blue,
    output logic       h_sync,
    output logic       v_sync,
    output logic [3:0] port_red,
    output logic [3:0] port_green,
    output logic [3:0] port_blue
);

    logic [9:0] x_pixel;
    logic [9:0] y_pixel;
    logic       de;
    logic [11:0] w_sw_color, w_color_bar;

    logic [$clog2(160*120)-1:0] addr;
    logic [15:0] imgPxlData;

    logic [$clog2(160*120)-1:0] qvga_addr;
    logic [15:0] qvga_imgPxlData;
    logic [11:0] qvga_port_rgb;

    logic [$clog2(160*120)-1:0] upscale_addr;
    logic [15:0] upscale_imgPxlData;
    logic [11:0] upscale_port_rgb;

    logic [$clog2(160*120)-1:0] downscale_addr;
    logic [15:0] downscale_imgPxlData;
    logic [11:0] downscale_port_rgb;

    logic [11:0] port_rgb;


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
        .addr      (qvga_addr),
        .imgPxlData(qvga_imgPxlData),
        .port_red  (qvga_port_rgb[11:8]),
        .port_green(qvga_port_rgb[7:4]),
        .port_blue (qvga_port_rgb[3:0])
    );


    // UpScaleimage U_UpScaleImage (
    //     .de(de),
    //     .x_pixel(x_pixel),
    //     .y_pixel(y_pixel),
    //     .addr(upscale_addr),
    //     .imgPxlData(upscale_imgPxlData),
    //     .port_red(upscale_port_rgb[11:8]),
    //     .port_green(upscale_port_rgb[7:4]),
    //     .port_blue(upscale_port_rgb[3:0])
    // );

    DownScaleimage U_DownScaleimage(
        .de(de),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .addr(downscale_addr),
        .imgPxlData(downscale_imgPxlData),
        .port_red(downscale_port_rgb[11:8]),
        .port_green(downscale_port_rgb[7:4]),
        .port_blue(downscale_port_rgb[3:0])
);

    mux_2x1 #(
        .PORT_WIDTH($clog2(160 * 120))
    ) U_Mux_2x1 (
        .sel(sw_mode),
        .x0 (qvga_addr),
        .x1 (downscale_addr),
        .y  (addr)
    );

    demux_2x1 #(
        .PORT_WIDTH(16)
    ) U_Demux_2x1 (
        .sel(sw_mode),
        .y  (imgPxlData),
        .x0 (qvga_imgPxlData),
        .x1 (downscale_imgPxlData)
    );

    ImgROM U_ImgROM (
        .addr(addr),
        .data(imgPxlData)
    );

    // ColorBar U_ColorBar (
    //     .x_pixel   (x_pixel),
    //     .y_pixel   (y_pixel),
    //     .de        (de),
    //     .port_red  (w_color_bar[11:8]),
    //     .port_green(w_color_bar[7:4]),
    //     .port_blue (w_color_bar[3:0])
    // );

    // VGA_RGB_SW U_VGA_RGB_SW (
    //     .sw_red    (sw_red),
    //     .sw_green  (sw_green),
    //     .sw_blue   (sw_blue),
    //     .de        (de),
    //     .x_pixel   (x_pixel),
    //     .y_pixel   (y_pixel),
    //     .port_red  (w_sw_color[11:8]),
    //     .port_green(w_sw_color[7:4]),
    //     .port_blue (w_sw_color[3:0])
    // );

    logic [11:0] rgb_org;
    logic [11:0] rgb_gray;

    mux_2x1 U_MUX_RGB (
        .sel(sw_mode),
        .x0 (qvga_port_rgb),
        .x1 (downscale_port_rgb),
        .y  (rgb_org)
    );

    // RGB_Filter U_RGB_Filter (
    //     .sw_r(sw_r),
    //     .sw_g(sw_g),
    //     .sw_b(sw_b),
    //     .port_rgb(port_rgb),
    //     .port_rgb_out({port_red, port_green, port_blue})
    // );

    grayScale_Filter U_Gray_Filter (
        .i_rgb(rgb_org),
        .o_rgb(rgb_gray)
    );

    mux_2x1 U_MUX_RGB_Gray (
        .sel(sw_gray),
        .x0(rgb_org),
        .x1(rgb_gray),
        .y({port_red, port_green, port_blue})
);


endmodule

module mux_2x1 #(
    parameter PORT_WIDTH = 12
) (
    input  logic                  sel,
    input  logic [PORT_WIDTH-1:0] x0,
    input  logic [PORT_WIDTH-1:0] x1,
    output logic [PORT_WIDTH-1:0] y
);
    assign y = sel ? x1 : x0;
endmodule

module demux_2x1 #(
    parameter PORT_WIDTH = 16
) (
    input  logic                  sel,
    input  logic [PORT_WIDTH-1:0] y,
    output logic [PORT_WIDTH-1:0] x0,
    output logic [PORT_WIDTH-1:0] x1
);

    always_comb begin
        case (sel)
            1'b0: begin
                x0 = y;
                x1 = 0;
            end
            1'b1: begin
                x0 = 0;
                x1 = y;
            end
            default: begin
                x0 = 0;
                x1 = 0;
            end
        endcase
    end
endmodule

// module RGB_filter (
//     input  logic [ 2:0] sw_rgb,
//     input  logic [11:0] i_rgb,
//     output logic [11:0] o_rgb
// );
//     assign o_rgb[3:0]  = sw_rgb[0] ? i_rgb[3:0] : 0;
//     assign o_rgb[7:4]  = sw_rgb[1] ? i_rgb[7:4] : 0;
//     assign o_rgb[11:8] = sw_rgb[2] ? i_rgb[11:8] : 0;
// endmodule

module grayScale_Filter (
    input logic [11:0] i_rgb,
    output logic [11:0] o_rgb
);

    logic [11:0] gray;
    assign gray = ((i_rgb[11:8] << 6) + (i_rgb[11:8] << 3) + (i_rgb[11:8] << 2)) + 
                  ((i_rgb[7:4] << 7) + (i_rgb[7:4] << 4) + (i_rgb[7:4] << 3) + (i_rgb[7:4] << 1)) + 
                  ((i_rgb[3:0] << 4) + (i_rgb[3:0] << 3) + (i_rgb[3:0] << 1));
    assign o_rgb = {gray[11:8], gray[11:8], gray[11:8]};
    
endmodule
