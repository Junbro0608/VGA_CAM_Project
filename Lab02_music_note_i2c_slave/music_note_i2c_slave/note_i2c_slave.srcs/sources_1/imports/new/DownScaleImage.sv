`timescale 1ns / 1ps

module DownScaleimage (
    input logic rclk,
    input logic reset,
    input logic de,
    input logic [9:0] x_pixel,
    input logic [9:0] y_pixel,
    output logic [$clog2(320*240)-1:0] addr,
    input logic [15:0] imgPxlData,
    output logic [3:0] port_red,
    output logic [3:0] port_green,
    output logic [3:0] port_blue
);

    logic de_d;
    logic [9:0] rom_x;
    logic [9:0] rom_y;
    logic valid_area;
    logic valid_area_d;

    assign valid_area = (x_pixel < 106) && (y_pixel < 120);

    assign rom_x = (x_pixel << 1) + x_pixel;
    assign rom_y = (y_pixel << 1);

    assign addr = (de && valid_area) ? (320 * rom_y + rom_x) : 'bz;

    always_ff @(posedge rclk) begin
        if (reset) begin
            de_d <= '0;
            valid_area_d <= '0;
        end else begin
            de_d <= de;
            valid_area_d <= valid_area;
        end
    end

    assign {port_red, port_green, port_blue} = (de_d && valid_area_d) ? {imgPxlData[15:12], imgPxlData[10:7], imgPxlData[4:1]} : 0;


endmodule
