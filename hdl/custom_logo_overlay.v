// DDR-output RGB888, positive VS, DE pixel cadence; no backpressure.
// Three registered stages: ROM address, ROM fetch, alpha composition.
module custom_logo_overlay #(parameter X=1088, Y=16)(
 input i_clk,i_rst_n,i_vs,i_hs,i_de,input [23:0] i_rgb,
 output reg o_vs,o_hs,o_de,output reg [23:0] o_rgb);
 reg [11:0] x,y;reg old_de;
 reg [14:0] addr;wire [24:0] pixel;
 reg [1:0] hit,vs,hs,de;
 reg [23:0] rgb0,rgb1;
 wire inside_logo=i_de && x>=X && x<X+160 && y>=Y && y<Y+160;
 wire [11:0] lx=x-X,ly=y-Y;
 custom_logo_rom u_rom(.I_clk(i_clk),.I_addr(addr),.O_pixel(pixel));
 always @(posedge i_clk or negedge i_rst_n)begin
  if(!i_rst_n)begin
   x<=0;y<=0;old_de<=0;addr<=0;hit<=0;vs<=0;hs<=0;de<=0;
   rgb0<=0;rgb1<=0;o_vs<=0;o_hs<=0;o_de<=0;o_rgb<=0;
  end else begin
   old_de<=i_de;
   if(i_vs)y<=0;else if(old_de&&!i_de)y<=y+1'b1;
   if(!i_de)x<=0;else x<=x+1'b1;
   addr<=inside_logo ? ly*15'd160+lx : 15'd0;
   hit<={hit[0],inside_logo};vs<={vs[0],i_vs};hs<={hs[0],i_hs};de<={de[0],i_de};
   rgb0<=i_rgb;rgb1<=rgb0;
   o_vs<=vs[1];o_hs<=hs[1];o_de<=de[1];
   o_rgb<=!de[1]?24'd0:((hit[1]&&pixel[24])?pixel[23:0]:rgb1);
  end
 end
endmodule
// Rows 34..127 of the 160x160 logo hold every opaque pixel; other rows read as
// transparent.  One registered read, as before, so the overlay pipeline is unchanged.
module custom_logo_rom #(parameter INIT_FILE="custom_logo_rom.hex")(
    input wire I_clk,
    input wire [14:0] I_addr,
    output wire [24:0] O_pixel
);
    localparam BASE=5440, DEPTH=15040;
    // synthesis ram_style = bram
    reg [24:0] S_mem [0:DEPTH-1];
    reg [24:0] S_q;
    reg        S_in_range;
    wire [14:0] S_index=I_addr-BASE;
    initial $readmemh(INIT_FILE,S_mem);
    always @(posedge I_clk) begin
        S_q<=S_mem[S_index[13:0]];
        S_in_range<=I_addr>=BASE && I_addr<BASE+DEPTH;
    end
    // Only the alpha bit needs gating: the overlay ignores color when alpha is 0.
    assign O_pixel={S_q[24]&S_in_range,S_q[23:0]};
endmodule
