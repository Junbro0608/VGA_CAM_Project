`timescale 1ns / 1ps

module ImgRomReader (
    input  logic                         de,
    input  logic [                  9:0] x_pixel,
    input  logic [                  9:0] y_pixel,
    output logic [$clog2(106*120) - 1:0] addr,
    input  logic [                 15:0] imgPxlData,
    output logic [                  3:0] port_red,
    output logic [                  3:0] port_green,
    output logic [                  3:0] port_blue
);

logic displayArea;

assign displayArea = de && (x_pixel < 106) && (y_pixel < 120);

    assign addr = displayArea ? (106 * y_pixel + x_pixel) : 0;
    assign {port_red, port_green, port_blue} 
                = displayArea ? {imgPxlData[15:12], imgPxlData[10:7], imgPxlData[4:1]} : 0;

endmodule
