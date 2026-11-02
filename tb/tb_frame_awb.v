`timescale 1ns/1ps
module tb_frame_awb;
`ifdef FULL_FRAME
 localparam W=1280,H=720;
`else
 localparam W=32,H=4;
`endif
 reg clk=0,run_clock=1;always #5 if(run_clock)clk=~clk;
 reg rst=0,valid=0,sof=0;reg [95:0] data=0;
 wire [95:0] out;wire [19:0] rg,bg,n;wire ready,bad,late;
 custom_frame_awb #(.WIDTH(W),.HEIGHT(H)) dut(clk,rst,data,valid,sof,out,rg,bg,ready,bad,late,n);
 integer errors=0,checks=0,pixels=0,f=0,y,x,l,r,g,b,rv,bv,stability;
 integer cycle=0,observed_words=0,last_word_cycle=-1;
 reg old_ready=0;
 always @(posedge clk)begin
  cycle=cycle+1;
  if(!rst)begin observed_words=0;last_word_cycle=-1;end
  else if(valid)begin
   observed_words=observed_words+1;
   if(observed_words%(W*H/4)==0)last_word_cycle=cycle;
  end
  #2;
  if(rst&&ready&&!old_ready)$display("OBS result_ready_after_last_pixel=%0d clocks gains_pending=%h/%h",cycle-last_word_cycle,dut.pending_r,dut.pending_b);
  old_ready=ready;
 end
 integer er=65536,eb=65536,nr=65536,nb=65536,ct;
 reg [63:0] sr,sg,sb,den;
 reg [95:0] expected;
 function integer update_gain;
 input integer oldv;input [63:0] gs,cs;
 reg [63:0] target;
 begin
  target=gs*65536/cs;
  if(target<32768)target=32768;
  if(target>131072)target=131072;
  // Independent integer arithmetic oracle, NOT a restoring divider.
  if(target>=oldv)update_gain=oldv+(target-oldv)/4;
  else update_gain=oldv-(oldv-target)/4;
 end endfunction
 task check;
 input yes;input [255:0] tag;
 begin checks=checks+1;if(!yes)begin errors=errors+1;if(errors<12)$display("FAIL %s f=%0d y=%0d x=%0d rg=%h bg=%h expected=%h/%h",tag,f,y,x,rg,bg,er,eb);end end endtask
 task tick;
 input v,s;input [95:0] d;
 begin
  @(negedge clk);valid=v;sof=s;data=d;
  expected=0;
  for(l=0;l<4;l=l+1)begin
   rv=(d[l*24+16 +:8]*er)/65536;bv=(d[l*24 +:8]*eb)/65536;
   expected[l*24+16 +:8]=rv>255?255:rv;
   expected[l*24+8 +:8]=d[l*24+8 +:8];expected[l*24 +:8]=bv>255?255:bv;
  end
  @(posedge clk);#1;
  if(v)begin
   check(out===expected,"pixels independent reference");check(rg==er&&bg==eb,"fixed gain within frame");pixels=pixels+4;
  end
 end endtask
 reg [95:0] word;
 reg early_case=0,skip_sof=0;
 task frame;
 input integer scene,wait_cycles;
 begin
  f=f+1;er=nr;eb=nb;sr=0;sg=0;sb=0;ct=0;
  tick(0,!skip_sof,0);skip_sof=0;tick(0,0,0);
  for(y=0;y<H;y=y+1)begin
   for(x=0;x<W/4;x=x+1)begin
    word=0;
    for(l=0;l<4;l=l+1)begin
     case(scene)
      0:begin r=80;g=80;b=80;end
      1:begin r=160;g=100;b=60;end
      2:begin r=50;g=100;b=200;end
      3:begin r=255;g=0;b=0;end
      4:begin r=0;g=0;b=0;end
      5:case(l)
       0:begin r=90;g=90;b=30;end
       1:begin r=30;g=90;b=120;end
       2:begin r=80;g=120;b=160;end
       3:begin r=200;g=100;b=50;end
      endcase
      6:begin r=255;g=255;b=255;end
      7:begin r=50;g=200;b=100;end
      8:begin r=200;g=50;b=100;end
      9:begin r=50+(x*13+y*17+l*31)%100;g=50+(x*19+y*23+l*11)%100;b=50+(x*7+y*29+l*37)%100;end
      default:begin r=(x==0&&y==0&&l==0)?80:0;g=r;b=r;end
     endcase
     word[l*24 +:24]={r[7:0],g[7:0],b[7:0]};
     // These scenes have known qualified populations, no copy of DUT mask.
     if(scene==0||scene==1||scene==2||scene==5||(scene>=7&&scene<=9)||(scene==10&&r==80))begin sr=sr+r;sg=sg+g;sb=sb+b;ct=ct+1;end
    end
    if(early_case&&y==H-1&&x==W/4-2)begin tick(1,1,word);skip_sof=1;end
    else tick(1,0,word);
   end
   tick(0,0,0); // also the AWB invalid-line-end shape
  end
  repeat(wait_cycles)tick(0,0,0);
  // Measured complete result is visible after L+98; next frame's first
  // valid edge is L+wait_cycles+4. Same-edge finish/SOF MUST hold old gains.
  if(wait_cycles>=95&&ct>=W*H/16)begin
   nr=update_gain(er,sg,sr);nb=update_gain(eb,sg,sb);
   if(wait_cycles>=100)check(ready,"both divisions finished before commit");
   check(n==ct,"all four lanes count");
  end else begin nr=er;nb=eb;end
  if(ct<W*H/16)check(!ready,"insufficient sample population holds");
  if(scene==0&&er==65536&&eb==65536)check(out[95:72]==24'h505050,"hardcoded neutral gray");
 end endtask
 initial begin
  repeat(5)@(negedge clk);rst=1;repeat(3)tick(0,0,0);
  frame(0,110);frame(1,110);frame(2,110);frame(5,110);
  frame(3,110);frame(4,110);frame(6,110);frame(0,110);
  frame(7,110);frame(8,110);frame(9,110);frame(10,110);
  early_case=1;frame(5,110);early_case=0;frame(0,110);
  check(!bad&&!late,"normal complete frames protocol");
  // No vblank for division: next frame holds; old result cannot leak later.
  frame(1,0);frame(0,110);check(late,"late completion explicitly rejected");
  frame(1,0);repeat(15)tick(0,0,0);check(dut.busy,"division in flight before stopped clock");
  @(negedge clk);run_clock=0;#1000;check(dut.busy&&!ready,"stopped clock cannot complete division");run_clock=1;
  // Reset cancels a genuinely in-flight calculation and clears its epoch.
  @(negedge clk);rst=0;valid=0;sof=0;#1;check(rg==65536&&bg==65536&&!ready,"async reset");
  er=65536;eb=65536;nr=65536;nb=65536;
  repeat(4)@(negedge clk);rst=1;
  frame(5,110);frame(0,110);check(!bad&&!late,"reset restart no stale result");
  if(W<1280)begin
   for(stability=0;stability<49;stability=stability+1)frame(1,110);
   check(rg>=40960&&rg<=40963&&bg>=109223&&bg<=109226,"hardcoded warm steady-state Q16");
   for(stability=0;stability<49;stability=stability+1)frame(2,110);
   check(rg>=131069&&rg<=131072&&bg>=32768&&bg<=32771,"hardcoded cool steady-state Q16");
   check(!bad&&!late,"stable illumination no protocol fault");
   frame(1,94);frame(0,110);check(late,"SOF on finish edge holds old gains");
   @(negedge clk);rst=0;valid=0;sof=0;er=65536;eb=65536;nr=65536;nb=65536;
   repeat(4)@(negedge clk);rst=1;
   frame(1,95);frame(0,110);check(!late&&!bad,"SOF one cycle after finish commits new gains");
  end
  $display("RESULT FRAME_AWB W=%0d H=%0d frames=%0d pixels=%0d checks=%0d errors=%0d",W,H,f,pixels,checks,errors);
  if(errors)$fatal(1,"FRAME_AWB failed");$finish;
 end
 initial begin #400000000;$fatal(1,"timeout");end
endmodule
