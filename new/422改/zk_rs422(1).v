`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: SITP
// Engineer: 
// 
// Create Date:   
// Design Name:    
// Module Name:    
// Project Name:   
// Target Devices: 
// Tool versions:  
// Description: 
//
// Dependencies: 
//
// Revision: V0.01
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module zk_rs422(
	input	I_clk, 
	input	I_rst,
	 
	output	O_tx_en,
	output	O_tx, 
	input	I_rx, 
	
	//output   reg cmd_update,
	//output	O_param_update, 					
	output	[15:0] 	O_ChengXiangZhouQi,	
	output	[15:0] 	O_JiFenShiJian,			
	output	[7:0] 	O_ChengXiangZengYi,	
	output  [7:0]   O_image_ctrl,		
	output	O_driver_en, 
			
	//output	[31:0] 	O_XiangJiWenDu,
	//output	[15:0] 	O_JiaoPingMianWenDu,
	//output	[15:0] 	O_ShangDianZhuangTai,		//F4
	//output	[31:0] 	O_TuXiangJiShu,
	//output	[15:0] 	O_BaoGuangMoShi,			//F6
	//output	[15:0] 	O_ZhiLengJiMenXian,			//F3
	//output	[15:0]	O_TuXiangLeiXing,			//F5
	
	//时间信息
	input           I_time_update_busy,
	// input	[7:0]  I_year,
	// input	[7:0]   I_month,
	// input	[7:0]   I_date,
	input	[7:0]  I_second,
	input   [15:0] I_millisecond,

	output	O_time_update,
	output	[7:0] O_year,
	output	[7:0] O_month,
	output	[7:0] O_date,
	output  [7:0] O_hour,
    output	[7:0] O_minute,
	output	[7:0] O_second,
	output  [15:0] O_millisecond,
	//output	[7:0] O_ShiJianZhuangTai, 
	

	input	I_temp1_rdy, 
	input	[15:0] I_temperature1

	// input	[15:0] COLUMN_NUM, 
	// input	[15:0] ROW_NUM

	);

reg driver_en;
reg tx_en;
assign O_tx_en = ~tx_en;
//assign O_rx_en = 1'b0;
/////////rx/////////////////

wire [7:0] rx_data;
wire rx_rdy;
wire rxclk;
reg [6:0] receive_fsm; 
reg [5:0] rx_count;
reg [1:0] rxclk_sample;
reg get_data;
reg delay;

// 超时计数器
reg [15:0] rx_timeout_cnt;    // 接收字节间隔超时计数器（400us）
reg [17:0] resp_timeout_cnt;  // 应答超时计数器（2ms）
reg rx_timeout_flag;          // 接收超时标志
reg resp_timeout_flag;        // 应答超时标志

reg [15:0] COLUMN_NUM;
reg [15:0] ROW_NUM;

reg [7:0] package_length;
reg [7:0] GongZuoMoShi;
reg [7:0] HeBingMoShi;
reg [7:0] image_ctrl;

reg [7:0] image_ctrl_last;

reg	[7:0] BeiYong;


reg	[7:0] 	package_type;
reg	[15:0] 	package_head;
reg	[15:0] 	JiFenShiJian;			
reg	[7:0] 	ChengXiangZengYi;			
reg	[15:0] 	ChengXiangZhouQi;	

//校正参数包
reg [31:0] package_num; 
reg [15:0] package_lenjz;

reg [7:0] JiaoZheng_CanShu [0:499];

// 中空导航数据包
reg [15:0] mid_frame_head;        //0-1
reg [15:0] mid_system_status;     //2-3
reg [63:0] mid_time;              //4-11
reg [31:0] mid_longitude;         //12-15
reg [31:0] mid_latitude;          //16-19
reg [31:0] mid_altitude;          //20-23
reg [31:0] mid_roll;              //24-27
reg [31:0] mid_pitch;             //28-31
reg [31:0] mid_yaw;               //32-35
reg [31:0] mid_track;             //36-39
reg [31:0] mid_north_speed;       //40-43
reg [31:0] mid_east_speed;        //44-47
reg [31:0] mid_down_speed;        //48-51
reg [31:0] mid_roll_rate;         //52-55
reg [31:0] mid_pitch_rate;        //56-59
reg [31:0] mid_yaw_rate;          //60-63
reg [7:0]  mid_frame_seq;         //64
reg [7:0]  mid_checksum;          //65
reg [7:0]  mid_reserved;          //66

// 高空导航数据包
reg [16:0]  high_frame_head;      //1-2:0x55
reg [7:0]  high_data_len;         //3
reg [7:0]  high_frame_type;       //4:0x12
reg [15:0] high_sys_status;       //5-6
reg [15:0] high_nav_status;       //7-8
reg [15:0] high_true_heading;     //9-10
reg [15:0] high_pitch;            //11-12
reg [15:0] high_roll;             //13-14
reg [15:0] high_gyro_x;           //15-16
reg [15:0] high_gyro_y;           //17-18
reg [15:0] high_gyro_z;           //19-20
reg [15:0] high_accel_z;          //21-22
reg [15:0] high_vel_north;        //23-24
reg [15:0] high_vel_east;         //25-26
reg [31:0] high_longitude;        //27-30
reg [31:0] high_latitude;         //31-34
reg [31:0] high_altitude;         //35-38
reg [15:0] high_overload_x;       //39-40
reg [15:0] high_overload_y;       //41-42
reg [15:0] high_overload_z;       //43-44
reg [15:0] high_vel_up;           //45-46
reg [31:0] high_nav_time;         //47-50
reg [31:0] high_utc_sec;          //51-54
reg [31:0] high_bd_ms;            //55-58
reg [15:0] high_bd_week;          //59-60
reg [15:0] high_reserved1;        //61-62
reg [15:0] high_reserved2;        //63-64
reg [15:0] high_reserved3;        //65-66
reg [7:0]  high_checksum;         //67

// 高空卫星数据包
reg [15:0]  sat_frame_head;       //1-2
reg [7:0]  sat_data_len;          //3
reg [7:0]  sat_frame_type;        //4:0x11
reg [7:0]  sat_year;              //5
reg [7:0]  sat_month;             //6
reg [7:0]  sat_day;               //7
reg [7:0]  sat_hour;              //8
reg [7:0]  sat_minute;            //9
reg [7:0]  sat_second;            //10
reg [15:0] sat_millisecond;       //11-12
reg [31:0] sat_longitude;         //13-16
reg [31:0] sat_latitude;          //17-20
reg [31:0] sat_altitude;          //21-24
reg [31:0] sat_vel_north;         //25-28
reg [31:0] sat_vel_up;            //29-32
reg [31:0] sat_vel_east;          //33-36
reg [15:0] sat_nav_status;        //37-38
reg [15:0] sat_pdop;              //39-40
reg [7:0]  sat_data_valid;        //41
reg [7:0]  sat_checksum;          //42
reg [199:0] sat_reserved;         //43-66

//导航数据包温度
reg  [31:0] HeiTiA_WenDu;      // 黑体A温度
reg  [31:0] HeiTiB_WenDu;      // 黑体B温度
reg  [15:0] HuanJingWenDu_1;   // 环境温度1
reg  [15:0] HuanJingWenDu_2;   // 环境温度2
reg  [15:0] HuanJingWenDu_3;   // 环境温度3
reg  [15:0] HuanJingWenDu_4;   // 环境温度4
reg  [15:0] HuanJingWenDu_5;   // 环境温度5
reg  [15:0] HuanJingWenDu_6;   // 环境温度6
reg  [15:0] HuanJingWenDu_7;   // 环境温度7
reg  [15:0] HuanJingWenDu_8;   // 环境温度8
reg  [15:0] HuanJingWenDu_9;   // 环境温度9
reg  [15:0] HuanJingWenDu_10;  // 环境温度10
reg  [31:0] JiGuangCeJu_1;// 激光测距参数
reg  [31:0] JiGuangCeJu_2;
reg  [31:0] JiGuangCeJu_3;
reg  [23:0] JiGuangCeJu_4;

//output	[31:0] 	O_XiangJiWenDu,
//output	[15:0] 	O_JiaoPingMianWenDu,
//reg	[15:0] 	ShangDianZhuangTai;		//F4
//output	[31:0] 	O_TuXiangJiShu,
//reg	[15:0] 	BaoGuangMoShi;			//F6
//reg	[15:0] 	ZhiLengJiMenXian;			//F3
//reg	[15:0]	TuXiangLeiXing;			//F5
reg package_en;
/*
assign	O_param_update = package_en;
assign	O_cnt_yaoce_cmd = cnt_yaoce_cmd;
assign	O_cnt_yaoce_cmd_right = cnt_yaoce_cmd_right;
assign	O_cnt_yaoce_cmd_error = cnt_yaoce_cmd_error;
assign	O_package_type = package_type;
assign	O_JiFenShiJian = JiFenShiJian;
assign	O_ChengXiangZengYi = ChengXiangZengYi;
assign	O_ChengXiangZhouQi = ChengXiangZhouQi;
assign	O_XiangJiWenDu[31:0] = {temperature1[15:0], temperature1[15:0]};
assign	O_JiaoPingMianWenDu[15:0] = temperature[15:0];
assign	O_ShangDianZhuangTai = ShangDianZhuangTai;
assign	O_TuXiangJiShu = I_TuXiangJiShu;
assign	O_BaoGuangMoShi = BaoGuangMoShi;
assign	O_ZhiLengJiMenXian = ZhiLengJiMenXian;
//*/

//assign	O_param_update = package_en;
assign	O_JiFenShiJian = JiFenShiJian;
assign	O_ChengXiangZengYi = ChengXiangZengYi;
assign	O_ChengXiangZhouQi = ChengXiangZhouQi;
assign  O_image_ctrl = image_ctrl_last;

//assign	O_ShangDianZhuangTai = ShangDianZhuangTai;
//assign	O_TuXiangLeiXing = TuXiangLeiXing;
//reg [15:0] JiFenShiJian_tmp;
//reg [15:0] ChengXiangZengYi_tmp;
//reg	[15:0] ChengXiangZhouQi_tmp;
//reg	[15:0] ZhiLengJiMenXian_tmp;
//reg	[15:0] ShangDianZhuangTai_tmp;
//reg	[15:0] TuXiangLeiXing_tmp;
//reg	[15:0] BaoGuangMoShi_tmp;

reg	[7:0] RCV_Parity;
//reg	[15:0] package_Tail;



reg flag_cmd_send;
reg cmd_update ;

reg	time_update;
reg	[7:0] year;
reg	[7:0] month;
reg	[7:0] date;
reg	[7:0] hour;
reg	[7:0] minute;
reg	[7:0] second;
reg [15:0] millisecond;

reg	[7:0] year_tmp;
reg	[7:0] month_tmp;
reg	[7:0] date_tmp;
reg	[7:0] hour_tmp;
reg	[7:0] minute_tmp;
reg	[7:0] second_tmp;
reg [15:0] millisecond_tmp;

// reg	[7:0] year_syn;
// reg	[7:0] month_syn;
// reg	[7:0] date_syn;
reg	[7:0] second_syn;
reg	[15:0] millisecond_syn;

assign	O_time_update = time_update;
assign	O_year = year;
assign	O_month = month;
assign	O_date = date;
assign  O_hour = hour;
assign  O_minute = minute;
assign	O_second = second;
assign  O_millisecond = millisecond;


reg [15:0] cmd_value_zq;
reg [15:0] cmd_value_jf; 
reg [7:0]  cmd_value_zy; 
reg [7:0]  cmd_value_gm; 
reg [7:0]  cmd_value_hm; 

reg [7:0] crc_num;

reg [15:0] crc_rcv;
reg [15:0] crc_send;

reg	[7:0] tx_count;
reg	[7:0] tx_count_length;

reg crc_err;


reg rx_en;
reg [1:0] sw_fsm;
////////////tx////////////////
wire tx_busy;
wire txclk;
reg start_send;
reg [5:0] send_cnt;
reg [1:0] txclk_sample;
reg [7:0] tx_data;
reg send_rdy;
reg send_en;		//enable send 
reg send_finish;	//finish send
reg [1:0] send_fsm;
//////////////package/////////////////////////
reg [7:0] send_data[27:0]; //send message 
//reg [1:0] package_fsm;
//reg [5:0] pack_cnt;


///////////////////////////////////
//assign O_tx = I_rx;			//only for test
///*
uart_baudrate U7_1(
	.I_clk(I_clk), 
	.I_rst(I_rst), 
	.O_txclk(txclk), 
	.O_rxclk(rxclk)
	);

uart_rx U7_2(
	.I_clk(I_clk),
	.I_rst(I_rst),
	.I_rxclk(rxclk),
	.I_rx(I_rx),
	.I_get_data(get_data),
	.O_rx_data(rx_data),
	.O_rx_rdy(rx_rdy)
	);

uart_tx U7_3(
	.I_clk(I_clk),
	.I_rst(I_rst),
	.I_txclk(txclk),
	.I_tx_data(tx_data),
	.I_tx_en(send_en),
	.O_tx(O_tx), 
	.O_tx_busy(tx_busy)
	);
//*/

///////////////////time_update////////////////////////////
always @(posedge I_clk) begin
	if (!I_rst) begin
		second_syn <= 0;
		millisecond_syn <= 0;
	end //end if
	else if (I_time_update_busy == 1'b0) begin
		    second_syn <= I_second;
			millisecond_syn <= I_millisecond;
	end //end if
end //end else

///////////////////clk_sample////////////////////////////

reg [15:0] temperature1;
always @(posedge I_clk) begin
	if (!I_rst) begin
		temperature1 <= 0;
	end //end if
	else begin
		if (I_temp1_rdy) begin
			temperature1 <= I_temperature1;
		end //end if
	end //end else
end //end always



///////////////////clk_sample////////////////////////////
always @(posedge I_clk) begin
	if (!I_rst) begin
		rxclk_sample <= 0;
		txclk_sample <= 0;
	end //end if
	else begin
		rxclk_sample[1] <= rxclk_sample[0];		//sample rxclk
		rxclk_sample[0] <= rxclk;
		
		txclk_sample[1] <= txclk_sample[0];		//sample txclk 
		txclk_sample[0] <= txclk;
	end //end else
end //end always

/////////////rx_process////////////////////////	
integer i;  
always @(posedge I_clk) begin
	if (!I_rst) begin
		receive_fsm <= 0;
		get_data <= 0;
		rx_count <= 0;
		cmd_update <= 0;
		delay <= 0;

        
		package_length <= 8'h0;
        image_ctrl <= 8'h0;
		image_ctrl_last <= 8'h0;

        
		cmd_value_zq <= 16'h0;
        cmd_value_jf <= 16'h0;
        cmd_value_zy <= 8'h0;
        cmd_value_gm <= 8'h0;
        cmd_value_hm <= 8'h0;

		package_type <= 8'h0; 
        package_head <= 16'h0;

		JiFenShiJian <= 16'd2000;		//2ms
       
		ChengXiangZengYi <= 8'h1;
		ChengXiangZhouQi <= 16'd5000;			//5000ms, 20fps
        GongZuoMoShi  <=8'h0;
        HeBingMoShi   <=8'h0;
		BeiYong <= 8'h0;

		//ShangDianZhuangTai <= 16'h0000;

		RCV_Parity <= 8'h0;

		time_update <= 1'b0;
		// year <= 16'd2026;
		// month <= 8'd1;
		// date <= 8'd20;
		// second <= 0;
		year_tmp <= 8'd26;
		month_tmp <= 8'd1;
		date_tmp <= 8'd20;
		hour_tmp  <= 0;
        minute_tmp <= 0;
        second_tmp <= 0;
        millisecond_tmp <= 0;

		year <= 8'd26;
		month <= 8'd1;
		date <= 8'd20;
		hour  <= 0;
        minute <= 0;
        second <= 0;
        millisecond <= 0;
		//ZhengMiaoLeiJiaZhi <= 32'd0;
		//HaoMiaoZhi <= 16'd0;
		//ZhengMiaoLeiJiaZhi_tmp <= 32'd0;
		//HaoMiaoZhi_tmp <= 16'd0;
        package_num <= 0;
        package_lenjz <= 0;
		
		
        for(i = 0; i < 500; i = i + 1) begin
            JiaoZheng_CanShu[i] <= 8'h00;
        end

		mid_frame_head <= 16'h0000;
		mid_system_status <= 16'h0000;
		mid_time <= 64'h0000000000000000;
		mid_longitude <= 32'h00000000;
		mid_latitude <= 32'h00000000;
		mid_altitude <= 32'h00000000;
		mid_roll <= 32'h00000000;
		mid_pitch <= 32'h00000000;
		mid_yaw <= 32'h00000000;
		mid_track <= 32'h00000000;
		mid_north_speed <= 32'h00000000;
		mid_east_speed <= 32'h00000000;
		mid_down_speed <= 32'h00000000;
		mid_roll_rate <= 32'h00000000;
		mid_pitch_rate <= 32'h00000000;
		mid_yaw_rate <= 32'h00000000;
		mid_frame_seq <= 8'h00;
		mid_checksum <= 8'h00;
		mid_reserved <= 8'h00;
       
	    high_frame_head <= 16'h0000;
		high_data_len <= 8'h00;
		high_frame_type <= 8'h00;
		high_sys_status <= 16'h0000;
		high_nav_status <= 16'h0000;
		high_true_heading <= 16'h0000;
		high_pitch <= 16'h0000;
		high_roll <= 16'h0000;
		high_gyro_x <= 16'h0000;
		high_gyro_y <= 16'h0000;
		high_gyro_z <= 16'h0000;
		high_accel_z <= 16'h0000;
		high_vel_north <= 16'h0000;
		high_vel_east <= 16'h0000;
		high_longitude <= 32'h00000000;
		high_latitude <= 32'h00000000;
		high_altitude <= 32'h00000000;
		high_overload_x <= 16'h0000;
		high_overload_y <= 16'h0000;
		high_overload_z <= 16'h0000;
		high_vel_up <= 16'h0000;
		high_nav_time <= 32'h00000000;
		high_utc_sec <= 32'h00000000;
		high_bd_ms <= 32'h00000000;
		high_bd_week <= 16'h0000;
		high_reserved1 <= 16'h0000;
		high_reserved2 <= 16'h0000;
		high_reserved3 <= 16'h0000;
		high_checksum <= 8'h00;
        
		sat_frame_head <= 16'h00;
		sat_data_len <= 8'h00;
		sat_frame_type <= 8'h00;
		sat_year <= 8'h00;
		sat_month <= 8'h00;
		sat_day <= 8'h00;
		sat_hour <= 8'h00;
		sat_minute <= 8'h00;
		sat_second <= 8'h00;
		sat_millisecond <= 16'h0000;
		sat_longitude <= 32'h00000000;
		sat_latitude <= 32'h00000000;
		sat_altitude <= 32'h00000000;
		sat_vel_north <= 32'h00000000;
		sat_vel_up <= 32'h00000000;
		sat_vel_east <= 32'h00000000;
		sat_nav_status <= 16'h0000;
		sat_pdop <= 16'h0000;
		sat_data_valid <= 8'h00;
		sat_checksum <= 8'h00;
		sat_reserved <= 200'd0;
        

        HeiTiA_WenDu <= 0;    
        HeiTiB_WenDu <= 0;  
        HuanJingWenDu_1 <= 0;
        HuanJingWenDu_2 <= 0; 
        HuanJingWenDu_3 <= 0;
        HuanJingWenDu_4 <= 0;
        HuanJingWenDu_5 <= 0;
        HuanJingWenDu_6 <= 0;
        HuanJingWenDu_7 <= 0;
        HuanJingWenDu_8 <= 0;
        HuanJingWenDu_9 <= 0;
        HuanJingWenDu_10 <= 0;
        JiGuangCeJu_1 <= 0;
        JiGuangCeJu_2 <= 0;
        JiGuangCeJu_3 <= 0;
        JiGuangCeJu_4 <= 0;

        crc_num <= 0;
		crc_rcv <= 0;
		crc_err <= 0;
		//O_crc_err_num <= 0;
		package_en <= 0;
	
		send_data[27] <= 0;
		send_data[26] <= 0;
		send_data[25] <= 0;
		send_data[24] <= 0;
		send_data[23] <= 0;
		send_data[22] <= 0;
		send_data[21] <= 0;
		send_data[20] <= 0;
		send_data[19] <= 0;
		send_data[18] <= 0;
		send_data[17] <= 0;
		send_data[16] <= 0;
		send_data[15] <= 0;
		send_data[14] <= 0;
		send_data[13] <= 0;
		send_data[12] <= 0;
		send_data[11] <= 0;
		send_data[10] <= 0;
		send_data[9] <= 0;
		send_data[8] <= 0;
		send_data[7] <= 0;
		send_data[6] <= 0;
		send_data[5] <= 0;
		send_data[4] <= 0;
		send_data[3] <= 0;
		send_data[2] <= 0;
		send_data[1] <= 0;
		send_data[0] <= 0;
		
		send_rdy <= 0;
		crc_send <= 0;
		
		tx_count <= 0;
		tx_count_length <= 0;
		flag_cmd_send <= 1'b0;

		rx_timeout_cnt <= 16'd0;
		resp_timeout_cnt <= 18'd0;
		rx_timeout_flag <= 1'b0;
		resp_timeout_flag <= 1'b0;
		
	end //end if
	else begin

		if (receive_fsm != 0) begin
			rx_timeout_cnt <= rx_timeout_cnt + 1'b1;
			if (rx_timeout_cnt >= 16'd40000) begin // 超过400us，触发超时
				rx_timeout_flag <= 1'b1;
				receive_fsm <= 0;       // 回到等待识别码状态
				rx_count <= 0;          // 接收计数清零
				rx_timeout_cnt <= 0;    // 计数器清零
			end
		end 
		else begin        // 未接收数据时
			rx_timeout_cnt <= 16'd0;
			rx_timeout_flag <= 1'b0;
		end

		if (flag_cmd_send == 1'b1) begin  // 收到查询状态包需应答
			resp_timeout_cnt <= resp_timeout_cnt + 1'b1;
			if (resp_timeout_cnt >= 18'd200000) begin  // 超过2ms强制触发发送
				resp_timeout_flag <= 1'b1;
				send_rdy <= 1'b1;       // 强制启动发送
				resp_timeout_cnt <= 0;  // 计数器清零
			end
		end 
		else if (send_fsm != 0) begin  // 已启动发送，清零计数器
			resp_timeout_cnt <= 18'd0;
			resp_timeout_flag <= 1'b0;
		end

		if (rxclk_sample == 2'b10) begin 			//sample rxclk negedge
			if (rx_rdy) begin						//receive one byte
				get_data <= 1;						//get the received data;
				//cmd_package[rx_count] <= rx_data;
				rx_count <= rx_count + 1;
				rx_timeout_cnt <= 16'd0;  // 收到字节，重置接收超时计数器
				case (receive_fsm)
					0: begin
						if ((rx_count==0) && ((rx_data == 8'hAF) || (rx_data == 8'h68) || (rx_data == 8'h90))) begin			//BLOCK_HEAD_WORD1
							//send_data[0] <= rx_data;
							//crc_send <= rx_data;
							//crc_rcv <= rx_data;
							package_head[15:8] <= rx_data;
							crc_rcv <= 0;
							receive_fsm <= 1;
						end //end if
						else begin
							rx_count <= 0;	
							receive_fsm <= 0;
						end //end else
					end //end case 0
					
					1: begin
						if ((rx_count == 1)&&((rx_data == 8'h21) || (rx_data == 8'h12) || (rx_data == 8'h13)|| (rx_data == 8'h72) || (rx_data == 8'h5A))) begin			    //BLOCK_HEAD_WORD2
							//send_data[1] <= rx_data;
							//crc_send <= crc_send + rx_data;
							//crc_rcv <= crc_rcv + rx_data;
							package_head[7:0] <= rx_data;
							receive_fsm <= 2;
						end //end if
						else begin
							rx_count <= 0;	
							receive_fsm <= 0;
						end //end else
					end //end case 1

                   2: begin												//
						if ((rx_count==2) && (rx_data == 8'hFF))begin			//设备标识, MSB
							receive_fsm <= 3;
						end //end if
						else begin							    
							rx_count <= 0;	
							receive_fsm <= 0;
						end //end if
					end //end case 2 
					
                    3: begin
						if ((rx_count==3) && (rx_data == 8'h04)) begin			//设备标识, LSB
							receive_fsm <= 4;
						end //end if
						else begin
							rx_count <= 0;	
							receive_fsm <= 0;
						end //end else
					end //end case 0

                    4: begin												
						if ((rx_count == 4)&& (package_head != 16'h905A)) begin							//数据类型
							package_type[7:0] <= rx_data;
							crc_rcv <= 0;
							if ((rx_data == 8'h02) && (package_head == 16'hAF21)) begin	                    //参数包请求
								receive_fsm <= 5;
							end //end if
							else if ((rx_data == 8'h04) && (package_head == 16'hAF12)) begin				//成像包请求
								receive_fsm <= 6;
							end //end else if
							// else if (rx_data == 8'h01) begin				//时间包请求
							// 	receive_fsm <= 7;
							// end //end else if
							else if ((rx_data == 8'h03) && (package_head == 16'hAF13)) begin				//查询状态包
								receive_fsm <= 7;
							end //end else if
							else if ((rx_data == 8'h01) && (package_head == 16'h6872)) begin	       //中空导航数据包
								receive_fsm <= 9;
							end //end else if
							else if ((rx_data == 8'h02) && (package_head == 16'h6872)) begin	       //高空导航数据包
								receive_fsm <= 10;
							end //end else if
							else if ((rx_data == 8'h03)&& (package_head == 16'h6872)) begin	       //高空卫星数据包
								receive_fsm <= 11;
							end //end else if
							else begin
								receive_fsm <= 12;
							end //end else
						end //end if
						else if ((rx_count == 4) && (package_head == 16'h905A)) begin
							package_num[31:24] <= rx_data;
							receive_fsm <= 8;
						end
						else begin
							rx_count <= 0;	
							receive_fsm <= 0;
						end //end else
					end //end case 4

					

					5: begin												//参数包
						if (rx_count == 5) begin							//包长度
							package_length[7:0] <= rx_data;
							crc_rcv <= crc_rcv + rx_data;
						end //end if
						else if (rx_count == 6) begin							//成像周期，MSB
							cmd_value_zq[15:8] <= rx_data;
							crc_rcv <= crc_rcv + rx_data;
						end //end if
						else if (rx_count == 7) begin							//成像周期, LSB
							cmd_value_zq[7:0] <= rx_data;
							crc_rcv <= crc_rcv + rx_data;
						end //end if
						else if (rx_count == 8) begin							//积分时间, MSB
							cmd_value_jf[15:8] <= rx_data;
							crc_rcv <= crc_rcv + rx_data;
						end //end if
                        else if (rx_count == 9) begin							//积分时间, LSB
							cmd_value_jf[7:0] <= rx_data;
							crc_rcv <= crc_rcv + rx_data;
						end //end if
                        else if (rx_count == 10) begin							//成像增益
							cmd_value_zy[7:0] <= rx_data;
							crc_rcv <= crc_rcv + rx_data;
						end //end if
                        else if (rx_count == 11) begin							//工作模式
							cmd_value_gm[7:0] <= rx_data;
							crc_rcv <= crc_rcv + rx_data;
						end //end if
                        else if (rx_count == 12) begin							//合并模式
							cmd_value_hm[7:0] <= rx_data;
							crc_rcv <= crc_rcv + rx_data;
						end //end if
                        else if (rx_count == 13) begin							//行，MSB
							ROW_NUM [15:8] <= rx_data;
                            crc_rcv <= crc_rcv + rx_data;
						end //end if
                        else if (rx_count == 14) begin							//行，MSB
							ROW_NUM [7:0] <= rx_data;
                            crc_rcv <= crc_rcv + rx_data;
						end //end if
                        else if (rx_count == 15) begin							//列，MSB
							COLUMN_NUM [15:8] <= rx_data;
                            crc_rcv <= crc_rcv + rx_data;
						end //end if
                        else if (rx_count == 16) begin							//列，LSB
							COLUMN_NUM [7:0] <= rx_data;
                            crc_rcv <= crc_rcv + rx_data;
						end //end if
                        else if (rx_count == 17) begin							//年
							year_tmp[7:0] <= rx_data;
                            crc_rcv <= crc_rcv + rx_data;
						end //end if
						else if (rx_count == 18) begin							//月
							month_tmp[7:0] <= rx_data;
                            crc_rcv <= crc_rcv + rx_data;
						end //end if
						else if (rx_count == 19) begin							//日
							date_tmp[7:0] <= rx_data;
                            crc_rcv <= crc_rcv + rx_data;
						end //end if
                        else if (rx_count == 20) begin							//时
							hour_tmp[7:0] <= rx_data;
                            crc_rcv <= crc_rcv + rx_data;
						end //end if
						else if (rx_count == 21) begin							//分
							minute_tmp[7:0] <= rx_data;
                            crc_rcv <= crc_rcv + rx_data;
						end //end if
                        else if (rx_count == 22) begin							//秒
							second_tmp[7:0] <= rx_data;
                            crc_rcv <= crc_rcv + rx_data;
						end //end if
						else if (rx_count == 23) begin							//毫秒，MSB
							millisecond_tmp[15:8] <= rx_data;
                            crc_rcv <= crc_rcv + rx_data;
						end //end if
						else if (rx_count == 24) begin							//毫秒，LSB
							millisecond_tmp[7:0] <= rx_data;
                            crc_rcv <= crc_rcv + rx_data;
						end //end if
						else if (rx_count == 25) begin							//备用
							BeiYong[7:0] <= rx_data;
                            crc_rcv <= crc_rcv + rx_data;
						end //end if
						else if (rx_count == 26) begin							//校验码, LSB
							RCV_Parity[7:0] <= rx_data;
							if ((crc_rcv[7:0] == rx_data) ) begin
								// cmd_update <= 1;
							    ChengXiangZhouQi <= cmd_value_zq ;
								JiFenShiJian     <= cmd_value_jf ;
                                ChengXiangZengYi <= cmd_value_zy ;
                                GongZuoMoShi     <= cmd_value_gm ;
                                HeBingMoShi      <= cmd_value_hm ;
								year    <= year_tmp;
								month   <= month_tmp;
								date    <= date_tmp;
								hour    <= hour_tmp;
								minute  <= minute_tmp;
								second  <= second_tmp;
								millisecond <= millisecond_tmp;

								rx_count <= 0;
								crc_rcv <= 0;
								crc_err <= 0;
								time_update <= 1'b1;
                                receive_fsm <= 0;
							end //end if
							else begin
								receive_fsm <= 0;
								rx_count <= 0;
                                crc_num <= crc_num + 1;
								crc_rcv <= 0;
								crc_err <=  1;
							end //end else
						end //end if
					end //end case 5
					
					
					6: begin												//成像请求
                        if (rx_count == 5) begin							//包长度
							package_length[7:0] <= rx_data;
							crc_rcv <= crc_rcv + rx_data;
						end //end if
                        else if (rx_count == 6) begin							//成像启停
							image_ctrl[7:0] <= rx_data;
							crc_rcv <= crc_rcv + rx_data;
						end //end if
						else if (rx_count == 7) begin							//校验码, LSB
							RCV_Parity[7:0] <= rx_data;
							if (crc_rcv[7:0] == rx_data) begin
								image_ctrl_last <= image_ctrl ;
								cmd_update <= 1;
								rx_count <= 0;
								crc_rcv <= 0;
								crc_err <= 0;
								receive_fsm <= 0;
							end //end if
							else begin
								receive_fsm <= 0;
								rx_count <= 0;
                                crc_num <= crc_num + 1;
								crc_rcv <= 0;
								crc_err <= 1;
							end //end else
						end //end if
					end //end case 6
                    
                    7: begin												//查询状态请求
                        if (rx_count == 5) begin							//包长度
							package_length[7:0] <= rx_data;
							crc_rcv <= crc_rcv + rx_data;
						end //end if
						else if (rx_count == 6) begin							//校验码, LSB
							RCV_Parity[7:0] <= rx_data;
							if (crc_rcv[7:0] == rx_data) begin
								// cmd_update <= 1;
								rx_count <= 0;
								crc_rcv <= 0;
								crc_err <= 0;
                                flag_cmd_send <= 1'b1;	
								receive_fsm <= 0;
							end //end if
							else begin
								receive_fsm <= 0;
								rx_count <= 0;
                                crc_num <= crc_num + 1;
								crc_rcv <= 0;
								crc_err <= 1;
							end //end else
						end //end if
					end //end case 7
                    
					8: begin												//校正参数包
						if (rx_count == 5) begin							//包编号
							package_num[23:16] <= rx_data;
						end //end if
						else if (rx_count == 6) begin							//包编号
							package_num[15:8] <= rx_data;
						end //end if
						else if (rx_count == 7) begin							//包编号
							package_num[7:0] <= rx_data;
						end //end if
						else if (rx_count == 8) begin							//校正包长度
							package_lenjz[15:8] <= rx_data;
						end //end if
                        else if (rx_count == 9) begin							//校正包长度
							package_lenjz[7:0] <= rx_data;
							crc_rcv <= 0;
						end //end if
						else if (rx_count >= 10 && rx_count <= 509) begin      //校正参数
                           JiaoZheng_CanShu[rx_count - 10] <= rx_data;
                            crc_rcv <= crc_rcv + rx_data;	
						end
						else if (rx_count == 510) begin							//校验码, LSB
							RCV_Parity[7:0] <= rx_data;
							if ((crc_rcv[7:0] == rx_data) ) begin
								// cmd_update <= 1;
								rx_count <= 0;
								crc_rcv <= 0;
								crc_err <= 0;
                                receive_fsm <= 0;
							end //end if
							else begin
								receive_fsm <= 0;
								rx_count <= 0;
                                crc_num <= crc_num + 1;
								crc_rcv <= 0;
								crc_err <=  1;
							end //end else
						end //end if
					end //end case 8

					9: begin												//中空导航
                        if (rx_count == 5) begin							//包长度
							package_length[7:0] <= rx_data;
							crc_rcv <= crc_rcv + rx_data;
						end //end if
						else if (rx_count == 6) begin							
							mid_frame_head [15:8] <= rx_data;
							crc_rcv <= crc_rcv + rx_data;
						end //end if
						else if (rx_count == 7) begin							
							mid_frame_head [7:0] <= rx_data;
							crc_rcv <= crc_rcv + rx_data;
						end //end if
						else if(rx_count == 8) begin 
						    mid_system_status[15:8] <= rx_data; 
						    crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 9) begin 
						    mid_system_status[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 10) begin 
							mid_time[63:56] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 11) begin 
							mid_time[55:48] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 12) begin 
							mid_time[47:40] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 13) begin 
							mid_time[39:32] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 14) begin 
							mid_time[31:24] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 15) begin 
							mid_time[23:16] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 16) begin 
							mid_time[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 17) begin 
							mid_time[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 18) begin 
							mid_longitude[31:24] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 19) begin 
							mid_longitude[23:16] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 20) begin 
							mid_longitude[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 21) begin 
							mid_longitude[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 22) begin 
							mid_latitude[31:24] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 23) begin 
							mid_latitude[23:16] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 24) begin 
							mid_latitude[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 25) begin 
							mid_latitude[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 26) begin 
							mid_altitude[31:24] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 27) begin 
							mid_altitude[23:16] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 28) begin 
							mid_altitude[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 29) begin 
							mid_altitude[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 30) begin 
							mid_roll[31:24] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 31) begin 
							mid_roll[23:16] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 32) begin 
							mid_roll[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 33) begin 
							mid_roll[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 34) begin 
							mid_pitch[31:24] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 35) begin 
							mid_pitch[23:16] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 36) begin 
							mid_pitch[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 37) begin 
							mid_pitch[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 38) begin 
							mid_yaw[31:24] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 39) begin 
							mid_yaw[23:16] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 40) begin 
							mid_yaw[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 41) begin 
							mid_yaw[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 42) begin 
							mid_track[31:24] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 43) begin 
							mid_track[23:16] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 44) begin 
							mid_track[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 45) begin 
							mid_track[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 46) begin 
							mid_north_speed[31:24] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 47) begin 
							mid_north_speed[23:16] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 48) begin 
							mid_north_speed[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 49) begin 
							mid_north_speed[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 50) begin 
							mid_east_speed[31:24] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 51) begin 
							mid_east_speed[23:16] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 52) begin 
							mid_east_speed[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 53) begin 
							mid_east_speed[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 54) begin 
							mid_down_speed[31:24] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 55) begin 
							mid_down_speed[23:16] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 56) begin 
							mid_down_speed[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 57) begin 
							mid_down_speed[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 58) begin 
							mid_roll_rate[31:24] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 59) begin 
							mid_roll_rate[23:16] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 60) begin 
							mid_roll_rate[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 61) begin 
							mid_roll_rate[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 62) begin 
							mid_pitch_rate[31:24] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 63) begin 
							mid_pitch_rate[23:16] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 64) begin 
							mid_pitch_rate[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 65) begin 
							mid_pitch_rate[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 66) begin 
							mid_yaw_rate[31:24] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 67) begin 
							mid_yaw_rate[23:16] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 68) begin 
							mid_yaw_rate[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 69) begin 
							mid_yaw_rate[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end  
                        else if(rx_count == 70) begin 
							mid_frame_seq[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 71) begin 
							mid_checksum[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 72) begin 
							mid_reserved[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 73) begin 
							HeiTiA_WenDu[31:24] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 74) begin 
							HeiTiA_WenDu[23:16] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 75) begin 
							HeiTiA_WenDu[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 76) begin 
							HeiTiA_WenDu[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 77) begin 
							HeiTiB_WenDu[31:24] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 78) begin 
							HeiTiB_WenDu[23:16] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 79) begin 
							HeiTiB_WenDu[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 80) begin 
							HeiTiB_WenDu[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 81) begin 
							HuanJingWenDu_1[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 82) begin 
							HuanJingWenDu_1[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 83) begin 
							HuanJingWenDu_2[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 84) begin 
							HuanJingWenDu_2[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 85) begin 
							HuanJingWenDu_3[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 86) begin 
							HuanJingWenDu_3[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 87) begin 
							HuanJingWenDu_4[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 88) begin 
							HuanJingWenDu_4[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 89) begin 
							HuanJingWenDu_5[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 90) begin 
							HuanJingWenDu_5[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 91) begin 
							HuanJingWenDu_6[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 92) begin 
							HuanJingWenDu_6[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 93) begin 
							HuanJingWenDu_7[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 94) begin 
							HuanJingWenDu_7[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 95) begin 
							HuanJingWenDu_8[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 96) begin 
							HuanJingWenDu_8[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 97) begin 
							HuanJingWenDu_9[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 98) begin 
							HuanJingWenDu_9[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 99) begin 
							HuanJingWenDu_10[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 100) begin 
							HuanJingWenDu_10[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 101) begin 
							JiGuangCeJu_1[31:24] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 102) begin 
							JiGuangCeJu_1[23:16] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 103) begin 
							JiGuangCeJu_1[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 104) begin 
							JiGuangCeJu_1[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 105) begin 
							JiGuangCeJu_2[31:24] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 106) begin 
							JiGuangCeJu_2[23:16] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 107) begin 
							JiGuangCeJu_2[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 108) begin 
							JiGuangCeJu_2[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 109) begin 
							JiGuangCeJu_3[31:24] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 110) begin 
							JiGuangCeJu_3[23:16] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 111) begin 
							JiGuangCeJu_3[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 112) begin 
							JiGuangCeJu_3[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 113) begin 
							JiGuangCeJu_4[23:16] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 114) begin 
							JiGuangCeJu_4[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 115) begin 
							JiGuangCeJu_4[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						if (rx_count == 116) begin							//校验码, LSB
							RCV_Parity[7:0] <= rx_data;
							if (crc_rcv[7:0] == rx_data) begin
								// cmd_update <= 1;
								rx_count <= 0;
								crc_rcv <= 0;
								crc_err <= 0;
								receive_fsm <= 0;
							end //end if
							else begin
								receive_fsm <= 0;
								rx_count <= 0;
                                crc_num <= crc_num + 1;
								crc_rcv <= 0;
								crc_err <= 1;
							end //end else
						end //end if
					end //end case 9
                    
    				10: begin												
                        if (rx_count == 5) begin				// 高空导航
                            package_length[7:0] <= rx_data;
                            crc_rcv <= crc_rcv + rx_data;
                        end 
                        else if (rx_count == 6) begin							
                            high_frame_head[15:8] <= rx_data;
                            crc_rcv <= crc_rcv + rx_data;
                        end 
                        else if (rx_count == 7) begin							
                            high_frame_head[7:0] <= rx_data;
                            crc_rcv <= crc_rcv + rx_data;
                        end 
                        else if(rx_count == 8) begin 
                            high_data_len <= rx_data; 
                            crc_rcv <= crc_rcv + rx_data; 
                        end
                        else if(rx_count == 9) begin 
                            high_frame_type <= rx_data; 
                            crc_rcv <= crc_rcv + rx_data; 
                        end
                        else if(rx_count == 10) begin 
                            high_sys_status[15:8] <= rx_data; 
                            crc_rcv <= crc_rcv + rx_data; 
                        end
                        else if(rx_count == 11) begin 
                            high_sys_status[7:0] <= rx_data; 
                            crc_rcv <= crc_rcv + rx_data; 
                        end
                        else if(rx_count == 12) begin 
                            high_nav_status[15:8] <= rx_data; 
                            crc_rcv <= crc_rcv + rx_data; 
                        end
                        else if(rx_count == 13) begin 
                            high_nav_status[7:0] <= rx_data; 
                            crc_rcv <= crc_rcv + rx_data; 
                        end
                        else if(rx_count == 14) begin 
                            high_true_heading[15:8] <= rx_data; 
                            crc_rcv <= crc_rcv + rx_data; 
                        end
                        else if(rx_count == 15) begin 
                            high_true_heading[7:0] <= rx_data; 
                            crc_rcv <= crc_rcv + rx_data; 
                        end
                        else if(rx_count == 16) begin 
                            high_pitch[15:8] <= rx_data; 
                            crc_rcv <= crc_rcv + rx_data; 
                        end
                        else if(rx_count == 17) begin 
                            high_pitch[7:0] <= rx_data; 
                            crc_rcv <= crc_rcv + rx_data; 
                        end
                        else if(rx_count == 18) begin 
                            high_roll[15:8] <= rx_data; 
                            crc_rcv <= crc_rcv + rx_data; 
                        end
                        else if(rx_count == 19) begin 
                            high_roll[7:0] <= rx_data; 
                            crc_rcv <= crc_rcv + rx_data; 
                        end
                        else if(rx_count == 20) begin 
    						high_gyro_x[15:8] <= rx_data; 
    						crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 21) begin 
    						high_gyro_x[7:0] <= rx_data; 
    						crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 22) begin 
    						high_gyro_y[15:8] <= rx_data; 
    						crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 23) begin 
    						high_gyro_y[7:0] <= rx_data; 
    						crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 24) begin 
    						high_gyro_z[15:8] <= rx_data; 
    						crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 25) begin 
    						high_gyro_z[7:0] <= rx_data; 
    						crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 26) begin 
    						high_accel_z[15:8] <= rx_data; 
    						crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 27) begin 
    						high_accel_z[7:0] <= rx_data; 
    						crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 28) begin 
    						high_vel_north[15:8] <= rx_data; 
    						crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 29) begin 
    						high_vel_north[7:0] <= rx_data; 
    						crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 30) begin 
    						high_vel_east[15:8] <= rx_data; 
    						crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 31) begin 
    						high_vel_east[7:0] <= rx_data; 
    						crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 32) begin 
    						high_longitude[31:24] <= rx_data; 
    						crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 33) begin 
    						high_longitude[23:16] <= rx_data; 
    						crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 34) begin 
    						high_longitude[15:8] <= rx_data; 
    						crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 35) begin 
    						high_longitude[7:0] <= rx_data; 
    						crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 36) begin 
    						high_latitude[31:24] <= rx_data; 
    						crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 37) begin 
    						high_latitude[23:16] <= rx_data; 
    						crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 38) begin 
    						high_latitude[15:8] <= rx_data; 
    						crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 39) begin 
    						high_latitude[7:0] <= rx_data; 
    						crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 40) begin 
    						high_altitude[31:24] <= rx_data; 
    						crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 41) begin 
    						high_altitude[23:16] <= rx_data; 
    						crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 42) begin 
    						high_altitude[15:8] <= rx_data; 
    						crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 43) begin 
    						high_altitude[7:0] <= rx_data; 
    						crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 44) begin 
    						high_overload_x[15:8] <= rx_data; 
    						crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 45) begin 
    						high_overload_x[7:0] <= rx_data; 
    						crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 46) begin 
    						high_overload_y[15:8] <= rx_data; 
    						crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 47) begin 
    						high_overload_y[7:0] <= rx_data; 
    						crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 48) begin 
    						high_overload_z[15:8] <= rx_data; 
    						crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 49) begin 
    						high_overload_z[7:0] <= rx_data; 
    						crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 50) begin 
    						high_vel_up[15:8] <= rx_data; 
    						crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 51) begin 
    						high_vel_up[7:0] <= rx_data; 
    						crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 52) begin 
    						high_nav_time[31:24] <= rx_data; 
    						crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 53) begin 
    						high_nav_time[23:16] <= rx_data; 
    						crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 54) begin 
    						high_nav_time[15:8] <= rx_data; 
    						crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 55) begin 
    						high_nav_time[7:0] <= rx_data; 
    						crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 56) begin 
    						high_utc_sec[31:24] <= rx_data; 
    						crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 57) begin 
    						high_utc_sec[23:16] <= rx_data; 
    						crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 58) begin 
    						high_utc_sec[15:8] <= rx_data; 
    						crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 59) begin 
    						high_utc_sec[7:0] <= rx_data; 
    						crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 60) begin 
    						high_bd_ms[31:24] <= rx_data; 
    						crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 61) begin 
    						high_bd_ms[23:16] <= rx_data; 
    						crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 62) begin 
    						high_bd_ms[15:8] <= rx_data; 
    						crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 63) begin 
    						high_bd_ms[7:0] <= rx_data; 
    						crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 64) begin 
    						high_bd_week[15:8] <= rx_data; 
    						crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 65) begin 
    						high_bd_week[7:0] <= rx_data; 
    						crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 66) begin 
    						high_reserved1[15:8] <= rx_data; 
    						crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 67) begin 
    						high_reserved1[7:0] <= rx_data; 
    						crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 68) begin 
    						high_reserved2[15:8] <= rx_data; 
    						crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 69) begin 
    						high_reserved2[7:0] <= rx_data; 
    						crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 70) begin 
    						high_reserved3[15:8] <= rx_data; 
    						crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 71) begin 
    						high_reserved3[7:0] <= rx_data; 
    						crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 72) begin 
                            high_checksum[7:0] <= rx_data; 
                            crc_rcv <= crc_rcv + rx_data; 
                        end 
						else if(rx_count == 73) begin 
							HeiTiA_WenDu[31:24] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 74) begin 
							HeiTiA_WenDu[23:16] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 75) begin 
							HeiTiA_WenDu[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 76) begin 
							HeiTiA_WenDu[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 77) begin 
							HeiTiB_WenDu[31:24] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 78) begin 
							HeiTiB_WenDu[23:16] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 79) begin 
							HeiTiB_WenDu[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 80) begin 
							HeiTiB_WenDu[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 81) begin 
							HuanJingWenDu_1[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 82) begin 
							HuanJingWenDu_1[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 83) begin 
							HuanJingWenDu_2[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 84) begin 
							HuanJingWenDu_2[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 85) begin 
							HuanJingWenDu_3[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 86) begin 
							HuanJingWenDu_3[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 87) begin 
							HuanJingWenDu_4[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 88) begin 
							HuanJingWenDu_4[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 89) begin 
							HuanJingWenDu_5[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 90) begin 
							HuanJingWenDu_5[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 91) begin 
							HuanJingWenDu_6[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 92) begin 
							HuanJingWenDu_6[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 93) begin 
							HuanJingWenDu_7[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 94) begin 
							HuanJingWenDu_7[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 95) begin 
							HuanJingWenDu_8[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 96) begin 
							HuanJingWenDu_8[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 97) begin 
							HuanJingWenDu_9[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 98) begin 
							HuanJingWenDu_9[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 99) begin 
							HuanJingWenDu_10[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 100) begin 
							HuanJingWenDu_10[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end //JiGuangCeJu_1
						else if(rx_count == 101) begin 
							JiGuangCeJu_1[31:24] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 102) begin 
							JiGuangCeJu_1[23:16] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 103) begin 
							JiGuangCeJu_1[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 104) begin 
							JiGuangCeJu_1[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 105) begin 
							JiGuangCeJu_2[31:24] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 106) begin 
							JiGuangCeJu_2[23:16] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 107) begin 
							JiGuangCeJu_2[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 108) begin 
							JiGuangCeJu_2[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 109) begin 
							JiGuangCeJu_3[31:24] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 110) begin 
							JiGuangCeJu_3[23:16] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 111) begin 
							JiGuangCeJu_3[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 112) begin 
							JiGuangCeJu_3[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 113) begin 
							JiGuangCeJu_4[23:16] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 114) begin 
							JiGuangCeJu_4[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 115) begin 
							JiGuangCeJu_4[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
                        if (rx_count == 116) begin						
                            RCV_Parity[7:0] <= rx_data;
                            if (crc_rcv[7:0] == rx_data) begin
                                rx_count <= 0;
                                crc_rcv <= 0;
                                crc_err <= 0;
                                receive_fsm <= 0;
                            end 
                            else begin
                                receive_fsm <= 0;
                                rx_count <= 0;
                                crc_num <= crc_num + 1;
                                crc_rcv <= 0;
                                crc_err <= 1;
                            end 
                        end 
                    end // end case 10
    
    				11: begin				                          //高空卫星								
                        if (rx_count == 5) begin							// 包长度
                            package_length[7:0] <= rx_data;
                            crc_rcv <= crc_rcv + rx_data;
                        end 
                        else if (rx_count == 6) begin							
                            sat_frame_head[15:8] <= rx_data;
                            crc_rcv <= crc_rcv + rx_data;
                        end 
                        else if (rx_count == 7) begin							
                            sat_frame_head[7:0] <= rx_data;
                            crc_rcv <= crc_rcv + rx_data;
                        end 
                        else if(rx_count == 8) begin 
                            sat_data_len <= rx_data; 
                            crc_rcv <= crc_rcv + rx_data; 
                        end
                        else if(rx_count == 9) begin 
                            sat_frame_type <= rx_data; 
                            crc_rcv <= crc_rcv + rx_data; 
                        end
                        else if(rx_count == 10) begin 
    						sat_year <= rx_data; 
    					    crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 11) begin 
    						sat_month <= rx_data; 
    					    crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 12) begin 
    						sat_day <= rx_data; 
    					    crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 13) begin 
    						sat_hour <= rx_data; 
    					    crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 14) begin 
    						sat_minute <= rx_data; 
    					    crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 15) begin 
    						sat_second <= rx_data; 
    					    crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 16) begin 
    						sat_millisecond[15:8] <= rx_data; 
    					    crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 17) begin 
    						sat_millisecond[7:0] <= rx_data; 
    					    crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 18) begin 
    						sat_longitude[31:24] <= rx_data; 
    					    crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 19) begin 
    						sat_longitude[23:16] <= rx_data; 
    					    crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 20) begin 
    						sat_longitude[15:8] <= rx_data; 
    					    crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 21) begin 
    						sat_longitude[7:0] <= rx_data; 
    					    crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 22) begin 
    						sat_latitude[31:24] <= rx_data; 
    					    crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 23) begin 
    						sat_latitude[23:16] <= rx_data; 
    					    crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 24) begin 
    						sat_latitude[15:8] <= rx_data; 
    					    crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 25) begin 
    						sat_latitude[7:0] <= rx_data; 
    					    crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 26) begin 
    						sat_altitude[31:24] <= rx_data; 
    					    crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 27) begin 
    						sat_altitude[23:16] <= rx_data; 
    					    crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 28) begin 
    						sat_altitude[15:8] <= rx_data; 
    					    crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 29) begin 
    						sat_altitude[7:0] <= rx_data; 
    					    crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 30) begin 
    						sat_vel_north[31:24] <= rx_data; 
    					    crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 31) begin 
    						sat_vel_north[23:16] <= rx_data; 
    					    crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 32) begin 
    						sat_vel_north[15:8] <= rx_data; 
    					    crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 33) begin 
    						sat_vel_north[7:0] <= rx_data; 
    					    crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 34) begin 
    						sat_vel_up[31:24] <= rx_data; 
    					    crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 35) begin 
    						sat_vel_up[23:16] <= rx_data; 
    					    crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 36) begin 
    						sat_vel_up[15:8] <= rx_data; 
    					    crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 37) begin 
    						sat_vel_up[7:0] <= rx_data; 
    					    crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 38) begin 
    						sat_vel_east[31:24] <= rx_data; 
    					    crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 39) begin 
    						sat_vel_east[23:16] <= rx_data; 
    					    crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 40) begin 
    						sat_vel_east[15:8] <= rx_data; 
    					    crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 41) begin 
    						sat_vel_east[7:0] <= rx_data; 
    					    crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 42) begin 
    						sat_nav_status[15:8] <= rx_data; 
    					    crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 43) begin 
    						sat_nav_status[7:0] <= rx_data; 
    					    crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 44) begin 
    						sat_pdop[15:8] <= rx_data; 
    					    crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 45) begin 
    						sat_pdop[7:0] <= rx_data; 
    					    crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 46) begin 
    						sat_data_valid <= rx_data; 
    					    crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 47) begin 
    						sat_checksum <= rx_data; 
    					    crc_rcv <= crc_rcv + rx_data; 
    					end
                        else if(rx_count == 48) begin 
                            sat_reserved[199:192] <= rx_data;  
                            crc_rcv <= crc_rcv + rx_data; 
                        end
                        else if(rx_count == 49) begin 
                            sat_reserved[191:184] <= rx_data;  
                            crc_rcv <= crc_rcv + rx_data; 
                        end
                        else if(rx_count == 50) begin 
                            sat_reserved[183:176] <= rx_data;  
                            crc_rcv <= crc_rcv + rx_data; 
                        end
                        else if(rx_count == 51) begin 
                            sat_reserved[175:168] <= rx_data;  
                            crc_rcv <= crc_rcv + rx_data; 
                        end
                        else if(rx_count == 52) begin 
                            sat_reserved[167:160] <= rx_data;  
                            crc_rcv <= crc_rcv + rx_data; 
                        end
                        else if(rx_count == 53) begin 
                            sat_reserved[159:152] <= rx_data;  
                            crc_rcv <= crc_rcv + rx_data; 
                        end
                        else if(rx_count == 54) begin 
                            sat_reserved[151:144] <= rx_data;  
                            crc_rcv <= crc_rcv + rx_data; 
                        end
                        else if(rx_count == 55) begin 
                            sat_reserved[143:136] <= rx_data;  
                            crc_rcv <= crc_rcv + rx_data; 
                        end
                        else if(rx_count == 56) begin 
                            sat_reserved[135:128] <= rx_data;  
                            crc_rcv <= crc_rcv + rx_data; 
                        end
                        else if(rx_count == 57) begin 
                            sat_reserved[127:120] <= rx_data;  
                            crc_rcv <= crc_rcv + rx_data; 
                        end
                        else if(rx_count == 58) begin 
                            sat_reserved[119:112] <= rx_data;  
                            crc_rcv <= crc_rcv + rx_data; 
                        end
                        else if(rx_count == 59) begin 
                            sat_reserved[111:104] <= rx_data; 
                            crc_rcv <= crc_rcv + rx_data; 
                        end
                        else if(rx_count == 60) begin 
                            sat_reserved[103:96] <= rx_data;   
                            crc_rcv <= crc_rcv + rx_data; 
                        end
                        else if(rx_count == 61) begin 
                            sat_reserved[95:88] <= rx_data;    
                            crc_rcv <= crc_rcv + rx_data; 
                        end
                        else if(rx_count == 62) begin 
                            sat_reserved[87:80] <= rx_data;    
                            crc_rcv <= crc_rcv + rx_data; 
                        end
                        else if(rx_count == 63) begin 
                            sat_reserved[79:72] <= rx_data;   
                            crc_rcv <= crc_rcv + rx_data; 
                        end
                        else if(rx_count == 64) begin 
                            sat_reserved[71:64] <= rx_data;    
                            crc_rcv <= crc_rcv + rx_data; 
                        end
                        else if(rx_count == 65) begin 
                            sat_reserved[63:56] <= rx_data;   
                            crc_rcv <= crc_rcv + rx_data; 
                        end
                        else if(rx_count == 66) begin 
                            sat_reserved[55:48] <= rx_data;   
                            crc_rcv <= crc_rcv + rx_data; 
                        end
                        else if(rx_count == 67) begin 
                            sat_reserved[47:40] <= rx_data;   
                            crc_rcv <= crc_rcv + rx_data; 
                        end
                        else if(rx_count == 68) begin 
                            sat_reserved[39:32] <= rx_data;    
                            crc_rcv <= crc_rcv + rx_data; 
                        end
                        else if(rx_count == 69) begin 
                            sat_reserved[31:24] <= rx_data;   
                            crc_rcv <= crc_rcv + rx_data; 
                        end
                        else if(rx_count == 70) begin 
                            sat_reserved[23:16] <= rx_data;   
                            crc_rcv <= crc_rcv + rx_data; 
                        end
                        else if(rx_count == 71) begin 
                            sat_reserved[15:8] <= rx_data;    
                            crc_rcv <= crc_rcv + rx_data; 
                        end
    					else if(rx_count == 72) begin 
                            sat_reserved[7:0] <= rx_data;    
                            crc_rcv <= crc_rcv + rx_data; 
                        end
						else if(rx_count == 73) begin 
							HeiTiA_WenDu[31:24] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 74) begin 
							HeiTiA_WenDu[23:16] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 75) begin 
							HeiTiA_WenDu[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 76) begin 
							HeiTiA_WenDu[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 77) begin 
							HeiTiB_WenDu[31:24] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 78) begin 
							HeiTiB_WenDu[23:16] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 79) begin 
							HeiTiB_WenDu[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 80) begin 
							HeiTiB_WenDu[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 81) begin 
							HuanJingWenDu_1[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 82) begin 
							HuanJingWenDu_1[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 83) begin 
							HuanJingWenDu_2[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 84) begin 
							HuanJingWenDu_2[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 85) begin 
							HuanJingWenDu_3[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 86) begin 
							HuanJingWenDu_3[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 87) begin 
							HuanJingWenDu_4[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 88) begin 
							HuanJingWenDu_4[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 89) begin 
							HuanJingWenDu_5[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 90) begin 
							HuanJingWenDu_5[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 91) begin 
							HuanJingWenDu_6[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 92) begin 
							HuanJingWenDu_6[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 93) begin 
							HuanJingWenDu_7[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 94) begin 
							HuanJingWenDu_7[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 95) begin 
							HuanJingWenDu_8[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 96) begin 
							HuanJingWenDu_8[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 97) begin 
							HuanJingWenDu_9[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 98) begin 
							HuanJingWenDu_9[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 99) begin 
							HuanJingWenDu_10[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 100) begin 
							HuanJingWenDu_10[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end
						else if(rx_count == 101) begin 
							JiGuangCeJu_1[31:24] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 102) begin 
							JiGuangCeJu_1[23:16] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 103) begin 
							JiGuangCeJu_1[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 104) begin 
							JiGuangCeJu_1[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 105) begin 
							JiGuangCeJu_2[31:24] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 106) begin 
							JiGuangCeJu_2[23:16] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 107) begin 
							JiGuangCeJu_2[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 108) begin 
							JiGuangCeJu_2[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 109) begin 
							JiGuangCeJu_3[31:24] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 110) begin 
							JiGuangCeJu_3[23:16] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 111) begin 
							JiGuangCeJu_3[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 112) begin 
							JiGuangCeJu_3[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 113) begin 
							JiGuangCeJu_4[23:16] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 114) begin 
							JiGuangCeJu_4[15:8] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
						else if(rx_count == 115) begin 
							JiGuangCeJu_4[7:0] <= rx_data; 
							crc_rcv <= crc_rcv + rx_data; 
						end 
                        if (rx_count == 116) begin						
                            RCV_Parity[7:0] <= rx_data;
                            if (crc_rcv[7:0] == rx_data) begin
                                rx_count <= 0;
                                crc_rcv <= 0;
                                crc_err <= 0;
                                receive_fsm <= 0;
                            end 
                            else begin
                                receive_fsm <= 0;
                                rx_count <= 0;
                                crc_num <= crc_num + 1;
                                crc_rcv <= 0;
                                crc_err <= 1;
                            end 
                        end 
                    end // end case 11
    
    				12: begin
    					receive_fsm <= 0;
                        crc_num <= 0;
    					rx_count <= 0;
    				end //end case 12
    				
    				default: begin
    					receive_fsm <= 0;
    					rx_count <= 0;
    				end //end default
    			endcase //end case
    		end //end if
    
    		if (get_data) begin
    			get_data <= 0;
    		end //end if

    	end //end if
		    
        
		if (flag_cmd_send == 1'b1) begin
			if (package_type == 8'h03) begin
				tx_count <= tx_count + 1'b1;
				if (tx_count == 0) begin				//帧头, MSB
					send_data[0] <= 8'hAF;
				end //end if
				else if (tx_count == 1) begin			//帧头, LSB
					send_data[1] <= 8'h05;
				end //end else if
                else if (tx_count == 2) begin			//设备标识, MSB
					send_data[2] <= 8'hFF;
				end //end else if
                else if (tx_count == 3) begin			//设备标识, LSB
					send_data[3] <= 8'h04;
				end //end else if
                else if (tx_count == 4) begin			//包类型
					send_data[4] <= 8'h05;
					crc_send <= {8'h00, 8'h00};
				end //end else if
				else if (tx_count == 5) begin			//包长度
					send_data[5] <= 8'h1C;
					crc_send <= crc_send + 8'h1c;
				end //end else if
				else if (tx_count == 6) begin			//成像周期，MSB
					send_data[6] <= ChengXiangZhouQi[15:8];
					crc_send <= crc_send + ChengXiangZhouQi[15:8];
				end //end else if
				else if (tx_count == 7) begin			//成像周期，LSB
					send_data[7] <= ChengXiangZhouQi[7:0];
					crc_send <= crc_send + ChengXiangZhouQi[7:0];
				end //end else if
                else if (tx_count == 8) begin			//积分时间, MSB
					send_data[8] <= JiFenShiJian[15:8];
					crc_send <= crc_send + JiFenShiJian[15:8];
				end //end else if
				else if (tx_count == 9) begin			//积分时间, LSB
					send_data[9] <= JiFenShiJian[7:0];
					crc_send <= crc_send + JiFenShiJian[7:0];
				end //end else if
				else if (tx_count == 10) begin			//成像增益
					send_data[10] <= ChengXiangZengYi[7:0];
					crc_send <= crc_send + ChengXiangZengYi[7:0];
				end //end else if
                else if (tx_count == 11) begin			//工作模式
					send_data[11] <= GongZuoMoShi[7:0];
					crc_send <= crc_send + GongZuoMoShi[7:0];
				end //end else if
                else if (tx_count == 12) begin			//合并模式
					send_data[12] <= HeBingMoShi[7:0];
					crc_send <= crc_send + HeBingMoShi[7:0];
				end //end else if
                else if (tx_count == 13) begin			//行，MSB
					send_data[13] <= ROW_NUM [15:8];
					crc_send <= crc_send + ROW_NUM [15:8];
				end //end else if
                else if (tx_count == 14) begin			//行，LSB
					send_data[14] <= ROW_NUM [7:0];
					crc_send <= crc_send + ROW_NUM [7:0];
				end //end else if
                else if (tx_count == 15) begin			//列，MSB
					send_data[15] <= COLUMN_NUM [15:8];
					crc_send <= crc_send + COLUMN_NUM [15:8];
				end //end else if
                else if (tx_count == 16) begin			//列，LSB
					send_data[16] <= COLUMN_NUM [7:0];
					crc_send <= crc_send + COLUMN_NUM [7:0];
				end //end else if
                else if (tx_count == 17) begin			//年
					send_data[17] <= year [7:0];
					crc_send <= crc_send + year [7:0];
				end //end else if 
                else if (tx_count == 18) begin			//月
					send_data[18] <= month [7:0];
					crc_send <= crc_send + month [7:0];
				end //end else if 
                else if (tx_count == 19) begin			//日
					send_data[19] <= date [7:0];
					crc_send <= crc_send + date [7:0];
				end //end else if 
                else if (tx_count == 20) begin			//时
					send_data[20] <= hour [7:0];
					crc_send <= crc_send + hour [7:0];
				end //end else if 
                else if (tx_count == 21) begin			//分
					send_data[21] <= minute [7:0];
					crc_send <= crc_send + minute [7:0];
				end //end else if 
                else if (tx_count == 22) begin			//秒
					send_data[22] <= second_syn [7:0];
					crc_send <= crc_send + second_syn [7:0];
				end //end else if 
                else if (tx_count == 23) begin			//毫秒，MSB
					send_data[23] <= millisecond_syn [15:8];
					crc_send <= crc_send + millisecond_syn [15:8];
				end //end else if 
                else if (tx_count == 24) begin			//毫秒，LSB
					send_data[24] <= millisecond_syn [7:0];
					crc_send <= crc_send + millisecond_syn [7:0];
				end //end else if 
				else if (tx_count == 25) begin			//毫秒，LSB
					send_data[25] <= BeiYong [7:0];
					crc_send <= crc_send + BeiYong [7:0];
				end //end else if 
                else if (tx_count == 26) begin			
					send_data[26] <= crc_num [7:0];
					crc_send <= crc_send + crc_num [7:0];
				end //end else if
				else if (tx_count == 27) begin			//校验码, LSB
					send_data[27] <= crc_send[7:0];
				end //end else if
				else begin
					flag_cmd_send <= 1'b0;
					tx_count <= 0;
					tx_count_length <= 28;
					send_rdy <= 1;
				end //end else
			end //end if

			// else if (package_type == 8'h15) begin
				// tx_count <= tx_count + 1'b1;
				// if (tx_count == 0) begin				//帧头, MSB
					// send_data[0] <= 8'hEB;
				// end //end if
				// else if (tx_count == 1) begin			//帧头, LSB
					// send_data[1] <= 8'h90;
				// end //end else if
				// else if (tx_count == 2) begin			//数据长度, MSB
					// send_data[2] <= 8'h00;
					// crc_send <= {8'h00, 8'h00};
				// end //end else if
				// else if (tx_count == 3) begin			//数据长度, LSB
					// send_data[3] <= 8'h01;
					// crc_send <= crc_send + 8'h01;
				// end //end else if
				// else if (tx_count == 4) begin			//数据类型
					// send_data[4] <= 8'h16;
					// crc_send <= crc_send + 8'h16;
				// end //end else if
				// else if (tx_count == 5) begin			//校验码, MSB
					// send_data[5] <= crc_send[15:8];
				// end //end else if
				// else if (tx_count == 6) begin			//校验码, LSB
					// send_data[6] <= crc_send[7:0];
				// end //end else if
				// else if (tx_count == 7) begin			//帧尾, MSB
					// send_data[7] <= 8'h09;
				// end //end else if
				// else if (tx_count == 8) begin			//帧尾, LSB
					// send_data[8] <= 8'hD7;
				// end //end else if
				// else begin
					// flag_cmd_send <= 1'b0;
					// tx_count <= 0;
					// tx_count_length <= 9;
					// send_rdy <= 1;
				// end //end else
			// end //end else if

			// else if (package_type == 8'h21) begin
				// tx_count <= tx_count + 1'b1;
				// if (tx_count == 0) begin				//帧头, MSB
					// send_data[0] <= 8'hEB;
				// end //end if
				// else if (tx_count == 1) begin			//帧头, LSB
					// send_data[1] <= 8'h90;
				// end //end else if
				// else if (tx_count == 2) begin			//数据长度, MSB
					// send_data[2] <= 8'h00;
					// crc_send <= {8'h00, 8'h00};
				// end //end else if
				// else if (tx_count == 3) begin			//数据长度, LSB
					// send_data[3] <= 8'h04;
					// crc_send <= crc_send + 8'h04;
				// end //end else if
				// else if (tx_count == 4) begin			//数据类型
					// send_data[4] <= 8'h21;
					// crc_send <= crc_send + 8'h21;
				// end //end else if
				// else if (tx_count == 5) begin			//指令类型
					// send_data[5] <= cmd_type;
					// crc_send <= crc_send + cmd_type;
				// end //end else if
				// else if (tx_count == 6) begin			//指令数据, MSB
					// send_data[6] <= cmd_value[15:8];
					// crc_send <= crc_send + cmd_value[15:8];
				// end //end else if
				// else if (tx_count == 7) begin			//指令数据, LSB
					// send_data[7] <= cmd_value[7:0];
					// crc_send <= crc_send + cmd_value[7:0];
				// end //end else if
				// else if (tx_count == 8) begin			//校验码, MSB
					// send_data[8] <= crc_send[15:8];
				// end //end else if
				// else if (tx_count == 9) begin			//校验码, LSB
					// send_data[9] <= crc_send[7:0];
				// end //end else if
				// else if (tx_count == 10) begin			//帧尾, MSB
					// send_data[10] <= 8'h09;
				// end //end else if
				// else if (tx_count == 11) begin			//帧尾, LSB
					// send_data[11] <= 8'hD7;
				// end //end else if
				// else begin
					// flag_cmd_send <= 1'b0;
					// tx_count <= 0;
					// tx_count_length <= 12;
					// send_rdy <= 1;
				// end //end else if
		end //end if

		// end //end if
		
		if (send_rdy) begin
			send_rdy <= 0;
		end //end if

		if (cmd_update) begin
			if (delay) begin
				cmd_update <= 0;
				package_en <= 0;
				delay <= 0;
			end //end if
			else begin
				package_en <= 1;
				delay <= 1;
			end //end else
		end //end if

		if (time_update) begin
			time_update <= 1'b0;
		 end //end if
	end
end //end always


/////////////////////driver_en///////////////////////
assign	O_driver_en = driver_en;

always @(posedge I_clk) begin
	if (!I_rst) begin
		driver_en <= 0;
	end
	else if (image_ctrl_last == 8'h5F) begin
		driver_en <= 1;
	end
	else if (image_ctrl_last == 8'hF5) begin
		driver_en <= 0;
	end
	else begin
	    driver_en <= driver_en;
    end
end
/* 
/////////////////////RS485 control///////////////////////
//reg flag_tx_delay;
//reg [31:0] cnt_tx_delay;
always @(posedge I_clk) begin
	if (!I_rst) begin
		tx_en <= 1;
		rx_en <= 0;		 		//after reset ,enter receive mode
		sw_fsm <= 0;
		//flag_tx_delay <= 0;
		//cnt_tx_delay <= 0;
	end //end if
	else begin
		case (sw_fsm)
			0: begin
				if (cmd_update) begin
					if (package_en) begin					//change into send mode
						sw_fsm <= 1;
					end //end if
				end //end if
			end //end case 0
			1: begin
				//cnt_tx_delay <= cnt_tx_delay + 1;
				//if (cnt_tx_delay == 799_9999) begin		//delay 100ms
					//cnt_tx_delay <= 0;
					sw_fsm <= 2;
					tx_en <= 0;
					rx_en <= 1;
				//end //end if
			end //end case 1
			2: begin
				if (send_finish) begin
					tx_en <= 1;
					rx_en <= 0;
					sw_fsm <= 0;
				end //end if
			end //end case 2
			default: begin
				sw_fsm <= 0;
			end //end default
		endcase //end case
	end //end else
end	 //end always
//*/
//////////////////tx_process/////////////////////
reg         tx_frame_busy;       // 正在发送一帧
reg [15:0]  tx_byte_gap_cnt;     // 字节间隔计数器

always @(posedge I_clk) begin
	if (!I_rst) begin
		tx_data <= 0;
		send_cnt <= 0;
		send_en <= 0;
		send_finish <= 0;
		send_fsm <= 0;
		tx_en <= 0;

		tx_frame_busy   <= 1'b0;
        tx_byte_gap_cnt <= 16'd0;

	end //end if
	else begin

		if (tx_frame_busy) begin
            tx_byte_gap_cnt <= tx_byte_gap_cnt + 1'b1;
        end
        else begin
            tx_byte_gap_cnt <= 16'd0;
        end

		case (send_fsm)
			0: begin
				send_finish <= 0;
				if (send_rdy) begin
					send_fsm <= 1;	
					send_cnt <= 0;
					// tx_en <= 1;

					tx_frame_busy <= 1'b1;  // 标记一帧开始
                    tx_byte_gap_cnt <= 16'd0;
				end //end if
				
			end //end case 0
			1: begin
				//if (cnt_tx_delay == 799_9999) begin
				    tx_en <= 1;
					send_fsm <= 2;
					// tx_en <= 1;
				//end //end if
			end //end case 1
			2: begin
				if (tx_byte_gap_cnt >= 30000 ) begin  // 帧内字节超过 3us 未发下一个强制结束
                    send_fsm    <= 3;
                    send_finish <= 1'b1;
                    tx_frame_busy <= 1'b0;
                end
				else if (txclk_sample == 2'b10) begin
					if (send_cnt < tx_count_length) begin
						if (!tx_busy) begin
							tx_data <= 	send_data[send_cnt];
							send_cnt <= send_cnt + 1;
							send_en <= 1;
							tx_byte_gap_cnt <= 16'd0;
						end //end if
					end //end if
					else begin
						if (!tx_busy) begin
							send_fsm <= 3;	
							send_finish <= 1;
							send_cnt <= 0;
						end //end if
					end //end else
					if (send_en) begin
						send_en <= 0;
					end //end if
				end //end if

			end //end case 2
			3: begin
				send_fsm <= 0;	
				send_finish <= 0;
				tx_en <= 0;
				tx_frame_busy <= 1'b0;
			end //end case 2
			default: begin
				send_fsm <= 0;
			end //end default
		endcase //end case
	end //end else
end //end always

/* ila_422 ila_422 (
	.clk(I_clk), // input wire clk

	.probe0(image_ctrl_last), // input wire [7:0]  probe0 
	.probe1(driver_en), // input wire [0:0]  probe1
	.probe2(crc_rcv), // input wire [15:0]  probe2
	.probe3(receive_fsm), // input wire [6:0]  probe3
	.probe4(rx_count) // input wire [5:0]  probe3
); */

endmodule