`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: SITP
// Engineer: He Daogang
// 
// Create Date:    11:09:29 08/03/2014 
// Design Name:    HSTA
// Module Name:    dcm 
// Project Name:   FPGA Send module
// Target Devices: XC6SLX75-2FGG484
// Tool versions:  ISE 13.2
// Description: 
//
// Dependencies: 
//
// Revision: V0.01
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module camlink_send(
	input 				I_clk,				//8MHz
	input 				I_rst, 
	input	[4:1] 		I_dip_sts, 
	input				I_cl_clk, 
	input	[7:0]		I_devid, 
	input 				I_sample_rdy,
	input [543:0] 		I_mc_data,
	input [151:0]       I_cam_data,
	input [79:0]        I_time,
	input [15:0] 		I_sample_data,
	input I_data_en,
	output reg [9:0] 	O_addr_rd,
	output reg 			O_frame_start,
	output reg 			O_rd_finish, 
	output				O_txclkout, 
	output	reg 		O_pwr_down, 
	output	reg			O_fval, 
	output	reg 		O_lval, 
	output	reg 		O_dval, 
	output	reg 		O_space, 
	output	[23:0]  	O_txout
	);
localparam ROW = 513;//one assist line
localparam COLUNM = 640;

reg [3:0] send_fsm;
reg [15:0] cnt_row;
reg [15:0] cnt_pixel;
reg	[15:0] send_data;
reg sim_en;
reg [15:0] data_sim;       /// for simulate
reg [31:0] real_frame_num;
reg [15:0] sim_frame_num;
reg [15:0] crc_send;
reg assist_en;
reg [1:0] sample_data_en;
assign O_txout[23:0] = {8'b0000_0000, send_data[15:0]};

reg [1:0] sample_rdy_sample;
always@(posedge I_cl_clk) begin
	if(!I_rst) begin
		sample_rdy_sample <= 0;
		sample_data_en <= 0;
	end
	else begin
		sample_rdy_sample[0] <= I_sample_rdy;
		sample_rdy_sample[1] <= sample_rdy_sample[0];     //sample sample rdy

		sample_data_en[0] <= I_data_en;
		sample_data_en[1] <= sample_data_en[0];
	end 
end //end always

reg [2:0] head_data_state;
reg [9:0] head_data_state2;
reg [543:0] mc_data;
reg [79:0]  cam_time;
reg [9:0] tx_data_num; 
reg [9:0] tx_data_num2;
assign O_txclkout = I_cl_clk;
reg [15:0] package_data [149:0];
reg O_rd_finish_flag;
reg	[7:0] cnt_delay;
reg [31:0] cnt_frame;
always @(posedge I_cl_clk) begin
	if(!I_rst) begin
		O_pwr_down <= 0;
		O_fval <= 0;
		O_lval <= 0;
		O_dval <= 0;
		O_space <= 0;
		//O_txclkout <= 0;
		send_data <= 0;
		O_frame_start <= 0;
		cnt_pixel <= 0;
		cnt_row <= 0;
		O_addr_rd <= 0;
		O_rd_finish <= 0;
		data_sim <= 0;
		O_rd_finish_flag <= 0;
		cnt_delay <= 0;
		cnt_frame <= 0;
		sim_en <= 0;
		assist_en <= 0;
		head_data_state <= 0;
		head_data_state2 <= 0;
		real_frame_num <= 0;
		sim_frame_num <= 0;
		crc_send <= 0;
		mc_data <= 0;
		cam_time <= 0;
		tx_data_num <= 1'b1;
		tx_data_num2 <= 0;

		package_data[0] <= 0;
		package_data[1] <= 0;
		package_data[2] <= 0;
		package_data[3] <= 0;
		package_data[4] <= 0;
		package_data[5] <= 0;
		package_data[6] <= 0;
		package_data[7] <= 0;
		package_data[8] <= 0;
		package_data[9] <= 0;
		package_data[10] <= 0;
		package_data[11] <= 0;
		package_data[12] <= 0;
		package_data[13] <= 0;
		package_data[14] <= 0;
		package_data[15] <= 0;
		package_data[16] <= 0;
		package_data[17] <= 0;
		package_data[18] <= 0;
		package_data[19] <= 0;
		package_data[20] <= 0;
		package_data[21] <= 0;
		package_data[22] <= 0;
		package_data[23] <= 0;
		package_data[24] <= 0;
		package_data[25] <= 0;
		package_data[26] <= 0;
		package_data[27] <= 0;
		package_data[28] <= 0;
		package_data[29] <= 0;
		package_data[30] <= 0;
		package_data[31] <= 0;
		package_data[32] <= 0;
		package_data[33] <= 0;
		package_data[34] <= 0;
		package_data[35] <= 0;
		package_data[36] <= 0;
		package_data[37] <= 0;
		package_data[38] <= 0;
		package_data[39] <= 0;
		package_data[40] <= 0;
		package_data[41] <= 0;
		package_data[42] <= 0;
		package_data[43] <= 0;
		package_data[44] <= 0;
		package_data[45] <= 0;
		package_data[46] <= 0;
		package_data[47] <= 0;
		package_data[48] <= 0;
		package_data[49] <= 0;
		package_data[50] <= 0;
		package_data[51] <= 0;
		package_data[52] <= 0;
		package_data[53] <= 0;
		package_data[54] <= 0;
		package_data[55] <= 0;
		package_data[56] <= 0;
		package_data[57] <= 0;
		package_data[58] <= 0;
		package_data[59] <= 0;
		package_data[60] <= 0;
		package_data[61] <= 0;
		package_data[62] <= 0;
		package_data[63] <= 0;
		package_data[64] <= 0;
		package_data[65] <= 0;
		package_data[66] <= 0;
		package_data[67] <= 0;
		package_data[68] <= 0;
		package_data[69] <= 0;
		package_data[70] <= 0;
		package_data[71] <= 0;
		package_data[72] <= 0;
		package_data[73] <= 0;
		package_data[74] <= 0;
		package_data[75] <= 0;
		package_data[76] <= 0;
		package_data[77] <= 0;
		package_data[78] <= 0;
		package_data[79] <= 0;
		package_data[80] <= 0;
		package_data[81] <= 0;
		package_data[82] <= 0;
		package_data[83] <= 0;
		package_data[84] <= 0;
		package_data[85] <= 0;
		package_data[86] <= 0;
		package_data[87] <= 0;
		package_data[88] <= 0;
		package_data[89] <= 0;
		package_data[90] <= 0;
		package_data[91] <= 0;
		package_data[92] <= 0;
		package_data[93] <= 0;
		package_data[94] <= 0;
		package_data[95] <= 0;
		package_data[96] <= 0;
		package_data[97] <= 0;
		package_data[98] <= 0;
		package_data[99] <= 0;
		package_data[100] <= 0;
		package_data[101] <= 0;
		package_data[102] <= 0;
		package_data[103] <= 0;
		package_data[104] <= 0;
		package_data[105] <= 0;
		package_data[106] <= 0;
		package_data[107] <= 0;
		package_data[108] <= 0;
		package_data[109] <= 0;
		package_data[110] <= 0;
		package_data[111] <= 0;
		package_data[112] <= 0;
		package_data[113] <= 0;
		package_data[114] <= 0;
		package_data[115] <= 0;
		package_data[116] <= 0;
		package_data[117] <= 0;
		package_data[118] <= 0;
		package_data[119] <= 0;
		package_data[120] <= 0;
		package_data[121] <= 0;
		package_data[122] <= 0;
		package_data[123] <= 0;
		package_data[124] <= 0;
		package_data[125] <= 0;
		package_data[126] <= 0;
		package_data[127] <= 0;
		package_data[128] <= 0;
		package_data[129] <= 0;
		package_data[130] <= 0;
		package_data[131] <= 0;
		package_data[132] <= 0;
		package_data[133] <= 0;
		package_data[134] <= 0;
		package_data[135] <= 0;
		package_data[136] <= 0;
		package_data[137] <= 0;
		package_data[138] <= 0;
		package_data[139] <= 0;
		package_data[140] <= 0;
		package_data[141] <= 0;
		package_data[142] <= 0;
		package_data[143] <= 0;
		package_data[144] <= 0;
		package_data[145] <= 0;
		package_data[146] <= 0;
		package_data[147] <= 0;
		package_data[148] <= 0;
		package_data[149] <= 0;

	end
	else begin
		O_pwr_down <= 1;
		
		//if (I_cl_clk_sample == 2'b01) begin
			//O_txclkout <= 1;
		//end //end if
		//else if (I_cl_clk_sample == 2'b10) begin
			//O_txclkout <= 0;
		//end //end elseif
		
		// cnt_frame <= cnt_frame + 1;		
		
		case (send_fsm)
			0: begin
				if (I_dip_sts[1]) begin
					sim_en <= 0;
					if (sample_data_en == 2'b11) begin //辅助数据先发送
						O_fval <= 1;
						assist_en <= 1'b1;
						cnt_delay <= 0;
						send_fsm <= 1;
						cnt_frame <= 0;
					end //end if
				end //end if
				else begin
					if (cnt_frame == 39_9999) begin //cnt_frame == 399_9999
						cnt_frame <= 0;
						O_fval <= 1;
						data_sim <= 0;
						cnt_delay <= 0;
						send_fsm <= 1;
						sim_en <= 1;
					end //end if
					else begin
						cnt_frame <= cnt_frame + 1;	
					end
				end //end else
			end //end case 0
			
			1: begin
				//if (I_cl_clk_sample == 2'b10) begin
					cnt_delay <= cnt_delay + 1;
					if (cnt_delay == 12) begin
						cnt_delay <= 0;
						cnt_pixel <= 0;
						cnt_row <= 0;
						cam_time <= I_time;
						mc_data <= I_mc_data;
						send_fsm <= 2;

						package_data[0] <= {8'h0,cam_time[79:72]};
						package_data[1] <= {8'h0,cam_time[71:64]};
						package_data[2] <= {8'h0,cam_time[63:56]};
						package_data[3] <= {8'h0,cam_time[55:48]};
						package_data[4] <= {8'h0,cam_time[47:40]};
						package_data[5] <= {8'h0,cam_time[39:32]};
						package_data[6] <= {8'h0,cam_time[31:24]};
						package_data[7] <= {8'h0,cam_time[23:16]};
						package_data[8] <= 0;//冗余
						package_data[9] <= 0;
						package_data[10] <= 0;
						package_data[11] <= 0;
						package_data[12] <= 0;
						package_data[13] <= 0;
						package_data[14] <= 0;
						package_data[15] <= 0;
						package_data[16] <= 0;
						package_data[17] <= 0;
						package_data[18] <= 0;
						package_data[19] <= 0;
						package_data[20] <= 0;
						package_data[21] <= 0;
						package_data[22] <= 0;
						package_data[23] <= 0;
						package_data[24] <= 0;
						package_data[25] <= 0;
						package_data[26] <= 0;
						package_data[27] <= 0;
						package_data[28] <= 0;
						package_data[29] <= 0;
						package_data[30] <= 0;
						package_data[31] <= 0;
						package_data[32] <= 0;
						package_data[33] <= 0;
						package_data[34] <= 0;
						package_data[35] <= 0;
						package_data[36] <= 0;
						package_data[37] <= 0;
						package_data[38] <= 0;
						package_data[39] <= 0;//冗余
						package_data[40] <= I_mc_data[543:528];//扫描角时间
						package_data[41] <= I_mc_data[527:512];
						package_data[42] <= I_mc_data[511:496];
						package_data[43] <= I_mc_data[495:480];
						package_data[44] <= I_mc_data[479:464];//扫描角
						package_data[45] <= I_mc_data[463:448];
						package_data[46] <= I_mc_data[447:432];
						package_data[47] <= I_mc_data[431:416];//扫描角
						package_data[48] <= I_mc_data[415:400];//电机状态
						package_data[49] <= I_mc_data[399:384];//二路温度点
						package_data[50] <= I_mc_data[383:368];
						package_data[51] <= I_mc_data[367:352];
						package_data[52] <= I_mc_data[351:336];
						package_data[53] <= I_mc_data[335:320];
						package_data[54] <= I_mc_data[319:304];
						package_data[55] <= I_mc_data[303:288];
						package_data[56] <= I_mc_data[287:272];
						package_data[57] <= I_mc_data[271:256];
						package_data[58] <= I_mc_data[255:240];
						package_data[59] <= I_mc_data[239:224];
						package_data[60] <= I_mc_data[223:208];
						package_data[61] <= I_mc_data[207:192];
						package_data[62] <= I_mc_data[191:176];
						package_data[63] <= I_mc_data[175:160];
						package_data[64] <= I_mc_data[159:144];
						package_data[65] <= I_mc_data[143:128];
						package_data[66] <= I_mc_data[127:112];
						package_data[67] <= I_mc_data[111:96];
						package_data[68] <= I_mc_data[95:80];
						package_data[69] <= I_mc_data[79:64];
						package_data[70] <= I_mc_data[63:48];
						package_data[71] <= I_mc_data[47:32];
						package_data[72] <= I_mc_data[31:16];
						package_data[73] <= I_mc_data[15:0];
						package_data[74] <= 0;
						package_data[75] <= 16'h0003;
						package_data[76] <= 0;
						package_data[77] <= I_cam_data[151:136];
						package_data[78] <= {8'h0,I_cam_data[135:128]};//成像增益
						package_data[79] <= 0;//成像周期
						package_data[80] <= I_cam_data[127:112];//成像周期
						package_data[81] <= 0;
						package_data[82] <= I_cam_data[111:96];
						package_data[83] <= 0;
						package_data[84] <= I_cam_data[95:80];
						package_data[85] <= {8'h0,I_cam_data[79:72]};
						package_data[86] <= {8'h0,I_cam_data[71:64]};
						package_data[87] <= 0;
						package_data[88] <= 0;
						package_data[89] <= 0;
						package_data[90] <= 0;
						package_data[91] <= 0;
						package_data[92] <= 0;
						package_data[93] <= 0;
						package_data[94] <= 0;
						package_data[95] <= 0;
						package_data[96] <= 0;
						package_data[97] <= 0;
						package_data[98] <= 0;
						package_data[99] <= 0;
						package_data[100] <= 0;
						package_data[101] <= 0;
						package_data[102] <= 0;
						package_data[103] <= 0;
						package_data[104] <= 0;
						package_data[105] <= 0;
						package_data[106] <= 0;
						package_data[107] <= 0;
						package_data[108] <= 0;
						package_data[109] <= 0;
						package_data[110] <= 0;
						package_data[111] <= 0;
						package_data[112] <= 0;
						package_data[113] <= 0;
						package_data[114] <= 0;
						package_data[115] <= 0;
						package_data[116] <= 0;
						package_data[117] <= 0;
						package_data[118] <= 0;
						package_data[119] <= 0;
						package_data[120] <= 0;
						package_data[121] <= 0;
						package_data[122] <= 0;
						package_data[123] <= I_cam_data[63:48];
						package_data[124] <= 0;
						package_data[125] <= I_cam_data[47:32];
						package_data[126] <= 0;
						package_data[127] <= I_cam_data[31:16];
						package_data[128] <= 0;
						package_data[129] <= I_cam_data[15:0];
						package_data[130] <= 0;
						package_data[131] <= 0;
						package_data[132] <= 0;
						package_data[133] <= 0;
						package_data[134] <= 0;
						package_data[135] <= 0;
						package_data[136] <= {8'h0,I_time[15:8]};
						package_data[137] <= {8'h0,I_time[7:0]};
						package_data[138] <= 0;
						package_data[139] <= 0;
						package_data[140] <= real_frame_num[31:16];
						package_data[141] <= real_frame_num[15:0];
						package_data[142] <= 16'h1234;//版本号
					end //end if
				//end //end if
			end //end case 1
			
			2: begin
				//if (I_cl_clk_sample == 2'b10) begin
					if (cnt_row == ROW) begin
						send_data <= 0;
						O_fval <= 0;
						O_lval <= 0;
						O_dval <= 0;
						send_fsm <= 0;
						if(sim_en) begin
							sim_frame_num <= sim_frame_num + 1'b1;
						end
						else begin
							real_frame_num <= real_frame_num + 1'b1;
						end
					end //end if
					else begin
						cnt_pixel <= 0;
						O_addr_rd <= 0;
						O_rd_finish <= 0;
						crc_send <= 0;
						tx_data_num <= 1'b1;
						if ((sim_en || assist_en) || (sample_rdy_sample == 2'b11)) begin //I_sample_rdy) begin
							send_fsm <= 3;
						end //end if
					end //end else
				//end //end if
			end //end case 2
			//固定头部
			3: begin
				O_lval <= 1;
				O_dval <= 1;
				tx_data_num <= tx_data_num + 1'b1;
				case (head_data_state)
					3'd0: begin
						send_data <= 16'hfdfd;
						crc_send <= crc_send + 16'hfdfd;
						head_data_state <= 3'd1;
					end 
					3'd1: begin
						send_data <= 16'h7f7f;
						crc_send <= crc_send + 16'h7f7f;
						head_data_state <= 3'd2;
					end
					3'd2: begin
						send_data <= 16'h7f7f;
						crc_send <= crc_send + 16'h7f7f;
						head_data_state <= 3'd3;
					end
					3'd3: begin//包长度
						send_data <= 16'd640;
						crc_send <= crc_send + 16'h640;
						head_data_state <= 3'd4;
					end
					3'd4: begin
						send_data <= 16'haa20;
						crc_send <= crc_send + 16'haa20;
						head_data_state <= 3'd5;
					end
					3'd5: begin//帧号
						if(sim_en) begin
							send_data <= sim_frame_num;
							crc_send <= crc_send + sim_frame_num;
						end
						else begin
							if(sim_en) begin
								send_data <= sim_frame_num;
								crc_send <= crc_send + real_frame_num;
							end
							else begin
								send_data <= real_frame_num[15:0];
								crc_send <= crc_send + real_frame_num;
							end
						end
						head_data_state <= 3'd6;
					end
					3'd6: begin//行号
						send_data <= cnt_row;
						crc_send <= crc_send + cnt_row;
						tx_data_num2 <= 0;
						head_data_state <= 3'd0;
						data_sim <= 0;
						if(cnt_row == 0) begin//跳到输出辅助数据行
							send_fsm <= 4;
							tx_data_num2 <= 0;
							head_data_state2 <= 0;
						end
						else begin
							send_fsm <= 5;
						end
					end
					default: begin
						head_data_state <= 0;
					end
				endcase
			end
			4: begin//辅助行
				O_lval <= 1;
				O_dval <= 1;
				tx_data_num <= tx_data_num + 1'b1;
				tx_data_num2 <= tx_data_num2 + 1'b1;
				send_data <= package_data[tx_data_num2];//日内秒8 低八位有效 
				crc_send <= crc_send  + package_data[tx_data_num2];
				case (head_data_state2) 
					0: begin
						send_data <= package_data[tx_data_num2]; 
						crc_send <= crc_send  + package_data[tx_data_num2];
						if(tx_data_num == 149) begin
							head_data_state2 <= 1;
						end
					end 
					1: begin
						send_data <= 16'ha501;//光谱冗余 + 备用
						crc_send <= crc_send  + 16'ha501;
						if(tx_data_num == 646) begin
                        	head_data_state2 <= 2;
						end
					end 
					2: begin
						send_data <= package_data[142];//版本号
						crc_send <= crc_send  + package_data[142];
                        head_data_state2 <= 3;
					end 
					3: begin
						send_data <= crc_send;//校验和
                        head_data_state2 <= 0;
						assist_en <= 0;
						send_fsm <= 6;
					end 
					default: begin
						head_data_state2 <= 0;
					end
				endcase
			end
			5: begin
				//if (I_cl_clk_sample == 2'b10) begin
				tx_data_num <= tx_data_num + 1'b1;
					if (cnt_pixel == COLUNM) begin
						cnt_pixel <= 0;
						send_data <= crc_send;
						O_rd_finish <= 1;
						send_fsm <= 6;
					end //end if
					else begin
						O_lval <= 1;
						O_dval <= 1;
						cnt_pixel <= cnt_pixel + 1;
						O_addr_rd <= O_addr_rd + 1;
						if (!sim_en) begin
							send_data <= I_sample_data;
							crc_send <= crc_send + I_sample_data;
						end //end if
						else begin
							data_sim <= data_sim + 1;		//only for simulator
							send_data <= data_sim;
							crc_send <= crc_send + data_sim;
						end //end else
					end //end else
				//end //end if
			end //end case 3
			
			6: begin
				cnt_delay <= cnt_delay + 1;
				if (cnt_delay == 7) begin
					cnt_delay <= 0;
					cnt_row <= cnt_row + 1;
					send_fsm <= 2;
				end //end if
				else begin
					O_lval <= 0;
					O_dval <= 0;
				end
			end //end case 4
			
			default: begin
				send_fsm <= 0;
			end //end default
		endcase //end case
	end
end

endmodule
