`timescale 1ns / 1ps

module text_rom (

    input logic [12:0] addr,
    output logic data_rom
);
    logic [0:0] mem[0:1439];

    initial begin
        $readmemb("rom_violin_text.mem", mem);
    end

    assign data_rom = mem[addr][0];

endmodule
