`timescale 1ns / 1ps

// select R,G,B
module rgb_filter (
    input  logic [ 2:0] sel,
    input  logic [11:0] input_rgb,
    output logic [11:0] port_rgb
);


    assign port_rgb[11:8] = sel[2] ? input_rgb[11:8] : 0;
    assign port_rgb[7:4]  = sel[1] ? input_rgb[7:4] : 0;
    assign port_rgb[3:0]  = sel[0] ? input_rgb[3:0] : 0;


endmodule

// grayscale(ITI-R BT.601 : Gray = 0.299*R + 0.587*G + 0.114*B)
// 256 밝기 기준 : R : G : B = 3 : 6 : 1 = 76.8 : 153.6 : 25.6 = 76 : 154 : 26
// 곱셉 => shift 최적화 
module grayscale_filter (
    input  logic [11:0] in_rgb,
    output logic [11:0] port_gray
);
    logic [11:0] gray_data;

    assign gray_data = ((in_rgb[11:8] << 6) + (in_rgb[11:8]<<3) + (in_rgb[11:8]<<2))+
                       ((in_rgb[7:4]<<7) + (in_rgb[7:4]<<4) + (in_rgb[7:4]<<3) + (in_rgb[7:4]<<1))+
                       ((in_rgb[3:0]<<4) + (in_rgb[3:0]<<3) + (in_rgb[3:0]<<1));
    assign port_gray = {gray_data[11:8], gray_data[11:8], gray_data[11:8]};

endmodule
