`timescale 1ns / 1ps

module ColorBar (
    input  logic [9:0] x_pixel,
    input  logic [9:0] y_pixel,
    input  logic       de,
    output logic [3:0] port_red,
    output logic [3:0] port_green,
    output logic [3:0] port_blue
);

    // localparam WHITE_R = 4'hf, WHITE_G = 4'hf, WHITE_B = 4'hf;
    localparam WHITE = 12'hfff;
    localparam YELLOW = 12'hff0;
    localparam CYAN = 12'h0ff;
    localparam GREEN = 12'h0f0;
    localparam MAGENTA = 12'hf0f;
    localparam RED = 12'hf00;
    localparam BLUE = 12'h00f;
    localparam GRAY = 12'h777;
    localparam LGRAY = 12'haaa;
    localparam DGRAY = 12'h333;
    localparam NAVY = 12'h258;
    localparam PURPLE = 12'h52a;
    localparam BLACK = 12'h000;

    always_comb begin
        if (de) begin
            if (y_pixel >= 0 && y_pixel < 320) begin
                if (x_pixel >= 0 && x_pixel < 91) begin
                    {port_red, port_green, port_blue} = WHITE;
                end else if (x_pixel >= 91 && x_pixel < 182) begin
                    {port_red, port_green, port_blue} = YELLOW;
                end else if (x_pixel >= 182 && x_pixel < 273) begin
                    {port_red, port_green, port_blue} = CYAN;
                end else if (x_pixel >= 273 && x_pixel < 364) begin
                    {port_red, port_green, port_blue} = GREEN;
                end else if (x_pixel >= 364 && x_pixel < 455) begin
                    {port_red, port_green, port_blue} = MAGENTA;
                end else if (x_pixel >= 455 && x_pixel < 546) begin
                    {port_red, port_green, port_blue} = RED;
                end else if (x_pixel >= 546 && x_pixel < 640) begin
                    {port_red, port_green, port_blue} = BLUE;
                end
            end else if (y_pixel >= 320 && y_pixel < 360) begin
                if (x_pixel >= 0 && x_pixel < 91) begin
                    {port_red, port_green, port_blue} = BLUE;
                end else if (x_pixel >= 91 && x_pixel < 182) begin
                    {port_red, port_green, port_blue} = BLACK;
                end else if (x_pixel >= 182 && x_pixel < 273) begin
                    {port_red, port_green, port_blue} = MAGENTA;
                end else if (x_pixel >= 273 && x_pixel < 364) begin
                    {port_red, port_green, port_blue} = BLACK;
                end else if (x_pixel >= 364 && x_pixel < 455) begin
                    {port_red, port_green, port_blue} = CYAN;
                end else if (x_pixel >= 455 && x_pixel < 546) begin
                    {port_red, port_green, port_blue} = BLACK;
                end else if (x_pixel >= 546 && x_pixel < 640) begin
                    {port_red, port_green, port_blue} = LGRAY;
                end
            end else if (y_pixel >= 360 && y_pixel < 480) begin
                if (x_pixel >= 0 && x_pixel < 115) begin
                    {port_red, port_green, port_blue} = NAVY;
                end else if (x_pixel >= 115 && x_pixel < 230) begin
                    {port_red, port_green, port_blue} = WHITE;
                end else if (x_pixel >= 230 && x_pixel < 345) begin
                    {port_red, port_green, port_blue} = PURPLE;
                end else if (x_pixel >= 345 && x_pixel < 455) begin
                    {port_red, port_green, port_blue} = DGRAY;
                end else if (x_pixel >= 455 && x_pixel < 491) begin
                    {port_red, port_green, port_blue} = BLACK;
                end else if (x_pixel >= 491 && x_pixel < 522) begin
                    {port_red, port_green, port_blue} = DGRAY;
                end else if (x_pixel >= 522 && x_pixel < 546) begin
                    {port_red, port_green, port_blue} = LGRAY;
                end else if (x_pixel >= 540 && x_pixel < 640) begin
                    {port_red, port_green, port_blue} = DGRAY;
                end
            end
        end else begin
            {port_red, port_green, port_blue} = BLACK;
        end
    end

endmodule
