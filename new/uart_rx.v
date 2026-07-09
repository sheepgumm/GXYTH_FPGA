`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Deng Yukun
// 
// Create Date: 2026/01/01 15:52:12
// Design Name: 
// Module Name: uart_rx
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

module uart_rx
(
    // ===================== 时钟与复位 =====================
    input                           I_clk               , // 系统时钟
    input                           I_rst               , // 复位信号（低有效）
    input                           I_rxclk             , // 接收波特率时钟（16倍过采样）
    input                           I_rx                , // UART 接收数据输入
    input                           I_get_data          , // 读取数据触发（外部拉高后清除接收完成标志）

    // ===================== 数据输出 =====================
    output reg              [7:0]   O_rx_data           , // 接收到的 8bit 数据
    output reg                      O_rx_rdy              // 接收数据就绪标志
);

    // ===================== 内部信号定义 =====================
    reg                             odd                 ; // 奇偶校验累加（内部）
    reg                             rx_odd              ; // 接收到的奇偶校验位
    reg                             odd_err             ; // 奇偶校验错误标志
    reg                     [2:0]   rx_sample           ; // 接收数据采样打拍（用于边沿检测）
    reg                     [3:0]   rx_fsm              ; // 接收状态机
    reg                     [7:0]   data                ; // 接收数据移位寄存器
    reg                     [3:0]   rx_cnt              ; // 过采样计数器（0~14）
    reg                             sample_startbit     ; // 正在采样起始位标志
    reg                     [3:0]   startbit_cnt        ; // 起始位低电平计数
    reg                     [1:0]   one_cnt             ; // 三位采样中高电平计数（多数判决）
    reg                             stopbit_err         ; // 停止位错误标志
    reg                     [1:0]   rxclk_sample        ; // rxclk 同步打拍

    wire                            neg_rx              ; // I_rx 下降沿检测（起始位检测）

    // ===================== 边沿检测 =====================
    assign neg_rx = ((!I_rx) & (rx_sample[2])); // 下降沿检测

    // ===================== rxclk 同步打拍 =====================
    always @(posedge I_clk or negedge I_rst) begin
        if (!I_rst) begin
            rxclk_sample <= 2'b00;
        end else begin
            rxclk_sample[0] <= I_rxclk;
            rxclk_sample[1] <= rxclk_sample[0];
        end
    end

    // ===================== 接收数据采样打拍 =====================
    // 在 rxclk 的上升沿同步采样 I_rx，用于稳定判断
    always @(posedge I_clk or negedge I_rst) begin
        if (!I_rst) begin
            rx_sample <= 3'd0;
        end else begin
            if (rxclk_sample == 2'b01) begin // rxclk 上升沿
                rx_sample[0] <= I_rx;
                rx_sample[1] <= rx_sample[0];
                rx_sample[2] <= rx_sample[1];
            end
        end
    end

    // ===================== 接收状态机 =====================
    always @(posedge I_clk or negedge I_rst) begin
        if (!I_rst) begin
            rx_cnt          <= 4'd0;
            data            <= 8'd0;
            rx_fsm          <= 4'd0;
            sample_startbit <= 1'b0;
            startbit_cnt    <= 4'd0;
            one_cnt         <= 2'd0;
            odd             <= 1'b0;
            rx_odd          <= 1'b0;
            odd_err         <= 1'b0;
            stopbit_err     <= 1'b0;
            O_rx_data       <= 8'd0;
            O_rx_rdy        <= 1'b0;
        end else begin
            if (rxclk_sample == 2'b01) begin // 在 rxclk 上升沿处理接收
                case (rx_fsm)
                    // ====== 状态 0：等待起始位 ======
                    0: begin
                        stopbit_err <= 1'b0;
                        if (neg_rx) begin // 检测到 I_rx 下降沿，可能为起始位
                            sample_startbit <= 1'b1;
                        end
                        if (sample_startbit) begin
                            if (rx_cnt < 13) begin // 连续采样 13 个 rxclk 周期
                                if (I_rx == 1'b0) begin
                                    startbit_cnt <= startbit_cnt + 1'b1;
                                end
                                rx_cnt <= rx_cnt + 1'b1;
                            end else begin
                                // 如果低电平采样次数 > 8，认为起始位有效
                                if (startbit_cnt > 8) begin
                                    rx_fsm          <= 4'd1;
                                    rx_cnt          <= 4'd0;
                                    startbit_cnt    <= 4'd0;
                                    sample_startbit <= 1'b0;
                                end else begin
                                    rx_fsm          <= 4'd0;
                                    rx_cnt          <= 4'd0;
                                    startbit_cnt    <= 4'd0;
                                    sample_startbit <= 1'b0;
                                end
                            end
                        end
                    end

                    // ====== 状态 1~8：接收 8 个数据位 ======
                    // 每个状态在 15 个 rxclk 周期内采样 3 次（在 rx_cnt=3,6,9 时），多数判决
                    1: begin
                        if (rx_cnt < 15) begin
                            rx_cnt <= rx_cnt + 1'b1;
                            if (rx_cnt == 3) begin
                                if (I_rx) one_cnt <= one_cnt + 1'b1;
                            end
                            if (rx_cnt == 6) begin
                                if (I_rx) one_cnt <= one_cnt + 1'b1;
                            end
                            if (rx_cnt == 9) begin
                                if (I_rx) one_cnt <= one_cnt + 1'b1;
                            end
                        end else begin
                            rx_fsm <= 4'd2;
                            rx_cnt <= 4'd0;
                            if (one_cnt >= 2) begin // 多数判决为 1
                                data[0] <= 1'b1;
                                odd    <= odd + 1'b1; // 奇偶校验累加
                            end else begin
                                data[0] <= 1'b0;
                            end
                            one_cnt <= 2'd0;
                        end
                    end

                    2: begin
                        if (rx_cnt < 15) begin
                            rx_cnt <= rx_cnt + 1'b1;
                            if (rx_cnt == 3) begin
                                if (I_rx) one_cnt <= one_cnt + 1'b1;
                            end
                            if (rx_cnt == 6) begin
                                if (I_rx) one_cnt <= one_cnt + 1'b1;
                            end
                            if (rx_cnt == 9) begin
                                if (I_rx) one_cnt <= one_cnt + 1'b1;
                            end
                        end else begin
                            rx_fsm <= 4'd3;
                            rx_cnt <= 4'd0;
                            if (one_cnt >= 2) begin
                                data[1] <= 1'b1;
                                odd    <= odd + 1'b1;
                            end else begin
                                data[1] <= 1'b0;
                            end
                            one_cnt <= 2'd0;
                        end
                    end

                    3: begin
                        if (rx_cnt < 15) begin
                            rx_cnt <= rx_cnt + 1'b1;
                            if (rx_cnt == 3) begin
                                if (I_rx) one_cnt <= one_cnt + 1'b1;
                            end
                            if (rx_cnt == 6) begin
                                if (I_rx) one_cnt <= one_cnt + 1'b1;
                            end
                            if (rx_cnt == 9) begin
                                if (I_rx) one_cnt <= one_cnt + 1'b1;
                            end
                        end else begin
                            rx_fsm <= 4'd4;
                            rx_cnt <= 4'd0;
                            if (one_cnt >= 2) begin
                                data[2] <= 1'b1;
                                odd    <= odd + 1'b1;
                            end else begin
                                data[2] <= 1'b0;
                            end
                            one_cnt <= 2'd0;
                        end
                    end

                    4: begin
                        if (rx_cnt < 15) begin
                            rx_cnt <= rx_cnt + 1'b1;
                            if (rx_cnt == 3) begin
                                if (I_rx) one_cnt <= one_cnt + 1'b1;
                            end
                            if (rx_cnt == 6) begin
                                if (I_rx) one_cnt <= one_cnt + 1'b1;
                            end
                            if (rx_cnt == 9) begin
                                if (I_rx) one_cnt <= one_cnt + 1'b1;
                            end
                        end else begin
                            rx_fsm <= 4'd5;
                            rx_cnt <= 4'd0;
                            if (one_cnt >= 2) begin
                                data[3] <= 1'b1;
                                odd    <= odd + 1'b1;
                            end else begin
                                data[3] <= 1'b0;
                            end
                            one_cnt <= 2'd0;
                        end
                    end

                    5: begin
                        if (rx_cnt < 15) begin
                            rx_cnt <= rx_cnt + 1'b1;
                            if (rx_cnt == 3) begin
                                if (I_rx) one_cnt <= one_cnt + 1'b1;
                            end
                            if (rx_cnt == 6) begin
                                if (I_rx) one_cnt <= one_cnt + 1'b1;
                            end
                            if (rx_cnt == 9) begin
                                if (I_rx) one_cnt <= one_cnt + 1'b1;
                            end
                        end else begin
                            rx_fsm <= 4'd6;
                            rx_cnt <= 4'd0;
                            if (one_cnt >= 2) begin
                                data[4] <= 1'b1;
                                odd    <= odd + 1'b1;
                            end else begin
                                data[4] <= 1'b0;
                            end
                            one_cnt <= 2'd0;
                        end
                    end

                    6: begin
                        if (rx_cnt < 15) begin
                            rx_cnt <= rx_cnt + 1'b1;
                            if (rx_cnt == 3) begin
                                if (I_rx) one_cnt <= one_cnt + 1'b1;
                            end
                            if (rx_cnt == 6) begin
                                if (I_rx) one_cnt <= one_cnt + 1'b1;
                            end
                            if (rx_cnt == 9) begin
                                if (I_rx) one_cnt <= one_cnt + 1'b1;
                            end
                        end else begin
                            rx_fsm <= 4'd7;
                            rx_cnt <= 4'd0;
                            if (one_cnt >= 2) begin
                                data[5] <= 1'b1;
                                odd    <= odd + 1'b1;
                            end else begin
                                data[5] <= 1'b0;
                            end
                            one_cnt <= 2'd0;
                        end
                    end

                    7: begin
                        if (rx_cnt < 15) begin
                            rx_cnt <= rx_cnt + 1'b1;
                            if (rx_cnt == 3) begin
                                if (I_rx) one_cnt <= one_cnt + 1'b1;
                            end
                            if (rx_cnt == 6) begin
                                if (I_rx) one_cnt <= one_cnt + 1'b1;
                            end
                            if (rx_cnt == 9) begin
                                if (I_rx) one_cnt <= one_cnt + 1'b1;
                            end
                        end else begin
                            rx_fsm <= 4'd8;
                            rx_cnt <= 4'd0;
                            if (one_cnt >= 2) begin
                                data[6] <= 1'b1;
                                odd    <= odd + 1'b1;
                            end else begin
                                data[6] <= 1'b0;
                            end
                            one_cnt <= 2'd0;
                        end
                    end

                    8: begin
                        if (rx_cnt < 15) begin
                            rx_cnt <= rx_cnt + 1'b1;
                            if (rx_cnt == 3) begin
                                if (I_rx) one_cnt <= one_cnt + 1'b1;
                            end
                            if (rx_cnt == 6) begin
                                if (I_rx) one_cnt <= one_cnt + 1'b1;
                            end
                            if (rx_cnt == 9) begin
                                if (I_rx) one_cnt <= one_cnt + 1'b1;
                            end
                        end else begin
                            rx_fsm <= 4'd9;
                            rx_cnt <= 4'd0;
                            if (one_cnt >= 2) begin
                                data[7] <= 1'b1;
                                odd    <= odd + 1'b1;
                            end else begin
                                data[7] <= 1'b0;
                            end
                            one_cnt <= 2'd0;
                        end
                    end

                    // ====== 状态 9：接收停止位 ======
                    9: begin
                        rx_cnt <= rx_cnt + 1'b1;
                        if (rx_cnt == 3) begin
                            if (!I_rx) one_cnt <= one_cnt + 1'b1;
                        end
                        if (rx_cnt == 5) begin
                            if (!I_rx) one_cnt <= one_cnt + 1'b1;
                        end
                        if (rx_cnt == 8) begin
                            if (!I_rx) one_cnt <= one_cnt + 1'b1;
                        end
                        if (rx_cnt == 9) begin
                            // 若采样到低电平次数 >= 2，说明停止位错误（应为高电平）
                            if (one_cnt >= 2) begin
                                stopbit_err <= 1'b1;
                                rx_fsm      <= 4'd0;
                                rx_cnt      <= 4'd0;
                                one_cnt     <= 2'd0;
                            end else begin
                                stopbit_err <= 1'b0;
                                rx_fsm      <= 4'd0;
                                O_rx_rdy    <= 1'b1; // 接收完成
                                O_rx_data   <= data;
                                rx_cnt      <= 4'd0;
                                one_cnt     <= 2'd0;
                            end
                        end
                    end

                    default: begin
                        rx_fsm  <= 4'd0;
                        rx_cnt  <= 4'd0;
                        one_cnt <= 2'd0;
                    end
                endcase

                // 外部读取数据后，清除就绪标志
                if (I_get_data) begin
                    stopbit_err <= 1'b0;
                    O_rx_rdy    <= 1'b0;
                    odd_err     <= 1'b0;
                    data        <= 8'd0;
                end
            end
        end
    end

endmodule