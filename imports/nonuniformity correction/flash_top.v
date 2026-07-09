`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Deng Yukun
// 
// Create Date: 2026/01/01 15:52:12
// Design Name: 
// Module Name: flash_top
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

module flash_top
(
    // ===================== 时钟与复位 =====================
    input                           clk_sys             , // 80MHz 系统时钟
    input                           rst_n               , // 复位信号（低有效）

    // ===================== Flash SPI 引脚 =====================
    // 单向信号，顶层 IOBUF 统一管理双向
    output                          flash_clk           , // SPI 时钟（通过 STARTUPE2 输出到 CCLK）
    output                          flash_cs            , // SPI 片选
    output                          D0_o                , // D0 输出（MOSI/写数据 → 顶层 IOBUF）
    input                           D0_i                , // D0 输入（MISO/读数据 ← 顶层 IOBUF）
    output                          D1_o                , // D1 输出（Dual Output 数据线 → 顶层 IOBUF）
    input                           D1_i                , // D1 输入（Dual Output 读数据 ← 顶层 IOBUF）

    // ===================== DDR 接口 =====================
    input                           ddr_init_done       , // DDR 初始化完成信号
    input                           ddr_rd_clk          , // DDR 读时钟（用于 FIFO 跨时钟域）
    input                           read_en             , // 读使能（来自 DDR 控制）
    output                  [127:0] O_flash1_data       , // 输出到 DDR 的 128bit 数据
    input                           ddr_finish          , // DDR 写入完成信号
    input                   [3:0]   wram_rd_addr        , // WRAM 读地址（未使用？）
    output                          fifo_finish         , // FIFO 写入完成（告诉 DDR 已存完一页）
    input                           flash_spi_clk       , // Flash SPI 时钟（来自外部？）
    output                  [8:0]   flash_read_num_test , // 测试输出：已读取的 Flash 页数
    output                  [8:0]   wr_fifo1_count_test , // 测试输出：FIFO1 写入计数
    output                          k_b_finish_O        , // KB 参数读取完成标志

    // ===================== RS422 串口接口 =====================
    input                           I_rs422_rx          , // RS422 接收（与 new_rs422 共用物理引脚）
    output                          O_rs422_tx          , // RS422 发送
    output                          O_rs422_tx_en       , // RS422 发送使能（高有效）

    // ===================== 状态输出（供顶层 TX 方向 MUX 使用） =====================
    output                          O_update_active     , // 1=正在进行 Flash 参数更新，顶层据此切换 RS422 TX 方向
    output                          flash_io_sig        , // 读模式=1(FPGA 高阻 OE=0)，写模式=0(FPGA 驱动 OE=1) → 顶层 IOBUF
    output                          O_spi_read            // spi_wr 正在读 MISO=1 → 顶层 IOBUF 需切为输入模式
);

    // ============================================================================
    // 内部连线定义
    // ============================================================================

    // ---- read_kb_from_flash1 的 SPI 输出 ----
    wire                            rd_flash_cs         ; // 正常读取时的 CS
    wire                            rd_flash_clk        ; // 正常读取时的 CLK（spi_clk_en ? flash_spi_clk : 0）

    // ---- kb_update_top（spi_wr）的 SPI 输出 ----
    wire                            wr_flash_clk        ; // 更新写入时的 CLK
    wire                            wr_flash_cs         ; // 更新写入时的 CS
    wire                            wr_flash_mosi       ; // 更新写入时的 MOSI（输出到 D0）
    wire                            I_wr_flash_miso     ; // 更新写入时的 MISO（从 D0 读取）

    // ---- 更新状态信号 ----
    (* mark_debug = "true" *) wire  update_active       ; // 1=正在更新 Flash，0=正常非均匀校正
    (* mark_debug = "true" *) wire  update_done         ; // 参数更新完成脉冲

    // ---- 数据信号 ----
    wire                    [7:0]   flash1_data         ; // 从 Flash 读出的 8bit 数据
    wire                            write_en            ; // 数据有效信号，作为写一次数据信号
    wire                            shift_sig           ; // SPI 时钟使能（spi_clk_en）

    // ---- FIFO ----
    wire                    [127:0] fifo_output         ; // FIFO 输出（未直接使用）

    // ============================================================================
    // kb_update_top：RS422 参数更新模块
    // 功能：接收 RS422 数据 → 擦除 Flash → 逐页写入新参数 → 触发重新读取
    // ============================================================================
    kb_update_top U_kb_update_top (
        .clk_sys            (clk_sys            ), // 80MHz 系统时钟
        .rst_n              (rst_n              ), // 复位信号
        .flash_spi_clk      (flash_spi_clk      ), // SPI 时钟

        .I_rs422_rx         (I_rs422_rx         ), // RS422 接收
        .O_rs422_tx         (O_rs422_tx         ), // RS422 发送
        .O_rs422_tx_en      (O_rs422_tx_en      ), // RS422 发送使能

        // Flash SPI 写接口
        .O_wr_flash_clk     (wr_flash_clk       ), // 写 Flash 时钟
        .O_wr_flash_cs      (wr_flash_cs        ), // 写 Flash 片选
        .O_wr_flash_mosi    (wr_flash_mosi      ), // 写 Flash MOSI
        .I_wr_flash_miso    (I_wr_flash_miso    ), // 写 Flash MISO

        // 状态输出
        .O_update_active    (update_active      ), // 更新激活标志
        .O_update_done      (update_done        ), // 更新完成脉冲，触发重新读取 Flash
        .O_spi_read         (O_spi_read         )  // SPI 读模式指示
    );

    // ============================================================================
    // STARTUPE2 原语：将 flash_clk 绑定到 FPGA 的 CCLK 专用引脚
    // CCLK 由 MUX 选择：
    //   update_active=0：来自 read_kb（正常读取）
    //   update_active=1：来自 spi_wr（参数更新）
    // ============================================================================
    wire final_flash_clk;
    assign final_flash_clk = update_active ? wr_flash_clk : rd_flash_clk;

    STARTUPE2 #(
        .PROG_USR("FALSE"),  // Activate program event security feature. Requires encrypted bitstreams.
        .SIM_CCLK_FREQ(0.0)  // Set the Configuration Clock Frequency(ns) for simulation.
    )
    STARTUPE2_cclk (
        .GTS(0),             // 1-bit input: Global 3-state input (GTS cannot be used for the port name)
        .USRCCLKO(final_flash_clk),   // 1-bit input: User CCLK input
        .USRCCLKTS(0)        // 1-bit input: User CCLK 3-state enable input
    );

    // ============================================================================
    // SPI 片选 MUX：选择 CS 来源
    //   update_active=0：read_kb_from_flash1 的 CS
    //   update_active=1：spi_wr 的 CS
    // ============================================================================
    assign flash_cs = update_active ? wr_flash_cs : rd_flash_cs;

    // ============================================================================
    // D0/D1 单向信号：
    //   D0_o/D1_o：read_kb 内部驱动（正常读取/Dual Output/写入 MOSI）
    //   D0_i/D1_i：从顶层 IOBUF 输入（读回 Flash 数据）
    //   三态控制全部在 read_kb 内部完成，此处只做直连
    // ============================================================================
    assign I_wr_flash_miso = D0_i; // spi_wr 的 MISO 从 D0_i 读取

    // ============================================================================
    // read_kb_from_flash1：正常模式从 Flash 读取 KB 参数到 DDR（Dual Output Read）
    // ============================================================================
    read_kb_from_flash1_1 read_kb_from_flash1_1 (
        .flash_clk          (rd_flash_clk       ), // Flash 时钟
        .flash_cs           (rd_flash_cs        ), // Flash 片选
        .D0_o               (D0_o               ), // D0 输出 → 顶层 IOBUF
        .D0_i               (D0_i               ), // D0 输入 ← 顶层 IOBUF
        .D1_o               (D1_o               ), // D1 输出 → 顶层 IOBUF
        .D1_i               (D1_i               ), // D1 输入 ← 顶层 IOBUF
        .flash_spi_clk      (flash_spi_clk      ), // SPI 时钟输入
        .CLK                (clk_sys            ), // 系统时钟 80MHz
        .flash_rstn         (rst_n              ), // 复位信号
        .ddr_init_done      (ddr_init_done      ), // DDR 初始化完成
        .k_b_finish_O       (k_b_finish_O       ), // KB 读取完成
        .mydata_o           (flash1_data        ), // 输出 Flash 数据（8bit）
        .myvalid_o          (write_en           ), // 数据有效信号
        .shift_sig          (shift_sig          ), // SPI 时钟使能输出
        .o_data_sim         (                   ), // 仿真数据（未用）
        .flash_read_num_test(flash_read_num_test), // 测试：已读页数

        // RS422 参数更新接口
        .update_active      (update_active      ), // 高有效时本模块暂停并将 wr_mosi 输出到 D0
        .re_read_req        (update_done        ), // 更新完成时触发重新读取
        .I_wr_mosi          (wr_flash_mosi      ), // 更新模式下写入 D0 的 MOSI 数据
        .flash_io_sig       (flash_io_sig       )  // 读模式=1(FPGA 高阻)，写模式=0(FPGA 驱动) → 顶层 IOBUF OE
    );

    // ============================================================================
    // flash1_to_ddr_ram：将从 Flash 读出的 8bit 数据拼接成 128bit，并写入 DDR
    // ============================================================================
    flash1_to_ddr_ram flash1_to_ddr_ram (
        .I_clk              (clk_sys            ), // 系统时钟 80MHz
        .rst_n              (rst_n              ), // 复位信号
        .flash1_data        (flash1_data        ), // 输入的 8bit Flash 数据
        .I_shift_sig        (shift_sig          ), // SPI 时钟使能
        .write_en           (write_en           ), // 数据有效信号
        .read_clk           (ddr_rd_clk         ), // DDR 读时钟（用于跨时钟域）
        .read_en            (read_en            ), // DDR 读使能
        .I_ddr_finish       (ddr_finish         ), // DDR 已完成一页的写入
        .O_ddr_data         (O_flash1_data      ), // 输出 128bit 数据给 DDR
        .O_fifo_finish      (fifo_finish        )  // 告诉 DDR 已完成一页的存储
    );

    // ============================================================================
    // 状态输出：将 update_active 输出给顶层，供 new_rs422 和 kb_update_top 的 TX 方向仲裁
    // ============================================================================
    assign O_update_active = update_active;

endmodule