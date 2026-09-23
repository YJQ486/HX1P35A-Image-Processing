// Equality belongs to the white class: gray >= threshold -> 8'hff.
module custom_gray_threshold (
    input  wire [7:0] i_gray,
    input  wire [7:0] i_threshold,
    output wire [7:0] o_gray
);
    assign o_gray = (i_gray >= i_threshold) ? 8'hff : 8'h00;
endmodule
