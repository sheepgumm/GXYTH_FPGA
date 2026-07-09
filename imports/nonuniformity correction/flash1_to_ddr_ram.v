`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Deng Yukun
// 
// Create Date: 2026/01/01 15:52:12
// Design Name: 
// Module Name: flash1_to_ddr_ram
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

module flash1_to_ddr_ram
(
    // ===================== 时钟与复位 =====================
    input                           I_clk               , // 系统时钟 80MHz
    input                           rst_n               , // 复位信号（低有效）

    // ===================== Flash 数据输入 =====================
    (*mark_debug = "true"*) input   [7:0]   flash1_data , // 来自 Flash 的 8bit 数据
    input                           I_shift_sig         , // SPI 时钟使能（用于同步）
    (*mark_debug = "true"*) input   write_en            , // 数据有效信号（来自 flash）
    (*mark_debug = "true"*) input   read_clk            , // DDR 读时钟（用于 FIFO 读）
    (*mark_debug = "true"*) input   read_en             , // DDR 读使能
    (*mark_debug = "true"*) input   I_ddr_finish        , // DDR 写入完成信号

    // ===================== DDR 数据输出 =====================
    (*mark_debug = "true"*) output  [127:0] O_ddr_data  , // 输出到 DDR 的 128bit 数据
    output reg                      O_fifo_finish         // FIFO 写入完成（告诉 DDR 一页已存好）
);

    // ===================== 内部信号定义 =====================
    (* MARK_DEBUG="true" *) reg             wr_en1          ; // FIFO1 写使能（前半部分）
    (* MARK_DEBUG="true" *) reg             wr_en2          ; // FIFO2 写使能（前半部分）
    (* MARK_DEBUG="true" *) reg             wr_en1_2        ; // FIFO1 写使能（后半部分）
    (* MARK_DEBUG="true" *) reg             wr_en2_2        ; // FIFO2 写使能（后半部分）
    (* MARK_DEBUG="true" *) reg             rd_en1          ; // FIFO1 读使能
    (* MARK_DEBUG="true" *) reg             rd_en2          ; // FIFO2 读使能

    reg                             wr_en_tag           ; // 乒乓写标记（0=前半，1=后半）
    reg                     [3:0]   wr_en_cnt           ; // 写使能计数（每8字节切换一次）

    wire                    [6:0]   rd_fifo1_count      ; // FIFO1 读计数（未用）
    wire                    [9:0]   wr_fifo1_count      ; // FIFO1 写计数（未用）
    wire                    [6:0]   rd_fifo2_count      ; // FIFO2 读计数（未用）
    wire                    [9:0]   wr_fifo2_count      ; // FIFO2 写计数（未用）

    reg                             fifo_order          ; // 乒乓切换顺序（0=FIFO1, 1=FIFO2）
    reg                     [1:0]   shift_sig           ; // I_shift_sig 同步打拍
    reg                     [1:0]   write_en_sample     ; // write_en 同步打拍
    reg                     [1:0]   ddr_finish_sample   ; // I_ddr_finish 同步打拍

    reg                     [8:0]   write_fifo1_num     ; // FIFO1 已写入字节数
    reg                     [8:0]   write_fifo2_num     ; // FIFO2 已写入字节数
    (*mark_debug = "true"*) reg     [2:0]   fifo1_state ; // FIFO1 状态机
    (*mark_debug = "true"*) reg     [2:0]   fifo2_state ; // FIFO2 状态机

    reg                             fifo1_en            ; // FIFO1 使能脉冲（单周期）
    reg                             fifo2_en            ; // FIFO2 使能脉冲（单周期）
    reg                             fifo1_finish        ; // FIFO1 页写入完成
    reg                             fifo2_finish        ; // FIFO2 页写入完成
    reg                     [3:0]   fifo1_finish_cnt    ; // FIFO1 完成信号延时计数
    reg                     [3:0]   fifo2_finish_cnt    ; // FIFO2 完成信号延时计数

    wire                    [63:0]  ddr_data1           ; // FIFO1 输出数据（前半）
    wire                    [63:0]  ddr_data1_2         ; // FIFO1 输出数据（后半）
    wire                    [63:0]  ddr_data2           ; // FIFO2 输出数据（前半）
    wire                    [63:0]  ddr_data2_2         ; // FIFO2 输出数据（后半）
    reg                             dout_sel            ; // 输出选择（0=FIFO2, 1=FIFO1）

    // ===================== FIFO 实例化 =====================
    // FIFO1 前半（64bit）
    fifo_generator_1 fifo1 (
        .rst    (~rst_n             ), // 复位（高有效）
        .wr_clk (I_clk              ), // 写时钟 80MHz
        .rd_clk (read_clk           ), // 读时钟（来自 DDR）
        .din    (flash1_data        ), // 8bit 输入
        .wr_en  (wr_en1             ), // 写使能
        .rd_en  (rd_en1 & read_en   ), // 读使能（需 DDR 读使能）
        .dout   (ddr_data1          ), // 64bit 输出
        .full   (                   ), // 满标志（未用）
        .empty  (                   )  // 空标志（未用）
    );

    // FIFO1 后半（64bit）
    fifo_generator_1 fifo1_2 (
        .rst    (~rst_n             ),
        .wr_clk (I_clk              ),
        .rd_clk (read_clk           ),
        .din    (flash1_data        ),
        .wr_en  (wr_en1_2           ),
        .rd_en  (rd_en1 & read_en   ),
        .dout   (ddr_data1_2        ),
        .full   (                   ),
        .empty  (                   )
    );

    // FIFO2 前半（64bit）
    fifo_generator_1 fifo2 (
        .rst    (~rst_n             ),
        .wr_clk (I_clk              ),
        .rd_clk (read_clk           ),
        .din    (flash1_data        ),
        .wr_en  (wr_en2             ),
        .rd_en  (rd_en2 & read_en   ),
        .dout   (ddr_data2          ),
        .full   (                   ),
        .empty  (                   )
    );

    // FIFO2 后半（64bit）
    fifo_generator_1 fifo2_2 (
        .rst    (~rst_n             ),
        .wr_clk (I_clk              ),
        .rd_clk (read_clk           ),
        .din    (flash1_data        ),
        .wr_en  (wr_en2_2           ),
        .rd_en  (rd_en2 & read_en   ),
        .dout   (ddr_data2_2        ),
        .full   (                   ),
        .empty  (                   )
    );

    // ===================== DDR 数据输出选择 =====================
    // 选择 FIFO1 或 FIFO2 的输出，拼接成 128bit
    assign O_ddr_data = dout_sel ? {ddr_data1, ddr_data1_2} : {ddr_data2, ddr_data2_2};

    // ===================== 异步信号同步打拍 =====================
    always @(posedge I_clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_sig         <= 2'b00;
            write_en_sample   <= 2'b00;
            ddr_finish_sample <= 2'b00;
        end else begin
            shift_sig[0]         <= I_shift_sig;
            shift_sig[1]         <= shift_sig[0];

            write_en_sample[0]   <= write_en;
            write_en_sample[1]   <= write_en_sample[0];

            ddr_finish_sample[0] <= I_ddr_finish;
            ddr_finish_sample[1] <= ddr_finish_sample[0];
        end
    end

    // ===================== FIFO 乒乓切换（产生单周期使能脉冲） =====================
    always @(posedge I_clk or negedge rst_n) begin
        if (!rst_n) begin
            fifo_order <= 1'b0;
            fifo1_en   <= 1'b0;
            fifo2_en   <= 1'b0;
        end else begin
            if (shift_sig == 2'b01) begin            // I_shift_sig 上升沿
                if (!fifo_order) begin
                    fifo1_en <= 1'b1;                // 使能 FIFO1
                    fifo_order <= 1'b1;
                end else begin
                    fifo2_en <= 1'b1;                // 使能 FIFO2
                    fifo_order <= 1'b0;
                end
            end
            if (fifo1_en) fifo1_en <= 1'b0;          // 单周期脉冲
            if (fifo2_en) fifo2_en <= 1'b0;
        end
    end

    // ===================== FIFO 状态机 =====================
    always @(posedge I_clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_en1          <= 1'b0;
            wr_en1_2        <= 1'b0;
            wr_en2          <= 1'b0;
            wr_en2_2        <= 1'b0;
            wr_en_tag       <= 1'b0;
            wr_en_cnt       <= 4'd0;
            rd_en1          <= 1'b0;
            rd_en2          <= 1'b0;
            fifo1_state     <= 3'd0;
            fifo2_state     <= 3'd0;
            write_fifo1_num <= 9'd0;
            write_fifo2_num <= 9'd0;
            fifo1_finish    <= 1'b0;
            fifo2_finish    <= 1'b0;
            dout_sel        <= 1'b0;
            fifo1_finish_cnt<= 4'd0;
            fifo2_finish_cnt<= 4'd0;
        end else begin
            // ---------- FIFO1 状态机 ----------
            case (fifo1_state)
                3'd0: begin
                    if (fifo1_en) begin
                        fifo1_state <= 3'd1;
                        wr_en_tag   <= 1'b0;
                        wr_en_cnt   <= 4'd0;
                    end
                end
                3'd1: begin
                    if (write_fifo1_num == 9'd256) begin    // 写入 256 个字节（一页）
                        fifo1_state <= 3'd2;
                        wr_en1      <= 1'b0;
                        wr_en1_2    <= 1'b0;
                        rd_en1      <= 1'b1;                // 开启读使能
                        fifo1_finish <= 1'b1;               // 一页存储完成
                        dout_sel    <= 1'b1;                // 选择 FIFO1 输出
                        write_fifo1_num <= 9'd0;
                    end else begin
                        if (write_en_sample == 2'b01) begin // write_en 上升沿，写入一个字节
                            write_fifo1_num <= write_fifo1_num + 1'b1;
                            if (wr_en_tag) begin
                                wr_en1_2 <= 1'b1;           // 写入后半部分 FIFO
                            end else begin
                                wr_en1 <= 1'b1;             // 写入前半部分 FIFO
                            end
                            // 每写入 8 字节切换一次（实现 64bit 拼接）
                            if (wr_en_cnt == 4'd7) begin
                                wr_en_tag <= ~wr_en_tag;
                                wr_en_cnt <= 4'd0;
                            end else begin
                                wr_en_cnt <= wr_en_cnt + 1'b1;
                            end
                        end else begin
                            wr_en1   <= 1'b0;
                            wr_en1_2 <= 1'b0;
                        end
                    end
                end
                3'd2: begin
                    // 延长 fifo1_finish 信号，确保被 DDR 捕获
                    if (fifo1_finish_cnt == 4'd4) begin
                        fifo1_finish    <= 1'b0;
                        fifo1_finish_cnt <= 4'd0;
                    end else begin
                        fifo1_finish_cnt <= fifo1_finish_cnt + 1'b1;
                    end
                    if (ddr_finish_sample == 2'b01) begin    // DDR 完成读取后复位
                        fifo1_state <= 3'd0;
                        rd_en1      <= 1'b0;
                    end
                end
                default: fifo1_state <= 3'd0;
            endcase

            // ---------- FIFO2 状态机 ----------
            case (fifo2_state)
                3'd0: begin
                    if (fifo2_en) begin
                        fifo2_state <= 3'd1;
                        wr_en_tag   <= 1'b0;
                        wr_en_cnt   <= 4'd0;
                    end
                end
                3'd1: begin
                    if (write_fifo2_num == 9'd256) begin
                        fifo2_state <= 3'd2;
                        wr_en2      <= 1'b0;
                        wr_en2_2    <= 1'b0;
                        rd_en2      <= 1'b1;
                        fifo2_finish <= 1'b1;
                        dout_sel    <= 1'b0;                // 选择 FIFO2 输出
                        write_fifo2_num <= 9'd0;
                    end else begin
                        if (write_en_sample == 2'b01) begin
                            write_fifo2_num <= write_fifo2_num + 1'b1;
                            if (wr_en_tag) begin
                                wr_en2_2 <= 1'b1;
                            end else begin
                                wr_en2 <= 1'b1;
                            end
                            if (wr_en_cnt == 4'd7) begin
                                wr_en_tag <= ~wr_en_tag;
                                wr_en_cnt <= 4'd0;
                            end else begin
                                wr_en_cnt <= wr_en_cnt + 1'b1;
                            end
                        end else begin
                            wr_en2   <= 1'b0;
                            wr_en2_2 <= 1'b0;
                        end
                    end
                end
                3'd2: begin
                    if (fifo2_finish_cnt == 4'd4) begin
                        fifo2_finish    <= 1'b0;
                        fifo2_finish_cnt <= 4'd0;
                    end else begin
                        fifo2_finish_cnt <= fifo2_finish_cnt + 1'b1;
                    end
                    if (ddr_finish_sample == 2'b01) begin
                        fifo2_state <= 3'd0;
                        rd_en2      <= 1'b0;
                    end
                end
                default: fifo2_state <= 3'd0;
            endcase

            // ===================== O_fifo_finish 输出 =====================
            // 当任一 FIFO 完成一页写入时，输出完成信号给 DDR
            if (fifo1_finish || fifo2_finish) begin
                O_fifo_finish <= 1'b1;
            end else begin
                O_fifo_finish <= 1'b0;
            end
        end
    end

endmodule