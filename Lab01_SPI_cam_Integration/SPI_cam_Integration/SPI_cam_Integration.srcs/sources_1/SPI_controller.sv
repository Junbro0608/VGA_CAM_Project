`timescale 1ns / 1ps

module SPI_controller (
    input logic clk,
    input logic reset,
    // VGA_decoder side
    input logic v_sync,
    input logic [$clog2(800)-1:0] x_pixel,  // h_count 전체를 받음
    input logic [$clog2(525)-1:0] y_pixel,  // v_count 전체를 받음
    // SPI side
    output logic [7:0] clk_div,
    output logic [13:0] spi_tx_data,
    output logic start,
    input logic done,
    input logic busy,
    output logic [2:0] slv_select
    // Mem wirte sied
    output wline,
    output logic wAddr,
);

    // --- 파라미터 정의 ---
    // SLV0
    localparam SLV0_start_x = 0, SLV0_start_y = 0;
    localparam SLV0_end_x = 105, SLV0_end_y = 119;
    // SLV1 (내부 마스터 이미지 - SPI 통신 불필요)
    localparam SLV1_start_x = 107, SLV1_start_y = 0;
    localparam SLV1_end_x = 212, SLV1_end_y = 119;
    // SLV2
    localparam SLV2_start_x = 214, SLV2_start_y = 0;
    localparam SLV2_end_x = 319, SLV2_end_y = 119;
    // SLV3
    localparam SLV3_start_x = 0, SLV3_start_y = 120;
    localparam SLV3_end_x = 105, SLV3_end_y = 239;
    // SLV4
    localparam SLV4_start_x = 107, SLV4_start_y = 120;
    localparam SLV4_end_x = 212, SLV4_end_y = 239;
    // SLV5
    localparam SLV5_start_x = 214, SLV5_start_y = 120;
    localparam SLV5_end_x = 319, SLV5_end_y = 239;

    // --- SPI 기본 설정 ---
    assign cpol = 1'b0;  // Mode 0 기준 
    assign cpha = 1'b0;
    assign clk_div = 8'd2;  // 시스템 클럭에 맞게 분주비 설정

    // --- FSM 상태 정의 ---
    typedef enum logic [3:0] {
        READY = 0,
        CHECK_SLAVES,
        SEND_SYNC,
        WAIT_SYNC_DONE,
        WAIT_5CLK,
        READ_PIXEL,
        WAIT_READ_DONE,
        NEXT_SLAVE
    } state_e;

    state_e state;

    // --- 내부 레지스터 ---
    logic [7:0] next_y;
    logic [7:0] local_y;     // 슬레이브에게 보낼 0~119 라인 번호
    logic [2:0] current_slv; // 현재 통신 중인 슬레이브 인덱스
    logic [2:0] wait_cnt;    // 5 클럭 대기 카운터
    logic [6:0] pixel_cnt;   // 106 픽셀 카운터 (0~105)

    // --- 메인 상태 머신 ---
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= READY;
            start <= 1'b0;
            spi_tx_data <= 13'h00;
            slv_select <= 3'b000;
            wait_cnt <= 0;
            pixel_cnt <= 0;
            current_slv <= 0;
            next_y <= 0;
            local_y <= 0;
        end else begin
            case (state)
                READY: begin
                    start <= 1'b0;
                    // 디스플레이 영역(x=319)이 끝날 때 다음 라인(y+1) 프리페치 시작
                    if (x_pixel == 319 && y_pixel < 239) begin
                        next_y <= y_pixel + 1;
                        state  <= CHECK_SLAVES;
                    end
                end
                CHECK_SLAVES: begin
                    // 다음 Y 라인에 따라 통신할 첫 번째 슬레이브 결정
                    if (next_y < 120) begin
                        current_slv <= 3'd0; // 상단 라인: SLV0 부터 시작
                        local_y <= next_y;
                    end else begin
                        current_slv <= 3'd3; // 하단 라인: SLV3 부터 시작
                        local_y <= next_y - 120;  // 0~119로 정규화
                    end
                    state <= SEND_SYNC;
                end
                SEND_SYNC: begin
                    if (!busy) begin
                        slv_select  <= current_slv;
                        // 앞 4비트는 0, 뒤 8비트는 라인 번호 (총 12비트 전송)
                        spi_tx_data <= {6'h0, local_y};
                        start       <= 1'b1;
                        state       <= WAIT_SYNC_DONE;
                    end
                end
                WAIT_SYNC_DONE: begin
                    start <= 1'b0;  // 트리거 신호 끄기
                    if (done) begin
                        wait_cnt <= 0;
                        state <= WAIT_5CLK; // 싱크 전송 완료 후 5클럭 턴어라운드 진입
                    end
                end
                WAIT_5CLK: begin
                    // 슬레이브가 데이터를 준비할 5 clock 대기
                    if (wait_cnt == 4) begin
                        pixel_cnt <= 0;
                        state <= READ_PIXEL;
                    end else begin
                        wait_cnt <= wait_cnt + 1;
                    end
                end
                READ_PIXEL: begin
                    if (!busy) begin
                        spi_tx_data <= 13'h00;  // 읽기용 더미 데이터
                        start <= 1'b1;
                        state <= WAIT_READ_DONE;
                    end
                end
                WAIT_READ_DONE: begin
                    start <= 1'b0;
                    if (done) begin
                        if (pixel_cnt == 105) begin // 106 픽셀 모두 읽음
                            state <= NEXT_SLAVE;
                        end else begin
                            pixel_cnt <= pixel_cnt + 1;
                            state <= READ_PIXEL;  // 다음 픽셀 읽기
                        end
                    end
                end
                NEXT_SLAVE: begin
                    // 해당 라인의 다음 슬레이브 지정 (SLV1은 내부 이미지라 건너뜀)
                    if (current_slv == 0) begin
                        current_slv <= 3'd2;  // SLV0 끝 -> SLV2 시작
                        state <= SEND_SYNC;
                    end else if (current_slv == 3) begin
                        current_slv <= 3'd4;  // SLV3 끝 -> SLV4 시작
                        state <= SEND_SYNC;
                    end else if (current_slv == 4) begin
                        current_slv <= 3'd5;  // SLV4 끝 -> SLV5 시작
                        state <= SEND_SYNC;
                    end else begin
                        // 현재 라인에 필요한 외부 슬레이브 데이터 수신 완료
                        state <= READY;
                    end
                end
                default: state <= READY;
            endcase
        end
    end

endmodule
