`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lbr
// Aurora AXI-Stream 64-bit 发送组包（按行）
// 增加内置 AXI-Stream FIFO 彻底解决 BRAM 潜伏期与反压冲突造成的拖尾问题
//////////////////////////////////////////////////////////////////////////////////

module aurora_tx
(
    input               I_clk,          // 未用
    input               I_rst_n,
    input               I_sim_data_en,
    input               I_data_en,
    input               I_sample_rdy,
    input   [63:0]      I_sample_data,
    //辅助数据
    input   [15:0]      I_image_mode,    // 成像模式
    input   [15:0]      I_integ_time,    // 积分时间(单位0.2µs)
    input   [15:0]      I_frame_period,  // 成像周期 (单位10µs)
    input   [15:0]      I_gain,          // 曝光增益
    input   [15:0]      I_fpa_temp,      // 焦平面温度
    input   [15:0]      I_temp_point1,   // 测温点1

    output  reg         O_rd_finish,
    output  reg         O_HTS_TDIS,

    output  reg [9:0]   last_line_addr,
    output  reg [9:0]   O_addr_rd1,
	output  reg [9:0]   O_addr_rd2,
	output  reg [9:0]   O_addr_rd3,

    input               aurora_init,
    input               axis_clk,
    
    // 注意：这里改为了 wire，因为驱动源变成了内部的 FIFO
    output  wire        axis_tvalid,
    (*mark_debug = "true"*) output wire [63:0] axis_tdata,
    output  wire [7:0]  axis_tkeep,
    output  wire        axis_tlast,
    input               axis_tready
);

localparam integer ROW           = 513;   // 行号 0..512；当 cnt_row==ROW 表示帧结束
localparam integer PAYLOAD_BEATS = 160;   

localparam integer LINE_GAP_CLKS  = 7;
localparam integer FRAME_GAP_CLKS = 3;

//============================================================
// reset sync to axis_clk
//============================================================
wire I_rst_n_r;
data_sync u1_data_sync(
    .clk        (axis_clk),
    .pre_data   (I_rst_n),
    .post_data  (I_rst_n_r)
);

//============================================================
// sync I_data_en / I_sample_rdy into axis_clk
//============================================================
reg [1:0] sample_rdy_sample;
reg [1:0] sample_data_en;

always @(posedge axis_clk) begin
    if(!I_rst_n_r) begin
        sample_rdy_sample <= 2'b00;
        sample_data_en    <= 2'b00;
    end else begin
        sample_rdy_sample[0] <= I_sample_rdy;
        sample_rdy_sample[1] <= sample_rdy_sample[0];

        sample_data_en[0] <= I_data_en;
        sample_data_en[1] <= sample_data_en[0];
    end
end

wire data_en_rise  = (sample_data_en == 2'b01);
wire line_ready_ok = (sample_rdy_sample == 2'b11);

//============================================================
// FSM
//============================================================
localparam [3:0]
    S_IDLE      = 4'd0,
    S_LINE_WAIT = 4'd1,
    S_HEAD0     = 4'd2,
    S_HEAD1     = 4'd3,
    S_PAYLOAD   = 4'd4,
    S_TAIL      = 4'd5,
    S_LINE_GAP  = 4'd6,
    S_FRAME_GAP = 4'd7;

(*mark_debug = "TRUE" *)reg [3:0]  send_fsm;

reg [15:0] cnt_row;
reg [7:0]  payload_beat_cnt;   // 0..159
reg [7:0]  line_gap_cnt;
reg [7:0]  frame_gap_cnt;

reg [31:0] real_frame_num;
reg [15:0] data_sim;

//============================================================
// 协议字段
//============================================================
localparam [7:0]  DEV_ID  = 8'h07;
localparam [15:0] PKT_LEN = 16'd1304;   // 总共的字节数

wire [7:0] pkt_type = (cnt_row==16'd0) ? 8'hAA : 8'h55;

// 7个 16bit header words
wire [15:0] h0 = 16'hFDFD;
wire [15:0] h1 = 16'h7F7F;
wire [15:0] h2 = 16'h7F7F;
wire [15:0] h3 = PKT_LEN;
wire [15:0] h4 = {pkt_type, DEV_ID};
wire [15:0] h5 = real_frame_num[15:0];
wire [15:0] h6 = cnt_row[15:0];

//============================================================
// 仿真64bit数据（每beat递增）
//============================================================
wire [15:0] sim0 = data_sim;
wire [15:0] sim1 = data_sim + 16'd1;
wire [15:0] sim2 = data_sim + 16'd2;
wire [15:0] sim3 = data_sim + 16'd3;
wire [63:0] sim64 = {sim0, sim1, sim2, sim3};

//============================================================
// 内部 FIFO 连线与 Fire 逻辑
//============================================================
wire        fsm_tvalid;
wire        fsm_tready;
wire [63:0] fsm_tdata;
wire [7:0]  fsm_tkeep;
wire        fsm_tlast;

// 现在状态机的推进由内部 FIFO 的 tready 决定，而不是外部的 axis_tready
wire fire = fsm_tvalid && fsm_tready; 

//============================================================
// 组合输出：当前beat的 tdata / tkeep / tlast
//============================================================
(*mark_debug = "TRUE" *)wire sending_state = (send_fsm==S_HEAD0) || (send_fsm==S_HEAD1) ||
                     (send_fsm==S_PAYLOAD) || (send_fsm==S_TAIL);

(*mark_debug = "TRUE" *)reg [63:0] cur_beat;
reg [7:0]  cur_keep;
reg        cur_last;

always @(*) begin
    cur_beat = 64'd0;
    cur_keep = 8'h00;
    cur_last = 1'b0;

    case(send_fsm)
        // Header beat0
        S_HEAD0: begin
            cur_beat = {h0, h1, h2, h5};
            cur_keep = 8'hFF;
            cur_last = 1'b0;
        end
        // Header beat1
        S_HEAD1: begin
            cur_beat = {h6,h3,h4,16'h0000};
            cur_keep = 8'hFF;   
            cur_last = 1'b0;
        end

        // Payload 160 beats
        S_PAYLOAD: begin
            if(cnt_row == 16'd0) begin
                //辅助行
                case(payload_beat_cnt)
                    8'd0:    cur_beat = {I_image_mode,I_integ_time,I_frame_period,I_gain};
                    8'd1:    cur_beat = {I_fpa_temp, I_temp_point1, 16'd0, 16'd0};
                default: cur_beat = 64'hA5A5A5A5A5A5A5A5;
                endcase
            end else begin
                // 【核心改动】：因为有内置 FIFO 吸收停顿，BRAM时序完美匹配2拍延迟
                // 直接将 BRAM 的实时输出拉给总线，抛弃所有手写的 data_pipe_reg 防滑逻辑
                cur_beat = (I_sim_data_en) ? sim64 : I_sample_data;
            end
            cur_keep = 8'hFF;
            cur_last = 1'b0;
        end

        // Tail 1 beat
        S_TAIL: begin
            cur_beat = {16'hFBFB,16'hFBFB,16'hFBFB,16'hFBFB};
            cur_keep = 8'hFF;
            cur_last = 1'b1;     // 行结束
        end

        default: begin
            cur_beat = 64'd0;
            cur_keep = 8'h00;
            cur_last = 1'b0;
        end
    endcase
end

// 将状态机产生的数据分配给写入 FIFO 的端线
assign fsm_tvalid = aurora_init && sending_state;
assign fsm_tdata  = cur_beat;
assign fsm_tkeep  = cur_keep;
assign fsm_tlast  = cur_last;


(*mark_debug = "TRUE" *)reg frame_req_latched;
// 只要拿到触发，就锁存起来
always @(posedge axis_clk) begin
    if (!I_rst_n_r)
        frame_req_latched <= 1'b0;
    else if (data_en_rise)
        frame_req_latched <= 1'b1;
    else if (send_fsm == S_LINE_WAIT) // 响应后清除
        frame_req_latched <= 1'b0;
end

//============================================================
// 主时序：只在 fire 时推进
//============================================================
always @(posedge axis_clk) begin
    if(!I_rst_n_r) begin
        send_fsm         <= S_IDLE;
        cnt_row          <= 16'd0;
        payload_beat_cnt <= 8'd0;
        
        O_addr_rd1 <= 0;
		O_addr_rd2 <= 0;
		O_addr_rd3 <= 1;
        last_line_addr <= 0;
        O_rd_finish      <= 1'b0;

        line_gap_cnt     <= 8'd0;
        frame_gap_cnt    <= 8'd0;

        real_frame_num   <= 32'd0;
        data_sim         <= 16'd0;
        O_HTS_TDIS       <= 1'd1;
    end else begin
        O_HTS_TDIS       <= 1'd0;

        case(send_fsm)
            // 等待帧开始
            S_IDLE: begin
                if(aurora_init && frame_req_latched) begin
                    cnt_row          <= 16'd0;
                    payload_beat_cnt <= 8'd0;
                    
                    O_addr_rd1 <= 0;
                    O_addr_rd2 <= 0;
                    O_addr_rd3 <= 1;
                    last_line_addr <= 0;
                    data_sim         <= 16'd0;
                    send_fsm         <= S_LINE_WAIT;
                end
            end

            // 等待行开始（0行不等 rdy，其余行等 line_ready_ok）
            S_LINE_WAIT: begin
                if(cnt_row == ROW) begin
                    frame_gap_cnt  <= 8'd0;
                    real_frame_num <= real_frame_num + 1'b1;
                    send_fsm       <= S_FRAME_GAP;
                end else begin
                    if(cnt_row == 16'd0) begin
                        payload_beat_cnt <= 8'd0;
                        O_addr_rd1 <= 0;
                        O_addr_rd2 <= 0;
                        O_addr_rd3 <= 1;
                        last_line_addr <= 0;
                        send_fsm         <= S_HEAD0;
                    end else if(line_ready_ok || I_sim_data_en) begin
                        payload_beat_cnt <= 8'd0;
                        O_addr_rd1 <= 0;
                        O_addr_rd2 <= 0;
                        O_addr_rd3 <= 1;
                        last_line_addr <= 0;
                        data_sim         <= 16'd0;
                        send_fsm         <= S_HEAD0;
                    end
                end
            end

            // header beat0
            S_HEAD0: begin
                if(fire) begin
                    if(cnt_row != 16'd0) begin
                        last_line_addr <= 10'd1;
                        O_addr_rd1 <= 10'd0;
					    O_addr_rd2 <= 10'd1;
					    O_addr_rd3 <= 10'd2;
                    end
                    send_fsm <= S_HEAD1;
                end
            end

            // header beat1
            S_HEAD1: begin
                if(fire) begin
                    payload_beat_cnt <= 8'd0;
                    if(cnt_row != 16'd0) begin
                        last_line_addr <= 10'd2;
                        O_addr_rd1 <= 10'd1;
					    O_addr_rd2 <= 10'd2;
					    O_addr_rd3 <= 10'd3;
                    end
                    send_fsm         <= S_PAYLOAD;
                end
            end

            // payload 160 beats
            S_PAYLOAD: begin
                if(fire) begin
                    // 图像行才推进读地址/仿真数据
                    if(cnt_row != 16'd0) begin
                        last_line_addr <= last_line_addr + 1'b1;
                        O_addr_rd1 <= O_addr_rd1 + 1;
						O_addr_rd2 <= O_addr_rd2 + 1;
						O_addr_rd3 <= O_addr_rd3 + 1;
                        
                        if(I_sim_data_en)
                            data_sim <= data_sim + 16'd4;
                    end

                    if(payload_beat_cnt == (PAYLOAD_BEATS-1)) begin
                        payload_beat_cnt <= 8'd0;
                        send_fsm         <= S_TAIL;
                    end else begin
                        payload_beat_cnt <= payload_beat_cnt + 1'b1;
                    end
                end
            end

            // tail 1 beat
            S_TAIL: begin
                if(fire) begin
                    O_rd_finish  <= 1'b1;
                    line_gap_cnt <= 8'd0;
                    send_fsm     <= S_LINE_GAP;
                end
            end

            // 行间隔
            S_LINE_GAP: begin
                if(line_gap_cnt == (LINE_GAP_CLKS-1)) begin
                    line_gap_cnt <= 8'd0;
                    cnt_row      <= cnt_row + 1'b1;
                    send_fsm     <= S_LINE_WAIT;
                    O_rd_finish <= 1'b0; // 默认拉低
                end else begin
                    line_gap_cnt <= line_gap_cnt + 1'b1;
                end
            end

            // 帧间隔
            S_FRAME_GAP: begin
                if(frame_gap_cnt == (FRAME_GAP_CLKS-1)) begin
                    frame_gap_cnt <= 8'd0;
                    send_fsm      <= S_IDLE;
                end else begin
                    frame_gap_cnt <= frame_gap_cnt + 1'b1;
                end
            end

            default: send_fsm <= S_IDLE;
        endcase
    end
end

//============================================================
// 实例化原生 AXI-Stream FIFO 作为防滑/反压缓冲池
//============================================================
axis_data_fifo_tx u_tx_buffer (
    .s_axis_aresetn (I_rst_n_r),      // 同步复位
    .s_axis_aclk    (axis_clk),       // 发送端时钟
    .s_axis_tvalid  (fsm_tvalid),     // 状态机产生的 valid
    .s_axis_tready  (fsm_tready),     // FIFO 反馈给状态机的 ready
    .s_axis_tdata   (fsm_tdata),      // 状态机产生的数据
    .s_axis_tkeep   (fsm_tkeep),
    .s_axis_tlast   (fsm_tlast),

    // .m_axis_aclk    (axis_clk),       // 接收端时钟 (这里是同频同相)
    .m_axis_tvalid  (axis_tvalid),    // 直连外部的 Aurora 发送管脚
    .m_axis_tready  (axis_tready),    // 接收外部 Aurora 的反压信号
    .m_axis_tdata   (axis_tdata),
    .m_axis_tkeep   (axis_tkeep),
    .m_axis_tlast   (axis_tlast)
);

endmodule