`timescale 1ns / 1ps

module top_VGA (
    input  logic       clk,
    input  logic       reset,
    //io side
    input  logic       sw_upscl,
    input  logic [1:0] sw_mode,
    input  logic       sw_clr_red,
    input  logic       sw_clr_green,
    input  logic       sw_clr_blue,
    input  logic       OV_init_btn,
    //i2c side
    output logic       scl,
    inout  logic       sda,
    //ov7670 side
    output logic       xclk,
    input  logic       pclk,
    input  logic       href,
    input  logic       vsync,
    input  logic [7:0] pdata,
    // vga side
    output logic       h_sync,
    output logic       v_sync,
    output logic [3:0] port_red,
    output logic [3:0] port_green,
    output logic [3:0] port_blue
);

    logic [                9:0] x_pixel;
    logic [                9:0] y_pixel;
    logic                       de;

    logic [$clog2(320*240)-1:0] addr;
    logic [               15:0] imgPxlData;

    logic [$clog2(320*240)-1:0] qvga_addr, upscl_addr, org_addr;
    logic [               15:0] qvga_imgPxlData;
    logic [               11:0] qvga_port_rgb;

    logic                       we;
    logic [$clog2(320*240)-1:0] wAddr;
    logic [               15:0] wData;

    logic clk_100M, clk_25M, rclk;

    logic [3:0] org_red, org_green, org_blue;
    logic [3:0] unscl_red, unscl_green, unscl_blue;
    logic OV_init_btn_d;

    assign xclk = clk_25M;

    btn_debounce U_btn_debounce(
    .clk(clk),
    .reset(reset),
    .i_btn(OV_init_btn),
    .o_btn(OV_init_btn_d)
);


    clk_wiz_0 U_clk_wiz (
        // Clock out ports
        .clk_100M(clk_100M),
        .clk_25M (clk_25M),
        // Status and control signals
        .reset   (reset),
        // Clock in ports
        .clk_in1 (clk)
    );

    OV7670_controller U_OV7670_controller (
        .clk  (clk),
        .reset(reset),
        .start(OV_init_btn_d),
        .scl  (scl),
        .sda  (sda)
    );


    VGA_Decoder U_VGA_Decoder (
        .clk    (clk_100M),
        .reset  (reset),
        .rclk   (rclk),
        .h_sync (h_sync),
        .v_sync (v_sync),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .de     (de)
    );

    OV7670_MemController U_OV7670_MemController (
        .pclk (pclk),
        .reset(reset),
        // ov7670 side
        .href (href),
        .vsync(vsync),
        .pdata(pdata),
        // framebuffere side
        .we   (we),
        .wAddr(wAddr),
        .wData(wData)
    );

    frameBuffer U_frameBuffer (
        // write side
        .wclk (pclk),
        .we   (we),
        .wAddr(wAddr),
        .wData(wData),
        // read side
        .rclk (rclk),
        .rAddr(qvga_addr),
        .rData(qvga_imgPxlData)
    );

    frameBufferReader U_frameBufferReader (
        .de        (de),
        .x_pixel   (x_pixel),
        .y_pixel   (y_pixel),
        .addr      (org_addr),
        .imgPxlData(qvga_imgPxlData),
        .port_red  (org_red),
        .port_green(org_green),
        .port_blue (org_blue)
    );

    UnScaleImage u_UnScaleImage (
        .de        (de),
        .x_pixel   (x_pixel),
        .y_pixel   (y_pixel),
        .addr      (upscl_addr),
        .imgPxlData(qvga_imgPxlData),
        .port_red  (unscl_red),
        .port_green(unscl_green),
        .port_blue (unscl_blue)
    );

    mux_2x1 #(
        .PORT_WIDTH($clog2(320 * 240))
    ) U_addr_mux (
        .sel(sw_upscl),
        .x0 (org_addr),
        .x1 (upscl_addr),
        .y  (qvga_addr)
    );

    logic [3:0] img_red, img_green, img_blue;
    logic [3:0] rgb_red, rgb_green, rgb_blue;
    logic [3:0] gray_red, gray_green, gray_blue;

    mux_2x1 #(
        .PORT_WIDTH(12)
    ) U_unscl_mux (
        .sel(sw_upscl),
        .x0 ({org_red, org_green, org_blue}),
        .x1 ({unscl_red, unscl_green, unscl_blue}),
        .y  ({img_red, img_green, img_blue})
    );


    rgb_filter U_rgb_filter (
        .sel({sw_clr_red, sw_clr_green, sw_clr_blue}),
        .input_rgb({img_red, img_green, img_blue}),
        .port_rgb({rgb_red, rgb_green, rgb_blue})
    );

    grayscale_filter U_grayscale_filter (
        .in_rgb({img_red, img_green, img_blue}),
        .port_gray({gray_red, gray_green, gray_blue})
    );

    mux_3x1 #(
        .PORT_WIDTH(12)
    ) U_outport_mux (
        .sel(sw_mode),
        .x0 ({img_red, img_green, img_blue}),
        .x1 ({rgb_red, rgb_green, rgb_blue}),
        .x2 ({gray_red, gray_green, gray_blue}),
        .y  ({port_red, port_green, port_blue})
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

module mux_3x1 #(
    parameter PORT_WIDTH = 12
) (
    input  logic [           1:0] sel,
    input  logic [PORT_WIDTH-1:0] x0,
    input  logic [PORT_WIDTH-1:0] x1,
    input  logic [PORT_WIDTH-1:0] x2,
    output logic [PORT_WIDTH-1:0] y
);
    assign y = (sel == 2) ? x2 : (sel == 1) ? x1 : x0;
endmodule


module demux_2x1 #(
    parameter PORT_WIDTH = 12
) (
    input  logic                  sel,
    input  logic [PORT_WIDTH-1:0] y,
    output logic [PORT_WIDTH-1:0] x0,
    output logic [PORT_WIDTH-1:0] x1
);
    always_comb begin
        x0 = 0;
        x1 = 0;
        case (sel)
            0: x0 = y;
            1: x1 = y;
        endcase
    end
endmodule
