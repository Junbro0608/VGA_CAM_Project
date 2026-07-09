`timescale 1ns / 1ps

module ImgROM (
    input logic [$clog2(160*120)-1:0] addr,
    output logic [15:0] data
);
    logic [15:0] mem[0:160*120-1];

    initial begin
        $readmemh("Lenna_160x120.mem", mem);
    end

    assign data = mem[addr];
endmodule
