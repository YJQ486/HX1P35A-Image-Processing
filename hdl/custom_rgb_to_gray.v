// Bit-exact (77R+150G+29B+128)>>8, carry-save tree, no extra cycle.
module custom_rgb_to_gray(input wire [23:0] i_rgb,output wire [7:0] o_gray);
 wire [15:0] r={8'd0,i_rgb[23:16]},g={8'd0,i_rgb[15:8]},b={8'd0,i_rgb[7:0]};
 function [31:0] csa;
 input [15:0] a,bv,c;
 reg [15:0] s,t;
 begin s=a^bv^c;t=((a&bv)|(a&c)|(bv&c))<<1;csa={t,s};end
 endfunction
 wire [31:0] a0=csa(r<<6,r<<3,r<<2);
 wire [31:0] a1=csa(g<<7,g<<4,g<<2);
 wire [31:0] a2=csa(b<<4,b<<3,b<<2);
 wire [31:0] a3=csa(a0[15:0],a0[31:16],r);
 wire [31:0] a4=csa(a1[15:0],a1[31:16],g<<1);
 wire [31:0] a5=csa(a2[15:0],a2[31:16],b);
 wire [31:0] a6=csa(a3[15:0],a3[31:16],a4[15:0]);
 wire [31:0] a7=csa(a4[31:16],a5[15:0],a5[31:16]);
 wire [31:0] a8=csa(a6[15:0],a6[31:16],a7[15:0]);
 wire [31:0] a9=csa(a8[15:0],a8[31:16],a7[31:16]);
 wire [31:0] a10=csa(a9[15:0],a9[31:16],16'd128);
 wire [15:0] result=a10[15:0]+a10[31:16];
 assign o_gray=result[15:8];
endmodule
