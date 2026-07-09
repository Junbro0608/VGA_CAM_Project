`timescale 1ns / 1ps

module RGB_Filter (
    input  logic        sw_r,
    input  logic        sw_g,
    input  logic        sw_b,
    input  logic [11:0] port_rgb,
    output logic [11:0] port_rgb_out
);

    logic [2:0] sel;
    assign sel = {sw_r, sw_g, sw_b};

    always_comb begin
        case (sel)
            3'b000: port_rgb_out = {4'h0, 4'h0, 4'h0};
            3'b001: port_rgb_out = {4'h0, 4'h0, port_rgb[3:0]};
            3'b010: port_rgb_out = {4'h0, port_rgb[7:4], 4'h0};
            3'b011: port_rgb_out = {4'h0, port_rgb[7:4], port_rgb[3:0]};
            3'b100: port_rgb_out = {port_rgb[11:8], 4'h0, 4'h0};
            3'b101: port_rgb_out = {port_rgb[11:8], 4'h0, port_rgb[3:0]};
            3'b110: port_rgb_out = {port_rgb[11:8], port_rgb[7:4], 4'h0};
            3'b111: port_rgb_out = port_rgb;
        endcase

    end
endmodule
