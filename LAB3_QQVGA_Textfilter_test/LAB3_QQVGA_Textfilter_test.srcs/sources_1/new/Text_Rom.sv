`timescale 1ns / 1ps

module Text_Rom (

    input  logic [12:0] addr,  // {label_idx(4b), rel_y(4b), rel_x(5b)} = 13bit
    output logic        data
);
    logic [0:0] mem[0:2879];  

    initial begin
        $readmemb("TextRom.mem", mem);  // 0/1 텍스트라서 readmemb 사용
    end


    assign data = mem[addr][0];

endmodule
