`timescale 1ns / 1ps


module noise_debounce #(
    parameter COOLDOWN_MS = 500 // 500ms 쿨다운
)(
    input  logic clk,
    input  logic reset,
    input  logic [1:0] data_lat,
    output logic o_start_tick
);

    // clock divider for debounce shift register
    // 100Mhz -> 100Khz
    // counter = 100M/100K = 1000
    parameter CLK_DIV = 100_000;
    parameter F_COUNT = 100_000_000 / CLK_DIV;
    reg [$clog2(1000)-1:0] counter_reg;
    logic i_data;

    assign i_data = (data_lat != 2'b00) ? 1 : 0;

    reg clk_100khz_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_reg <= 0;
            clk_100khz_reg <= 1'b0;
        end else begin
            counter_reg <= counter_reg + 1;
            if (counter_reg == F_COUNT - 1) begin
                counter_reg <= 0;
                clk_100khz_reg <= 1'b1;
            end else begin
                clk_100khz_reg <= 1'b0;
            end
        end
    end

    // series 8 tap F/F (8bit Shift Register)
    reg [7:0] q_reg, q_next;
    //reg [7:0] debounce_reg;
    wire debounce;

    // SL
    always @(posedge clk_100khz_reg, posedge reset) begin
        if (reset) begin
            q_reg <= 0;
        end else begin
            // 
            q_reg <= q_next;
            //debounce_reg <= {i_btn, debounce_reg[7:1]}
        end
    end

    // next CL
    always @(*) begin
        q_next = {i_data, q_reg[7:1]};
    end

    // debounce, 8input AND
    assign debounce = &q_reg;

    parameter COOLDOWN_MAX = (100_000_000 / 1000) * COOLDOWN_MS;

    reg [$clog2(COOLDOWN_MAX)-1:0] cooldown_cnt;
    reg cooldown_active;
    reg edge_reg;

    // edge detection
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            edge_reg <= 1'b0;
            cooldown_cnt <= 0;
            cooldown_active <= 1'b0;
            o_start_tick <= 1'b0;
        end else begin
            edge_reg <= debounce;
            o_start_tick <= 1'b0;

            if (cooldown_active) begin
                if (cooldown_cnt == COOLDOWN_MAX - 1) begin
                    cooldown_active <= 1'b0;
                    cooldown_cnt <= 0;
                end else begin
                    cooldown_cnt <= cooldown_cnt + 1;
                end
            end else begin
                // no cooldown
                if (debounce & ~edge_reg) begin
                    o_start_tick <= 1'b1;
                    cooldown_active <= 1'b1;
                    cooldown_cnt <= 0;
                end
            end
        end
    end
endmodule
