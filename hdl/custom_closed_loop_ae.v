// CAM clock controller. Exact iterative division, one in-flight eight-write group.
module custom_closed_loop_ae #(
 parameter integer PIXELS=1280*720,TARGET=112,TOLERANCE=12,
 parameter integer STEP_SHIFT=2,UPDATE_INTERVAL=2,SAT_LIMIT_Q8=13,
 parameter integer WHITE_LIMIT_Q8=128,BRIGHT_HOLD_Q8=192,COLOR_DOMINANT_Q8=192,
 parameter integer CENTER_WEIGHT=4,CENTER_PIXELS=PIXELS/4,
 parameter integer EXP_MIN=4,EXP_MAX=1991,INITIAL_EXP=1991,INITIAL_GAIN=144
)(
 input i_clk,i_rst_n,input [159:0] i_packet,
 input i_cfg_ready,i_started,i_finished,i_error,i_sof,i_frame_ready,i_frame_fault,
 output reg o_request,output reg [15:0] o_exposure,o_gain,
 output reg o_done_token,output reg [7:0] o_mean,
 output reg [8:0] o_sat_q8,output reg [3:0] o_state,
 output reg [15:0] o_completed_exposure,o_completed_gain,
 output reg [15:0] o_updates,output reg o_fault
);
 localparam [3:0] BOOT=0,START_WAIT=1,BUS_WAIT=2,FEEDBACK=3,DIVIDE=4,DECIDE=5,SOF_WAIT=6,ERROR=7;
 localparam integer METER_PIXELS=PIXELS+(CENTER_WEIGHT-1)*CENTER_PIXELS;
 reg [15:0] seen_sequence,pending_sequence;
 reg [31:0] yn,sn,yr,sr,yq,sq;
 reg [31:0] wn,bn,wr,br,wq,bq;
 reg [8:0] white_q8,bright_q8;
 reg [5:0] bits_left;
 reg [7:0] interval_count;
 reg [1:0] previous_direction;
 reg packet_token;
 reg [15:0] candidate_exp,candidate_gain;
 reg [1:0] direction;
 reg [17:0] base_exp,delta,new_exp;
 reg [15:0] base_gain;
 wire [32:0] ytrial={yr,yn[31]},strial={sr,sn[31]};
 wire [32:0] wtrial={wr,wn[31]},btrial={br,bn[31]};
 always @*begin
  direction=0;base_exp={2'd0,o_exposure};base_gain=o_gain;
  // Indoor subject priority: a small bright background must not veto dark-up.
  // Broad multichannel highlights only bias the upper half of the target band.
  // Dominant single-channel clipping remains an unattainable-luma conflict.
  if(o_mean>TARGET+TOLERANCE)direction=2;
  else if((white_q8>WHITE_LIMIT_Q8 ||bright_q8>BRIGHT_HOLD_Q8) &&o_mean>TARGET)direction=2;
  else if(o_mean<TARGET-TOLERANCE)begin
   if(o_sat_q8>=COLOR_DOMINANT_Q8 &&white_q8<=SAT_LIMIT_Q8)direction=0;
   else direction=1;
  end
  if(direction==2 &&o_gain>16 &&o_exposure<=EXP_MAX/2)begin
   base_exp={1'd0,o_exposure,1'b0};base_gain=o_gain-16'd32;
  end else if(direction==1 &&o_exposure==EXP_MAX &&o_gain<176)begin
   base_exp=({2'd0,o_exposure}+18'd1)>>1;base_gain=o_gain+16'd32;
  end
  delta=base_exp>>STEP_SHIFT;if(delta==0)delta=1;
  new_exp=base_exp;
  if(direction==1)new_exp=base_exp+delta;
  else if(direction==2)new_exp=base_exp>delta?base_exp-delta:18'd0;
  if(new_exp<EXP_MIN)new_exp=EXP_MIN;
  if(new_exp>EXP_MAX)new_exp=EXP_MAX;
  candidate_exp=new_exp[15:0];candidate_gain=base_gain;
 end
 always @(posedge i_clk or negedge i_rst_n)begin
  if(!i_rst_n)begin
   o_request<=0;o_exposure<=INITIAL_EXP;o_gain<=INITIAL_GAIN;o_done_token<=0;
   o_mean<=0;o_sat_q8<=0;o_state<=BOOT;o_completed_exposure<=0;o_completed_gain<=0;
   o_updates<=0;o_fault<=0;seen_sequence<=0;pending_sequence<=0;
   yn<=0;sn<=0;yr<=0;sr<=0;yq<=0;sq<=0;bits_left<=0;interval_count<=0;
   previous_direction<=0;packet_token<=0;
   wn<=0;bn<=0;wr<=0;br<=0;wq<=0;bq<=0;white_q8<=0;bright_q8<=0;
  end else begin
   o_request<=0;
   if(i_error||i_frame_fault)begin o_fault<=1;o_state<=ERROR;end
   else case(o_state)
    BOOT:if(i_cfg_ready &&i_frame_ready &&i_sof)begin o_request<=1;o_state<=START_WAIT;end
    START_WAIT:if(i_started)o_state<=BUS_WAIT;
    BUS_WAIT:if(i_finished)begin
     o_done_token<=!o_done_token;o_completed_exposure<=o_exposure;o_completed_gain<=o_gain;
     o_updates<=o_updates+1'b1;interval_count<=0;previous_direction<=0;o_state<=FEEDBACK;
    end
    FEEDBACK:if(i_frame_ready &&i_packet[63:48]!=seen_sequence)begin
     seen_sequence<=i_packet[63:48];
     if(i_packet[65] &&i_packet[64]==o_done_token)begin
      yn<=i_packet[159:128];sn<={4'd0,i_packet[19:0],8'd0};
      yr<=0;sr<=0;yq<=0;sq<=0;bits_left<=32;
      wn<={4'd0,i_packet[99:80],8'd0};bn<={4'd0,i_packet[119:100],8'd0};
      wr<=0;br<=0;wq<=0;bq<=0;
      packet_token<=i_packet[64];pending_sequence<=i_packet[63:48];o_state<=DIVIDE;
     end
    end
    DIVIDE:begin
     yn<={yn[30:0],1'b0};sn<={sn[30:0],1'b0};
     wn<={wn[30:0],1'b0};bn<={bn[30:0],1'b0};
     if(wtrial>=PIXELS)begin wr<=wtrial-PIXELS;wq<={wq[30:0],1'b1};end
     else begin wr<=wtrial[31:0];wq<={wq[30:0],1'b0};end
     if(btrial>=PIXELS)begin br<=btrial-PIXELS;bq<={bq[30:0],1'b1};end
     else begin br<=btrial[31:0];bq<={bq[30:0],1'b0};end
     if(ytrial>=METER_PIXELS)begin yr<=ytrial-METER_PIXELS;yq<={yq[30:0],1'b1};end
     else begin yr<=ytrial[31:0];yq<={yq[30:0],1'b0};end
     if(strial>=PIXELS)begin sr<=strial-PIXELS;sq<={sq[30:0],1'b1};end
     else begin sr<=strial[31:0];sq<={sq[30:0],1'b0};end
     bits_left<=bits_left-1'b1;
     if(bits_left==1)o_state<=DECIDE;
    end
    DECIDE:begin
     // Quotients are now stable; direction is evaluated on the next cycle.
     o_mean<=yq[7:0];o_sat_q8<=sq[8:0];interval_count<=interval_count+1'b1;
     white_q8<=wq[8:0];bright_q8<=bq[8:0];
     o_state<=SOF_WAIT;
    end
    SOF_WAIT:begin
     // Never issue after loss of epoch, or reuse a result from an older frame.
     if(!i_frame_ready ||packet_token!=o_done_token ||i_packet[63:48]!=pending_sequence)begin
      previous_direction<=0;o_state<=FEEDBACK;
     end else if(i_sof)begin
      if(direction!=0 &&interval_count>=UPDATE_INTERVAL &&
         (direction==previous_direction ||o_sat_q8>SAT_LIMIT_Q8 ||white_q8>WHITE_LIMIT_Q8) &&
         (candidate_exp!=o_exposure ||candidate_gain!=o_gain) &&i_cfg_ready)begin
       o_exposure<=candidate_exp;o_gain<=candidate_gain;o_request<=1;o_state<=START_WAIT;
      end else begin previous_direction<=direction;o_state<=FEEDBACK;end
     end
    end
    ERROR:begin o_request<=0;end
    default:o_state<=ERROR;
   endcase
  end
 end
endmodule
