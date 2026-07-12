`timescale 1ns / 1ps


module frameBuffer (
    // write side
    input  logic                       wclk,
    input  logic                       we,
    input  logic [$clog2(106*120)-1:0] wAddr,
    input  logic [               15:0] wData,
    // read side
    input  logic                       rclk,
    input  logic [$clog2(106*120)-1:0] rAddr,
    output logic [               15:0] rData
);

    logic [15:0] mem[0:(106*120)-1];

    //write
    always_ff @(posedge wclk) begin
        if (we) begin
            mem[wAddr] <= wData;
        end
    end
    //read
    always_ff @(posedge rclk) begin
        rData <= mem[rAddr];
    end
endmodule
