`timescale 1ns / 1ps

module OV7670_Music_Scale_Detect (
    input  logic        rclk,
    input  logic        reset,
    input  logic        vsync,
    input  logic [15:0] imgPxlData,
    input  logic [ 9:0] x_pixel,
    input  logic [ 9:0] y_pixel,
    output logic [ 1:0] data_lat
);
    localparam CHADO = 4'h2;

    logic vsync_edge;
    logic red_detect;
    logic [1:0] data;
    logic [3:0] red, green, blue;
    logic [3:0] max_val, min_val;

    assign red_detect = (red > green + 4'h2) && (red > blue + 4'h2) && ((max_val - min_val) > CHADO);
    assign red = imgPxlData[15:12];
    assign green = imgPxlData[10:7];
    assign blue = imgPxlData[4:1];
    assign max_val = (red > green) ? ((red > blue) ? red : blue) : ((green > blue) ? green : blue);
    assign min_val = (red < green) ? ((red < blue) ? red : blue) : ((green < blue) ? green : blue);

    always_ff @(posedge rclk) begin
        if (reset) begin
            vsync_edge <= 1'b0;
            data_lat   <= 2'b00;
            data       <= 2'b00;
        end else begin
            vsync_edge <= vsync;
            if (!vsync && vsync_edge) begin
                data_lat <= data;
                data     <= 2'b00;
            end else if (red_detect) begin
                if (y_pixel < 80) data <= 2'b00;
                else if (x_pixel > 1 && x_pixel < 36) data <= 2'b01;
                else if (x_pixel > 36 && x_pixel < 72) data <= 2'b10;
                else if (x_pixel > 72) data <= 2'b11;
            end
        end
    end

endmodule
