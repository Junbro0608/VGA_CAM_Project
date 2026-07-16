`timescale 1ns / 1ps

module top_master (
    input logic clk,
    input logic reset,

    // [추가] UART (PC 통신용) 포트
    input  logic       rx,
    output logic       tx,

    // [추가] I2C Master (Slave 통신용) 포트
    output logic       scl_s,
    inout  wire        sda_s,

    // i2c side (OV7670 제어용)
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
    input  logic [4:0] miso,
    output logic       mosi,
    output logic [4:0] cs_n,
    output logic       LED_xy00,
    output logic [1:0] led
);

    // ==========================================
    // 🔗 내부 연결선 (Wire/Logic) 선언
    // ==========================================
    logic clk_100M, clk_25M, rclk;
    assign xclk = clk_25M;
    // VGA Decoder 및 픽셀 신호
    logic [                  9:0] x_pixel;
    logic [                  9:0] y_pixel;
    logic                         de;

    // OV7670 -> MMU 쓰기 신호
    logic                         cam_raw_we;
    logic [  $clog2(320*240)-1:0] cam_raw_wAddr;
    logic [                 15:0] cam_raw_wData;
    logic                         we;
    logic [  $clog2(106*120)-1:0] wAddr;
    logic [                 15:0] wData;

    // SPI 관련 신호
    logic                         decoder_start;
    logic                         fsm_done;
    logic [                  4:0] SPI_error;
    logic [                  4:0] SPI_we;
    logic [$clog2(106*120/4)-1:0] SPI_waddr;
    logic [                119:0] SPI_wdata;

    // MMU 제어 및 데이터 신호
    logic [4:0] r_sel, w_sel;

    // 주소 및 데이터 분리 신호
    logic [  $clog2(106*120)-1:0] cam_rAddr;
    logic [$clog2(106*120/4)-1:0] mem_rAddr;
    logic [23:0] rData0, rData2, rData3, rData4, rData5;
    logic [11:0] rData1;
    logic [ 7:0] slv0_rx_data;

    // ==========================================
    // 🔗 I2C Master & UART 통신용 내부 신호 선언
    // ==========================================
    logic w_start_uart; // UART 전송 시작 틱
  
    logic [11:0] w_note;
    logic [7:0]  w_tx_data;
    logic  w_u_start;
    
    // [주의 포인트] 테스트 코드에 있던 OV7670_Music_Scale_Detect 모듈이 현재 탑에는 없습니다.
    // 마스터 본체의 2비트 데이터(m_note)를 0으로 고정해 두었으니, 
    // 추후 필요시 카메라 추출 로직을 추가하거나 slv0_rx_data[1:0] 등을 연결하세요.
    logic [1:0] m_note;
    assign led = w_note[1:0];

    always_ff @(posedge clk_100M or posedge reset) begin
        if (reset) begin
            LED_xy00 <= 0;
        end else if(x_pixel == 0 && LED_xy00 == 0) begin
            LED_xy00 <= ~LED_xy00;
        end
    end

    ila_0 U_ila_0 (
        .clk(clk),  
        .probe0(SPI_error[0]),  
        .probe1(SPI_we[0]),   
        .probe2(SPI_waddr),   
        .probe3({16'b0, slv0_rx_data[7:0]}),  
        .probe4(cs_n[0]),   
        .probe5(miso[0])  
    );

    // ==========================================
    // 🧱 하위 모듈 인스턴스화 (기존)
    // ==========================================
    clk_wiz_0 U_clk_wiz (
        .clk_100M(clk_100M),
        .clk_25M (clk_25M),
        .reset   (reset),
        .clk_in1 (clk)
    );

    OV7670_controller U_OV7670_controller (
        .clk  (pclk),
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
        .we   (cam_raw_we),
        .wAddr(cam_raw_wAddr),
        .wData(cam_raw_wData)
    );

    CameraDownScale106x120 U_CameraDownScale106x120 (
        .pclk   (pclk),
        .reset  (reset),
        .vsync  (vsync),
        .i_we   (cam_raw_we),
        .i_wData(cam_raw_wData),
        .o_we   (we),
        .o_wAddr(wAddr),
        .o_wData(wData)
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
        .wdata        (SPI_wdata),
        .slv0_rx_data (slv0_rx_data)
    );

    mem_controller U_mem_controller (
        .clk         (clk_100M),
        .reset       (reset),
        .x_pixel     (x_pixel),
        .y_pixel     (y_pixel),
        .de          (de),
        .SPI_start   (decoder_start),
        .SPI_error   (SPI_error),
        .SPI_fsm_done(fsm_done),
        .w_sel       (w_sel),
        .r_sel       (r_sel)
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
        .de        (de),
        .x_pixel   (x_pixel),
        .y_pixel   (y_pixel),
        .cam_raddr (cam_rAddr),
        .cam_rdata1(rData1),
        .mem_raddr (mem_rAddr),
        .mem_rdata0(rData0),
        .mem_rdata2(rData2),
        .mem_rdata3(rData3),
        .mem_rdata4(rData4),
        .mem_rdata5(rData5),
        .port_red  (port_red),
        .port_green(port_green),
        .port_blue (port_blue)
    );


OV7670_Music_Scale_Detect U_OV7670_Music_Scale_Detect (
    .rclk(),
    .reset(),
    .vsync(),
    .imgPxlData(),
    .x_pixel(),
    .y_pixel(),
    .data_lat(m_note)
);


I2C_MASTER_TOP U_I2C_MASTER_TOP(
    .clk_100M(clk_100M),
    .reset(reset),
    .m_note(m_note),
    .o_note(w_note),
    .scl_s(scl_s),
    .sda_s(sda_s)

    );

 UART_MASTER_TOP U_UART_MASTER_TOP(
    .clk_100M(clk_100M),
    .reset(reset),
    .note(w_note),
    .rx(rx),
    .tx(tx)
    );


endmodule