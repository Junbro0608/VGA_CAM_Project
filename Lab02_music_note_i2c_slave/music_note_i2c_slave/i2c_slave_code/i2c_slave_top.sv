`timescale 1ns / 1ps

module i2c_slave_top (
    input  logic        clk,
    input  logic        reset,
    input  logic [15:0] sw,
    input  logic        scl,
    inout  wire         sda,
    output logic [ 3:0] fnd_digit,
    output logic [ 7:0] fnd_data
);

    logic [7:0] rx_data;
    logic done;
    logic [7:0] fnd_in;

    i2c_slave U_I2C_SLAVE (
        .clk(clk),
        .reset(reset),
        .tx_data(sw[7:0]),
        .rx_data(rx_data),
        .done(done),
        .scl(scl),
        .sda(sda)
    );

    fnd_controller U_FND_CNTRL (
        .clk(clk),
        .reset(reset),
        .fnd_in_data(fnd_in),
        .fnd_digit(fnd_digit),
        .fnd_data(fnd_data)
    );

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            fnd_in <= 0;
        end else begin
            if (done) begin
                fnd_in <= rx_data;
            end
        end
    end
endmodule
