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

    btn_debounce U_btn_debounce (
        .clk  (clk),
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

    SPI_controller U_SPI_controller (
        .clk        (clk_100M),
        .reset      (reset),
        // VGA_decoder side
        .v_sync     (v_sync),
        .x_pixel    (x_pixel),      // h_count 전체를 받음
        .y_pixel    (y_pixel),      // v_count 전체를 받음
        // SPI side
        .spi_tx_data(spi_tx_data),
        .start      (start),
        .done       (done),
        .busy       (busy),
        .slv_select (slv_select)
    );

    spi_master_14bit U_SPI_MST_14bit (
        .clk(clk_100M),
        .reset(reset),
        .cpol(0),  // idle 0: low, 1: high
        .cpha(0),  // first sampling, 0: first edge, 1: second edge
        .clk_div(4),
        .tx_data(spi_tx_data),
        .rx_data(spi_rx_data),
        .start(start),
        .done(done),
        .busy(busy),
        .sclk(sclk),
        .mosi(mosi),
        .miso(miso),
        .cs_n(cs_n)
    );

    LineBufferx2 U_SLB0 (
        // write side
        .wclk(clk_100M),
        .we(done & (slv_select)),
        .wline(wline),
        .wAddr(SLB0_wAddr),
        .wData(spi_rx_data),
        // read side
        .rline(rline),
        .rclk(rclk),
        .rAddr(SLB0_rAddr),
        .rData(SLB0_rData)
    );
    LineBufferx2 U_SLB1 (
        // write side
        .wclk(clk_100M),
        .we(done & (slv_select)),
        .wline(wline),
        .wAddr(SLB1_wAddr),
        .wData(spi_rx_data),
        // read side
        .rline(rline),
        .rclk(rclk),
        .rAddr(SLB1_rAddr),
        .rData(SLB1_rData)
    );
    LineBufferx2 U_SLB2 (
        // write side
        .wclk(clk_100M),
        .we(done & (slv_select)),
        .wline(wline),
        .wAddr(SLB2_wAddr),
        .wData(spi_rx_data),
        // read side
        .rline(rline),
        .rclk(rclk),
        .rAddr(SLB2_rAddr),
        .rData(SLB2_rData)
    );
    LineBufferx2 U_SLB3 (
        // write side
        .wclk(clk_100M),
        .we(done & (slv_select)),
        .wline(wline),
        .wAddr(SLB3_wAddr),
        .wData(spi_rx_data),
        // read side
        .rline(rline),
        .rclk(rclk),
        .rAddr(SLB3_rAddr),
        .rData(SLB3_rData)
    );
    LineBufferx2 U_SLB4 (
        // write side
        .wclk(clk_100M),
        .we(done & (slv_select)),
        .wline(wline),
        .wAddr(SLB4_wAddr),
        .wData(spi_rx_data),
        // read side
        .rline(rline),
        .rclk(rclk),
        .rAddr(SLB4_rAddr),
        .rData(SLB4_rData)
    );

    assign ss0 = (!cs_n) & (slv_select == 0);
    assign ss1 = (!cs_n) & (slv_select == 1);
    assign ss2 = (!cs_n) & (slv_select == 2);
    assign ss3 = (!cs_n) & (slv_select == 3);
    assign ss4 = (!cs_n) & (slv_select == 4);

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


module demux_5x1 #(
) (
    input  logic [2:0] sel,
    input  logic       y,
    output logic       x0,
    output logic       x1,
    output logic       x2,
    output logic       x3,
    output logic       x4
);
    always_comb begin
        x0 = 1;
        x1 = 1;
        x2 = 1;
        x3 = 1;
        x4 = 1;
        case (sel)
            0: x0 = y;
            1: x1 = y;
            2: x2 = y;
            3: x3 = y;
            4: x4 = y;
            default: x0 = y;
        endcase
    end
endmodule
