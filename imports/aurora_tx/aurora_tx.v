`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Deng Yukun
// 
// Create Date: 2026/01/01 15:52:12
// Design Name: 
// Module Name: aurora_tx
// Project Name: GXYTH_LWIR
// Target Devices: lwir 640*512
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module aurora_tx
(
    // ===================== 时钟与复位 =====================
    input                           I_clk               , // 未用
    input                           I_rst_n             , // 复位信号(低电平有效)
    input                           I_sim_data_en       , // 仿真数据使能
    input                           I_data_en           , // 数据使能
    input                           I_sample_rdy        , // 采样数据就绪信号
    input                   [63:0]  I_sample_data       , // 采样数据
    input                           I_driver_en         , // 开始成像信号
    // ===================== 辅助数据(图像参数/导航数据) =====================
    input                   [15:0]  I_image_mode        , // 成像模式
    input                   [15:0]  I_integ_time        , // 积分时间(单位0.2µs)
    input                   [15:0]  I_frame_period      , // 成像周期 (单位10µs)
    input                   [15:0]  I_gain              , // 曝光增益
    input                   [15:0]  I_fpa_temp          , // 焦平面温度
    input                   [15:0]  I_temp_point1       , // 测温点1
    input                   [63:0]  I_loc_time          , // 系统时间
    input                   [535:0] I_mid_navigation_data, // 中导航数据
    input                   [535:0] I_high_navigation_data, // 高导航数据
    input                   [535:0] I_high_satellite_data, // 高卫星数据

    // ===================== 输出控制与地址 =====================
    output  reg                     O_rd_finish         , // 读取完成标志
    output  reg                     O_HTS_TDIS          , // 热像仪使能信号
    output  reg                     O_gtx_wr_en         , // GTX写使能
    output  reg             [9:0]   last_line_addr      , // 上一行地址
    output  reg             [9:0]   O_addr_rd1          , // 读取地址1
    output  reg             [9:0]   O_addr_rd2          , // 读取地址2
    output  reg             [9:0]   O_addr_rd3          , // 读取地址3
    output  wire            [15:0]  O_read_row          , // 当前读取行号

    // ===================== Aurora/AXI Stream 接口 =====================
    input                           aurora_init         , // Aurora初始化完成
    input                           axis_clk            , // AXI Stream 时钟
    output  reg                     axis_tvalid         , // AXI Stream 有效信号
    (*mark_debug = "TRUE" *)output  reg             [63:0]  axis_tdata          , // AXI Stream 数据
    output  reg             [7:0]   axis_tkeep          , // AXI Stream 字节有效掩码
    output  reg                     axis_tlast          , // AXI Stream 帧结束标志
    input                           axis_tready           // AXI Stream 从机就绪
);

    // ===================== 参数定义 =====================
    localparam integer ROW           = 513;   // 行号 0..512；当 cnt_row==ROW 表示帧结束
    localparam integer PAYLOAD_BEATS = 160;   // 每行有效负载的 beats 数
    localparam integer LINE_GAP_CLKS = 7;     // 行间隔时钟周期数
    localparam integer FRAME_GAP_CLKS = 3;    // 帧间隔时钟周期数

    // ===================== 内部信号定义 =====================
    // 复位同步
    wire                            I_rst_n_r           ; // 同步到 axis_clk 域的复位信号

    // 同步打拍信号
    reg                     [1:0]   sample_rdy_sample   ; // 采样就绪信号同步
    reg                     [1:0]   sample_data_en      ; // 数据使能信号同步

    // 状态机
    (*mark_debug = "TRUE"*) reg     [3:0]   send_fsm    ; // 发送状态机

    // 计数与数据
    reg                     [15:0]  cnt_row             ; // 当前行计数
    reg                     [7:0]   payload_beat_cnt    ; // 有效负载 beat 计数(0~159)
    reg                     [7:0]   line_gap_cnt        ; // 行间隔计数
    reg                     [7:0]   frame_gap_cnt       ; // 帧间隔计数
    reg                     [31:0]  real_frame_num      ; // 实际帧号
    reg                     [15:0]  data_sim            ; // 仿真数据累加器

    // 流水线与防滑缓冲(Skid Buffer)
    (*mark_debug = "TRUE"*) reg     [63:0]  data_pipe_reg; // 正常流水线寄存器
    (*mark_debug = "TRUE"*) reg     [63:0]  skid_reg    ; // 背压时暂存数据
    (*mark_debug = "TRUE"*) reg             use_skid    ; // 是否正在使用 skid_reg

    // 组合逻辑中间变量
    (*mark_debug = "TRUE"*) wire            sending_state; // 是否处于发送状态
    (*mark_debug = "TRUE"*) reg     [63:0]  cur_beat    ; // 当前 beat 数据
    reg                     [7:0]   cur_keep            ; // 当前 beat 字节有效掩码
    reg                             cur_last            ; // 当前 beat 是否结束

    (*mark_debug = "TRUE"*) reg             frame_req_latched; // 帧请求锁存信号

    // ===================== 赋值与连线 =====================
    assign O_read_row = cnt_row;
    assign fire = axis_tvalid && axis_tready; // 握手成功条件

    // ===================== 复位同步到 axis_clk =====================
    data_sync u1_data_sync (
        .clk        (axis_clk),
        .pre_data   (I_rst_n),
        .post_data  (I_rst_n_r)
    );

    // ===================== 同步 I_data_en / I_sample_rdy =====================
    always @(posedge axis_clk) begin
        if(!I_rst_n_r) begin
            sample_rdy_sample <= 2'b00;
            sample_data_en    <= 2'b00;
        end else begin
            sample_rdy_sample[0] <= I_sample_rdy;          // 打拍采样就绪信号
            sample_rdy_sample[1] <= sample_rdy_sample[0];  // 同步到 axis_clk

            sample_data_en[0] <= I_data_en;                // 打拍数据使能信号
            sample_data_en[1] <= sample_data_en[0];        // 同步到 axis_clk
        end
    end

    // 数据使能上升沿检测(仿真模式时恒为1)
    wire data_en_rise  = I_sim_data_en ? I_driver_en : (sample_data_en == 2'b01);
    // 行数据就绪判断(仿真模式时直接有效)
    wire line_ready_ok = (sample_rdy_sample == 2'b11);

    // ===================== 状态机定义 =====================
    localparam [3:0]
        S_IDLE      = 4'd0, // 空闲，等待帧触发
        S_LINE_WAIT = 4'd1, // 等待行有效信号
        S_HEAD0     = 4'd2, // 发送协议头 beat0
        S_HEAD1     = 4'd3, // 发送协议头 beat1
        S_PAYLOAD   = 4'd4, // 发送图像有效负载
        S_TAIL      = 4'd5, // 发送行尾标识
        S_LINE_GAP  = 4'd6, // 行间隔等待
        S_FRAME_GAP = 4'd7; // 帧间隔等待

// ===================== 协议字段定义 =====================
    localparam [7:0]  DEV_ID  = 8'h07;                       // 设备ID
    localparam [15:0] PKT_LEN = 16'd1304;                   // 总字节长度(160*8 + 头部7*2 + 尾部2 = 1304)

    wire [7:0] pkt_type = (cnt_row == 16'd0) ? 8'hAA : 8'h55; // 首行标记0xAA，其余行0x55

    // 7个16bit头部字段
    wire [15:0] h0 = 16'hFDFD;                               // 帧头标识1
    wire [15:0] h1 = 16'h7F7F;                               // 帧头标识2
    wire [15:0] h2 = 16'h7F7F;                               // 帧头标识3
    wire [15:0] h3 = PKT_LEN;                                // 包长度
    wire [15:0] h4 = {pkt_type, DEV_ID};                     // 包类型 + 设备ID
    wire [15:0] h5 = real_frame_num[15:0];                   // 帧号低16位
    wire [15:0] h6 = cnt_row[15:0];                          // 当前行号

    // ===================== 仿真数据生成 =====================
    wire [15:0] sim0 = data_sim;
    wire [15:0] sim1 = data_sim + 16'd1;
    wire [15:0] sim2 = data_sim + 16'd2;
    wire [15:0] sim3 = data_sim + 16'd3;
    wire [63:0] sim64 = {sim0, sim1, sim2, sim3};           // 每beat递增4个16bit数据

    // ===================== BRAM Skid Buffer (防滑缓冲器) =====================
    // 核心功能：当 axis_tready 为低(反压)时，由于 BRAM 读取无法暂停，
    // 必须用 skid_reg 暂存当前拍 BRAM 吐出的数据，防止数据丢失。
    always @(posedge axis_clk) begin
        if (!I_rst_n_r) begin
            data_pipe_reg <= 64'd0;
            skid_reg      <= 64'd0;
            use_skid      <= 1'b0;
        end else begin
            // 仅在发送头 beat1 和有效负载阶段需要从 BRAM 取数
            if (send_fsm == S_HEAD1 || send_fsm == S_PAYLOAD) begin
                if (fire) begin
                    // 握手成功，将数据推向下游
                    if (use_skid) begin
                        // 优先使用缓冲器中的存货
                        data_pipe_reg <= skid_reg;
                        use_skid      <= 1'b0;
                    end else begin
                        // 正常从 BRAM 取数
                        data_pipe_reg <= I_sample_data;
                    end
                end else begin
                    // 遇到反压，且当前未使用缓冲器，则暂存当前拍 BRAM 吐出的数据
                    if (!use_skid && cnt_row != 16'd0) begin
                        skid_reg <= I_sample_data;
                        use_skid <= 1'b1;
                    end
                end
            end else if (send_fsm == S_IDLE || send_fsm == S_LINE_WAIT) begin
                // 空闲或等待行时，清空缓冲标记
                use_skid <= 1'b0;
            end
        end
    end

    // ===================== 组合逻辑输出：当前 beat 数据 =====================
    assign sending_state = (send_fsm == S_HEAD0) || (send_fsm == S_HEAD1) ||
                           (send_fsm == S_PAYLOAD) || (send_fsm == S_TAIL);

    always @(*) begin
        cur_beat = 64'd0;
        cur_keep = 8'h00;
        cur_last = 1'b0;

        case (send_fsm)
            // 头部 beat0：4个16bit头部字段 (8字节全有效)
            S_HEAD0: begin
                cur_beat = {h0, h1, h2, h5};
                cur_keep = 8'hFF;
                cur_last = 1'b0;
            end
            // 头部 beat1：3个16bit头部字段 + 1字节填充 (共7字节有效)
            S_HEAD1: begin
                cur_beat = {h6, h3, h4, 16'h0000};
                cur_keep = 8'hFF;   // 实际有效7字节，但此处按全8字节发送
                cur_last = 1'b0;
            end

            // 有效负载：160 beats
            S_PAYLOAD: begin
                if (cnt_row == 16'd0) begin
                    // 第0行为辅助数据行
                    case (payload_beat_cnt)
                        8'd0:  cur_beat = {I_image_mode, I_integ_time, I_frame_period, I_gain};
                        8'd1:  cur_beat = {I_fpa_temp, I_temp_point1, 16'd513, 16'd0};
                        8'd2:  cur_beat = {16'd0, I_loc_time[63:16]}; // 字节16-23
                        8'd3:  cur_beat = {I_loc_time[15:0], 8'h01, I_mid_navigation_data[535:496]}; // 字节16-23
                        8'd4:  cur_beat = I_mid_navigation_data[495:432];
                        8'd5:  cur_beat = I_mid_navigation_data[431:368];
                        8'd6:  cur_beat = I_mid_navigation_data[367:304];
                        8'd7:  cur_beat = I_mid_navigation_data[303:240];
                        8'd8:  cur_beat = I_mid_navigation_data[239:176];
                        8'd9:  cur_beat = I_mid_navigation_data[175:112];
                        8'd10: cur_beat = I_mid_navigation_data[111:48];
                        8'd11: cur_beat = {I_mid_navigation_data[47:0], 8'h02, I_high_navigation_data[535:528]};
                        8'd12: cur_beat = I_high_navigation_data[527:464];
                        8'd13: cur_beat = I_high_navigation_data[463:400];
                        8'd14: cur_beat = I_high_navigation_data[399:336];
                        8'd15: cur_beat = I_high_navigation_data[335:272];
                        8'd16: cur_beat = I_high_navigation_data[271:208];
                        8'd17: cur_beat = I_high_navigation_data[207:144];
                        8'd18: cur_beat = I_high_navigation_data[143:80];
                        8'd19: cur_beat = I_high_navigation_data[79:16];
                        8'd20: cur_beat = {I_high_navigation_data[15:0], 8'h03, I_high_satellite_data[535:496]};
                        8'd21: cur_beat = I_high_satellite_data[495:432];
                        8'd22: cur_beat = I_high_satellite_data[431:368];
                        8'd23: cur_beat = I_high_satellite_data[367:304];
                        8'd24: cur_beat = I_high_satellite_data[303:240];
                        8'd25: cur_beat = I_high_satellite_data[239:176];
                        8'd26: cur_beat = I_high_satellite_data[175:112];
                        8'd27: cur_beat = I_high_satellite_data[111:48];
                        8'd28: cur_beat = {I_mid_navigation_data[47:0], 16'hA5A5};
                        default: cur_beat = 64'hA5A5A5A5A5A5A5A5; // 其他 beat 填充固定数据
                    endcase
                end else begin
                    // 图像行数据
                    cur_beat = (I_sim_data_en) ? sim64 : data_pipe_reg;
                end
                cur_keep = 8'hFF;
                cur_last = 1'b0;
            end

            // 尾部 beat：发送 4 个 16'hFBFB，表示帧结束
            S_TAIL: begin
                cur_beat = {16'hFBFB, 16'hFBFB, 16'hFBFB, 16'hFBFB};
                cur_keep = 8'hFF;
                cur_last = 1'b1;     // 标记行结束
            end

            default: begin
                cur_beat = 64'd0;
                cur_keep = 8'h00;
                cur_last = 1'b0;
            end
        endcase
    end

    // 驱动 AXI Stream 输出端口
    always @(*) begin
        axis_tvalid = aurora_init && sending_state;
        axis_tdata  = cur_beat;
        axis_tkeep  = cur_keep;
        axis_tlast  = cur_last;
    end


    // ===================== 帧请求锁存 =====================
    // 只要检测到数据使能上升沿，就锁存帧请求，直到状态机响应后清除
    always @(posedge axis_clk) begin
        if (!I_rst_n_r)
            frame_req_latched <= 1'b0;
        else if (data_en_rise)
            frame_req_latched <= 1'b1;
        else if (send_fsm == S_LINE_WAIT) // 状态机进入等待行状态，表示已响应
            frame_req_latched <= 1'b0;
    end
    
    // ===================== 主发送状态机 =====================
    // 仅在 fire (axis_tvalid && axis_tready) 条件下推进状态
    always @(posedge axis_clk) begin
        if (!I_rst_n_r) begin
            send_fsm         <= S_IDLE;
            cnt_row          <= 16'd0;
            payload_beat_cnt <= 8'd0;
            O_addr_rd1       <= 10'd0;
            O_addr_rd2       <= 10'd0;
            O_addr_rd3       <= 10'd1;
            last_line_addr   <= 10'd0;
            O_rd_finish      <= 1'b0;
            line_gap_cnt     <= 8'd0;
            frame_gap_cnt    <= 8'd0;
            real_frame_num   <= 32'd0;
            data_sim         <= 16'd0;
            O_HTS_TDIS       <= 1'd1;
            O_gtx_wr_en      <= 1'b0;
        end else begin
            O_HTS_TDIS <= 1'd0; // 正常工作时拉低，表示热像仪数据有效

            case (send_fsm)
            // ===== 空闲状态：等待帧触发 =====
                S_IDLE: begin
                    if (aurora_init && frame_req_latched) begin
                        cnt_row          <= 16'd0;
                        payload_beat_cnt <= 8'd0;
                        O_addr_rd1       <= 10'd0;
                        O_addr_rd2       <= 10'd0;
                        O_addr_rd3       <= 10'd1;
                        last_line_addr   <= 10'd0;
                        data_sim         <= 16'd0;
                        O_gtx_wr_en      <= 1'b1;      // 开启GTX写使能
                        send_fsm         <= S_LINE_WAIT;
                    end
                end
            
                // ===== 等待行信号：第0行不等待 rdy，其余行等待 line_ready_ok =====
                S_LINE_WAIT: begin
                    if (cnt_row == ROW) begin
                        // 所有行发送完毕，进入帧间隔
                        frame_gap_cnt  <= 8'd0;
                        real_frame_num <= real_frame_num + 1'b1;
                        send_fsm       <= S_FRAME_GAP;
                    end else begin
                        if (cnt_row == 16'd0) begin
                            // 第0行（辅助行）无需等待数据就绪，直接发送
                            payload_beat_cnt <= 8'd0;
                            O_addr_rd1       <= 10'd0;
                            O_addr_rd2       <= 10'd0;
                            O_addr_rd3       <= 10'd1;
                            last_line_addr   <= 10'd0;
                            send_fsm         <= S_HEAD0;
                        end else if (line_ready_ok || I_sim_data_en) begin
                            // 图像行：等待采样数据就绪或仿真模式直接开始
                            payload_beat_cnt <= 8'd0;
                            O_addr_rd1       <= 10'd0;
                            O_addr_rd2       <= 10'd0;
                            O_addr_rd3       <= 10'd1;
                            last_line_addr   <= 10'd0;
                            data_sim         <= 16'd0;
                            send_fsm         <= S_HEAD0;
                        end
                    end
                end
            
                // ===== 发送头部 beat0 =====
                S_HEAD0: begin
                    if (fire) begin
                        if (cnt_row != 16'd0) begin
                            // 图像行：预取下一拍地址
                            last_line_addr <= 10'd1;
                            O_addr_rd1     <= 10'd0;
                            O_addr_rd2     <= 10'd1;
                            O_addr_rd3     <= 10'd2;
                        end
                        send_fsm <= S_HEAD1;
                    end
                end
            
                // ===== 发送头部 beat1 =====
                S_HEAD1: begin
                    if (fire) begin
                        payload_beat_cnt <= 8'd0;
                        O_gtx_wr_en      <= 1'b0;       // 关闭GTX写使能
                        if (cnt_row != 16'd0) begin
                            // 图像行：预取后续地址
                            last_line_addr <= 10'd2;
                            O_addr_rd1     <= 10'd1;
                            O_addr_rd2     <= 10'd2;
                            O_addr_rd3     <= 10'd3;
                        end
                        send_fsm <= S_PAYLOAD;
                    end
                end
            
                // ===== 发送有效负载 160 beats =====
                S_PAYLOAD: begin
                    if (fire) begin
                        // 图像行：每个 beat 推进一次地址
                        if (cnt_row != 16'd0) begin
                            last_line_addr <= last_line_addr + 1'b1;
                            O_addr_rd1     <= O_addr_rd1 + 1;
                            O_addr_rd2     <= O_addr_rd2 + 1;
                            O_addr_rd3     <= O_addr_rd3 + 1;
                            if (I_sim_data_en)
                                data_sim <= data_sim + 16'd4; // 仿真数据累加
                        end

                        if (payload_beat_cnt == (PAYLOAD_BEATS - 1)) begin
                            payload_beat_cnt <= 8'd0;
                            send_fsm         <= S_TAIL;
                        end else begin
                            payload_beat_cnt <= payload_beat_cnt + 1'b1;
                        end
                    end
                end
            
                // ===== 发送尾部 beat =====
                S_TAIL: begin
                    if (fire) begin
                        O_rd_finish  <= 1'b1;     // 产生行读取完成脉冲
                        line_gap_cnt <= 8'd0;
                        send_fsm     <= S_LINE_GAP;
                    end
                end
            
                // ===== 行间隔等待 =====
                S_LINE_GAP: begin
                    if (line_gap_cnt == (LINE_GAP_CLKS - 1)) begin
                        line_gap_cnt <= 8'd0;
                        cnt_row      <= cnt_row + 1'b1;
                        send_fsm     <= S_LINE_WAIT;
                        O_rd_finish  <= 1'b0;      // 清除读取完成标志
                    end else begin
                        line_gap_cnt <= line_gap_cnt + 1'b1;
                    end
                end
            
                // ===== 帧间隔等待 =====
                S_FRAME_GAP: begin
                    if (frame_gap_cnt == (FRAME_GAP_CLKS - 1)) begin
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

endmodule
