`timescale 1ns / 1ps


module LineBufferx2 (
    // write side
    input  logic                   wclk,
    input  logic                   we,
    input  logic                   wline,
    input  logic [$clog2(106)-1:0] wAddr,
    input  logic [           15:0] wData,
    // read side
    input  logic                   rline,
    input  logic                   rclk,
    input  logic [$clog2(106)-1:0] rAddr,
    output logic [           15:0] rData
);

    logic [15:0] mem0[0:106-1];
    logic [15:0] mem1[0:106-1];

    //write
    always_ff @(posedge wclk) begin
        if (we) begin
            if (wline == 1) mem1[wAddr] <= wData;
            else mem0[wAddr] <= wData;
        end
    end
    //read
    always_ff @(posedge rclk) begin
        if (wline == 1) rData <= mem1[rAddr];
        else rData <= mem0[rAddr];
    end
endmodule
