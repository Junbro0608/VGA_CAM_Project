`timescale 1ns / 1ps

module frameBuffer (
    input  logic                       wclk,
    input  logic                       we,
    input  logic [$clog2(320*240)-1:0] wAddr,
    input  logic [               15:0] wData,
    input  logic                       rclk,
    input  logic [$clog2(320*240)-1:0] rAddr,
    output logic [               15:0] rData
);

    logic [15:0] mem[0:(320*240)-1];

    always_ff @(posedge wclk) begin
        if (we) begin
            mem[wAddr] <= wData;
        end
    end

    always_ff @(posedge rclk) begin
        rData <= mem[rAddr];
    end

endmodule
