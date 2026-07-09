`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Deng Yukun
// 
// Create Date: 2026/01/01 15:52:12
// Design Name: 
// Module Name: uart_top_422
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

module uart_top_422
(
    // ===================== 时钟与复位 =====================
    input                           CLK                 , // 系统时钟 80MHz
    input                           rst_n               , // 复位信号（低有效）

    // ===================== RS422 接口 =====================
    input                           I_rs422_rx          , // RS422 接收数据
    output                          O_rs422_tx          , // RS422 发送数据
    output                          O_tx_en             , // RS422 发送使能（低有效）

    // ===================== 乒乓 RAM 写接口 =====================
    output reg                      O_ping_pong_wr_en   , // 乒乓 RAM 写使能
    output reg              [8:0]   O_ping_pong_wr_addr , // 乒乓 RAM 写地址
    output reg              [7:0]   O_ping_pong_wr_data , // 乒乓 RAM 写数据
    output reg                      O_wr_bank           , // 乒乓 RAM 写 Bank 选择

    // ===================== Flash 控制接口 =====================
    output reg                      O_start_erase_req   , // 启动擦除请求
    output reg                      O_packet_ready_req  , // 数据包准备好请求
    input                           I_es_done           , // Flash 擦除完成
    input                           I_wr_done             // Flash 编程完成
);

    // ===================== 内部信号定义 =====================
    wire                            txclk               ; // UART 发送波特率时钟
    wire                            rxclk               ; // UART 接收波特率时钟
    wire                            rx_rdy              ; // 接收数据就绪
    wire                            tx_busy             ; // 发送忙标志
    wire                    [7:0]   rx_data             ; // 接收数据

    reg                     [7:0]   tx_data             ; // 发送数据寄存器
    reg                             get_data            ; // 获取数据标志
    reg                             tx_en               ; // 发送使能内部寄存器
    reg                             send_en             ; // 发送使能（给 uart_tx）
    reg                             send_rdy            ; // 发送就绪
    reg                     [5:0]   send_cnt            ; // 发送计数
    reg                     [1:0]   send_fsm            ; // 发送状态机
    reg                     [31:0]  cnt_tx_delay        ; // 发送延时计数器

    reg                     [1:0]   es_done             ; // I_es_done 同步打拍
    reg                     [1:0]   wr_done             ; // I_wr_done 同步打拍

    reg                     [5:0]   receive_fsm         ; // 接收状态机
    reg                     [7:0]   sum                 ; // 校验和累加器
    reg                     [7:0]   packdata[1:0]       ; // 发送应答包数据（2字节）
    reg                     [8:0]   pack_byte_cnt       ; // 负载字节计数（0~511）
    reg                     [31:0]  pack_id             ; // 当前包 ID
    reg                     [7:0]   rx_data_d1          ; // 接收数据打拍，用于检测 0x905A
    reg                     [31:0]  last_pack_id        ; // 上一个包 ID（防重传）
    reg                             is_erase_cmd        ; // 当前命令是否为擦除命令

    reg                     [1:0]   rxclk_sample        ; // rxclk 采样打拍
    reg                     [1:0]   txclk_sample        ; // txclk 采样打拍

    // ===================== 实例化子模块 =====================
    uart_rx U_1 (
        .I_clk          (CLK                ),
        .I_rst          (rst_n              ),
        .I_rxclk        (rxclk              ),
        .I_rx           (I_rs422_rx         ),
        .I_get_data     (get_data           ),
        .O_rx_data      (rx_data            ),
        .O_rx_rdy       (rx_rdy             )
    );

    uart_tx U_2 (
        .I_clk          (CLK                ),
        .I_rst          (rst_n              ),
        .I_txclk        (txclk              ),
        .I_tx_data      (tx_data            ),
        .I_tx_en        (send_en            ),
        .O_tx           (O_rs422_tx         ),
        .O_tx_busy      (tx_busy            )
    );

    uart_baudrate U_3 (
        .I_clk          (CLK                ),
        .I_rst          (rst_n              ),
        .O_txclk        (txclk              ),
        .O_rxclk        (rxclk              )
    );

    // ===================== 异步信号同步打拍 =====================
    always @(posedge CLK) begin
        if (!rst_n) begin
            rxclk_sample <= 2'b00;
            txclk_sample <= 2'b00;
            es_done      <= 2'b00;
            wr_done      <= 2'b00;
        end else begin
            rxclk_sample <= {rxclk_sample[0], rxclk};
            txclk_sample <= {txclk_sample[0], txclk};
            es_done      <= {es_done[0], I_es_done};
            wr_done      <= {wr_done[0], I_wr_done};
        end
    end

    // 检测完成信号的上升沿
    wire es_done_pulse = es_done[0] & ~es_done[1];
    wire wr_done_pulse = wr_done[0] & ~wr_done[1];

    // ===================== 接收处理状态机 =====================
    always @(posedge CLK) begin
        if (!rst_n) begin
            receive_fsm         <= 5'd0;
            sum                 <= 8'd0;
            rx_data_d1          <= 8'd0;
            packdata[0]         <= 8'd0;
            packdata[1]         <= 8'd0;
            send_rdy            <= 1'b0;
            get_data            <= 1'b0;
            O_ping_pong_wr_en   <= 1'b0;
            O_ping_pong_wr_addr <= 9'd0;
            O_ping_pong_wr_data <= 8'd0;
            O_wr_bank           <= 1'b0;
            O_start_erase_req   <= 1'b0;
            O_packet_ready_req  <= 1'b0;
            pack_byte_cnt       <= 9'd0;
            last_pack_id        <= 32'hFFFF_FFFF;
            is_erase_cmd        <= 1'b0;
        end else begin
            if (send_rdy)
                send_rdy <= 1'b0;            // 清除发送就绪标志
            O_ping_pong_wr_en <= 1'b0;       // 默认拉低写使能

            // 跨域异步脉冲触发回复
            if (es_done_pulse) begin
                send_rdy <= 1'b1;
                receive_fsm <= 5'd0;
                packdata[0] <= 8'hbb;
                packdata[1] <= 8'hbb;
            end
            if (wr_done_pulse) begin
                send_rdy <= 1'b1;
                receive_fsm <= 5'd0;
                packdata[0] <= 8'hdd;
                packdata[1] <= 8'hdd;
            end

            // 接收数据采样
            if (rxclk_sample == 2'b10) begin
                if (get_data)
                    get_data <= 1'b0;
                if (rx_rdy) begin
                    get_data <= 1'b1;
                    rx_data_d1 <= rx_data;

                    case (receive_fsm)
                        0: begin
                            // 统一入口：等待帧头 0x905A
                            if ({rx_data_d1, rx_data} == 16'h905A) begin
                                receive_fsm <= 5'd11;
                            end else begin
                                receive_fsm <= 5'd0;
                            end
                        end

                        // ========== 解析帧头 ==========
                        11: begin
                            if (rx_data == 8'hFF) receive_fsm <= 5'd12;
                            else receive_fsm <= 5'd0;
                        end
                        12: begin
                            if (rx_data == 8'h07) receive_fsm <= 5'd13;
                            else receive_fsm <= 5'd0;
                        end

                        // 接收包号（不参与校验）
                        13: begin pack_id[31:24] <= rx_data; receive_fsm <= 5'd14; end
                        14: begin pack_id[23:16] <= rx_data; receive_fsm <= 5'd15; end
                        15: begin pack_id[15:8]  <= rx_data; receive_fsm <= 5'd16; end
                        16: begin pack_id[7:0]   <= rx_data; receive_fsm <= 5'd17; end

                        // ========== 开始校验和计算 ==========
                        // 从包长度的高字节 0x02 开始，sum 重新起算
                        17: begin
                            if (rx_data == 8'h02) begin
                                sum <= rx_data; receive_fsm <= 5'd18;
                            end else receive_fsm <= 5'd0;
                        end
                        18: begin
                            if (rx_data == 8'h0B) begin
                                sum <= sum + rx_data; receive_fsm <= 5'd19;
                            end else receive_fsm <= 5'd0;
                        end

                        // 核心分流：命令字节（0x22 擦除 或 0x33 写数据）
                        19: begin
                            if (rx_data == 8'h22 || rx_data == 8'h33) begin
                                is_erase_cmd <= (rx_data == 8'h22); // 记录命令类型
                                sum <= sum + rx_data;               // 累加命令字节
                                pack_byte_cnt <= 9'd0;
                                receive_fsm <= 5'd20;
                            end else begin
                                receive_fsm <= 5'd0; // 命令字非法，丢弃
                            end
                        end

                        // ========== 接收 512 字节负载 ==========
                        20: begin
                            sum <= sum + rx_data; // 无论擦除还是数据，512 字节全部参与校验

                            // 如果是数据包（0x33），才允许写入乒乓 RAM；如果是擦除包，则只空转计算校验和
                            if (!is_erase_cmd) begin
                                O_ping_pong_wr_en <= 1'b1;
                                O_ping_pong_wr_addr <= pack_byte_cnt;
                                O_ping_pong_wr_data <= rx_data;
                            end

                            if (pack_byte_cnt == 9'd511)
                                receive_fsm <= 5'd21;
                            else
                                pack_byte_cnt <= pack_byte_cnt + 1'b1;
                        end

                        // ========== 对比校验和与触发 ==========
                        21: begin
                            if (rx_data == sum) begin
                                if (is_erase_cmd) begin
                                    // 0x22 擦除命令
                                    O_start_erase_req <= ~O_start_erase_req;
                                    O_wr_bank <= 1'b0;
                                    last_pack_id <= 32'hFFFF_FFFF;
                                    send_rdy <= 1'b1;
                                    packdata[0] <= 8'haa;
                                    packdata[1] <= 8'haa;
                                end else begin
                                    // 0x33 数据包命令
                                    if (pack_id != last_pack_id) begin // 防重传保护
                                        O_wr_bank <= ~O_wr_bank;
                                        O_packet_ready_req <= ~O_packet_ready_req;
                                        last_pack_id <= pack_id;
                                    end
                                    send_rdy <= 1'b1;
                                    packdata[0] <= 8'hcc;
                                    packdata[1] <= 8'hcc;
                                end
                            end else begin
                                // 校验错误，要求重传
                                send_rdy <= 1'b1;
                                packdata[0] <= 8'hee;
                                packdata[1] <= 8'hee;
                            end
                            receive_fsm <= 5'd0;
                        end

                        default: receive_fsm <= 5'd0;
                    endcase
                end
            end
        end
    end

    // ===================== 发送控制状态机 =====================
    always @(posedge CLK) begin
        if (!rst_n) begin
            tx_data         <= 8'd0;
            tx_en           <= 1'b0;
            send_cnt        <= 6'd0;
            send_en         <= 1'b0;
            send_fsm        <= 2'd0;
            cnt_tx_delay    <= 32'd0;
        end else begin
            case (send_fsm)
                0: begin
                    if (send_rdy)
                        send_fsm <= 2'd1;
                end
                1: begin
                    if (cnt_tx_delay == 32'd7999) begin
                        send_fsm <= 2'd2;
                        tx_en <= 1'b1;
                        cnt_tx_delay <= 32'd0;
                    end else begin
                        cnt_tx_delay <= cnt_tx_delay + 1'b1;
                    end
                end
                2: begin
                    if (txclk_sample == 2'b10) begin
                        if (send_cnt < 6'd2) begin
                            if (!tx_busy) begin
                                tx_data <= packdata[send_cnt];
                                send_cnt <= send_cnt + 1'b1;
                                send_en <= 1'b1;
                            end
                        end else begin
                            if (!tx_busy) begin
                                send_fsm <= 2'd3;
                                send_cnt <= 6'd0;
                            end
                        end
                        if (send_en)
                            send_en <= 1'b0;
                    end
                end
                3: begin
                    tx_en <= 1'b0;
                    send_fsm <= 2'd0;
                end
            endcase
        end
    end

    // ===================== 输出赋值 =====================
    assign O_tx_en = ~tx_en; // 低有效

endmodule