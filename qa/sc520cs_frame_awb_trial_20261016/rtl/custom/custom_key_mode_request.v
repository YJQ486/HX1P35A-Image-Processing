// One active-low asynchronous key selects bypass, gray, binary, Sobel in order.
// The key is synchronized/debounced in i_key_clk. A closed-loop toggle CDC
// transfers one press event to i_video_clk; no multi-bit bus crosses domains.
// The downstream processor, not this module, commits o_mode_req at valid SOF.
module custom_key_mode_request #(
    parameter integer DEBOUNCE_CYCLES = 480000,
    parameter integer LONG_PRESS_CYCLES = 23809524 // 1 s at actual CAM 23.809524 MHz
)(
    input  wire       i_key_clk,
    input  wire       i_video_clk,
    input  wire       i_rst_n,
    input  wire       i_key_n,
    output reg  [1:0] o_mode_req,
    output reg        o_event_overflow,
    output wire       o_awb_bypass_req,
    output wire       o_awb_frame_req
);
    // Both clock domains assert reset asynchronously and release it locally.
    reg [1:0] key_reset_pipe;
    reg [1:0] video_reset_pipe;
    always @(posedge i_key_clk or negedge i_rst_n) begin
        if (!i_rst_n) key_reset_pipe <= 2'b00;
        else          key_reset_pipe <= {key_reset_pipe[0], 1'b1};
    end
    always @(posedge i_video_clk or negedge i_rst_n) begin
        if (!i_rst_n) video_reset_pipe <= 2'b00;
        else          video_reset_pipe <= {video_reset_pipe[0], 1'b1};
    end
    wire key_rst_n = key_reset_pipe[1];
    wire video_rst_n = video_reset_pipe[1];

    // A counter width of at least one also supports short simulation settings.
    localparam integer COUNT_WIDTH = (DEBOUNCE_CYCLES < 2) ? 1 :
                                      $clog2(DEBOUNCE_CYCLES);
    reg key_meta, key_sync;
    reg stable_key_n;
    reg [COUNT_WIDTH-1:0] debounce_count;
    reg request_toggle;
    reg pending_event;
    reg ack_meta, ack_sync;
    reg request_meta, request_sync;
    reg acknowledge_toggle;
    reg captured_long,capture_pending;
    reg [1:0] awb_mode;
    assign o_awb_bypass_req=(awb_mode==1);
    assign o_awb_frame_req=(awb_mode==2);
    wire transition_done = (key_sync != stable_key_n) &&
                           (debounce_count == DEBOUNCE_CYCLES - 1);
    // A short press is emitted on RELEASE. A long hold emits once and
    // suppresses that release's short event, so A/B cannot change four-mode.
    reg [31:0] hold_count;
    reg held_long,request_long,pending_long;
    wire long_event = !stable_key_n && !held_long &&
                      (hold_count == LONG_PRESS_CYCLES-1);
    wire short_event = transition_done && key_sync && !held_long;
    wire press_event = long_event || short_event;
    wire request_idle = (request_toggle == ack_sync);

    always @(posedge i_key_clk or negedge key_rst_n) begin
        if (!key_rst_n) begin
            key_meta <= 1'b1;
            key_sync <= 1'b1;
            stable_key_n <= 1'b1;
            debounce_count <= {COUNT_WIDTH{1'b0}};
            request_toggle <= 1'b0;
            pending_event <= 1'b0;
            ack_meta <= 1'b0;
            ack_sync <= 1'b0;
            o_event_overflow <= 1'b0;
            hold_count <= 0;
            held_long <= 0;
            request_long <= 0;
            pending_long <= 0;
        end else begin
            key_meta <= i_key_n;
            key_sync <= key_meta;
            ack_meta <= acknowledge_toggle;
            ack_sync <= ack_meta;
            if (stable_key_n) begin hold_count <= 0; held_long <= 0; end
            else if (long_event) held_long <= 1;
            else if (!held_long) hold_count <= hold_count + 1'b1;
            if (key_sync == stable_key_n)
                debounce_count <= {COUNT_WIDTH{1'b0}};
            else if (transition_done) begin
                stable_key_n <= key_sync;
                debounce_count <= {COUNT_WIDTH{1'b0}};
            end else
                debounce_count <= debounce_count + 1'b1;

            if (pending_event && request_idle) begin
                request_toggle <= ~request_toggle;
                pending_event <= press_event;
                request_long <= pending_long;
                pending_long <= long_event;
            end else if (press_event) begin
                if (request_idle) begin
                    request_toggle <= ~request_toggle;
                    request_long <= long_event;
                end else if (!pending_event) begin
                    pending_event <= 1'b1;
                    pending_long <= long_event;
                end else
                    o_event_overflow <= 1'b1;
            end
        end
    end

    always @(posedge i_video_clk or negedge video_rst_n) begin
        if (!video_rst_n) begin
            request_meta <= 1'b0;
            request_sync <= 1'b0;
            acknowledge_toggle <= 1'b0;
            o_mode_req <= 2'b00;
            awb_mode <= 2'd0;
            captured_long <= 0;
            capture_pending <= 0;
        end else begin
            request_meta <= request_toggle;
            request_sync <= request_meta;
            if (capture_pending) begin
                if (captured_long) awb_mode <= (awb_mode==2)?2'd0:awb_mode+1'b1;
                else o_mode_req <= o_mode_req + 2'b01;
                acknowledge_toggle <= request_sync;
                capture_pending <= 0;
            end else if (request_sync != acknowledge_toggle) begin
                // Held type is captured after the two-stage request has
                // settled, then consumed a cycle later. Constrain this one
                // bundled path, not an unsynchronized combinational control.
                captured_long <= request_long;
                capture_pending <= 1;
            end
        end
    end
endmodule
