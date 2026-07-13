`timescale 1ns / 1ps

module top_master (
    input  logic       clk,
    input  logic       reset,
    
    // i2c side
    output logic       scl,
    inout  logic       sda,
    // ov7670 side
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
    // spi side
    output logic       sclk,
    input  logic       miso,
    output logic       mosi,
    output logic [4:0] cs_n
);

    // ==========================================
    // 🔗 내부 연결선 (Wire/Logic) 선언
    // ==========================================
    logic clk_100M, clk_25M, rclk;
    assign xclk = clk_25M;

    // VGA Decoder 및 픽셀 신호
    logic [ 9:0] x_pixel;
    logic [ 9:0] y_pixel;
    logic        de;

    // OV7670 -> MMU 쓰기 신호
    logic        we;
    logic [$clog2(320*240)-1:0] wAddr;
    logic [ 15:0] wData;

    // SPI 관련 신호
    logic        decoder_start;
    logic        fsm_done;       
    logic [ 4:0] SPI_error;
    logic        SPI_we;
    logic [$clog2(106*120*5)-1:0] SPI_waddr; 
    logic [ 11:0] SPI_wdata;

    // MMU 제어 및 데이터 신호
    logic [ 4:0] r_sel, w_sel;   

    // 주소 및 데이터 분리 신호
    logic [$clog2(106*120)-1:0]   cam_rAddr;
    logic [$clog2(106*120/4)-1:0] mem_rAddr;
    
    logic [24:0] rData0, rData2, rData3, rData4, rData5;
    logic [11:0] rData1;

    // 불필요한(Floating) Logic 선언부 싹 정리 완료!


    // ==========================================
    // 🧱 하위 모듈 인스턴스화
    // ==========================================
    clk_wiz_0 U_clk_wiz (
        .clk_100M(clk_100M),
        .clk_25M (clk_25M),
        .reset   (reset),
        .clk_in1 (clk)
    );

    OV7670_controller U_OV7670_controller (
        .clk  (clk),
        .reset(reset),
        .start(1'b1),
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
        .href (href),
        .vsync(vsync),
        .pdata(pdata),
        .we   (we),
        .wAddr(wAddr),
        .wData(wData)
    );

    SPI_sender U_SPI_sender (
        .clk          (clk_100M),
        .reset        (reset),
        .decoder_start(decoder_start),
        .fsm_done     (fsm_done),
        .SPI_error    (SPI_error),
        .sclk         (sclk),
        .mosi         (mosi),
        .miso         (miso),
        .cs_n         (cs_n),
        .we           (SPI_we),
        .waddr        (SPI_waddr),
        .wdata        (SPI_wdata)
    );

    mem_controller U_mem_controller (
        .clk          (clk_100M),
        .reset        (reset),
        .de           (de),
        .x_pixel      (x_pixel),
        .y_pixel      (y_pixel),
        .SPI_error    (SPI_error),
        .SPI_fsm_done (fsm_done), // [수정] SPI_sender의 출력인 fsm_done에 연결
        .w_sel        (w_sel),
        .r_sel        (r_sel)
    );

    MMU U_MMU (
        .CAM_pclk (pclk),
        .CAM_we   (we),
        .CAM_wAddr(wAddr),
        .CAM_wData(wData),
        .wclk     (clk_100M),
        .w_sel    (w_sel),
        .we       (SPI_we),
        .wAddr    (SPI_waddr),
        .wData    (SPI_wdata),
        .rclk     (rclk),
        .r_sel    (r_sel),
        .cam_rAddr(cam_rAddr),
        .mem_rAddr(mem_rAddr),
        .rData0   (rData0),
        .rData1   (rData1),
        .rData2   (rData2),
        .rData3   (rData3),
        .rData4   (rData4),
        .rData5   (rData5)
    );

    UnScaleImage U_UnScaleImage (
        .de         (de),
        .x_pixel    (x_pixel),
        .y_pixel    (y_pixel),
        // cam side 
        .cam_raddr  (cam_rAddr),
        .cam_rdata1 (rData1),
        // mem side 
        .mem_raddr  (mem_rAddr),
        .mem_rdata0 (rData0),
        .mem_rdata2 (rData2),
        .mem_rdata3 (rData3),
        .mem_rdata4 (rData4),
        .mem_rdata5 (rData5),
        // VGA side
        .port_red   (port_red),
        .port_green (port_green),
        .port_blue  (port_blue)
    );

endmodule