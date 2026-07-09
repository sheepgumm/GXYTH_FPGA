`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Deng Yukun
// 
// Create Date: 2026/01/01 15:52:12
// Design Name: 
// Module Name: uart_tx
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

module uart_tx
(
    // ===================== 时钟与复位 =====================
    input                           I_clk               , // 系统时钟
    input                           I_rst               , // 复位信号（低有效？）
    input                           I_txclk             , // 发送波特率时钟（16倍过采样）

    // ===================== 发送数据与控制 =====================
    input                   [7:0]   I_tx_data           , // 待发送的 8bit 数据
    input                           I_tx_en             , // 发送使能（上升沿触发发送）
    input                           spi_done            , // SPI 完成信号（测试用，未使用）

    // ===================== 输出信号 =====================
    output reg                      O_tx                , // UART 发送数据输出
    output reg                      O_tx_busy             // 发送忙标志
);

    // ===================== 内部信号定义 =====================
    reg                     [3:0]   tx_cnt              ; // 发送位计数器（0~10）
    reg                     [7:0]   data                ; // 发送数据缓存
    reg                     [3:0]   odd                 ; // 奇偶校验累加器（未使用奇偶校验功能）
    reg                     [1:0]   txclk_sample        ; // txclk 同步打拍

    // ===================== txclk 同步打拍 =====================
    always @(posedge I_clk or negedge I_rst) begin
        if (!I_rst) begin
            txclk_sample <= 2'b00;
        end else begin
            txclk_sample[0] <= I_txclk;
            txclk_sample[1] <= txclk_sample[0];
        end
    end

    // ===================== 发送状态机 =====================
    always @(posedge I_clk or negedge I_rst) begin
        if (!I_rst) begin
            tx_cnt      <= 4'd0;
            data        <= 8'd0;
            odd         <= 4'd0;
            O_tx        <= 1'b1; // 空闲时 TX 为高
            O_tx_busy   <= 1'b0;
        end else begin
            if (txclk_sample == 2'b01) begin // 在 txclk 上升沿处理发送
                // 检测到发送使能，加载数据并置忙
                if (I_tx_en) begin
                    data      <= I_tx_data;
                    O_tx_busy <= 1'b1;
                end

                if (O_tx_busy) begin
                    if (tx_cnt == 4'd0) begin
                        // 发送起始位（0）
                        O_tx    <= 1'b0;
                        tx_cnt  <= tx_cnt + 1'b1;
                    end else if (tx_cnt > 4'd0 && tx_cnt < 4'd9) begin
                        // 发送 8 个数据位（从 LSB 到 MSB）
                        O_tx    <= data[tx_cnt - 1'b1];
                        odd     <= odd + data[tx_cnt - 1'b1];
                        tx_cnt  <= tx_cnt + 1'b1;
                    end else if (tx_cnt == 4'd9) begin
                        // 发送停止位（1）
                        O_tx    <= 1'b1;
                        tx_cnt  <= tx_cnt + 1'b1;
                    end else if (tx_cnt == 4'd10) begin
                        // 发送完成，复位状态
                        O_tx      <= 1'b1;
                        tx_cnt    <= 4'd0;
                        O_tx_busy <= 1'b0;
                        odd       <= 4'd0;
                    end
                end
            end
        end
    end

endmodule