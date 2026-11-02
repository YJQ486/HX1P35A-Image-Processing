// Align the active Lab1 AWB's early SOF to its first output pixel.
// The early event is also exposed unchanged for the legacy FIFO-reset path.
// No pixel storage, stalls, or fixed-cycle SOF delay are used.
module custom_awb_sof_aligner #(
    parameter integer FRAME_LINES = 720
)(
    input  wire        i_clk,
    input  wire        i_rst_n,
    input  wire [95:0] i_tdata,
    input  wire        i_tvalid,
    input  wire        i_awb_tuser,
    input  wire        i_tlast,
    output wire [95:0] o_tdata,
    output wire        o_tvalid,
    output wire        o_tuser,
    output wire        o_tlast,
    output wire        o_early_tuser,
    output reg         o_protocol_error,
    output reg         o_missing_sof_error,
    output reg         o_duplicate_sof_error,
    output reg         o_midframe_sof_error,
    output wire        o_data_sof_candidate
);
    localparam [1:0] ST_WAIT = 2'd0;
    localparam [1:0] ST_FRAME = 2'd1;
    localparam [1:0] ST_FAULT = 2'd2;
    localparam [10:0] LAST_LINE = FRAME_LINES - 1;

    reg [1:0] state;
    reg pending_sof;
    reg [10:0] completed_lines;

    wire missing_now;
    wire duplicate_now;
    wire midframe_now;
    wire fault_now;
    wire start_now;
    wire pass_now;

    assign missing_now = (state == ST_WAIT) &&
                         ((!pending_sof && !i_awb_tuser && i_tvalid) ||
                          (i_tlast && !i_tvalid));
    assign duplicate_now = i_awb_tuser && pending_sof;
    // A new sensor SOF can lead the final AWB line, but not an earlier line.
    // FRAME_LINES comes from the active ISP's AWB parameter, not a timer.
    assign midframe_now = (state == ST_FRAME) && i_awb_tuser &&
                          (completed_lines < LAST_LINE);
    assign fault_now = missing_now || duplicate_now || midframe_now;
    assign start_now = (state == ST_WAIT) && i_tvalid &&
                       (pending_sof || i_awb_tuser);
    assign pass_now = i_rst_n && (state != ST_FAULT) && !fault_now &&
                      ((state == ST_FRAME) || start_now);

    assign o_early_tuser = i_awb_tuser;
    assign o_tvalid = i_tvalid && pass_now;
    // Keep SOF/protocol checks off the pixel arithmetic input path.  A fault
    // suppresses o_tvalid; downstream must consume data only with valid.
    assign o_tdata = (i_rst_n && i_tvalid) ? i_tdata : 96'd0;
    assign o_tlast = i_tlast && pass_now;
    assign o_tuser = o_tvalid && start_now;
    // DATA-MUX HINT, NOT AN EVENT. On every accepted pixel WAIT is precisely
    // the first pixel, so select the requested branch before acceptance.
    // Invalid WAIT cycles may select any data; strict o_tvalid/o_tuser and
    // all frame-state commits remain unchanged. Do not use this as SOF.
    assign o_data_sof_candidate = (state == ST_WAIT);

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            state <= ST_WAIT;
            pending_sof <= 1'b0;
            completed_lines <= 11'd0;
            o_protocol_error <= 1'b0;
            o_missing_sof_error <= 1'b0;
            o_duplicate_sof_error <= 1'b0;
            o_midframe_sof_error <= 1'b0;
        end else if (state != ST_FAULT && fault_now) begin
            state <= ST_FAULT;
            pending_sof <= 1'b0;
            o_protocol_error <= 1'b1;
            if (missing_now) o_missing_sof_error <= 1'b1;
            if (duplicate_now) o_duplicate_sof_error <= 1'b1;
            if (midframe_now) o_midframe_sof_error <= 1'b1;
        end else begin
            case (state)
                ST_WAIT: begin
                    if (start_now) begin
                        pending_sof <= 1'b0;
                        if (i_tlast) begin
                            completed_lines <= 11'd1;
                            if (LAST_LINE == 11'd0)
                                state <= ST_WAIT;
                            else
                                state <= ST_FRAME;
                        end else begin
                            completed_lines <= 11'd0;
                            state <= ST_FRAME;
                        end
                    end else if (i_awb_tuser) begin
                        pending_sof <= 1'b1;
                    end
                end
                ST_FRAME: begin
                    if (i_awb_tuser)
                        pending_sof <= 1'b1;
                    if (i_tlast) begin
                        if (completed_lines == LAST_LINE) begin
                            completed_lines <= 11'd0;
                            state <= ST_WAIT;
                        end else begin
                            completed_lines <= completed_lines + 11'd1;
                        end
                    end
                end
                default: begin
                    state <= ST_FAULT;
                end
            endcase
        end
    end
endmodule
