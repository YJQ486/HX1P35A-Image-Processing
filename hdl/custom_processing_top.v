// Four-mode processor for AWB's 4 x RGB888 stream in S_csi_rx_clk.
// Modes: bypass, gray, pencil sketch (white paper, Sobel strokes, light shading), Sobel.
// i_threshold is unused since the sketch replaced binary; the port is kept for isp_top.
// A sampled beat appears at the output after two rising-edge stages.
// tuser is SOF; tlast is EOL and may accompany tvalid=0.
module custom_processing_top #(
    parameter IMG_WIDTH = 1280,
    parameter IMG_HEIGHT = 720,
    // Stroke = (Sobel - core) << EDGE_SHIFT, floored at 0 and saturated, with
    // core = EDGE_CORE + (gray >> CORE_GRAY_SHIFT). Bright areas carry more
    // sensor noise and surface texture, so they need a higher core; the gain
    // keeps real edges dark in dim rooms.
    parameter EDGE_CORE = 8'd40,
    parameter CORE_GRAY_SHIFT = 2,
    parameter EDGE_SHIFT = 1,
    // Shading = (255 - gray) >> SHADE_SHIFT; larger values give a lighter wash.
    parameter SHADE_SHIFT = 1
)(
    input  wire        i_clk,
    input  wire        i_rst_n,
    input  wire [1:0]  i_mode_req,
    input  wire [7:0]  i_threshold,
    input  wire [95:0] i_tdata,
    input  wire        i_tvalid,
    input  wire        i_tuser,
    input  wire        i_tlast,
    output wire [95:0] o_tdata,
    output wire        o_tvalid,
    output wire        o_tuser,
    output wire        o_tlast
);
    localparam MODE_BYPASS = 2'b00;
    localparam MODE_GRAY   = 2'b01;
    localparam MODE_SKETCH = 2'b10;
    localparam MODE_SOBEL  = 2'b11;

    reg [1:0] active_mode;
    wire sof_accept;
    wire [1:0] beat_mode;
    wire [7:0] gray0, gray1, gray2, gray3;
    wire [95:0] gray_word;
    wire [95:0] sketch_word;
    wire [95:0] sobel_data;
    wire sobel_valid, sobel_user, sobel_last;

    reg [95:0] bypass_d1, bypass_d2;
    reg [95:0] gray_d1, gray_d2;
    reg [1:0] mode_d1, mode_d2;
    reg [95:0] selected_data;

    assign sof_accept = i_tvalid && i_tuser;
    assign beat_mode = sof_accept ? i_mode_req : active_mode;

    custom_rgb_to_gray u_gray0 (.i_rgb(i_tdata[95:72]), .o_gray(gray0));
    custom_rgb_to_gray u_gray1 (.i_rgb(i_tdata[71:48]), .o_gray(gray1));
    custom_rgb_to_gray u_gray2 (.i_rgb(i_tdata[47:24]), .o_gray(gray2));
    custom_rgb_to_gray u_gray3 (.i_rgb(i_tdata[23:0]),  .o_gray(gray3));
    assign gray_word = {{3{gray0}}, {3{gray1}}, {3{gray2}}, {3{gray3}}};
    // Sketch value = 255 - stroke - shading, floored at 0. Flat areas are already 0
    // after the Sobel noise floor, so they stay paper white apart from shading.
    // The Sobel window lags the gray by one row and one pixel, which is not
    // visible at 1280x720.
    genvar l;
    generate
        for (l = 0; l < 4; l = l + 1) begin : g_sketch
            wire [7:0]  sob_l  = sobel_data[l*24+16 +: 8];
            wire [8:0]  base_l = {1'b0, EDGE_CORE} + (gray_d2[l*24+16 +: 8] >> CORE_GRAY_SHIFT);
            wire [7:0]  core_l = ({1'b0, sob_l} > base_l) ? (sob_l - base_l[7:0]) : 8'd0;
            wire [15:0] gain_l = {8'd0, core_l} << EDGE_SHIFT;
            wire [7:0] edge_l  = (gain_l > 16'd255) ? 8'd255 : gain_l[7:0];
            wire [7:0] shade_l = (~gray_d2[l*24+16 +: 8]) >> SHADE_SHIFT;
            wire [8:0] ink_l   = edge_l + shade_l;
            wire [7:0] paper_l = ink_l[8] ? 8'd0 : ~ink_l[7:0];
            assign sketch_word[l*24 +: 24] = {3{paper_l}};
        end
    endgenerate

    // Keep history warm in every mode; a subsequent SOF can select Sobel.
    custom_sobel_4px #(
        .IMG_WIDTH(IMG_WIDTH), .IMG_HEIGHT(IMG_HEIGHT)
    ) u_sobel (
        .i_clk(i_clk), .i_rst_n(i_rst_n),
        .i_tdata(i_tdata), .i_tvalid(i_tvalid),
        .i_tuser(i_tuser), .i_tlast(i_tlast),
        .o_tdata(sobel_data), .o_tvalid(sobel_valid),
        .o_tuser(sobel_user), .o_tlast(sobel_last)
    );

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            active_mode <= MODE_BYPASS;
            bypass_d1 <= 96'd0;
            bypass_d2 <= 96'd0;
            gray_d1 <= 96'd0;
            gray_d2 <= 96'd0;
            mode_d1 <= MODE_BYPASS;
            mode_d2 <= MODE_BYPASS;
        end else begin
            if (sof_accept) begin
                active_mode <= i_mode_req;
            end
            bypass_d1 <= i_tvalid ? i_tdata : 96'd0;
            gray_d1 <= i_tvalid ? gray_word : 96'd0;
            bypass_d2 <= bypass_d1;
            gray_d2 <= gray_d1;
            mode_d1 <= beat_mode;
            mode_d2 <= mode_d1;
        end
    end

    always @(*) begin
        case (mode_d2)
            MODE_GRAY:   selected_data = gray_d2;
            MODE_SKETCH: selected_data = sketch_word;
            MODE_SOBEL:  selected_data = sobel_data;
            default:     selected_data = bypass_d2;
        endcase
    end

    assign o_tdata = sobel_valid ? selected_data : 96'd0;
    assign o_tvalid = sobel_valid;
    assign o_tuser = sobel_user;
    assign o_tlast = sobel_last;
endmodule
