`timescale 1ns / 1ps

module Icon_Filter (
    input  logic        clk,
    input  logic        de,
    input  logic [ 9:0] x_pixel,
    input  logic [ 9:0] y_pixel,
    input  logic [ 5:0] sw_icon,
    input  logic [11:0] input_rgb,
    output logic [11:0] output_rgb
);

    // BASSOON
    localparam BASSOON_WIDTH = 20;
    localparam BASSOON_HEIGHT = 65;
    localparam BASSOON_X = 80;
    localparam BASSOON_Y = 10;

    // DRUM
    localparam DRUM_WIDTH = 40;
    localparam DRUM_HEIGHT = 36;
    localparam DRUM_X = 60;
    localparam DRUM_Y = 39;

    // CYMBALS
    // localparam CYMBALS_WIDTH = 35;
    // localparam CYMBALS_HEIGHT = 35;
    // localparam CYMBALS_X = 65;
    // localparam CYMBALS_Y = 40;

    // TRUMPET
    localparam TRUMPET_WIDTH = 32;
    localparam TRUMPET_HEIGHT = 46;
    localparam TRUMPET_X = 68;
    localparam TRUMPET_Y = 29;

    // VIOLIN
    localparam VIOLIN_WIDTH = 23;
    localparam VIOLIN_HEIGHT = 64;
    localparam VIOLIN_X = 77;
    localparam VIOLIN_Y = 11;

    // PIANO
    localparam PIANO_WIDTH = 41;
    localparam PIANO_HEIGHT = 32;
    localparam PIANO_X = 59;
    localparam PIANO_Y = 43;

    // NECKTIE
    localparam NECKTIE_WIDTH = 31;
    localparam NECKTIE_HEIGHT = 15;
    localparam NECKTIE_X = 37;
    localparam NECKTIE_Y = 65;

    logic        in_icon;
    logic [ 5:0] local_x;
    logic [ 6:0] local_y;
    logic [10:0] icon_addr;
    logic        icon_bit;

    logic [6:0] icon_width, icon_height;
    logic [9:0] icon_x, icon_y;

    logic [0:0] bassoon_mem[0:BASSOON_WIDTH * BASSOON_HEIGHT - 1];
    logic [0:0] drum_mem   [      0:DRUM_WIDTH * DRUM_HEIGHT - 1];
    // logic [0:0] cymbals_mem[0:CYMBALS_WIDTH * CYMBALS_HEIGHT - 1];
    logic [0:0] trumpet_mem[0:TRUMPET_WIDTH * TRUMPET_HEIGHT - 1];
    logic [0:0] violin_mem [  0:VIOLIN_WIDTH * VIOLIN_HEIGHT - 1];
    logic [0:0] piano_mem  [    0:PIANO_WIDTH * PIANO_HEIGHT - 1];
    logic [0:0] necktie_mem[0:NECKTIE_WIDTH * NECKTIE_HEIGHT - 1];

    initial begin
        $readmemb("01_bassoon_20x65_bin.mem", bassoon_mem);
        $readmemb("02_drum_40x36_bin.mem", drum_mem);
        // $readmemb("03_cymbals_35x35_bin.mem", cymbals_mem);
        $readmemb("04_trumpet_32x46_bin.mem", trumpet_mem);
        $readmemb("05_violin_23x64_bin.mem", violin_mem);
        $readmemb("06_piano_41x32_bin.mem", piano_mem);
        $readmemb("07_necktie_31x15_bin.mem", necktie_mem);
    end

    always_comb begin
        case (sw_icon)
            6'b000001: begin
                icon_width  = BASSOON_WIDTH;
                icon_height = BASSOON_HEIGHT;
                icon_x      = BASSOON_X;
                icon_y      = BASSOON_Y;
            end

            6'b000010: begin
                icon_width  = DRUM_WIDTH;
                icon_height = DRUM_HEIGHT;
                icon_x      = DRUM_X;
                icon_y      = DRUM_Y;
            end

            6'b000100: begin
                // icon_width = CYMBALS_WIDTH;
                // icon_height = CYMBALS_HEIGHT;
                // icon_x = CYMBALS_X;
                // icon_y = CYMBALS_Y;
                icon_width  = NECKTIE_WIDTH;
                icon_height = NECKTIE_HEIGHT;
                icon_x      = NECKTIE_X;
                icon_y      = NECKTIE_Y;
            end

            6'b001000: begin
                icon_width  = TRUMPET_WIDTH;
                icon_height = TRUMPET_HEIGHT;
                icon_x      = TRUMPET_X;
                icon_y      = TRUMPET_Y;
            end

            6'b010000: begin
                icon_width  = VIOLIN_WIDTH;
                icon_height = VIOLIN_HEIGHT;
                icon_x      = VIOLIN_X;
                icon_y      = VIOLIN_Y;
            end

            6'b100000: begin
                icon_width  = PIANO_WIDTH;
                icon_height = PIANO_HEIGHT;
                icon_x      = PIANO_X;
                icon_y      = PIANO_Y;
            end

            default: begin
                icon_width  = 0;
                icon_height = 0;
                icon_x      = 0;
                icon_y      = 0;
            end
        endcase
    end

    assign in_icon = de && (x_pixel >= icon_x) && (x_pixel < icon_x + icon_width) 
                    && (y_pixel >= icon_y) && (y_pixel < icon_y + icon_height);

    assign local_x = x_pixel - icon_x;
    assign local_y = y_pixel - icon_y;

    assign icon_addr = in_icon ? (local_y * icon_width + local_x) : 0;

    always_comb begin
        case (sw_icon)
            6'b000001: icon_bit = bassoon_mem[icon_addr];
            6'b000010: icon_bit = drum_mem[icon_addr];
            // 6'b000100: icon_bit = cymbals_mem[icon_addr];
            6'b000100: icon_bit = necktie_mem[icon_addr];
            6'b001000: icon_bit = trumpet_mem[icon_addr];
            6'b010000: icon_bit = violin_mem[icon_addr];
            6'b100000: icon_bit = piano_mem[icon_addr];
            default:   icon_bit = 1'b0;
        endcase
    end

    always_comb begin
        if (!de) begin
            output_rgb = 12'h000;
        end else if (in_icon) begin
            if (sw_icon == 6'b100000) begin
                // piano: 1은 검정 건반/선, 0은 흰 건반
                if (icon_bit) begin
                    output_rgb = 12'h000;
                end else begin
                    output_rgb = 12'hFFF;
                end
            end else begin
                // other instruments: 1만 출력, 0은 투명
                if (icon_bit) begin
                    output_rgb = 12'h000;
                end else begin
                    output_rgb = input_rgb;
                end
            end
        end else begin
            output_rgb = input_rgb;
        end
    end

endmodule
