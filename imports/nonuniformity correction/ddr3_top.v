`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Deng Yukun
// 
// Create Date: 2026/01/01 15:52:12
// Design Name: 
// Module Name: DDR3_top
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

module ddr3_top
(
    // ===================== 时钟与复位 =====================
    input                           I_clk               , // 系统时钟（80MHz）
    input                           I_rst               , // 复位信号
    input                           clk_200MHz          , // 200MHz 时钟（用于 MIG）

    // ===================== Flash 接口 =====================
    output                          flash_clk           , // Flash 时钟
    output                          flash_cs            , // Flash 片选
    output                          D0_o                , // D0 输出（MOSI/写数据 → 顶层 IOBUF）
    input                           D0_i                , // D0 输入（MISO/读数据 ← 顶层 IOBUF）
    output                          D1_o                , // D1 输出（Dual Output 数据线 → 顶层 IOBUF）
    input                           D1_i                , // D1 输入（Dual Output 读数据 ← 顶层 IOBUF）

    // ===================== DDR3 接口 =====================
    inout                   [15:0]  ddr3_dq             , // DDR3 数据
    inout                   [1:0]   ddr3_dqs_n          , // DDR3 DQS 负
    inout                   [1:0]   ddr3_dqs_p          , // DDR3 DQS 正
    output                  [14:0]  ddr3_addr           , // DDR3 地址
    output                  [2:0]   ddr3_ba             , // DDR3 Bank 选择
    output                          ddr3_ras_n          , // DDR3 行选
    output                          ddr3_cas_n          , // DDR3 列选
    output                          ddr3_we_n           , // DDR3 写使能
    output                          ddr3_reset_n        , // DDR3 复位
    output                  [0:0]   ddr3_ck_p           , // DDR3 时钟正
    output                  [0:0]   ddr3_ck_n           , // DDR3 时钟负
    output                  [0:0]   ddr3_cke            , // DDR3 时钟使能
    output                  [0:0]   ddr3_cs_n           , // DDR3 片选
    output                  [1:0]   ddr3_dm             , // DDR3 数据掩码
    output                  [0:0]   ddr3_odt            , // DDR3 ODT

    // ===================== DDR3 状态输出 =====================
    output                          O_init_calib_complete, // MIG 初始化校准完成
    output                          O_ddr_wr_finish     , // DDR 写完成
    output                          O_rram_rq_read      , // RRAM 读请求

    // ===================== 内部交互接口 =====================
    (*mark_debug = "true"*) output  fifo_ddr_done       , // FIFO 到 DDR 写入完成
    output                  [127:0] o_kb_data           , // KB 校正系数数据（128bit）
    input                   [9:0]   rram_read_addr1     , // RRAM 读地址1
    input                   [9:0]   rram_read_addr2     , // RRAM 读地址2
    input                           read_ram_finish1    , // RAM1 读取完成
    input                           read_ram_finish2    , // RAM2 读取完成
    input                           rram_rclk           , // RRAM 读时钟
    input                           flash_spi_clk       , // Flash SPI 时钟

    // ===================== RS422 参数更新接口 =====================
    input                           I_rs422_rx          , // RS422 接收数据
    output                          O_rs422_tx          , // RS422 发送数据
    output                          O_rs422_tx_en       , // RS422 发送使能
    output                          O_update_active     , // 1=参数更新中，供顶层 RS422 TX 方向 MUX
    output                          flash_io_sig        , // 读模式=1(FPGA高阻)，写模式=0(FPGA驱动) → 顶层 IOBUF
    output                          O_spi_read          , // SPI 读模式指示（MISO 切换为输入）

    // ===================== 其他状态输出 =====================
    output                          k_b_finish_O        , // KB 校正系数读取完成
    output                          O_fifo_sample_finish  // FIFO 采样完成
);

    // ===================== 内部信号定义 =====================
    wire                            ui_clk              ; // 用户时钟（来自 MIG）
    wire                    [28:0]  app_addr            ; // DDR3 应用地址
    wire                    [2:0]   app_cmd             ; // 用户读写命令
    wire                            app_en              ; // MIG IP 核使能
    wire                            app_rdy             ; // MIG IP 核就绪
    wire                    [127:0] app_rd_data         ; // 用户读数据
    wire                            app_rd_data_end     ; // 突发读当前时钟最后一个数据
    wire                            app_rd_data_valid   ; // 读数据有效
    wire                    [127:0] app_wdf_data        ; // 用户写数据
    wire                            app_wdf_end         ; // 突发写当前时钟最后一个数据
    wire                    [7:0]   app_wdf_mask        ; // 写数据掩码
    wire                            app_wdf_rdy         ; // 写就绪（DDR 是否接收数据）
    wire                            app_sr_active       ; // 保留
    wire                            app_ref_ack         ; // 刷新请求响应
    wire                            app_zq_ack          ; // ZQ 校准请求响应
    wire                            app_wdf_wren        ; // DDR3 写使能
    wire                            ui_clk_sync_rst     ; // 用户复位信号
    wire                            rram_wren           ; // 从 DDR3 读出数据的有效使能
    wire                            I_ddr_w_finish      ; // DDR 写完成（内部）
    wire                            fifo_sample_finish  ; // FIFO 采样完成
    wire                            ddr_wr_finish       ; // DDR 写完成
    wire                            init_calib_complete ; // MIG 初始化校准完成
    wire                            read_ram_en         ; // 读 RAM 使能
    wire                            rram_rq_read        ; // RRAM 读请求
    wire                    [3:0]   wram_rd_addr        ; // WRAM 读地址
    wire                            ddr_init_done       ; // DDR 初始化完成（用于 Flash 启动）

    // ===================== 输出赋值 =====================
    assign O_init_calib_complete = init_calib_complete;
    assign O_ddr_wr_finish       = ddr_wr_finish;
    assign O_rram_rq_read        = rram_rq_read;
    assign O_fifo_sample_finish  = fifo_sample_finish;
    assign ddr_init_done         = (init_calib_complete & (app_wdf_rdy & app_rdy));

    // ===================== Flash 顶层模块实例化 =====================
    // 负责从 Flash 读取校正系数并写入 DDR，同时通过 RS422 接口进行参数更新
    flash_top u_flash_top (
        .clk_sys            (I_clk              ), // 80MHz 系统时钟
        .rst_n              (I_rst              ), // 复位信号
        .flash_clk          (flash_clk          ), // Flash 时钟
        .flash_cs           (flash_cs           ), // Flash 片选
        .D0_o               (D0_o               ), // D0 输出 → 顶层 IOBUF
        .D0_i               (D0_i               ), // D0 输入 ← 顶层 IOBUF
        .D1_o               (D1_o               ), // D1 输出 → 顶层 IOBUF
        .D1_i               (D1_i               ), // D1 输入 ← 顶层 IOBUF
        .ddr_init_done      (ddr_init_done      ), // DDR 初始化完成，Flash 开始读取
        .ddr_rd_clk         (ui_clk             ), // 来自 DDR 的用户时钟
        .read_en            (app_wdf_wren       ), // 写使能（用于控制 Flash 数据写入 DDR）
        .O_flash1_data      (app_wdf_data       ), // 128bit FIFO -> DDR
        .ddr_finish         (ddr_wr_finish      ), // 来自 DDR 的写完成信号
        .wram_rd_addr       (wram_rd_addr       ), // WRAM 读地址
        .fifo_finish        (fifo_sample_finish ), // 输出到 DDR，FIFO 已写入一行
        .flash_spi_clk      (flash_spi_clk      ), // Flash SPI 时钟
        .k_b_finish_O       (k_b_finish_O       ), // KB 校正系数读取完成

        // RS422 参数更新接口
        .I_rs422_rx         (I_rs422_rx         ), // RS422 接收
        .O_rs422_tx         (O_rs422_tx         ), // RS422 发送
        .O_rs422_tx_en      (O_rs422_tx_en      ), // RS422 发送使能
        .O_update_active    (O_update_active    ), // 更新激活标志
        .flash_io_sig       (flash_io_sig       ), // 读模式=1(FPGA 高阻), 写模式=0 → 顶层 IOBUF
        .O_spi_read         (O_spi_read         )  // SPI 读模式（MISO 切换为输入）
    );

    // ===================== DDR3 双 RAM FIFO 模块实例化 =====================
    // 负责从 DDR 读取数据到两个 RAM（乒乓），并输出校正系数
    ddr3_double_ram_fifo u_ddr3_double_ram_fifo (
        .I_clk              (I_clk              ), // 系统时钟
        .rst_n              (I_rst              ), // 复位信号
        .ui_clk             (ui_clk             ), // 用户时钟（来自 MIG）
        .rram_rclk          (rram_rclk          ), // RRAM 读时钟
        .I_rram_read_addr1  (rram_read_addr1    ), // RRAM 读地址1
        .I_rram_read_addr2  (rram_read_addr2    ), // RRAM 读地址2
        .read_ram_finish1   (read_ram_finish1   ), // RAM1 读取完成
        .read_ram_finish2   (read_ram_finish2   ), // RAM2 读取完成
        .rram_din           (app_rd_data        ), // 用户读数据（来自 DDR）
        .rram_wren          (rram_wren          ), // == app_rd_data_valid，DDR 读出数据的有效使能
        .rram_shift_sig     (read_ram_en        ), // 读 RAM 切换信号
        .ram_rq_read        (rram_rq_read       ), // 输出读请求
        .o_kb_data          (o_kb_data          )  // 输出 128bit 校正系数数据
    );

    // ===================== DDR 读写控制模块实例化 =====================
    ddr3_rw u_ddr3_rw (
        .ui_clk                 (ui_clk             ), // 用户时钟
        .ui_clk_sync_rst        (ui_clk_sync_rst    ), // 用户同步复位
        .init_calib_complete    (init_calib_complete), // 初始化校准完成
        .app_rdy                (app_rdy            ), // 应用就绪
        .app_wdf_rdy            (app_wdf_rdy        ), // 写就绪
        .app_rd_data_valid      (app_rd_data_valid  ), // 读数据有效
        .I_wram_sample_finish   (fifo_sample_finish ), // 写 RAM 采样完成
        .I_rram_rq_read         (rram_rq_read       ), // RRAM 读请求
        .rram_wren              (rram_wren          ), // == app_rd_data_valid
        .app_addr               (app_addr           ), // 输出应用地址
        .app_en                 (app_en             ), // 输出应用使能
        .app_wdf_wren           (app_wdf_wren       ), // 输出写使能
        .app_wdf_end            (app_wdf_end        ), // 输出写结束
        .app_cmd                (app_cmd            ), // 输出命令
        .ddr_wr_finish          (ddr_wr_finish      ), // 输出 DDR 写完成
        .fifo_ddr_done          (fifo_ddr_done      ), // 输出 FIFO 到 DDR 完成
        .read_ram_en            (read_ram_en        ), // 输出读 RAM 使能
        .wram_rd_addr           (wram_rd_addr       )  // 输出 WRAM 读地址
    );

    // ===================== MIG DDR3 IP 核实例化 =====================
    mig_7series_0 u_ddr3_mig (
        // Memory interface ports
        .ddr3_addr              (ddr3_addr          ), // output [14:0] ddr3_addr
        .ddr3_ba                (ddr3_ba            ), // output [2:0]   ddr3_ba
        .ddr3_cas_n             (ddr3_cas_n         ), // output         ddr3_cas_n
        .ddr3_ck_n              (ddr3_ck_n          ), // output [0:0]   ddr3_ck_n
        .ddr3_ck_p              (ddr3_ck_p          ), // output [0:0]   ddr3_ck_p
        .ddr3_cke               (ddr3_cke           ), // output [0:0]   ddr3_cke
        .ddr3_ras_n             (ddr3_ras_n         ), // output         ddr3_ras_n
        .ddr3_reset_n           (ddr3_reset_n       ), // output         ddr3_reset_n
        .ddr3_we_n              (ddr3_we_n          ), // output         ddr3_we_n
        .ddr3_dq                (ddr3_dq            ), // inout [15:0]   ddr3_dq
        .ddr3_dqs_n             (ddr3_dqs_n         ), // inout [1:0]    ddr3_dqs_n
        .ddr3_dqs_p             (ddr3_dqs_p         ), // inout [1:0]    ddr3_dqs_p
        .init_calib_complete    (init_calib_complete), // output         init_calib_complete
        .ddr3_cs_n              (ddr3_cs_n          ), // output [0:0]   ddr3_cs_n
        .ddr3_dm                (ddr3_dm            ), // output [1:0]   ddr3_dm
        .ddr3_odt               (ddr3_odt           ), // output [0:0]   ddr3_odt

        // Application interface ports
        .app_addr               (app_addr           ), // input [28:0]   app_addr
        .app_cmd                (app_cmd            ), // input [2:0]    app_cmd
        .app_en                 (app_en             ), // input          app_en
        .app_wdf_data           (app_wdf_data       ), // input [127:0]  app_wdf_data
        .app_wdf_end            (app_wdf_end        ), // input          app_wdf_end
        .app_wdf_wren           (app_wdf_wren       ), // input          app_wdf_wren
        .app_rd_data            (app_rd_data        ), // output [127:0] app_rd_data
        .app_rd_data_end        (app_rd_data_end    ), // output         app_rd_data_end
        .app_rd_data_valid      (app_rd_data_valid  ), // output         app_rd_data_valid
        .app_rdy                (app_rdy            ), // output         app_rdy
        .app_wdf_rdy            (app_wdf_rdy        ), // output         app_wdf_rdy
        .app_sr_req             (1'b0               ), // input          app_sr_req
        .app_ref_req            (1'b0               ), // input          app_ref_req
        .app_zq_req             (1'b0               ), // input          app_zq_req
        .app_sr_active          (app_sr_active      ), // output         app_sr_active
        .app_ref_ack            (app_ref_ack        ), // output         app_ref_ack
        .app_zq_ack             (app_zq_ack         ), // output         app_zq_ack
        .ui_clk                 (ui_clk             ), // output         ui_clk
        .ui_clk_sync_rst        (ui_clk_sync_rst    ), // output         ui_clk_sync_rst
        .app_wdf_mask           (16'b0              ), // input [15:0]   app_wdf_mask

        // System Clock Ports
        .sys_clk_i              (clk_200MHz         ), // input          sys_clk_i
        .sys_rst                (I_rst              )  // input          sys_rst
    );

endmodule