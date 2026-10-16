// Small hexadecimal snapshot panel. No effect on frame-store reads or ISP.
// Three output stages carry RGB/DE/HS/VS together. Character selection is
// separated from glyph lookup based on the syn_1 y->ink1 timing evidence.
module custom_diag_overlay (
    input i_clk,input i_rst_n,
    input i_vs,input i_hs,input i_de,input [23:0] i_rgb,
    input [467:0] i_status,
    output reg o_vs,output reg o_hs,output reg o_de,output reg [23:0] o_rgb
);
    reg [11:0] x,y;
    reg de_old;
    reg [467:0] display_status;
    reg vs1,hs1,de1;
    reg [23:0] rgb1;
    reg panel1,ink1;
    reg [7:0] character_d;
    reg [1:0] gx_d;reg [2:0] gy_d;
    reg panel_d,vs_d,hs_d,de_d;reg [23:0] rgb_d;
    reg [7:0] character;
    reg [15:0] address;
    reg [7:0] value;
    reg [14:0] glyph;
    integer row,col,index,gx,gy;
    function [7:0] hexchar;
        input [3:0] nibble;
        begin hexchar=nibble<10 ? 8'h30+{4'd0,nibble}:8'h41+{4'd0,nibble}-8'd10;end
    endfunction
    function [14:0] font;
        input [7:0] ch;
        begin
            case(ch)
                "0":font=15'b111_101_101_101_111;
                "1":font=15'b010_110_010_010_111;
                "2":font=15'b111_001_111_100_111;
                "3":font=15'b111_001_111_001_111;
                "4":font=15'b101_101_111_001_001;
                "5":font=15'b111_100_111_001_111;
                "6":font=15'b111_100_111_101_111;
                "7":font=15'b111_001_010_010_010;
                "8":font=15'b111_101_111_101_111;
                "9":font=15'b111_101_111_001_111;
                "A":font=15'b010_101_111_101_101;
                "B":font=15'b110_101_110_101_110;
                "C":font=15'b111_100_100_100_111;
                "D":font=15'b110_101_101_101_110;
                "E":font=15'b111_100_110_100_111;
                "F":font=15'b111_100_110_100_100;
                "G":font=15'b111_100_101_101_111;
                "I":font=15'b111_010_010_010_111;
                "L":font=15'b100_100_100_100_111;
                "N":font=15'b101_111_111_111_101;
                "O":font=15'b111_101_101_101_111;
                "P":font=15'b111_101_111_100_100;
                "R":font=15'b110_101_110_101_101;
                "S":font=15'b111_100_111_001_111;
                "T":font=15'b111_010_010_010_010;
                "V":font=15'b101_101_101_101_010;
                "W":font=15'b101_101_111_111_101;
                "X":font=15'b101_101_010_101_101;
                "Y":font=15'b101_101_010_010_010;
                "=":font=15'b000_111_000_111_000;
                "?":font=15'b111_001_010_000_010;
                "-":font=15'b000_000_111_000_000;
                default:font=15'd0;
            endcase
        end
    endfunction
    always @* begin
        // 4x6 character cells scaled by 2 (8x12 display pixels).
        row=y>>4;col=x>>3;gx=(x>>1)&3;gy=(y&15)>>1;
        character=" ";address=0;value=0;index=row-3;
        if(row==0)begin
            case(col)
                0:character="R";1:character="E";2:character="G";
                4:character="S";5:character="N";6:character="A";7:character="P";
                9:character="O";10:character="N";11:character="L";12:character="Y";
                default:character=" ";
            endcase
        end else if(row==1)begin
            case(col)
                0:character="I";1:character="D";
                3:character=hexchar(display_status[109:106]);
                4:character=hexchar(display_status[105:102]);
                5:character=hexchar(display_status[101:98]);
                6:character=hexchar(display_status[97:94]);
                8:character="C";9:character=hexchar({3'd0,display_status[111]});
                11:character="A";12:character=hexchar({3'd0,display_status[112]});
                14:character="E";15:character=hexchar({3'd0,display_status[113]});
                default:character=" ";
            endcase
        end else if(row==2)begin
            case(col)
                0:character="D";1:character=hexchar({3'd0,display_status[114]});
                3:character="S";4:character=hexchar({3'd0,display_status[115]});
                6:character="B";7:character=hexchar({3'd0,display_status[116]});
                9:character="F";10:character=hexchar(display_status[93:90]);
                default:character=" ";
            endcase
        end else if(row==15)begin
            case(col)
                0:character="A";1:character="E";
                3:character="R";4:character="E";5:character="G";
                8:character="D";9:character="A";10:character="T";11:character="A";
                13:character="V";15:character="C";17:character="A";
                default:character=" ";
            endcase
        end else if(row>=16 &&row<24)begin
            index=row-16;
            address=display_status[152+index*24+8 +: 16];
            value=display_status[152+index*24 +: 8];
            case(col)
                0:character=hexchar(index);
                3:character=hexchar(address[15:12]);4:character=hexchar(address[11:8]);
                5:character=hexchar(address[7:4]);6:character=hexchar(address[3:0]);
                9:character=hexchar(value[7:4]);10:character=hexchar(value[3:0]);
                13:character=hexchar({3'd0,display_status[344+index]});
                15:character=hexchar({3'd0,display_status[352+index]});
                17:character=hexchar({3'd0,display_status[360+index]});
                default:character=" ";
            endcase
        end else if(row==24)begin
            case(col)
                0:character="W";1:character=hexchar({3'd0,display_status[464]});
                3:character="S";4:character=hexchar({2'd0,display_status[466:465]});
                6:character="X";7:character=hexchar({3'd0,display_status[467]});
                9:character="L";10:character=hexchar({3'd0,display_status[462]});
                12:character="D";13:character=hexchar({3'd0,display_status[463]});
                15:character="F";16:character=hexchar(display_status[461:458]);
                default:character=" ";
            endcase
        end else if(row==13)begin
            case(col)
                0:character="V";1:character=hexchar({3'd0,display_status[151]});
                3:character="T";4:character=hexchar({1'b0,display_status[150:148]});
                6:character="I";7:character=hexchar({3'd0,display_status[147]});
                8:character=hexchar(display_status[146:143]);
                9:character=hexchar(display_status[142:139]);
                11:character="P";12:character=hexchar({1'b0,display_status[122:120]});
                default:character=" ";
            endcase
        end else if(row==14)begin
            case(col)
                0:character="R";1:character="E";2:character="G";
                4:character=hexchar(display_status[138:135]);
                5:character=hexchar(display_status[134:131]);
                6:character=hexchar(display_status[130:127]);
                7:character=hexchar(display_status[126:123]);
                default:character=" ";
            endcase
        end else if(row>=3 && row<13)begin
            case(index)
                0:address=16'h3e00;1:address=16'h3e01;2:address=16'h3e02;
                3:address=16'h3e09;4:address=16'h3e06;5:address=16'h3e07;
                6:address=16'h320e;7:address=16'h320f;
                8:address=16'h3221;9:address=16'h3812;
                default:address=0;
            endcase
            value=display_status[index*8 +: 8];
            case(col)
                0:character=hexchar(address[15:12]);1:character=hexchar(address[11:8]);
                2:character=hexchar(address[7:4]);3:character=hexchar(address[3:0]);
                5:character="=";
                7:character=display_status[80+index]?hexchar(value[7:4]):"?";
                8:character=display_status[80+index]?hexchar(value[3:0]):"?";
                12:character="L";
                14:character=display_status[448+index]?hexchar(display_status[368+index*8+4 +: 4]):"?";
                15:character=display_status[448+index]?hexchar(display_status[368+index*8 +: 4]):"?";
                default:character=" ";
            endcase
        end
        glyph=font(character_d);
    end
    always @(posedge i_clk or negedge i_rst_n)begin
        if(!i_rst_n)begin
            x<=0;y<=0;de_old<=0;display_status<=0;
            vs1<=0;hs1<=0;de1<=0;rgb1<=0;panel1<=0;ink1<=0;
            character_d<=0;gx_d<=0;gy_d<=0;panel_d<=0;
            vs_d<=0;hs_d<=0;de_d<=0;rgb_d<=0;
            o_vs<=0;o_hs<=0;o_de<=0;o_rgb<=0;
        end else begin
            de_old<=i_de;
            if(i_vs)begin y<=0;display_status<=i_status;end
            else if(de_old && !i_de)y<=y+1'b1;
            if(!i_de)x<=0;else x<=x+1'b1;
            character_d<=character;gx_d<=gx;gy_d<=gy;
            panel_d<=i_de &&x<160 &&y<400;
            vs_d<=i_vs;hs_d<=i_hs;de_d<=i_de;rgb_d<=i_rgb;
            vs1<=vs_d;hs1<=hs_d;de1<=de_d;rgb1<=rgb_d;
            panel1<=panel_d;
            ink1<=gx_d<3 &&gy_d<5 &&glyph[14-gy_d*3-gx_d];
            o_vs<=vs1;o_hs<=hs1;o_de<=de1;
            o_rgb<=!de1 ? 24'd0 : (panel1 ? (ink1 ? 24'hffffff:24'h101820):rgb1);
        end
    end
endmodule
