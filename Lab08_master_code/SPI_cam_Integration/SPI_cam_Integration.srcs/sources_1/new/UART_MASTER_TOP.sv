`timescale 1ns / 1ps



module UART_MASTER_TOP(
    input logic clk_100M,
    input logic reset,
    input logic [11:0] note,
      input  logic       rx,
    output logic       tx

    );
    logic w_start_uart, w_u_start;
    logic [7:0]  w_tx_data;


     // UART 전송 주기 카운터 (예: 100M 카운트 = 1초)
    start_counter #(
        .COUNT(100_000_000)
    ) U_START_COUNTER_UART (
        .clk       (clk_100M),
        .rst       (reset),
        .start_tick(w_start_uart)
    );

    // UART 전송 통제 FSM
    uart_master_fsm U_UART_MST_FSM (
        .clk    (clk_100M),
        .rst    (reset),
        .i_start(w_start_uart),
        .note   (note),             // I2C FSM에서 조립된 12비트 입력
        .done   (),             // UART 전송 모듈의 1바이트 전송 완료 응답
        .tx_data(w_tx_data),
        .o_start(w_u_start)
    );

    // UART 송수신 물리 모듈
    uart_top U_UART_TOP (
        .clk     (clk_100M),          // 100MHz 시스템 클럭 사용
        .rst     (reset),
        .tx_data (w_tx_data),
        .tx_valid(w_u_start),
        .tx_done (),
        .tx_ready(),
        .tx      (tx),
        .rx      (rx)
    );


endmodule
