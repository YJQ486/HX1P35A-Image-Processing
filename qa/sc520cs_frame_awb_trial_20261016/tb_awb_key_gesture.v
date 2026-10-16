`timescale 1ns/1ps
module tb_awb_key_gesture;
 reg kc=0,vc=0,rst=0,key=1,run_video=1;
 always #7 kc=~kc;
 always #5 if(run_video)vc=~vc;
 wire [1:0] mode;wire overflow,bypass,frame_awb;
 custom_key_mode_request #(.DEBOUNCE_CYCLES(3),.LONG_PRESS_CYCLES(20))
 dut(kc,vc,rst,key,mode,overflow,bypass,frame_awb);
 integer checks=0,errors=0;
 task ck;input integer ok;input [255:0] why;
 begin checks=checks+1;if(!ok)begin errors=errors+1;$display("FAIL %s mode=%d B=%b",why,mode,bypass);end end endtask
 task ticks;input integer n;begin repeat(n)@(negedge kc);end endtask
 task short_press;begin key=0;ticks(9);key=1;ticks(18);end endtask
 initial begin
  ticks(5);rst=1;ticks(10);ck(mode==0&&!bypass,"reset default AWB and RGB");
  key=0;ticks(1);key=1;ticks(1);key=0;ticks(1);key=1;ticks(10);
  ck(mode==0&&!bypass,"bounce no event");
  key=0;ticks(10);ck(mode==0,"short not emitted before release");key=1;ticks(18);
  ck(mode==1&&!bypass,"short release gray only");
  key=0;ticks(60);ck(mode==1&&bypass,"long once no short");
  ticks(40);ck(mode==1&&bypass,"continued hold not repeated");key=1;ticks(18);
  ck(mode==1&&bypass,"long release suppressed");
  short_press;ck(mode==2&&bypass,"binary retains bypass");
  short_press;ck(mode==3&&bypass,"Sobel reachable");
  short_press;ck(mode==0&&bypass,"RGB reachable");
  key=0;ticks(40);key=1;ticks(18);ck(mode==0&&!bypass&&frame_awb,"second long selects frame AWB C");
  key=0;ticks(40);key=1;ticks(18);ck(mode==0&&!bypass&&!frame_awb,"third long restores original A");
  @(negedge vc);run_video=0;short_press;
  ck(mode==0,"stopped camera holds request");
  ticks(10);run_video=1;ticks(20);ck(mode==1,"restart transfers event once");
  rst=0;ticks(3);rst=1;ticks(15);ck(mode==0&&!bypass&&!overflow,"reset flushes gestures");
  @(negedge vc);run_video=0;
  short_press;
  key=0;ticks(40);key=1;ticks(18); // pending long behind in-flight short
  short_press; // queue is full: must report overflow, not corrupt first two
  ck(overflow&&mode==0&&!bypass,"full queue explicit overflow");
  run_video=1;ticks(40);ck(mode==1&&bypass&&overflow,"ordered pending type and one in-flight");
  rst=0;ticks(3);rst=1;ticks(15);ck(mode==0&&!bypass&&!overflow,"overflow reset recovery");
  $display("RESULT AWB_KEY checks=%0d errors=%0d",checks,errors);
  if(errors)$fatal(1,"gesture");$finish;
 end
 initial begin #100000;$fatal(1,"gesture timeout");end
endmodule
