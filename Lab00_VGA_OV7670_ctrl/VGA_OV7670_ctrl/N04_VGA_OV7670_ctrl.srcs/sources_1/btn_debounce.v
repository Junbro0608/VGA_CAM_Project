`timescale 1ns / 1ps

//btn_rising_egde_detection
module btn_debounce (
    input  clk,
    input  reset,
    input  i_btn,
    output o_btn
);

    // clock divider for debounce shift register
    //199Mhz -> 100khz
    //counter = 100M/100K = 1000
    parameter CLK_DIV = 100_000;
    parameter  F_COUNT = 100_000_000 / CLK_DIV;
    reg [$clog2(F_COUNT)-1:0] counter_reg;
    
    reg clk_100khz_reg;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            counter_reg <= 0;
            clk_100khz_reg <= 1'b0;
        end else begin
            counter_reg <= counter_reg + 1;
            if (counter_reg == (F_COUNT-1)) begin
                counter_reg <= 0;
                clk_100khz_reg <= 1'b1;
            end else begin
                clk_100khz_reg <= 1'b0;
            end
        end
    end


    // series 8 tap F/F
    reg [7:0] q_reg, q_next;
    wire debounce;

    // SL
    always @(posedge clk_100khz_reg or posedge reset) begin
        if(reset) begin
            q_reg <= 8'b0;
        end else begin
            q_reg = q_next;
        end
    end

    //next CL
    always @(*) begin
        q_next = {i_btn,q_reg[7:1]};
    end

    //debounce, 8input AND
    assign debounce = &q_reg;

    reg edge_reg;

    //edge detection
    always @(posedge clk, posedge reset) begin
        if(reset) begin
            edge_reg <= 1'b0;
        end else begin
            edge_reg <= debounce;
        end
    end

    assign o_btn = debounce && ~edge_reg;
endmodule