`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Deng Yukun
// 
// Create Date: 2026/01/01 15:52:12
// Design Name: 
// Module Name: ds18b20
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

module ds18b20
(
    // ===================== 时钟与复位 =====================
    input                           I_clk               , // 系统时钟（80MHz）
    input                           I_rst               , // 复位信号

    // ===================== DS18B20 接口 =====================
    inout                           IO_ds18b20_dq       , // 1-Wire 数据线（双向）

    // ===================== 温度数据输出 =====================
    output                          O_temp_rdy          , // 温度数据就绪
    output                  [15:0]  O_temperature         // 温度数据（原始值）
);

    // ===================== 内部信号定义 =====================
    reg                             ds18b20_rdy         ; // 温度就绪内部寄存器
    reg                     [15:0]  temperature_buf     ; // 采集的温度值，原始数据未处理
    assign O_temp_rdy      = ds18b20_rdy;
    assign O_temperature   = temperature_buf;

    // ---------- 内部复位生成 ----------
    reg                             rst_n               ; // 内部复位（经过延迟）
    reg                     [31:0]  cnt_rst             ; // 内部复位延时计数器
    always @(posedge I_clk) begin
        if (!I_rst) begin
            rst_n   <= 1'b0;
            cnt_rst <= 32'd0;
        end else begin
            if (cnt_rst < 32'h100000) begin
                rst_n   <= 1'b0;
                cnt_rst <= cnt_rst + 1'b1;
            end else begin
                rst_n   <= 1'b1;
            end
        end
    end

    // ---------- 1us 时钟生成（80MHz 分频） ----------
    reg                     [6:0]   cnt                 ; // 分频计数器（0~79）
    reg                             clk_1us             ; // 1us 脉冲
    always @(posedge I_clk) begin
        if (!rst_n) begin
            cnt     <= 7'd0;
            clk_1us <= 1'b0;
        end else begin
            if (cnt == 7'd79) begin
                cnt <= 7'd0;
            end else begin
                cnt <= cnt + 1'b1;
            end
            if (cnt <= 7'd39) begin
                clk_1us <= 1'b0;
            end else begin
                clk_1us <= 1'b1;
            end
        end
    end

    // ---------- clk_1us 同步打拍 ----------
    reg                     [1:0]   clk_1us_sample      ; // 1us 时钟同步打拍
    always @(posedge I_clk) begin
        if (!rst_n) begin
            clk_1us_sample <= 2'b00;
        end else begin
            clk_1us_sample[0] <= clk_1us;
            clk_1us_sample[1] <= clk_1us_sample[0];
        end
    end

    // ---------- 微秒计数器 ----------
    reg                     [31:0]  cnt_1us             ; // 1us 计数
    reg                             cnt_1us_clear       ; // 计数清零标志
    always @(posedge I_clk) begin
        if (!rst_n) begin
            cnt_1us <= 32'd0;
        end else begin
            if (cnt_1us_clear) begin
                cnt_1us <= 32'd0;
            end else begin
                if (clk_1us_sample == 2'b01) begin
                    cnt_1us <= cnt_1us + 1'b1;
                end
            end
        end
    end

    // ---------- 状态机参数 ----------
    localparam S00     = 5'h00; // 初始状态
    localparam S0      = 5'h01; // 启动复位
    localparam S1      = 5'h03; // 等待复位低电平
    localparam S2      = 5'h02; // 等待存在脉冲
    localparam S3      = 5'h06; // 检测存在脉冲
    localparam S4      = 5'h07; // 复位完成等待
    localparam S5      = 5'h05; // 发送命令/数据
    localparam S6      = 5'h04; // 等待转换完成
    localparam S7      = 5'h0C; // 读取温度数据
    localparam WRITE0  = 5'h0D; // 写 0
    localparam WRITE1  = 5'h0F; // 写 1
    localparam WRITE00 = 5'h0E; // 写 0 结束
    localparam WRITE01 = 5'h0A; // 写 1 结束
    localparam READ0   = 5'h0B; // 读开始
    localparam READ1   = 5'h09; // 读采样
    localparam READ2   = 5'h08; // 读数据
    localparam READ3   = 5'h18; // 读完成等待

    reg                     [4:0]   state               ; // 状态机
    reg                             IO_ds18b20_dq_buf   ; // 数据线输出缓存
    reg                     [5:0]   step                ; // 子步骤计数器（0~50）
    reg                     [3:0]   bit_valid           ; // 当前读取的位索引
    reg                     [2:0]   cnt_timeout         ; // 超时计数器

    // ===================== 主状态机 =====================
    always @(posedge I_clk) begin
        if (!rst_n) begin
            IO_ds18b20_dq_buf <= 1'bZ;
            step              <= 6'd0;
            state             <= S00;
            ds18b20_rdy       <= 1'b0;
            temperature_buf   <= 16'h001F; // 默认值
            cnt_1us_clear     <= 1'b0;
            bit_valid         <= 4'd0;
            cnt_timeout       <= 3'd0;
        end else begin
            if (clk_1us_sample == 2'b01) begin
                case (state)
                    S00: begin
                        temperature_buf <= 16'h001F;
                        state           <= S0;
                        cnt_timeout     <= 3'd0;
                    end
                    S0: begin // 发起复位脉冲
                        cnt_1us_clear     <= 1'b1;
                        IO_ds18b20_dq_buf <= 1'b0;
                        ds18b20_rdy       <= 1'b0;
                        state             <= S1;
                    end
                    S1: begin // 保持复位低电平 500us
                        cnt_1us_clear <= 1'b0;
                        if (cnt_1us == 32'd500) begin
                            cnt_1us_clear     <= 1'b1;
                            IO_ds18b20_dq_buf <= 1'bZ; // 释放总线
                            state             <= S2;
                        end
                    end
                    S2: begin // 等待 DS18B20 的存在脉冲（低电平）
                        cnt_1us_clear <= 1'b0;
                        if (cnt_1us == 32'd20) begin // 等待 20us
                            cnt_1us_clear <= 1'b1;
                            state         <= S3;
                        end
                    end
                    S3: begin // 检测存在脉冲
                        if (!IO_ds18b20_dq) begin // 检测到低电平，复位成功
                            state <= S4;
                        end else if (IO_ds18b20_dq) begin // 未检测到，重新复位
                            cnt_timeout <= cnt_timeout + 1'b1;
                            if (cnt_timeout == 3'd5) begin
                                state <= S0; // 超时重试
                            end else begin
                                state <= S2;
                            end
                        end
                    end
                    S4: begin // 复位完成，等待 400us 后进入命令阶段
                        cnt_1us_clear <= 1'b0;
                        if (cnt_1us == 32'd400) begin
                            cnt_1us_clear <= 1'b1;
                            state         <= S5;
                        end
                    end
                    S5: begin // 发送命令（跳过 ROM 0xCC + 转换命令 0x44，再读取温度）
                        if (step == 6'd0) begin // 0xCC 的第 0 位
                            step  <= step + 1'b1;
                            state <= WRITE0;
                        end else if (step == 6'd1) begin
                            step  <= step + 1'b1;
                            state <= WRITE0;
                        end else if (step == 6'd2) begin
                            IO_ds18b20_dq_buf <= 1'b0;
                            step              <= step + 1'b1;
                            state             <= WRITE01;
                        end else if (step == 6'd3) begin
                            IO_ds18b20_dq_buf <= 1'b0;
                            step              <= step + 1'b1;
                            state             <= WRITE01;
                        end else if (step == 6'd4) begin
                            step  <= step + 1'b1;
                            state <= WRITE0;
                        end else if (step == 6'd5) begin
                            step  <= step + 1'b1;
                            state <= WRITE0;
                        end else if (step == 6'd6) begin
                            IO_ds18b20_dq_buf <= 1'b0;
                            step              <= step + 1'b1;
                            state             <= WRITE01;
                        end else if (step == 6'd7) begin
                            IO_ds18b20_dq_buf <= 1'b0;
                            step              <= step + 1'b1;
                            state             <= WRITE01;
                        end else if (step == 6'd8) begin // 0x44 命令开始
                            step  <= step + 1'b1;
                            state <= WRITE0;
                        end else if (step == 6'd9) begin
                            step  <= step + 1'b1;
                            state <= WRITE0;
                        end else if (step == 6'd10) begin
                            IO_ds18b20_dq_buf <= 1'b0;
                            step              <= step + 1'b1;
                            state             <= WRITE01;
                        end else if (step == 6'd11) begin
                            step  <= step + 1'b1;
                            state <= WRITE0;
                        end else if (step == 6'd12) begin
                            step  <= step + 1'b1;
                            state <= WRITE0;
                        end else if (step == 6'd13) begin
                            step  <= step + 1'b1;
                            state <= WRITE0;
                        end else if (step == 6'd14) begin
                            IO_ds18b20_dq_buf <= 1'b0;
                            step              <= step + 1'b1;
                            state             <= WRITE01;
                        end else if (step == 6'd15) begin
                            step  <= step + 1'b1;
                            state <= WRITE0;
                        end else if (step == 6'd16) begin // 发送完成，进入转换等待
                            IO_ds18b20_dq_buf <= 1'bZ;
                            step              <= step + 1'b1;
                            state             <= S6;
                        end
                        // 第二次通信：0xCC + 0xBE
                        else if (step == 6'd17) begin // 0xCC
                            step  <= step + 1'b1;
                            state <= WRITE0;
                        end else if (step == 6'd18) begin
                            step  <= step + 1'b1;
                            state <= WRITE0;
                        end else if (step == 6'd19) begin
                            IO_ds18b20_dq_buf <= 1'b0;
                            step              <= step + 1'b1;
                            state             <= WRITE01;
                        end else if (step == 6'd20) begin
                            step              <= step + 1'b1;
                            state             <= WRITE01;
                            IO_ds18b20_dq_buf <= 1'b0;
                        end else if (step == 6'd21) begin
                            step  <= step + 1'b1;
                            state <= WRITE0;
                        end else if (step == 6'd22) begin
                            step  <= step + 1'b1;
                            state <= WRITE0;
                        end else if (step == 6'd23) begin
                            IO_ds18b20_dq_buf <= 1'b0;
                            step              <= step + 1'b1;
                            state             <= WRITE01;
                        end else if (step == 6'd24) begin
                            IO_ds18b20_dq_buf <= 1'b0;
                            step              <= step + 1'b1;
                            state             <= WRITE01;
                        end else if (step == 6'd25) begin // 0xBE
                            step  <= step + 1'b1;
                            state <= WRITE0;
                        end else if (step == 6'd26) begin
                            IO_ds18b20_dq_buf <= 1'b0;
                            step              <= step + 1'b1;
                            state             <= WRITE01;
                        end else if (step == 6'd27) begin
                            IO_ds18b20_dq_buf <= 1'b0;
                            step              <= step + 1'b1;
                            state             <= WRITE01;
                        end else if (step == 6'd28) begin
                            IO_ds18b20_dq_buf <= 1'b0;
                            step              <= step + 1'b1;
                            state             <= WRITE01;
                        end else if (step == 6'd29) begin
                            IO_ds18b20_dq_buf <= 1'b0;
                            step              <= step + 1'b1;
                            state             <= WRITE01;
                        end else if (step == 6'd30) begin
                            IO_ds18b20_dq_buf <= 1'b0;
                            step              <= step + 1'b1;
                            state             <= WRITE01;
                        end else if (step == 6'd31) begin
                            step  <= step + 1'b1;
                            state <= WRITE0;
                        end else if (step == 6'd32) begin
                            IO_ds18b20_dq_buf <= 1'b0;
                            step              <= step + 1'b1;
                            state             <= WRITE01;
                        end else if (step == 6'd33) begin // 第二次发送完成，进入读取
                            step  <= step + 1'b1;
                            state <= S7;
                        end
                    end
                    S6: begin // 等待温度转换完成（750ms）
                        cnt_1us_clear <= 1'b0;
                        if (cnt_1us == 32'd750000 || IO_ds18b20_dq) begin // 转换结束或总线拉高
                            cnt_1us_clear <= 1'b1;
                            state         <= S0; // 重新初始化
                        end
                    end
                    S7: begin // 读取温度数据（16位）
                        if (step == 6'd34) begin
                            bit_valid         <= 4'd0;
                            IO_ds18b20_dq_buf <= 1'b0;
                            step              <= step + 1'b1;
                            state             <= READ0;
                        end else if (step == 6'd35) begin
                            bit_valid         <= bit_valid + 1'b1;
                            IO_ds18b20_dq_buf <= 1'b0;
                            step              <= step + 1'b1;
                            state             <= READ0;
                        end else if (step == 6'd36) begin
                            bit_valid         <= bit_valid + 1'b1;
                            IO_ds18b20_dq_buf <= 1'b0;
                            step              <= step + 1'b1;
                            state             <= READ0;
                        end else if (step == 6'd37) begin
                            bit_valid         <= bit_valid + 1'b1;
                            IO_ds18b20_dq_buf <= 1'b0;
                            step              <= step + 1'b1;
                            state             <= READ0;
                        end else if (step == 6'd38) begin
                            bit_valid         <= bit_valid + 1'b1;
                            IO_ds18b20_dq_buf <= 1'b0;
                            step              <= step + 1'b1;
                            state             <= READ0;
                        end else if (step == 6'd39) begin
                            bit_valid         <= bit_valid + 1'b1;
                            IO_ds18b20_dq_buf <= 1'b0;
                            step              <= step + 1'b1;
                            state             <= READ0;
                        end else if (step == 6'd40) begin
                            bit_valid         <= bit_valid + 1'b1;
                            IO_ds18b20_dq_buf <= 1'b0;
                            step              <= step + 1'b1;
                            state             <= READ0;
                        end else if (step == 6'd41) begin
                            bit_valid         <= bit_valid + 1'b1;
                            IO_ds18b20_dq_buf <= 1'b0;
                            step              <= step + 1'b1;
                            state             <= READ0;
                        end else if (step == 6'd42) begin
                            bit_valid         <= bit_valid + 1'b1;
                            IO_ds18b20_dq_buf <= 1'b0;
                            step              <= step + 1'b1;
                            state             <= READ0;
                        end else if (step == 6'd43) begin
                            bit_valid         <= bit_valid + 1'b1;
                            IO_ds18b20_dq_buf <= 1'b0;
                            step              <= step + 1'b1;
                            state             <= READ0;
                        end else if (step == 6'd44) begin
                            bit_valid         <= bit_valid + 1'b1;
                            IO_ds18b20_dq_buf <= 1'b0;
                            step              <= step + 1'b1;
                            state             <= READ0;
                        end else if (step == 6'd45) begin
                            bit_valid         <= bit_valid + 1'b1;
                            IO_ds18b20_dq_buf <= 1'b0;
                            step              <= step + 1'b1;
                            state             <= READ0;
                        end else if (step == 6'd46) begin
                            bit_valid         <= bit_valid + 1'b1;
                            IO_ds18b20_dq_buf <= 1'b0;
                            step              <= step + 1'b1;
                            state             <= READ0;
                        end else if (step == 6'd47) begin
                            bit_valid         <= bit_valid + 1'b1;
                            IO_ds18b20_dq_buf <= 1'b0;
                            step              <= step + 1'b1;
                            state             <= READ0;
                        end else if (step == 6'd48) begin
                            bit_valid         <= bit_valid + 1'b1;
                            IO_ds18b20_dq_buf <= 1'b0;
                            step              <= step + 1'b1;
                            state             <= READ0;
                        end else if (step == 6'd49) begin
                            bit_valid         <= bit_valid + 1'b1;
                            IO_ds18b20_dq_buf <= 1'b0;
                            step              <= step + 1'b1;
                            state             <= READ0;
                        end else if (step == 6'd50) begin
                            step            <= 6'd0;
                            ds18b20_rdy     <= 1'b1;
                            state           <= S0;
                        end
                    end
                    WRITE0: begin // 写 0：拉低 80us
                        cnt_1us_clear     <= 1'b0;
                        IO_ds18b20_dq_buf <= 1'b0;
                        if (cnt_1us == 32'd80) begin
                            cnt_1us_clear     <= 1'b1;
                            IO_ds18b20_dq_buf <= 1'bZ; // 释放总线
                            state             <= WRITE00;
                        end
                    end
                    WRITE00: begin // 写 0 结束，返回 S5
                        state <= S5;
                    end
                    WRITE01: begin // 写 1 结束，进入 WRITE1
                        state <= WRITE1;
                    end
                    WRITE1: begin // 写 1：释放总线 80us
                        cnt_1us_clear     <= 1'b0;
                        IO_ds18b20_dq_buf <= 1'bZ; // 释放总线，DS18B20 拉低表示 0，否则为 1
                        if (cnt_1us == 32'd80) begin
                            cnt_1us_clear <= 1'b1;
                            state         <= S5;
                        end
                    end
                    READ0: begin // 读开始
                        state <= READ1;
                    end
                    READ1: begin // 采样准备：释放总线 10us
                        cnt_1us_clear     <= 1'b0;
                        IO_ds18b20_dq_buf <= 1'bZ;
                        if (cnt_1us == 32'd10) begin
                            cnt_1us_clear <= 1'b1;
                            state         <= READ2;
                        end
                    end
                    READ2: begin // 读取数据位
                        temperature_buf[bit_valid] <= IO_ds18b20_dq;
                        state                      <= READ3;
                    end
                    READ3: begin // 读完成等待 55us
                        cnt_1us_clear <= 1'b0;
                        if (cnt_1us == 32'd55) begin
                            cnt_1us_clear <= 1'b1;
                            state         <= S7;
                        end
                    end
                    default: begin
                        state <= S00;
                    end
                endcase
            end
        end
    end

    // ===================== 三态总线输出 =====================
    assign IO_ds18b20_dq = IO_ds18b20_dq_buf;

endmodule