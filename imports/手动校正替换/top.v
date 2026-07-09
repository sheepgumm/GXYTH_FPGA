`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/03/17 15:52:12
// Design Name: 
// Module Name: top
// Project Name: 
// Target Devices: swir 2560*2048
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
    input I_CLK40M,
    
    //det signal 
    //output fpga_fsync,
    //output fpga_lsync,
    output det_rst_b,
    output det_data,
    output fpga_det_mclk,
    output fpga_det_int,
    input fpga_det_valid,
    input fpga_det_error,
    
    //det pwr
    output fpga_pwr_ctrl1,
    output fpga_pwr_ctrl2,
    output fpga_pwr_ctrl3,
    //output fpga_pwr_ctrl4,
    //output fpga_pwr_ctrl5,
   // output fpga_pwr_ctrl6,
    // output det_245_oe,


    //led
    output  led,

     //gtx
    input Q0_CLK1_GTREFCLK_PAD_P_IN,
    input Q0_CLK1_GTREFCLK_PAD_N_IN,


    output  TXP_OUT,
    output  TXN_OUT,
    //output  TXP_OUT1,
    //output  TXN_OUT1,

    //output	cdcm_ce, 
	//output	cdcm_rst, 
	//input	hts8502_los, 
	//output	hts8502_tdis, 
     //ds18b20
    inout IO_ds18b20_ctrl_dq,
    // inout IO_ds18b20_pwr_dq,
    //ad7680
    //output det_temp_cs,
    //output det_temp_sclk,
    //input det_temp_sdata,
    inout sda,
    output scl,
    output convst,
    input Alt_busy,

    //ad9257 input
    input I_D0A_Data_p,
    input I_D0A_Data_n,
    input I_D1A_Data_p,
    input I_D1A_Data_n,
    input I_D0B_Data_p,
    input I_D0B_Data_n,
    input I_D1B_Data_p,
    input I_D1B_Data_n,
    input I_D0C_Data_p,
    input I_D0C_Data_n,
    input I_D1C_Data_p,
    input I_D1C_Data_n,
    input I_D0D_Data_p,
    input I_D0D_Data_n,
    input I_D1D_Data_p,
    input I_D1D_Data_n,
    input [1:0] ad0dclk,
    input [1:0] ad0fclk,
    

    //ad9257 output 
    output O_adc0_clk_p,
    output O_adc0_clk_n,
    output adpdwn,

    ////ad9257 spi
    inout ad9253_sdio1,
    output ad9253_sclk1,
    output ad9253_csb1,
    output ad9253_sync1,


    //rs422
    input	rs422_rxd,
    output	rs422_txd,
    output	rs422_txden,
    //testpoint
    output testpoint1,//cool ctrl
    output testpoint2,
    output testpoint3,
    output testpoint4,
    output testpoint5,
    output testpoint6,
    // output testpoint7,
    // output testpoint8,
    // output testpoint9,
    // output testpoint10,
    // output testpoint11,
    // output testpoint12

    //flash
    //output flash_clk,
    output flash_cs,
    inout flash1_D0,
    inout  flash1_D1,

    // DDR3 IO接口 
    inout   [15:0]     ddr3_dq          ,   //ddr3 数据
    inout   [1:0]      ddr3_dqs_n       ,   //ddr3 dqs�??
    inout   [1:0]      ddr3_dqs_p       ,   //ddr3 dqs�??  
    output  [14:0]     ddr3_addr        ,   //ddr3 地址   
    output  [2:0]      ddr3_ba          ,   //ddr3 banck 选择
    output             ddr3_ras_n       ,   //ddr3 行�?�择
    output             ddr3_cas_n       ,   //ddr3 列�?�择
    output             ddr3_we_n        ,   //ddr3 读写选择
    output             ddr3_reset_n     ,   //ddr3 复位
    output  [0:0]      ddr3_ck_p        ,   //ddr3 时钟�??
    output  [0:0]      ddr3_ck_n        ,   //ddr3 时钟�??
    output  [0:0]      ddr3_cke         ,   //ddr3 时钟使能
    output  [0:0]      ddr3_cs_n        ,   //ddr3 片�??
    output  [1:0]      ddr3_dm          ,   //ddr3_dm
    output  [0:0]      ddr3_odt            //ddr3_odt 
    );
    
    wire [15:0] ad0data_conn = {I_D1D_Data_n, I_D1D_Data_p, 
                                I_D0D_Data_n, I_D0D_Data_p, 
                                I_D1C_Data_n, I_D1C_Data_p, 
                                I_D0C_Data_n, I_D0C_Data_p, 
                                I_D1B_Data_n, I_D1B_Data_p, 
                                I_D0B_Data_n, I_D0B_Data_p, 
                                I_D1A_Data_n, I_D1A_Data_p, 
                                I_D0A_Data_n, I_D0A_Data_p };
     // �?? [15:14]
     // �?? [13:12]
     // �?? [11:10]
     // �?? [9:8]
     // �?? [7:6]
     // �?? [5:4]
     // �?? [3:2]
    // �?? [1:0]
//assign fpga_pwr_ctrl3 = fpga_pwr_ctrl4;
//assign fpga_pwr_ctrl3 = fpga_pwr_ctrl5;
//assign fpga_pwr_ctrl3 = fpga_pwr_ctrl6;

wire CLK80M;
wire REFCLK;
wire clk_det;
wire clk_adv;
wire clk_100M;
wire spi_clk;
wire clkgtx;
wire rst_n;
wire data_rst;
wire int_en;
wire [10:0] I_addrb;
wire I_tx_done;
wire O_sample_done;
wire [63:0] data_sample;
wire cmd_update;
wire [7:0] image_ctrl;
wire [7:0] gain_para;
wire [8:0] CINT;
wire sim_data_en;
(*mark_debug = "true"*) wire data_en;
wire [79:0] sync_time;
wire [15:0] frame_frequency;
wire [15:0] integral_time;
wire fpga_line_valid;
wire fuzhuhang;

(*mark_debug = "true"*) wire [13:0] adc1_data_a;
(*mark_debug = "true"*) wire [13:0] adc1_data_b;
(*mark_debug = "true"*) wire [13:0] adc1_data_c;
(*mark_debug = "true"*) wire [13:0] adc1_data_d;
// wire [15:0] adc1_data_e;
// wire [15:0] adc1_data_f;
// wire [15:0] adc1_data_g;
// wire [15:0] adc1_data_h;
// wire [15:0] adc2_data_a;
// wire [15:0] adc2_data_b;
// wire [15:0] adc2_data_c;
// wire [15:0] adc2_data_d;
// wire [15:0] adc2_data_e;
// wire [15:0] adc2_data_f;
// wire [15:0] adc2_data_g;
// wire [15:0] adc2_data_h;

(*mark_debug = "true"*) wire fco;
wire [31:0]fre_num;
wire [15:0]line_num;
wire [7:0] image_mode;
wire [543:0] gtx_mc_data;
wire [151:0] gtx_cam_data;
wire [63:0] rx_time;
wire O_temp_ctrl_rdy;
wire O_temp_pwr_rdy;
wire O_det_temp_rdy;
wire [15:0] O_temperature_CA;
wire [15:0] O_temperature_IA;
wire [15:0] O_temperature_DET;
wire [15:0] o_rd_data;
wire o_rd_data_vaild;
wire driver_en;

wire fifo_ddr_done;
wire [127:0] kb_data;
wire [9:0] rram_read_addr1;
wire [9:0] rram_read_addr2;
wire read_ram_finish1;
wire read_ram_finish2;
wire rram_rclk;
wire O_init_calib_complete;

wire k_b_finish_O;
wire O_ddr_wr_finish;
wire O_rram_rq_read;
wire O_two_point_start;
wire O_fifo_sample_finish;

assign led = !O_init_calib_complete;

wire            time_update_busy;
wire [7:0]      I_second;
wire [15:0]     I_millisecond;
wire            time_update;
wire [7:0]      year;
wire [7:0]      month;
wire [7:0]      date;
wire [7:0]      hour;
wire [7:0]      minute;
wire [7:0]      second;
wire [7:0]      millisecond;
wire [7:0]      moshi;
wire            temp1_rdy;
wire [15:0]     temperature1;
wire [7:0]      BeiYong;

wire [7:0]      cmd_value_gm;
wire [7:0]      cmd_value_hm;

wire            aurora_init;
wire            axi_tx_tvalid;
wire [7:0]      axi_tx_tkeep;
wire [63:0]     axi_tx_tdata;
wire            axi_tx_tlast;
wire            axi_tx_tready;
wire            HTS_TDIS;
wire [15:0]     read_row;

wire [9:0] last_line_addr;
wire [9:0] addr_rd1;
wire [9:0] addr_rd2;
wire [9:0] addr_rd3;

wire flash_clk;
// IOBUF内部信号 (flash1_D0/D1的bidirectional拆分)
wire flash1_D0_o;   // 输出到Flash (MOSI)
wire flash1_D0_i;   // 从Flash输入 (MISO)
wire flash1_D1_o;   // 输出到Flash (Dual Output)
wire flash1_D1_i;   // 从Flash输入 (Dual Input)
wire flash_io_sig;  // 读模式=1(FPGA高阻),写模式=0(FPGA驱动) → IOBUF T
wire spi_read_kb;   // spi_wr读MISO=1时(IOBUF应切为输入) → IOBUF T

//assign TXN_OUT1 = TXN_OUT;
//assign TXP_OUT1 = TXP_OUT;

assign sim_data_en = (cmd_value_gm[1] & (~cmd_value_gm[0]));
//testpoint

assign testpoint1 = fifo_ddr_done;
assign testpoint2 = I_CLK40M;
assign testpoint3 = k_b_finish_O;
assign testpoint4 = flash_clk;
assign testpoint5 = det_rst_b;
assign testpoint6 = O_fifo_sample_finish;
// assign testpoint7 = fpga_det_mclk;
//assign testpoint8 = 
//assign testpoint9 = 




clk_wiz_0 U0_dcm
(
    // Clock out ports
    .clk_80MHz(CLK80M),     // output clk_80MHz
    .clk_det(clk_det),     // output clk_det
    .clk_adc(clk_adc),     // output clk_adc
    .clk_100M(clk_100M),
    .REFCLK(REFCLK),
    .spi_clk(spi_clk),
    // Clock in ports
    .clk_in1(I_CLK40M));      // input clk_in1
reset U1_reset(
    .I_clk(CLK80M),
    .O_rst(rst_n)
);


det U_det(
	.I_clk 				(CLK80M),//
	.I_rst			    (rst_n),//
	.I_clk_drv 			(clk_det),//
    .I_clk_delay        (clk_100M),
    .I_trig             (),
	.I_dip_sts			(4'b1111),//
	//.I_cmd_update 		(cmd_update),//???
	.I_gain_num 		(gain_para),//
	.I_int_num 			(integral_time),//
	.I_freframe_num 	(frame_frequency),//
	.I_driver_en 		(driver_en),//
	.I_image_ctrl		(image_ctrl),//????赋�?�不�??
    .I_fpga_det_valid   (fpga_det_valid),//fpga_det_valid
    .I_fpga_det_error   (fpga_det_error),//
    .I_param_update     (cmd_update),
	
	
	.O_fpga_pwr_ctrl1		(fpga_pwr_ctrl1),//
	.O_fpga_pwr_ctrl2		(fpga_pwr_ctrl2),//
	.O_fpga_pwr_ctrl3		(fpga_pwr_ctrl3),//
	
	
	.O_fpga_det_reset	(det_rst_b),//
	.O_fpga_det_serial	(det_data),//传输控制字DATA的管�??
	.O_fpga_det_mclk 		(fpga_det_mclk),//
    .O_fpga_det_int     (fpga_det_int),//
    .O_fpga_line_valid  (fpga_line_valid),//fpga_line_valid
    .O_fpga_det_error   (O_fpga_det_error),
    
	.O_frame_valid_syn	(data_en)//
    //.O_fuzhuhang        (fuzhuhang)
    //.O_line_num         (line_num),//15�??8?
	//.O_frame_num		(fre_num)//
	);


ad9253 U3_adc_sample1(

    //input
	.clk_sys(CLK80M),
	.rst_n(rst_n),
	.clk_ad(clk_adc),//MHZ
    .ad0dclk(ad0dclk),
    .ad0fclk(ad0fclk),
    .ad0data(ad0data_conn), 

    //output
    .ad_clk_p(O_adc0_clk_p),
	.ad_clk_n(O_adc0_clk_n),
    
    .cha_data(adc1_data_a),
    .chb_data(adc1_data_b),
    .chc_data(adc1_data_c),
    .chd_data(adc1_data_d),
	.fco_0(fco),//out fco
    //ad9257 spi
    .adsdio(ad9253_sdio1),
    .adsclk(ad9253_sclk1),
    .adcsb (ad9253_csb1),
    .adsync(ad9253_sync1),
    .adpdwn(adpdwn)
);



image_sample U4_image_sample(
	.I_clk(CLK80M), //100M
	.I_rst(rst_n), 
	.I_cl_clk(clkgtx), //cam read clk 66M
	.I_adc_clk(clk_det),//just sim st signal
	.I_line_vaild(fpga_line_valid), //fpga_det_valid

    .fifo_ddr_done(fifo_ddr_done),
    .two_point_sig(moshi),

    // .I_dataA1(16'h2710),
    // .I_dataB1(16'h2710),
    // .I_dataC1(16'h2710),
    // .I_dataD1(16'h2710),

	.I_dataA1({2'b00,adc1_data_a}),//adc1_data_a 16'h1111
	.I_dataB1({2'b00,adc1_data_b}),//adc1_data_b 
	.I_dataC1({2'b00,adc1_data_c}),//adc1_data_c 
	.I_dataD1({2'b00,adc1_data_d}),//adc1_data_d

    
	//.I_addr_rd(I_addrb), 
    .last_line_addr(last_line_addr),
    .I_addr_rd1(addr_rd1),
    .I_addr_rd2(addr_rd2),
    .I_addr_rd3(addr_rd3),
    .I_read_row(read_row),

    .O_two_point_start(O_two_point_start),

	.I_data_rd_finish(I_tx_done), 
	.fco(fco), //input fco
    //output
	.O_sample_data(data_sample), 
	.O_sample_finish(O_sample_done),
    .kb_data(kb_data),
	.O_read_ram_addr1(rram_read_addr1),
	.O_read_ram_addr2(rram_read_addr2),
	.read_rram_finish1(read_ram_finish1),
	.read_rram_finish2(read_ram_finish2),
	.rram_rclk(rram_rclk)
	);

aurora_tx U5_aurora_tx(
    .I_clk(CLK80M),         
    .I_rst_n(rst_n),
    .I_sim_data_en(sim_data_en),
    .I_data_en(fpga_line_valid),
    .I_sample_rdy(O_sample_done),
    .I_sample_data(data_sample),

    //辅助数据
    .I_image_mode({cmd_value_gm,cmd_value_hm}),
    .I_integ_time(integral_time),
    .I_frame_period(frame_frequency),
    .I_gain(gain_para),
    .I_fpa_temp(O_temperature_CA),
    .I_temp_point1(o_rd_data),

    .last_line_addr(last_line_addr),
    .O_addr_rd1(addr_rd1),
    .O_addr_rd2(addr_rd2),
    .O_addr_rd3(addr_rd3),
    .O_read_row(read_row),
    
    //.O_addr_rd(I_addrb),     
    .O_rd_finish(I_tx_done),
    .O_HTS_TDIS(HTS_TDIS),
    .aurora_init(aurora_init),
    .axis_clk(clkgtx),
    .axis_tvalid(axi_tx_tvalid),
    .axis_tdata(axi_tx_tdata),
    .axis_tkeep(axi_tx_tkeep),
    .axis_tlast(axi_tx_tlast),
    .axis_tready(axi_tx_tready)
);

aurora_64b66b U6_aurora_64b66b(
    .gt_refclk_p(Q0_CLK1_GTREFCLK_PAD_P_IN),
    .gt_refclk_n(Q0_CLK1_GTREFCLK_PAD_N_IN),
//    .gt_rxp(),
//    .gt_rxn(),

    .gt_txp(TXP_OUT),
    .gt_txn(TXN_OUT),
    .init_clk(clk_100M),
    .drp_clk(clk_100M),
    .user_clk(clkgtx),
    .rst_n(rst_n),

    .aurora_init    (aurora_init),
    .s_axi_tx_tvalid(axi_tx_tvalid),
    .s_axi_tx_tkeep (axi_tx_tkeep),
    .s_axi_tx_tdata (axi_tx_tdata),
    .s_axi_tx_tlast (axi_tx_tlast),
    .s_axi_tx_tready(axi_tx_tready)
//    .m_axi_rx_tvalid(),
//    .m_axi_rx_tdata (),
//    .m_axi_rx_tkeep (),
//    .m_axi_rx_tlast ()
);

// gtx_tx U5_gtx_tx(
//     .Q0_CLK1_GTREFCLK_PAD_N_IN(Q0_CLK1_GTREFCLK_PAD_N_IN),
//     .Q0_CLK1_GTREFCLK_PAD_P_IN(Q0_CLK1_GTREFCLK_PAD_P_IN),
//     .DRPCLK_IN(CLK80M),
//     .rst_n(rst_n),
//     .I_sim_data_en(sim_data_en),
//     .I_sample_done(O_sample_done),//1'b1
//     .I_LSYNC(fpga_det_int), //利用积分上升沿开始一帧图像的辅助�??
//     //.I_frame_vaild(data_en), 
//     .I_sample_data(data_sample),
//     //.I_image_start(work_mode[7]),
//     .clk_gtx_tx(clkgtx),
//     .O_tx_done(I_tx_done),
//     .O_addr(I_addrb),
//     .TXN_OUT(TXN_OUT),
//     .TXP_OUT(TXP_OUT),

//     .I_gtx_mc_data(544'h0),//  544'h0
//     .I_cam_time(sync_time)// 80'h0
//     //.I_integral_time    (integral_time  ),
//     //.I_gain_para        (gain_para      ),
//     //.I_frame_frequency  (frame_frequency),
//     //.I_tjdj_wz          (tjdj_wz        ),
//     //.I_cool_menxian     (cool_menxian   ),
//     //.I_work_mode        (work_mode      ),
//     //.I_image_mode       (image_mode     ),
//     //.I_temperature_CA     (O_temperature_CA),//temperature_CA 
//     //.I_temperature_IA     (O_temperature_IA ),//temperature_IA
//     //.I_temperature_PA     (16'hFFFF ),//temperature_PA
//     //.I_temperature_DET    (O_temperature_DET), //temperature_DET

//     //.I_det_linenum          (line_num)
//     //.I_clk(CLK80M), 
//     //.O_cdcm_ce			(cdcm_ce), 
//     //.O_cdcm_rst			(cdcm_rst), 
//     //.I_hts8502_los		(hts8502_los), 
//     //.O_hts8502_tdis		(hts8502_tdis)
// );

// RS422 TX方向仲裁线: update_active=0时由new_rs422驱动,=1时由kb_update_top驱动
wire rs422_tx_from_ctrl;    // new_rs422 的TX
wire rs422_txen_from_ctrl;  // new_rs422 的TX使能
wire rs422_tx_from_kb;      // kb_update_top 的TX (来自ddr3_top)
wire rs422_txen_from_kb;    // kb_update_top 的TX使能 (来自ddr3_top)
(* mark_debug = "true" *) wire update_active_kb;       // kb_update_top 参数更新进行中

zk_rs422 U7_rs422(
	.I_clk(CLK80M), 
	.I_rst(rst_n), 
	.O_tx(rs422_tx_from_ctrl),
	.I_rx(rs422_rxd),
	.O_tx_en(rs422_txen_from_ctrl),
	.O_cmd_update(cmd_update),
	.O_ChengXiangZhouQi(frame_frequency),//成像周期
	.O_JiFenShiJian(integral_time),//积分时间
	.O_ChengXiangZengYi(gain_para),
    .O_driver_en(driver_en),
	.O_image_ctrl(image_ctrl),

    .I_time_update_busy(time_update_busy),
    .I_second(I_second),
    .I_millisecond(I_millisecond),

    .O_time_update(time_update),
    .O_year(year),
    .O_month(month),
    .O_date(date),
    .O_hour(hour),
    .O_minute(minute),
    .O_second(second),
    .O_millisecond(millisecond),
    .O_moshi(moshi),
    .O_cmd_value_gm(cmd_value_gm),
    .O_cmd_value_hm(cmd_value_hm),
//    .BeiYong(BeiYong),

    .I_temp1_rdy(temp1_rdy),
    .I_temperature1(temperature1)
	);

    // RS422物理引脚TX方向仲裁: 参数更新时(update_active=1)切换到kb_update_top
assign rs422_txd   = update_active_kb ? rs422_tx_from_kb   : rs422_tx_from_ctrl;
assign rs422_txden = update_active_kb ? rs422_txen_from_kb : rs422_txen_from_ctrl;

temp_sample U8(
    .I_clk(CLK80M),
    .I_rst(rst_n),
    .IO_ds18b20_1_dq(IO_ds18b20_ctrl_dq),
    .IO_ds18b20_2_dq(IO_ds18b20_pwr_dq),
    .O_temp1_rdy(O_temp_ctrl_rdy),
    .O_temp2_rdy(O_temp_pwr_rdy),
    .O_temperature1(O_temperature_CA),
    .O_temperature2(O_temperature_IA),

    .sda(sda),
    .scl(scl),
    .convst(convst),
    .Alt_busy(Alt_busy),
    .o_rd_data(o_rd_data),
    .o_rd_data_vaild(o_rd_data_vaild)
);

time_update U_time_update(
    .I_clk(CLK80M),
    .I_rst(rst_n),
    .I_time_update(time_update),
    .I_second(),
    .I_second_pulse(),
    .clkgtx(clkgtx),
    .O_timecode(sync_time)
);

//非均�??校正模块
ddr3_top U_nonuniformity_correction(
    //顶层模块的输入输出接�??
    .I_clk(CLK80M),
	.I_rst(rst_n),
	.clk_200MHz(REFCLK),

    //flash1
	.flash_clk(flash_clk),
    .flash_cs(flash_cs),
    .D0_o(flash1_D0_o),   // D0输出 → IOBUF
    .D0_i(flash1_D0_i),   // D0输入 ← IOBUF
    .D1_o(flash1_D1_o),   // D1输出 → IOBUF
    .D1_i(flash1_D1_i),   // D1输入 ← IOBUF

    // DDR3 IO接口 
    .ddr3_addr                      (ddr3_addr),  // output [13:0]		ddr3_addr
    .ddr3_ba                        (ddr3_ba),  // output [2:0]		ddr3_ba
    .ddr3_cas_n                     (ddr3_cas_n),  // output			ddr3_cas_n
    .ddr3_ck_n                      (ddr3_ck_n),  // output [0:0]		ddr3_ck_n
    .ddr3_ck_p                      (ddr3_ck_p),  // output [0:0]		ddr3_ck_p
    .ddr3_cke                       (ddr3_cke),  // output [0:0]		ddr3_cke
    .ddr3_ras_n                     (ddr3_ras_n),  // output			ddr3_ras_n
    .ddr3_reset_n                   (ddr3_reset_n),  // output			ddr3_reset_n
    .ddr3_we_n                      (ddr3_we_n),  // output			ddr3_we_n
    .ddr3_dq                        (ddr3_dq),  // inout [7:0]		ddr3_dq
    .ddr3_dqs_n                     (ddr3_dqs_n),  // inout [0:0]		ddr3_dqs_n
    .ddr3_dqs_p                     (ddr3_dqs_p),  // inout [0:0]		ddr3_dqs_p
	.ddr3_cs_n                      (ddr3_cs_n),  // output [0:0]		ddr3_cs_n
    .ddr3_dm                        (ddr3_dm),  // output [0:0]		ddr3_dm
    .ddr3_odt                       (ddr3_odt),  // output [0:0]		ddr3_odt  

    .O_init_calib_complete                (O_init_calib_complete),
    .O_ddr_wr_finish                      (O_ddr_wr_finish),
    .O_rram_rq_read                       (O_rram_rq_read),
    .O_fifo_sample_finish                 (O_fifo_sample_finish),
	/////
	.fifo_ddr_done(fifo_ddr_done),
	.o_kb_data(kb_data),
	.rram_read_addr1(rram_read_addr1),
	.rram_read_addr2(rram_read_addr2),
	.read_ram_finish1(read_ram_finish1),
	.read_ram_finish2(read_ram_finish2),
	.rram_rclk(rram_rclk),
	.flash_spi_clk(spi_clk),
    .k_b_finish_O(k_b_finish_O),

    // RS422参数更新 (与new_rs422共用物理引脚)
    .I_rs422_rx(rs422_rxd),
    .O_rs422_tx(rs422_tx_from_kb),
    .O_rs422_tx_en(rs422_txen_from_kb),
    .O_update_active(update_active_kb),
    .flash_io_sig(flash_io_sig),    // 读模式=1(FPGA高阻),写模式=0 → IOBUF T
    .O_spi_read(spi_read_kb)        // spi_wr读MISO中=1 → IOBUF切为输入
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
wire flash_iobuf_T;
assign flash_iobuf_T = update_active_kb ? spi_read_kb : flash_io_sig;

IOBUF #(
    .IBUF_LOW_PWR("TRUE"),
    .IOSTANDARD("DEFAULT")
) IOBUF_flash_D0 (
    .O  (flash1_D0_i),   // 输入到FPGA (MISO)
    .IO (flash1_D0),     // 物理引脚
    .I  (flash1_D0_o),   // FPGA输出 (MOSI)
    .T  (flash_iobuf_T)  // T=0输出使能; T=1高阻接收
);

IOBUF #(
    .IBUF_LOW_PWR("TRUE"),
    .IOSTANDARD("DEFAULT")
) IOBUF_flash_D1 (
    .O  (flash1_D1_i),   // 输入到FPGA (Dual Input)
    .IO (flash1_D1),     // 物理引脚
    .I  (flash1_D1_o),   // FPGA输出 (Dual Output)
    .T  (flash_iobuf_T)  // T=0输出使能; T=1高阻接收
);






endmodule

