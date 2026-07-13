`timescale 1ns / 1ps
//=============================================================================
//  ycocg_codec.sv
//-----------------------------------------------------------------------------
//  YCoCg 4:2:0 block codec :  2x2 RGB444 block (48 bit)  <->  24 bit code
//
//    compression ratio 2:1, multiplier-free (shift + add only)
//
//  pixel layout (2x2 rectangle)           block bit layout
//    +-----+-----+                         block[11: 0] = P0
//    | P0  | P1  |                         block[23:12] = P1
//    +-----+-----+                         block[35:24] = P2
//    | P2  | P3  |                         block[47:36] = P3
//    +-----+-----+                         P = {R[3:0], G[3:0], B[3:0]}
//
//  code bit layout
//    code[ 3: 0] = Y0        (unsigned 4b)
//    code[ 7: 4] = Y1
//    code[11: 8] = Y2
//    code[15:12] = Y3
//    code[19:16] = Co        (signed   4b, shared by the whole block)
//    code[23:20] = Cg        (signed   4b, shared by the whole block)
//
//  transform
//      Y  = ( R + 2G + B) / 4                 luma  , kept per pixel
//      Co = ( R      - B) / 2                 chroma, averaged over the block
//      Cg = (-R + 2G - B) / 4                 chroma, averaged over the block
//  inverse
//      t = Y - Cg ;  G = Y + Cg ;  R = t + Co ;  B = t - Co
//=============================================================================

//=============================================================================
//  ycocg_inv_px : one pixel, Y + Co + Cg -> RGB444 (with clamping)
//=============================================================================
module ycocg_inv_px (
    input  logic        [3:0] i_y,
    input  logic signed [3:0] i_co,
    input  logic signed [3:0] i_cg,
    output logic        [3:0] o_r,
    output logic        [3:0] o_g,
    output logic        [3:0] o_b
);
    // signed 7 bit head-room : R  -15..+30 , G  -8..+22 , B  -15..+31
    logic signed [6:0] y_s, co_s, cg_s;
    logic signed [6:0] t, rr, gg, bb;

    assign y_s  = $signed({3'b0, i_y});
    assign co_s = 7'($signed(i_co));  // sign-extend
    assign cg_s = 7'($signed(i_cg));

    assign t    = y_s - cg_s;  // (R + B) / 2
    assign gg   = y_s + cg_s;
    assign rr   = t + co_s;
    assign bb   = t - co_s;

    // clamp to [0, 15]
    assign o_r  = rr[6] ? 4'd0 : (|rr[5:4] ? 4'd15 : rr[3:0]);
    assign o_g  = gg[6] ? 4'd0 : (|gg[5:4] ? 4'd15 : gg[3:0]);
    assign o_b  = bb[6] ? 4'd0 : (|bb[5:4] ? 4'd15 : bb[3:0]);
endmodule

//=============================================================================
//  ycocg_decoder : 24 bit code -> 48 bit block
//                  the single Co/Cg pair is replicated to all 4 pixels
//=============================================================================
module ycocg_decoder #(
    parameter bit REGISTERED = 1'b1
) (
    input  logic        clk,
    input  logic        reset,
    input  logic        i_valid,
    input  logic [23:0] i_code,
    output logic        o_valid,
    output logic [47:0] o_block
);
    logic [3:0] y0, y1, y2, y3;
    logic signed [3:0] co, cg;

    assign y0 = i_code[3:0];
    assign y1 = i_code[7:4];
    assign y2 = i_code[11:8];
    assign y3 = i_code[15:12];
    assign co = $signed(i_code[19:16]);
    assign cg = $signed(i_code[23:20]);

    logic [3:0] r0, g0, b0, r1, g1, b1, r2, g2, b2, r3, g3, b3;

    ycocg_inv_px u_i0 (
        y0,
        co,
        cg,
        r0,
        g0,
        b0
    );
    ycocg_inv_px u_i1 (
        y1,
        co,
        cg,
        r1,
        g1,
        b1
    );
    ycocg_inv_px u_i2 (
        y2,
        co,
        cg,
        r2,
        g2,
        b2
    );
    ycocg_inv_px u_i3 (
        y3,
        co,
        cg,
        r3,
        g3,
        b3
    );

    logic [47:0] blk_c;
    assign blk_c = {r3, g3, b3, r2, g2, b2, r1, g1, b1, r0, g0, b0};

    generate
        if (REGISTERED) begin : g_reg
            always_ff @(posedge clk) begin
                if (reset) begin
                    o_block <= 48'h0;
                    o_valid <= 1'b0;
                end else begin
                    o_block <= blk_c;
                    o_valid <= i_valid;
                end
            end
        end else begin : g_comb
            assign o_block = blk_c;
            assign o_valid = i_valid;
        end
    endgenerate
endmodule
