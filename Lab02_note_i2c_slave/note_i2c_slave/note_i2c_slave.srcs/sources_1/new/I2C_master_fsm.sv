`timescale 1ns / 1ps

module I2C_master_fsm (
    input  logic        clk,
    input  logic        rst,
    input  logic        start_i2c_fsm,
    input  logic [ 1:0] m_note,
    output logic [11:0] note,
    output logic        scl,
    inout  wire         sda

);

    typedef enum logic [2:0] {
        IDLE,
        SLV1,
        SLV2,
        SLV3,
        SLV4,
        SLV5
    } i2c_master_e;


    localparam SLA_R1 = {7'h01, 1'b1};
    localparam SLA_R2 = {7'h02, 1'b1};
    localparam SLA_R3 = {7'h04, 1'b1};
    localparam SLA_R4 = {7'h08, 1'b1};
    localparam SLA_R5 = {7'h10, 1'b1};

    i2c_master_e state;
    logic [7:0] w_addr, w_rdata;
    logic w_start_t, done_top;
    logic [11:0] reg_note;


    i2c_read_top U_I2C_READ_TOP (
        .clk       (clk),
        .reset     (rst),
        .addr      (w_addr),
        .start_tick(w_start_t),
        .rdata     (w_rdata),
        .o_done    (done_top),
        .scl       (scl),
        .sda       (sda)
    );

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state     <= IDLE;
            note      <= 0;
            w_addr    <= 0;
            w_start_t <= 0;
            reg_note  <= 0;
        end else begin
            w_start_t <= 1'b0;
            case (state)
                IDLE: begin
                    w_addr    <= 0;
                    note      <= 0;
                    w_start_t <= 0;
                    note      <= reg_note;
                    if (start_i2c_fsm) begin
                        state           <= SLV1;
                        w_start_t       <= 1'b1;
                        w_addr          <= SLA_R1;
                        reg_note[11:10] <= m_note;
                    end
                end
                SLV1: begin
                    w_start_t <= 0;
                    if (done_top) begin
                        state         <= SLV2;
                        w_start_t     <= 1'b1;
                        w_addr        <= SLA_R2;
                        reg_note[1:0] <= w_rdata[1:0];
                    end
                end
                SLV2: begin
                    w_start_t <= 0;
                    if (done_top) begin
                        state         <= SLV3;
                        w_start_t     <= 1'b1;
                        w_addr        <= SLA_R3;
                        reg_note[3:2] <= w_rdata[1:0];
                    end
                end
                SLV3: begin
                    w_start_t <= 0;
                    if (done_top) begin
                        state         <= SLV4;
                        w_start_t     <= 1'b1;
                        w_addr        <= SLA_R4;
                        reg_note[5:4] <= w_rdata[1:0];
                    end
                end
                SLV4: begin
                    w_start_t <= 0;
                    if (done_top) begin
                        state         <= SLV5;
                        w_start_t     <= 1'b1;
                        w_addr        <= SLA_R5;
                        reg_note[7:6] <= w_rdata[1:0];
                    end
                end
                SLV5: begin
                    w_start_t <= 0;
                    if (done_top) begin
                        state         <= IDLE;
                        reg_note[9:8] <= w_rdata[1:0];
                    end
                end

            endcase
        end
    end


endmodule


module i2c_read_top (
    input  logic       clk,
    input  logic       reset,
    input  logic [7:0] addr,
    input  logic       start_tick,
    output logic [7:0] rdata,
    output logic       o_done,
    output logic       scl,
    inout  wire        sda
);

    typedef enum logic [2:0] {
        IDLE  = 0,
        START,
        ADDR,
        READ,
        STOP
    } i2c_state_e;


    i2c_state_e       state;
    // logic       [7:0] counter;
    logic             cmd_start;
    logic             cmd_write;
    logic             cmd_read;
    logic             cmd_stop;
    logic       [7:0] tx_data;
    logic             ack_in;
    logic       [7:0] rx_data;
    logic             done;
    logic             ack_out;
    logic             busy;
    logic       [7:0] reg_addr;

    I2C_Master U_I2C_Master (
        .clk      (clk),
        .reset    (reset),
        .cmd_start(cmd_start),
        .cmd_write(cmd_write),
        .cmd_read (cmd_read),
        .cmd_stop (cmd_stop),
        .tx_data  (tx_data),
        .ack_in   (ack_in),
        .rx_data  (rx_data),
        .done     (done),
        .ack_out  (ack_out),
        .busy     (busy),
        .scl      (scl),
        .sda      (sda)
    );

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state     <= IDLE;
            cmd_start <= 1'b0;
            cmd_write <= 1'b0;
            cmd_read  <= 1'b0;
            cmd_stop  <= 1'b0;
            reg_addr  <= 0;
            rdata     <= 0;
            o_done    <= 0;
        end else begin
            o_done <= 1'b0;
            case (state)
                IDLE: begin
                    cmd_start <= 1'b0;
                    cmd_write <= 1'b0;
                    cmd_read  <= 1'b0;
                    cmd_stop  <= 1'b0;
                    if (start_tick) begin
                        state <= START;
                        reg_addr <= addr;
                    end
                end
                START: begin
                    cmd_start <= 1'b1;
                    cmd_write <= 1'b0;
                    cmd_read  <= 1'b0;
                    cmd_stop  <= 1'b0;
                    if (done) begin
                        state <= ADDR;
                    end
                end
                ADDR: begin
                    cmd_start <= 1'b0;
                    cmd_write <= 1'b1;
                    cmd_read  <= 1'b0;
                    cmd_stop  <= 1'b0;
                    tx_data   <= reg_addr;
                    if (done) begin
                        state <= READ;
                    end
                end
                READ: begin
                    cmd_start <= 1'b0;
                    cmd_write <= 1'b0;
                    cmd_read  <= 1'b1;
                    cmd_stop  <= 1'b0;
                    if (done) begin
                        state <= STOP;
                        rdata <= rx_data;
                    end
                end
                STOP: begin
                    cmd_start <= 1'b0;
                    cmd_write <= 1'b0;
                    cmd_read  <= 1'b0;
                    cmd_stop  <= 1'b1;
                    if (done) begin
                        state  <= IDLE;
                        o_done <= 1'b1;
                    end
                end
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule


module I2C_Master (
    input  logic       clk,
    input  logic       reset,
    // command port
    input  logic       cmd_start,
    input  logic       cmd_write,
    input  logic       cmd_read,
    input  logic       cmd_stop,
    input  logic [7:0] tx_data,
    input  logic       ack_in,
    // internal output
    output logic [7:0] rx_data,
    output logic       done,
    output logic       ack_out,
    output logic       busy,
    // external i2c port
    output logic       scl,
    inout  logic       sda
);
    logic sda_o, sda_i;

    assign sda_i = sda;
    assign sda   = sda_o ? 1'bz : 1'b0;

    i2c_master u_i2c_master (
        .*,
        .sda_o(sda_o),
        .sda_i(sda_i)
    );
endmodule

module i2c_master (
    input  logic       clk,
    input  logic       reset,
    // command port
    input  logic       cmd_start,
    input  logic       cmd_write,
    input  logic       cmd_read,
    input  logic       cmd_stop,
    input  logic [7:0] tx_data,
    input  logic       ack_in,
    // internal output
    output logic [7:0] rx_data,
    output logic       done,
    output logic       ack_out,
    output logic       busy,
    // external i2c port
    output logic       scl,
    output logic       sda_o,
    input  logic       sda_i
);

    typedef enum logic [2:0] {
        IDLE = 3'b000,
        START,
        WAIT_CMD,
        DATA,
        DATA_ACK,
        STOP
    } i2c_state_e;

    i2c_state_e state;
    logic [7:0] div_cnt;
    logic qtr_tick;
    logic scl_r, sda_r;
    logic [1:0] step;
    logic [7:0] tx_shift_reg, rx_shift_reg;
    logic [2:0] bit_cnt;
    logic is_read, ack_in_r;

    assign scl   = scl_r;
    assign sda_o = sda_r;
    assign busy  = (state != IDLE);

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            div_cnt  <= 0;
            qtr_tick <= 1'b0;
        end else begin
            if (div_cnt == 250 - 1) begin  // scl : 100khz
                div_cnt  <= 0;
                qtr_tick <= 1'b1;
            end else begin
                div_cnt  <= div_cnt + 1;
                qtr_tick <= 1'b0;
            end
        end
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state        <= IDLE;
            scl_r        <= 1'b1;
            sda_r        <= 1'b1;
            //busy         <= 1'b0;
            step         <= 0;
            done         <= 1'b0;
            tx_shift_reg <= 0;
            rx_shift_reg <= 0;
            is_read      <= 1'b0;
            bit_cnt      <= 0;
            ack_in_r     <= 1'b1;
        end else begin
            done <= 1'b0;
            case (state)
                IDLE: begin
                    scl_r <= 1'b1;
                    sda_r <= 1'b1;
                    busy  <= 1'b0;
                    if (cmd_start) begin
                        state <= START;
                        step  <= 0;
                        //busy  <= 1'b1;
                    end
                end

                START: begin
                    if (qtr_tick) begin
                        case (step)
                            2'd0: begin
                                sda_r <= 1'b1;
                                scl_r <= 1'b1;
                                step  <= 2'd1;
                            end
                            2'd1: begin
                                sda_r <= 1'b0;
                                step  <= 2'd2;
                            end
                            2'd2: begin
                                step <= 2'd3;
                            end
                            2'd3: begin
                                scl_r <= 1'b0;
                                step  <= 2'd0;
                                done  <= 1'b1;
                                state <= WAIT_CMD;
                            end
                        endcase
                    end
                end

                WAIT_CMD: begin
                    step <= 0;
                    if (cmd_write) begin
                        tx_shift_reg <= tx_data;
                        bit_cnt <= 0;
                        is_read <= 1'b0;
                        state <= DATA;
                    end else if (cmd_read) begin
                        rx_shift_reg <= 0;
                        bit_cnt <= 0;
                        is_read <= 1'b1;
                        ack_in_r <= ack_in;
                        state <= DATA;
                    end else if (cmd_stop) begin
                        state <= STOP;
                    end else if (cmd_start) begin
                        state <= START;
                    end
                end

                DATA: begin
                    if (qtr_tick) begin
                        case (step)
                            2'd0: begin
                                scl_r <= 1'b0;
                                sda_r <= is_read ? 1'b1 : tx_shift_reg[7];
                                step  <= 2'd1;
                            end
                            2'd1: begin
                                scl_r <= 1'b1;
                                step  <= 2'd2;
                            end
                            2'd2: begin
                                scl_r <= 1'b1;
                                if (is_read) begin
                                    rx_shift_reg <= {rx_shift_reg[6:0], sda_i};
                                end
                                step <= 2'd3;
                            end
                            2'd3: begin
                                scl_r <= 1'b0;
                                if (!is_read) begin
                                    tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
                                end
                                step <= 2'd0;

                                if (bit_cnt == 7) begin
                                    state <= DATA_ACK;
                                end else begin
                                    bit_cnt <= bit_cnt + 1;
                                end
                            end
                        endcase
                    end
                end

                DATA_ACK: begin
                    if (qtr_tick) begin
                        case (step)
                            2'd0: begin
                                scl_r <= 1'b0;
                                if (is_read) begin
                                    sda_r <= ack_in_r;
                                end else begin
                                    sda_r <= 1'b1;  // sda input 설정
                                end
                                step <= 2'd1;
                            end
                            2'd1: begin
                                scl_r <= 1'b1;
                                step  <= 2'd2;
                            end
                            2'd2: begin
                                scl_r <= 1'b1;
                                if (!is_read) begin  // ack 수신
                                    ack_out <= sda_i;

                                end
                                if (is_read) begin
                                    rx_data <= rx_shift_reg;
                                end
                                step <= 2'd3;
                            end
                            2'd3: begin
                                scl_r <= 1'b0;
                                done  <= 1'b1;
                                step  <= 2'd0;
                                state <= WAIT_CMD;
                            end
                        endcase
                    end
                end

                STOP: begin
                    if (qtr_tick) begin
                        case (step)
                            2'd0: begin
                                sda_r <= 1'b0;
                                scl_r <= 1'b0;
                                step  <= 2'd1;
                            end
                            2'd1: begin
                                scl_r <= 1'b1;
                                step  <= 2'd2;
                            end
                            2'd2: begin
                                sda_r <= 1'b1;
                                step  <= 2'd3;
                            end
                            2'd3: begin
                                step  <= 2'd0;
                                done  <= 1'b1;
                                state <= IDLE;
                            end
                        endcase
                    end
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule

