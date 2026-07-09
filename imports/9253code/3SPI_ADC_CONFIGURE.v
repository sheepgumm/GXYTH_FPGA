`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Deng Yukun
// 
// Create Date: 2026/01/01 15:52:12
// Design Name: 
// Module Name: ADC_CONFIGURE
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

module ADC_CONFIGURE
(
    // ===================== 时钟与复位 =====================
    input                           CLK                 , // 系统工作时钟，20MHz
    input                           reset               , // 系统同步复位

    // ===================== 控制信号 =====================
    input                           image_en            , // 图像使能（未使用？）
    input                           spi_en              , // SPI 配置使能

    // ===================== ADC SPI 接口 =====================
    output reg                      sclk                , // SPI 时钟（到 ADC）
    output reg                      cs_b                , // SPI 片选（低有效）
    input                           sdin                , // SPI 数据输入（从 ADC 到 FPGA）
    output reg                      sdout               , // SPI 数据输出（从 FPGA 到 ADC）

    // ===================== 状态输出 =====================
    output reg                      CfgDone             , // 配置完成标志（高有效）
    output reg                      Tri_en                // FPGA 三态总线使能（1=输出，0=输入）
);

    // ===================== 参数定义 =====================
    // 【修改 1】：将写寄存器数量修改为 7（原本是 5 + 新增 2）
    localparam Wr_n = 8'd7;

    // 写寄存器数据定义（24bit：3bit 指令 + 13bit 地址 + 8bit 数据）
    wire    [23:0]  WriteReg1;
    wire    [23:0]  WriteReg2;
    wire    [23:0]  WriteReg3;
    wire    [23:0]  WriteReg4;
    wire    [23:0]  WriteReg5;
    // 【修改 2】：增加 WriteReg6 和 WriteReg7
    wire    [23:0]  WriteReg6;
    wire    [23:0]  WriteReg7;

    assign WriteReg1 = {3'b000, 13'h000, 8'h3c}; // 所有寄存器恢复默认
    assign WriteReg2 = {3'b000, 13'h015, 8'h30}; // 100Ω
    assign WriteReg3 = {3'b000, 13'h109, 8'h00}; // 50Ω, 14bit, 20MSPS （52 14bit 40MSPS）
    assign WriteReg4 = {3'b000, 13'h018, 8'h02}; // 设置分辨率/采样率覆盖
    assign WriteReg5 = {3'b000, 13'h00d, 8'h00}; // 关闭（00），输出测试模式 0/1（09）
    // 【修改 3】：为新增的两个寄存器赋初值（请根据芯片手册修改地址和数据）
    assign WriteReg6 = {3'b000, 13'h009, 8'h01};   // 打开 DCS
    assign WriteReg7 = {3'b000, 13'h0FF, 8'h01};   // 向 0xFF 写 0x01，使前面配置生效

    // 读寄存器地址定义（24bit：指令+地址+数据掩码）
    localparam Rd_n = 8'd4; // 需读 4 个寄存器的值
    wire    [23:0]  RdAddr1;
    wire    [23:0]  RdAddr2;
    wire    [23:0]  RdAddr3;
    wire    [23:0]  RdAddr4;
    assign RdAddr1 = 24'h80_08_FF; // 默认 99 为正常模式，BD 为测试模式
    assign RdAddr2 = 24'h80_0d_FF; // Chip ID，0x29
    assign RdAddr3 = 24'h80_00_FF; // 0x01
    assign RdAddr4 = 24'h81_09_FF; // 0x01

    // ===================== 内部信号定义 =====================
    (*mark_debug = "true"*) reg     [7:0]   RdData1     ; // 存储读取的第1个寄存器值
    (*mark_debug = "true"*) reg     [7:0]   RdData2     ; // 存储读取的第2个寄存器值
    (*mark_debug = "true"*) reg     [7:0]   RdData3     ; // 存储读取的第3个寄存器值
    (*mark_debug = "true"*) reg     [7:0]   RdData4     ; // 存储读取的第4个寄存器值

    (*mark_debug = "true"*) reg     [7:0]   state       ; // 状态机状态
    reg                     [21:0]  cnt             ; // 通用计数器
    reg                     [7:0]   n               ; // 写寄存器索引（第几个）
    reg                     [7:0]   m               ; // 读寄存器索引（第几个）

    // ===================== 主状态机 =====================
    always @(posedge CLK or negedge reset) begin
        if (~reset) begin
            state   <= 8'd16;
            cs_b    <= 1'b1;
            sdout   <= 1'b1;
            sclk    <= 1'b1;
            CfgDone <= 1'b0;
            cnt     <= 22'd23;
            n       <= 8'd0;
            m       <= 8'd0;
            RdData1 <= 8'd0;
            RdData2 <= 8'd0;
            RdData3 <= 8'd0;
            RdData4 <= 8'd0;
            Tri_en  <= 1'b1; // 置 1 时代表方向为 sdio 为输出
        end else begin
            case (state)
                8'd16: begin
                    if (cnt == 22'd0) begin
                        // 外部复位后，等待 15 个时钟周期，使电平稳定再进行 ADC 寄存器配置
                        state <= 8'd0;
                        cnt   <= 22'd23;
                    end else begin
                        cnt   <= cnt - 1'b1;
                        state <= 8'd16;
                        Tri_en <= 1'b1;
                    end
                end

                8'd0: begin // 初始化所有寄存器初始值
                    cs_b    <= 1'b1;
                    sdout   <= 1'b1;
                    sclk    <= 1'b1;
                    cnt     <= 22'd23;
                    n       <= 8'd1;
                    m       <= 8'd1;
                    CfgDone <= 1'b0;
                    RdData1 <= 8'd0;
                    RdData2 <= 8'd0;
                    RdData3 <= 8'd0;
                    Tri_en  <= 1'b1;
                    if (spi_en)
                        state <= 8'd1;
                    else
                        state <= 8'd0;
                end

                8'd1: begin // 写入 24bit 寄存器数据的 MSB
                    cs_b  <= 1'b0;
                    sclk  <= 1'b0;
                    if (n == 8'd1)
                        sdout <= WriteReg1[cnt];
                    else if (n == 8'd2)
                        sdout <= WriteReg2[cnt];
                    else if (n == 8'd3)
                        sdout <= WriteReg3[cnt];
                    else if (n == 8'd4)
                        sdout <= WriteReg4[cnt];
                    else if (n == 8'd5)
                        sdout <= WriteReg5[cnt];
                    // 【修改 4】：在发送状态机中增加 6 和 7 的分支
                    else if (n == 8'd6)
                        sdout <= WriteReg6[cnt];
                    else if (n == 8'd7)
                        sdout <= WriteReg7[cnt];
                    state <= 8'd2;
                end

                8'd2: begin // 循环 24 次，将 24bit 数据从高到低写入
                    sclk <= 1'b1;
                    if (cnt == 22'd0) begin
                        state <= 8'd3;
                        cnt   <= 22'd23;
                    end else begin
                        cnt   <= cnt - 1'b1;
                        state <= 8'd1;
                    end
                end

                8'd3: begin // 写入一个 24bit 数据后，等待 24 个时钟周期再开始下一个状态
                    if (cnt == 22'd0) begin
                        state <= 8'd4;
                        cnt   <= 22'd23;
                    end else begin
                        cnt   <= cnt - 1'b1;
                        cs_b  <= 1'b1;
                        sclk  <= 1'b1;
                        sdout <= 1'b1;
                        state <= 8'd3;
                    end
                end

                8'd4: begin // 判断 n 值，如果没到总数则继续写
                    // 【修改 5】：直接用 n==Wr_n 判断，去掉了多余的 || n==5，修复了只能发 4 个的 bug
                    if (n == Wr_n) begin
                        state <= 8'd7; // 循环写完毕，准备开始下一个读操作
                        n     <= 8'd1;
                        cnt   <= 22'd23;
                    end else if (n < Wr_n) begin
                        n     <= n + 1'b1;
                        state <= 8'd1; // 返回状态 1 循环写
                    end
                end

                // ==================== 读寄存器 ====================
                8'd7: begin // 等待 23 个时钟周期后再进行下一个读操作
                    if (cnt == 22'd0) begin
                        state <= 8'd8;
                        cnt   <= 22'd23;
                    end else begin
                        cnt   <= cnt - 1'b1;
                        state <= 8'd7;
                    end
                end

                8'd8: begin // 开始读操作，先写入 3 位指令 + 13 位地址
                    cs_b  <= 1'b0;
                    sclk  <= 1'b0;
                    Tri_en <= 1'b1;
                    if (m == 8'd1)
                        sdout <= RdAddr1[cnt];
                    else if (m == 8'd2)
                        sdout <= RdAddr2[cnt];
                    else if (m == 8'd3)
                        sdout <= RdAddr3[cnt];
                    else if (m == 8'd4)
                        sdout <= RdAddr4[cnt];
                    state <= 8'd9;
                end

                8'd9: begin // 循环写入直到写入 16bit，在最后一个 sclk 下降沿即将写入第 10bit 地址
                    sclk <= 1'b1;
                    if (cnt == 22'd8) begin
                        // 当 cnt 为 8 时，16bit 写完，在接下来的 sclk 下降沿 ADC 开始输出寄存器数据
                        // 此时 FPGA 的三态门要变为输入，接收数据
                        state <= 8'd10; // 读等待状态
                        cnt   <= 22'd7; // 读数 cnt 要赋值为 7，因为对于 ADC 读出是 8bit，只需接收 7 个移位
                    end else begin
                        cnt   <= cnt - 1'b1;
                        state <= 8'd8;
                    end
                end

                8'd10: begin // 在 sclk 下降沿，三态变为输入
                    sclk  <= 1'b0;   // 下降沿 ADC 输出数据开始，FPGA 在 sclk 上升沿读取，等待数据稳定
                    cs_b  <= 1'b0;
                    Tri_en <= 1'b0; // 状态转换
                    state <= 8'd11;
                end

                8'd11: begin // 在 sclk 上升沿，开始读取
                    sclk <= 1'b1;
                    if (cnt == 22'd0) begin // 8bit 读完
                        state <= 8'd12; // 读完毕状态
                    end else begin
                        cnt   <= cnt - 1'b1;
                        state <= 8'd10;
                    end

                    // 在 cnt 为 7 时，因为前面写入 16bit 的读指令和地址，
                    // 把地址和数据在接下来的 8 个 clk 内移位接收
                    if ((cnt <= 22'd7) && (m == 8'd1))
                        RdData1 <= {RdData1[6:0], sdin};
                    if ((cnt <= 22'd7) && (m == 8'd2))
                        RdData2 <= {RdData2[6:0], sdin};
                    if ((cnt <= 22'd7) && (m == 8'd3))
                        RdData3 <= {RdData3[6:0], sdin};
                    if ((cnt <= 22'd7) && (m == 8'd4))
                        RdData4 <= {RdData4[6:0], sdin};
                end

                8'd12: begin // 拉高相关信号
                    sclk  <= 1'b1;
                    cs_b  <= 1'b1;
                    state <= 8'd13;
                    cnt   <= 22'd23;
                end

                8'd13: begin // 读完一个地址数据之后等待 24 个时钟周期
                    if (cnt == 22'd0) begin
                        state <= 8'd14;
                    end else begin
                        cnt   <= cnt - 1'b1;
                        cs_b  <= 1'b1;
                        sclk  <= 1'b1;
                        sdout <= 1'b1;
                        state <= 8'd13;
                    end
                end

                8'd14: begin // 判断读写是否完成，没有的话返回状态 8 继续
                    if (m == Rd_n) begin // 读完所有地址的读操作即算完成
                        state <= 8'd15;
                        m     <= 8'd1;
                        cnt   <= 22'd23;
                    end else begin
                        m     <= m + 1'b1;
                        state <= 8'd8;
                        cnt   <= 22'd23;
                    end
                end

                8'd15: begin
                    // 配置完成，保持状态（原代码此处被注释，但保留）
                    state <= 8'd15;
                end

                default: state <= 8'd16;
            endcase
        end
    end

endmodule