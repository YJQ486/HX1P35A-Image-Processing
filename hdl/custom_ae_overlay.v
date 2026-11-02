// Compact AE status; request/completed/readback are explicitly different rows.
// Three equal RGB/DE/HS/VS stages; no change to upstream processing latency.
module custom_ae_overlay(
 input i_clk,i_rst_n,i_vs,i_hs,i_de,input [23:0] i_rgb,input [467:0] i_status,
 output reg o_vs,o_hs,o_de,output reg [23:0] o_rgb
);
 reg [11:0] x,y;reg old_de;
 reg [467:0] status;
 reg [7:0] ch,ch_d;reg [14:0] glyph;
 reg [1:0] gx_d;reg [2:0] gy_d;
 reg [2:0] vs_pipe,hs_pipe,de_pipe;
 reg [23:0] rgb_d,rgb_1;
 reg panel_d,panel_1,ink_1;
 integer row,col;
 function [7:0] hex;
 input [3:0] n;begin hex=n<10?8'h30+{4'd0,n}:8'h41+{4'd0,n}-8'd10;end
 endfunction
 function [14:0] font;
 input [7:0] c;begin case(c)
 "0":font=15'b111_101_101_101_111;"1":font=15'b010_110_010_010_111;
 "2":font=15'b111_001_111_100_111;"3":font=15'b111_001_111_001_111;
 "4":font=15'b101_101_111_001_001;"5":font=15'b111_100_111_001_111;
 "6":font=15'b111_100_111_101_111;"7":font=15'b111_001_010_010_010;
 "8":font=15'b111_101_111_101_111;"9":font=15'b111_101_111_001_111;
 "A":font=15'b010_101_111_101_101;"B":font=15'b110_101_110_101_110;
 "C":font=15'b111_100_100_100_111;"D":font=15'b110_101_101_101_110;
 "E":font=15'b111_100_110_100_111;"F":font=15'b111_100_110_100_100;
 "G":font=15'b111_100_101_101_111;"I":font=15'b111_010_010_010_111;
 "N":font=15'b101_111_111_111_101;"O":font=15'b111_101_101_101_111;
 "P":font=15'b110_101_111_100_100;"Q":font=15'b111_101_101_111_001;
 "R":font=15'b110_101_110_101_101;"S":font=15'b111_100_111_001_111;
 "T":font=15'b111_010_010_010_010;"U":font=15'b101_101_101_101_111;
 "V":font=15'b101_101_101_101_010;"Y":font=15'b101_101_010_010_010;
 "W":font=15'b101_101_101_111_101;
 "?":font=15'b111_001_010_000_010;default:font=0;endcase end
 endfunction
 reg [15:0] value1,value2;
 always @*begin
  row=y>>4;col=x>>3;ch=" ";value1=0;value2=0;
  case(row)
   0:case(col)0:ch="A";1:ch="U";2:ch="T";3:ch="O";5:ch="A";6:ch="E";endcase
   1:begin
    case(col)0:ch="I";1:ch="D";3:ch=hex(status[109:106]);4:ch=hex(status[105:102]);
     5:ch=hex(status[101:98]);6:ch=hex(status[97:94]);8:ch="C";9:ch=hex({3'd0,status[111]});
     11:ch="A";12:ch=hex({3'd0,status[112]});14:ch="E";15:ch=hex({3'd0,status[113]});endcase
   end
   2:begin
    case(col)0:ch="Y";2:ch=hex(status[159:156]);3:ch=hex(status[155:152]);
     5:ch="S";6:ch="A";7:ch="T";9:ch=hex({3'd0,status[168]});
     10:ch=hex(status[167:164]);11:ch=hex(status[163:160]);endcase
   end
   3,4:begin
    value1=row==3?status[188:173]:status[220:205];
    value2=row==3?status[204:189]:status[236:221];
    case(col)0:ch=row==3?"R":"D";1:ch=row==3?"E":"O";2:ch=row==3?"Q":"N";
     4:ch=hex(value1[15:12]);5:ch=hex(value1[11:8]);6:ch=hex(value1[7:4]);7:ch=hex(value1[3:0]);
     9:ch="G";11:ch=hex(value2[15:12]);12:ch=hex(value2[11:8]);
     13:ch=hex(value2[7:4]);14:ch=hex(value2[3:0]);endcase
   end
   5:begin
    case(col)0:ch="U";2:ch=hex(status[252:249]);3:ch=hex(status[248:245]);
     4:ch=hex(status[244:241]);5:ch=hex(status[240:237]);7:ch="S";9:ch=hex(status[172:169]);
     11:ch="E";13:ch=hex({3'd0,status[253]});endcase
   end
   6:begin
    case(col)0:ch="V";1:ch=hex({3'd0,status[151]});3:ch="T";4:ch=hex({1'd0,status[150:148]});
     6:ch="I";7:ch=hex({3'd0,status[147]});8:ch=hex(status[146:143]);9:ch=hex(status[142:139]);
     11:ch="P";12:ch=hex({1'd0,status[122:120]});endcase
   end
   7:begin
    // Historical first read only, not the ongoing requested/completed target.
    case(col)0:ch="R";1:ch="0";3:ch=status[83]?hex(status[31:28]):"?";
     4:ch=status[83]?hex(status[27:24]):"?";6:ch="R";7:ch="E";8:ch="A";9:ch="D";endcase
   end
   8:case(col)
    0:ch="A";1:ch="W";2:ch="B";4:ch=status[295]?(status[319]?"C":(status[294]?"B":"A")):"?";
    6:ch="A";7:ch="B";9:ch="R";10:ch="G";11:ch="B";
   endcase
   9,10,11:begin
    case(col)0:ch=row==9?"R":(row==10?"G":"B");endcase
    if(col>=2 && col<7)begin
     if(!status[295])ch="?";
     else if(row==10)case(col)2:ch="1";default:ch="0";endcase
     else if(row==9)case(col)
      2:ch=hex(status[293:290]);3:ch=hex(status[289:286]);4:ch=hex(status[285:282]);
      5:ch=hex(status[281:278]);6:ch=hex(status[277:274]);endcase
     else case(col)
      2:ch=hex(status[273:270]);3:ch=hex(status[269:266]);4:ch=hex(status[265:262]);
      5:ch=hex(status[261:258]);6:ch=hex(status[257:254]);endcase
    end
   end
   12:begin
    case(col)0:ch="N";2:ch=hex(status[315:312]);3:ch=hex(status[311:308]);
     4:ch=hex(status[307:304]);5:ch=hex(status[303:300]);6:ch=hex(status[299:296]);
     8:ch="P";9:ch=hex({3'd0,status[318]});11:ch="E";12:ch=hex({2'd0,status[317:316]});endcase
   end
  endcase
  glyph=font(ch_d);
 end
 always @(posedge i_clk or negedge i_rst_n)begin
  if(!i_rst_n)begin
   x<=0;y<=0;old_de<=0;status<=0;ch_d<=0;gx_d<=0;gy_d<=0;
   vs_pipe<=0;hs_pipe<=0;de_pipe<=0;rgb_d<=0;rgb_1<=0;panel_d<=0;panel_1<=0;ink_1<=0;
   o_vs<=0;o_hs<=0;o_de<=0;o_rgb<=0;
  end else begin
   old_de<=i_de;if(i_vs)begin y<=0;status<=i_status;end
   else if(old_de&&!i_de)y<=y+1'b1;
   if(!i_de)x<=0;else x<=x+1'b1;
   ch_d<=ch;gx_d<=x[2:1];gy_d<=y[3:1];panel_d<=i_de&&x<160&&y<208;
   rgb_d<=i_rgb;rgb_1<=rgb_d;panel_1<=panel_d;
   ink_1<=gx_d<3&&gy_d<5&&glyph[14-gy_d*3-gx_d];
   vs_pipe<={vs_pipe[1:0],i_vs};hs_pipe<={hs_pipe[1:0],i_hs};de_pipe<={de_pipe[1:0],i_de};
   o_vs<=vs_pipe[1];o_hs<=hs_pipe[1];o_de<=de_pipe[1];
   o_rgb<=!de_pipe[1]?24'd0:(panel_1?(ink_1?24'hffffff:24'h101820):rgb_1);
  end
 end
endmodule
