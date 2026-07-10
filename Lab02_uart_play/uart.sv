`timescale 1 ns / 1 ps

module uart_top #(
    parameter CLK_FREQ  = 100_000_000,
    parameter BAUD_RATE = 115_200
) (
    input  wire       clk,      // 100MHz 시스템 마스터 클럭 (W5 핀 매핑)
    input  wire       rst,      // Reset (Active High - U18 중앙 버튼 매핑)
    
    // Basys3 물리 하드웨어 인터페이스
    input  wire [7:0] sw,       // 스위치 8개 (sw[1:0]: 음계, sw[4:2]: 악기코드)
    input  wire       btn_r,    // 전송 시작 트리거용 오른쪽 버튼 (T17 버튼 매핑)
    
    // UART 물리 핀 인터페이스
    output wire       tx,       // FPGA -> PC (TXD A18 핀 매핑)
    input  wire       rx        // PC -> FPGA (RXD B18 핀 매핑)
);

    // 내부 제어 신호 선언
    wire [7:0] w_tx_data;
    wire       w_tx_valid;
    wire       w_tx_ready;

    // 최상위 포트에서 제외된 수신 신호들을 내부 wire로 선언 (Undeclared Identifier 에러 방지)
    wire [7:0] rx_data;
    wire       rx_valid;

    // ====================================================
    // [하드웨어 디바운스 로직] 기계식 버튼 채터링 노이즈 제거
    // ====================================================
    reg [19:0] db_cnt;
    reg        btn_stable;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            db_cnt     <= 20'd0;
            btn_stable <= 1'b0;
        end else begin
            db_cnt <= db_cnt + 1'b1;
            if (db_cnt == 20'd0) begin
                btn_stable <= btn_r; // 약 10.4ms 마다 버튼 상태를 안정적으로 샘플링
            end
        end
    end

    // ====================================================
    // [라이징 엣지 디텍터] 버튼을 누른 순간 딱 1클럭만 신호 생성
    // ====================================================
    reg btn_stable_d;
    wire btn_pulse;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            btn_stable_d <= 1'b0;
        end else begin
            btn_stable_d <= btn_stable;
        end
    end
    
    // 이전엔 0이었고 지금 1인 순간 감지 (Rising Edge Trigger)
    assign btn_pulse = btn_stable && !btn_stable_d;

    // ====================================================
    // [TX 데이터 래치 제어 회로]
    // ====================================================
    reg [7:0] r_tx_data;
    reg       r_tx_valid;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            r_tx_data  <= 8'h00;
            r_tx_valid <= 1'b0;
        end else begin
            if (btn_pulse && w_tx_ready) begin
                r_tx_data  <= sw;       // 버튼이 눌린 바로 그 순간의 스위치 값을 락(Latch)
                r_tx_valid <= 1'b1;     // 송신 시작 플래그 1클럭 턴 온
            end else begin
                r_tx_valid <= 1'b0;     // 연속 전송 방지를 위해 즉시 다운
            end
        end
    end

    assign w_tx_data  = r_tx_data;
    assign w_tx_valid = r_tx_valid;

    // ====================================================
    // 서브 IP 모듈 인스턴스화 (Active High rst 매핑)
    // ====================================================
    uart_tx #(
        .CLK_FREQ (CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) u_tx (
        .clk    (clk),
        .rst    (rst),
        .data_in(w_tx_data),
        .valid  (w_tx_valid),
        .ready  (w_tx_ready),
        .tx     (tx)
    );

    uart_rx #(
        .CLK_FREQ (CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) u_rx (
        .clk     (clk),
        .rst     (rst),
        .rx      (rx),
        .data_out(rx_data),
        .valid   (rx_valid)
    );

endmodule


// ====================================================
// UART 수신기 (Active High posedge 리셋 구동)
// ====================================================
module uart_rx #(
    parameter CLK_FREQ  = 100_000_000,
    parameter BAUD_RATE = 115_200
) (
    input  wire       clk,
    input  wire       rst,
    input  wire       rx,        
    output reg  [7:0] data_out,  
    output reg        valid      
);

    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    localparam HALF_BIT     = CLKS_PER_BIT / 2;

    localparam S_IDLE  = 2'd0;
    localparam S_START = 2'd1;
    localparam S_DATA  = 2'd2;
    localparam S_STOP  = 2'd3;

    reg [                   1:0] state;
    reg [$clog2(CLKS_PER_BIT):0] clk_cnt;
    reg [                   2:0] bit_idx;
    reg [                   7:0] shift_reg;
    reg rx_sync0, rx_sync;

    // 동기화 플립플롭의 비동기 리셋 셋업 (메타스테이빌리티 방지)
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rx_sync0 <= 1'b1;
            rx_sync  <= 1'b1;
        end else begin
            rx_sync0 <= rx;
            rx_sync  <= rx_sync0;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state     <= S_IDLE;
            clk_cnt   <= 0;
            bit_idx   <= 0;
            shift_reg <= 8'h00;
            data_out  <= 8'h00;
            valid     <= 1'b0;
        end else begin
            valid <= 1'b0;

            case (state)
                S_IDLE: begin
                    clk_cnt <= 0;
                    bit_idx <= 0;
                    if (rx_sync == 1'b0)
                        state <= S_START;
                end

                S_START: begin
                    if (clk_cnt == HALF_BIT - 1) begin
                        clk_cnt <= 0;
                        if (rx_sync == 1'b0)
                            state <= S_DATA;
                        else 
                            state <= S_IDLE;
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end

                S_DATA: begin
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt            <= 0;
                        shift_reg[bit_idx] <= rx_sync;
                        if (bit_idx == 3'd7) begin
                            state <= S_STOP;
                        end else begin
                            bit_idx <= bit_idx + 1;
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end

                S_STOP: begin
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt  <= 0;
                        data_out <= shift_reg;
                        valid    <= 1'b1;
                        state    <= S_IDLE;
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end
endmodule


// ====================================================
// UART 송신기 (Active High posedge 리셋 구동)
// ====================================================
module uart_tx #(
    parameter CLK_FREQ  = 100_000_000,
    parameter BAUD_RATE = 115_200
) (
    input  wire       clk,
    input  wire       rst,
    input  wire [7:0] data_in,  
    input  wire       valid,    
    output reg        ready,    
    output reg        tx        
);

    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    
    localparam S_IDLE  = 2'd0;
    localparam S_START = 2'd1;
    localparam S_DATA  = 2'd2;
    localparam S_STOP  = 2'd3;

    reg [                   1:0] state;
    reg [$clog2(CLKS_PER_BIT):0] clk_cnt;
    reg [                   2:0] bit_idx;
    reg [                   7:0] shift_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state     <= S_IDLE;
            clk_cnt   <= 0;
            bit_idx   <= 0;
            shift_reg <= 8'h00;
            tx        <= 1'b1;  // Idle 상태 시 통신 라인은 High 유지
            ready     <= 1'b1;
        end else begin
            case (state)
                S_IDLE: begin
                    tx    <= 1'b1;
                    ready <= 1'b1;
                    if (valid) begin
                        shift_reg <= data_in;
                        clk_cnt   <= 0;
                        ready     <= 1'b0;
                        state     <= S_START;
                    end
                end

                S_START: begin
                    tx <= 1'b0; // Start Bit 출력 (Low 드롭)
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= 0;
                        bit_idx <= 0;
                        state   <= S_DATA;
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end

                S_DATA: begin
                    tx <= shift_reg[bit_idx]; // LSB부터 8비트 데이터 직렬화 출력
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= 0;
                        if (bit_idx == 3'd7) begin
                            state <= S_STOP;
                        end else begin
                            bit_idx <= bit_idx + 1;
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end

                S_STOP: begin
                    tx <= 1'b1; // Stop Bit 출력 (High 복귀)
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= 0;
                        state   <= S_IDLE;
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end
endmodule