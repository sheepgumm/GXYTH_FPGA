`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Deng Yukun
// 
// Create Date: 2026/01/01 15:52:12
// Design Name: 
// Module Name: uart_baudrate
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

module uart_baudrate
(
    // ===================== 时钟与复位 =====================
    input                           I_clk               , // 系统时钟（80MHz）
    input                           I_rst               , // 复位信号

    // ===================== 波特率时钟输出 =====================
    output                          O_txclk             , // 发送波特率时钟（16倍过采样）
    output                          O_rxclk               // 接收波特率时钟（16倍过采样）
);

    // ===================== 参数定义 =====================
    // 波特率 = 115200 bps，系统时钟 80MHz
    // 过采样倍数 = 16
    // rxclk 频率 = 115200 * 16 = 1.8432 MHz
    // 分频系数 = 80M / 1.8432M ≈ 43.4，取整为 44
    // 占空比 50%：高电平持续 22 个周期，低电平持续 22 个周期
    parameter rx_div1 = 22;           // rxclk 高电平持续时间（周期数）
    parameter rx_div2 = 44;           // rxclk 一个完整周期（44 个系统时钟周期）

    // txclk 频率 = 115200 Hz（波特率）
    // 分频系数 = 80M / 115200 ≈ 694.4，取整为 695
    // 占空比 50%：高电平持续 348 个周期，低电平持续 347 个周期
    parameter tx_div3 = 348;          // txclk 高电平持续时间（周期数）
    parameter tx_div4 = 695;          // txclk 一个完整周期（695 个系统时钟周期）

    // ===================== 内部信号定义 =====================
    reg                     [6:0]   rx_cnt              ; // rxclk 计数器（0~43）
    reg                     [10:0]  tx_cnt              ; // txclk 计数器（0~694）
    reg                             rx_clkout           ; // rxclk 内部寄存器
    reg                             tx_clkout           ; // txclk 内部寄存器

    // ===================== 输出赋值 =====================
    assign O_rxclk = rx_clkout;
    assign O_txclk = tx_clkout;

    // ===================== 接收波特率时钟生成 =====================
    always @(posedge I_clk) begin
        if (!I_rst) begin
            rx_cnt    <= 7'd0;
            rx_clkout <= 1'b0;
        end else begin
            if (rx_cnt == rx_div1) begin
                rx_clkout <= 1'b1;
                rx_cnt    <= rx_cnt + 1'b1;
            end else if (rx_cnt == rx_div2) begin
                rx_clkout <= 1'b0;
                rx_cnt    <= 7'd0;
            end else begin
                rx_cnt <= rx_cnt + 1'b1;
            end
        end
    end

    // ===================== 发送波特率时钟生成 =====================
    always @(posedge I_clk) begin
        if (!I_rst) begin
            tx_cnt    <= 11'd0;
            tx_clkout <= 1'b0;
        end else begin
            if (tx_cnt == tx_div3) begin
                tx_cnt    <= tx_cnt + 1'b1;
                tx_clkout <= 1'b1;
            end else if (tx_cnt == tx_div4) begin
                tx_clkout <= 1'b0;
                tx_cnt    <= 11'd0;
            end else begin
                tx_cnt <= tx_cnt + 1'b1;
            end
        end
    end

endmodule