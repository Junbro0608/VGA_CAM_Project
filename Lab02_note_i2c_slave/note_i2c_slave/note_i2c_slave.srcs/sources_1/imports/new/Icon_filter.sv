`timescale 1ns / 1ps

module Icon_Filter (
    input  logic        de,
    input  logic [ 9:0] x_pixel,
    input  logic [ 9:0] y_pixel,
    input  logic [11:0] input_rgb,
    output logic [11:0] output_rgb
);

    // VIOLIN
    localparam VIOLIN_WIDTH = 23;
    localparam VIOLIN_HEIGHT = 64;
    localparam VIOLIN_X = 77;
    localparam VIOLIN_Y = 11;

    logic        in_icon;
    logic [ 5:0] local_x;
    logic [ 6:0] local_y;
    logic [10:0] icon_addr;
    logic        icon_bit;

    logic [6:0] icon_width, icon_height;
    logic [9:0] icon_x, icon_y;

    logic [0:0] violin_mem[0:VIOLIN_WIDTH * VIOLIN_HEIGHT - 1];

    initial begin
        $readmemb("rom_violin_picture.mem", violin_mem);
    end

    always_comb begin
        icon_width  = VIOLIN_WIDTH;
        icon_height = VIOLIN_HEIGHT;
        icon_x      = VIOLIN_X;
        icon_y      = VIOLIN_Y;
    end

    assign in_icon = de && (x_pixel >= icon_x) && (x_pixel < icon_x + icon_width) 
                    && (y_pixel >= icon_y) && (y_pixel < icon_y + icon_height);

    assign local_x = x_pixel - icon_x;
    assign local_y = y_pixel - icon_y;

    assign icon_addr = in_icon ? (local_y * icon_width + local_x) : 0;

    assign icon_bit = violin_mem[icon_addr];

    always_comb begin
        if (!de) begin
            output_rgb = 12'h000;
        end else if (in_icon) begin
            if (icon_bit) begin
                output_rgb = 12'h000;
            end else begin
                output_rgb = input_rgb;
            end
        end else begin
            output_rgb = input_rgb;
        end
    end

endmodule
