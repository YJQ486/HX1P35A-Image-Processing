// Passive RGB888 x4 detector. Power-of-two tiles and one dominant row-run chain.
// DIAG uses spare coordinate MSBs; the matching overlay masks these explicitly.
module custom_red_detector #(
 parameter BLUE=0,WIDTH=1280,HEIGHT=720,R_MIN=96,RG_DELTA=48,RB_DELTA=48,
 parameter MIN_PIXELS=160,CONFIRM_FRAMES=3,WATCHDOG_CYCLES=8000000,
 parameter TILE_CAP=64,MIN_WIDTH=1,MIN_HEIGHT=1,INDOOR_RED=0,TILE_BITS=5,INDOOR_BLUE=0,DIAG=0,MIN_SPAN=1,RED_RESCUE=0,
 parameter TILE_ENTER=64,TILE_EXIT=48,EXIT_FRAMES=2
)(input i_clk,i_rst_n,input [95:0] i_data,input i_valid,i_user,i_last,i_fault,
 output reg [56:0] o_packet);
 localparam COLS=WIDTH/(1<<TILE_BITS);
 reg [3:0] red,rd,chroma,cd,rescue,rsd;
 reg vd,ud,ld,fd;
 integer k;
 reg [7:0] r,g,b;
 always @* begin
  red=0;chroma=0;rescue=0;r=0;g=0;b=0;
  for(k=0;k<4;k=k+1)begin
   r=i_data[95-k*24 -:8];g=i_data[87-k*24 -:8];b=i_data[79-k*24 -:8];
   if(BLUE)begin r=i_data[79-k*24 -:8];b=i_data[95-k*24 -:8];end
   if(BLUE&&INDOOR_BLUE)begin
    // Blue: relative dominance plus absolute separation; cyan/grey rejected.
    chroma[k]=({1'b0,r}>={1'b0,g}+9'd20)&&({1'b0,r}>={1'b0,b}+9'd24)&&
      ({3'b0,r}<<2)>=(({3'b0,g}<<2)+{3'b0,g})&&
      ({3'b0,r}<<1)>=(({3'b0,b}<<1)+{3'b0,b});
    red[k]=chroma[k]&&(r>=64);
   end else begin
    chroma[k]=({1'b0,r}>={1'b0,g}+RG_DELTA)&&({1'b0,r}>={1'b0,b}+RB_DELTA);
    if(INDOOR_RED&&!BLUE)chroma[k]=chroma[k]&&(({3'b0,r}<<1)>=(({3'b0,g}<<1)+{3'b0,g}));
    red[k]=(r>=R_MIN)&&chroma[k];
    // Restricted dim red extension. Above96 this is a subset of the old rule.
    // It never relaxes warm low-saturation colors, density or region support.
    if(RED_RESCUE&&INDOOR_RED&&!BLUE)begin
     rescue[k]=!red[k]&&(r>=64)&&({1'b0,r}>=({1'b0,g}<<1))&&({1'b0,r}>=({1'b0,b}<<1));
     red[k]=red[k]||rescue[k];
    end
   end
  end
 end
 always @(posedge i_clk or negedge i_rst_n)
 if(!i_rst_n)begin rd<=0;cd<=0;rsd<=0;vd<=0;ud<=0;ld<=0;fd<=0;end
 else begin rd<=red;cd<=chroma;rsd<=rescue;vd<=i_valid;ud<=i_user;ld<=i_last;fd<=i_fault;end
 wire [2:0] beat_count={2'd0,rd[0]}+{2'd0,rd[1]}+{2'd0,rd[2]}+{2'd0,rd[3]};
 reg [19:0] raw_hits;
 wire [2:0] rescue_count={2'd0,rsd[0]}+{2'd0,rsd[1]}+{2'd0,rsd[2]}+{2'd0,rsd[3]};
 reg [19:0] rescue_hits,completed_rescue_hits;
 reg chroma_seen,bright_seen,dense_seen;
 reg [19:0] completed_hits;reg completed_chroma,completed_bright;
 // Six qualification flags use physically unused coordinate MSBs in DIAG mode.
 // Overlay masks these bits; logical mailbox width and cadence stay unchanged.
 reg [11:0] x,y;
 reg active,bank,relaxed;
 reg [23:0] watchdog;
 wire sof=vd&&ud;
 wire [11:0] cx=sof?12'd0:x,cy=sof?12'd0:y;
 wire taking=vd&&(active||sof);
 wire [12:0] after_x={1'b0,cx}+(taking?13'd4:13'd0);
 wire eol=ld&&(active||sof);
 wire stripe_end=eol&&((cy % (1<<TILE_BITS))==((1<<TILE_BITS)-1)||cy==HEIGHT-1);
 reg [1:0] state;
 // Every stripe analysis consumes COLS+3 cycles, concurrently with next capture.
 // The two counter banks are individually cleared as the previous stripe scans.
 wire broken=fd||(sof&&active)||(vd&&!(active||sof))||
  (taking&&(cx>=WIDTH||cy>=HEIGHT))||(eol&&after_x!=WIDTH)||
  (stripe_end&&state!=0);
 wire timeout=(watchdog==WATCHDOG_CYCLES-1);
 wire abort_frame=broken||timeout;
 reg scan_bank,scan_first,scan_final;
 reg [6:0] scan_x,scan_row;
 reg [8:0] tiles0[0:COLS-1],tiles1[0:COLS-1];
 // One shared saturating incrementer per color, selected from the active bank.
 // Storage bank/write addresses, scan clearing and accepted-beat timing are unchanged.
 wire [8:0] capture_count=(cx<WIDTH)?(bank?tiles1[cx>>TILE_BITS]:tiles0[cx>>TILE_BITS]):9'd0;
 wire [9:0] capture_sum={1'b0,capture_count}+{7'd0,beat_count};
 wire [8:0] capture_next=(capture_sum>=TILE_CAP)?TILE_CAP:capture_sum[8:0];
 genvar t;
 generate for(t=0;t<COLS;t=t+1)begin: density
  wire hit=taking&&((cx>>TILE_BITS)==t);
  always @(posedge i_clk or negedge i_rst_n)begin
   if(!i_rst_n)begin tiles0[t]<=0;tiles1[t]<=0;end
   else if(abort_frame)begin tiles0[t]<=0;tiles1[t]<=0;end
   else begin
    if(state==1&&scan_x==t)begin
     if(scan_bank)tiles1[t]<=0;else tiles0[t]<=0;
    end
    // SOF clears only the new capture bank; prior frame analysis may still run.
    if(sof)begin
     if(bank)tiles1[t]<=hit?{6'd0,beat_count}:9'd0;
     else tiles0[t]<=hit?{6'd0,beat_count}:9'd0;
    end else if(hit)begin
     if(bank)tiles1[t]<=capture_next;
     else tiles0[t]<=capture_next;
    end
   end
  end
 end endgenerate
 reg [8:0] scan_value;
 always @* begin
  scan_value=0;
  if(scan_x<COLS)scan_value=scan_bank?tiles1[scan_x]:tiles0[scan_x];
 end
 reg scan_relaxed;
 wire dense=(scan_x<COLS)&&(scan_value>=(scan_relaxed?TILE_EXIT:TILE_ENTER));
 reg [6:0] run_left,strip_left,strip_right;
 reg [13:0] run_score,strip_score;
 reg [6:0] chain_left,chain_right,chain_top,chain_bottom,last_left,last_right;
 // 40 x 23 tiles x saturated256 = 235520 at 1280x720; 18 bits required.
 reg [17:0] chain_score,best_score;
 reg [6:0] best_left,best_right,best_top,best_bottom;
 reg [7:0] streak,misses,seq;
 reg present;

 wire joined=(chain_score!=0)&&(last_left<=(strip_right+7'd1))&&
  (strip_left<=(last_right+7'd1));
 wire [11:0] win_x0=(best_left<<TILE_BITS),win_x1=((best_right<<TILE_BITS)+((1<<TILE_BITS)-1));
 wire [11:0] win_y0=(best_top<<TILE_BITS);
 wire [11:0] raw_y1=((best_bottom<<TILE_BITS)+((1<<TILE_BITS)-1));
 wire [11:0] win_y1=(raw_y1>=HEIGHT)?HEIGHT-1:raw_y1;
 wire region_ok=(best_score>=MIN_PIXELS)&&((best_right-best_left+1)>=MIN_SPAN)&&((best_bottom-best_top+1)>=MIN_SPAN)&&(win_x1>=win_x0+MIN_WIDTH-1)&&(win_y1>=win_y0+MIN_HEIGHT-1);
 wire dimensions_ok=(best_score!=0)&&(win_x1>=win_x0+MIN_WIDTH-1)&&(win_y1>=win_y0+MIN_HEIGHT-1);
 // Red rescue diagnostic: O,E,N,T,S,D. Old160, extension used, new160,
 // dense tile, winning score160, winning dimensions. Label/box confirms present.
 wire [5:0] flags=(RED_RESCUE&&INDOOR_RED&&!BLUE)?
  {((completed_hits-completed_rescue_hits)>=MIN_PIXELS),(completed_rescue_hits!=0),(completed_hits>=MIN_PIXELS),dense_seen,(best_score>=MIN_PIXELS),dimensions_ok}:
  {completed_chroma,completed_bright,(completed_hits>=MIN_PIXELS),dense_seen,region_ok,(present||streak>=CONFIRM_FRAMES-1)&&region_ok};
 wire [47:0] flag_mask=DIAG?{flags[5],11'd0,flags[4],11'd0,flags[3:2],10'd0,flags[1:0],10'd0}:48'd0;

 // State 3 uses the winning closed chain after the state-2 nonblocking updates.
 always @(posedge i_clk or negedge i_rst_n)begin
  if(!i_rst_n)begin
   raw_hits<=0;rescue_hits<=0;completed_rescue_hits<=0;chroma_seen<=0;bright_seen<=0;dense_seen<=0;completed_hits<=0;completed_chroma<=0;completed_bright<=0;
   x<=0;y<=0;active<=0;bank<=0;relaxed<=0;watchdog<=0;state<=0;
   scan_bank<=0;scan_first<=0;scan_final<=0;scan_relaxed<=0;scan_x<=0;scan_row<=0;
   run_left<=0;run_score<=0;strip_left<=0;strip_right<=0;strip_score<=0;
   chain_left<=0;chain_right<=0;chain_top<=0;chain_bottom<=0;last_left<=0;last_right<=0;chain_score<=0;
   best_left<=0;best_right<=0;best_top<=0;best_bottom<=0;best_score<=0;
   streak<=0;misses<=0;seq<=0;present<=0;o_packet<=0;
  end else begin
   if(vd||ld)watchdog<=0;else if(watchdog<WATCHDOG_CYCLES)watchdog<=watchdog+1'b1;
   if(sof)begin raw_hits<=beat_count;chroma_seen<=|cd;bright_seen<=|rd;x<=0;y<=0;active<=1;relaxed<=present;end
   if(sof)rescue_hits<=rescue_count;
   else if(taking)rescue_hits<=rescue_hits+rescue_count;
   if(taking)begin x<=cx+12'd4;if(!sof)begin raw_hits<=raw_hits+beat_count;chroma_seen<=chroma_seen||(|cd);bright_seen<=bright_seen||(|rd);end end
   if(stripe_end&&cy<(1<<TILE_BITS))dense_seen<=0;
   if(state==1&&dense)dense_seen<=1;
   if(eol&&cy==HEIGHT-1)begin completed_hits<=raw_hits+(taking?beat_count:0);completed_chroma<=chroma_seen||(taking&&(|cd));completed_bright<=bright_seen||(taking&&(|rd));end
   if(eol&&cy==HEIGHT-1)completed_rescue_hits<=rescue_hits+(taking?rescue_count:0);
   if(eol)begin x<=0;if(cy==HEIGHT-1)begin y<=0;active<=0;end else y<=cy+1'b1;end
   if(stripe_end)begin
    bank<=!bank;scan_bank<=bank;scan_x<=0;scan_row<=(cy>>TILE_BITS);
    scan_first<=(cy<(1<<TILE_BITS));scan_final<=(cy==HEIGHT-1);
    scan_relaxed<=sof?present:relaxed;state<=1;
    run_score<=0;strip_score<=0;
    if(cy<(1<<TILE_BITS))begin chain_score<=0;best_score<=0;end
   end
   if(state==1)begin
    if(dense)begin
     if(run_score==0)run_left<=scan_x;
     run_score<=run_score+scan_value;
     if(run_score+scan_value>strip_score)begin
      strip_score<=run_score+scan_value;
      strip_left<=(run_score==0)?scan_x:run_left;strip_right<=scan_x;
     end
    end else run_score<=0;
    if(scan_x==COLS)state<=2;else scan_x<=scan_x+1'b1;
   end
   if(state==2)begin
    state<=scan_final?2'd3:2'd0;
    if(strip_score!=0)begin
     if(joined)begin
      chain_score<=chain_score+strip_score;last_left<=strip_left;last_right<=strip_right;chain_bottom<=scan_row;
      if(strip_left<chain_left)chain_left<=strip_left;
      if(strip_right>chain_right)chain_right<=strip_right;
      // Update best with the whole connected chain, including this strip.
      if(chain_score+strip_score>best_score)begin
       best_score<=chain_score+strip_score;best_top<=chain_top;best_bottom<=scan_row;
       best_left<=(strip_left<chain_left)?strip_left:chain_left;
       best_right<=(strip_right>chain_right)?strip_right:chain_right;
      end
     end else begin
      chain_score<=strip_score;chain_left<=strip_left;chain_right<=strip_right;
      last_left<=strip_left;last_right<=strip_right;chain_top<=scan_row;chain_bottom<=scan_row;
      if(strip_score>best_score)begin
       best_score<=strip_score;best_left<=strip_left;best_right<=strip_right;best_top<=scan_row;best_bottom<=scan_row;
      end
     end
    end else chain_score<=0;
   end
   if(state==3)begin
    state<=0;seq<=seq+1'b1;
    if(region_ok)begin
     misses<=0;
     if(streak<CONFIRM_FRAMES)streak<=streak+1'b1;
     if(present||streak>=CONFIRM_FRAMES-1)begin
      present<=1;o_packet<={seq+8'd1,1'b1,({win_x0,win_x1,win_y0,win_y1}|flag_mask)};
     end else o_packet<={seq+8'd1,1'b0,flag_mask};
    end else begin
     streak<=0;
     if(present&&misses<EXIT_FRAMES-1)begin
      misses<=misses+1'b1;o_packet<={seq+8'd1,1'b1,((o_packet[47:0]&48'h7ff7ff3ff3ff)|flag_mask)};
     end else begin misses<=0;present<=0;o_packet<={seq+8'd1,1'b0,flag_mask};end
    end
   end
   if(abort_frame)begin
    x<=0;y<=0;active<=0;state<=0;streak<=0;misses<=0;present<=0;chain_score<=0;best_score<=0;
    seq<=seq+1'b1;o_packet<={seq+8'd1,49'd0};raw_hits<=0;rescue_hits<=0;completed_rescue_hits<=0;chroma_seen<=0;bright_seen<=0;dense_seen<=0;completed_hits<=0;completed_chroma<=0;completed_bright<=0;
   end
  end
 end
endmodule
