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
    output logic [3:0] port_blue,
    //spi side
    output logic       sclk,
    input  logic       miso,
    output logic       mosi,
    output logic [4:0] ss
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

    logic [13:0] SPI_tx_data, SPI_rx_data;
    logic       SPI_start;
    logic       SPI_done;
    logic       SPI_busy;
    logic [2:0] SLV_select;
    logic LB_wline, LB_rline;
    logic [6:0] LB_wAddr, LB_rAddr;

    //OV7670
    assign xclk  = clk_25M;
    //SPI
    assign ss[0] = (!cs_n) & (slv_select == 0);
    assign ss[1] = (!cs_n) & (slv_select == 1);
    assign ss[2] = (!cs_n) & (slv_select == 2);
    assign ss[3] = (!cs_n) & (slv_select == 3);
    assign ss[4] = (!cs_n) & (slv_select == 4);

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
        .start      (SPI_start),
        .done       (SPI_done),
        .busy       (SPI_busy),
        .slv_select (SLV_select),
        // Mem write side
        .wline      (LB_wline),
        .wAddr      (LB_wAddr)
    );

    spi_master_14bit U_SPI_MST_14bit (
        .clk(clk_100M),
        .reset(reset),
        .cpol(0),  // idle 0: low, 1: high
        .cpha(0),  // first sampling, 0: first edge, 1: second edge
        .clk_div(4),
        .tx_data(SPI_tx_data),
        .rx_data(SPI_rx_data),
        .start(SPI_start),
        .done(SPI_done),
        .busy(SPI_busy),
        .sclk(sclk),
        .mosi(mosi),
        .miso(miso),
        .cs_n(cs_n)
    );

    MMU U_MMU (
        //Write frameBuffer side
        .frame_wclk    (),
        .frame_we      (),
        .frame_wAddr   (),
        .frame_wData   (),
        //Write LineBuffer side
        .LB_wclk       (),
        .LB_we         (),
        .LB_wBuffer_sel(),
        .LB_wLine      (),
        .LB_wAddr      (),
        .LB_wData      (),
        //Read side
        .rclk          (),
        .rBuffer_sel   (),
        .rline         (),
        .rAddr         (),
        .rData         ()
    );

    LineBufferx2 U_SLB0 (
        // write side
        .wclk(clk_100M),
        .we(done & (slv_select == 0)),
        .wline(wline),
        .wAddr(LB_wAddr),
        .wData(SPI_rx_data[11:0]),
        // read side
        .rline(rline),
        .rclk(rclk),
        .rAddr(SLB0_rAddr),
        .rData(SLB0_rData)
    );
    LineBufferx2 U_SLB1 (
        // write side
        .wclk (clk_100M),
        .we   (done & (slv_select == 1)),
        .wline(wline),
        .wAddr(LB_wAddr),
        .wData(SPI_rx_data[11:0]),
        // read side
        .rline(rline),
        .rclk (rclk),
        .rAddr(SLB1_rAddr),
        .rData(SLB1_rData)
    );
    LineBufferx2 U_SLB2 (
        // write side
        .wclk (clk_100M),
        .we   (done & (slv_select == 2)),
        .wline(wline),
        .wAddr(LB_wAddr),
        .wData(SPI_rx_data[11:0]),
        // read side
        .rline(rline),
        .rclk (rclk),
        .rAddr(SLB2_rAddr),
        .rData(SLB2_rData)
    );
    LineBufferx2 U_SLB3 (
        // write side
        .wclk (clk_100M),
        .we   (done & (slv_select == 3)),
        .wline(wline),
        .wAddr(LB_wAddr),
        .wData(SPI_rx_data[11:0]),
        // read side
        .rline(rline),
        .rclk (rclk),
        .rAddr(SLB3_rAddr),
        .rData(SLB3_rData)
    );
    LineBufferx2 U_SLB4 (
        // write side
        .wclk (clk_100M),
        .we   (done & (slv_select == 4)),
        .wline(wline),
        .wAddr(LB_wAddr),
        .wData(SPI_rx_data[11:0]),
        // read side
        .rline(rline),
        .rclk (rclk),
        .rAddr(SLB4_rAddr),
        .rData(SLB4_rData)
    );

    frameBufferReader U_frameBufferReader (
        // VGA Decoder side
        .de        (de),
        .x_pixel   (x_pixel),
        .y_pixel   (y_pixel),
        // MEM side
        .mem_sel   (mem_sel),
        .LB_rline  (LB_rline),
        .addr      (addr),        // 넉넉하게 15비트로 할당
        .imgPxlData(imgPxlData),  // RGB444 (12비트)
        // VGA PORT side
        .port_red  (port_red),
        .port_green(port_green),
        .port_blue (port_blue)
    );

endmodule


module MMU (
    //Write frameBuffer side
    input                        frame_wclk,
    input                        frame_we,
    input  [$clog2(106*120)-1:0] frame_wAddr,
    input  [               15:0] frame_wData,
    //Write LineBuffer side
    input                        LB_wclk,
    input                        LB_we,
    input  [                2:0] LB_wBuffer_sel,
    input                        LB_wLine,
    input  [    $clog2(106)-1:0] LB_wAddr,
    input  [               11:0] LB_wData,
    //Read side
    input                        rclk,
    input  [                2:0] rBuffer_sel,
    input                        rline,
    input  [               14:0] rAddr,
    output [               11:0] rData
);
    logic [11:0] SLB0_rData, SLB1_rData, SLB2_rData, SLB3_rData, SLB4_rData;
    logic [15:0] qvga_imgPxlData;

    mux_6x1 #(
        .DATA_WIDTH(12)
    ) u_rdata_mux (
        .sel(rBuffer_sel),
        .d0(SLB0_rData),
        .d1({
            qvga_imgPxlData[15:12], qvga_imgPxlData[10:7], qvga_imgPxlData[4:1]
        }),
        .d2(SLB1_rData),
        .d3(SLB2_rData),
        .d4(SLB3_rData),
        .d5(SLB4_rData),
        .y(rData)
    );

    frameBuffer U_frameBuffer (
        // write side
        .wclk (frame_wclk),
        .we   (frame_we),
        .wAddr(frame_wAddr),
        .wData(frame_wData),
        // read side
        .rclk (rclk),
        .rAddr(rAddr),
        .rData(qvga_imgPxlData)
    );
    LineBufferx2 U_SLB0 (
        // write side
        .wclk(LB_wclk),
        .we(LB_we & (LB_wBuffer_sel == 0)),
        .wline(LB_wLine),
        .wAddr(LB_wAddr),
        .wData(LB_wData),
        // read side
        .rline(rline),
        .rclk(rclk),
        .rAddr(rAddr[6:0]),
        .rData(SLB0_rData)
    );
    LineBufferx2 U_SLB1 (
        // write side
        .wclk (LB_wclk),
        .we   (LB_we & (LB_wBuffer_sel == 1)),
        .wline(LB_wLine),
        .wAddr(LB_wAddr),
        .wData(LB_wData),
        // read side
        .rline(rline),
        .rclk (rclk),
        .rAddr(rAddr[6:0]),
        .rData(SLB1_rData)
    );
    LineBufferx2 U_SLB2 (
        // write side
        .wclk (LB_wclk),
        .we   (LB_we & (LB_wBuffer_sel == 2)),
        .wline(LB_wLine),
        .wAddr(LB_wAddr),
        .wData(LB_wData),
        // read side
        .rline(rline),
        .rclk (rclk),
        .rAddr(rAddr[6:0]),
        .rData(SLB2_rData)
    );
    LineBufferx2 U_SLB3 (
        // write side
        .wclk (LB_wclk),
        .we   (LB_we & (LB_wBuffer_sel == 3)),
        .wline(LB_wLine),
        .wAddr(LB_wAddr),
        .wData(LB_wData),
        // read side
        .rline(rline),
        .rclk (rclk),
        .rAddr(rAddr[6:0]),
        .rData(SLB3_rData)
    );
    LineBufferx2 U_SLB4 (
        // write side
        .wclk (LB_wclk),
        .we   (LB_we & (LB_wBuffer_sel == 4)),
        .wline(LB_wLine),
        .wAddr(LB_wAddr),
        .wData(LB_wData),
        // read side
        .rline(rline),
        .rclk (rclk),
        .rAddr(rAddr[6:0]),
        .rData(SLB4_rData)
    );
endmodule


module mux_6x1 #(
    parameter DATA_WIDTH = 12
) (
    input logic [           2:0] sel,
    input logic [DATA_WIDTH-1:0] d0,
    input logic [DATA_WIDTH-1:0] d1,
    input logic [DATA_WIDTH-1:0] d2,
    input logic [DATA_WIDTH-1:0] d3,
    input logic [DATA_WIDTH-1:0] d4,
    input logic [DATA_WIDTH-1:0] d5,

    // 선택된 최종 픽셀 데이터
    output logic [DATA_WIDTH-1:0] y
);

    always_comb begin
        case (sel)
            3'd0: y = d0;
            3'd1: y = d1;
            3'd2: y = d2;
            3'd3: y = d3;
            3'd4: y = d4;
            3'd5: y = d5;
            default: y = {DATA_WIDTH{1'b0}};
        endcase
    end

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
