`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Deng Yukun
// 
// Create Date: 2026/01/01 15:52:12
// Design Name: 
// Module Name: aurora_64/66B
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

module aurora_64b66b (
    // ===================== GT 参考时钟 =====================
    input                           gt_refclk_p         , // GT 参考时钟 P
    input                           gt_refclk_n         , // GT 参考时钟 N

    // ===================== 串行 IO =====================
    output                          gt_txp              , // GT TX P 输出
    output                          gt_txn              , // GT TX N 输出

    // ===================== 时钟与复位 =====================
    input                           init_clk            , // 初始化时钟 (用于配置)
    input                           drp_clk             , // DRP 时钟
    output                          user_clk            , // 用户时钟 (由 IP 核输出)
    input                           rst_n               , // 异步复位信号 (低电平有效)

    // ===================== Aurora 状态 =====================
    output  reg                     aurora_init         , // Aurora 初始化完成标志

    // ===================== AXI Stream 发送接口 =====================
    (*mark_debug = "TRUE" *) input                      s_axi_tx_tvalid     , // 发送数据有效
    (* mark_debug = "TRUE", keep = "TRUE" *) input [7:0]    s_axi_tx_tkeep      , // 发送数据字节掩码
    (*mark_debug = "TRUE" *) input              [63:0]  s_axi_tx_tdata      , // 发送数据
    (*mark_debug = "TRUE" *) input                      s_axi_tx_tlast      , // 发送数据帧结束标志
    (*mark_debug = "TRUE" *) output                     s_axi_tx_tready       // 发送数据就绪 (IP 核输出)

    // ===================== AXI Stream 接收接口 (未使用) =====================
    //  (*mark_debug = "TRUE" *) output                     m_axi_rx_tvalid     ,
    //  (*mark_debug = "TRUE" *) output             [63:0]  m_axi_rx_tdata      ,
    //  (*mark_debug = "TRUE" *) output             [7:0]   m_axi_rx_tkeep      ,
    //  (*mark_debug = "TRUE" *) output                     m_axi_rx_tlast
);

    // ===================== 内部信号定义 =====================
    wire                    [2:0]   loopback            ; // 环回模式 (固定为 3'b010)
    reg                     [15:0]  reset_cnt           ; // 复位延时计数器 (200 周期)
    reg                             reset_pb            ; // IP 核复位脉冲信号
    reg                     [15:0]  gt_reset_cnt        ; // GT 复位延时计数器 (500 周期)
    reg                             pma_init            ; // PMA 初始化脉冲信号

    (*mark_debug = "TRUE" *) wire            channel_up          ; // 通道上线标志
    (*mark_debug = "TRUE" *) wire            lane_up             ; // 通道上线标志 (每通道)
    (*mark_debug = "TRUE" *) wire            hard_err            ; // 硬错误标志
    (*mark_debug = "TRUE" *) wire            soft_err            ; // 软错误标志

    // ===================== 逻辑赋值 =====================
    assign loopback = 3'b010; // 配置为正常模式 (非环回)

    // ===================== 复位计数器 (用于生成 reset_pb) =====================
    // 计数 200 个 init_clk 周期，为 IP 核提供稳定的复位脉冲
    always @(posedge init_clk or negedge rst_n) begin
        if (!rst_n) begin
            reset_cnt <= 0;
        end else if (reset_cnt == 200) begin
            reset_cnt <= reset_cnt;          // 计数达到 200 后保持
        end else if (reset_cnt < 200) begin
            reset_cnt <= reset_cnt + 1'b1;   // 计数器递增
        end else begin
            reset_cnt <= reset_cnt;
        end
    end

    // 在计数 10 到 199 期间拉高 reset_pb (即复位脉冲持续约 190 个 init_clk 周期)
    always @(posedge init_clk or negedge rst_n) begin
        if (!rst_n) begin
            reset_pb <= 1'b1;
        end else if (reset_cnt >= 10 && reset_cnt < 200) begin
            reset_pb <= 1'b1;
        end else begin
            reset_pb <= 1'b0;
        end
    end

    // ===================== GT 复位计数器 (用于生成 pma_init) =====================
    // 计数 500 个 init_clk 周期，为 GT 提供足够的复位时间
    always @(posedge init_clk or negedge rst_n) begin
        if (!rst_n) begin
            gt_reset_cnt <= 0;
        end else if (gt_reset_cnt == 500) begin
            gt_reset_cnt <= gt_reset_cnt;    // 计数达到 500 后保持
        end else if (gt_reset_cnt < 500) begin
            gt_reset_cnt <= gt_reset_cnt + 1'b1; // 计数器递增
        end else begin
            gt_reset_cnt <= gt_reset_cnt;
        end
    end

    // 在计数 10 到 499 期间拉高 pma_init (即 PMA 初始化脉冲持续约 490 个 init_clk 周期)
    always @(posedge init_clk or negedge rst_n) begin
        if (!rst_n) begin
            pma_init <= 1'b1;
        end else if (gt_reset_cnt >= 10 && gt_reset_cnt < 500) begin
            pma_init <= 1'b1;
        end else begin
            pma_init <= 1'b0;
        end
    end

    // ===================== Aurora 初始化完成检测 =====================
    // 当通道上线 (channel_up) 和通道上线 (lane_up) 均为高电平时，置位 aurora_init
    always @(posedge user_clk or negedge rst_n) begin
        if (!rst_n) begin
            aurora_init <= 1'b0;
        end else if (channel_up == 1'b1 && lane_up == 1'b1) begin
            aurora_init <= 1'b1;             // 通道与通道全部上线，标志初始化完成
        end else begin
            aurora_init <= aurora_init;      // 否则保持原状态
        end
    end

    // ===================== Aurora 64B/66B IP 核实例化 =====================
    aurora_64b66b_0 u_aurora_64b66b_0 (
        // ----- 复位与电源控制 -----
        .reset_pb               (reset_pb           ), // input wire reset_pb
        .power_down             (1'b0               ), // input wire power_down
        .pma_init               (pma_init           ), // input wire pma_init

        // ----- 串行发送输出 -----
        .txp                    (gt_txp             ), // output wire [0:0] txp
        .txn                    (gt_txn             ), // output wire [0:0] txn

        // ----- 状态与错误信息 -----
        .tx_hard_err            (hard_err           ), // output wire tx_hard_err
        .tx_soft_err            (soft_err           ), // output wire tx_soft_err
        .tx_channel_up          (channel_up         ), // output wire tx_channel_up
        .tx_lane_up             (lane_up            ), // output wire [0:0] tx_lane_up
        .tx_out_clk             (                   ), // output wire tx_out_clk
        .gt_pll_lock            (                   ), // output wire gt_pll_lock

        // ----- DRP 接口 -----
        .drp_clk_in             (drp_clk            ), // input wire drp_clk_in
        .drpaddr_in             (9'd0               ), // input wire [8:0] drpaddr_in
        .drpdi_in               (16'd0              ), // input wire [15:0] drpdi_in
        .drprdy_out             (                   ), // output wire drprdy_out
        .drpen_in               (1'b0               ), // input wire drpen_in
        .drpwe_in               (1'b0               ), // input wire drpwe_in
        .drpdo_out              (                   ), // output wire [15:0] drpdo_out

        // ----- AXI Stream 发送接口 -----
        .s_axi_tx_tdata         (s_axi_tx_tdata     ), // input wire [0:63] s_axi_tx_tdata
        .s_axi_tx_tkeep         (s_axi_tx_tkeep     ), // input wire [0:7] s_axi_tx_tkeep
        .s_axi_tx_tlast         (s_axi_tx_tlast     ), // input wire s_axi_tx_tlast
        .s_axi_tx_tvalid        (s_axi_tx_tvalid    ), // input wire s_axi_tx_tvalid
        .s_axi_tx_tready        (s_axi_tx_tready    ), // output wire s_axi_tx_tready

        // ----- 时钟与复位 -----
        .init_clk               (init_clk           ), // input wire init_clk
        .mmcm_not_locked_out    (                   ), // output wire mmcm_not_locked_out
        .link_reset_out         (                   ), // output wire link_reset_out
        .sys_reset_out          (                   ), // output wire sys_reset_out
        .gt_reset_out           (                   ), // output wire gt_reset_out
        .reset2fg               (                   ), // output wire reset2fg

        // ----- GT 参考时钟 -----
        .gt_refclk1_p           (gt_refclk_p        ), // input wire gt_refclk1_p
        .gt_refclk1_n           (gt_refclk_n        ), // input wire gt_refclk1_n
        .gt_refclk1_out         (                   ), // output wire gt_refclk1_out

        // ----- 用户时钟输出 -----
        .user_clk_out           (user_clk           ), // output wire user_clk_out
        .sync_clk_out           (                   ), // output wire sync_clk_out

        // ----- QPLL 输出 (未连接) -----
        .gt_qpllclk_quad1_out   (                   ), // output wire gt_qpllclk_quad1_out
        .gt_qpllrefclk_quad1_out(                   ), // output wire gt_qpllrefclk_quad1_out

        // ----- 其他控制与状态 -----
        .gt_rxcdrovrden_in      (1'b0               )  // input wire gt_rxcdrovrden_in
    );

endmodule