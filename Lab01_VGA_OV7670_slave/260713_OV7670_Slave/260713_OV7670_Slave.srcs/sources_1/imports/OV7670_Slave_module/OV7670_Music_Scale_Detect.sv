`timescale 1ns / 1ps

module OV7670_Music_Scale_Detect (
    input  logic        clk,
    input  logic        reset,
    input  logic        p_tick,
    input  logic        vsync,
    input  logic [15:0] imgPxlData,
    input  logic [ 9:0] x_pixel,
    input  logic [ 9:0] y_pixel,
    output logic [ 1:0] data_lat
);

    logic vsync_edge;
    logic red_detect;
    logic [1:0] data;
    logic [3:0] red, green, blue;
    logic [3:0] max_val, min_val;

    assign red = imgPxlData[15:12];
    assign green = imgPxlData[10:7];
    assign blue = imgPxlData[4:1];

    assign max_val = (red > green) ? ((red > blue) ? red : blue)
                                   : ((green > blue) ? green : blue);
    assign min_val = (red < green) ? ((red < blue) ? red : blue)
                                   : ((green < blue) ? green : blue);

    assign red_detect = ({1'b0, red} > {1'b0, green} + 5'd2)
                     && ({1'b0, red} > {1'b0, blue}  + 5'd2)
                     && (({1'b0, max_val} - {1'b0, min_val}) > 5'd2);

    always_ff @(posedge clk) begin
        if (reset) begin
            vsync_edge <= 1'b0;
            data_lat   <= 2'b00;
            data       <= 2'b00;
        end else if (p_tick) begin
            vsync_edge <= vsync;
            if (!vsync && vsync_edge) begin
                data_lat <= data;
                data     <= 2'b00;
            end else if (red_detect && (y_pixel >= 80) && (y_pixel < 120)) begin
                if (x_pixel < 36) data <= 2'b01;
                else if (x_pixel < 72) data <= 2'b10;
                else if (x_pixel < 106) data <= 2'b11;
            end
        end
    end

endmodule
