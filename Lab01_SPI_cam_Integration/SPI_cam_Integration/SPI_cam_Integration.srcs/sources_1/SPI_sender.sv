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
    input  logic [ 4:0] miso,
    output logic [ 4:0] cs_n,
    //write mem side
    output logic [ 4:0] we,
    output logic [11:0] waddr,
    output logic [119:0] wdata
);
    logic [7:0] SPI_tx_data;
    logic [39:0] SPI_rx_data;
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
        .clk(clk),
        .reset(reset),
        .cpol(1'b0),  // idle 0: low, 1: high
        .cpha(1'b0),  // first sampling, 0: first edge, 1: second edge
        .clk_div(8'h4),
        .tx_data(SPI_tx_data),
        .start(SPI_start),
        .rx_data(SPI_rx_data),
        .done(SPI_done),
        .busy(SPI_busy),
        //인터널
        .sclk(sclk),
        .mosi(mosi),
        .miso(miso),
        .cs_n(SPI_cs_n)
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
    input  logic [39:0] rx_data,
    input  logic       done,
    input  logic       busy,

    // --- 외부 슬레이브 CS 제어 ---
    output logic [4:0] ss_n,

    // --- Frame Buffer (MMU) 쓰기 포트 ---
    output logic [ 4:0] we,
    output logic [11:0] waddr,
    output logic [119:0] wdata
);

    // --- FSM 상태 정의 (STATUS 확인 상태 제거됨) ---
    typedef enum logic [3:0] {
        FRAME_START,
        SEND_HEADER,
        WAIT_HEADER_DONE,
        READ_STATUS,
        WAIT_STATUS,
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
    logic [11:0] loop_cnt;
    logic [4:0] status_ready;
    logic [23:0] data_buf0, data_buf1, data_buf2, data_buf3, data_buf4;

    // --- 출력 포트 매핑 ---
    assign waddr    = loop_cnt;
    assign fsm_done = (state == FRAME_DONE);

    always_comb begin
        status_ready[0] = (rx_data[ 7: 0] == 8'h18);
        status_ready[1] = (rx_data[15: 8] == 8'h18);
        status_ready[2] = (rx_data[23:16] == 8'h18);
        status_ready[3] = (rx_data[31:24] == 8'h18);
        status_ready[4] = (rx_data[39:32] == 8'h18);

        we = 5'b00000;
        wdata = {data_buf4, data_buf3, data_buf2, data_buf1, data_buf0};
        if (state == WRITE_MEM) begin
            we = ~spi_error;
        end
    end

    // --- 고속 상태 머신 (동기 리셋 유지) ---
    always_ff @(posedge clk) begin
        if (reset) begin
            state     <= FRAME_START;
            tx_data   <= 8'h00;
            start     <= 1'b0;
            ss_n      <= 5'b11111;
            loop_cnt  <= 0;
            data_buf0 <= 24'd0;
            data_buf1 <= 24'd0;
            data_buf2 <= 24'd0;
            data_buf3 <= 24'd0;
            data_buf4 <= 24'd0;
            spi_error <= 5'b00000;
        end else begin
            case (state)
                // 1. 트리거 대기 상태
                FRAME_START: begin
                    start <= 1'b0;
                    if (decoder_start) begin
                        loop_cnt <= 0;
                        state    <= SEND_HEADER;
                    end
                end

                // 2. 헤더 (0xA9) 전송
                SEND_HEADER: begin
                    if (!busy) begin
                        ss_n    <= 5'b00000;
                        tx_data <= 8'hA9;
                        start   <= 1'b1;
                        state   <= WAIT_HEADER_DONE;
                    end
                end

                // 3. 헤더 전송 완료 대기
                WAIT_HEADER_DONE: begin
                    start <= 1'b0;
                    if (done) begin
                        // 헤더와 동시에 들어온 값은 사용하지 않고 다음 바이트에서 상태를 읽는다.
                        state <= READ_STATUS;
                    end
                end

                // 4. 별도 상태 바이트 수신
                READ_STATUS: begin
                    if (!busy) begin
                        tx_data <= 8'h00;
                        start   <= 1'b1;
                        state   <= WAIT_STATUS;
                    end
                end

                WAIT_STATUS: begin
                    start <= 1'b0;
                    if (done) begin
                        spi_error <= ~status_ready;
                        if (status_ready != 5'b00000) begin
                            state              <= READ_B1;
                        end else begin
                            ss_n               <= 5'b11111;
                            state              <= FRAME_DONE;
                        end
                    end
                end

                // 5. 바이트 1 수신
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
                        data_buf0[23:16] <= rx_data[ 7: 0];
                        data_buf1[23:16] <= rx_data[15: 8];
                        data_buf2[23:16] <= rx_data[23:16];
                        data_buf3[23:16] <= rx_data[31:24];
                        data_buf4[23:16] <= rx_data[39:32];
                        state           <= READ_B2;
                    end
                end

                // 6. 바이트 2 수신
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
                        data_buf0[15:8] <= rx_data[ 7: 0];
                        data_buf1[15:8] <= rx_data[15: 8];
                        data_buf2[15:8] <= rx_data[23:16];
                        data_buf3[15:8] <= rx_data[31:24];
                        data_buf4[15:8] <= rx_data[39:32];
                        state          <= READ_B3;
                    end
                end

                // 7. 바이트 3 수신
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
                        data_buf0[7:0] <= rx_data[ 7: 0];
                        data_buf1[7:0] <= rx_data[15: 8];
                        data_buf2[7:0] <= rx_data[23:16];
                        data_buf3[7:0] <= rx_data[31:24];
                        data_buf4[7:0] <= rx_data[39:32];
                        state           <= WRITE_MEM;
                    end
                end

                // 8. 메모리 쓰기 펄스
                WRITE_MEM: begin
                    state <= CHECK_LOOP;
                end

                // 9. 3180루프 검사
                CHECK_LOOP: begin
                    if (loop_cnt == 12'd3179) begin
                        ss_n  <= 5'b11111;
                        state <= FRAME_DONE;
                    end else begin
                        loop_cnt <= loop_cnt + 1;
                        state    <= READ_B1;
                    end
                end

                // 11. 완료 보고
                FRAME_DONE: begin
                    state <= FRAME_START;
                end

                default: state <= FRAME_START;
            endcase
        end
    end
endmodule


module spi_master (
    input logic clk,
    input logic reset,
    input logic cpol,  // idle 0: low, 1: high
    input logic cpha,  // first sampling, 0: first edge, 1: second edge
    input logic [7:0] clk_div,
    input logic [7:0] tx_data,
    input logic start,
    output logic [39:0] rx_data,
    output logic done,
    output logic busy,
    output logic sclk,
    output logic mosi,
    input logic [4:0] miso,
    output logic cs_n
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
    logic [7:0] tx_shift_reg;
    logic [7:0] rx_shift_reg0, rx_shift_reg1, rx_shift_reg2,
                rx_shift_reg3, rx_shift_reg4;
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
            end else begin
                div_cnt   <= 0;
                half_tick <= 1'b0;
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
            rx_shift_reg0 <= 0;
            rx_shift_reg1 <= 0;
            rx_shift_reg2 <= 0;
            rx_shift_reg3 <= 0;
            rx_shift_reg4 <= 0;
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
                                rx_shift_reg0 <= {rx_shift_reg0[6:0], miso[0]};
                                rx_shift_reg1 <= {rx_shift_reg1[6:0], miso[1]};
                                rx_shift_reg2 <= {rx_shift_reg2[6:0], miso[2]};
                                rx_shift_reg3 <= {rx_shift_reg3[6:0], miso[3]};
                                rx_shift_reg4 <= {rx_shift_reg4[6:0], miso[4]};
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
                                rx_shift_reg0 <= {rx_shift_reg0[6:0], miso[0]};
                                rx_shift_reg1 <= {rx_shift_reg1[6:0], miso[1]};
                                rx_shift_reg2 <= {rx_shift_reg2[6:0], miso[2]};
                                rx_shift_reg3 <= {rx_shift_reg3[6:0], miso[3]};
                                rx_shift_reg4 <= {rx_shift_reg4[6:0], miso[4]};
                            end

                            if (bit_cnt == 7) begin
                                state <= STOP;
                                if (!cpha) begin
                                    rx_data <= {rx_shift_reg4, rx_shift_reg3,
                                                rx_shift_reg2, rx_shift_reg1,
                                                rx_shift_reg0};
                                end else begin
                                    rx_data <= {
                                        rx_shift_reg4[6:0], miso[4],
                                        rx_shift_reg3[6:0], miso[3],
                                        rx_shift_reg2[6:0], miso[2],
                                        rx_shift_reg1[6:0], miso[1],
                                        rx_shift_reg0[6:0], miso[0]
                                    };
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
