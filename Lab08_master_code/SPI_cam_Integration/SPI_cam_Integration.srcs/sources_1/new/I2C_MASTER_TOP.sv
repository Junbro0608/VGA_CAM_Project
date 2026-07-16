`timescale 1ns / 1ps



module I2C_MASTER_TOP(
    input logic clk_100M,
    input logic reset,
    input logic [1:0] m_note,
    output logic [11:0] o_note,
    output logic       scl_s,
    inout  wire        sda_s

    );


  logic w_start_i2c;  // I2C 읽기 시작 틱
    
    // I2C 폴링 주기 카운터 (예: 200_000 카운트 = 2ms)
    start_counter #(
        .COUNT(200_000)
    ) U_START_COUNTER_I2C (
        .clk       (clk_100M),
        .rst       (reset),
        .start_tick(w_start_i2c)
    );

    // I2C Master FSM
    I2C_master_fsm U_I2C_MASTER_FSM (
        .clk          (clk_100M),
        .rst          (reset),
        .start_i2c_fsm(w_start_i2c),
        .m_note       (m_note),       // 최상단에서 2'b00으로 할당된 wire 연결
        .note         (o_note),       // 취합된 12비트 출력
        .scl          (scl_s),
        .sda          (sda_s),
        .done         ()
    );

endmodule
