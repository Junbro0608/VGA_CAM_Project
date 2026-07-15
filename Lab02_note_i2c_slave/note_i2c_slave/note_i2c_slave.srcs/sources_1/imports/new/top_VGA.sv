`timescale 1ns / 1ps

module top_VGA (
    input logic clk,
    input logic reset,

    input  logic       pclk,
    output logic       xclk,
    input  logic       href,
    input  logic       vsync,
    input  logic [7:0] pdata,
    output logic       scl,
    inout  wire        sda,

    output logic       scl_s,
    inout  wire        sda_s,

    // input  logic [11:0] sw,
    // input  logic        rx,
    // output logic        tx,

    output logic [3:0] port_red,
    output logic [3:0] port_green,
    output logic [3:0] port_blue,
    output logic       h_sync,
    output logic       v_sync
);


    logic [                9:0] x_pixel;
    logic [                9:0] y_pixel;
    logic [                9:0] x_pixel_d;
    logic [                9:0] y_pixel_d;
    logic                       de;
    logic                       de_d;
    logic [                1:0] data;

    logic [$clog2(320*240)-1:0] addr;
    logic [               15:0] imgPxlData;

    logic                       we;
    logic [$clog2(320*240)-1:0] wAddr;
    logic [               15:0] wData;

    logic clk_100, clk_25;
    logic rclk;

    assign xclk = clk_25;

    logic ack_out, busy;

    logic data_rom;
    logic [12:0] tile_addr;

    logic [11:0] downscale_color;
    logic [11:0] text_color, tile_color;
    logic [$clog2(320*240)-1:0] downscale_addr;

    logic w_done, w_start_5s, w_start_2s, w_u_start;
    logic [ 7:0] w_tx_data;
    logic [11:0] w_note;

    clk_wiz_0 CLK_DIVIDER (
        .clk_100(clk_100),
        .clk_25 (clk_25),
        .reset  (reset),
        .clk_in1(clk)
    );

    OV7670_SCCB_Controller U_OV7670_SCCB_Controller (
        .clk    (clk),
        .reset  (reset),
        .ack_in (1'b1),
        .ack_out(ack_out),
        .busy   (busy),
        .scl    (scl),
        .sda    (sda)
    );

    VGA_Decoder U_VGA_Decoder (
        .clk    (clk_100),
        .reset  (reset),
        .rclk   (rclk),
        .h_sync (h_sync),
        .v_sync (v_sync),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .de     (de)
    );

    VGA_pixel_delay U_VGA_Pixel_Delay (
        .rclk(rclk),
        .reset(reset),
        .de(de),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .de_d(de_d),
        .x_pixel_d(x_pixel_d),
        .y_pixel_d(y_pixel_d)
    );

    frameBuffer U_frameBuffer (
        .wclk (pclk),
        .we   (we),
        .wAddr(wAddr),
        .wData(wData),
        .rclk (rclk),
        .rAddr(addr),
        .rData(imgPxlData)
    );

    OV7670_MemController U_OV7670_MemController (
        .pclk (pclk),
        .reset(reset),
        .href (href),
        .vsync(vsync),
        .pdata(pdata),
        .we   (we),
        .wAddr(wAddr),
        .wData(wData)
    );

    DownScaleimage U_DOWNSCALEIMAGE (
        .rclk      (rclk),
        .reset     (reset),
        .de        (de),
        .x_pixel   (x_pixel),
        .y_pixel   (y_pixel),
        .addr      (addr),
        .imgPxlData(imgPxlData),
        .port_red  (downscale_color[11:8]),
        .port_green(downscale_color[7:4]),
        .port_blue (downscale_color[3:0])
    );

    OV7670_Music_Scale_Detect U_OV7670_Music_Scale_Detect (
        .rclk      (rclk),
        .reset     (reset),
        .vsync     (v_sync),
        .imgPxlData(imgPxlData),
        .x_pixel   (x_pixel_d),
        .y_pixel   (y_pixel_d),
        .data_lat  (data)
    );

    i2c_slave U_I2C_SLAVE (
        .clk(clk_100),
        .reset(reset),
        .tx_data({6'd0, data}),
        .rx_data(),
        .done(),
        .scl(scl_s),
        .sda(sda_s)
    );

    text_rom U_TEXT_ROM (
        .addr    (tile_addr),
        .data_rom(data_rom)
    );

    text_filter U_TEXT_FILTER (
        .i_r     (downscale_color[11:8]),
        .i_g     (downscale_color[7:4]),
        .i_b     (downscale_color[3:0]),
        .x_pixel (x_pixel_d),
        .y_pixel (y_pixel_d),
        .addr    (tile_addr),
        .data_rom(data_rom),
        .o_r     (text_color[11:8]),
        .o_g     (text_color[7:4]),
        .o_b     (text_color[3:0])
    );

    tile_filter U_TILE_FILTER (
        .i_r    (text_color[11:8]),
        .i_g    (text_color[7:4]),
        .i_b    (text_color[3:0]),
        .x_pixel(x_pixel_d),
        .y_pixel(y_pixel_d),
        .data   (data),
        .o_r    (tile_color[11:8]),
        .o_g    (tile_color[7:4]),
        .o_b    (tile_color[3:0])
    );

    Icon_Filter U_ICON_FILTER (
        .de        (de_d),
        .x_pixel   (x_pixel_d),
        .y_pixel   (y_pixel_d),
        .input_rgb (tile_color),
        .output_rgb({port_red, port_green, port_blue})
    );

endmodule
