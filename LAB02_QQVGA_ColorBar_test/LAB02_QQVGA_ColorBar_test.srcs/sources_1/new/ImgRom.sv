`timescale 1ns / 1ps

module ImgROM (
    input  logic [$clog2(106*120)-1:0] addr,
    output logic [               15:0] data
);
    logic [15:0] mem[0:106*120-1];

    initial begin
        $readmemh("Marron.mem", mem);
    end

    assign data = mem[addr];
endmodule
 