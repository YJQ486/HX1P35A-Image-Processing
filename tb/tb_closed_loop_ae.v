`timescale 1ns/1ps
// Independent plant: light * exposure * analog gain, group applied N+2.
// This is a response model, not a physical SC520CS model or full DDR simulation.
module tb_closed_loop_ae;
 reg sc=0,cc=0,rst=0;reg run_sc=1,run_cc=1;
 always #5 if(run_sc)sc=~sc;always #21 if(run_cc)cc=~cc;
 reg [95:0] data=0;reg valid=0,user=0,last=0,sof=0;
 wire [159:0] packet,cam_packet;wire bad;
 wire req,token,fault;wire [15:0] exp,gain,completed_exp,completed_gain,updates;
 wire [7:0] mean;wire [8:0] sat;wire [3:0] state;
 reg ready=0,started=0,finished=0,error=0;reg [3:0] sofpipe=0;
 wire cam_sof,frame_fault,frame_ready;
 custom_csi_sof_events event_bridge(sc,sof,cc,rst,1'b1,cam_sof,frame_fault,frame_ready);
 custom_ae_frame_stats #(.WIDTH(16),.HEIGHT(4)) stats(sc,rst,data,valid,user,last,sof,token,packet,bad);
 custom_diag_snapshot_cdc #(.WIDTH(160)) bridge(sc,cc,rst,packet,cam_packet);
 custom_closed_loop_ae #(.PIXELS(64)) ctrl(cc,rst,cam_packet,ready,started,finished,error,
  cam_sof,frame_ready,frame_fault,req,exp,gain,token,mean,sat,state,completed_exp,completed_gain,updates,fault);
 integer errors=0,checks=0,frame=0,pending_frame=-1,bus_cycles=0;
 integer applied_exp=1991,applied_gain=16,pending_exp=0,pending_gain=0;
 integer light=256,pixel=0,p,r,b,idx,old_updates,count_at_done=-1;
 real plant_response;
 integer color_scene=0;
 integer window_light=4096,interior_light=128,window_pixel,initial_white,hold_updates;
 integer noisy=0,noise_value=0,window_right=0;
 integer req_count=0,last_req_frame=-100;
 reg bus_active=0;reg inject_nack=0;
 reg [15:0] accepted_exp,accepted_gain;
 function integer analog;
 input integer ag;
 begin case(ag)16:analog=1;48:analog=2;80:analog=4;112:analog=8;144:analog=16;176:analog=32;
 default:analog=-1;endcase end
 endfunction
 task check;
 input integer condition;input [255:0] what;
 begin checks=checks+1;if(!condition)begin errors=errors+1;$display("FAIL %s frame=%0d exp=%0d gain=%0d Y=%0d state=%0d",what,frame,exp,gain,mean,state);end end
 endtask
 always @(posedge cc)begin
  sofpipe<={sofpipe[2:0],sof};started<=0;finished<=0;
  if(!rst)begin ready<=0;bus_active<=0;bus_cycles<=0;error<=0;sofpipe<=0;end
  else begin
   if(!bus_active)ready<=1;
   if(req)begin
    check(!bus_active,"one inflight");check(exp>=4&&exp<=1991,"legal exposure");
    check(analog(gain)>0,"legal analog encoding");
    if(req_count>0)check(frame-last_req_frame>=4,"not chase N+2 old frames");
    last_req_frame=frame;req_count=req_count+1;
    accepted_exp=exp;accepted_gain=gain;bus_active<=1;bus_cycles<=100;ready<=0;started<=1;
   end
   if(bus_active)begin
    bus_cycles<=bus_cycles-1;
    if(bus_cycles==1)begin
     bus_active<=0;ready<=1;
     if(inject_nack)error<=1;
     else begin
      finished<=1;pending_exp=accepted_exp;pending_gain=analog(accepted_gain);
      pending_frame=frame+2;count_at_done=frame;
     end
    end
   end
  end
 end
 task send_frame;
 begin
  frame=frame+1;
  if(pending_frame>=0&&frame>=pending_frame)begin
   applied_exp=pending_exp;applied_gain=pending_gain;pending_frame=-1;
  end
  // Pure plant formula from independent physical exposure quantity.
  if(light==0)pixel=0;
  else begin
   plant_response=(1.0*applied_exp*applied_gain*light)/65536.0;
   pixel=plant_response>=255.0?255:$rtoi(plant_response);
  end
  if(pixel>255)pixel=255;
  @(negedge sc);sof=1;repeat(4)@(negedge sc);sof=0;
  repeat(20)@(negedge sc);
  user=1;@(negedge sc);user=0;
  for(r=0;r<4;r=r+1)begin
   for(b=0;b<4;b=b+1)begin
    valid=1;last=0;
    for(p=0;p<4;p=p+1)begin
     if(color_scene==1)data[p*24 +:24]={pixel[7:0],16'd0};
     else if(color_scene==2)begin
      // Independent two-dimensional radiance map, not DUT statistic formula.
      // Left-quarter bright background; central quarter subject; dim surround.
      plant_response=(1.0*applied_exp*applied_gain*((window_right?(b*4+3-p>=12):(b*4+3-p<4))?window_light:
       ((r>=1&&r<3&&b*4+3-p>=4&&b*4+3-p<12)?interior_light:32)))/65536.0;
      window_pixel=plant_response>=255.0?255:$rtoi(plant_response);
      if(noisy)begin
       noise_value=((r*29+(b*4+3-p)*17+frame*13)%5)-2;
       window_pixel=window_pixel+noise_value;
       if(window_pixel>255)window_pixel=255;if(window_pixel<0)window_pixel=0;
      end
      data[p*24 +:24]={window_pixel[7:0],window_pixel[7:0],window_pixel[7:0]};
     end
     else if(color_scene==3)begin
      plant_response=(1.0*applied_exp*applied_gain*((r>=1&&r<3&&b*4+3-p>=4&&b*4+3-p<12)?1024:64))/65536.0;
      window_pixel=plant_response>=255.0?255:$rtoi(plant_response);
      data[p*24 +:24]={window_pixel[7:0],window_pixel[7:0],window_pixel[7:0]};
     end
     else if(color_scene==4)data[p*24 +:24]={16'd0,pixel[7:0]};
     else if(color_scene==5)data[p*24 +:24]={8'd0,pixel[7:0],8'd0};
     else data[p*24 +:24]={pixel[7:0],pixel[7:0],pixel[7:0]};
    end
    @(negedge sc);
   end
   valid=0;last=1;@(negedge sc);last=0;repeat(8)@(negedge sc);
  end
  repeat(550)@(negedge sc); // independent blank time, enough for serial surrogate
 end endtask
 task scene;
 input integer illumination,frames;input [255:0] label;
 begin light=illumination;for(idx=0;idx<frames;idx=idx+1)send_frame;
  $display("SCENE %s frames=%0d Y=%0d sat=%0d white=%0d bright=%0d exp=%0d AG=%0d updates=%0d",label,frames,mean,sat,ctrl.white_q8,ctrl.bright_q8,exp,gain,updates);
 end endtask
 initial begin
  #137;rst=1;repeat(150)@(negedge sc);
  scene(256,20,"constant indoor");check(mean>=100&&mean<=124,"indoor target");
  old_updates=updates;scene(256,20,"constant stability");check(updates==old_updates,"constant no oscillation");
  scene(2048,90,"dark to bright");check(mean>=85&&mean<=135&&sat<13,"bright convergence");
  scene(256,100,"bright to dark");check(mean>=85&&mean<=135,"dark convergence");
  scene(0,130,"all black limit");check(exp==1991&&gain==176,"upper limits");
  scene(10000000,240,"all white limit");check(exp==4&&gain==16,"lower limits");
  old_updates=updates;run_sc=0;#30000;check(updates==old_updates,"source stopped no update");run_sc=1;
  run_cc=0;repeat(3)send_frame;run_cc=1;repeat(40)@(negedge sc);
  check(frame_fault&&fault&&state==7,"destination stop overflow halts updates");
  rst=0;#200;rst=1;frame=0;req_count=0;pending_frame=-1;light=256;
  scene(256,20,"reset restart");check(!fault,"restart error clear");
  color_scene=1;scene(2048,30,"primary clipped red");
  old_updates=updates;scene(2048,30,"same red stability");
  check(updates==old_updates,"low-Y saturated color no chase");
  color_scene=2;
  scene(256,60,"dark interior bright window");
  check(mean>=100&&mean<=124,"indoor weighted target");
  check(ctrl.white_q8>=64,"background window clipping allowed");
  check((1.0*applied_exp*applied_gain*interior_light)/65536.0>=90,"subject not sacrificed to window");
  hold_updates=updates;scene(256,30,"window stable no pumping");
  check(updates==hold_updates,"indoor window no oscillation");
  noisy=1;scene(256,30,"fixed light synthetic noise");
  check(updates==hold_updates,"small noise no pumping");noisy=0;
  window_right=1;scene(256,30,"bright window moves right");
  check(updates==hold_updates,"symmetric edge move no chase");
  window_light=8192;scene(256,70,"window doubles illumination");
  check(mean>=100&&mean<=124,"window brighter subject stays metered");
  hold_updates=updates;scene(256,30,"brighter window stability");
  check(updates==hold_updates,"background-only change no chase");
  color_scene=3;scene(256,100,"central white paper");
  check(mean>=100&&mean<=124,"white paper weighted convergence");
  hold_updates=updates;scene(256,30,"white paper fixed illumination");
  check(updates==hold_updates,"white paper no pumping");
  color_scene=0;scene(32,120,"dim room exposure capacity");
  check(exp==1991&&gain==176&&mean<100,"dim room cap not false target");
  hold_updates=updates;scene(32,30,"dim room cap stable");
  check(updates==hold_updates,"cap no redundant transactions");
  color_scene=4;scene(2048,30,"blue object");hold_updates=updates;
  scene(2048,30,"blue stable");check(updates==hold_updates,"blue clipping no chase");
  color_scene=5;scene(2048,90,"green object");hold_updates=updates;
  scene(2048,30,"green stable");check(updates==hold_updates,"green stable light no chase");
  color_scene=0;scene(256,100,"leave window return indoor");
  check(mean>=85&&mean<=135,"window exit recovers indoor");
  inject_nack=1;scene(2048,20,"NACK stop");check(fault&&state==7,"NACK sticky stop");
  old_updates=req_count;scene(256,10,"NACK no retry");check(req_count==old_updates,"no automatic retry");
  check(!bad,"complete frame statistic");
  $display("RESULT CLOSED_AE checks=%0d errors=%0d requests=%0d",checks,errors,req_count);
  if(errors)$fatal(1,"AE selfcheck");$finish;
 end
 initial begin #30000000;$fatal(1,"timeout");end
endmodule
