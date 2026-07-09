`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Deng Yukun
// 
// Create Date: 2026/01/01 15:52:12
// Design Name: 
// Module Name: kb_update_top
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

module kb_update_top
(
    // ===================== 时钟与复位 =====================
    input                           clk_sys             , // 80MHz 系统时钟
    input                           rst_n               , // 低有效复位
    input                           flash_spi_clk       , // SPI 时钟（来自 bihua_openW 现有时钟）

    // ===================== RS422 串口接口 =====================
    input                           I_rs422_rx          , // RS422 接收
    output                          O_rs422_tx          , // RS422 发送
    output                          O_rs422_tx_en       , // RS422 发送使能（高=发送；可接 DE/RE）

    // ===================== Flash SPI 写接口 =====================
    // 在 update_active 时由 flash_top 多路选择
    output                          O_wr_flash_clk      , // Flash SPI 时钟
    output                          O_wr_flash_cs       , // Flash SPI 片选
    output                          O_wr_flash_mosi     , // Flash SPI MOSI
    input                           I_wr_flash_miso     , // Flash SPI MISO

    // ===================== 状态输出 =====================
    (* mark_debug = "true" *) output O_update_active     , // 更新进行中标志（高有效）
    (* mark_debug = "true" *) output O_update_done       , // 更新完成脉冲（1个 clk_sys 周期高脉冲）
    output                          O_spi_read            // spi_wr 正在读 MISO=1（顶层 IOBUF 需切为输入模式）
);

    // ===================== 内部连线 =====================
    wire                            es_done             ; // Flash 擦除完成
    wire                            wr_done             ; // Flash 编程完成

    // UART 到 Flash 的控制信号
    wire                            start_erase_req     ; // 开始擦除请求
    wire                            packet_ready_req    ; // 数据包准备就绪请求
    wire                            wr_bank             ; // 乒乓 RAM 写 Bank 选择
    wire                            rd_bank             ; // 乒乓 RAM 读 Bank 选择

    // 乒乓 RAM 接口
    wire                            ping_pong_wr_en     ; // 乒乓 RAM 写使能
    wire                    [8:0]   ping_pong_wr_addr   ; // 乒乓 RAM 写地址
    wire                    [7:0]   ping_pong_wr_data   ; // 乒乓 RAM 写数据
    wire                    [8:0]   ping_pong_rd_addr   ; // 乒乓 RAM 读地址
    wire                    [7:0]   ping_pong_rd_data   ; // 乒乓 RAM 读数据

    // SPI 接口连线
    wire                    [7:0]   flash_cmd           ; // SPI 命令
    wire                    [23:0]  flash_addr          ; // SPI 地址
    wire                    [3:0]   cmd_type            ; // 命令类型（擦除/编程等）
    wire                            clock25M            ; // 25MHz 时钟（分频后）
    wire                            Done_Sig            ; // SPI 操作完成信号
    wire                    [7:0]   mydata_o            ; // 从 Flash 读回的数据（未用）
    wire                            myvalid_o           ; // 数据有效标志（未用）

    wire                            wr_flash_clk_wire   ; // 内部 SPI 时钟
    wire                            wr_flash_cs_wire    ; // 内部 SPI 片选
    wire                            wr_flash_mosi_wire  ; // 内部 SPI MOSI
    wire                            update_active_wire  ; // 更新激活内部信号
    wire                            spi_read_wire       ; // SPI 读模式指示

    // ===================== update_done 脉冲生成（wr_done 上升沿） =====================
    reg                     [1:0]   wr_done_r           ;
    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n)
            wr_done_r <= 2'b00;
        else begin
            wr_done_r[0] <= wr_done;
            wr_done_r[1] <= wr_done_r[0];
        end
    end

    assign O_update_done = wr_done_r[0] & ~wr_done_r[1]; // 上升沿脉冲
    assign O_update_active = update_active_wire;

    // ===================== 乒乓缓存模块 =====================
    ping_pong_ram U_ping_pong_ram (
        .wr_clk                 (clk_sys            ), // 写时钟 = 系统时钟
        .wr_en                  (ping_pong_wr_en    ),
        .wr_bank                (wr_bank            ),
        .wr_addr                (ping_pong_wr_addr  ),
        .wr_data                (ping_pong_wr_data  ),

        .rd_clk                 (~flash_spi_clk     ), // 读时钟用 SPI 时钟反相，保证时序余量
        .rd_bank                (rd_bank            ),
        .rd_addr                (ping_pong_rd_addr  ),
        .rd_data                (ping_pong_rd_data  )
    );

    // ===================== UART 接收 + 命令处理模块 =====================
    uart_top_422 U_uart_top_422 (
        .CLK                    (clk_sys            ),
        .rst_n                  (rst_n              ),
        .I_rs422_rx             (I_rs422_rx         ),
        .O_rs422_tx             (O_rs422_tx         ),
        .O_tx_en                (O_rs422_tx_en      ),

        // RAM 写入接口
        .O_ping_pong_wr_en      (ping_pong_wr_en    ),
        .O_ping_pong_wr_addr    (ping_pong_wr_addr  ),
        .O_ping_pong_wr_data    (ping_pong_wr_data  ),
        .O_wr_bank              (wr_bank            ),

        // 控制接口
        .O_start_erase_req      (start_erase_req    ),
        .O_packet_ready_req     (packet_ready_req   ),
        .I_es_done              (es_done            ),
        .I_wr_done              (wr_done            )
    );

    // ===================== Flash 擦除/编程控制状态机 =====================
    flash_control_kb U_flash_control_kb (
        .CLK                    (clk_sys            ),
        .RSTn                   (rst_n              ),
        .clk_spi                (flash_spi_clk      ),
        .clock25M               (clock25M           ),
        .cmd_type               (cmd_type           ),
        .Done_Sig               (Done_Sig           ),
        .flash_cmd              (flash_cmd          ),
        .flash_addr             (flash_addr         ),
        .mydata_o               (mydata_o           ),
        .myvalid_o              (myvalid_o          ),

        // UART 控制输入
        .I_start_erase_req      (start_erase_req    ),
        .I_packet_ready_req     (packet_ready_req   ),
        .O_rd_bank              (rd_bank            ), // 输出给 RAM 读选择

        .O_es_done              (es_done            ),
        .O_wr_done              (wr_done            ),
        .O_update_active        (update_active_wire )
    );

    // ===================== SPI 写通信模块 =====================
    spi_wr U_spi_wr (
        .flash_clk              (wr_flash_clk_wire  ),
        .flash_cs               (wr_flash_cs_wire   ),
        .flash_datain           (wr_flash_mosi_wire ),
        .flash_dataout          (I_wr_flash_miso    ),
        .CLK                    (clk_sys            ),
        .clock25M               (clock25M           ),
        .flash_rstn             (rst_n              ),
        .clk_spi                (flash_spi_clk      ),
        .cmd_type               (cmd_type           ),
        .Done_Sig               (Done_Sig           ),
        .flash_cmd              (flash_cmd          ),
        .flash_addr             (flash_addr         ),

        // 乒乓 RAM 读接口
        .O_ping_pong_rd_addr    (ping_pong_rd_addr  ),
        .I_ping_pong_rd_data    (ping_pong_rd_data  ),

        .mydata_o               (mydata_o           ),
        .myvalid_o              (myvalid_o          ),
        .O_spi_read             (spi_read_wire      )
    );

    // ===================== SPI 引脚输出连接 =====================
    assign O_wr_flash_clk  = wr_flash_clk_wire;
    assign O_wr_flash_cs   = wr_flash_cs_wire;
    assign O_wr_flash_mosi = wr_flash_mosi_wire;
    assign O_spi_read      = spi_read_wire;

endmodule