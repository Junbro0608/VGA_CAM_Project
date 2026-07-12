`timescale 1ns / 1ps

module spi_master_14bit (
    input wire clk,
    input wire reset,
    input wire cpol,  // idle 0: low, 1: high
    input wire cpha,  // first sampling, 0: first edge, 1: second edge
    input wire [7:0] clk_div,
    // 14비트 I/O로 확장
    input wire [13:0] tx_data,
    output reg [13:0] rx_data,
    input wire start,
    output reg done,
    output reg busy,
    output sclk,
    output reg mosi,
    input wire miso,
    output reg cs_n
);

    localparam [1:0] IDLE = 0, START = 1, DATA = 2, STOP = 3;

    reg [1:0] state;
    reg [7:0] div_cnt;
    reg       half_tick;
    reg [13:0] tx_shift_reg, rx_shift_reg;  // 14-bit 확장
    reg [3:0] bit_cnt;  // 0~13 카운트 (4-bit로 충분함)
    reg step, sclk_r;

    assign sclk = sclk_r;

    // 클럭 분주기
    always @(posedge clk or posedge reset) begin
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

    // 메인 상태 머신
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state        <= IDLE;
            mosi         <= 1'b1;
            cs_n         <= 1'b1;
            busy         <= 1'b0;
            done         <= 1'b0;
            tx_shift_reg <= 0;
            rx_shift_reg <= 0;
            bit_cnt      <= 0;
            step         <= 1'b0;
            rx_data      <= 0;
            sclk_r       <= cpol;
        end else begin
            done <= 1'b0;
            case (state)
                IDLE: begin
                    mosi   <= 1'b1;
                    cs_n   <= 1'b1;
                    sclk_r <= cpol;
                    if (start) begin
                        tx_shift_reg <= tx_data;
                        bit_cnt      <= 0;
                        step         <= 1'b0;
                        busy         <= 1'b1;
                        cs_n         <= 1'b0;
                        state        <= START;
                    end
                end

                START: begin
                    if (!cpha) begin
                        mosi <= tx_shift_reg[13];  // 14-bit 최상위 비트
                        tx_shift_reg <= {tx_shift_reg[12:0], 1'b0};
                    end
                    state <= DATA;
                end

                DATA: begin
                    if (half_tick) begin
                        sclk_r <= ~sclk_r;

                        if (step == 0) begin
                            step <= 1'b1;
                            if (!cpha) begin
                                rx_shift_reg <= {
                                    rx_shift_reg[12:0], miso
                                };  // 13-bit shift
                            end else begin
                                mosi         <= tx_shift_reg[13];
                                tx_shift_reg <= {tx_shift_reg[12:0], 1'b0};
                            end
                        end else begin
                            step <= 1'b0;
                            if (!cpha) begin
                                if (bit_cnt < 13) begin // 13까지 카운트 (총 14비트)
                                    mosi         <= tx_shift_reg[13];
                                    tx_shift_reg <= {tx_shift_reg[12:0], 1'b0};
                                end
                            end else begin
                                rx_shift_reg <= {rx_shift_reg[12:0], miso};
                            end

                            if (bit_cnt == 13) begin // 14번째 비트 도달 시
                                state <= STOP;
                                if (!cpha) begin
                                    rx_data <= rx_shift_reg;
                                end else begin
                                    rx_data <= {rx_shift_reg[12:0], miso};
                                end
                            end else begin
                                bit_cnt <= bit_cnt + 1;
                            end
                        end
                    end
                end

                STOP: begin
                    sclk_r <= cpol;
                    cs_n   <= 1'b1;
                    done   <= 1'b1;
                    busy   <= 1'b0;
                    mosi   <= 1'b1;
                    state  <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
