// One outstanding frame event plus one queued SOF, acknowledged at the source.
// Overflow is sticky and disables use of the count as a readback prerequisite.
// Common VIDEO epoch asserts both sides; private three-stage releases avoid
// mixing independent camera-control and CSI-user reset epochs.
module custom_csi_sof_events(
 input i_src_clk,input i_sof,input i_dst_clk,input i_epoch_n,input i_arm,
 output reg o_event,output wire o_fault,output wire o_ready
);
 reg [2:0] src_release,dst_release;
 reg arm_meta,arm_sync,request_toggle,ack_meta,ack_sync,overflow;
 reg sof_old,armed;
 reg queued;
 reg req_meta,req_sync,ack_toggle,fault_meta,fault_sync;
 assign o_fault=fault_sync;
 assign o_ready=dst_release[2];
 always @(posedge i_src_clk or negedge i_epoch_n)
  if(!i_epoch_n)src_release<=0;else src_release<={src_release[1:0],1'b1};
 always @(posedge i_dst_clk or negedge i_epoch_n)
  if(!i_epoch_n)dst_release<=0;else dst_release<={dst_release[1:0],1'b1};
 always @(posedge i_src_clk or negedge src_release[2])begin
  if(!src_release[2])begin
   arm_meta<=0;arm_sync<=0;request_toggle<=0;ack_meta<=0;ack_sync<=0;
   overflow<=0;sof_old<=0;armed<=0;queued<=0;
  end else begin
   arm_meta<=i_arm;arm_sync<=arm_meta;ack_meta<=ack_toggle;ack_sync<=ack_meta;
   sof_old<=i_sof;
   // Require low after reset/arm, so a source high spanning reset is discarded.
   if(!arm_sync)armed<=0;else if(!i_sof)armed<=1;
   if(arm_sync)begin
    if(request_toggle==ack_sync)begin
     if(queued)begin
      request_toggle<=!request_toggle;queued<=0;
      if(armed &&i_sof &&!sof_old)queued<=1;
     end else if(armed &&i_sof &&!sof_old)request_toggle<=!request_toggle;
    end else if(armed &&i_sof &&!sof_old)begin
     if(!queued)queued<=1;else overflow<=1;
    end
   end
  end
 end
 always @(posedge i_dst_clk or negedge dst_release[2])begin
  if(!dst_release[2])begin req_meta<=0;req_sync<=0;ack_toggle<=0;
   fault_meta<=0;fault_sync<=0;o_event<=0;end
  else begin
   req_meta<=request_toggle;req_sync<=req_meta;
   fault_meta<=overflow;fault_sync<=fault_meta;
   o_event<=0;
   if(req_sync!=ack_toggle)begin o_event<=1;ack_toggle<=req_sync;end
  end
 end
endmodule
