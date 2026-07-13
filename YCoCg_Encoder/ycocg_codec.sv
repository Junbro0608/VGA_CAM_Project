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
//  ycocg_fwd_px : one pixel, RGB444 -> Y (4b) + high-precision Co/Cg
//                 (no shift on chroma yet, so the block averager keeps
//                  every bit until the single final quantisation)
//=============================================================================
module ycocg_fwd_px (
    input  logic        [3:0] i_r,
    input  logic        [3:0] i_g,
    input  logic        [3:0] i_b,
    output logic        [3:0] o_y,      // 0 .. 15
    output logic signed [6:0] o_co_hp,  //  R - B        : -15 .. +15
    output logic signed [7:0] o_cg_hp   //  2G - R - B   : -30 .. +30
);
    logic [5:0] y_sum;  // R + 2G + B : 0 .. 60

    // Y : round-to-nearest.  max (60 + 2) >> 2 = 15  -> never overflows 4 bit.
    assign y_sum = {2'b0, i_r} + {1'b0, i_g, 1'b0} + {2'b0, i_b};
    assign o_y = (y_sum + 6'd2) >> 2;

    assign o_co_hp = $signed({3'b0, i_r}) - $signed({3'b0, i_b});
    assign o_cg_hp = $signed(
        {3'b0, i_g, 1'b0}
    )  // 2G
    - $signed(
        {4'b0, i_r}
    ) - $signed(
        {4'b0, i_b}
    );
endmodule


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
//  ycocg_encoder : 48 bit block -> 24 bit code
//                  latency 1 clk (REGISTERED=1) or 0 (REGISTERED=0)
//=============================================================================
module ycocg_encoder #(
    parameter bit REGISTERED = 1'b1
) (
    input  logic        clk,
    input  logic        reset,    // synchronous, active high
    input  logic        i_valid,
    input  logic [47:0] i_block,
    output logic        o_valid,
    output logic [23:0] o_code
);
    // ---- unpack (continuous assigns -> no part-select inside always) --------
    logic [3:0] r0, g0, b0, r1, g1, b1, r2, g2, b2, r3, g3, b3;
    assign {r0, g0, b0} = i_block[11:0];
    assign {r1, g1, b1} = i_block[23:12];
    assign {r2, g2, b2} = i_block[35:24];
    assign {r3, g3, b3} = i_block[47:36];

    // ---- per-pixel forward transform ---------------------------------------
    logic [3:0] y0, y1, y2, y3;
    logic signed [6:0] co0, co1, co2, co3;
    logic signed [7:0] cg0, cg1, cg2, cg3;

    ycocg_fwd_px u_f0 (
        r0,
        g0,
        b0,
        y0,
        co0,
        cg0
    );
    ycocg_fwd_px u_f1 (
        r1,
        g1,
        b1,
        y1,
        co1,
        cg1
    );
    ycocg_fwd_px u_f2 (
        r2,
        g2,
        b2,
        y2,
        co2,
        cg2
    );
    ycocg_fwd_px u_f3 (
        r3,
        g3,
        b3,
        y3,
        co3,
        cg3
    );

    // ---- chroma downsample : sum the 4 pixels, then quantise ONCE -----------
    //   Co_blk = ( sum(R-B)    / 4 ) / 2 = sum_co >>> 3     sum_co : -60..+60
    //   Cg_blk = ( sum(2G-R-B) / 4 ) / 4 = sum_cg >>> 4     sum_cg : -120..+120
    //   round-to-nearest can push the positive end to +8, which does not fit
    //   in signed 4 bit -> one upper saturation is all that is needed.
    logic signed [8:0] sum_co;
    logic signed [9:0] sum_cg;
    logic signed [5:0] co_rnd, cg_rnd;
    logic signed [3:0] co_q, cg_q;

    assign sum_co = 9'(co0) + 9'(co1) + 9'(co2) + 9'(co3);
    assign sum_cg = 10'(cg0) + 10'(cg1) + 10'(cg2) + 10'(cg3);

    assign co_rnd = 6'((sum_co + 9'sd4) >>> 3);  // -7 .. +8
    assign cg_rnd = 6'((sum_cg + 10'sd8) >>> 4);  // -7 .. +8

    assign co_q   = (co_rnd > 6'sd7) ? 4'sd7 : co_rnd[3:0];
    assign cg_q   = (cg_rnd > 6'sd7) ? 4'sd7 : cg_rnd[3:0];

    // ---- pack ---------------------------------------------------------------
    logic [23:0] code_c;
    assign code_c = {cg_q, co_q, y3, y2, y1, y0};

    // ---- output stage -------------------------------------------------------
    generate
        if (REGISTERED) begin : g_reg
            always_ff @(posedge clk) begin
                if (reset) begin
                    o_code  <= 24'h0;
                    o_valid <= 1'b0;
                end else begin
                    o_code  <= code_c;
                    o_valid <= i_valid;
                end
            end
        end else begin : g_comb
            assign o_code  = code_c;
            assign o_valid = i_valid;
        end
    endgenerate
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
