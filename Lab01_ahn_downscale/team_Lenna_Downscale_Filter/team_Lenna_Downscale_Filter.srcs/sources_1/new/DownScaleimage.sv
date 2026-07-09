`timescale 1ns / 1ps


module DownScaleimage(
    input logic de,
    input logic [9:0] x_pixel,
    input logic [9:0] y_pixel,
    output logic [$clog2(160*120)-1:0] addr,
    input logic [15:0] imgPxlData,
    output logic [3:0] port_red,
    output logic [3:0] port_green,
    output logic [3:0] port_blue
);

    logic [9:0] rom_x;
    logic [9:0] rom_y;
    logic valid_area;

    assign valid_area = (x_pixel < 106) && (y_pixel <120);

    assign rom_x = x_pixel + (x_pixel >> 1);
    assign rom_y = y_pixel;

    assign addr = (de && valid_area) ? (160 * rom_y + rom_x) : 'bz;

    assign {port_red, port_green, port_blue} = (de && valid_area) ? {imgPxlData[15:12], imgPxlData[10:7], imgPxlData[4:1]} : 0;


endmodule
