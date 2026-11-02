`timescale 1ns/1ps

module tb_custom_processing_top;
    parameter IMG_WIDTH = 1280;
    parameter IMG_HEIGHT = 720;
    localparam GROUPS = IMG_WIDTH / 4;
    localparam TEST_ROWS = (IMG_WIDTH > 64) ? 6 : IMG_HEIGHT;
    localparam PAT_BLACK = 0, PAT_WHITE = 1, PAT_HEDGE = 2;
    localparam PAT_VEDGE = 3, PAT_PULSE = 4, PAT_ASYM = 5;
    // Ramps: step 4 gives gradient 32 (below the noise floor), step 8 gives 64.
    localparam PAT_RAMP4 = 6, PAT_RAMP8 = 7;
    localparam NOISE_FLOOR = 48, EDGE_CORE = 40, CORE_GRAY_SHIFT = 2, EDGE_SHIFT = 1, SHADE_SHIFT = 1;
    localparam [95:0] COLORS = {24'h000000,24'hffffff,24'hff0000,24'h00ff00};
    localparam [95:0] BOUNDARY = {24'h7f7f7f,24'h808080,24'h818181,24'h0000ff};

    reg clk, rst_n;
    reg [1:0] mode_req;
    reg [7:0] threshold;
    reg [95:0] tdata;
    reg tvalid, tuser, tlast;
    wire [95:0] out_data;
    wire out_valid, out_user, out_last;
    reg [1:0] frame_mode;
    reg [7:0] frame_threshold;
    reg pending, stage_pending;
    reg [95:0] exp_data, stage_data;
    reg exp_valid, exp_user, exp_last;
    reg stage_valid, stage_user, stage_last;
    integer errors, valid_checks, marker_checks, sof_checks, eol_checks;
    integer reset_checks, hardcoded_checks;
    integer y, group_id;

    custom_processing_top #(.IMG_WIDTH(IMG_WIDTH), .IMG_HEIGHT(IMG_HEIGHT)) dut (
        .i_clk(clk), .i_rst_n(rst_n), .i_mode_req(mode_req),
        .i_threshold(threshold), .i_tdata(tdata), .i_tvalid(tvalid),
        .i_tuser(tuser), .i_tlast(tlast), .o_tdata(out_data),
        .o_tvalid(out_valid), .o_tuser(out_user), .o_tlast(out_last)
    );
    always #5 clk = ~clk;

    // Integer reference, plus fixed color checkpoints below.  This does not
    // instantiate or sample any DUT internal arithmetic or line-buffer state.
    function [7:0] ref_gray;
        input [23:0] rgb;
        integer r, g, b, sum;
        begin
            r = rgb[23:16]; g = rgb[15:8]; b = rgb[7:0];
            sum = 77*r + 150*g + 29*b + 128;
            ref_gray = sum / 256;
        end
    endfunction

    function [95:0] ref_color_word;
        input [95:0] pixels;
        input [1:0] mode;
        input [7:0] th;
        integer lane;
        reg [23:0] rgb;
        reg [7:0] lum, mono;
        reg [95:0] result;
        begin
            result = 96'd0;
            for (lane = 0; lane < 4; lane = lane + 1) begin
                rgb = pixels[(3-lane)*24 +: 24];
                lum = ref_gray(rgb);
                mono = (lum < th) ? 8'd0 : 8'd255;
                if (mode == 2'b00) result[(3-lane)*24 +: 24] = rgb;
                else if (mode == 2'b01) result[(3-lane)*24 +: 24] = {lum,lum,lum};
                else result[(3-lane)*24 +: 24] = {mono,mono,mono};
            end
            ref_color_word = result;
        end
    endfunction

    function integer source_pixel;
        input integer pattern_id, x, row;
        begin
            case (pattern_id)
                PAT_WHITE: source_pixel = 255;
                PAT_HEDGE: source_pixel = (row < 3) ? 0 : 255;
                PAT_VEDGE: source_pixel = (x < IMG_WIDTH/2) ? 0 : 255;
                PAT_PULSE: source_pixel = (x == 8 && row == 3) ? 255 : 0;
                PAT_ASYM: source_pixel = (x + 2*row + x*row) & 255;
                PAT_RAMP4: source_pixel = (x*4) & 255;
                PAT_RAMP8: source_pixel = (x*8) & 255;
                default: source_pixel = 0;
            endcase
        end
    endfunction

    function [7:0] ref_sobel_pixel;
        input integer pattern_id, center_x, center_y;
        integer a,b,c,d,e,f,g,h;
        integer left_sum, right_sum, upper_sum, lower_sum, gradient;
        begin
            if (center_x <= 0 || center_x >= IMG_WIDTH-1 ||
                center_y <= 0 || center_y >= IMG_HEIGHT-1) begin
                ref_sobel_pixel = 0;
            end else begin
                a=source_pixel(pattern_id,center_x-1,center_y-1);
                b=source_pixel(pattern_id,center_x,center_y-1);
                c=source_pixel(pattern_id,center_x+1,center_y-1);
                d=source_pixel(pattern_id,center_x-1,center_y);
                e=source_pixel(pattern_id,center_x+1,center_y);
                f=source_pixel(pattern_id,center_x-1,center_y+1);
                g=source_pixel(pattern_id,center_x,center_y+1);
                h=source_pixel(pattern_id,center_x+1,center_y+1);
                left_sum=a+2*d+f; right_sum=c+2*e+h;
                upper_sum=a+2*b+c; lower_sum=f+2*g+h;
                gradient=(left_sum>right_sum ? left_sum-right_sum : right_sum-left_sum)
                        +(upper_sum>lower_sum ? upper_sum-lower_sum : lower_sum-upper_sum);
                if (gradient < NOISE_FLOOR) ref_sobel_pixel = 0;
                else ref_sobel_pixel=(gradient>255) ? 8'd255 : gradient;
            end
        end
    endfunction

    function [95:0] ref_sobel_word;
        input integer pattern_id, row, group_num;
        integer lane;
        reg [7:0] pixel;
        reg [95:0] result;
        begin
            result=96'd0;
            for (lane=0;lane<4;lane=lane+1) begin
                pixel=ref_sobel_pixel(pattern_id,group_num*4+lane-1,row-1);
                result[(3-lane)*24 +: 24]={pixel,pixel,pixel};
            end
            ref_sobel_word=result;
        end
    endfunction

    // Pencil sketch: core = EDGE_CORE + gray >> CORE_GRAY_SHIFT;
    // 255 - min((sobel - core) << shift, 255) - (255 - gray) >> shade.
    function [7:0] ref_sketch_pixel;
        input integer sobel, gray;
        integer stroke, ink, core;
        begin
            core = EDGE_CORE + (gray >> CORE_GRAY_SHIFT);
            stroke = (sobel > core) ? (sobel - core) << EDGE_SHIFT : 0;
            if (stroke > 255) stroke = 255;
            ink = stroke + ((255 - gray) >> SHADE_SHIFT);
            ref_sketch_pixel = (ink > 255) ? 8'd0 : 255 - ink;
        end
    endfunction

    // Sobel is centered one row and one pixel behind; shading uses the current pixel.
    function [95:0] ref_sketch_word;
        input integer pattern_id, row, group_num;
        input [95:0] pixels;
        integer lane;
        reg [7:0] pixel;
        reg [95:0] result;
        begin
            for (lane=0;lane<4;lane=lane+1) begin
                pixel=ref_sketch_pixel(ref_sobel_pixel(pattern_id,group_num*4+lane-1,row-1),
                                       ref_gray(pixels[(3-lane)*24 +: 24]));
                result[(3-lane)*24 +: 24]={pixel,pixel,pixel};
            end
            ref_sketch_word=result;
        end
    endfunction

    function [95:0] stimulus_word;
        input [1:0] mode;
        input integer pattern_id, row, group_num;
        integer lane, x, v;
        reg [95:0] result;
        reg [23:0] offset;
        begin
            if (mode != 2'b11 && mode != 2'b10) begin
                if (group_num == 0) result=COLORS;
                else if (group_num == 1) result=BOUNDARY;
                else begin
                    offset=group_num+row;
                    result={24'h010203,24'hfe7f40,24'h001122,24'hbbccdd}
                            ^ {4{offset}};
                end
            end else begin
                result=96'd0;
                for (lane=0;lane<4;lane=lane+1) begin
                    x=group_num*4+lane;
                    v=source_pixel(pattern_id,x,row);
                    result[(3-lane)*24 +: 24]={3{v[7:0]}};
                end
            end
            stimulus_word=result;
        end
    endfunction

    task check_hardcoded;
        input [95:0] actual, expected;
        input [8*32-1:0] label;
        begin
            hardcoded_checks=hardcoded_checks+1;
            if (actual !== expected) begin
                errors=errors+1;
                $display("ERROR fixed %0s actual=%h expected=%h",label,actual,expected);
            end
        end
    endtask

    task queue_beat;
        input [95:0] in_data;
        input in_valid, in_user, in_last;
        input [1:0] req_mode;
        input [7:0] req_threshold;
        input integer pattern_id, row, group_num;
        begin
            @(negedge clk);
            mode_req=req_mode; threshold=req_threshold;
            tdata=in_data; tvalid=in_valid; tuser=in_user; tlast=in_last;
            pending=stage_pending;
            exp_data=stage_data; exp_valid=stage_valid;
            exp_user=stage_user; exp_last=stage_last;
            if (in_valid && in_user) begin
                frame_mode=req_mode;
                frame_threshold=req_threshold;
            end
            stage_valid=in_valid; stage_user=in_user; stage_last=in_last;
            if (!in_valid) stage_data=96'd0;
            else if (frame_mode == 2'b11)
                stage_data=ref_sobel_word(pattern_id,row,group_num);
            else if (frame_mode == 2'b10)
                stage_data=ref_sketch_word(pattern_id,row,group_num,in_data);
            else
                stage_data=ref_color_word(in_data,frame_mode,frame_threshold);
            stage_pending=1'b1;
        end
    endtask

    task send_frame;
        input [1:0] mode;
        input [7:0] th;
        input integer pattern_id;
        reg [1:0] requested_mode;
        reg [7:0] requested_threshold;
        begin
            requested_mode=mode; requested_threshold=th;
            for (y=0;y<TEST_ROWS;y=y+1) begin
                for (group_id=0;group_id<GROUPS;group_id=group_id+1) begin
                    if (y==2 && group_id==2) begin
                        requested_mode=mode+2'd1;
                        requested_threshold=8'd3;
                    end
                    queue_beat(stimulus_word(mode,pattern_id,y,group_id),1'b1,
                               y==0 && group_id==0,1'b0,
                               requested_mode,requested_threshold,pattern_id,y,group_id);
                end
                // AWB emits line end on an invalid beat.  No extra bubble follows.
                queue_beat(96'd0,1'b0,1'b0,1'b1,
                           requested_mode,requested_threshold,pattern_id,y,GROUPS);
            end
        end
    endtask

    task check_reset;
        begin
            #1;
            pending=1'b0; stage_pending=1'b0;
            reset_checks=reset_checks+1;
            if (out_data !== 96'd0 || out_valid !== 1'b0 ||
                out_user !== 1'b0 || out_last !== 1'b0) begin
                errors=errors+1;
                $display("ERROR reset outputs at %0t",$time);
            end
        end
    endtask

    always @(posedge clk) begin
        if (!rst_n) check_reset;
        else if (pending) begin
            #1;
            marker_checks=marker_checks+1;
            if (out_valid !== exp_valid || out_user !== exp_user || out_last !== exp_last) begin
                errors=errors+1;
                $display("ERROR marker time=%0t got=%b%b%b exp=%b%b%b",
                         $time,out_valid,out_user,out_last,exp_valid,exp_user,exp_last);
            end
            if (exp_valid) begin
                valid_checks=valid_checks+1;
                if (exp_user) sof_checks=sof_checks+1;
                if (out_data !== exp_data) begin
                    errors=errors+1;
                    if (errors < 20)
                        $display("ERROR data time=%0t got=%h exp=%h",$time,out_data,exp_data);
                end
            end else begin
                if (exp_last) eol_checks=eol_checks+1;
                if (out_data !== 96'd0) begin
                    errors=errors+1;
                    $display("ERROR invalid data time=%0t got=%h",$time,out_data);
                end
            end
        end
    end

    initial begin
        clk=0; rst_n=0; mode_req=0; threshold=0;
        tdata=0; tvalid=0; tuser=0; tlast=0;
        frame_mode=0; frame_threshold=0;
        pending=0; stage_pending=0;
        exp_data=0; stage_data=0;
        exp_valid=0; exp_user=0; exp_last=0;
        stage_valid=0; stage_user=0; stage_last=0;
        errors=0; valid_checks=0; marker_checks=0;
        sof_checks=0; eol_checks=0; reset_checks=0; hardcoded_checks=0;

        check_hardcoded(ref_color_word(COLORS,2'b00,8'd0),COLORS,"bypass RGB");
        check_hardcoded(ref_color_word(COLORS,2'b01,8'd0),
                        {24'h000000,24'hffffff,24'h4d4d4d,24'h959595},"known gray");
        check_hardcoded(ref_gray(24'h0000ff),8'h1d,"known blue");
        // Hand-computed sketch values: (sobel, gray) -> paper.
        check_hardcoded(ref_sketch_pixel(0,255),8'd255,"sketch flat white");
        check_hardcoded(ref_sketch_pixel(48,255),8'd255,"sketch bright noise cored");
        check_hardcoded(ref_sketch_pixel(48,0),8'd112,"sketch dark noise faint");
        check_hardcoded(ref_sketch_pixel(100,200),8'd208,"sketch bright texture faint");
        check_hardcoded(ref_sketch_pixel(200,200),8'd8,"sketch bright edge dark");
        check_hardcoded(ref_sketch_pixel(255,255),8'd0,"sketch strong edge");
        check_hardcoded(ref_sketch_pixel(0,0),8'd128,"sketch dark shading");
        if (IMG_WIDTH==16) begin
            check_hardcoded(ref_sobel_word(PAT_BLACK,3,2),96'd0,"black Sobel");
            check_hardcoded(ref_sobel_word(PAT_WHITE,3,2),96'd0,"white Sobel");
            check_hardcoded(ref_sobel_word(PAT_HEDGE,3,2),{4{24'hffffff}},"horizontal Sobel");
            check_hardcoded(ref_sobel_word(PAT_VEDGE,3,2),
                            96'hffffffffffff000000000000,"vertical Sobel");
            check_hardcoded(ref_sobel_word(PAT_PULSE,3,2),
                            96'hffffffffffffffffff000000,"pulse cross-group");
            check_hardcoded(ref_sobel_word(PAT_ASYM,3,2),
                            96'h606060686868707070787878,"asymmetric Sobel");
        end

        repeat (2) @(posedge clk);
        @(negedge clk); rst_n=1'b1;
        send_frame(2'b00,8'd64,PAT_BLACK);
        send_frame(2'b01,8'd17,PAT_BLACK);
        send_frame(2'b10,8'd128,PAT_BLACK);
        send_frame(2'b10,8'd128,PAT_HEDGE);
        send_frame(2'b10,8'd128,PAT_VEDGE);
        send_frame(2'b10,8'd128,PAT_ASYM);
        send_frame(2'b10,8'd128,PAT_RAMP4);
        send_frame(2'b10,8'd128,PAT_RAMP8);
        send_frame(2'b11,8'd31,PAT_BLACK);
        send_frame(2'b11,8'd31,PAT_WHITE);
        send_frame(2'b11,8'd31,PAT_HEDGE);
        send_frame(2'b11,8'd31,PAT_VEDGE);
        send_frame(2'b11,8'd31,PAT_PULSE);
        send_frame(2'b11,8'd31,PAT_ASYM);
        send_frame(2'b11,8'd31,PAT_RAMP4);
        send_frame(2'b11,8'd31,PAT_RAMP8);

        // Abort active traffic and verify asynchronous recovery.
        queue_beat(stimulus_word(2'b11,PAT_VEDGE,0,0),1'b1,1'b1,1'b0,
                   2'b11,8'd99,PAT_VEDGE,0,0);
        queue_beat(stimulus_word(2'b11,PAT_VEDGE,0,1),1'b1,1'b0,1'b0,
                   2'b01,8'd3,PAT_VEDGE,0,1);
        @(negedge clk); rst_n=1'b0;
        check_reset;
        @(negedge clk); rst_n=1'b1;
        send_frame(2'b11,8'd31,PAT_BLACK);
        queue_beat(96'd0,1'b0,1'b0,1'b0,2'b00,8'd0,PAT_BLACK,0,0);
        queue_beat(96'd0,1'b0,1'b0,1'b0,2'b00,8'd0,PAT_BLACK,0,0);
        @(posedge clk); #2;
        if (errors==0 && valid_checks>0 && sof_checks==18 &&
            eol_checks==17*TEST_ROWS && hardcoded_checks>=10) begin
            $display("PASS: processing top width=%0d rows=%0d valid=%0d markers=%0d sof=%0d eol=%0d reset=%0d hardcoded=%0d errors=%0d",
                     IMG_WIDTH,TEST_ROWS,valid_checks,marker_checks,sof_checks,
                     eol_checks,reset_checks,hardcoded_checks,errors);
            $finish;
        end else begin
            $display("FAIL: processing top width=%0d valid=%0d sof=%0d eol=%0d hardcoded=%0d errors=%0d",
                     IMG_WIDTH,valid_checks,sof_checks,eol_checks,hardcoded_checks,errors);
            $fatal(1,"processing top self-check failure");
        end
    end

    initial begin
        #5000000;
        $display("FAIL: processing top timeout");
        $fatal(1,"processing top timeout");
    end
endmodule
