`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Deng Yukun
// 
// Create Date: 2026/01/01 15:52:12
// Design Name: 
// Module Name: temp_sample
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

module temp_sample
(
    // ===================== 时钟与复位 =====================
    input                           I_clk               , // 系统时钟（用于 DS18B20）
    input                           clk_100M            , // 100MHz 时钟（用于 AD7998）
    input                           I_rst               , // 复位信号

    // ===================== DS18B20 接口 =====================
    inout                           IO_ds18b20_1_dq     , // DS18B20 1 数据线
    inout                           IO_ds18b20_2_dq     , // DS18B20 2 数据线
    output                          O_temp1_rdy         , // 温度1 就绪信号
    output                          O_temp2_rdy         , // 温度2 就绪信号
    (*mark_debug = "true"*) output  [15:0]  O_temperature1 , // 温度1 数据
    output                  [15:0]  O_temperature2     , // 温度2 数据

    // ===================== AD7998 接口 =====================
    inout                           sda                 , // AD7998 I2C 数据线
    (*mark_debug = "true"*) output  scl                 , // AD7998 I2C 时钟线
    (*mark_debug = "true"*) output  convst              , // AD7998 转换启动信号
    (*mark_debug = "true"*) input   Alt_busy            , // AD7998 忙标志
    (*mark_debug = "true"*) output  [15:0]  o_rd_data   , // AD7998 读取数据
    (*mark_debug = "true"*) output  o_rd_data_vaild       // AD7998 数据有效标志
);

    // ===================== DS18B20 温度传感器实例化 =====================
    // 读取 DS18B20 1 的温度数据，输出 16 位温度值及就绪信号
    ds18b20 U7_1 (
        .I_clk          (I_clk              ), // 系统时钟
        .I_rst          (I_rst              ), // 复位信号
        .IO_ds18b20_dq  (IO_ds18b20_1_dq    ), // DS18B20 数据线
        .O_temp_rdy     (O_temp1_rdy        ), // 温度就绪
        .O_temperature  (O_temperature1     )  // 温度数据
    );

    // 读取 DS18B20 2 的温度数据，输出 16 位温度值及就绪信号
    ds18b20 U7_2 (
        .I_clk          (I_clk              ), // 系统时钟
        .I_rst          (I_rst              ), // 复位信号
        .IO_ds18b20_dq  (IO_ds18b20_2_dq    ), // DS18B20 数据线
        .O_temp_rdy     (O_temp2_rdy        ), // 温度就绪
        .O_temperature  (O_temperature2     )  // 温度数据
    );

    // ===================== AD7998 ADC 控制器实例化 =====================
    // 通过 I2C 接口读取 AD7998 多通道 ADC 数据，输出转换结果及有效标志
    ad7998_ctrl U7_3 (
        .SysClk         (clk_100M           ), // 100MHz 系统时钟
        .SysReset_p     (!I_rst             ), // 复位信号（高有效）
        .sda            (sda                ), // I2C 数据线
        .scl            (scl                ), // I2C 时钟线
        .convst         (convst             ), // 转换启动
        .Alt_busy       (Alt_busy           ), // 忙标志
        .o_rd_data      (o_rd_data          ), // 读取数据
        .o_rd_data_vaild(o_rd_data_vaild    )  // 数据有效
    );

endmodule