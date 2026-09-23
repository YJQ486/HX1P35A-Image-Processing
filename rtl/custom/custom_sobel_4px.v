// Four-pixel-per-clock RGB888 Sobel stage for the real AWB stream.
// Contract: IMG_WIDTH is divisible by four; tlast may occur with tvalid low.
// The causal 3x3 window is centered one source row and one source pixel behind
// the current input.  Output words therefore contain a one-row/one-pixel
// spatial shift.  Synchronous ERAM reads add a second registered stream stage;
// data and every stream marker therefore have two clocks of latency.
module custom_sobel_4px #(
    parameter IMG_WIDTH  = 1280,
    parameter IMG_HEIGHT = 720
)(
    input  wire        i_clk,
    input  wire        i_rst_n,
    input  wire [95:0] i_tdata,
    input  wire        i_tvalid,
    input  wire        i_tuser,
    input  wire        i_tlast,
    output reg  [95:0] o_tdata,
    output reg         o_tvalid,
    output reg         o_tuser,
    output reg         o_tlast
);
    localparam GROUPS_PER_LINE = IMG_WIDTH / 4;

    wire [7:0] gray0;
    wire [7:0] gray1;
    wire [7:0] gray2;
    wire [7:0] gray3;

    // Four lanes share one group address.  Packing them into a wide word lets
    // TD infer PH1P ERAM instead of eight independent asynchronous-read DRAMs.
    reg [31:0] line1_word [0:GROUPS_PER_LINE-1];
    reg [31:0] line2_word [0:GROUPS_PER_LINE-1];
    reg [31:0] line1_q;
    reg [31:0] line2_q;

    reg [9:0] x_group;
    reg [9:0] y_pos;
    wire [9:0] read_group;
    wire [9:0] active_y;

    wire [31:0] gray_word;
    reg  [31:0] gray_word_d;
    wire [7:0] top0;
    wire [7:0] top1;
    wire [7:0] top2;
    wire [7:0] top3;
    wire [7:0] mid0;
    wire [7:0] mid1;
    wire [7:0] mid2;
    wire [7:0] mid3;
    wire [7:0] bot0;
    wire [7:0] bot1;
    wire [7:0] bot2;
    wire [7:0] bot3;

    reg        stage1_valid;
    reg        stage1_user;
    reg        stage1_last;
    reg [9:0]  stage1_group;
    reg [9:0]  stage1_y;

    reg [7:0] top_prev2;
    reg [7:0] top_prev1;
    reg [7:0] mid_prev2;
    reg [7:0] mid_prev1;
    reg [7:0] bot_prev2;
    reg [7:0] bot_prev1;

    wire [7:0] sobel0_raw;
    wire [7:0] sobel1_raw;
    wire [7:0] sobel2_raw;
    wire [7:0] sobel3_raw;
    wire lane0_valid;
    wire lane1_valid;
    wire lane2_valid;
    wire lane3_valid;
    wire [7:0] sobel0;
    wire [7:0] sobel1;
    wire [7:0] sobel2;
    wire [7:0] sobel3;

    custom_rgb_to_gray u_gray0 (.i_rgb(i_tdata[95:72]), .o_gray(gray0));
    custom_rgb_to_gray u_gray1 (.i_rgb(i_tdata[71:48]), .o_gray(gray1));
    custom_rgb_to_gray u_gray2 (.i_rgb(i_tdata[47:24]), .o_gray(gray2));
    custom_rgb_to_gray u_gray3 (.i_rgb(i_tdata[23:0]),  .o_gray(gray3));

    assign read_group = (i_tvalid && i_tuser) ? 10'd0 : x_group;
    assign active_y   = (i_tvalid && i_tuser) ? 10'd0 : y_pos;

    assign gray_word = {gray0, gray1, gray2, gray3};
    assign top0 = line2_q[31:24];
    assign top1 = line2_q[23:16];
    assign top2 = line2_q[15:8];
    assign top3 = line2_q[7:0];
    assign mid0 = line1_q[31:24];
    assign mid1 = line1_q[23:16];
    assign mid2 = line1_q[15:8];
    assign mid3 = line1_q[7:0];
    assign bot0 = gray_word_d[31:24];
    assign bot1 = gray_word_d[23:16];
    assign bot2 = gray_word_d[15:8];
    assign bot3 = gray_word_d[7:0];

    function [7:0] sobel_magnitude;
        input [7:0] a00;
        input [7:0] a01;
        input [7:0] a02;
        input [7:0] a10;
        input [7:0] a11;
        input [7:0] a12;
        input [7:0] a20;
        input [7:0] a21;
        input [7:0] a22;
        reg signed [12:0] gx;
        reg signed [12:0] gy;
        reg [12:0] abs_gx;
        reg [12:0] abs_gy;
        reg [13:0] magnitude;
        begin
            gx = -$signed({5'd0,a00}) + $signed({5'd0,a02})
                 - ($signed({5'd0,a10}) <<< 1) + ($signed({5'd0,a12}) <<< 1)
                 - $signed({5'd0,a20}) + $signed({5'd0,a22});
            gy =  $signed({5'd0,a00}) + ($signed({5'd0,a01}) <<< 1) + $signed({5'd0,a02})
                 - $signed({5'd0,a20}) - ($signed({5'd0,a21}) <<< 1) - $signed({5'd0,a22});
            abs_gx = gx[12] ? (~gx + 13'd1) : gx;
            abs_gy = gy[12] ? (~gy + 13'd1) : gy;
            magnitude = abs_gx + abs_gy;
            sobel_magnitude = (magnitude > 14'd255) ? 8'hff : magnitude[7:0];
        end
    endfunction

    // Four consecutive centers: previous group's lane3, then current lanes0..2.
    // This is the cross-beat bridge that avoids treating each 4-pixel word as
    // an independent mini-line.
    assign sobel0_raw = sobel_magnitude(top_prev2, top_prev1, top0,
                                        mid_prev2, mid_prev1, mid0,
                                        bot_prev2, bot_prev1, bot0);
    assign sobel1_raw = sobel_magnitude(top_prev1, top0, top1,
                                        mid_prev1, mid0, mid1,
                                        bot_prev1, bot0, bot1);
    assign sobel2_raw = sobel_magnitude(top0, top1, top2,
                                        mid0, mid1, mid2,
                                        bot0, bot1, bot2);
    assign sobel3_raw = sobel_magnitude(top1, top2, top3,
                                        mid1, mid2, mid3,
                                        bot1, bot2, bot3);

    // First two output rows are zero: row 0 is causal padding and row 1
    // represents source row 0, which is a border.  At the left edge, lanes 0
    // and 1 are padding/source-border respectively.
    assign lane0_valid = (stage1_y >= 10'd2) && (stage1_group != 10'd0);
    assign lane1_valid = (stage1_y >= 10'd2) && (stage1_group != 10'd0);
    assign lane2_valid = (stage1_y >= 10'd2);
    assign lane3_valid = (stage1_y >= 10'd2);
    assign sobel0 = lane0_valid ? sobel0_raw : 8'd0;
    assign sobel1 = lane1_valid ? sobel1_raw : 8'd0;
    assign sobel2 = lane2_valid ? sobel2_raw : 8'd0;
    assign sobel3 = lane3_valid ? sobel3_raw : 8'd0;

    // line1 is a single-clock, synchronous-read, read-before-write RAM.  The
    // old word supplies the middle window row while the current gray word is
    // stored at the same address.  line2 has an independent synchronous read
    // and a one-stage-delayed write address; normal continuous traffic reads
    // group N while writing group N-1, so its behavior never depends on a
    // same-address dual-port collision.
    always @(posedge i_clk) begin
        if (i_tvalid) begin
            line1_q <= line1_word[read_group];
            line1_word[read_group] <= gray_word;
            line2_q <= line2_word[read_group];
        end
        if (stage1_valid)
            line2_word[stage1_group] <= line1_q;
    end

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            x_group   <= 10'd0;
            y_pos     <= 10'd0;
            top_prev2 <= 8'd0;
            top_prev1 <= 8'd0;
            mid_prev2 <= 8'd0;
            mid_prev1 <= 8'd0;
            bot_prev2 <= 8'd0;
            bot_prev1 <= 8'd0;
            gray_word_d <= 32'd0;
            stage1_valid <= 1'b0;
            stage1_user  <= 1'b0;
            stage1_last  <= 1'b0;
            stage1_group <= 10'd0;
            stage1_y     <= 10'd0;
            o_tdata   <= 96'd0;
            o_tvalid  <= 1'b0;
            o_tuser   <= 1'b0;
            o_tlast   <= 1'b0;
        end else begin
            o_tvalid <= stage1_valid;
            o_tuser  <= stage1_user;
            o_tlast  <= stage1_last;
            if (stage1_valid)
                o_tdata <= {{3{sobel0}}, {3{sobel1}}, {3{sobel2}}, {3{sobel3}}};
            else
                o_tdata <= 96'd0;

            if (i_tvalid) begin
                gray_word_d <= gray_word;
                stage1_group <= read_group;
                stage1_y <= active_y;
            end
            stage1_valid <= i_tvalid;
            stage1_user  <= i_tuser;
            stage1_last  <= i_tlast;

            // Horizontal window history follows the delayed RAM/data stage.
            if (stage1_last) begin
                top_prev2 <= 8'd0;
                top_prev1 <= 8'd0;
                mid_prev2 <= 8'd0;
                mid_prev1 <= 8'd0;
                bot_prev2 <= 8'd0;
                bot_prev1 <= 8'd0;
            end else if (stage1_valid) begin
                top_prev2 <= top2;
                top_prev1 <= top3;
                mid_prev2 <= mid2;
                mid_prev1 <= mid3;
                bot_prev2 <= bot2;
                bot_prev1 <= bot3;
            end

            // Input-side coordinates advance from the real stream markers.
            if (i_tlast) begin
                x_group <= 10'd0;
                if (y_pos == IMG_HEIGHT - 1)
                    y_pos <= 10'd0;
                else
                    y_pos <= y_pos + 10'd1;
            end else if (i_tvalid) begin
                if (i_tuser) begin
                    y_pos <= 10'd0;
                    if (GROUPS_PER_LINE > 1)
                        x_group <= 10'd1;
                    else
                        x_group <= 10'd0;
                end else if (x_group < GROUPS_PER_LINE - 1) begin
                    x_group <= x_group + 10'd1;
                end
            end
        end
    end
endmodule
