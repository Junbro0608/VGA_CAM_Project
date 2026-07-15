`timescale 1ns / 1ps

module ycocg_encoder (
    input  logic        clk,
    input  logic        reset,
    input  logic        start,

    // Frame Buffer (BRAM) 읽기 포트
    output logic [13:0] raddr0,     // $clog2(106*120) = 14비트
    output logic [13:0] raddr1,
    output logic [13:0] raddr2,
    output logic [13:0] raddr3,
    input  logic [11:0] rdata0,     // {R[3:0], G[3:0], B[3:0]}
    input  logic [11:0] rdata1,
    input  logic [11:0] rdata2,
    input  logic [11:0] rdata3,
    
    // 디코더 완벽 호환: ycocg_data = {Y3(4), Y2(4), Y1(4), Y0(4), Co(4), Cg(4)}
    output logic [23:0] ycocg_data
);

    // ==========================================
    // 내부 제어 신호
    // ==========================================
    logic       running;        // 주소 생성기가 동작 중임을 나타냄
    logic       is_last_pixel;  // 현재 픽셀이 프레임의 마지막인지 판별

    // ==========================================
    // 곱셈기 제거(Multiplier-Free)를 위한 주소 카운터
    // ==========================================
    logic [6:0]  x_cnt;         // 가로 픽셀 카운터: 0, 2, 4 ... 104
    logic [13:0] row_base;      // 현재 윗줄(Row 0)의 시작 주소
    logic [13:0] next_row_base; // 현재 아랫줄(Row 1)의 시작 주소

    assign is_last_pixel = (x_cnt == 7'd104) && (row_base == 14'd12508);

    // ==========================================
    // YCoCg 연산 로직 (조합 회로 - 클럭 지연 없이 즉시 계산)
    // ==========================================
    logic [3:0] r0, g0, b0, r1, g1, b1, r2, g2, b2, r3, g3, b3;
    
    assign {r0, g0, b0} = rdata0;
    assign {r1, g1, b1} = rdata1;
    assign {r2, g2, b2} = rdata2;
    assign {r3, g3, b3} = rdata3;

    logic [3:0] y0, y1, y2, y3;
    logic [3:0] co, cg;

    always_comb begin
        // 1. 명도(Y) 계산
        y0 = ( {2'b0, r0} + ({1'b0, g0} << 1) + {2'b0, b0} ) >> 2;
        y1 = ( {2'b0, r1} + ({1'b0, g1} << 1) + {2'b0, b1} ) >> 2;
        y2 = ( {2'b0, r2} + ({1'b0, g2} << 1) + {2'b0, b2} ) >> 2;
        y3 = ( {2'b0, r3} + ({1'b0, g3} << 1) + {2'b0, b3} ) >> 2;

        // 2. 색차 연산을 위한 2x2 블록 평균 R, G, B
        logic [5:0] sum_r = {2'b0, r0} + {2'b0, r1} + {2'b0, r2} + {2'b0, r3};
        logic [5:0] sum_g = {2'b0, g0} + {2'b0, g1} + {2'b0, g2} + {2'b0, g3};
        logic [5:0] sum_b = {2'b0, b0} + {2'b0, b1} + {2'b0, b2} + {2'b0, b3};

        logic [3:0] avg_r = sum_r >> 2;
        logic [3:0] avg_g = sum_g >> 2;
        logic [3:0] avg_b = sum_b >> 2;

        // 3. 색차(Co, Cg) Signed 연산 및 Offset Binary(+8) 변환
        logic signed [5:0] s_r = $signed({2'b00, avg_r});
        logic signed [5:0] s_g = $signed({2'b00, avg_g});
        logic signed [5:0] s_b = $signed({2'b00, avg_b});

        logic signed [5:0] s_co = (s_r - s_b) >>> 1;
        logic signed [5:0] s_cg = ((s_g <<< 1) - s_r - s_b) >>> 2;

        logic [5:0] co_offset = s_co + 6'sd8;
        logic [5:0] cg_offset = s_cg + 6'sd8;

        co = co_offset[3:0];
        cg = cg_offset[3:0];
    end

    // 🌟 파이프라인 지연 없이 조합 회로로 즉시 출력 (다음 클럭에 rdata가 나오면 바로 반영됨)
    assign ycocg_data = {y3, y2, y1, y0, co, cg};

    // ==========================================
    // 🚀 주소 생성 카운터
    // ==========================================
    always_ff @(posedge clk) begin
        if (reset) begin
            running       <= 1'b0;
            raddr0        <= 0; raddr1 <= 0; raddr2 <= 0; raddr3 <= 0;
            x_cnt         <= 0;
            row_base      <= 0;
            next_row_base <= 14'd106; 
        end else begin
            
            // 1. 시작 트리거 감지
            if (start && !running) begin
                running       <= 1'b1;
                x_cnt         <= 0;
                row_base      <= 0;
                next_row_base <= 14'd106;
            end

            // 2. 메모리 주소 연속 생성 (매 클럭마다)
            if (running) begin
                raddr0 <= row_base + x_cnt;             
                raddr1 <= row_base + x_cnt + 1;         
                raddr2 <= next_row_base + x_cnt;        
                raddr3 <= next_row_base + x_cnt + 1;    

                if (is_last_pixel) begin
                    running <= 1'b0; // 모두 요청 완료
                end else if (x_cnt == 7'd104) begin
                    x_cnt         <= 0;
                    row_base      <= row_base + 14'd212;      
                    next_row_base <= next_row_base + 14'd212; 
                end else begin
                    x_cnt <= x_cnt + 2;
                end
            end
        end
    end

endmodule