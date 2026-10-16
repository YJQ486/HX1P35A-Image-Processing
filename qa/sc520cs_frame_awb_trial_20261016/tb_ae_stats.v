`timescale 1ns/1ps
module tb_ae_stats;
`ifdef FULL_FRAME
 localparam W=1280,H=720;
`else
 localparam W=16,H=4;
`endif
 reg clk=0,rst=0;always #5 clk=~clk;
 reg [95:0] data=0;reg valid=0,user=0,last=0,sof=0,token=0;
 wire [159:0] packet;wire bad;
 custom_ae_frame_stats #(.WIDTH(W),.HEIGHT(H)) dut(clk,rst,data,valid,user,last,sof,token,packet,bad);
 integer x,y,p,v,expected_sum,expected_sat,checks=0,errors=0;
 reg [159:0] saved;
 task ck;input integer ok;input [255:0]label;
 begin checks=checks+1;if(!ok)begin errors=errors+1;$display("FAIL %s",label);end end endtask
 task frame_start;begin
 @(negedge clk);sof=1;@(negedge clk);sof=0;
 repeat(8)@(negedge clk);user=1;@(negedge clk);user=0;
 end endtask
 initial begin
 #27;rst=1;token=1;repeat(8)@(negedge clk);
 repeat(3)begin sof=1;@(negedge clk);sof=0;repeat(8)@(negedge clk);end
 frame_start;expected_sum=0;expected_sat=0;
 for(y=0;y<H;y=y+1)begin
  for(x=0;x<W/4;x=x+1)begin
   valid=1;
   for(p=0;p<4;p=p+1)begin
    // Independent fixed color/lane expectations: red, green, blue, white.
    case(p)0:begin data[p*24 +:24]=24'hff0000;v=63;end
     1:begin data[p*24 +:24]=24'h00ff00;v=127;end
     2:begin data[p*24 +:24]=24'h0000ff;v=63;end
     3:begin data[p*24 +:24]=24'hffffff;v=255;end endcase
    expected_sum=expected_sum+v;expected_sat=expected_sat+1;
   end
   @(negedge clk);
  end
  valid=0;data=96'hffffff;last=1;@(negedge clk);last=0;repeat(4)@(negedge clk);
 end
 repeat(4)@(negedge clk);
 ck(packet[47:20]==expected_sum,"four lane total");ck(packet[19:0]==expected_sat,"saturation full coverage");
 ck(packet[65]&&packet[64],"settled complete frame");ck(!bad,"normal complete");
 ck(packet[99:80]==W*H/4,"only white lane is multi-channel clipping");
 ck(packet[119:100]==W*H/4,"only white lane is multi-channel bright");
 ck(packet[159:128]==expected_sum*7/4,"central4 surround1 weighted numerator");
 saved=packet;frame_start;valid=1;@(negedge clk);valid=0;last=1;@(negedge clk);last=0;
 repeat(4)@(negedge clk);frame_start;repeat(4)@(negedge clk);
 ck(packet==saved&&bad,"incomplete frame excluded");
 rst=0;#17;rst=1;valid=1;repeat(10)@(negedge clk);valid=0;
 ck(packet==0,"missing SOF excluded after reset");
 $display("RESULT AE_STATS %0dx%0d checks=%0d errors=%0d total=%0d",W,H,checks,errors,expected_sum);
 if(errors)$fatal(1,"stats check");$finish;
 end
 initial begin #100000000;$fatal(1,"stats timeout");end
endmodule
