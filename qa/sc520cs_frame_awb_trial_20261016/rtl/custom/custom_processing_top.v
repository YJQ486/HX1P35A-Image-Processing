// Four-mode processor for AWB's 4 x RGB888 stream in S_csi_rx_clk.
// A sampled beat appears at the output after two rising-edge stages.
// tuser is SOF; tlast is EOL and may accompany tvalid=0.
module custom_processing_top #(
    parameter IMG_WIDTH = 1280,
    parameter IMG_HEIGHT = 720
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
    localparam MODE_BINARY = 2'b10;
    localparam MODE_SOBEL  = 2'b11;

    reg [1:0] active_mode;
    reg [7:0] active_threshold;
    wire sof_accept;
    wire [1:0] beat_mode;
    wire [7:0] beat_threshold;
    wire [7:0] gray0, gray1, gray2, gray3;
    wire [7:0] bin0, bin1, bin2, bin3;
    wire [95:0] gray_word;
    wire [95:0] binary_word;
    wire [95:0] sobel_data;
    wire sobel_valid, sobel_user, sobel_last;

    reg [95:0] bypass_d1, bypass_d2;
    reg [95:0] gray_d1, gray_d2;
    reg [95:0] binary_d1, binary_d2;
    reg [1:0] mode_d1, mode_d2;
    reg [95:0] selected_data;

    assign sof_accept = i_tvalid && i_tuser;
    assign beat_mode = sof_accept ? i_mode_req : active_mode;
    assign beat_threshold = sof_accept ? i_threshold : active_threshold;

    custom_rgb_to_gray u_gray0 (.i_rgb(i_tdata[95:72]), .o_gray(gray0));
    custom_rgb_to_gray u_gray1 (.i_rgb(i_tdata[71:48]), .o_gray(gray1));
    custom_rgb_to_gray u_gray2 (.i_rgb(i_tdata[47:24]), .o_gray(gray2));
    custom_rgb_to_gray u_gray3 (.i_rgb(i_tdata[23:0]),  .o_gray(gray3));
    custom_gray_threshold u_bin0 (.i_gray(gray0), .i_threshold(beat_threshold), .o_gray(bin0));
    custom_gray_threshold u_bin1 (.i_gray(gray1), .i_threshold(beat_threshold), .o_gray(bin1));
    custom_gray_threshold u_bin2 (.i_gray(gray2), .i_threshold(beat_threshold), .o_gray(bin2));
    custom_gray_threshold u_bin3 (.i_gray(gray3), .i_threshold(beat_threshold), .o_gray(bin3));
    assign gray_word = {{3{gray0}}, {3{gray1}}, {3{gray2}}, {3{gray3}}};
    assign binary_word = {{3{bin0}}, {3{bin1}}, {3{bin2}}, {3{bin3}}};

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
            active_threshold <= 8'd0;
            bypass_d1 <= 96'd0;
            bypass_d2 <= 96'd0;
            gray_d1 <= 96'd0;
            gray_d2 <= 96'd0;
            binary_d1 <= 96'd0;
            binary_d2 <= 96'd0;
            mode_d1 <= MODE_BYPASS;
            mode_d2 <= MODE_BYPASS;
        end else begin
            if (sof_accept) begin
                active_mode <= i_mode_req;
                active_threshold <= i_threshold;
            end
            bypass_d1 <= i_tvalid ? i_tdata : 96'd0;
            gray_d1 <= i_tvalid ? gray_word : 96'd0;
            binary_d1 <= i_tvalid ? binary_word : 96'd0;
            bypass_d2 <= bypass_d1;
            gray_d2 <= gray_d1;
            binary_d2 <= binary_d1;
            mode_d1 <= beat_mode;
            mode_d2 <= mode_d1;
        end
    end

    always @(*) begin
        case (mode_d2)
            MODE_GRAY:   selected_data = gray_d2;
            MODE_BINARY: selected_data = binary_d2;
            MODE_SOBEL:  selected_data = sobel_data;
            default:     selected_data = bypass_d2;
        endcase
    end

    assign o_tdata = sobel_valid ? selected_data : 96'd0;
    assign o_tvalid = sobel_valid;
    assign o_tuser = sobel_user;
    assign o_tlast = sobel_last;
endmodule
