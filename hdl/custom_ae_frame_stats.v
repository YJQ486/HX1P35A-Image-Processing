// Non-intrusive pre-AWB RGB888 tap. No pixels or stream markers are modified.
module custom_ae_frame_stats #(
 parameter integer WIDTH=1280, HEIGHT=720, SAT_LEVEL=250, BRIGHT_LEVEL=176, SETTLE_SOF=3,
 parameter integer CENTER_WEIGHT=4
)(
 input i_clk,i_rst_n,input [95:0] i_data,input i_valid,i_user,i_last,
 input i_csi_sof,input i_done_token,
 output reg [159:0] o_packet,output reg o_bad_frame
);
 reg token_meta,token_sync,token_seen;
 reg [3:0] settle_count;
 reg sof_old;
 reg [9:0] beat_sum;
 reg [2:0] beat_sat;
 reg [2:0] beat_white,beat_bright;
 reg [31:0] beat_weighted,weighted_total;
 reg [15:0] input_group,input_row;
 reg valid_d,user_d,last_d;
 reg active,bad,frame_eligible,frame_token;
 reg [15:0] sequence;
 reg [15:0] row_beats;
 reg [15:0] rows;
 reg [27:0] total;
 reg [19:0] saturated;
 reg [19:0] white_pixels,bright_pixels;
 integer p;
 reg [9:0] sum_comb;
 reg [2:0] sat_comb;
 reg [2:0] white_comb,bright_comb;
 reg rclip,gclip,bclip,rbright,gbright,bbright;
 reg [9:0] ytemp;
 reg [31:0] weighted_comb;
 integer input_x;
 wire [15:0] group_now=i_user?16'd0:input_group;
 wire [15:0] row_now=i_user?16'd0:input_row;
 always @* begin
  sum_comb=0;sat_comb=0;white_comb=0;bright_comb=0;ytemp=0;weighted_comb=0;input_x=0;
  rclip=0;gclip=0;bclip=0;rbright=0;gbright=0;bbright=0;
  for(p=0;p<4;p=p+1)begin
   ytemp={2'b00,i_data[p*24+16 +:8]}+
         {1'b0,i_data[p*24+8 +:8],1'b0}+{2'b00,i_data[p*24 +:8]};
   sum_comb=sum_comb+{2'b00,ytemp[9:2]};
   // Logical leftmost pixel is [95:72], not the low24-bit lane.
   input_x=group_now*4+(3-p);
   if(input_x>=WIDTH/4 &&input_x<3*WIDTH/4 &&row_now>=HEIGHT/4 &&row_now<3*HEIGHT/4)
    weighted_comb=weighted_comb+{24'd0,ytemp[9:2]}*CENTER_WEIGHT;
   else weighted_comb=weighted_comb+{24'd0,ytemp[9:2]};
   if(i_data[p*24+16 +:8]>=SAT_LEVEL ||i_data[p*24+8 +:8]>=SAT_LEVEL ||
      i_data[p*24 +:8]>=SAT_LEVEL)sat_comb=sat_comb+1'b1;
   rclip=i_data[p*24+16 +:8]>=SAT_LEVEL;
   gclip=i_data[p*24+8 +:8]>=SAT_LEVEL;
   bclip=i_data[p*24 +:8]>=SAT_LEVEL;
   rbright=i_data[p*24+16 +:8]>=BRIGHT_LEVEL;
   gbright=i_data[p*24+8 +:8]>=BRIGHT_LEVEL;
   bbright=i_data[p*24 +:8]>=BRIGHT_LEVEL;
   // Distribution bins, not a claim about physical sensor RAW clipping.
   // At least two channels: single-channel primary saturation is excluded.
   if((rclip&&gclip)||(rclip&&bclip)||(gclip&&bclip))white_comb=white_comb+1'b1;
   if((rbright&&gbright)||(rbright&&bbright)||(gbright&&bbright))bright_comb=bright_comb+1'b1;
  end
 end
 wire [16:0] next_beats={1'b0,(user_d?16'd0:row_beats)}+(valid_d?17'd1:17'd0);
 wire [27:0] next_sum=(user_d?28'd0:total)+(valid_d?{18'd0,beat_sum}:28'd0);
 wire [19:0] next_sat=(user_d?20'd0:saturated)+(valid_d?{17'd0,beat_sat}:20'd0);
 wire [19:0] next_white=(user_d?20'd0:white_pixels)+(valid_d?{17'd0,beat_white}:20'd0);
 wire [19:0] next_bright=(user_d?20'd0:bright_pixels)+(valid_d?{17'd0,beat_bright}:20'd0);
 wire [31:0] next_weighted=(user_d?32'd0:weighted_total)+(valid_d?beat_weighted:32'd0);
 wire [15:0] current_row=user_d?16'd0:rows;
 wire frame_live=active||user_d;
 wire frame_bad=user_d?1'b0:bad;
 wire eligible_now=token_sync==token_seen && settle_count>=SETTLE_SOF;
 always @(posedge i_clk or negedge i_rst_n)begin
  if(!i_rst_n)begin
   token_meta<=0;token_sync<=0;token_seen<=0;settle_count<=0;sof_old<=0;
   beat_sum<=0;beat_sat<=0;beat_white<=0;beat_bright<=0;valid_d<=0;user_d<=0;last_d<=0;
   beat_weighted<=0;weighted_total<=0;input_group<=0;input_row<=0;
   active<=0;bad<=0;frame_eligible<=0;frame_token<=0;sequence<=0;
   row_beats<=0;rows<=0;total<=0;saturated<=0;white_pixels<=0;bright_pixels<=0;o_packet<=0;o_bad_frame<=0;
  end else begin
   token_meta<=i_done_token;token_sync<=token_meta;sof_old<=i_csi_sof;
   if(token_sync!=token_seen)begin token_seen<=token_sync;settle_count<=0;end
   else if(i_csi_sof&&!sof_old &&settle_count<SETTLE_SOF)settle_count<=settle_count+1'b1;
   beat_sum<=sum_comb;beat_sat<=sat_comb;valid_d<=i_valid;user_d<=i_user;last_d<=i_last;
   beat_white<=white_comb;beat_bright<=bright_comb;
   beat_weighted<=weighted_comb;
   if(i_user)begin input_group<=0;input_row<=0;end
   if(i_valid)input_group<=group_now+1'b1;
   if(i_last)begin input_group<=0;input_row<=row_now+1'b1;end
   if(user_d)begin
    if(active)o_bad_frame<=1;
    active<=1;bad<=0;rows<=0;row_beats<=0;total<=0;saturated<=0;white_pixels<=0;bright_pixels<=0;
    weighted_total<=0;
    sequence<=sequence+1'b1;frame_token<=token_sync;frame_eligible<=eligible_now;
   end
   if(frame_live &&(valid_d||last_d))begin
    total<=next_sum;saturated<=next_sat;
    white_pixels<=next_white;bright_pixels<=next_bright;
    weighted_total<=next_weighted;
    if(last_d)begin
     row_beats<=0;rows<=current_row+1'b1;
     if(next_beats!=WIDTH/4)begin bad<=1;o_bad_frame<=1;end
     if(current_row==HEIGHT-1)begin
      active<=0;
      if(!frame_bad &&next_beats==WIDTH/4)
       o_packet<={next_weighted,8'd0,next_bright,next_white,14'd0,(user_d?eligible_now:frame_eligible),
        (user_d?token_sync:frame_token),(user_d?sequence+16'd1:sequence),next_sum,next_sat};
     end
    end else begin
     row_beats<=next_beats[15:0];
     if(next_beats>WIDTH/4)begin bad<=1;o_bad_frame<=1;end
    end
   end else if(valid_d&&!frame_live)o_bad_frame<=1;
  end
 end
endmodule
