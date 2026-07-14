`timescale 1ns / 1ps

module UnScaleImage (
    input logic       de,
    input logic [9:0] x_pixel,
    input logic [9:0] y_pixel,

    // cam side (1번 위치: Top-Middle)
    output logic [$clog2(320*240)-1:0] cam_raddr,
    input  logic [               11:0] cam_rdata1,

    // mem side (나머지 5개 위치)
    output logic [$clog2(106*120/4)-1:0] mem_raddr,
    input  logic [                 23:0] mem_rdata0,
    input  logic [                 23:0] mem_rdata2,
    input  logic [                 23:0] mem_rdata3,
    input  logic [                 23:0] mem_rdata4,
    input  logic [                 23:0] mem_rdata5,

    // VGA side
    output logic [3:0] port_red,
    output logic [3:0] port_green,
    output logic [3:0] port_blue
);

    logic [23:0] mem_rdata_reg;
    logic        cam_flag;
    logic        border_flag;
    logic [3:0] Y_data, Co_data, Cg_data, temp_data;

    // ==========================================
    // 🧮 1. 로컬 좌표계 (Local Coordinates) 계산
    // ==========================================
    // 화면 어느 영역에 있든, 해당 박스 안에서의 상대 좌표(0~105, 0~119)를 구합니다.
    logic [9:0] local_x;
    logic [9:0] local_y;

    always_comb begin
        // Local Y 계산 (위아래 2분할)
        if (y_pixel >= 120) local_y = y_pixel - 120;
        else local_y = y_pixel;

        // Local X 계산 (좌/중/우 3분할, 106과 213 구분선 고려)
        if (x_pixel > 213) local_x = x_pixel - 214;  // 214 ~ 319 -> 0 ~ 105
        else if (x_pixel > 106) local_x = x_pixel - 107;  // 107 ~ 212 -> 0 ~ 105
        else local_x = x_pixel;  //   0 ~ 105 -> 0 ~ 105
    end

    // ==========================================
    // 📍 2. 메모리/카메라 주소(Address) 할당
    // ==========================================
    // 6개의 화면이 모두 같은 크기이므로, 계산된 로컬 좌표를 기반으로 주소를 계산합니다.

    // --- 카메라 (320x240 다운스케일링 읽기) ---
    logic [9:0] mapped_cam_x;
    logic [9:0] mapped_cam_y;

    // 로컬 좌표를 원본 320x240 비율로 변환
    assign mapped_cam_x = (local_x << 1) + local_x;  // local_x * 3
    assign mapped_cam_y = (local_y << 1);  // local_y * 2

    // 320x240 메모리의 1D 주소 = (Y * 320) + X
    assign cam_raddr    = de ? ((mapped_cam_y * 320) + mapped_cam_x) : '0;

    // --- 메모리 (2x2 압축 읽기) ---
    // 가로세로 >> 1 하여 주소 계산, 가로폭 53
    assign mem_raddr    = de ? ((local_y >> 1) * 53 + (local_x >> 1)) : '0;

    // ==========================================
    // 📺 3. 영역별 데이터 멀티플렉싱 (Mux)
    // ==========================================
    always_comb begin
        mem_rdata_reg = 0;
        cam_flag      = 0;
        border_flag   = 0;

        if (de) begin
            // 가로선 106과 213은 구분선(검은색) 처리
            if (x_pixel == 106 || x_pixel == 213) begin
                border_flag = 1;
            end else if (y_pixel < 120) begin
                // --- 윗줄 (Top Row) ---
                if (x_pixel < 106) begin
                    mem_rdata_reg = mem_rdata0;  // 0번 영역 (좌상단)
                end else if (x_pixel < 213) begin
                    cam_flag = 1;  // 1번 영역 (중상단 - 실시간 카메라)
                end else begin
                    mem_rdata_reg = mem_rdata2;  // 2번 영역 (우상단)
                end
            end else begin
                // --- 아랫줄 (Bottom Row) ---
                if (x_pixel < 106) begin
                    mem_rdata_reg = mem_rdata3;  // 3번 영역 (좌하단)
                end else if (x_pixel < 213) begin
                    mem_rdata_reg = mem_rdata4;  // 4번 영역 (중하단)
                end else begin
                    mem_rdata_reg = mem_rdata5;  // 5번 영역 (우하단)
                end
            end
        end
    end

    // ==========================================
    // 🎨 4. 데이터 추출 및 YCoCg 연산 (1:1 스케일)
    // ==========================================
    always_comb begin
        Cg_data = mem_rdata_reg[23:20];
        Co_data = mem_rdata_reg[19:16];

        // 1:1 출력이므로 픽셀 단위로 정확히 가져오기 위해 [0]번 비트 사용
        case ({
            local_y[0], local_x[0]
        })
            2'b00: Y_data = mem_rdata_reg[3:0];
            2'b01: Y_data = mem_rdata_reg[7:4];
            2'b10: Y_data = mem_rdata_reg[11:8];
            2'b11: Y_data = mem_rdata_reg[15:12];
        endcase

        temp_data = Y_data - Cg_data;
    end

    // ==========================================
    // 🖥️ 5. 최종 RGB 출력
    // ==========================================
    // border_flag가 1이거나 de가 0일 때는 모두 0(검은색)을 출력합니다.
    assign port_red   = (!de || border_flag) ? 4'd0 : (cam_flag) ? cam_rdata1[11:8] : (temp_data + Co_data);
    assign port_green = (!de || border_flag) ? 4'd0 : (cam_flag) ? cam_rdata1[7:4]  : (Y_data + Cg_data);
    assign port_blue  = (!de || border_flag) ? 4'd0 : (cam_flag) ? cam_rdata1[3:0]  : (temp_data - Co_data);
endmodule
