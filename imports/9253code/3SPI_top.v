`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Deng Yukun
// 
// Create Date: 2026/01/01 15:52:12
// Design Name: 
// Module Name: spi_config
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

module spi_config
(
    // ===================== SPI 接口 =====================
    output                          SCLK                , // SPI 时钟
    inout                           SDIO                , // SPI 数据（双向）
    output                          CSB                 , // SPI 片选（低有效）

    // ===================== 控制信号 =====================
    input                           image_en            , // 图像使能（传入 ADC_CONFIGURE）
    input                           spi_en              , // SPI 配置使能

    // ===================== 时钟与复位 =====================
    input                           clk_spi             , // SPI 时钟源（20MHz）
    input                           rst_n               , // 复位信号（低有效）

    // ===================== 状态输出 =====================
    output                          spi_done            , // 配置完成标志
    output wire                     Tri_en                // FPGA 三态方向控制（1=输出，0=输入）
);

    // ===================== 内部信号 =====================
    wire                            sdin                ; // SDIO 输入信号（从 ADC 到 FPGA）
    wire                            sdout               ; // SDIO 输出信号（从 FPGA 到 ADC）

    // ===================== 三态总线控制 =====================
    // 使用 assign 实现双向 IO（替代 IOBUF 原语）
    // 当 Tri_en == 1 时，FPGA 驱动 SDIO（输出 sdout）；否则高阻（输入模式）
    assign sdin  = SDIO;                     // 读取外部输入
    assign SDIO = (Tri_en == 1'b1) ? sdout : 1'bz; // 三态输出

    // ===================== ADC_CONFIGURE 实例化 =====================
    ADC_CONFIGURE ADC_CONFIGURE_Inst1 (
        .reset      (rst_n          ), // 复位信号
        .CLK        (clk_spi        ), // 时钟 20MHz
        .image_en   (1'b1           ), // 图像使能（固定为 1）
        .spi_en     (spi_en         ), // SPI 配置使能
        .cs_b       (CSB            ), // SPI 片选输出
        .sdin       (sdin           ), // SPI 数据输入
        .sdout      (sdout          ), // SPI 数据输出
        .sclk       (SCLK           ), // SPI 时钟输出
        .CfgDone    (spi_done       ), // 配置完成标志
        .Tri_en     (Tri_en         )  // 三态方向控制
    );

endmodule