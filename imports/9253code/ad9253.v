`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Deng Yukun
// 
// Create Date: 2026/01/01 15:52:12
// Design Name: 
// Module Name: ad9253
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

module ad9253
(
    // ===================== 时钟与复位 =====================
    input                           clk_sys             , // 系统时钟（80MHz）
    input                           clk_ad              , // ADC 采样时钟（用于输出给 ADC）
    input                           rst_n               , // 复位信号（低有效）

    // ===================== ADC 差分输入 =====================
    input                   [1:0]   ad0dclk             , // ADC DCO 差分时钟（320MHz）
    input                   [1:0]   ad0fclk             , // ADC FCO 差分时钟（80MHz）
    input                   [15:0]  ad0data             , // ADC 数据输入（16 个单端信号，对应四通道 LVDS）

    // ===================== ADC 数据输出 =====================
    output                  [13:0]  cha_data            , // 通道 A 输出数据
    output                  [13:0]  chb_data            , // 通道 B 输出数据
    output                  [13:0]  chc_data            , // 通道 C 输出数据
    output                  [13:0]  chd_data            , // 通道 D 输出数据
    output                          fco_0               , // 帧同步时钟输出

    // ===================== ADC 配置接口（SPI） =====================
    output                          adsclk              , // ADC SPI 时钟
    output                          adcsb               , // ADC SPI 片选（低有效）
    output                          adsync              , // ADC 同步信号（未使用）
    inout                           adsdio              , // ADC SPI 数据（双向）
    output                          ad_clk_p            , // 输出给 ADC 的差分时钟正
    output                          ad_clk_n            , // 输出给 ADC 的差分时钟负
    output                          adpdwn                // ADC 掉电控制
);

    // ===================== 内部信号定义 =====================
    reg                             sync                ; // 同步信号（未使用）
    reg                             clk_4M              ; // 4MHz 分频时钟（用于 SPI）
    reg                     [7:0]   clk_4M_cnt          ; // 分频计数器

    // ===================== ADC 差分时钟输出（OBUFDS） =====================
    // 将内部 clk_ad 转换为 LVDS 差分时钟输出给 ADC
    OBUFDS #(
        .IOSTANDARD ("LVDS_25"      ), // I/O 标准
        .SLEW       ("SLOW"         )  // 压摆率
    ) OBUFDS_inst_0 (
        .O  (ad_clk_p                ), // 正输出
        .OB (ad_clk_n                ), // 负输出
        .I  (clk_ad                  )  // 输入时钟
    );

    // ===================== 4MHz SPI 时钟生成（从 80MHz 分频） =====================
    // 80MHz 分频得到 4MHz，用于 ADC SPI 配置
    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            clk_4M     <= 1'b0;
            clk_4M_cnt <= 8'd0;
        end else begin
            if (clk_4M_cnt == 8'd9) begin // 80M / (10*2) = 4MHz
                clk_4M     <= ~clk_4M;
                clk_4M_cnt <= 8'd0;
            end else begin
                clk_4M_cnt <= clk_4M_cnt + 1'b1;
            end
        end
    end

    assign adsync = 1'b0; // 同步信号固定为 0

    // ===================== ADC 接口模块实例化（ad_ios） =====================
    ad_ios ad_inst (
        .ad0dclk        (ad0dclk        ), // ADC DCO 差分时钟
        .ad0fclk        (ad0fclk        ), // ADC FCO 差分时钟
        .ad0data        (ad0data        ), // ADC 数据输入
        .clk_sys        (clk_sys        ), // 系统时钟
        .clk_spi        (clk_4M         ), // SPI 时钟（4MHz）
        .rst_n          (rst_n          ), // 复位
        .adsclk         (adsclk         ), // SPI 时钟输出
        .adcsb          (adcsb          ), // SPI 片选
        .adsdio         (adsdio         ), // SPI 数据
        .adpdwn         (adpdwn         ), // 掉电控制
        .fco_0          (fco_0          ), // 帧时钟输出
        .ad_out00       (cha_data       ), // 通道 A
        .ad_out01       (chb_data       ), // 通道 B
        .ad_out02       (chc_data       ), // 通道 C
        .ad_out03       (chd_data       )  // 通道 D
    );

endmodule