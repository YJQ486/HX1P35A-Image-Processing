// Bundled-data mailbox. Source holds every bit until round-trip acknowledgement.
// Common epoch reset prevents stale toggles when the video domain restarts.
module custom_diag_snapshot_cdc #(parameter integer WIDTH=468) (
    input i_src_clk, input i_dst_clk, input i_epoch_n,
    input [WIDTH-1:0] i_status,
    output reg [WIDTH-1:0] o_status
);
    // Two capture stages, then a timed distribution stage. The third stage
    // may be replicated; first Q must still feed a single second-stage D.
    reg [2:0] src_release,dst_release;
    reg [WIDTH-1:0] held_data,capture_data;
    reg request_toggle,ack_toggle;
    reg ack_meta,ack_sync,req_meta,req_sync;
    reg [1:0] dst_phase;
    always @(posedge i_src_clk or negedge i_epoch_n)
        if(!i_epoch_n)src_release<=0;else src_release<={src_release[1:0],1'b1};
    always @(posedge i_dst_clk or negedge i_epoch_n)
        if(!i_epoch_n)dst_release<=0;else dst_release<={dst_release[1:0],1'b1};
    always @(posedge i_src_clk or negedge src_release[2]) begin
        if(!src_release[2]) begin
            held_data<=0;request_toggle<=0;ack_meta<=0;ack_sync<=0;
        end else begin
            ack_meta<=ack_toggle;ack_sync<=ack_meta;
            if(ack_sync==request_toggle && i_status!=held_data)begin
                held_data<=i_status;request_toggle<=!request_toggle;
            end
        end
    end
    always @(posedge i_dst_clk or negedge dst_release[2]) begin
        if(!dst_release[2])begin
            req_meta<=0;req_sync<=0;dst_phase<=0;capture_data<=0;o_status<=0;ack_toggle<=0;
        end else begin
            req_meta<=request_toggle;req_sync<=req_meta;
            case(dst_phase)
                0:if(req_sync!=ack_toggle)dst_phase<=1;
                1:begin capture_data<=held_data;dst_phase<=2;end
                2:begin o_status<=capture_data;ack_toggle<=req_sync;dst_phase<=0;end
                default:dst_phase<=0;
            endcase
        end
    end
endmodule
