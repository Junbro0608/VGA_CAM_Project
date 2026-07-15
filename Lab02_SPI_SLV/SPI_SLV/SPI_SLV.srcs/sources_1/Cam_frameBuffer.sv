`timescale 1ns / 1ps

module Cam_frameBuffer (
    input logic clk,
    input logic reset,

    input logic        we,
    input logic [13:0] wAddr,
    input logic [11:0] wData,
    input logic        frame_done,

    input  logic [13:0] rAddr,
    output logic [11:0] rData,

    input  logic sending,
    input  logic sender_busy,
    input  logic tx_done,
    output logic frame_ready
);

    logic [11:0] mem0[0:12719];
    logic [11:0] mem1[0:12719];

    logic w_sel;
    logic [11:0] rd0, rd1;
    logic tx_busy;

    assign tx_busy = sending | sender_busy;

    always_ff @(posedge clk) begin
        if (we) begin
            if (w_sel) begin
                mem1[wAddr] <= wData;
            end else begin
                mem0[wAddr] <= wData;
            end
        end
    end

    always_ff @(posedge clk) begin
        rd0 <= mem0[rAddr];
        rd1 <= mem1[rAddr];
    end
    assign rData = w_sel ? rd0 : rd1;

    always_ff @(posedge clk) begin
        if (reset) begin
            w_sel       <= 1'b0;
            frame_ready <= 1'b0;
        end else begin
            if (frame_done && !tx_busy) begin
                w_sel       <= ~w_sel;
                frame_ready <= 1'b1;
            end else if (tx_done) begin
                frame_ready <= 1'b0;
            end
        end
    end

endmodule

`timescale 1ns / 1ps

module framebuffer_1w4r (
    input  logic        clk,

    // ==========================================
    // ✍️ 1개의 쓰기 포트 (카메라 데이터 수신용)
    // ==========================================
    input  logic        we,
    input  logic [13:0] waddr,    // 106 * 120 = 12720 (최대 14비트 필요)
    input  logic [11:0] wdata,    // RGB444 (12비트)

    // ==========================================
    // 📖 4개의 읽기 포트 (YCoCg 인코더 2x2 블록 제공용)
    // ==========================================
    input  logic [13:0] raddr0,
    input  logic [13:0] raddr1,
    input  logic [13:0] raddr2,
    input  logic [13:0] raddr3,
    
    output logic [11:0] rdata0,
    output logic [11:0] rdata1,
    output logic [11:0] rdata2,
    output logic [11:0] rdata3
);

    // BRAM 추론을 강제하기 위한 메모리 4개 복제 선언
    // 하나의 쓰기 신호를 4개의 BRAM에 동시에 똑같이 저장하고, 읽을 때는 각자 따로 읽습니다.
    logic [11:0] mem0 [0:12719];
    logic [11:0] mem1 [0:12719];
    logic [11:0] mem2 [0:12719];
    logic [11:0] mem3 [0:12719];

    // ==========================================
    // BRAM 동기식 쓰기 및 읽기 처리
    // ==========================================
    always_ff @(posedge clk) begin
        // --- Write Port ---
        // 4개의 뱅크에 동일한 데이터를 동시에 기록합니다.
        if (we) begin
            mem0[waddr] <= wdata;
            mem1[waddr] <= wdata;
            mem2[waddr] <= wdata;
            mem3[waddr] <= wdata;
        end

        // --- Read Ports (1 Clock Latency) ---
        // 각각의 독립된 주소로 4개의 픽셀을 동시에 꺼냅니다.
        rdata0 <= mem0[raddr0];
        rdata1 <= mem1[raddr1];
        rdata2 <= mem2[raddr2];
        rdata3 <= mem3[raddr3];
    end
endmodule
