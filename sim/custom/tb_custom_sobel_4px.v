`timescale 1ns/1ps

module tb_custom_sobel_4px;
    localparam IMG_WIDTH  = 16;
    localparam IMG_HEIGHT = 6;
    localparam GROUPS     = IMG_WIDTH / 4;
    localparam PAT_BLACK  = 0;
    localparam PAT_WHITE  = 1;
    localparam PAT_VEDGE  = 2;
    localparam PAT_HEDGE  = 3;
    localparam PAT_PULSE  = 4;
    localparam PAT_ASYM   = 5;

    reg clk;
    reg rst_n;
    reg [95:0] tdata;
    reg tvalid;
    reg tuser;
    reg tlast;
    wire [95:0] out_tdata;
    wire out_tvalid;
    wire out_tuser;
    wire out_tlast;

    reg exp_pending;
    reg exp_stage_pending;
    reg [95:0] exp_tdata;
    reg exp_tvalid;
    reg exp_tuser;
    reg exp_tlast;
    reg [95:0] exp_stage_tdata;
    reg exp_stage_tvalid;
    reg exp_stage_tuser;
    reg exp_stage_tlast;
    integer errors;
    integer valid_checks;
    integer marker_checks;
    integer reset_checks;
    integer hardcoded_checks;

    custom_sobel_4px #(
        .IMG_WIDTH(IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT)
    ) dut (
        .i_clk(clk), .i_rst_n(rst_n),
        .i_tdata(tdata), .i_tvalid(tvalid), .i_tuser(tuser), .i_tlast(tlast),
        .o_tdata(out_tdata), .o_tvalid(out_tvalid),
        .o_tuser(out_tuser), .o_tlast(out_tlast)
    );

    always #5 clk = ~clk;

    function integer source_pixel;
        input integer pattern_id;
        input integer x;
        input integer y;
        begin
            case (pattern_id)
                PAT_WHITE: source_pixel = 255;
                PAT_VEDGE: source_pixel = (x < 8) ? 0 : 255;
                PAT_HEDGE: source_pixel = (y < 3) ? 0 : 255;
                PAT_PULSE: source_pixel = ((x == 8) && (y == 3)) ? 255 : 0;
                // Deliberately non-symmetric in both axes and below clipping.
                PAT_ASYM:  source_pixel = x + (2*y) + (x*y);
                default: source_pixel = 0;
            endcase
        end
    endfunction

    function [7:0] reference_sobel;
        input integer pattern_id;
        input integer center_x;
        input integer center_y;
        integer p00, p01, p02, p10, p12, p20, p21, p22;
        integer gx, gy, magnitude;
        begin
            if ((center_x <= 0) || (center_x >= IMG_WIDTH-1) ||
                (center_y <= 0) || (center_y >= IMG_HEIGHT-1)) begin
                reference_sobel = 8'd0;
            end else begin
                p00 = source_pixel(pattern_id, center_x-1, center_y-1);
                p01 = source_pixel(pattern_id, center_x,   center_y-1);
                p02 = source_pixel(pattern_id, center_x+1, center_y-1);
                p10 = source_pixel(pattern_id, center_x-1, center_y);
                p12 = source_pixel(pattern_id, center_x+1, center_y);
                p20 = source_pixel(pattern_id, center_x-1, center_y+1);
                p21 = source_pixel(pattern_id, center_x,   center_y+1);
                p22 = source_pixel(pattern_id, center_x+1, center_y+1);
                gx = -p00 + p02 - (2*p10) + (2*p12) - p20 + p22;
                gy =  p00 + (2*p01) + p02 - p20 - (2*p21) - p22;
                if (gx < 0) gx = -gx;
                if (gy < 0) gy = -gy;
                magnitude = gx + gy;
                reference_sobel = (magnitude > 255) ? 8'hff : magnitude[7:0];
            end
        end
    endfunction

    function [95:0] input_word;
        input integer pattern_id;
        input integer y;
        input integer group_id;
        integer p0, p1, p2, p3;
        begin
            p0 = source_pixel(pattern_id, group_id*4+0, y);
            p1 = source_pixel(pattern_id, group_id*4+1, y);
            p2 = source_pixel(pattern_id, group_id*4+2, y);
            p3 = source_pixel(pattern_id, group_id*4+3, y);
            input_word = {{3{p0[7:0]}}, {3{p1[7:0]}}, {3{p2[7:0]}}, {3{p3[7:0]}}};
        end
    endfunction

    function [95:0] expected_word;
        input integer pattern_id;
        input integer output_y;
        input integer group_id;
        integer x0;
        reg [7:0] e0, e1, e2, e3;
        begin
            x0 = group_id * 4;
            // Causal mapping: output (x,y) carries source-center (x-1,y-1).
            e0 = reference_sobel(pattern_id, x0-1, output_y-1);
            e1 = reference_sobel(pattern_id, x0+0, output_y-1);
            e2 = reference_sobel(pattern_id, x0+1, output_y-1);
            e3 = reference_sobel(pattern_id, x0+2, output_y-1);
            expected_word = {{3{e0}}, {3{e1}}, {3{e2}}, {3{e3}}};
        end
    endfunction

    task check_hardcoded_reference;
        input [95:0] actual;
        input [95:0] expected;
        input [8*32-1:0] label;
        begin
            hardcoded_checks = hardcoded_checks + 1;
            if (actual !== expected) begin
                errors = errors + 1;
                $display("ERROR hardcoded reference %0s got=%h exp=%h", label, actual, expected);
            end
        end
    endtask

    task queue_beat;
        input [95:0] in_data;
        input in_valid;
        input in_user;
        input in_last;
        input [95:0] expected_data;
        begin
            @(negedge clk);
            tdata = in_data;
            tvalid = in_valid;
            tuser = in_user;
            tlast = in_last;
            exp_pending = exp_stage_pending;
            exp_tdata = exp_stage_tdata;
            exp_tvalid = exp_stage_tvalid;
            exp_tuser = exp_stage_tuser;
            exp_tlast = exp_stage_tlast;
            exp_stage_tdata = expected_data;
            exp_stage_tvalid = in_valid;
            exp_stage_tuser = in_user;
            exp_stage_tlast = in_last;
            exp_stage_pending = 1'b1;
        end
    endtask

    task send_frame;
        input integer pattern_id;
        integer y;
        integer group_id;
        begin
            for (y = 0; y < IMG_HEIGHT; y = y + 1) begin
                for (group_id = 0; group_id < GROUPS; group_id = group_id + 1) begin
                    queue_beat(input_word(pattern_id, y, group_id), 1'b1,
                               (y == 0) && (group_id == 0), 1'b0,
                               expected_word(pattern_id, y, group_id));
                end
                // Real AWB convention: line end is an invalid marker beat.
                queue_beat(96'd0, 1'b0, 1'b0, 1'b1, 96'd0);
            end
        end
    endtask

    task check_reset;
        begin
            #1;
            exp_pending = 1'b0;
            exp_stage_pending = 1'b0;
            reset_checks = reset_checks + 1;
            if (out_tdata !== 96'd0 || out_tvalid !== 1'b0 ||
                out_tuser !== 1'b0 || out_tlast !== 1'b0) begin
                errors = errors + 1;
                $display("ERROR reset output not clean at %0t", $time);
            end
        end
    endtask

    always @(posedge clk) begin
        if (!rst_n) begin
            check_reset;
        end else if (exp_pending) begin
            #1;
            marker_checks = marker_checks + 1;
            if (out_tvalid !== exp_tvalid || out_tuser !== exp_tuser || out_tlast !== exp_tlast) begin
                errors = errors + 1;
                $display("ERROR marker at %0t v=%b/%b u=%b/%b l=%b/%b",
                         $time, out_tvalid, exp_tvalid, out_tuser, exp_tuser,
                         out_tlast, exp_tlast);
            end
            if (exp_tvalid) begin
                valid_checks = valid_checks + 1;
                if (out_tdata !== exp_tdata) begin
                    errors = errors + 1;
                    $display("ERROR data at %0t got=%h exp=%h", $time, out_tdata, exp_tdata);
                end
            end else if (out_tdata !== 96'd0) begin
                errors = errors + 1;
                $display("ERROR invalid beat carried data at %0t got=%h", $time, out_tdata);
            end
        end
    end

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        tdata = 96'd0;
        tvalid = 1'b0;
        tuser = 1'b0;
        tlast = 1'b0;
        exp_pending = 1'b0;
        exp_stage_pending = 1'b0;
        exp_tdata = 96'd0;
        exp_tvalid = 1'b0;
        exp_tuser = 1'b0;
        exp_tlast = 1'b0;
        exp_stage_tdata = 96'd0;
        exp_stage_tvalid = 1'b0;
        exp_stage_tuser = 1'b0;
        exp_stage_tlast = 1'b0;
        errors = 0;
        valid_checks = 0;
        marker_checks = 0;
        reset_checks = 0;
        hardcoded_checks = 0;

        // Independent fixed checkpoints for saturation, orientation and shift.
        check_hardcoded_reference(expected_word(PAT_BLACK, 3, 2),
                                  96'h000000000000000000000000, "black interior");
        check_hardcoded_reference(expected_word(PAT_WHITE, 3, 2),
                                  96'h000000000000000000000000, "white interior");
        check_hardcoded_reference(expected_word(PAT_VEDGE, 3, 2),
                                  96'hffffffffffff000000000000, "vertical edge");
        check_hardcoded_reference(expected_word(PAT_HEDGE, 3, 2),
                                  96'hffffffffffffffffffffffff, "horizontal edge");
        check_hardcoded_reference(expected_word(PAT_PULSE, 3, 2),
                                  96'hffffffffffffffffff000000, "pulse upper row");
        check_hardcoded_reference(expected_word(PAT_PULSE, 4, 2),
                                  96'hffffff000000ffffff000000, "pulse center row");
        check_hardcoded_reference(expected_word(PAT_ASYM, 3, 2),
                                  96'h606060686868707070787878, "asymmetric 2D");

        repeat (2) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;

        // Back-to-back frames, separated only by the required invalid tlast beat.
        send_frame(PAT_BLACK);
        send_frame(PAT_WHITE);
        send_frame(PAT_VEDGE);
        send_frame(PAT_HEDGE);
        send_frame(PAT_PULSE);
        send_frame(PAT_ASYM);

        // Begin another frame, then reset in the middle of its second line.
        queue_beat(input_word(PAT_VEDGE, 0, 0), 1'b1, 1'b1, 1'b0,
                   expected_word(PAT_VEDGE, 0, 0));
        queue_beat(input_word(PAT_VEDGE, 0, 1), 1'b1, 1'b0, 1'b0,
                   expected_word(PAT_VEDGE, 0, 1));
        queue_beat(input_word(PAT_VEDGE, 0, 2), 1'b1, 1'b0, 1'b0,
                   expected_word(PAT_VEDGE, 0, 2));
        queue_beat(input_word(PAT_VEDGE, 0, 3), 1'b1, 1'b0, 1'b0,
                   expected_word(PAT_VEDGE, 0, 3));
        queue_beat(96'd0, 1'b0, 1'b0, 1'b1, 96'd0);
        queue_beat(input_word(PAT_VEDGE, 1, 0), 1'b1, 1'b0, 1'b0,
                   expected_word(PAT_VEDGE, 1, 0));
        queue_beat(input_word(PAT_VEDGE, 1, 1), 1'b1, 1'b0, 1'b0,
                   expected_word(PAT_VEDGE, 1, 1));
        @(negedge clk);
        rst_n = 1'b0;
        check_reset;
        @(negedge clk);
        rst_n = 1'b1;

        // A complete black frame proves clean recovery without clearing RAMs.
        send_frame(PAT_BLACK);
        queue_beat(96'd0, 1'b0, 1'b0, 1'b0, 96'd0);
        @(posedge clk);
        #2;

        if ((errors == 0) && (hardcoded_checks == 7)) begin
            $display("PASS: sobel checks valid=%0d marker=%0d reset=%0d hardcoded=%0d errors=%0d",
                     valid_checks, marker_checks, reset_checks, hardcoded_checks, errors);
            $finish;
        end else begin
            $display("FAIL: sobel checks valid=%0d marker=%0d reset=%0d hardcoded=%0d errors=%0d",
                     valid_checks, marker_checks, reset_checks, hardcoded_checks, errors);
            $fatal(1, "sobel self-check failure");
        end
    end

    initial begin
        #100000;
        $display("FAIL: sobel timeout");
        $fatal(1, "sobel timeout");
    end
endmodule
