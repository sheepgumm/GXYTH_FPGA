`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Deng Yukun
// 
// Create Date: 2026/01/01 15:52:12
// Design Name: 
// Module Name: LWIR_top
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


module top(
    // ==========================================
    // 1. 系统全局时钟 (System Clock)
    // ==========================================
    input                   I_CLK40M                    , // 40MHz 外部输入时钟
    
    // ==========================================
    // 2. 探测器控制与数据接口 (Detector Interface)
    // ==========================================
    output                  det_rst_b                   , // 探测器复位信号 (低有效)
    output                  det_data                    , // 探测器串行配置数据
    output                  fpga_det_mclk               , // 探测器主时钟
    output                  fpga_det_int                , // 探测器积分控制信号
    input                   fpga_det_valid              , // 探测器数据有效信号
    input                   fpga_det_error              , // 探测器错误状态指示
    
    // 探测器电源控制 (Detector Power Control)
    output                  fpga_pwr_ctrl1              , // 电源控制 1
    output                  fpga_pwr_ctrl2              , // 电源控制 2
    output                  fpga_pwr_ctrl3              , // 电源控制 3

    // ==========================================
    // 3. 状态指示与按键 (LEDs & Buttons)
    // ==========================================
    output                  led                         , // 系统状态指示灯
    input                   button1                     , // 按键 1
    input                   button2                     , // 按键 2
    input                   button3                     , // 按键 3
    input                   button4                     , // 按键 4

    // ==========================================
    // 4. GTX 高速收发器接口 (GTX Transceiver)
    // ==========================================
    input                   Q0_CLK1_GTREFCLK_PAD_P_IN   , // GTX 参考时钟 (正)
    input                   Q0_CLK1_GTREFCLK_PAD_N_IN   , // GTX 参考时钟 (负)
    output                  TXP_OUT                     , // GTX 高速串行发送数据 (正)
    output                  TXN_OUT                     , // GTX 高速串行发送数据 (负)
    //output  TXP_OUT1,
    //output  TXN_OUT1,

    // ==========================================
    // 5. 温度传感器接口 (Temperature Sensors)
    // ==========================================
    inout                   IO_ds18b20_ctrl_dq          , // DS18B20 温度传感器数据线 (控制板)
    inout                   sda                         , // I2C 数据线
    output                  scl                         , // I2C 时钟线
    output                  convst                      , // 转换启动信号 (可能用于AD7680或其他ADC)
    input                   Alt_busy                    , // 转换忙碌指示信号

    // ==========================================
    // 6. AD9253 ADC 数据输入接口 (ADC Data Input)
    // ==========================================
    input                   I_D0A_Data_p                , // ADC 通道 A 数据 0 (正)
    input                   I_D0A_Data_n                , // ADC 通道 A 数据 0 (负)
    input                   I_D1A_Data_p                , // ADC 通道 A 数据 1 (正)
    input                   I_D1A_Data_n                , // ADC 通道 A 数据 1 (负)
    input                   I_D0B_Data_p                , // ADC 通道 B 数据 0 (正)
    input                   I_D0B_Data_n                , // ADC 通道 B 数据 0 (负)
    input                   I_D1B_Data_p                , // ADC 通道 B 数据 1 (正)
    input                   I_D1B_Data_n                , // ADC 通道 B 数据 1 (负)
    input                   I_D0C_Data_p                , // ADC 通道 C 数据 0 (正)
    input                   I_D0C_Data_n                , // ADC 通道 C 数据 0 (负)
    input                   I_D1C_Data_p                , // ADC 通道 C 数据 1 (正)
    input                   I_D1C_Data_n                , // ADC 通道 C 数据 1 (负)
    input                   I_D0D_Data_p                , // ADC 通道 D 数据 0 (正)
    input                   I_D0D_Data_n                , // ADC 通道 D 数据 0 (负)
    input                   I_D1D_Data_p                , // ADC 通道 D 数据 1 (正)
    input                   I_D1D_Data_n                , // ADC 通道 D 数据 1 (负)
    
    input           [1:0]   ad0dclk                     , // ADC 数据时钟 (DCO)
    input           [1:0]   ad0fclk                     , // ADC 帧时钟 (FCO)
    output                  O_adc0_clk_p                , // 提供给 ADC 的采样时钟 (正)
    output                  O_adc0_clk_n                , // 提供给 ADC 的采样时钟 (负)
    output                  adpdwn                      , // ADC 掉电控制

    // ADC SPI 控制接口
    inout                   ad9253_sdio1                , // SPI 数据
    output                  ad9253_sclk1                , // SPI 时钟
    output                  ad9253_csb1                 , // SPI 片选
    output                  ad9253_sync1                , // SPI 同步


    // ==========================================
    // 7. RS422 串口接口 (RS422 Communication)
    // ==========================================
    input                   rs422_rxd                   , // 接收端
    output                  rs422_txd                   , // 发送端
    output                  rs422_txden                 , // 发送使能 (用于控制RS422收发器)

    // ==========================================
    // 8. 测试点 (Test Points)
    // ==========================================
    output                  testpoint1                  , // 制冷控制等测试点 1
    output                  testpoint2                  , // 测试点 2
    output                  testpoint3                  , // 测试点 3
    output                  testpoint4                  , // 测试点 4
    output                  testpoint5                  , // 测试点 5
    output                  testpoint6                  , // 测试点 6

    // ==========================================
    // 9. PPS 时间同步信号 (Time Synchronization)
    // ==========================================
    input                   zk_pps                      , // 主控板 PPS 脉冲输入
    output                  pps_en                      , // PPS 使能输出

    // ==========================================
    // 10. Flash 存储器接口 (SPI Flash)
    // ==========================================
    //output flash_clk,
    output                  flash_cs                    , // Flash 片选
    inout                   flash1_D0                   , // Flash 数据线 0 (MOSI/MISO)
    inout                   flash1_D1                   , // Flash 数据线 1 (Dual IO)

    // ==========================================
    // 11. DDR3 存储器接口 (DDR3 Memory)
    // ==========================================
    inout           [15:0]  ddr3_dq                     , // DDR3 数据线
    inout           [1:0]   ddr3_dqs_n                  , // DDR3 数据选通 (负)
    inout           [1:0]   ddr3_dqs_p                  , // DDR3 数据选通 (正)
    output          [14:0]  ddr3_addr                   , // DDR3 地址线
    output          [2:0]   ddr3_ba                     , // DDR3 Bank 选择
    output                  ddr3_ras_n                  , // DDR3 行选通
    output                  ddr3_cas_n                  , // DDR3 列选通
    output                  ddr3_we_n                   , // DDR3 写使能
    output                  ddr3_reset_n                , // DDR3 复位信号
    output          [0:0]   ddr3_ck_p                   , // DDR3 时钟 (正)
    output          [0:0]   ddr3_ck_n                   , // DDR3 时钟 (负)
    output          [0:0]   ddr3_cke                    , // DDR3 时钟使能
    output          [0:0]   ddr3_cs_n                   , // DDR3 片选
    output          [1:0]   ddr3_dm                     , // DDR3 数据掩码
    output          [0:0]   ddr3_odt                      // DDR3 片上终端电阻使能
    );
    
// =========================================================================
// 内部信号定义与连线 (Internal Signals & Wires)
// =========================================================================

wire                [15:0]  ad0data_conn                = { I_D1D_Data_n, I_D1D_Data_p, 
                                                            I_D0D_Data_n, I_D0D_Data_p, 
                                                            I_D1C_Data_n, I_D1C_Data_p, 
                                                            I_D0C_Data_n, I_D0C_Data_p, 
                                                            I_D1B_Data_n, I_D1B_Data_p, 
                                                            I_D0B_Data_n, I_D0B_Data_p, 
                                                            I_D1A_Data_n, I_D1A_Data_p, 
                                                            I_D0A_Data_n, I_D0A_Data_p };


// 时钟与复位网络信号
wire                        CLK80M                      ; // 80MHz 系统主时钟
wire                        REFCLK                      ; // 200MHz DDR3参考时钟
wire                        clk_det                     ; // 探测器时钟
wire                        clk_adv                     ; // ADC驱动时钟
wire                        clk_100M                    ; // 100MHz 时钟
wire                        spi_clk                     ; // FLASH SPI 通信时钟
wire                        clkgtx                      ; // GTX 收发器用户时钟
wire                        rst_n                       ; // 全局异步复位 (低有效)

// 图像数据与控制相关信号
wire                        I_tx_done                   ; // 图像发送完成标志
wire                        O_sample_done               ; // 一行图像采样完成标志
wire                [63:0]  data_sample                 ; // 64位采样像素数据
wire                        cmd_update                  ; // 串口指令更新标志
wire                [7:0]   image_ctrl                  ; // 图像控制字
wire                [7:0]   gain_para                   ; // 增益参数
wire                [8:0]   CINT                        ;
wire                        sim_data_en                 ; // 模拟数据使能 (用于测试)
(*mark_debug = "true"*) wire data_en                    ; // 探测器帧有效信号
wire                [79:0]  sync_time                   ;
wire                [15:0]  frame_frequency             ; // 成像周期/帧频控制字
wire                [15:0]  zhenpin                     ; // 实际帧频
wire                [15:0]  integral_time               ; // 用户设置的积分时间
wire                        fpga_line_valid             ; // FPGA处理后的行有效信号
wire                [15:0]  real_integral               ; // 实际生效的积分时间

//assign frame_frequency = 100000/zhenpin;

// ADC 解析后的各通道数据
(*mark_debug = "true"*) wire [13:0] adc1_data_a         ;
(*mark_debug = "true"*) wire [13:0] adc1_data_b         ;
(*mark_debug = "true"*) wire [13:0] adc1_data_c         ;
(*mark_debug = "true"*) wire [13:0] adc1_data_d         ;

(*mark_debug = "true"*) wire fco                        ; // ADC 帧同步时钟
// wire                [31:0]  fre_num                     ;
// wire                [15:0]  line_num                    ;
wire                [7:0]   image_mode                  ; // 图像模式

// 温度传感器信号
wire                        O_temp_ctrl_rdy             ;
wire                        O_temp_pwr_rdy              ;
wire                        O_det_temp_rdy              ;
wire                [15:0]  O_temperature_CA            ; // 控制板温度
wire                [15:0]  O_temperature_IA            ; // 接口板/电源板温度
wire                [15:0]  O_temperature_DET           ; // 探测器温度
wire                [15:0]  o_rd_data                   ; // AD7998量化温度数据
wire                        o_rd_data_vaild             ; // AD7998量化温度数据有效信号
wire                        driver_en                   ; // 驱动使能

// 内存与校正处理 (NUC) 相关信号
wire                        fifo_ddr_done               ;
wire                [127:0] kb_data                     ; // 读回的 K/B 校正系数
wire                [9:0]   rram_read_addr1             ;
wire                [9:0]   rram_read_addr2             ;
wire                        read_ram_finish1            ;
wire                        read_ram_finish2            ;
wire                        rram_rclk                   ;
wire                        O_init_calib_complete       ; // DDR3 初始化完成标志

wire                        k_b_finish_O                ;
wire                        O_ddr_wr_finish             ;
wire                        O_rram_rq_read              ;
wire                        O_two_point_start           ;
wire                        O_fifo_sample_finish        ;

// LED 逻辑: DDR 初始化未完成时点亮
// assign                      led                         = ~O_init_calib_complete;

// 时间与工作模式相关信号
wire                        time_update_busy            ;
wire                [7:0]   I_second                    ;
wire                [15:0]  I_millisecond               ;
wire                        time_update                 ;
wire                [7:0]   year, month, date, hour, minute, second;
wire                [15:0]  millisecond                 ;
wire                [7:0]   system_hour, system_minute, system_second;
wire                [15:0]  system_millisecond          ;
wire                [7:0]   GongZuoMoShi                ; // 工作模式
wire                [7:0]   HeBingMoShi                 ; // 合并模式/两点校正模式
wire                        temp1_rdy                   ;
wire                [15:0]  temperature1                ;
wire                        pps_ready                   ; // PPS 同步就绪状态
wire                [7:0]   trigger                     ; // 触发工作模式（01 = 内触发 / 02 = 外触发）
wire                [535:0] mid_navigation_data         ; // 中空导航数据 
wire                [535:0] high_navigation_data        ; // 高空导航数据 
wire                [535:0] high_satellite_data         ; // 高空卫星数据
wire                        gtx_wr_en                   ;
wire                [63:0]  loc_time                    ;

wire                [7:0]   cmd_value_gm                ;
wire                [7:0]   cmd_value_hm                ;

// Aurora 发送侧逻辑接口
wire                        aurora_init                 ; //握手成功信号
wire                        axi_tx_tvalid               ; 
wire                [7:0]   axi_tx_tkeep                ;
wire                [63:0]  axi_tx_tdata                ; // 64/66B IP核发送的数据
wire                        axi_tx_tlast                ;
wire                        axi_tx_tready               ;
wire                        HTS_TDIS                    ; // 没用上
wire                [15:0]  read_row                    ; // 正在读取的行号

wire                [9:0]   last_line_addr              ; //上一行8个像素地址
wire                [9:0]   addr_rd1                    ; //左边行4个像素地址
wire                [9:0]   addr_rd2                    ; //发送行4个像素地址
wire                [9:0]   addr_rd3                    ; //右边行4个像素地址

// IOBUF内部信号 (flash1_D0/D1的bidirectional拆分)
wire                        flash_clk                   ;
wire                        flash1_D0_o                 ; // 输出到 Flash (MOSI)
wire                        flash1_D0_i                 ; // 从 Flash 输入 (MISO)
wire                        flash1_D1_o                 ; // 输出到 Flash (Dual Output)
wire                        flash1_D1_i                 ; // 从 Flash 输入 (Dual Input)
wire                        flash_io_sig                ; // 读模式=1(FPGA高阻接收),写模式=0(FPGA驱动发送) → 对应IOBUF的T端
wire                        spi_read_kb                 ; // spi_wr读MISO时=1 (IOBUF切换为输入) → 对应IOBUF的T端

// 测试模式使能：根据工作模式寄存器位解析
assign                      sim_data_en                 = (GongZuoMoShi[1] & (~GongZuoMoShi[0]));

// 测试点信号分配
assign                      testpoint1                  = fifo_ddr_done                         ;
assign                      testpoint2                  = I_CLK40M                              ;
assign                      testpoint3                  = k_b_finish_O                          ;
assign                      testpoint4                  = flash_clk                             ;
assign                      testpoint5                  = det_rst_b                             ;
assign                      testpoint6                  = O_fifo_sample_finish                  ;

// =========================================================================
// 模块例化 (Module Instantiations)
// =========================================================================

clk_wiz_0 U0_dcm
(
    // Clock out ports
    .clk_80MHz              (CLK80M                     ), // 80MHz 系统时钟
    .clk_det                (clk_det                    ), // 探测器时钟
    .clk_adc                (clk_adc                    ), // ADC 处理时钟
    .clk_100M               (clk_100M                   ), // 100MHz 辅助时钟
    .REFCLK                 (REFCLK                     ), // 200MHz DDR3 参考时钟
    .spi_clk                (spi_clk                    ), // SPI 操作时钟
    // Clock in ports
    .clk_in1                (I_CLK40M                   )  // 40MHz 输入
);

// 2. 全局复位模块
reset U1_reset (
    .I_clk                  (CLK80M                     ),
    .O_rst                  (rst_n                      )  // 产生稳定的异步复位信号
);

// 3. 探测器驱动模块 (Detector Driver)
det U_det (
    .I_clk                  (CLK80M                     ),
    .I_rst                  (rst_n                      ),
    .I_clk_drv              (clk_det                    ),
    .I_clk_delay            (clk_100M                   ),
    .I_trig                 (                           ),
    .I_dip_sts              (4'b1111                    ),
    .I_gain_num             (gain_para                  ), // 从串口解析的增益参数
    .I_int_num              (integral_time              ), // 从串口解析的积分时间
    .I_freframe_num         (frame_frequency            ), // 从串口解析的成像周期
    .I_driver_en            (driver_en                  ), // 从串口解析的开始成像指令
    .I_image_ctrl           (image_ctrl                 ),
    .I_fpga_det_valid       (fpga_det_valid             ), // 探测器输出的valid信号，没用上
    .I_fpga_det_error       (fpga_det_error             ), // 探测器输出的error信号，没用上
    .I_param_update         (cmd_update                 ),
    .I_GongZuoMoShi         (GongZuoMoShi               ), // 从串口解析的工作模式
    .I_HeBingMoShi          (HeBingMoShi                ), // 从串口解析的图像模式
    .pps_ready              (pps_ready                  ), // 从time_update模块解析的pps检测成功信号
    .trigger                (trigger                    ), // 内外触发
    .o_rd_data              (o_rd_data                  ), // AD7998温度数据
    
    .O_fpga_pwr_ctrl1       (fpga_pwr_ctrl1             ), // 上电顺序1
    .O_fpga_pwr_ctrl2       (fpga_pwr_ctrl2             ), // 上电顺序2
    .O_fpga_pwr_ctrl3       (fpga_pwr_ctrl3             ), // 上电顺序3
    
    .O_N_int                (real_integral              ), // 实际生效的积分值
    .O_fpga_det_reset       (det_rst_b                  ), // 给探测器的DATA复位信号
    .O_fpga_det_serial      (det_data                   ), // 给探测器的命令控制字
    .O_fpga_det_mclk        (fpga_det_mclk              ), // 给探测器的主时钟
    .O_fpga_det_int         (fpga_det_int               ), // 给探测器的积分时间信号
    .O_fpga_line_valid      (fpga_line_valid            ), // FPGA产生的行同步信号
    .O_fpga_det_error       (O_fpga_det_error           ), // 没用
    .O_frame_valid_syn      (data_en                    )  // 帧同步使能信号
);

// 4. ADC 采样模块 (AD9257/AD9253)
ad9253 U3_adc_sample1 (
    .clk_sys                (CLK80M                     ),
    .rst_n                  (rst_n                      ),
    .clk_ad                 (clk_adc                    ),
    .ad0dclk                (ad0dclk                    ),
    .ad0fclk                (ad0fclk                    ),
    .ad0data                (ad0data_conn               ), 
    .ad_clk_p               (O_adc0_clk_p               ),
    .ad_clk_n               (O_adc0_clk_n               ),
    .cha_data               (adc1_data_a                ), // 通道A解串数据
    .chb_data               (adc1_data_b                ), // 通道B解串数据
    .chc_data               (adc1_data_c                ), // 通道C解串数据
    .chd_data               (adc1_data_d                ), // 通道D解串数据
    .fco_0                  (fco                        ),
    
    // ADC SPI 配置总线
    .adsdio                 (ad9253_sdio1               ),
    .adsclk                 (ad9253_sclk1               ),
    .adcsb                  (ad9253_csb1                ),
    .adsync                 (ad9253_sync1               ),
    .adpdwn                 (adpdwn                     )
);


// 5. 图像数据预处理与缓冲 (Image Preprocessing)
image_sample U4_image_sample (
    .I_clk                  (CLK80M                     ), 
    .I_rst                  (rst_n                      ), 
    .I_cl_clk               (clkgtx                     ), // 读取时钟，与TX对齐
    .I_adc_clk              (clk_det                    ),
    .I_line_vaild           (fpga_line_valid            ), 
    .fifo_ddr_done          (fifo_ddr_done              ),
    .two_point_sig          (trigger                    ), // 两点校正模式指示

    // 此处接入了固定的测试图案数据
    // .I_dataA1               (16'd3681                   ),
    // .I_dataB1               (16'd9533                   ),
    // .I_dataC1               (16'd1210                   ),
    // .I_dataD1               (16'd13566                  ),

    // // 拼接后的图像数据
	.I_dataA1              ({2'b00,adc1_data_a}        ),//adc1_data_a
	.I_dataB1              ({2'b00,adc1_data_b}        ),//adc1_data_b 
	.I_dataC1              ({2'b00,adc1_data_c}        ),//adc1_data_c 
	.I_dataD1              ({2'b00,adc1_data_d}        ),//adc1_data_d
    
	.last_line_addr         (last_line_addr             ),
    .I_addr_rd1             (addr_rd1                   ),
    .I_addr_rd2             (addr_rd2                   ),
    .I_addr_rd3             (addr_rd3                   ),
    .I_read_row             (read_row                   ),

    .O_two_point_start      (O_two_point_start          ),
    .I_data_rd_finish       (I_tx_done                  ), 
    .fco                    (fco                        ),
    
    // 输出采样拼包后的数据给 Aurora 发送模块
    .O_sample_data          (data_sample                ), 
    .O_sample_finish        (O_sample_done              ),
    .kb_data                (kb_data                    ),
    .O_read_ram_addr1       (rram_read_addr1            ),
    .O_read_ram_addr2       (rram_read_addr2            ),
    .read_rram_finish1      (read_ram_finish1           ),
    .read_rram_finish2      (read_ram_finish2           ),
    .rram_rclk              (rram_rclk                  )
	);

// 6. Aurora 数据组帧与链路层 (Aurora TX Framing)
aurora_tx U5_aurora_tx (
    .I_clk                  (CLK80M                     ),         
    .I_rst_n                (rst_n                      ),
    .I_sim_data_en          (sim_data_en                ),
    .I_data_en              (fpga_line_valid            ),
    .I_sample_rdy           (O_sample_done              ),
    .I_sample_data          (data_sample                ),
    .I_driver_en            (driver_en                  ),

    // 拼接辅助数据 (如图像模式、积分时间、温度、系统时间等)
    .I_image_mode           ({cmd_value_gm, cmd_value_hm}),
    .I_integ_time           (real_integral              ),
    .I_frame_period         (zhenpin                    ),
    .I_gain                 ({8'd0, gain_para}          ),
    .I_fpa_temp             (O_temperature_CA           ),
    .I_temp_point1          (o_rd_data                  ),

    // // 真实数据
    .I_loc_time             (loc_time                   ),
    .I_mid_navigation_data  (mid_navigation_data        ),
    .I_high_navigation_data (high_navigation_data       ),
    .I_high_satellite_data  (high_satellite_data        ),

    // 固化测试时间及导航卫星数据
    // .I_year                 (8'd26                      ),
    // .I_month                (8'd6                       ),
    // .I_date                 (8'd24                      ),
    // .I_hour                 (8'd15                      ),
    // .I_minute               (8'd40                      ),
    // .I_second               (8'd55                      ),
    // .I_millisecond          (16'd200                    ),
    // .I_mid_navigation_data  (536'd564313                ),
    // .I_high_navigation_data (536'd769252                ),
    // .I_high_satellite_data  (536'd423468                ),

    .O_gtx_wr_en            (gtx_wr_en                  ),
    .last_line_addr         (last_line_addr             ),
    .O_addr_rd1             (addr_rd1                   ),
    .O_addr_rd2             (addr_rd2                   ),
    .O_addr_rd3             (addr_rd3                   ),
    .O_read_row             (read_row                   ),
    
    .O_rd_finish            (I_tx_done                  ),
    .O_HTS_TDIS             (HTS_TDIS                   ),
    
    // AXI4-Stream 接口连接到 Aurora 物理层
    .aurora_init            (aurora_init                ),
    .axis_clk               (clkgtx                     ),
    .axis_tvalid            (axi_tx_tvalid              ),
    .axis_tdata             (axi_tx_tdata               ),
    .axis_tkeep             (axi_tx_tkeep               ),
    .axis_tlast             (axi_tx_tlast               ),
    .axis_tready            (axi_tx_tready              )
);

// 7. Aurora 64B/66B 物理层 (GTX Transceiver)
aurora_64b66b U6_aurora_64b66b (
    .gt_refclk_p            (Q0_CLK1_GTREFCLK_PAD_P_IN  ),
    .gt_refclk_n            (Q0_CLK1_GTREFCLK_PAD_N_IN  ),
    // .gt_rxp                 (                           ),
    // .gt_rxn                 (                           ),
    .gt_txp                 (TXP_OUT                    ),
    .gt_txn                 (TXN_OUT                    ),
    .init_clk               (clk_100M                   ),
    .drp_clk                (clk_100M                   ),
    .user_clk               (clkgtx                     ), // 提供给上一层的用户时钟
    .rst_n                  (rst_n                      ),

    .aurora_init            (aurora_init                ),
    .s_axi_tx_tvalid        (axi_tx_tvalid              ),
    .s_axi_tx_tkeep         (axi_tx_tkeep               ),
    .s_axi_tx_tdata         (axi_tx_tdata               ),
    .s_axi_tx_tlast         (axi_tx_tlast               ),
    .s_axi_tx_tready        (axi_tx_tready              )
//    .m_axi_rx_tvalid(),
//    .m_axi_rx_tdata (),
//    .m_axi_rx_tkeep (),
//    .m_axi_rx_tlast ()
);

// =========================================================================
// RS422 TX方向仲裁线: update_active=0时由new_rs422驱动,=1时由kb_update_top驱动
// =========================================================================
wire                        rs422_tx_from_ctrl          ; // 来自普通控制模块的 TX
wire                        rs422_txen_from_ctrl        ; // 来自普通控制模块的 TX 使能
wire                        rs422_tx_from_kb            ; // 来自系数更新模块 (DDR/Flash) 的 TX
wire                        rs422_txen_from_kb          ; // 来自系数更新模块的 TX 使能
(* mark_debug = "true" *) wire update_active_kb         ; // 指示 DDR/Flash 正在进行参数更新

// 当需要通过串口更新 Flash/DDR 盲元/校正参数时，接管物理串口引脚
assign                      rs422_txd                   = update_active_kb ? rs422_tx_from_kb   : rs422_tx_from_ctrl;
assign                      rs422_txden                 = update_active_kb ? rs422_txen_from_kb : rs422_txen_from_ctrl;

// 8. RS422 协议解析与控制模块 (RS422 Parser)
zk_rs422 U7_rs422 (
    .I_clk                  (CLK80M                     ), 
    .I_rst                  (rst_n                      ), 
    .clkgtx                 (clkgtx                     ),
    .O_tx                   (rs422_tx_from_ctrl         ),
    .I_rx                   (rs422_rxd                  ),
    .O_tx_en                (rs422_txen_from_ctrl       ),
    .O_cmd_update           (cmd_update                 ),
    .O_ChengXiangZhouQi     (frame_frequency            ),
    .O_ChengXiangZhenpin    (zhenpin                    ),
    .O_JiFenShiJian         (integral_time              ),
    .O_ChengXiangZengYi     (gain_para                  ),
    .O_driver_en            (driver_en                  ),
    .O_image_ctrl           (image_ctrl                 ),

    .I_time_update_busy     (time_update_busy           ),
    .I_second               (I_second                   ),
    .I_millisecond          (I_millisecond              ),
    .I_gtx_wr_en            (gtx_wr_en                  ),

    // 解析下发的系统状态参数
    .O_time_update          (time_update                ),
    .O_year                 (year                       ),
    .O_month                (month                      ),
    .O_date                 (date                       ),
    .O_hour                 (hour                       ),
    .O_minute               (minute                     ),
    .O_second               (second                     ),
    .O_millisecond          (millisecond                ),
    .O_GongZuoMoShi         (GongZuoMoShi               ),
    .O_HeBingMoShi          (HeBingMoShi                ),
    .O_cmd_value_gm         (cmd_value_gm               ),
    .O_cmd_value_hm         (cmd_value_hm               ),
    .BeiYong                (trigger                    ),
    .O_mid_navigation_data  (mid_navigation_data        ),
    .O_high_navigation_data (high_navigation_data       ),
    .O_high_satellite_data  (high_satellite_data        ),
    .O_temp_laser_data      (temp_laser_data            ),

    .I_temp1_rdy            (temp1_rdy                  ),
    .I_temperature1         (temperature1               )
);


// 9. 温度采集模块 (DS18B20 & I2C)
temp_sample U8 (
    .I_clk                  (CLK80M                     ),
    .clk_100M               (clk_100M                   ),
    .I_rst                  (rst_n                      ),
    .IO_ds18b20_1_dq        (IO_ds18b20_ctrl_dq         ),
    // .IO_ds18b20_2_dq        (IO_ds18b20_pwr_dq          ), // 注: 顶层端口中该信号已被注释掉，需注意
    .O_temp1_rdy            (O_temp_ctrl_rdy            ),
    .O_temp2_rdy            (O_temp_pwr_rdy             ),
    .O_temperature1         (O_temperature_CA           ),
    .O_temperature2         (O_temperature_IA           ),

    .sda                    (sda                        ),
    .scl                    (scl                        ),
    .convst                 (convst                     ),
    .Alt_busy               (Alt_busy                   ),
    .o_rd_data              (o_rd_data                  ),
    .o_rd_data_vaild        (o_rd_data_vaild            )
);

assign                      pps_en                      = 1'b1; // 始终使能 PPS 接收

// 10. 系统时间更新模块 (Time/RTC Sync)
time_update U_time_update (
    .I_clk                  (CLK80M                     ),
    .I_rst                  (rst_n                      ),
    .I_zk_pps               (zk_pps                     ), // 秒脉冲
    .I_ctrl2time_datardy    (time_update                ),
    .I_zk_TIME              ({year,month,date,hour,minute,second,millisecond}),

    .O_loc_TIME             (loc_time                   ),
    .O_pps_ready            (pps_ready                  ),
    .O_TIME_update_busy     (time_update_busy           )
);

// 11. 非均匀性校正与存储控制模块 (DDR3 NUC / Blind Pixel Replacement)
ddr3_top U_nonuniformity_correction (
    .I_clk                  (CLK80M                     ),
    .I_rst                  (rst_n                      ),
    .clk_200MHz             (REFCLK                     ),

    // 拆分后的 Flash 接口控制
    .flash_clk              (flash_clk                  ),
    .flash_cs               (flash_cs                   ),
    .D0_o                   (flash1_D0_o                ), // D0 输出 -> IOBUF
    .D0_i                   (flash1_D0_i                ), // D0 输入 <- IOBUF
    .D1_o                   (flash1_D1_o                ), // D1 输出 -> IOBUF
    .D1_i                   (flash1_D1_i                ), // D1 输入 <- IOBUF

    // DDR3 物理引脚
    .ddr3_addr              (ddr3_addr                  ),
    .ddr3_ba                (ddr3_ba                    ),
    .ddr3_cas_n             (ddr3_cas_n                 ),
    .ddr3_ck_n              (ddr3_ck_n                  ),
    .ddr3_ck_p              (ddr3_ck_p                  ),
    .ddr3_cke               (ddr3_cke                   ),
    .ddr3_ras_n             (ddr3_ras_n                 ),
    .ddr3_reset_n           (ddr3_reset_n               ),
    .ddr3_we_n              (ddr3_we_n                  ),
    .ddr3_dq                (ddr3_dq                    ),
    .ddr3_dqs_n             (ddr3_dqs_n                 ),
    .ddr3_dqs_p             (ddr3_dqs_p                 ),
    .ddr3_cs_n              (ddr3_cs_n                  ),
    .ddr3_dm                (ddr3_dm                    ),
    .ddr3_odt               (ddr3_odt                   ),  

    .O_init_calib_complete  (O_init_calib_complete      ),
    .O_ddr_wr_finish        (O_ddr_wr_finish            ),
    .O_rram_rq_read         (O_rram_rq_read             ),
    .O_fifo_sample_finish   (O_fifo_sample_finish       ),
    
    // 校正系数存取逻辑
    .fifo_ddr_done          (fifo_ddr_done              ),
    .o_kb_data              (kb_data                    ),
    .rram_read_addr1        (rram_read_addr1            ),
    .rram_read_addr2        (rram_read_addr2            ),
    .read_ram_finish1       (read_ram_finish1           ),
    .read_ram_finish2       (read_ram_finish2           ),
    .rram_rclk              (rram_rclk                  ),
    .flash_spi_clk          (spi_clk                    ),
    .k_b_finish_O           (k_b_finish_O               ),

    // RS422 系数更新接口
    .I_rs422_rx             (rs422_rxd                  ),
    .O_rs422_tx             (rs422_tx_from_kb           ),
    .O_rs422_tx_en          (rs422_txen_from_kb         ),
    .O_update_active        (update_active_kb           ),
    
    // Flash IOBUF 方向控制
    .flash_io_sig           (flash_io_sig               ), // 读模式=1(FPGA高阻), 写模式=0
    .O_spi_read             (spi_read_kb                )  // spi_wr读MISO时置1，使IOBUF切为输入
);

// vio_0 your_instance_name (
//   .clk(clk),                // input wire clk
//   .probe_in0(probe_in0),    // input wire [0 : 0] probe_in0
//   .probe_out0(probe_out0)  // output wire [0 : 0] probe_out0
// );

// ============================================================================
// IOBUF: Flash D0/D1 的 bidirectional 信号拆分
// IOBUF.T 低有效: T=0→输出使能(FPGA驱动), T=1→高阻(Flash驱动/FPGA接收)
// T逻辑:
//   正常读取模式(update_active=0): T = flash_io_sig  (io_sig=1时高阻接收)
//   参数更新模式(update_active=1): T = spi_read_kb   (read_wait时高阻接收MISO)
// ============================================================================
wire                        flash_iobuf_T               ;
assign                      flash_iobuf_T               = update_active_kb ? spi_read_kb : flash_io_sig;

// 例化 D0 的原语 (MOSI / MISO 共用)
IOBUF #(
    .IBUF_LOW_PWR           ("TRUE"                     ),
    .IOSTANDARD             ("DEFAULT"                  )
) IOBUF_flash_D0 (
    .O                      (flash1_D0_i                ), // FPGA 内部接收 (MISO)
    .IO                     (flash1_D0                  ), // 连接到物理 Pin
    .I                      (flash1_D0_o                ), // FPGA 内部发送 (MOSI)
    .T                      (flash_iobuf_T              )  // T=0 发送; T=1 接收
);

// 例化 D1 的原语 (Dual IO)
IOBUF #(
    .IBUF_LOW_PWR           ("TRUE"                     ),
    .IOSTANDARD             ("DEFAULT"                  )
) IOBUF_flash_D1 (
    .O                      (flash1_D1_i                ), // FPGA 内部接收 (MISO)  
    .IO                     (flash1_D1                  ), // 连接到物理 Pin    
    .I                      (flash1_D1_o                ), // FPGA 内部发送 (MOSI)  
    .T                      (flash_iobuf_T              )  // T=0 发送; T=1 接收
);

endmodule

