`timescale 1ns/1ps

module tb_custom_video_mode_select;
    reg clk;
    reg rst_n;
    reg [1:0] mode_req;
    reg [7:0] threshold;
    reg [95:0] rgb;
    reg valid;
    reg de;
    reg hsync;
    reg vsync;
    reg frame_start;
    reg line_end;
    wire [95:0] out_rgb;
    wire out_valid;
    wire out_de;
    wire out_hsync;
    wire out_vsync;
    wire out_frame_start;
    wire out_line_end;
    wire [1:0] mode_active;
    integer errors;

    custom_video_mode_select dut (
        .i_clk(clk), .i_rst_n(rst_n), .i_mode_req(mode_req),
        .i_threshold(threshold), .i_rgb(rgb), .i_valid(valid), .i_de(de),
        .i_hsync(hsync), .i_vsync(vsync), .i_frame_start(frame_start),
        .i_line_end(line_end), .o_rgb(out_rgb), .o_valid(out_valid),
        .o_de(out_de), .o_hsync(out_hsync), .o_vsync(out_vsync),
        .o_frame_start(out_frame_start), .o_line_end(out_line_end),
        .o_mode_active(mode_active)
    );

    always #5 clk = ~clk;

    function [7:0] ref_gray;
        input [23:0] pixel;
        reg [15:0] sum;
        begin
            sum = pixel[23:16] * 8'd77 + pixel[15:8] * 8'd150 +
                  pixel[7:0] * 8'd29 + 16'd128;
            ref_gray = sum[15:8];
        end
    endfunction

    function [95:0] ref_mode;
        input [95:0] pixels;
        input [1:0] mode;
        input [7:0] th;
        reg [7:0] y0, y1, y2, y3;
        begin
            y0 = ref_gray(pixels[95:72]);
            y1 = ref_gray(pixels[71:48]);
            y2 = ref_gray(pixels[47:24]);
            y3 = ref_gray(pixels[23:0]);
            if (mode == 2'd1)
                ref_mode = {{3{y0}}, {3{y1}}, {3{y2}}, {3{y3}}};
            else if (mode == 2'd2)
                ref_mode = {{3{(y0 >= th) ? 8'hff : 8'h00}},
                            {3{(y1 >= th) ? 8'hff : 8'h00}},
                            {3{(y2 >= th) ? 8'hff : 8'h00}},
                            {3{(y3 >= th) ? 8'hff : 8'h00}}};
            else
                ref_mode = pixels;
        end
    endfunction

    task check_equal;
        input [95:0] exp_rgb;
        input exp_valid;
        input exp_de;
        input exp_hsync;
        input exp_vsync;
        input exp_sof;
        input exp_eol;
        input [1:0] exp_mode;
        input [8*40-1:0] label;
        begin
            #1;
            if (out_rgb !== exp_rgb || out_valid !== exp_valid || out_de !== exp_de ||
                out_hsync !== exp_hsync || out_vsync !== exp_vsync ||
                out_frame_start !== exp_sof || out_line_end !== exp_eol ||
                mode_active !== exp_mode) begin
                errors = errors + 1;
                $display("ERROR %0t %0s rgb=%h/%h v=%b/%b de=%b/%b hs=%b/%b vs=%b/%b sof=%b/%b eol=%b/%b mode=%0d/%0d",
                         $time, label, out_rgb, exp_rgb, out_valid, exp_valid,
                         out_de, exp_de, out_hsync, exp_hsync, out_vsync, exp_vsync,
                         out_frame_start, exp_sof, out_line_end, exp_eol,
                         mode_active, exp_mode);
            end
        end
    endtask

    task send_beat;
        input [95:0] in_rgb;
        input in_valid;
        input in_de;
        input in_hsync;
        input in_vsync;
        input in_sof;
        input in_eol;
        input [1:0] expected_mode;
        input [8*40-1:0] label;
        begin
            @(negedge clk);
            rgb = in_rgb; valid = in_valid; de = in_de; hsync = in_hsync;
            vsync = in_vsync; frame_start = in_sof; line_end = in_eol;
            @(posedge clk);
            check_equal(ref_mode(in_rgb, expected_mode, threshold), in_valid, in_de,
                        in_hsync, in_vsync, in_sof, in_eol, expected_mode, label);
            // A beat is one clock event.  Deassert it before the caller can
            // schedule the next one, so a frame_start pulse cannot persist.
            @(negedge clk);
            rgb = 96'd0; valid = 1'b0; de = 1'b0; hsync = 1'b0;
            vsync = 1'b0; frame_start = 1'b0; line_end = 1'b0;
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        mode_req = 2'd0;
        threshold = 8'd128;
        rgb = 96'd0;
        valid = 1'b0; de = 1'b0; hsync = 1'b0; vsync = 1'b0;
        frame_start = 1'b0; line_end = 1'b0;
        errors = 0;

        // Reset output and default mode (first required reset check).
        @(posedge clk);
        check_equal(96'd0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 2'd0, "reset");
        @(negedge clk); rst_n = 1'b1;

        // Frame 1: bypass. First/last pixels of line 0 and line 1; black/white/R/G.
        mode_req = 2'd0;
        send_beat({24'h000000,24'hffffff,24'hff0000,24'h00ff00}, 1'b1,1'b1,1'b1,1'b1,1'b1,1'b0,2'd0,"f1 l0 first");
        // Mid-frame request is deliberately ignored until the next valid frame_start.
        @(negedge clk); mode_req = 2'd1;
        send_beat({24'h0000ff,24'h7f7f7f,24'h808080,24'h818181}, 1'b1,1'b1,1'b0,1'b0,1'b0,1'b1,2'd0,"f1 l0 last mid switch");
        send_beat({24'h123456,24'h654321,24'h010203,24'hfedcba}, 1'b1,1'b1,1'b1,1'b0,1'b0,1'b0,2'd0,"f1 l1 first");
        send_beat({24'h0a0b0c,24'h0d0e0f,24'h101112,24'h131415}, 1'b1,1'b1,1'b0,1'b0,1'b0,1'b1,2'd0,"f1 l1 last");
        // Blank beat proves every synchronization signal is carried through the same register.
        send_beat(96'h0, 1'b0,1'b0,1'b1,1'b0,1'b0,1'b0,2'd0,"blank marker alignment");

        // Frame 2: gray. Covers B and rounded gray reference behavior.
        send_beat({24'h0000ff,24'h010101,24'h7f7f7f,24'hffffff}, 1'b1,1'b1,1'b1,1'b1,1'b1,1'b0,2'd1,"f2 gray first");
        send_beat({24'hff0000,24'h00ff00,24'h0000ff,24'h010203}, 1'b1,1'b1,1'b0,1'b0,1'b0,1'b1,2'd1,"f2 gray last");

        // Frame 3: binary. Values are threshold-1, threshold, threshold+1, and black.
        @(negedge clk); mode_req = 2'd2;
        send_beat({24'h7f7f7f,24'h808080,24'h818181,24'h000000}, 1'b1,1'b1,1'b1,1'b1,1'b1,1'b0,2'd2,"f3 binary threshold boundaries");
        send_beat({24'hffffff,24'hff0000,24'h00ff00,24'h0000ff}, 1'b1,1'b1,1'b0,1'b0,1'b0,1'b1,2'd2,"f3 binary last");

        // Assert asynchronous reset midstream; no old valid/markers or mode may survive.
        @(negedge clk); rst_n = 1'b0;
        #1;
        check_equal(96'd0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 2'd0, "async reset midframe");
        @(negedge clk); rst_n = 1'b1; mode_req = 2'd1;
        send_beat({24'hff0000,24'h00ff00,24'h0000ff,24'hffffff}, 1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,2'd1,"post reset frame");

        if (errors == 0)
            $display("PASS: custom_video_mode_select self-check completed with zero errors.");
        else
            $display("FAIL: custom_video_mode_select self-check errors=%0d.", errors);
        $finish;
    end
endmodule
