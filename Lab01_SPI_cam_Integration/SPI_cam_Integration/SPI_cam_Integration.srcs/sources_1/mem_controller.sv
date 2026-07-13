`timescale 1ns / 1ps

module mem_controller (
    input  logic       clk,
    input  logic       reset,
    // Decoder
    input  logic       de,
    input  logic [9:0] x_pixel,
    input  logic [9:0] y_pixel,
    // SPI side
    output logic       SPI_start,
    input  logic [4:0] SPI_error,
    input  logic       SPI_fsm_done,
    // Mem write side
    output logic [4:0] w_sel,
    // Mem read side
    output logic [4:0] r_sel
);

    logic [4:0] r_sel_reg, w_sel_reg;
    logic       fsm_done_reg;
    logic [4:0] SPI_error_reg;

    assign r_sel = r_sel_reg;
    assign w_sel = w_sel_reg;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            r_sel_reg     <= 5'b00000;
            w_sel_reg     <= 5'b00000;  
            fsm_done_reg  <= 1'b0;
            SPI_error_reg <= 5'b00000;
            SPI_start     <= 1'b0;
        end else begin
            
            // [핵심 수정] 매 클럭마다 기본적으로 SPI_start를 0으로 낮춥니다.
            // 아래 조건문에서 1을 주더라도, 다음 클럭이 되면 이 구문에 의해 다시 0으로 돌아갑니다 (1클럭 펄스 생성).
            SPI_start <= 1'b0; 

            // 1. SPI 통신 완료 시 에러 상태 캡처 및 w_sel 제어
            if (SPI_fsm_done) begin
                fsm_done_reg  <= 1'b1;
                SPI_error_reg <= SPI_error;
                w_sel_reg     <= w_sel_reg ^ (~SPI_error);
            end

            // 2. VGA 1프레임 출력 완료 시 r_sel 제어 및 SPI 시작
            if (y_pixel == 480 && x_pixel == 0) begin
                if (fsm_done_reg) begin
                    r_sel_reg    <= r_sel_reg ^ (~SPI_error_reg); // 에러 없을 시 반전
                    fsm_done_reg <= 1'b0;
                    
                    // 여기서 1을 주면, 이번 클럭에서는 최상단의 <= 0 을 덮어쓰고 1이 됩니다.
                    SPI_start    <= 1'b1; 
                end 
                // 기존에 있던 쓸모없는 else 구문은 삭제했습니다.
            end
        end
    end

endmodule