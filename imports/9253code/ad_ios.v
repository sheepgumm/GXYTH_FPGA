`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Deng Yukun
// 
// Create Date: 2026/01/01 15:52:12
// Design Name: 
// Module Name: ad_ios
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

module ad_ios
(
    // ===================== ADC 差分时钟输入 =====================
    input   wire                [1:0]       ad0dclk         , // ADC DCO 差分时钟（320MHz）
    input   wire                [1:0]       ad0fclk         , // ADC FCO 差分时钟（80MHz）
    input   wire                [15:0]      ad0data         , // ADC 数据输入（16 个单端信号，对应四通道 LVDS）

    // ===================== 时钟与复位 =====================
    input   wire                            clk_sys         , // 系统时钟（80MHz）
    input   wire                            clk_spi         , // SPI 配置时钟（20MHz）
    input   wire                            rst_n           , // 复位信号（低有效）

    // ===================== ADC 配置接口（SPI） =====================
    output  wire                            adsclk          , // ADC SPI 时钟
    output  wire                            adcsb           , // ADC SPI 片选（低有效）
    inout   wire                            adsdio          , // ADC SPI 数据（双向）
    output  wire                            adpdwn          , // ADC 掉电控制（低有效）

    // ===================== ADC 数据输出 =====================
    output                                  fco_0           , // 帧同步时钟输出（分频后）
    output  wire                [13:0]      ad_out00        , // 通道1 输出数据
    output  wire                [13:0]      ad_out01        , // 通道2 输出数据
    output  wire                [13:0]      ad_out02        , // 通道3 输出数据
    output  wire                [13:0]      ad_out03          // 通道4 输出数据
);

    // ===================== 内部信号定义 =====================
    wire                            SCLK            ; // SPI 时钟（内部）
    wire                            CSB             ; // SPI 片选（内部）
    wire                            SDIO            ; // SPI 数据（内部）

    reg                             spi_en          ; // SPI 配置使能
    reg                     [31:0]  cnt             ; // 延时计数器
    wire                            image_en        ; // 图像使能（固定为 1，未使用）

    wire                            fco_temp        ; // FCO 差分转单端后的信号

    // ===================== ADC 上电延时与 SPI 使能 =====================
    // 延时约 2 秒（20MHz 时钟下）后开启 SPI 配置
    always @(posedge clk_spi) begin
        if (!rst_n) begin
            spi_en <= 1'b0;
            cnt    <= 32'd0;
        end else if (cnt == 32'd19_999_998) begin
            spi_en <= 1'b1;
            cnt    <= cnt;
        end else begin
            cnt <= cnt + 1'b1;
        end
    end

    assign image_en = 1'b1; // 固定使能
    assign adpdwn   = 1'b0; // ADC 掉电无效（正常工作）

    // ===================== SPI 配置模块实例化 =====================
    spi_config spi_config_inst (
        .clk_spi    (clk_spi        ),
        .rst_n      (rst_n          ),
        .image_en   (image_en       ),
        .spi_en     (spi_en         ),
        .SCLK       (SCLK           ),
        .spi_done   (               ),
        .CSB        (CSB            ),
        .Tri_en     (               ),
        .SDIO       (SDIO           )
    );

    // 将内部 SPI 信号连接到顶层端口
    assign adsclk = SCLK;
    assign adcsb  = CSB;
    assign adsdio = SDIO;

    // ===================== FCO 差分输入转单端 =====================
    IBUFDS #(
        .DIFF_TERM    ("TRUE"         ),
        .IBUF_LOW_PWR ("FALSE"        ),
        .IOSTANDARD   ("LVDS_25"      )
    ) IBUFDS_inst0 (
        .O  (fco_temp                 ),
        .I  (ad0fclk[0]               ),
        .IB (ad0fclk[1]               )
    );

    // ===================== ADC 数据接口模块实例化 =====================
    ad_interface ad_interface_inst0 (
        .rst_n      (rst_n          ),
        .DCO_p      (ad0dclk[0]     ),
        .DCO_n      (ad0dclk[1]     ),
        .fco        (fco_temp       ),
        .AD1_D0p    (ad0data[0]     ),
        .AD1_D0n    (ad0data[1]     ),
        .AD1_D1p    (ad0data[2]     ),
        .AD1_D1n    (ad0data[3]     ),
        .AD2_D0p    (ad0data[4]     ),
        .AD2_D0n    (ad0data[5]     ),
        .AD2_D1p    (ad0data[6]     ),
        .AD2_D1n    (ad0data[7]     ),
        .AD3_D0p    (ad0data[8]     ),
        .AD3_D0n    (ad0data[9]     ),
        .AD3_D1p    (ad0data[10]    ),
        .AD3_D1n    (ad0data[11]    ),
        .AD4_D0p    (ad0data[12]    ),
        .AD4_D0n    (ad0data[13]    ),
        .AD4_D1p    (ad0data[14]    ),
        .AD4_D1n    (ad0data[15]    ),
        .AD_out1    (ad_out00       ),
        .AD_out2    (ad_out01       ),
        .AD_out3    (ad_out02       ),
        .AD_out4    (ad_out03       ),
        .O_fco_0    (fco_0          )
    );

endmodule