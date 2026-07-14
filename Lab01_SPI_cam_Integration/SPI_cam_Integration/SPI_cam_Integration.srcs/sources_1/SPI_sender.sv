`timescale 1ns / 1ps
module SPI_sender (
    input  logic        clk,
    input  logic        reset,
    //Decoder
    input  logic        decoder_start,
    output logic        fsm_done,
    output logic [ 4:0] SPI_error,
    //SPI side
    output logic        sclk,
    output logic        mosi,
    input  logic        miso,
    output logic [ 4:0] cs_n,
    //write mem side
    output logic        we,
    output logic [11:0] waddr,
    output logic [23:0] wdata
);
    logic [7:0] SPI_tx_data, SPI_rx_data;
    logic SPI_start, SPI_done, SPI_busy, SPI_cs_n;
    logic [4:0] ss_n;

    assign cs_n[0] = SPI_cs_n | ss_n[0];
    assign cs_n[1] = SPI_cs_n | ss_n[1];
    assign cs_n[2] = SPI_cs_n | ss_n[2];
    assign cs_n[3] = SPI_cs_n | ss_n[3];
    assign cs_n[4] = SPI_cs_n | ss_n[4];

    SPI_FSM U_SPI_FSM (
        .clk          (clk),
        .reset        (reset),
        .decoder_start(decoder_start),
        .fsm_done     (fsm_done),
        .spi_error    (SPI_error),
        //spi_master
        .tx_data      (SPI_tx_data),
        .start        (SPI_start),
        .rx_data      (SPI_rx_data),
        .done         (SPI_done),
        .busy         (SPI_busy),
        .ss_n         (ss_n),
        //Frame Buffer(MMU)
        .we           (we),
        .waddr        (waddr),
        .wdata        (wdata)
    );



    spi_master U_spi_master (
        .clk    (clk),
        .reset  (reset),
        .cpol   (1'b0),         // idle 0: low, 1: high
        .cpha   (1'b0),         // first sampling, 0: first edge, 1: second edge
        .clk_div(8'h4),
        .tx_data(SPI_tx_data),
        .start  (SPI_start),
        .rx_data(SPI_rx_data),
        .done   (SPI_done),
        .busy   (SPI_busy),
        //인터널
        .sclk   (sclk),
        .mosi   (mosi),
        .miso   (miso),
        .cs_n   (SPI_cs_n)
    );

endmodule

module SPI_FSM (
    input logic clk,
    input logic reset,

    // --- System Control ---
    input  logic decoder_start,
    output logic fsm_done,

    // --- 통신 상태 보고 포트 ---
    output logic [4:0] spi_error,

    // --- spi_master (하위 PHY 모듈) 제어 포트 ---
    output logic [7:0] tx_data,
    output logic       start,
    input  logic [7:0] rx_data,
    input  logic       done,
    input  logic       busy,

    // --- 외부 슬레이브 CS 제어 ---
    output logic [4:0] ss_n,

    // --- Frame Buffer (MMU) 쓰기 포트 ---
    output logic        we,
    output logic [11:0] waddr,
    output logic [23:0] wdata
);

    // --- FSM 상태 정의 (READ_STATUS, WAIT_STATUS_DONE 추가됨) ---
    typedef enum logic [3:0] {
        FRAME_START,
        SEND_HEADER,
        WAIT_HEADER_DONE,
        READ_STATUS,       // [추가] 슬레이브 상태 수신 시작
        WAIT_STATUS_DONE,  // [추가] 슬레이브 상태 수신 대기
        READ_B1,
        WAIT_B1,
        READ_B2,
        WAIT_B2,
        READ_B3,
        WAIT_B3,
        WRITE_MEM,
        CHECK_LOOP,
        NEXT_SLAVE_CHECK,
        FRAME_DONE
    } state_e;

    state_e state;

    // --- 내부 레지스터 ---
    logic [2:0] slv_idx;
    logic [11:0] loop_cnt;
    logic [23:0] data_buf;

    // --- 출력 포트 매핑 ---
    assign wdata    = data_buf;
    assign waddr    = loop_cnt;
    assign we       = (state == WRITE_MEM);
    assign fsm_done = (state == FRAME_DONE);

    // --- 고속 상태 머신 (동기 리셋 적용) ---
    always_ff @(posedge clk) begin
        if (reset) begin
            state     <= FRAME_START;
            tx_data   <= 8'h00;
            start     <= 1'b0;
            ss_n      <= 5'b11111;
            slv_idx   <= 0;
            loop_cnt  <= 0;
            data_buf  <= 24'h000000;
            spi_error <= 5'b00000; 
        end else begin
            case (state)
                // 1. 트리거 대기 상태
                FRAME_START: begin
                    start <= 1'b0;
                    if (decoder_start) begin
                        slv_idx  <= 0;
                        loop_cnt <= 0;
                        state    <= SEND_HEADER;
                    end
                end

                // 2. 헤더 (0xA9) 전송
                SEND_HEADER: begin
                    if (!busy) begin
                        ss_n    <= ~(5'b00001 << slv_idx);
                        tx_data <= 8'hA9; 
                        start   <= 1'b1;
                        state   <= WAIT_HEADER_DONE;
                    end
                end
                WAIT_HEADER_DONE: begin
                    start <= 1'b0;
                    if (done) begin
                        state <= READ_STATUS; // 헤더 전송만 완료하고 상태 읽기로 넘어감
                    end
                end

                // 3. [추가됨] 슬레이브 상태 수신 (통신 가능 여부 판별)
                READ_STATUS: begin
                    if (!busy) begin
                        tx_data <= 8'h00; // SCLK를 만들어내기 위해 더미 데이터(0x00) 전송
                        start   <= 1'b1;
                        state   <= WAIT_STATUS_DONE;
                    end
                end
                WAIT_STATUS_DONE: begin
                    start <= 1'b0;
                    if (done) begin
                        // 슬레이브가 다음 통신에서 MISO로 보낸 상태값이 18이면 통신 시작
                        if (rx_data == 8'd18) begin 
                            spi_error[slv_idx] <= 1'b0;
                            state              <= READ_B1;
                        end else begin
                            // 통신 불가능 상태이면 CS 즉시 해제 후 다음 슬레이브로 스킵
                            spi_error[slv_idx] <= 1'b1;
                            ss_n               <= 5'b11111; 
                            state              <= NEXT_SLAVE_CHECK; 
                        end
                    end
                end

                // 4. 바이트 1 수신
                READ_B1: begin
                    if (!busy) begin
                        tx_data <= 8'h00;
                        start   <= 1'b1;
                        state   <= WAIT_B1;
                    end
                end
                WAIT_B1: begin
                    start <= 1'b0;
                    if (done) begin
                        data_buf[23:16] <= rx_data;
                        state           <= READ_B2;
                    end
                end

                // 5. 바이트 2 수신
                READ_B2: begin
                    if (!busy) begin
                        tx_data <= 8'h00;
                        start   <= 1'b1;
                        state   <= WAIT_B2;
                    end
                end
                WAIT_B2: begin
                    start <= 1'b0;
                    if (done) begin
                        data_buf[15:8] <= rx_data;
                        state          <= READ_B3;
                    end
                end

                // 6. 바이트 3 수신
                READ_B3: begin
                    if (!busy) begin
                        tx_data <= 8'h00;
                        start   <= 1'b1;
                        state   <= WAIT_B3;
                    end
                end
                WAIT_B3: begin
                    start <= 1'b0;
                    if (done) begin
                        data_buf[7:0] <= rx_data;
                        state         <= WRITE_MEM;
                    end
                end

                // 7. 메모리 쓰기 펄스
                WRITE_MEM: begin
                    state <= CHECK_LOOP;
                end

                // 8. 3180루프 검사
                CHECK_LOOP: begin
                    if (loop_cnt == 12'd3179) begin
                        ss_n  <= 5'b11111;
                        state <= NEXT_SLAVE_CHECK;
                    end else begin
                        loop_cnt <= loop_cnt + 1;
                        state    <= READ_B1;
                    end
                end

                // 9. 5개 슬레이브 순회
                NEXT_SLAVE_CHECK: begin
                    if (slv_idx == 4) begin
                        state <= FRAME_DONE;  
                    end else begin
                        slv_idx  <= slv_idx + 1;
                        loop_cnt <= 0;
                        state    <= SEND_HEADER;
                    end
                end

                // 10. 완료 보고 (딱 1클럭 소요)
                FRAME_DONE: begin
                    state <= FRAME_START; 
                end

                default: state <= FRAME_START;
            endcase
        end
    end
endmodule



module spi_master (
    input  logic       clk,
    input  logic       reset,
    input  logic       cpol,     // idle 0: low, 1: high
    input  logic       cpha,     // first sampling, 0: first edge, 1: second edge
    input  logic [7:0] clk_div,
    input  logic [7:0] tx_data,
    input  logic       start,
    output logic [7:0] rx_data,
    output logic       done,
    output logic       busy,
    output logic       sclk,
    output logic       mosi,
    input  logic       miso,
    output logic       cs_n
);
    typedef enum logic [1:0] {
        IDLE  = 2'b00,
        START,
        DATA,
        STOP
    } spi_state_e;

    spi_state_e state;
    logic [7:0] div_cnt;
    logic half_tick;
    logic [7:0] tx_shift_reg, rx_shift_reg;
    logic [2:0] bit_cnt;
    logic step, sclk_r;

    assign sclk = sclk_r;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            div_cnt   <= 0;
            half_tick <= 1'b0;
        end else begin
            if (state == DATA) begin
                if (div_cnt == clk_div) begin
                    div_cnt   <= 0;
                    half_tick <= 1'b1;
                end else begin
                    div_cnt   <= div_cnt + 1;
                    half_tick <= 1'b0;
                end
            end
        end
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            mosi <= 1'b1;
            cs_n <= 1'b1;
            busy <= 1'b0;
            done <= 1'b0;
            tx_shift_reg <= 0;
            rx_shift_reg <= 0;
            bit_cnt <= 0;
            step <= 1'b0;
            rx_data <= 0;
            sclk_r <= cpol;
        end else begin
            done <= 1'b0;
            case (state)
                IDLE: begin
                    mosi   <= 1'b1;
                    cs_n   <= 1'b1;
                    sclk_r <= cpol;
                    if (start) begin
                        tx_shift_reg <= tx_data;
                        bit_cnt <= 0;
                        step <= 1'b0;
                        busy <= 1'b1;
                        cs_n <= 1'b0;
                        state <= START;
                    end
                end
                START: begin
                    if (!cpha) begin
                        mosi <= tx_shift_reg[7];
                        tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
                    end
                    state <= DATA;
                end
                DATA: begin
                    if (half_tick) begin  // susin
                        sclk_r <= ~sclk_r;
                        if (step == 0) begin
                            step <= 1'b1;
                            if (!cpha) begin
                                rx_shift_reg <= {rx_shift_reg[6:0], miso};
                            end else begin
                                mosi <= tx_shift_reg[7];
                                tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
                            end
                        end else begin  // songsin
                            step <= 1'b0;
                            if (!cpha) begin
                                if (bit_cnt < 7) begin
                                    mosi <= tx_shift_reg[7];
                                    tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
                                end
                            end else begin
                                rx_shift_reg <= {rx_shift_reg[6:0], miso};
                            end

                            if (bit_cnt == 7) begin
                                state <= STOP;
                                if (!cpha) begin
                                    rx_data <= rx_shift_reg;
                                end else begin
                                    rx_data <= {rx_shift_reg[6:0], miso};
                                end
                            end else begin
                                bit_cnt <= bit_cnt + 1;
                            end
                        end
                    end
                end
                STOP: begin
                    sclk_r <= 1'b0;
                    cs_n   <= 1'b1;
                    done   <= 1'b1;
                    busy   <= 1'b0;
                    mosi   <= 1'b1;
                    state  <= IDLE;
                end
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule
