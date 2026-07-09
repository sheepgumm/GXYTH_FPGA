`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Deng Yukun
// 
// Create Date: 2026/01/01 15:52:12
// Design Name: 
// Module Name: det
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
module det(
    // ==========================================
    // 1. 时钟、复位与基础控制 (Clocks & Reset)
    // ==========================================
    input                           I_clk                   , // 主系统时钟 (80MHz)
    input                           I_clk_adc               , // ADC 采样时钟 (未使用)
    input                           I_rst                   , // 异步复位信号 (低有效)
    input                           I_clk_drv               , // 探测器驱动时钟输入
    input                           I_clk_delay             , // 延迟时钟输入
    
    // ==========================================
    // 2. 状态指示与调试接口 (Status & Debug)
    // ==========================================
    output                  [6:1]   O_testpoint             , // 测试点输出
    input                   [4:1]   I_dip_sts               , // 拨码开关状态
    input                           I_trig                  , // 外部触发输入
    input                   [15:0]  o_rd_data               , // 读取的测试或状态数据

    // ==========================================
    // 3. 探测器物理接口 (Detector Physical Interface)
    // ==========================================
    (*mark_debug = "true"*) output  O_fpga_pwr_ctrl1        , // 探测器电源控制 1
    (*mark_debug = "true"*) output  O_fpga_pwr_ctrl2        , // 探测器电源控制 2
    (*mark_debug = "true"*) output  O_fpga_pwr_ctrl3        , // 探测器电源控制 3
    (*mark_debug = "true"*) output  O_fpga_det_mclk         , // 探测器主时钟输出
    (*mark_debug = "true"*) input   I_fpga_det_valid        , // 探测器输出的数据有效指示
    (*mark_debug = "true"*) input   I_fpga_det_error        , // 探测器错误状态指示
    (*mark_debug = "true"*) output  O_fpga_det_serial       , // 探测器串行配置数据 (DATA)
    (*mark_debug = "true"*) output  O_fpga_det_reset        , // 探测器复位控制
    (*mark_debug = "true"*) output  O_fpga_det_int          , // 探测器积分控制信号 (INT)
    (*mark_debug = "true"*) output  O_fpga_det_error        , // 输出到顶层的探测器错误状态

    // ==========================================
    // 4. 外部控制参数与指令输入 (Control Parameters)
    // ==========================================
    input                           I_param_update          , // 参数更新使能 (来自串口解析)
    input                   [7:0]   I_gain_num              , // 增益设置参数
    input                   [15:0]  I_int_num               , // 积分时间设置参数
    (*mark_debug = "true"*) input   [15:0]  I_freframe_num  , // 帧频/成像周期参数
    input                   [7:0]   I_image_ctrl            , // 图像控制模式字
    input                           I_driver_en             , // 驱动器整体使能
    input                   [7:0]   I_GongZuoMoShi          , // 系统工作模式
    input                   [7:0]   I_HeBingMoShi           , // 像素合并(Binning)或校正模式
    (*mark_debug = "true"*) input   [7:0]   trigger         , // 外部触发模式寄存器
    (*mark_debug = "true"*) input   pps_ready               , // PPS 秒脉冲同步就绪标志

    // ==========================================
    // 5. 图像同步与输出状态 (Synchronization Outputs)
    // ==========================================
    (*mark_debug = "true"*) output  O_fpga_line_valid       , // 行有效信号输出
    output                  [15:0]  O_N_int                 , // 实际生效的积分计数值
    output                  [15:0]  O_param_int             , // 回读: 积分时间参数
    output                  [15:0]  O_param_frame           , // 回读: 帧频参数
    output                  [7:0]   O_param_gain            , // 回读: 增益参数
    output                          O_expose_rdy            , // 曝光就绪指示
    output                          O_param_en              , // 参数生效指示
    output                          O_frame_valid_syn       , // 帧同步有效信号
    output                  [15:0]  O_frame_seq_num           // 帧序号计数输出
);

// =========================================================================
// 内部寄存器与连线定义 (Internal Registers & Wires)
// =========================================================================

// 探测器物理接口的内部驱动寄存器
reg                                 fpga_pwr_ctrl1          ;
reg                                 fpga_pwr_ctrl2          ;
reg                                 fpga_pwr_ctrl3          ;
reg                                 fpga_det_mclk           ;
reg                                 fpga_det_serial         ;
reg                                 fpga_det_reset          ;
reg                                 fpga_det_int            ;
reg                                 det_mclk_en             ; // 探测器 MCLK 输出使能

reg                         [15:0]  frame_seq_num           ; // 内部帧计数器

// 成像参数与缓存寄存器 (用于跨时钟域或时序安全更新)
reg                         [1:0]   param_en                ; // 参数更新生效状态机
reg                         [1:0]   INT_ctrl                ; // 积分时间控制模式
reg                         [31:0]  N_frame                 ; // 当前生效的帧周期计数值
reg                         [15:0]  N_int                   ; // 当前生效的积分计数值
reg                         [7:0]   N_gain                  ; // 当前生效的增益
reg                         [7:0]   image_ctrl              ; // 当前生效的图像控制字

reg                         [31:0]  tmp_N_frame             ; // 缓存的帧周期计数值
reg                         [15:0]  tmp_N_int               ; // 缓存的积分计数值
reg                         [7:0]   tmp_N_gain              ; // 缓存的增益
reg                         [7:0]   tmp_image_ctrl          ; // 缓存的图像控制字

// 状态机与计数器
(*mark_debug = "true"*) reg [3:0]   driver_fsm              ; // 上电与配置主状态机
reg                         [31:0]  cnt_frame               ; // 帧周期计数器
reg                         [31:0]  cnt_int                 ; // 积分时间计数器
reg                         [10:0]  cnt_line_pixel          ; // 行内像素计数器
reg                         [10:0]  cnt_line_no             ; // 帧内行号计数器
reg                                 frame_pixel_syn         ; // 像素同步标志
reg                                 expose_rdy              ; // 曝光就绪标志
reg                         [6:1]   testpoint = 0           ;
reg                         [4:0]   mc_wait                 ; // 行间等待计数器
reg                                 line_valid              ; // 内部行有效标志

// 内部连线
wire                                fpga_line_valid         ;
wire                                fpga_det_error          ;
wire                        [7:0]   GongZuoMoShi            ;
wire                        [7:0]   HeBingMoShi             ;
reg                         [1:0]   fpga_det_error_buf      ; // 探测器错误状态打拍缓存

// 端口赋值
assign                              fpga_line_valid         = I_fpga_det_valid;
assign                              fpga_det_error          = I_fpga_det_error;
assign                              O_fpga_pwr_ctrl1        = fpga_pwr_ctrl1;
assign                              O_fpga_pwr_ctrl2        = fpga_pwr_ctrl2;
assign                              O_fpga_pwr_ctrl3        = fpga_pwr_ctrl3;
assign                              O_fpga_det_mclk         = fpga_det_mclk & det_mclk_en;
assign                              O_fpga_det_serial       = fpga_det_serial;
assign                              O_fpga_det_reset        = fpga_det_reset;
assign                              O_fpga_det_int          = fpga_det_int;
// assign                             O_fpga_line_valid       = fpga_line_valid;
assign                              O_fpga_line_valid       = line_valid; // 输出行有效

assign                              GongZuoMoShi            = I_GongZuoMoShi;
assign                              HeBingMoShi             = I_HeBingMoShi;

// 参数回读接口赋值
assign                              O_param_int             = I_int_num;
assign                              O_param_frame           = I_freframe_num;
assign                              O_param_gain            = I_gain_num;
assign                              O_param_en              = param_en[0];
assign                              O_frame_valid_syn       = frame_pixel_syn;
assign                              O_expose_rdy            = expose_rdy;
assign                              O_frame_seq_num         = frame_seq_num;
assign                              O_fpga_det_error        = fpga_det_error_buf[1];


// =========================================================================
// 探测器配置字定义 (114-bit CMD WORD)
// =========================================================================
reg                         [113:0] DET_CMD_WORD            ; // 最终下发的 114 位串行数据

reg                         [3:0]   DET_CMD_WORD_START      ; // 串口使能控制 (起始位)
reg                                 DET_CMD_WORD_INTERLACE_EN; // INTERLACE 模式控制
reg                                 DET_CMD_WORD_BIN        ; // Binning 模式控制 (像素合并)
reg                                 DET_CMD_WORD_POLAR      ; // 像素极化控制
reg                                 DET_CMD_WORD_UPCOL      ; // 图像列反转
reg                                 DET_CMD_WORD_UPROW      ; // 图像行反转
reg                                 DET_CMD_WORD_SIZEA      ; // 固定格式控制 A
reg                                 DET_CMD_WORD_SIZEB      ; // 固定格式控制 B
reg                         [7:0]   DET_CMD_WORD_CMIN       ; // 窗口列起点位置
reg                         [7:0]   DET_CMD_WORD_CMAX       ; // 窗口列终点位置
reg                         [8:0]   DET_CMD_WORD_RMIN       ; // 窗口行起点位置
reg                         [8:0]   DET_CMD_WORD_RMAX       ; // 窗口行终点位置
reg                         [2:0]   DET_CMD_WORD_PWR_CTRL   ; // 全局功耗控制
reg                         [2:0]   DET_CMD_WORD_ICOL_CTRL  ; // 列电路功耗控制
reg                         [2:0]   DET_CMD_WORD_IAK_CTRL   ; // 逻辑电路功耗控制
reg                         [1:0]   DET_CMD_WORD_IOUT_CTRL  ; // 输出电路功耗控制
reg                         [2:0]   DET_CMD_WORD_CESHI_1    ; // 测试模式控制 1
reg                         [2:0]   DET_CMD_WORD_VAB_CTRL   ; // VAB 调整控制
reg                         [1:0]   DET_CMD_WORD_CESHI_2    ; // 测试模式控制 2
reg                         [2:0]   DET_CMD_WORD_CESHI_3    ; // 测试模式控制 3
reg                         [1:0]   DET_CMD_WORD_CESHI_4    ; // 测试模式控制 4
reg                         [1:0]   DET_CMD_WORD_CESHI_5    ; // 测试模式控制 5
reg                                 DET_CMD_WORD_T_ROWSH    ; // 行同步及行采样时间控制
reg                         [1:0]   DET_CMD_WORD_TR_SEL     ; // 积分电容复位时间控制
reg                         [4:0]   DET_CMD_WORD_CESHI_6    ; // 测试模式控制 6
reg                         [2:0]   DET_CMD_WORD_CESHI_7    ; // 测试模式控制 7
reg                                 DET_CMD_WORD_CESHI_8    ; // 测试模式控制 8
reg                         [2:0]   DET_CMD_WORD_CESHI_9    ; // 测试模式控制 9
reg                         [3:0]   DET_CMD_WORD_CESHI_10   ; // 测试模式控制 10
reg                         [7:0]   DET_CMD_WORD_CESHI_11   ; // 测试模式控制 11
reg                         [7:0]   DET_CMD_WORD_CESHI_12   ; // 测试模式控制 12
reg                         [7:0]   DET_CMD_WORD_CESHI_13   ; // 测试模式控制 13

wire                        [113:0] DET_CMD_WORD_TMP        ; // 拼接生成的完整控制字
assign	DET_CMD_WORD_TMP = {DET_CMD_WORD_START[3:0],DET_CMD_WORD_INTERLACE_EN,DET_CMD_WORD_BIN,DET_CMD_WORD_POLAR,
							DET_CMD_WORD_UPCOL,DET_CMD_WORD_UPROW,DET_CMD_WORD_SIZEA,DET_CMD_WORD_SIZEB,
							DET_CMD_WORD_CMIN[7:0],DET_CMD_WORD_CMAX[7:0],DET_CMD_WORD_RMIN[8:0],DET_CMD_WORD_RMAX[8:0],
							DET_CMD_WORD_PWR_CTRL[2:0],DET_CMD_WORD_ICOL_CTRL[2:0],DET_CMD_WORD_IAK_CTRL[2:0],DET_CMD_WORD_IOUT_CTRL[1:0],
							DET_CMD_WORD_CESHI_1[2:0],DET_CMD_WORD_VAB_CTRL[2:0],DET_CMD_WORD_CESHI_2[1:0],DET_CMD_WORD_CESHI_3[2:0],
							DET_CMD_WORD_CESHI_4[1:0],DET_CMD_WORD_CESHI_5[1:0],DET_CMD_WORD_T_ROWSH,DET_CMD_WORD_TR_SEL[1:0],
							DET_CMD_WORD_CESHI_6[4:0],DET_CMD_WORD_CESHI_7[2:0],DET_CMD_WORD_CESHI_8,DET_CMD_WORD_CESHI_9[2:0],
							DET_CMD_WORD_CESHI_10[3:0],DET_CMD_WORD_CESHI_11[7:0],DET_CMD_WORD_CESHI_12[7:0], DET_CMD_WORD_CESHI_13[7:0]
							};

reg                         [7:0]   N_START = 4             ;
reg                                 fpga_det_int_prev       ;
(*mark_debug = "true"*) reg [1:0]   det_frame_start         ;
(*mark_debug = "true"*) reg [6:0]   mclk_counter            ; // 计数器，用于计数 MCLK 周期
reg                                 wait_for_mclk           ; // 标志位，表示正在等待 MCLK 周期
reg                         [1:0]   clk_driver_sample       ; // 时钟采样寄存器 (从I_clk分频获得)
reg                                 image_start             ; // 图像采集启动标志
reg                                 flag_rd_finish          ; // 图像读取完成标志
(*mark_debug = "true"*) reg         frame_start             ; // 帧启动标志
reg                         [1:0]   det_image_start         ; // 打拍后的驱动使能信号
reg                         [15:0]  N_int_cnt               ; // 内部辅助积分计数

assign O_N_int = (INT_ctrl == 2'b10) ? tmp_N_int : N_int_cnt;

// =========================================================================
// 信号打拍与同步 (Signal Synchronization)
// =========================================================================

reg                         [1:0]   trig                    ; // PPS 同步触发信号打拍
always @(posedge I_clk) begin
    if (!I_rst) begin
        trig                    <= 0;
    end 
    else begin
        trig[0]                 <= pps_ready; 
        trig[1]                 <= trig[0];
    end
end

always @(posedge I_clk) begin
    if (!I_rst) begin
        fpga_det_error_buf      <= 0;
    end 
    else begin
        fpga_det_error_buf[0]   <= fpga_det_error; 
        fpga_det_error_buf[1]   <= fpga_det_error_buf[0];
    end
end

// 检测探测器 INT 信号下降沿并延迟特定 MCLK 周期产生 frame_start
always @(posedge I_clk) begin
    if (!I_rst) begin
        det_frame_start         <= 0;
        mclk_counter            <= 0;
        wait_for_mclk           <= 0;
        frame_start             <= 1'b0;
    end 
    else begin
        det_frame_start[0]      <= frame_start;
        det_frame_start[1]      <= det_frame_start[0];
        fpga_det_int_prev       <= fpga_det_int;
        
        // 检测 fpga_det_int 的下降沿 (从 1 变 0)
        if (fpga_det_int_prev && !fpga_det_int) begin
            // fpga_det_int 由 1 变 0，开始计数 81 个 MCLK 周期
            frame_start             <= 0;
            mclk_counter            <= 0;
            wait_for_mclk           <= 1;
        end

        // 如果正在等待 MCLK 周期
        if (wait_for_mclk) begin
            frame_start             <= 1'b0;
            // 检测 MCLK 的上升沿 (clk_driver_sample == 2'b01)
            if (clk_driver_sample == 2'b01) begin
                mclk_counter            <= mclk_counter + 1;
                // 当计数达到 83 个 MCLK 周期时，拉高 frame_start
                if (mclk_counter == 83) begin
                    frame_start             <= 1'b1;
                    wait_for_mclk           <= 0;
                    mclk_counter            <= 0;
                end
                else begin
                    frame_start             <= 1'b0;
                end
            end
        end
    end
end

// 驱动使能信号打拍同步
always @(posedge I_clk) begin
    if (!I_rst) begin
        det_image_start         <= 0;
    end 
    else begin
        det_image_start[0]      <= I_driver_en; 
        det_image_start[1]      <= det_image_start[0];
    end
end

// 外部/探测器行有效信号打拍同步
reg                         [1:0]   det_line_start          ;
always @(posedge I_clk) begin
    if (!I_rst) begin
        det_line_start          <= 0;
    end 
    else begin
        det_line_start[0]       <= fpga_line_valid; 
        det_line_start[1]       <= det_line_start[0];
    end
end

// 内部行有效信号打拍同步
reg                         [1:0]   line_start              ;
always @(posedge I_clk) begin
    if (!I_rst) begin
        line_start              <= 0;
    end 
    else begin
        line_start[0]           <= line_valid;
        line_start[1]           <= line_start[0];
    end
end

// =========================================================================
// 时钟分频生成 (5MHz 时钟驱动生成)
// =========================================================================
reg                         [3:0]   clk_div_counter = 0     ; // 分频计数器
reg                                 clk_5m = 0              ; // 5MHz 目标时钟

always @(posedge I_clk) begin
    if (!I_rst) begin
        clk_div_counter         <= 0;
        clk_5m                  <= 0;
    end 
    else begin
        if (clk_div_counter >= 7) begin  // 0-7 共8个周期翻转
            clk_div_counter         <= 0;
            clk_5m                  <= ~clk_5m;  
        end 
        else begin
            clk_div_counter         <= clk_div_counter + 1;
        end
    end
end

always @(posedge I_clk) begin
    if (!I_rst) begin
        clk_driver_sample       <= 0;
    end 
    else begin
        clk_driver_sample[0]    <= clk_5m;
        clk_driver_sample[1]    <= clk_driver_sample[0]; 
    end
end

reg                         [1:0]   fpga_det_mclk_r_sample  ;
always @(posedge I_clk) begin
    if (!I_rst) begin
        fpga_det_mclk_r_sample  <= 0;
    end 
    else begin
        fpga_det_mclk_r_sample[0] <= fpga_det_mclk;
        fpga_det_mclk_r_sample[1] <= fpga_det_mclk_r_sample[0];
    end
end

// =========================================================================
// 行计数统计与超时复位保护 (Line Valid Counter)
// =========================================================================
(*mark_debug = "true"*) reg [9:0]   valid_cnt               ;
always @(posedge I_clk) begin
    if (!I_rst) begin
        valid_cnt               <= 0;
    end 
    else begin
        if (line_start == 2'b01) begin
            valid_cnt               <= valid_cnt + 1;
        end
        else if (valid_cnt >= 512) begin // 探测器为 512 行
            valid_cnt               <= 0;
        end
        else begin
            valid_cnt               <= valid_cnt;
        end
    end
end

// =========================================================================
// 参数解析与配置字初始化逻辑 (Parameter Parsing)
// =========================================================================
(*mark_debug = "true"*) reg [2:0]   fsm_detout_rd           ;

always @(posedge I_clk) begin
    if (!I_rst) begin
        N_frame                 <= 4000;    // 默认值: 20Hz @ mclk=4MHz
        N_int                   <= 120;     // 默认值: 1ms
        N_gain                  <= 0;
        image_ctrl              <= 8'h70;
        tmp_N_frame             <= 4000;
        tmp_N_int               <= 120;
        tmp_N_gain              <= 0;
        tmp_image_ctrl          <= 8'h70;
        param_en                <= 0;
        N_int_cnt               <= 16'd5;
        INT_ctrl                <= 2'd0;

        // 初始化探测器串行配置寄存器的默认值
        DET_CMD_WORD_START      <= 4'b1101;
        DET_CMD_WORD_INTERLACE_EN <= 1'b0;
        DET_CMD_WORD_BIN        <= 1'b0;
        DET_CMD_WORD_POLAR      <= 1'b0;
        DET_CMD_WORD_UPCOL      <= 1'b1;
        DET_CMD_WORD_UPROW      <= 1'b1;
        DET_CMD_WORD_SIZEA      <= 1'b1;
        DET_CMD_WORD_SIZEB      <= 1'b1;
        DET_CMD_WORD_CMIN       <= 8'h00;
        DET_CMD_WORD_CMAX       <= 8'h00;
        DET_CMD_WORD_RMIN       <= 9'h000;
        DET_CMD_WORD_RMAX       <= 9'h000;
        DET_CMD_WORD_PWR_CTRL   <= 3'b011;
        DET_CMD_WORD_ICOL_CTRL  <= 3'b011;
        DET_CMD_WORD_IAK_CTRL   <= 3'b010;
        DET_CMD_WORD_IOUT_CTRL  <= 2'b10;
        DET_CMD_WORD_CESHI_1    <= 3'b000;
        DET_CMD_WORD_VAB_CTRL   <= 3'b100;
        DET_CMD_WORD_CESHI_2    <= 2'b00;
        DET_CMD_WORD_CESHI_3    <= 3'b101;
        DET_CMD_WORD_CESHI_4    <= 2'b00;
        DET_CMD_WORD_CESHI_5    <= 2'b01;
        DET_CMD_WORD_T_ROWSH    <= 1'b0;
        DET_CMD_WORD_TR_SEL     <= 2'b01;
        DET_CMD_WORD_CESHI_6    <= 5'b00100;
        DET_CMD_WORD_CESHI_7    <= 3'b001;
        DET_CMD_WORD_CESHI_8    <= 1'b0;
        DET_CMD_WORD_CESHI_9    <= 3'b000;
        DET_CMD_WORD_CESHI_10   <= 4'b1000;
        DET_CMD_WORD_CESHI_11   <= 8'h00;
        DET_CMD_WORD_CESHI_12   <= 8'h00;
        DET_CMD_WORD_CESHI_13   <= 8'h00;
    end
	else begin
		// 当接收到外部串口下发的参数更新指令时，缓存新参数
        if (I_param_update) begin
            tmp_N_frame             <= I_freframe_num;
            tmp_N_int               <= I_int_num;
            tmp_N_gain              <= I_gain_num;
            tmp_image_ctrl          <= I_image_ctrl;
            
            // 根据合并/两点校正模式设定参数生效标志
            if ((HeBingMoShi == 8'h03) || (HeBingMoShi == 8'h04)) begin
                param_en                <= 2'b01;
            end
            else begin 
                param_en                <= 2'b10;
            end
        end

		// 当不在发送配置数据的敏感阶段时，将缓存参数写入生效寄存器
        if (param_en == 2'b10) begin
            if ((driver_fsm == 5) || (driver_fsm == 6) || (driver_fsm == 7) || (driver_fsm == 8)) begin
                N_frame                 <= tmp_N_frame * 50; 
                INT_ctrl                <= 2'b10;
                N_gain                  <= tmp_N_gain;
                param_en                <= 0;
            end 
            image_ctrl              <= tmp_image_ctrl;
        end 

        if (param_en == 2'b01) begin
            if ((driver_fsm == 5) || (driver_fsm == 6) || (driver_fsm == 7) || (driver_fsm == 8)) begin
                N_frame                 <= tmp_N_frame * 50;
                INT_ctrl                <= 2'b01;
                N_gain                  <= tmp_N_gain;
                param_en                <= 0;
            end 
            image_ctrl              <= tmp_image_ctrl;
        end

		// 根据积分模式换算积分时间周期数 (通信协议: 500us -> 0x01F4)
        if (INT_ctrl == 2'b10) begin
            N_int                   <= (tmp_N_int * 5) + 16'd2500;
            N_int_cnt               <= 16'd5;
        end
        else if (INT_ctrl == 2'b01) begin 
            if (fsm_detout_rd == 3'd3) begin
                N_int_cnt               <= N_int_cnt + 16'd5;
                N_int                   <= (N_int_cnt * 5) + 16'd2500;
            end
            else if (N_int_cnt >= 280) begin 
                N_int_cnt               <= 16'd5;
            end
            else begin 
                N_int_cnt               <= N_int_cnt;
            end
        end 
        
        // 当未启动图像采集时，重置内部积分辅助计数
        if (image_start == 1'b0) begin
            N_int_cnt               <= 16'd5;
        end
    end 
end

reg                                 image_trig              ;
reg                         [6:0]   cnt_det_cmd_wr          ;
reg                         [63:0]  cnt_det_ctrl            ;
reg                         [63:0]  N_DET_CTRL = 64'd40000000; // 0.5s @ 80MHz，用于探测器上电间隙计时

// 生成探测器配置启动判断逻辑 (基于工作模式与温度门限)
(*mark_debug = "true"*) reg         det_image_start_tmp     ;
always @(posedge I_clk) begin
    if (!I_rst) begin
        det_image_start_tmp     <= 1'b0;
    end 
    else begin
        // 判断工作模式且状态数据正常才允许启动采集
        det_image_start_tmp     <= (((GongZuoMoShi == 8'h10) || (GongZuoMoShi == 8'h11)) && (det_image_start == 2'b11) && (o_rd_data > 16'd2400)) ? 1'b1 : 1'b0;
    end 
end

// =========================================================================
// 探测器上电复位时序与串行配置状态机 (Power Sequencing & SPI FSM)
// =========================================================================
always @(posedge I_clk) begin
    if (!I_rst) begin
        DET_CMD_WORD            <= 114'd0;
        fpga_pwr_ctrl1          <= 1'b0;
        fpga_pwr_ctrl2          <= 1'b0;
        fpga_pwr_ctrl3          <= 1'b0;
        fpga_det_mclk           <= 1'b0;
        det_mclk_en             <= 1'b0;
        fpga_det_serial         <= 1'b0;
        fpga_det_reset          <= 1'b0;
        image_start             <= 0;
        driver_fsm              <= 0;
        cnt_det_ctrl            <= 0;
        cnt_det_cmd_wr          <= 0;
    end
	else begin
        // 维持探测器时钟的翻转
        if (clk_driver_sample == 2'b01) begin
            fpga_det_mclk           <= 1'b1;
        end 
        else if (clk_driver_sample == 2'b10) begin
            fpga_det_mclk           <= 1'b0;
        end
		
		case (driver_fsm)
            0: begin                // IDLE 状态，等待图像采集启动指令
                if (det_image_start_tmp == 1'b1) begin
                    fpga_pwr_ctrl1          <= 1'b1; // 第一路上电
                    cnt_det_ctrl            <= 0;
                    driver_fsm              <= 1;
                end 
                else begin
                    fpga_pwr_ctrl1          <= 1'b0;
                    fpga_pwr_ctrl2          <= 1'b0;
                    fpga_pwr_ctrl3          <= 1'b0;
                    fpga_det_mclk           <= 1'b0;
                    det_mclk_en             <= 1'b0;
                    fpga_det_serial         <= 1'b0;
                    fpga_det_reset          <= 1'b0;
                end 
            end 
            
            1: begin                // 延时后拉起复位
                if (cnt_det_ctrl == N_DET_CTRL - 1) begin
                    cnt_det_ctrl            <= 0;
                    fpga_det_reset          <= 1'b1;
                    driver_fsm              <= 2;
                end 
                else begin
                    cnt_det_ctrl            <= cnt_det_ctrl + 1'b1;
                end 
            end 
            
            2: begin                // 延时后释放复位并开启第二路电源
                if (cnt_det_ctrl == N_DET_CTRL - 1) begin
                    cnt_det_ctrl            <= 0;
                    fpga_det_reset          <= 1'b0;
                    fpga_pwr_ctrl2          <= 1'b1;
                    driver_fsm              <= 3;
                end 
                else begin
                    cnt_det_ctrl            <= cnt_det_ctrl + 1'b1;
                end 
            end 
            
            3: begin                // 延时后开启第三路电源
                if (cnt_det_ctrl == N_DET_CTRL - 1) begin
                    cnt_det_ctrl            <= 0;
                    fpga_pwr_ctrl3          <= 1'b1;
                    driver_fsm              <= 4;
                end 
                else begin
                    cnt_det_ctrl            <= cnt_det_ctrl + 1'b1;
                end 
            end 
            
            4: begin                // 延时后使能 MCLK 驱动输出
                if (cnt_det_ctrl == N_DET_CTRL - 1) begin
                    cnt_det_ctrl            <= 0;
                    det_mclk_en             <= 1;
                    driver_fsm              <= 5;
                end 
                else begin
                    cnt_det_ctrl            <= cnt_det_ctrl + 1'b1;
                end 
            end 

            5: begin                // 缓冲延时
                if (cnt_det_ctrl == N_DET_CTRL - 1) begin
                    cnt_det_ctrl            <= 0;
                    driver_fsm              <= 6;
                end 
                else begin
                    cnt_det_ctrl            <= cnt_det_ctrl + 1'b1;
                end 
            end 
            
            6: begin                // 装载 114 位串行控制字
                if (det_image_start_tmp == 1'b1) begin  
                    DET_CMD_WORD            <= DET_CMD_WORD_TMP;
                    cnt_det_cmd_wr          <= 0;
                    driver_fsm              <= 7;
                end 
                else begin              
                    driver_fsm              <= 0;
                end 
            end 
            
            7: begin                // 串行移位输出配置字 (MSB 优先)
                if (clk_driver_sample == 2'b01) begin
                    if (cnt_det_cmd_wr < 114) begin
                        cnt_det_cmd_wr          <= cnt_det_cmd_wr + 1'b1;
                        fpga_det_serial         <= DET_CMD_WORD[113]; // 发送最高位
                        DET_CMD_WORD[113:0]     <= {DET_CMD_WORD[112:0], 1'b0}; // 左移
                    end 
                    else begin
                        cnt_det_cmd_wr          <= 0;
                        driver_fsm              <= 8;
                        fpga_det_serial         <= 1'b0;
                    end 
                end 
            end 
            
            8: begin                // 配置完成后延时缓冲
                if (cnt_det_ctrl == N_DET_CTRL - 1) begin
                    cnt_det_ctrl            <= 0;
                    driver_fsm              <= 9;
                end 
                else begin
                    cnt_det_ctrl            <= cnt_det_ctrl + 1'b1;
                end 
            end 
            
            9: begin                // 根据触发模式启动正常图像采集业务
                if (det_image_start_tmp == 1'b1 && HeBingMoShi == 8'h01) begin
                    image_start             <= 1'b1;
                end
                else if (det_image_start_tmp == 1'b1 && HeBingMoShi == 8'h02) begin
                    if (trig == 2'b01 && cnt_int == 0) begin
                        image_start             <= 1'b1;
                    end
                    else if(image_trig) begin
                        image_start             <= 1'b0;
                    end
                    else begin
                        image_start             <= image_start;
                    end
                end
                else if (det_image_start_tmp == 1'b0) begin
                    image_start             <= 1'b0;
                    driver_fsm              <= 10;
                end
            end 
            
            10: begin               // 停机序列：关闭 MCLK、复位及串口
                if (cnt_det_ctrl == (N_DET_CTRL*2 - 1)) begin
                    det_mclk_en             <= 0;
                    fpga_det_serial         <= 1'b0;
                    fpga_det_reset          <= 1'b0;
                    driver_fsm              <= 11;
                end 
                else begin
                    cnt_det_ctrl            <= cnt_det_ctrl + 1'b1;
                end 
            end 
            
            11: begin               // 停机序列：关闭第三路电源
                if (cnt_det_ctrl == (N_DET_CTRL*2 - 1)) begin
                    cnt_det_ctrl            <= 0;
                    fpga_pwr_ctrl3          <= 1'b0;
                    driver_fsm              <= 12;
                end 
                else begin
                    cnt_det_ctrl            <= cnt_det_ctrl + 1'b1;
                end 
            end 
            
            12: begin               // 停机序列：关闭第二路电源
                if (cnt_det_ctrl == (N_DET_CTRL*2 - 1)) begin
                    cnt_det_ctrl            <= 0;
                    fpga_pwr_ctrl2          <= 1'b0;
                    driver_fsm              <= 13;
                end 
                else begin
                    cnt_det_ctrl            <= cnt_det_ctrl + 1'b1;
                end 
            end 
            
            13: begin               // 停机序列：关闭第一路电源并回到 IDLE
                if (cnt_det_ctrl == (N_DET_CTRL*2 - 1)) begin
                    cnt_det_ctrl            <= 0;
                    fpga_pwr_ctrl1          <= 1'b0;
                    driver_fsm              <= 0;
                end 
                else begin
                    cnt_det_ctrl            <= cnt_det_ctrl + 1'b1;
                end 
            end
			
			default: begin
                fpga_pwr_ctrl1          <= 1'b0;
                fpga_pwr_ctrl2          <= 1'b0;
                fpga_pwr_ctrl3          <= 1'b0;
                fpga_det_mclk           <= 1'b0;
                det_mclk_en             <= 1'b0;
                fpga_det_serial         <= 1'b0;
                fpga_det_reset          <= 1'b0;
                driver_fsm              <= 0;
            end 
        endcase 
    end 
end

reg                         [3:0]   cnt_start_pixel         ;
reg                         [16:0]  cnt_end_pixel           ;


// =========================================================================
// 积分控制与数据读取时序状态机 (Integration & Readout FSM)
// =========================================================================
always @(posedge I_clk) begin
    if (!I_rst) begin
        cnt_line_pixel          <= 0;
        cnt_line_no             <= 0;
        frame_pixel_syn         <= 0;
        fsm_detout_rd           <= 0;
        flag_rd_finish          <= 0;
        cnt_start_pixel         <= 0;
        cnt_frame               <= 0;
        cnt_int                 <= 0;
        fpga_det_int            <= 0;
        frame_seq_num           <= 0;
        mc_wait                 <= 0;
        line_valid              <= 0;
        image_trig              <= 0;
    end 
    else if (det_image_start_tmp == 1'b0) begin
        fpga_det_int            <= 0;
        image_trig              <= 0;
        fsm_detout_rd           <= 0;
        line_valid              <= 0;
        cnt_int                 <= 0;
    end
    else begin
        if (image_trig) begin
            image_trig              <= ~image_trig;
        end

		if (image_start) begin
            case (fsm_detout_rd)
                0:  begin   // 状态 0: 积分期 (Integration)
                    if (clk_driver_sample == 2'b01) begin
                        cnt_int                 <= cnt_int + 1'b1;
                        if (cnt_int == 0) begin
                            fpga_det_int            <= 1'b1; // 开始积分
                        end 
                        else if (cnt_int == (N_int - 120)) begin
                            line_valid              <= 1;    // 提前拉高以配合后续流水
                        end
                        else if (cnt_int >= (N_int)) begin         
                            fpga_det_int            <= 1'b0; // 结束积分
                            fsm_detout_rd           <= 5;    // 跳转到准备读出状态
                            line_valid              <= 0;
                        end 
                        else begin
                            fpga_det_int            <= fpga_det_int;
                        end
                    end 
                end

                5: begin    // 状态 5: 等待读出同步 (Wait for Readout Sync)
                    if (det_frame_start == 2'b01) begin     // 检测到帧启动信号
                        cnt_line_pixel          <= 0;
                        cnt_line_no             <= 0;
                        flag_rd_finish          <= 0;
                        frame_pixel_syn         <= 1;
                        line_valid              <= 1;
                        fsm_detout_rd           <= 1;
                    end 
                end 
                
                1: begin    // 状态 1: 行像素读出计数 (Line Pixel Readout)
                    if (clk_driver_sample == 2'b01) begin
                        cnt_int                 <= cnt_int + 1'b1;
                        cnt_line_pixel          <= cnt_line_pixel + 1; // 像素递增
                        if (cnt_line_pixel == 159) begin               // 4 通道，160 个时钟周期对应 640 像素
                            cnt_line_pixel          <= 0;
                            cnt_line_no             <= cnt_line_no + 1;
                            line_valid              <= 0;              // 结束当前行读出
                            
                            if (cnt_line_no == 511) begin              // 读完一帧 (512行)
                                cnt_line_no             <= 0;
                                flag_rd_finish          <= 1;
                                frame_pixel_syn         <= 0;
                                fsm_detout_rd           <= 3;
                                line_valid              <= 0;
                            end 
                            else begin
                                fsm_detout_rd           <= 2;          // 准备读下一行，进入行间歇
                            end 
                        end 
                    end 
                end 
                    
                2: begin    // 状态 2: 行间歇等待 (Line Blanking)
                    if (clk_driver_sample == 2'b01) begin
                        cnt_int                 <= cnt_int + 1'b1;
                        mc_wait                 <= mc_wait + 1;
                        if (mc_wait == 30) begin                       // 间歇等待 30 个周期
                            line_valid              <= 1;              // 准备开始新一行有效数据
                            mc_wait                 <= 0;
                            fsm_detout_rd           <= 1;
                        end
                    end
                end 
                
                3: begin    // 状态 3: 帧读出结束缓冲 (Frame Finish)
                    flag_rd_finish          <= 0;
                    fsm_detout_rd           <= 4;
                    cnt_end_pixel           <= 0;
                end 
                
                4: begin    // 状态 4: 帧间歇等待满足帧频要求 (Frame Blanking)
                    if (clk_driver_sample == 2'b01) begin
                        cnt_int                 <= cnt_int + 1'b1;
                        if (cnt_int >= N_frame) begin                  // 达到配置的帧频周期
                            fsm_detout_rd           <= 0;              // 回到状态0进行下一次积分
                            cnt_int                 <= 0;    
                            image_trig              <= 1;
                        end
                    end 
                end 
                
                default: begin
                    flag_rd_finish          <= 0;
                    fsm_detout_rd           <= 0;
                end 
            endcase 
        end 
    end 
end

// =========================================================================
// 曝光就绪指示信号 (Exposure Ready Flag)
// =========================================================================
always @(posedge I_clk) begin
    if (!I_rst ) begin
        expose_rdy              <= 0;
    end 
    else begin
        if (det_frame_start == 2'b01) begin // 在检测到帧启动时拉高
            expose_rdy              <= 1;
        end 
        else begin
            expose_rdy              <= 0;
        end 
    end 
end

endmodule
