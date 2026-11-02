// HDMI domain: mailbox packet atomically committed at rising VS.
// One registered pixel stage. Clear invalid metadata immediately; no stale overlay.
module custom_red_overlay #(parameter DIAG=0,BLUE=0,WIDTH=1280,HEIGHT=720,STALE_FRAMES=4)(
 input i_clk,i_rst_n,i_vs,i_hs,i_de,input [23:0] i_rgb,input [56:0] i_packet,
 output reg o_hit,output reg o_vs,o_hs,o_de,output reg [23:0] o_rgb);
 reg [11:0] x,y,x0,x1,y0,y1;
 reg old_de,old_vs,present;
 reg [7:0] last_seq;
 reg [5:0] diagnostic;
 wire [47:0] coords=DIAG?(i_packet[47:0]&48'h7ff7ff3ff3ff):i_packet[47:0];
 wire diag_area=DIAG&&x>=336&&x<408&&y>=(BLUE?40:16)&&y<(BLUE?50:26);
 wire [3:0] diag_column=(x-336)/12;
 wire diag_on=diag_area&&(diag_column<6)&&diagnostic[5-diag_column];
 reg [3:0] age;
 wire vsrise=i_vs&&!old_vs;
 wire protect=(x<160&&y<208)||(x>=1088&&x<1248&&y>=16&&y<176);
 wire border=present&&x>=x0&&x<=x1&&y>=y0&&y<=y1&&
  ((x-x0<2)||(x1-x<2)||(y-y0<2)||(y1-y<2));
 wire text_area=x>=192&&x<(BLUE?324:312)&&y>=(BLUE?40:16)&&y<(BLUE?54:30);
 wire [11:0] tx=x-192,ty=y-(BLUE?40:16);
 wire [3:0] col=tx/12;
 wire [2:0] gx=(tx%12)/2,gy=ty/2;
 reg [4:0] bits;
 always @* begin
  bits=0;
  if(BLUE)begin case(col*7+gy)
   7'd0:bits=5'b11110;
   7'd1:bits=5'b10001;
   7'd2:bits=5'b10001;
   7'd3:bits=5'b11110;
   7'd4:bits=5'b10001;
   7'd5:bits=5'b10001;
   7'd6:bits=5'b11110;
   7'd7:bits=5'b10000;
   7'd8:bits=5'b10000;
   7'd9:bits=5'b10000;
   7'd10:bits=5'b10000;
   7'd11:bits=5'b10000;
   7'd12:bits=5'b10000;
   7'd13:bits=5'b11111;
   7'd14:bits=5'b10001;
   7'd15:bits=5'b10001;
   7'd16:bits=5'b10001;
   7'd17:bits=5'b10001;
   7'd18:bits=5'b10001;
   7'd19:bits=5'b10001;
   7'd20:bits=5'b01110;
   7'd21:bits=5'b11111;
   7'd22:bits=5'b10000;
   7'd23:bits=5'b10000;
   7'd24:bits=5'b11110;
   7'd25:bits=5'b10000;
   7'd26:bits=5'b10000;
   7'd27:bits=5'b11111;
   7'd28:bits=5'b00000;
   7'd29:bits=5'b00000;
   7'd30:bits=5'b00000;
   7'd31:bits=5'b00000;
   7'd32:bits=5'b00000;
   7'd33:bits=5'b00000;
   7'd34:bits=5'b00000;
   7'd35:bits=5'b11111;
   7'd36:bits=5'b00100;
   7'd37:bits=5'b00100;
   7'd38:bits=5'b00100;
   7'd39:bits=5'b00100;
   7'd40:bits=5'b00100;
   7'd41:bits=5'b00100;
   7'd42:bits=5'b01110;
   7'd43:bits=5'b10001;
   7'd44:bits=5'b10001;
   7'd45:bits=5'b11111;
   7'd46:bits=5'b10001;
   7'd47:bits=5'b10001;
   7'd48:bits=5'b10001;
   7'd49:bits=5'b11110;
   7'd50:bits=5'b10001;
   7'd51:bits=5'b10001;
   7'd52:bits=5'b11110;
   7'd53:bits=5'b10100;
   7'd54:bits=5'b10010;
   7'd55:bits=5'b10001;
   7'd56:bits=5'b01111;
   7'd57:bits=5'b10000;
   7'd58:bits=5'b10000;
   7'd59:bits=5'b10111;
   7'd60:bits=5'b10001;
   7'd61:bits=5'b10001;
   7'd62:bits=5'b01111;
   7'd63:bits=5'b11111;
   7'd64:bits=5'b10000;
   7'd65:bits=5'b10000;
   7'd66:bits=5'b11110;
   7'd67:bits=5'b10000;
   7'd68:bits=5'b10000;
   7'd69:bits=5'b11111;
   7'd70:bits=5'b11111;
   7'd71:bits=5'b00100;
   7'd72:bits=5'b00100;
   7'd73:bits=5'b00100;
   7'd74:bits=5'b00100;
   7'd75:bits=5'b00100;
   7'd76:bits=5'b00100;
   default:bits=0;endcase end else begin
  case(col*7+gy)
   7'd0: bits=5'b11110;
   7'd1: bits=5'b10001;
   7'd2: bits=5'b10001;
   7'd3: bits=5'b11110;
   7'd4: bits=5'b10100;
   7'd5: bits=5'b10010;
   7'd6: bits=5'b10001;
   7'd7: bits=5'b11111;
   7'd8: bits=5'b10000;
   7'd9: bits=5'b10000;
   7'd10: bits=5'b11110;
   7'd11: bits=5'b10000;
   7'd12: bits=5'b10000;
   7'd13: bits=5'b11111;
   7'd14: bits=5'b11110;
   7'd15: bits=5'b10001;
   7'd16: bits=5'b10001;
   7'd17: bits=5'b10001;
   7'd18: bits=5'b10001;
   7'd19: bits=5'b10001;
   7'd20: bits=5'b11110;
   7'd21: bits=5'b00000;
   7'd22: bits=5'b00000;
   7'd23: bits=5'b00000;
   7'd24: bits=5'b00000;
   7'd25: bits=5'b00000;
   7'd26: bits=5'b00000;
   7'd27: bits=5'b00000;
   7'd28: bits=5'b11111;
   7'd29: bits=5'b00100;
   7'd30: bits=5'b00100;
   7'd31: bits=5'b00100;
   7'd32: bits=5'b00100;
   7'd33: bits=5'b00100;
   7'd34: bits=5'b00100;
   7'd35: bits=5'b01110;
   7'd36: bits=5'b10001;
   7'd37: bits=5'b10001;
   7'd38: bits=5'b11111;
   7'd39: bits=5'b10001;
   7'd40: bits=5'b10001;
   7'd41: bits=5'b10001;
   7'd42: bits=5'b11110;
   7'd43: bits=5'b10001;
   7'd44: bits=5'b10001;
   7'd45: bits=5'b11110;
   7'd46: bits=5'b10100;
   7'd47: bits=5'b10010;
   7'd48: bits=5'b10001;
   7'd49: bits=5'b01111;
   7'd50: bits=5'b10000;
   7'd51: bits=5'b10000;
   7'd52: bits=5'b10111;
   7'd53: bits=5'b10001;
   7'd54: bits=5'b10001;
   7'd55: bits=5'b01111;
   7'd56: bits=5'b11111;
   7'd57: bits=5'b10000;
   7'd58: bits=5'b10000;
   7'd59: bits=5'b11110;
   7'd60: bits=5'b10000;
   7'd61: bits=5'b10000;
   7'd62: bits=5'b11111;
   7'd63: bits=5'b11111;
   7'd64: bits=5'b00100;
   7'd65: bits=5'b00100;
   7'd66: bits=5'b00100;
   7'd67: bits=5'b00100;
   7'd68: bits=5'b00100;
   7'd69: bits=5'b00100;
   default:bits=0;
  endcase
  end
 end
 wire text_hit=present&&text_area&&gx<5&&bits[4-gx];
 always @(posedge i_clk or negedge i_rst_n)begin
  if(!i_rst_n)begin
   x<=0;y<=0;old_de<=0;old_vs<=0;present<=0;x0<=0;x1<=0;y0<=0;y1<=0;
   diagnostic<=0;last_seq<=0;age<=0;o_hit<=0;o_vs<=0;o_hs<=0;o_de<=0;o_rgb<=0;
  end else begin
   old_de<=i_de;old_vs<=i_vs;
   if(i_vs)y<=0;else if(old_de&&!i_de)y<=y+1'b1;
   if(!i_de)x<=0;else x<=x+1'b1;

   if(vsrise)begin
    if(i_packet[56:49]!=last_seq)begin
     diagnostic<={i_packet[47],i_packet[35],i_packet[23:22],i_packet[11:10]};last_seq<=i_packet[56:49];age<=0;
     present<=i_packet[48]&&coords[47:36]<=coords[35:24]&&
      coords[23:12]<=coords[11:0]&&coords[35:24]<WIDTH&&coords[11:0]<HEIGHT;
     x0<=coords[47:36];x1<=coords[35:24];y0<=coords[23:12];y1<=coords[11:0];
    end else if(age>=STALE_FRAMES-1)begin age<=STALE_FRAMES;present<=0;diagnostic<=0;end
    else age<=age+1'b1;
   end
   o_hit<=i_de&&!protect&&(border||text_hit||diag_on);
   o_vs<=i_vs;o_hs<=i_hs;o_de<=i_de;
   o_rgb<=!i_de?24'd0:((!protect&&(border||text_hit||diag_on))?(BLUE?24'h00bfff:24'hffef00):i_rgb);
  end
 end
endmodule
