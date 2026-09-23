// Four RGB888 pixels per beat, lane order [95:72] through [23:0].
module custom_rgb_passthrough (
    input  wire [95:0] i_rgb,
    output wire [95:0] o_rgb
);
    assign o_rgb = i_rgb;
endmodule
