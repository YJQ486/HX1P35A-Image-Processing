`timescale 1ns/1ps
// HDMI resync excerpt from design_top_wrapper.v / hdmi_tx.v (vendor-derived files
// are not published). The board uses START = 150_000_000 and END = 262_500_000
// at the 75 MHz pixel clock: 2.0 s after pixel reset release, all four TMDS
// lanes (clock included) are held at 0 for 1.5 s. Simulation shortens both.
module hdmi_resync_excerpt #(
    parameter [27:0] HDMI_RESYNC_START = 28'd20,
    parameter [27:0] HDMI_RESYNC_END   = 28'd35
)(
    input  wire       S_hdmi_pixel_clk,
    input  wire       S_hdmi_rst_n,
    input  wire [9:0] S_ch0_tmds_data, S_ch1_tmds_data, S_ch2_tmds_data, S_clk_tmds_data,
    output wire [9:0] S_ch0_tmds_out, S_ch1_tmds_out, S_ch2_tmds_out, S_clk_tmds_out,
    output reg        S_hdmi_tmds_blank
);
    reg [27:0] S_hdmi_resync_cnt;
    always @(posedge S_hdmi_pixel_clk or negedge S_hdmi_rst_n)
        if(!S_hdmi_rst_n) begin
            S_hdmi_resync_cnt <= 28'd0;
            S_hdmi_tmds_blank <= 1'b0;
        end else begin
            if(S_hdmi_resync_cnt != HDMI_RESYNC_END)
                S_hdmi_resync_cnt <= S_hdmi_resync_cnt + 28'd1;
            S_hdmi_tmds_blank <= S_hdmi_resync_cnt >= HDMI_RESYNC_START &&
                                 S_hdmi_resync_cnt != HDMI_RESYNC_END;
        end

    assign S_ch0_tmds_out = S_hdmi_tmds_blank ? 10'd0 : S_ch0_tmds_data;
    assign S_ch1_tmds_out = S_hdmi_tmds_blank ? 10'd0 : S_ch1_tmds_data;
    assign S_ch2_tmds_out = S_hdmi_tmds_blank ? 10'd0 : S_ch2_tmds_data;
    assign S_clk_tmds_out = S_hdmi_tmds_blank ? 10'd0 : S_clk_tmds_data;
endmodule

// Expect exactly one blanking pulse of END-START cycles after each reset release,
// all lanes 0 during it and unchanged pass-through otherwise.
module tb_hdmi_resync;
    reg clk = 0, rst_n = 0;
    always #5 clk = ~clk;
    wire [9:0] o0, o1, o2, oc;
    wire blank;
    hdmi_resync_excerpt dut(
        .S_hdmi_pixel_clk(clk), .S_hdmi_rst_n(rst_n),
        .S_ch0_tmds_data(10'h155), .S_ch1_tmds_data(10'h2AA),
        .S_ch2_tmds_data(10'h0F0), .S_clk_tmds_data(10'h01F),
        .S_ch0_tmds_out(o0), .S_ch1_tmds_out(o1), .S_ch2_tmds_out(o2), .S_clk_tmds_out(oc),
        .S_hdmi_tmds_blank(blank));

    integer cycle, first, width, pulses, errors;
    reg prev;
    task run_after_reset;
        integer k;
        begin
            first = -1; width = 0; pulses = 0; prev = 0;
            for (k = 0; k < 200; k = k + 1) begin
                @(posedge clk); #1;
                if (blank) begin
                    width = width + 1;
                    if (first < 0) first = k;
                    if (o0 | o1 | o2 | oc) errors = errors + 1;
                end else if (o0 !== 10'h155 || o1 !== 10'h2AA || o2 !== 10'h0F0 || oc !== 10'h01F)
                    errors = errors + 1;
                if (blank && !prev) pulses = pulses + 1;
                prev = blank;
            end
            if (first != 20 || width != 15 || pulses != 1) errors = errors + 1;
            $display("RESYNC first=%0d width=%0d pulses=%0d", first, width, pulses);
        end
    endtask

    initial begin
        errors = 0;
        #12 rst_n = 1;
        run_after_reset;
        rst_n = 0; #20 rst_n = 1;   // C7 re-arms exactly one more pulse
        run_after_reset;
        if (errors == 0) $display("PASS: hdmi resync errors=0");
        else             $display("FAIL: hdmi resync errors=%0d", errors);
        $finish;
    end
endmodule
