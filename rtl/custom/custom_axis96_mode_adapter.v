// Real lab_ex1/lab_ex2 insertion-point adapter: AWB's four-lane RGB888 stream.
// There is deliberately no DE/HSYNC/VSYNC port at this point in the pipeline.
// tuser is frame_start and tlast is line_end; both are delayed exactly one clock.
module custom_axis96_mode_adapter (
    input  wire        i_clk,
    input  wire        i_rst_n,
    input  wire [1:0]  i_mode_req,
    input  wire [7:0]  i_threshold,
    input  wire [95:0] i_tdata,
    input  wire        i_tvalid,
    input  wire        i_tuser,
    input  wire        i_tlast,
    output reg  [95:0] o_tdata,
    output reg         o_tvalid,
    output reg         o_tuser,
    output reg         o_tlast,
    output reg  [1:0]  o_mode_active,
    output reg  [7:0]  o_threshold_active
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

    custom_rgb_passthrough u_bypass (.i_rgb(i_tdata), .o_rgb(bypass_rgb));
    custom_rgb_to_gray u_gray0 (.i_rgb(i_tdata[95:72]), .o_gray(gray0));
    custom_rgb_to_gray u_gray1 (.i_rgb(i_tdata[71:48]), .o_gray(gray1));
    custom_rgb_to_gray u_gray2 (.i_rgb(i_tdata[47:24]), .o_gray(gray2));
    custom_rgb_to_gray u_gray3 (.i_rgb(i_tdata[23:0]),  .o_gray(gray3));
    custom_gray_threshold u_bin0 (.i_gray(gray0), .i_threshold(selected_threshold), .o_gray(bin0));
    custom_gray_threshold u_bin1 (.i_gray(gray1), .i_threshold(selected_threshold), .o_gray(bin1));
    custom_gray_threshold u_bin2 (.i_gray(gray2), .i_threshold(selected_threshold), .o_gray(bin2));
    custom_gray_threshold u_bin3 (.i_gray(gray3), .i_threshold(selected_threshold), .o_gray(bin3));

    assign gray_rgb   = {{3{gray0}}, {3{gray1}}, {3{gray2}}, {3{gray3}}};
    assign binary_rgb = {{3{bin0}},  {3{bin1}},  {3{bin2}},  {3{bin3}}};
    assign requested_mode = (i_mode_req == MODE_GRAY || i_mode_req == MODE_BINARY) ?
                            i_mode_req : MODE_BYPASS;
    // On a valid SOF beat, the data itself uses the same fresh mode/threshold
    // that is committed to the frame state below.
    assign selected_mode = (i_tvalid && i_tuser) ? requested_mode : o_mode_active;
    assign selected_threshold = (i_tvalid && i_tuser) ? i_threshold : o_threshold_active;

    always @(*) begin
        case (selected_mode)
            MODE_GRAY:   selected_rgb = gray_rgb;
            MODE_BINARY: selected_rgb = binary_rgb;
            default:     selected_rgb = bypass_rgb;
        endcase
    end

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            o_tdata             <= 96'd0;
            o_tvalid            <= 1'b0;
            o_tuser             <= 1'b0;
            o_tlast             <= 1'b0;
            o_mode_active       <= MODE_BYPASS;
            o_threshold_active  <= 8'd0;
        end else begin
            if (i_tvalid && i_tuser) begin
                o_mode_active      <= requested_mode;
                o_threshold_active <= i_threshold;
            end
            o_tdata  <= selected_rgb;
            o_tvalid <= i_tvalid;
            o_tuser  <= i_tuser;
            o_tlast  <= i_tlast;
        end
    end
endmodule
