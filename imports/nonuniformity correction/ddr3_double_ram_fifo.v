`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Deng Yukun
// 
// Create Date: 2026/01/01 15:52:12
// Design Name: 
// Module Name: ddr3_double_ram_fifo
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

module ddr3_double_ram_fifo
(
    // ===================== 时钟与复位 =====================
    input                           I_clk               , // 系统时钟（用于读 RAM）
    input                           rst_n               , // 复位信号（低有效）
    input                           wr_clk              , // WFIFO 时钟（未使用）

    // ===================== DDR3 接口 =====================
    input                           ui_clk              , // 用户时钟（来自 MIG）
    input                           rram_rclk           , // RRAM 读时钟（未使用）
    (* MARK_DEBUG="true" *) input   [9:0]   I_rram_read_addr1, // 读 RAM 地址1（来自 CL）
    (* MARK_DEBUG="true" *) input   [9:0]   I_rram_read_addr2, // 读 RAM 地址2（来自 ADC sample）
    input                           read_ram_finish1    , // RAM1 读取完成信号
    input                           read_ram_finish2    , // RAM2 读取完成信号
    input                   [127:0] rram_din            , // 用户读数据（来自 DDR）
    (* MARK_DEBUG="true" *) input           rram_wren   , // DDR 读出数据有效使能
    input                           rram_shift_sig      , // 读 RAM 切换信号

    // ===================== 输出信号 =====================
    output reg                      ram_rq_read         , // 读请求输出
    output reg                      O_cl_sample_finish  , // CL 采样完成（未连接？）
    (* MARK_DEBUG="true" *) output  [127:0] o_kb_data      // 输出 KB 校正系数数据（128bit）
);

    // ===================== 内部信号定义 =====================
    // 读 RAM 控制信号
    reg                             read_ram_ena1       ; // RAM1 写使能
    reg                             read_ram_ena2       ; // RAM2 写使能
    reg                             read_ram_wea1       ; // RAM1 写允许
    reg                             read_ram_wea2       ; // RAM2 写允许
    (* MARK_DEBUG="true" *) reg     [9:0]   read_ram_waddr1; // RAM1 写地址
    (* MARK_DEBUG="true" *) reg     [9:0]   read_ram_waddr2; // RAM2 写地址
    reg                             read_ram_enb1       ; // RAM1 读使能
    reg                             read_ram_enb2       ; // RAM2 读使能
    wire                    [127:0] read_ram_doutb1     ; // RAM1 读数据输出
    wire                    [127:0] read_ram_doutb2     ; // RAM2 读数据输出

    reg                             read_ram_alter      ; // 双 RAM 输出选择（0=RAM1, 1=RAM2）
    reg                     [1:0]   read_ram_finish1_a  ; // RAM1 读取完成信号打拍同步
    reg                     [1:0]   read_ram_finish2_a  ; // RAM2 读取完成信号打拍同步
    reg                             read_ram1_en        ; // RAM1 使能脉冲（单周期）
    reg                             read_ram2_en        ; // RAM2 使能脉冲（单周期）
    reg                             read_ram_state      ; // 当前选择哪个 RAM 写入（0=RAM1, 1=RAM2）

    reg                     [3:0]   read_ram1_fsm       ; // RAM1 写入状态机
    reg                     [3:0]   read_ram2_fsm       ; // RAM2 写入状态机

    reg                             start_to_read       ; // 开始读标志（未使用）
    reg                     [3:0]   ram_rq_read_cnt     ; // 读请求计数（未使用）
    reg                     [1:0]   rram_shift_sig_sample; // rram_shift_sig 同步打拍

    // 仿真调试用（注释掉）
    // reg [15:0] tempa, tempb, tempc, tempd, tempe, tempf, tempg, temph;

    // ===================== 双端口 RAM 实例化 =====================
    // RAM1：从 DDR 写入，由 CL 读取
    dpram1_2 read_ram1 (
        .clka   (ui_clk             ), // 写时钟 = ui_clk（DDR 用户时钟）
        .ena    (read_ram_ena1      ), // 写使能
        .wea    (read_ram_wea1      ), // 写允许
        .addra  (read_ram_waddr1    ), // 写地址
        .dina   (rram_din           ), // 写数据
        .clkb   (I_clk              ), // 读时钟 = 系统时钟（原为 rram_rclk，但未用）
        .enb    (read_ram_enb1      ), // 读使能
        .addrb  (I_rram_read_addr1  ), // 读地址（来自 CL）
        .doutb  (read_ram_doutb1    )  // 读数据输出
    );

    // RAM2：从 DDR 写入，由 ADC sample 读取
    dpram1_2 read_ram2 (
        .clka   (ui_clk             ), // 写时钟 = ui_clk
        .ena    (read_ram_ena2      ), // 写使能
        .wea    (read_ram_wea2      ), // 写允许
        .addra  (read_ram_waddr2    ), // 写地址
        .dina   (rram_din           ), // 写数据
        .clkb   (I_clk              ), // 读时钟 = 系统时钟
        .enb    (read_ram_enb2      ), // 读使能
        .addrb  (I_rram_read_addr2  ), // 读地址（来自 ADC sample）
        .doutb  (read_ram_doutb2    )  // 读数据输出
    );

    // ===================== 输出数据 MUX =====================
    // 根据 read_ram_alter 选择从哪个 RAM 输出数据给 KB
    assign o_kb_data = read_ram_alter ? read_ram_doutb1 : read_ram_doutb2;

    // ===================== 异步信号同步打拍 =====================
    // 将来自其他时钟域的信号同步到 ui_clk 域
    always @(posedge ui_clk or negedge rst_n) begin
        if (!rst_n) begin
            rram_shift_sig_sample <= 2'b00;
            read_ram_finish1_a    <= 2'b00;
            read_ram_finish2_a    <= 2'b00;
        end else begin
            rram_shift_sig_sample[0] <= rram_shift_sig;        // 第一拍
            rram_shift_sig_sample[1] <= rram_shift_sig_sample[0];

            read_ram_finish1_a[0] <= read_ram_finish1;         // RAM1 读取完成信号同步
            read_ram_finish1_a[1] <= read_ram_finish1_a[0];

            read_ram_finish2_a[0] <= read_ram_finish2;         // RAM2 读取完成信号同步
            read_ram_finish2_a[1] <= read_ram_finish2_a[0];
        end
    end

    // ===================== 切换读 RAM 使能（产生单周期脉冲） =====================
    // 根据 rram_shift_sig 的上升沿，交替使能 RAM1 或 RAM2 的写入
    always @(posedge ui_clk or negedge rst_n) begin
        if (!rst_n) begin
            read_ram1_en  <= 1'b0;
            read_ram2_en  <= 1'b0;
            read_ram_state <= 1'b0;
        end else begin
            if (rram_shift_sig_sample == 2'b01) begin   // 上升沿检测
                if (read_ram_state == 1'b0) begin
                    read_ram1_en  <= 1'b1;              // 使能 RAM1 写入
                    read_ram2_en  <= 1'b0;
                    read_ram_state <= ~read_ram_state;  // 状态翻转
                end else begin
                    read_ram2_en  <= 1'b1;              // 使能 RAM2 写入
                    read_ram1_en  <= 1'b0;
                    read_ram_state <= ~read_ram_state;
                end
            end

            // en 信号只持续一个 clk，用于 ram 状态机的跳转
            if (read_ram1_en) read_ram1_en <= 1'b0;
            if (read_ram2_en) read_ram2_en <= 1'b0;
        end
    end

    // ===================== RAM 写入状态机 =====================
    // 将来自 DDR 的数据连续写入选中的 RAM，直到写满一行（160 个 128bit 数据）
    always @(posedge ui_clk or negedge rst_n) begin
        if (!rst_n) begin
            read_ram_ena1     <= 1'b0;
            read_ram_ena2     <= 1'b0;
            read_ram_wea1     <= 1'b0;
            read_ram_wea2     <= 1'b0;
            read_ram_waddr1   <= 10'd0;
            read_ram_waddr2   <= 10'd0;
            read_ram_enb1     <= 1'b0;
            read_ram_enb2     <= 1'b0;
            read_ram1_fsm     <= 4'd0;
            read_ram_alter    <= 1'b1;
            ram_rq_read       <= 1'b0;
        end else begin
            // ---------- RAM1 状态机 ----------
            case (read_ram1_fsm)
                0: begin
                    if (read_ram1_en) begin
                        read_ram1_fsm   <= 4'd1;
                        ram_rq_read     <= 1'b0;
                        read_ram_ena1   <= 1'b1;
                        read_ram_wea1   <= 1'b1;
                        // 仿真调试用，可忽略
                        // tempa <= 16'd1; tempb <= 16'd2; tempc <= 16'd3; tempd <= 16'd4;
                    end
                end
                1: begin
                    // 在 rram_wren 有效时，每个时钟周期将数据写入 RAM
                    if (rram_wren) begin
                        if (read_ram_waddr1 == 10'd159) begin    // 写满 160 个地址
                            read_ram1_fsm   <= 4'd2;
                            read_ram_wea1   <= 1'b0;
                            read_ram_ena1   <= 1'b0;
                            read_ram_enb1   <= 1'b1;            // 开启读使能
                            read_ram_waddr1 <= 10'd0;           // 地址归零
                        end else begin
                            read_ram_waddr1 <= read_ram_waddr1 + 1'b1;
                            // 仿真调试用，可忽略
                            // tempa <= tempa + 16'd4; ...
                        end
                    end
                end
                2: begin
                    // 等待读取完成信号（来自 CL）
                    if (read_ram_finish1_a == 2'b01) begin
                        read_ram1_fsm   <= 4'd0;
                        read_ram_alter  <= 1'b0;               // 切换输出到 RAM2
                        read_ram_enb1   <= 1'b0;
                        ram_rq_read     <= 1'b1;               // 发出读请求
                    end
                end
                default: read_ram1_fsm <= 4'd0;
            endcase

            // ---------- RAM2 状态机 ----------
            case (read_ram2_fsm)
                0: begin
                    if (read_ram2_en) begin
                        read_ram2_fsm   <= 4'd1;
                        ram_rq_read     <= 1'b0;
                        read_ram_ena2   <= 1'b1;
                        read_ram_wea2   <= 1'b1;
                        // 仿真调试用
                        // tempa <= 16'd1; tempb <= 16'd2; tempc <= 16'd3; tempd <= 16'd4;
                    end
                end
                1: begin
                    if (rram_wren) begin
                        if (read_ram_waddr2 == 10'd159) begin
                            read_ram2_fsm   <= 4'd2;
                            read_ram_wea2   <= 1'b0;
                            read_ram_ena2   <= 1'b0;
                            read_ram_enb2   <= 1'b1;
                            read_ram_waddr2 <= 10'd0;
                        end else begin
                            read_ram_waddr2 <= read_ram_waddr2 + 1'b1;
                            // 仿真调试用
                            // tempa <= tempa + 16'd4;
                        end
                    end
                end
                2: begin
                    // 等待读取完成信号（来自 ADC sample）
                    if (read_ram_finish2_a == 2'b01) begin
                        read_ram2_fsm   <= 4'd0;
                        read_ram_enb2   <= 1'b0;
                        read_ram_alter  <= 1'b1;               // 切换输出到 RAM1
                        ram_rq_read     <= 1'b1;               // 发出读请求
                    end
                end
                default: read_ram2_fsm <= 4'd0;
            endcase
        end
    end

endmodule