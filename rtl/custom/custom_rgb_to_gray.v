// RGB888 is {R[7:0], G[7:0], B[7:0]}.
// Y = (77*R + 150*G + 29*B + 128) >> 8, rounded BT.601-style luma.
module custom_rgb_to_gray (
    input  wire [23:0] i_rgb,
    output wire [7:0]  o_gray
);
    wire [15:0] weighted_sum;

    assign weighted_sum = (i_rgb[23:16] * 8'd77) +
                          (i_rgb[15:8]  * 8'd150) +
                          (i_rgb[7:0]   * 8'd29) + 16'd128;
    assign o_gray = weighted_sum[15:8];
endmodule
