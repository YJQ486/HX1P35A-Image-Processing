// Independent full-frame gray-world experiment. No sensor/CFA/AE changes.
// Input is the shared AWB delay's multiplication input; output registers on
// the SAME edge as the original AWB multipliers. No stream latency is added.
module custom_frame_awb #(
 parameter integer WIDTH=1280, HEIGHT=720,
 parameter integer MIN_SAMPLES=WIDTH*HEIGHT/16,
 parameter integer SAMPLE_LOW=16, SAMPLE_HIGH=239,
 parameter [19:0] GAIN_MIN=20'h08000, GAIN_MAX=20'h20000,
 parameter integer SMOOTH_SHIFT=2
)(
 input i_clk,i_rst_n,input [95:0] i_data,input i_valid,i_sof,
 output wire [95:0] o_data,
 output reg [19:0] o_r_gain,o_b_gain,
 output reg o_pending,o_bad_frame,o_late,
 output reg [19:0] o_samples
);
 localparam integer WORDS=WIDTH*HEIGHT/4, GROUPS=WIDTH/4;
 reg pending_sof,active,valid_old,frame_bad;
 reg [19:0] word_count;reg [15:0] row_count;
 reg [15:0] frame_id,job_id,result_id;
 reg [19:0] active_r,active_b,pending_r,pending_b,base_r,base_b;
 wire begin_frame=i_valid&&!active&&(pending_sof||i_sof);
 wire accepted=i_valid&&(active||begin_frame);
 wire end_frame=accepted&&((begin_frame?32'd0:word_count)==WORDS-1);
 // Complete pending result is committed before the first pixel's products.
 wire commit=begin_frame&&o_pending&&(result_id==frame_id);
 wire [19:0] use_r=commit?pending_r:active_r;
 wire [19:0] use_b=commit?pending_b:active_b;
 reg [27:0] product_r[0:3],product_b[0:3];
 reg [7:0] green[0:3];
 genvar l;
 generate for(l=0;l<4;l=l+1)begin: pixels
  assign o_data[l*24+16 +:8]=(|product_r[l][27:24])?8'hff:product_r[l][23:16];
  assign o_data[l*24+8 +:8]=green[l];
  assign o_data[l*24 +:8]=(|product_b[l][27:24])?8'hff:product_b[l][23:16];
 end endgenerate
 // Per-pixel sample qualification; all four lanes are equally represented.
 // Reject dark/clipped or >4:1 chromatic samples. This is conservative
 // gray-world qualification, NOT a claim to classify real neutral objects.
 integer p;reg [7:0] r,g,b,hi,lo;
 reg [3:0] qualified;
 reg [3:0] qualified_d;
 reg [95:0] sample_data;
 reg sample_valid,sample_begin,sample_end,sample_bad;
 reg [15:0] sample_id,stat_id;
 reg [9:0] beat_r,beat_g,beat_b;
 reg [2:0] beat_n;
 always @*begin
  qualified=0;r=0;g=0;b=0;hi=0;lo=0;
  for(p=0;p<4;p=p+1)begin
   r=i_data[p*24+16 +:8];g=i_data[p*24+8 +:8];b=i_data[p*24 +:8];
   hi=(r>g)?r:g;hi=(b>hi)?b:hi;
   lo=(r<g)?r:g;lo=(b<lo)?b:lo;
   qualified[p]=(lo>=SAMPLE_LOW&&hi<=SAMPLE_HIGH&&{lo,2'b00}>={2'b00,hi});
  end
 end
 integer q;
 always @*begin
  beat_r=0;beat_g=0;beat_b=0;beat_n=0;
  for(q=0;q<4;q=q+1)if(qualified_d[q])begin
   beat_r=beat_r+{2'd0,sample_data[q*24+16 +:8]};
   beat_g=beat_g+{2'd0,sample_data[q*24+8 +:8]};
   beat_b=beat_b+{2'd0,sample_data[q*24 +:8]};beat_n=beat_n+1'b1;
  end
 end
 // Statistics have a private pipeline, independent of the pixel/marker path.
 reg stat_valid,stat_begin,stat_end,stat_bad;
 reg [9:0] sr,sg,sb;reg [2:0] sn;
 reg [31:0] sum_r,sum_g,sum_b;reg [19:0] samples;
 wire [31:0] next_r=(stat_begin?32'd0:sum_r)+{22'd0,sr};
 wire [31:0] next_g=(stat_begin?32'd0:sum_g)+{22'd0,sg};
 wire [31:0] next_b=(stat_begin?32'd0:sum_b)+{22'd0,sb};
 wire [19:0] next_n=(stat_begin?20'd0:samples)+{17'd0,sn};
 // Resettable restoring divider, two sequential unsigned 48/32 operations.
 // No dependence on the original vendor divider's non-flushing reset stages.
 reg busy,channel;reg [5:0] bits_left;
 reg [47:0] quotient;
 reg [32:0] remainder;
 reg [31:0] denominator,saved_b,saved_g;
 reg [19:0] result_r;
 wire [32:0] shifted={remainder[31:0],quotient[47]};
 wire subtract_ok=shifted>={1'b0,denominator};
 wire [32:0] remainder_next=subtract_ok?shifted-{1'b0,denominator}:shifted;
 wire [47:0] quotient_next={quotient[46:0],subtract_ok};
 function [19:0] bounded;
 input [47:0] q;begin
  if(q<GAIN_MIN)bounded=GAIN_MIN;
  else if(q>GAIN_MAX)bounded=GAIN_MAX;
  else bounded=q[19:0];
 end endfunction
 function [19:0] smooth;
 input [19:0] old_value,new_value;
 begin
  if(new_value>=old_value)smooth=old_value+((new_value-old_value)>>SMOOTH_SHIFT);
  else smooth=old_value-((old_value-new_value)>>SMOOTH_SHIFT);
 end endfunction
 integer k;
 always @(posedge i_clk or negedge i_rst_n)begin
  if(!i_rst_n)begin
   pending_sof<=0;active<=0;valid_old<=0;frame_bad<=0;word_count<=0;row_count<=0;
   frame_id<=0;job_id<=0;result_id<=0;active_r<=20'h10000;active_b<=20'h10000;
   pending_r<=20'h10000;pending_b<=20'h10000;base_r<=20'h10000;base_b<=20'h10000;
   o_r_gain<=20'h10000;o_b_gain<=20'h10000;o_pending<=0;o_bad_frame<=0;o_late<=0;o_samples<=0;
   stat_valid<=0;stat_begin<=0;stat_end<=0;stat_bad<=0;sr<=0;sg<=0;sb<=0;sn<=0;
   qualified_d<=0;sample_data<=0;sample_valid<=0;sample_begin<=0;sample_end<=0;sample_bad<=0;sample_id<=0;stat_id<=0;
   sum_r<=0;sum_g<=0;sum_b<=0;samples<=0;busy<=0;channel<=0;bits_left<=0;
   quotient<=0;remainder<=0;denominator<=0;saved_b<=0;saved_g<=0;result_r<=0;
   for(k=0;k<4;k=k+1)begin product_r[k]<=0;product_b[k]<=0;green[k]<=0;end
  end else begin
   valid_old<=i_valid;
   if(i_sof)begin
    if(pending_sof)o_bad_frame<=1;
    pending_sof<=1;
   end
   if(begin_frame)begin
    pending_sof<=0;active<=1;frame_bad<=0;word_count<=0;row_count<=0;
    frame_id<=frame_id+1'b1;
    if(commit)begin active_r<=pending_r;active_b<=pending_b;end
    o_pending<=0;
    // An unfinished or late result must NEVER be committed to a later frame.
    if(busy)begin busy<=0;o_late<=1;end
   end
   if(accepted)begin
    word_count<=(begin_frame?32'd0:word_count)+1'b1;
    row_count<=(begin_frame?32'd0:row_count)+1'b1;
    if(end_frame)active<=0;
   end else if(i_valid)begin o_bad_frame<=1;end
   if(valid_old&&!i_valid)begin
    row_count<=0;
    if(row_count!=GROUPS)begin frame_bad<=1;o_bad_frame<=1;end
   end
   sample_data<=i_data;qualified_d<=qualified;
   sample_valid<=accepted;sample_begin<=begin_frame;sample_end<=end_frame;sample_bad<=frame_bad;
   sample_id<=begin_frame?frame_id+1'b1:frame_id;
   stat_valid<=sample_valid;stat_begin<=sample_begin;stat_end<=sample_end;stat_bad<=sample_bad;stat_id<=sample_id;
   sr<=beat_r;sg<=beat_g;sb<=beat_b;sn<=beat_n;
   if(stat_valid)begin
    sum_r<=next_r;sum_g<=next_g;sum_b<=next_b;samples<=next_n;
    if(stat_end)begin
     o_samples<=next_n;
     if(!stat_bad&&next_n>=MIN_SAMPLES&&next_r!=0&&next_b!=0&&!busy&&!begin_frame&&stat_id==frame_id)begin
      busy<=1;channel<=0;bits_left<=48;quotient<={next_g,16'd0};remainder<=0;
      denominator<=next_r;saved_b<=next_b;saved_g<=next_g;job_id<=stat_id;
      base_r<=active_r;base_b<=active_b;
     end
    end
   end
   if(busy&&!begin_frame)begin
    quotient<=quotient_next;remainder<=remainder_next;bits_left<=bits_left-1'b1;
    if(bits_left==1)begin
     if(!channel)begin
      result_r<=bounded(quotient_next);channel<=1;bits_left<=48;
      quotient<={saved_g,16'd0};remainder<=0;denominator<=saved_b;
     end else begin
      busy<=0;
      if(job_id==frame_id)begin
       pending_r<=smooth(base_r,result_r);pending_b<=smooth(base_b,bounded(quotient_next));
       result_id<=job_id;o_pending<=1;
      end else o_late<=1;
     end
    end
   end
   if(i_valid)begin
    o_r_gain<=use_r;o_b_gain<=use_b;
    for(k=0;k<4;k=k+1)begin
     product_r[k]<=use_r*i_data[k*24+16 +:8];
     product_b[k]<=use_b*i_data[k*24 +:8];green[k]<=i_data[k*24+8 +:8];
    end
   end
  end
 end
endmodule
