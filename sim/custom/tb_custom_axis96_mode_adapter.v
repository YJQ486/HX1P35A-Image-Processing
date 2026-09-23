`timescale 1ns/1ps

module tb_custom_axis96_mode_adapter;
    localparam MODE_BYPASS = 2'd0;
    localparam MODE_GRAY   = 2'd1;
    localparam MODE_BINARY = 2'd2;
    localparam [95:0] COLOR_WORD = {24'h000000, 24'hffffff, 24'hff0000, 24'h00ff00};
    // Fixed expected luma: black=00, white=ff, red=4d, green=95.
    localparam [95:0] GRAY_COLOR_WORD = {24'h000000, 24'hffffff, 24'h4d4d4d, 24'h959595};
    localparam [95:0] BLUE_BOUNDARY_WORD = {24'h0000ff, 24'h7f7f7f, 24'h808080, 24'h818181};
    localparam [95:0] GRAY_BLUE_BOUNDARY_WORD = {24'h1d1d1d, 24'h7f7f7f, 24'h808080, 24'h818181};
    localparam [95:0] BINARY_BOUNDARY_WORD = {24'h000000, 24'h000000, 24'hffffff, 24'hffffff};

    reg clk;
    reg rst_n;
    reg [1:0] mode_req;
    reg [7:0] threshold;
    reg [95:0] tdata;
    reg tvalid;
    reg tuser;
    reg tlast;
    wire [95:0] out_tdata;
    wire out_tvalid;
    wire out_tuser;
    wire out_tlast;
    wire [1:0] out_mode_active;
    wire [7:0] out_threshold_active;

    reg exp_pending;
    reg [95:0] exp_tdata;
    reg exp_tvalid;
    reg exp_tuser;
    reg exp_tlast;
    reg [1:0] exp_mode;
    reg [7:0] exp_threshold;
    integer errors;
    integer valid_checks;
    integer marker_checks;
    integer reset_checks;
    integer i;

    custom_axis96_mode_adapter dut (
        .i_clk(clk), .i_rst_n(rst_n),
        .i_mode_req(mode_req), .i_threshold(threshold),
        .i_tdata(tdata), .i_tvalid(tvalid), .i_tuser(tuser), .i_tlast(tlast),
        .o_tdata(out_tdata), .o_tvalid(out_tvalid), .o_tuser(out_tuser),
        .o_tlast(out_tlast), .o_mode_active(out_mode_active),
        .o_threshold_active(out_threshold_active)
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

    function [95:0] ref_word;
        input [95:0] pixels;
        input [1:0] mode;
        input [7:0] th;
        reg [7:0] y0, y1, y2, y3;
        begin
            y0 = ref_gray(pixels[95:72]);
            y1 = ref_gray(pixels[71:48]);
            y2 = ref_gray(pixels[47:24]);
            y3 = ref_gray(pixels[23:0]);
            case (mode)
                MODE_GRAY: ref_word = {{3{y0}}, {3{y1}}, {3{y2}}, {3{y3}}};
                MODE_BINARY: ref_word = {{3{(y0 >= th) ? 8'hff : 8'h00}},
                                          {3{(y1 >= th) ? 8'hff : 8'h00}},
                                          {3{(y2 >= th) ? 8'hff : 8'h00}},
                                          {3{(y3 >= th) ? 8'hff : 8'h00}}};
                default: ref_word = pixels;
            endcase
        end
    endfunction

    function [95:0] pattern_word;
        input [1:0] frame_id;
        input [8:0] beat_id;
        reg [7:0] a, b, c, d;
        begin
            a = beat_id[7:0];
            b = beat_id[7:0] + 8'h31;
            c = beat_id[7:0] + 8'h62;
            d = beat_id[7:0] + 8'h93;
            pattern_word = {{a, b, c}, {b, c, d}, {c, d, a}, {d, a, b}};
        end
    endfunction

    task queue_and_drive;
        input [95:0] in_data;
        input in_valid;
        input in_user;
        input in_last;
        input [95:0] expected_data;
        input [1:0] expected_mode;
        input [7:0] expected_threshold;
        begin
            @(negedge clk);
            tdata = in_data;
            tvalid = in_valid;
            tuser = in_user;
            tlast = in_last;
            exp_tdata = expected_data;
            exp_tvalid = in_valid;
            exp_tuser = in_user;
            exp_tlast = in_last;
            exp_mode = expected_mode;
            exp_threshold = expected_threshold;
            exp_pending = 1'b1;
        end
    endtask

    task check_reset;
        begin
            #1;
            exp_pending = 1'b0;
            reset_checks = reset_checks + 1;
            if (out_tdata !== 96'd0 || out_tvalid !== 1'b0 || out_tuser !== 1'b0 ||
                out_tlast !== 1'b0 || out_mode_active !== MODE_BYPASS ||
                out_threshold_active !== 8'd0) begin
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
            if (out_tvalid !== exp_tvalid || out_tuser !== exp_tuser ||
                out_tlast !== exp_tlast || out_mode_active !== exp_mode ||
                out_threshold_active !== exp_threshold) begin
                errors = errors + 1;
                $display("ERROR marker/state at %0t v=%b/%b u=%b/%b l=%b/%b mode=%0d/%0d th=%0d/%0d",
                    $time, out_tvalid, exp_tvalid, out_tuser, exp_tuser,
                    out_tlast, exp_tlast, out_mode_active, exp_mode,
                    out_threshold_active, exp_threshold);
            end
            if (exp_tvalid) begin
                valid_checks = valid_checks + 1;
                if (out_tdata !== exp_tdata) begin
                    errors = errors + 1;
                    $display("ERROR data at %0t got=%h exp=%h", $time, out_tdata, exp_tdata);
                end
            end
        end
    end

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        mode_req = MODE_BYPASS;
        threshold = 8'd64;
        tdata = 96'd0;
        tvalid = 1'b0;
        tuser = 1'b0;
        tlast = 1'b0;
        exp_pending = 1'b0;
        exp_tdata = 96'd0;
        exp_tvalid = 1'b0;
        exp_tuser = 1'b0;
        exp_tlast = 1'b0;
        exp_mode = MODE_BYPASS;
        exp_threshold = 8'd0;
        errors = 0;
        valid_checks = 0;
        marker_checks = 0;
        reset_checks = 0;

        // Startup reset, then frame 1: 320 consecutive valid beats, bypass.
        repeat (2) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;
        for (i = 0; i < 320; i = i + 1) begin
            if (i == 100) begin
                // Frame-1 mid-frame request: must not affect this frame.
                mode_req = MODE_GRAY;
                threshold = 8'd17;
            end
            if (i == 0)
                queue_and_drive(COLOR_WORD, 1'b1, 1'b1, 1'b0,
                                COLOR_WORD, MODE_BYPASS, 8'd64);
            else
                queue_and_drive(pattern_word(2'd0, i[8:0]), 1'b1, 1'b0, (i == 319),
                                pattern_word(2'd0, i[8:0]), MODE_BYPASS, 8'd64);
        end

        // Frame 2 starts on the next clock: no invalid bubble after frame 1.
        for (i = 0; i < 320; i = i + 1) begin
            if (i == 100) begin
                // Frame-2 mid-frame request: binary and threshold 128 wait for frame 3.
                mode_req = MODE_BINARY;
                threshold = 8'd128;
            end
            if (i == 0)
                queue_and_drive(COLOR_WORD, 1'b1, 1'b1, 1'b0,
                                GRAY_COLOR_WORD, MODE_GRAY, 8'd17);
            else if (i == 1)
                queue_and_drive(BLUE_BOUNDARY_WORD, 1'b1, 1'b0, 1'b0,
                                GRAY_BLUE_BOUNDARY_WORD, MODE_GRAY, 8'd17);
            else
                queue_and_drive(pattern_word(2'd1, i[8:0]), 1'b1, 1'b0, (i == 319),
                                ref_word(pattern_word(2'd1, i[8:0]), MODE_GRAY, 8'd17), MODE_GRAY, 8'd17);
        end

        // Frame 3 immediately follows and atomically accepts binary/128.
        for (i = 0; i < 320; i = i + 1) begin
            if (i == 0)
                queue_and_drive(BLUE_BOUNDARY_WORD, 1'b1, 1'b1, 1'b0,
                                BINARY_BOUNDARY_WORD, MODE_BINARY, 8'd128);
            else
                queue_and_drive(pattern_word(2'd2, i[8:0]), 1'b1, 1'b0, (i == 319),
                                ref_word(pattern_word(2'd2, i[8:0]), MODE_BINARY, 8'd128), MODE_BINARY, 8'd128);
        end

        // Real AWB line tail: tlast is asserted after tvalid falls.  Deliberately
        // change both requests; an invalid tlast beat must not latch either one.
        mode_req = MODE_GRAY;
        threshold = 8'd3;
        queue_and_drive(96'd0, 1'b0, 1'b0, 1'b1, 96'd0, MODE_BINARY, 8'd128);

        // Asynchronous reset after active traffic must clear stream and frame state.
        @(negedge clk);
        rst_n = 1'b0;
        check_reset;
        @(negedge clk);
        rst_n = 1'b1;
        mode_req = MODE_GRAY;
        threshold = 8'd200;
        queue_and_drive(COLOR_WORD, 1'b1, 1'b1, 1'b1,
                        GRAY_COLOR_WORD, MODE_GRAY, 8'd200);
        queue_and_drive(96'd0, 1'b0, 1'b0, 1'b0, 96'd0, MODE_GRAY, 8'd200);

        @(posedge clk);
        #2;
        if (errors == 0 && valid_checks == 961 && marker_checks >= 962) begin
            $display("PASS: adapter checks valid=%0d marker=%0d reset=%0d errors=%0d",
                     valid_checks, marker_checks, reset_checks, errors);
            $finish;
        end else begin
            $display("FAIL: adapter checks valid=%0d marker=%0d reset=%0d errors=%0d",
                     valid_checks, marker_checks, reset_checks, errors);
            $fatal(1, "self-check failure");
        end
    end

    initial begin
        #20000;
        $display("FAIL: timeout");
        $fatal(1, "timeout");
    end
endmodule
