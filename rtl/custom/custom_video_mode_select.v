// Registered four-pixel RGB888 processing stage.  This is Verilog-2001.
// i_frame_start must be asserted with i_valid on the first beat of a frame.
module custom_video_mode_select (
    input  wire        i_clk,
    input  wire        i_rst_n,
    input  wire [1:0]  i_mode_req,
    input  wire [7:0]  i_threshold,
    input  wire [95:0] i_rgb,
    input  wire        i_valid,
    input  wire        i_de,
    input  wire        i_hsync,
    input  wire        i_vsync,
    input  wire        i_frame_start,
    input  wire        i_line_end,
    output reg  [95:0] o_rgb,
    output reg         o_valid,
    output reg         o_de,
    output reg         o_hsync,
    output reg         o_vsync,
    output reg         o_frame_start,
    output reg         o_line_end,
    output reg  [1:0]  o_mode_active
);
    localparam MODE_BYPASS = 2'd0;
    localparam MODE_GRAY   = 2'd1;
    localparam MODE_BINARY = 2'd2;

    wire [95:0] bypass_rgb;
    wire [7:0] gray0;
    wire [7:0] gray1;
    wire [7:0] gray2;
    wire [7:0] gray3;
    wire [7:0] bin0;
    wire [7:0] bin1;
    wire [7:0] bin2;
    wire [7:0] bin3;
    wire [95:0] gray_rgb;
    wire [95:0] binary_rgb;
    wire [1:0] requested_mode;
    wire [1:0] selected_mode;
    wire [7:0] selected_threshold;
    reg  [95:0] selected_rgb;
    reg  [7:0] threshold_active;

    custom_rgb_passthrough u_bypass (.i_rgb(i_rgb), .o_rgb(bypass_rgb));
    custom_rgb_to_gray u_gray0 (.i_rgb(i_rgb[95:72]), .o_gray(gray0));
    custom_rgb_to_gray u_gray1 (.i_rgb(i_rgb[71:48]), .o_gray(gray1));
    custom_rgb_to_gray u_gray2 (.i_rgb(i_rgb[47:24]), .o_gray(gray2));
    custom_rgb_to_gray u_gray3 (.i_rgb(i_rgb[23:0]),  .o_gray(gray3));
    custom_gray_threshold u_bin0 (.i_gray(gray0), .i_threshold(selected_threshold), .o_gray(bin0));
    custom_gray_threshold u_bin1 (.i_gray(gray1), .i_threshold(selected_threshold), .o_gray(bin1));
    custom_gray_threshold u_bin2 (.i_gray(gray2), .i_threshold(selected_threshold), .o_gray(bin2));
    custom_gray_threshold u_bin3 (.i_gray(gray3), .i_threshold(selected_threshold), .o_gray(bin3));

    assign gray_rgb   = {{3{gray0}}, {3{gray1}}, {3{gray2}}, {3{gray3}}};
    assign binary_rgb = {{3{bin0}},  {3{bin1}},  {3{bin2}},  {3{bin3}}};
    assign requested_mode = (i_mode_req == MODE_GRAY || i_mode_req == MODE_BINARY) ?
                            i_mode_req : MODE_BYPASS;
    assign selected_mode = (i_valid && i_frame_start) ? requested_mode : o_mode_active;
    assign selected_threshold = (i_valid && i_frame_start) ? i_threshold : threshold_active;

    always @(*) begin
        case (selected_mode)
            MODE_GRAY:   selected_rgb = gray_rgb;
            MODE_BINARY: selected_rgb = binary_rgb;
            default:     selected_rgb = bypass_rgb;
        endcase
    end

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            o_rgb         <= 96'd0;
            o_valid       <= 1'b0;
            o_de          <= 1'b0;
            o_hsync       <= 1'b0;
            o_vsync       <= 1'b0;
            o_frame_start <= 1'b0;
            o_line_end    <= 1'b0;
            o_mode_active <= MODE_BYPASS;
            threshold_active <= 8'd0;
        end else begin
            if (i_valid && i_frame_start) begin
                o_mode_active <= requested_mode;
                threshold_active <= i_threshold;
            end
            o_rgb         <= selected_rgb;
            o_valid       <= i_valid;
            o_de          <= i_de;
            o_hsync       <= i_hsync;
            o_vsync       <= i_vsync;
            o_frame_start <= i_frame_start;
            o_line_end    <= i_line_end;
        end
    end
endmodule
