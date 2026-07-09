`timescale 1ns / 1ps


module tb_VGA_test ();
    logic       clk;
    logic       reset;
    logic       sw_mode;
    logic       sw_gray;
    // input  logic       sw_r,
    // input  logic       sw_g,
    // input  logic       sw_b,
    // input  logic [3:0] sw_red,
    // input  logic [3:0] sw_green,
    // input  logic [3:0] sw_blue,
    logic       h_sync;
    logic       v_sync;
    logic [3:0] port_red;
    logic [3:0] port_green;
    logic [3:0] port_blue;


    top_VGA dut (.*);

    always #5 clk = ~clk;

    initial begin
        
        clk     = 0;
        reset   = 1; // 리셋 먼저 가동
        sw_mode = 0; // DownScale 화면 모드 활성화 (1)
        sw_gray = 0; // 원본 컬러 모드

        // 100ns 후 리셋 해제하여 회로 가동
        #100;
        reset = 0;
        
        // 충분한 VGA 한 프레임 스케일(예: 20ms 이상) 동안 동작 관찰
        #20000000;
        $finish;
    end


endmodule