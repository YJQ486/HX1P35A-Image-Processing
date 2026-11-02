`timescale 1ns/1ps
module tb_awb_status_cdc;
 reg sc=0,dc=0,srun=1,drun=1,rst=0;
 always #4.83 if(srun)sc=~sc;
 always #21 if(drun)dc=~dc;
 reg [225:0] src=0;wire [225:0] dst;
 custom_diag_snapshot_cdc #(.WIDTH(226)) dut(sc,dc,rst,src,dst);
 integer checks=0,errors=0,n;reg [225:0] latest;
 function [225:0] word;
 input integer k;reg [19:0] r,b;
 begin r=k^20'habcde;b=~r;word={k[23:0],1'b1,k[0],r,b,{5{k}}};end
 endfunction
 always @(negedge dc)if(rst && dst[201])begin
  checks=checks+1;
  if(dst[179:160]!==~dst[199:180] ||
     dst[31:0]!==dst[63:32] || dst[31:0]!==dst[159:128] ||
     (dst[199:180]^20'habcde)!==dst[19:0] ||dst[225:202]!==dst[23:0])begin
   errors=errors+1;$display("FAIL incoherent gain/frame packet %h",dst);
  end
 end
 initial begin
  #100;rst=1;
  for(n=1;n<150;n=n+1)begin @(negedge sc);src=word(n);end
  #2000;if(dst!==src)$fatal(1,"latest telemetry not delivered");
  @(negedge dc);drun=0;
  for(n=150;n<200;n=n+1)begin @(negedge sc);src=word(n);end
  #1000;drun=1;#2500;
  checks=checks+1;if(dst!==src)begin errors=errors+1;$display("FAIL camera consumer restart");end
  @(negedge sc);srun=0;latest=dst;#500;
  checks=checks+1;if(dst!==latest)begin errors=errors+1;$display("FAIL phantom change");end
  rst=0;#100;checks=checks+1;if(dst!==0)begin errors=errors+1;$display("FAIL reset");end
  src=0;srun=1;rst=1;#500;src=word(250);#2500;
  checks=checks+1;if(dst!==src)begin errors=errors+1;$display("FAIL epoch restart");end
  $display("RESULT AWB_STATUS checks=%0d errors=%0d",checks,errors);
  if(errors)$fatal(1,"status CDC");$finish;
 end
 initial begin #20000;$fatal(1,"status timeout");end
endmodule
