`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Deng Yukun
// 
// Create Date: 2026/01/01 15:52:12
// Design Name: 
// Module Name: ad_interface
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

module ad_interface
(
    // ===================== 时钟与复位 =====================
    input   wire                        rst_n           , // 复位信号（低有效）
    input   wire                        DCO_p           , // 位同步时钟（320MHz，DCO+）
    input   wire                        DCO_n           , // 位同步时钟（320MHz，DCO-）
    input   wire                        fco             , // 帧同步时钟（80MHz，FCO+）

    // ===================== ADC 数据输入（四通道，每通道两对 LVDS） =====================
    input   wire                        AD1_D0p         , // 通道1 D0 正
    input   wire                        AD1_D0n         , // 通道1 D0 负
    input   wire                        AD1_D1p         , // 通道1 D1 正
    input   wire                        AD1_D1n         , // 通道1 D1 负
    input   wire                        AD2_D0p         , // 通道2 D0 正
    input   wire                        AD2_D0n         , // 通道2 D0 负
    input   wire                        AD2_D1p         , // 通道2 D1 正
    input   wire                        AD2_D1n         , // 通道2 D1 负
    input   wire                        AD3_D0p         , // 通道3 D0 正
    input   wire                        AD3_D0n         , // 通道3 D0 负
    input   wire                        AD3_D1p         , // 通道3 D1 正
    input   wire                        AD3_D1n         , // 通道3 D1 负
    input   wire                        AD4_D0p         , // 通道4 D0 正
    input   wire                        AD4_D0n         , // 通道4 D0 负
    input   wire                        AD4_D1p         , // 通道4 D1 正
    input   wire                        AD4_D1n         , // 通道4 D1 负

    // ===================== 数据输出 =====================
    output                  [13:0]      AD_out1         , // 通道1 输出数据（14bit）
    output                  [13:0]      AD_out2         , // 通道2 输出数据（14bit）
    output                  [13:0]      AD_out3         , // 通道3 输出数据（14bit）
    output                  [13:0]      AD_out4         , // 通道4 输出数据（14bit）
    output                              O_fco_0           // 帧同步时钟输出（分频后）
);

    // ===================== 内部信号定义 =====================
    wire                                bit_clk         ; // 位时钟（BUFIO 输出，用于 ISERDES）
    wire                                W_fc_clk        ; // 帧时钟（BUFR 分频 4 倍后，80MHz）
    (*mark_debug = "true"*) wire        R_bit_slip      ; // 位滑动控制信号（来自 fco_bitslip）
    wire                                BitClk          ; // 原始位时钟（来自 IBUFDS）
    wire                                frame_done      ; // 帧对齐完成信号（未输出，但内部使用）

    assign O_fco_0 = W_fc_clk;

    // ===================== IBUFDS（差分输入缓冲） =====================
    IBUFDS #(
        .DIFF_TERM("TRUE"),         // 差分端接
        .IBUF_LOW_PWR("FALSE"),     // 低功耗模式关闭，高性能
        .IOSTANDARD("LVDS_25")      // I/O 标准
    ) IBUFDS_inst10 (
        .O  (BitClk),               // 缓冲输出
        .I  (DCO_p),                // 差分正输入
        .IB (DCO_n)                 // 差分负输入
    );

    // ===================== BUFR（时钟分频器） =====================
    BUFR #(
        .BUFR_DIVIDE("4"),          // 分频系数 4
        .SIM_DEVICE("7SERIES")      // 仿真器件系列
    ) BUFR_inst_4 (
        .O  (W_fc_clk),             // 分频后时钟输出（80MHz）
        .CE (1'b1),                 // 时钟使能（常高）
        .CLR(1'b0),                 // 异步清除（无效）
        .I  (BitClk)                // 输入时钟（320MHz）
    );

    // ===================== BUFIO（时钟缓冲，用于驱动 I/O 时钟） =====================
    BUFIO BUFIO_p (
        .O  (bit_clk),              // 输出位时钟
        .I  (BitClk)                // 输入原始位时钟
    );

    // ===================== 复位延时计数器（用于 ISERDES 初始化） =====================
    // 仿真用：延时 625 个帧时钟周期（约 50us），等待 ADC 上电稳定
    reg [24:0] iser_rst_cnt = 25'd0;
    always @(posedge W_fc_clk) begin
        if (iser_rst_cnt == 25'd625)
            iser_rst_cnt <= iser_rst_cnt;
        else
            iser_rst_cnt <= iser_rst_cnt + 1'b1;
    end
    wire iser_rst;
    assign iser_rst = (iser_rst_cnt == 25'd625) ? 1'b0 : 1'b1;

    // ===================== fco_bitslip（FCO 位滑动对齐模块） =====================
    fco_bitslip fco_bitslip_inst (
        .I_reset_n      (!iser_rst      ), // 复位（低有效）
        .bit_clk        (bit_clk        ), // 位时钟
        .W_fc_clk       (W_fc_clk       ), // 帧时钟
        .frame_done     (frame_done     ), // 帧对齐完成
        .R_bit_slip     (R_bit_slip     ), // 位滑动控制
        .fco            (fco            )  // 原始 FCO 输入
    );

    // ===================== data_bitslip（数据位滑动对齐模块，四通道） =====================
    data_bitslip data_bitslip_inst1 (
        .I_reset_n      (!iser_rst      ), // 复位
        .bit_clk        (bit_clk        ), // 位时钟
        .W_fc_clk       (W_fc_clk       ), // 帧时钟
        .R_bit_slip     (R_bit_slip     ), // 位滑动控制
        .frame_done     (frame_done     ), // 帧对齐完成
        .I_ad_lvds_d0_p (AD1_D0p        ), // 通道1 D0+
        .I_ad_lvds_d0_n (AD1_D0n        ), // 通道1 D0-
        .I_ad_lvds_d1_p (AD1_D1p        ), // 通道1 D1+
        .I_ad_lvds_d1_n (AD1_D1n        ), // 通道1 D1-
        .ad_data        (AD_out1        )  // 通道1 输出数据
    );

    data_bitslip data_bitslip_inst2 (
        .I_reset_n      (!iser_rst      ),
        .bit_clk        (bit_clk        ),
        .W_fc_clk       (W_fc_clk       ),
        .R_bit_slip     (R_bit_slip     ),
        .frame_done     (frame_done     ),
        .I_ad_lvds_d0_p (AD2_D0p        ),
        .I_ad_lvds_d0_n (AD2_D0n        ),
        .I_ad_lvds_d1_p (AD2_D1p        ),
        .I_ad_lvds_d1_n (AD2_D1n        ),
        .ad_data        (AD_out2        )
    );

    data_bitslip data_bitslip_inst3 (
        .I_reset_n      (!iser_rst      ),
        .bit_clk        (bit_clk        ),
        .W_fc_clk       (W_fc_clk       ),
        .R_bit_slip     (R_bit_slip     ),
        .frame_done     (frame_done     ),
        .I_ad_lvds_d0_p (AD3_D0p        ),
        .I_ad_lvds_d0_n (AD3_D0n        ),
        .I_ad_lvds_d1_p (AD3_D1p        ),
        .I_ad_lvds_d1_n (AD3_D1n        ),
        .ad_data        (AD_out3        )
    );

    data_bitslip data_bitslip_inst4 (
        .I_reset_n      (!iser_rst      ),
        .bit_clk        (bit_clk        ),
        .W_fc_clk       (W_fc_clk       ),
        .R_bit_slip     (R_bit_slip     ),
        .frame_done     (frame_done     ),
        .I_ad_lvds_d0_p (AD4_D0p        ),
        .I_ad_lvds_d0_n (AD4_D0n        ),
        .I_ad_lvds_d1_p (AD4_D1p        ),
        .I_ad_lvds_d1_n (AD4_D1n        ),
        .ad_data        (AD_out4        )
    );

endmodule