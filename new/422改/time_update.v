`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: SITP
// Engineer: He Daogang
// 
// Create Date:    11:09:29 08/03/2014 
// Design Name:    HSTA
// Module Name:    dcm 
// Project Name:   FPGA Send module
// Target Devices: XC6SLX72-2FGG484
// Tool versions:  ISE 13.1
// Description: 
//
// Dependencies: 
//
// Revision: V0.01
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module time_update(
	input	I_clk, 
	input	I_rst, 

	input	I_time_update, 
	input	I_zk_pps, 
	// input	[7:0] I_year,
	// input	[7:0] I_month,
	// input	[7:0] I_date,
	input	[7:0] I_second,
	input	[15:0] I_millisecond,
	// output	reg [7:0] O_year,
	// output	reg [7:0] O_month,
	// output	reg [7:0] O_date,
    output reg [7:0] O_second,
	output reg [15:0] O_millisecond,
	//output	[15:0] O_us_count,
	output	reg O_time_update_busy
	// input	I_delay_en,
	// input	[15:0] I_delay_param,
	// output	reg [15:0] O_delay_time,
	// input [7:0]	I_image_ctrl,
	//input	I_driver_off,
    //input   clkgtx,
	// output	reg O_driver_en
   // output  [79:0] O_timecode

	);

//reg [7:0] O_minute;

reg [3:0]  us100_cnt;

reg [15:0] us_count;
reg [15:0] clk_count;
reg [1:0] pps_sample;
reg [1:0] time_fsm;
reg pps_ready;
reg [19:0] count;
reg [1:0] remove_jitter_fsm;
reg [15:0]  temp_ms_offset;    // 1PPS触发时的毫秒偏移
reg [15:0] temp_us_count;
reg [15:0] temp_clk_count;
reg [1:0] us_fsm;
//reg [15:0] delay_para;
// //time_fifo
// time_fifo U_time_fifo (
//   .rst(!I_rst),                  // input wire rst
//   .wr_clk(I_clk),            // input wire wr_clk
//   .rd_clk(clkgtx),            // input wire rd_clk
//   .din({O_second,us_count}),                  // input wire [79 : 0] din
//   .wr_en(1'b1),              // input wire wr_en
//   .rd_en(!empty),              // input wire rd_en
//   .dout(O_timecode),                // output wire [79 : 0] dout
//   .empty(empty)             // output wire empty
// );

///////////////////////////////////////////////////////////////////////////////////////////////////////	
always @(posedge I_clk) begin
	if (!I_rst) begin
		pps_sample <= 0;	
	end //end if
	else begin
		pps_sample[0] <= I_zk_pps;
		pps_sample[1] <= pps_sample[0];	
	end	 //end else
end //end always
	
always @(posedge I_clk) begin
	if (!I_rst) begin
		count <= 0;
		pps_ready <= 0;
		remove_jitter_fsm <= 0;
	end //end if
	else begin
		case (remove_jitter_fsm)
			0: begin
				if (pps_sample == 2'b10)begin
					remove_jitter_fsm <= 1;
				end //end if
			end  //end case 0
			1: begin
				//if (count == 20'h13880)begin           //1ms
				if (count == 19999)begin           //200us
					if (pps_sample == 2'b00)begin
						count <= count + 1;
						remove_jitter_fsm <= 2;
					end //end if
					else begin
						count <= 0;
						remove_jitter_fsm <= 0;
					end //end else
				end //end if
				else begin
					count <= count + 1;
				end //end else
			end //end case 1
			2: begin
				//if (count == 20'h61a80)begin           //5ms
				if (count == 59999)begin           //600us
					if (pps_sample == 2'b00)begin
						count <= 0;
						remove_jitter_fsm <= 3;
						pps_ready <= 1;
					end //end if
					else begin
						count <= 0;
						remove_jitter_fsm <= 0;
					end //end else
				end //end if
				else begin
					count <= count + 1;
				end //end else
			end //end case 2
			3: begin
				pps_ready <= 0;
				remove_jitter_fsm <= 0;
			end //end case 3

			default: begin
				remove_jitter_fsm <= 0;
			end
		endcase //end case
	end //end else
end //end always
	
always @(posedge I_clk) begin
	if (!I_rst) begin
		// temp_us_count <= 0;
		temp_ms_offset <= 0;
		temp_clk_count <= 0;
		us_fsm <= 0;
	end
	else begin
		case (us_fsm)
			0: begin
				if (pps_sample == 2'b10)begin
					us_fsm <= 1;
                    temp_ms_offset <= 0;
					// temp_us_count <= 0;
					temp_clk_count <= 0;
				end //end if
			end //end case 0
			1: begin
				if (pps_ready )begin
					us_fsm <= 2;
				end //end if
				else begin
					if (temp_clk_count == 16'd9999) begin		//100us
						temp_clk_count <= 0;
						temp_ms_offset <= temp_ms_offset + 1;
					end //end if
					else begin
						temp_clk_count <= temp_clk_count + 1;
					end //end else
				end //end else
			end //end case 1
			2: begin
				//temp_us_count <= 0;
				//temp_clk_count <= 0;
				us_fsm <= 0;
			end //end case 2
			default: begin
				//temp_us_count <= 0;
				//temp_clk_count <= 0;	
				us_fsm <= 0;
			end //end default
		endcase //end case
	end //end else
end //end always

////////////////////////////////////////////////////////////////////////
// always @(posedge I_clk) begin
// 	if (!I_rst) begin
// 		O_year <= 2026;
// 		O_month <= 1;
// 		O_date <= 20;	
// 	end //end if
// 	else begin	
// 		if (I_time_update) begin
// 			O_year <= I_year;
// 			O_month <= I_month;
// 			O_date <= I_date;
// 		end //end if
// 	end //end else
// end //end always

always @(posedge I_clk) begin     // calculate second and 100us
	if (!I_rst) begin
		O_second <= 0;
	    O_millisecond <= 0;
		// us_count <= 0;
		us100_cnt <= 0; 
		clk_count <= 0;
		O_time_update_busy <= 0;
	end //end if
	else begin
		if (I_time_update) begin
			O_second <= I_second;
            O_millisecond <= I_millisecond;
		end //end if
		else if (pps_ready) begin
			// us_count <= temp_us_count;
			// O_second <= O_second + 1'b1;
			O_second <= (O_second >= 8'd59) ? 8'd0 : (O_second + 1'b1);
            O_millisecond <= temp_ms_offset;         // 对应1pps毫秒偏移
			clk_count <= temp_clk_count;
			O_time_update_busy <= 1;
		end	 //end else if	
		else begin	
			 if (clk_count >= 16'd9999) begin // 100μs
                clk_count <= 0;
				us100_cnt <= us100_cnt + 1'b1; 
               if(us100_cnt >= 4'd9) begin // 0~9累计10次=1ms
                    us100_cnt <= 0;         // 重置100μs计数器
                    O_millisecond <= O_millisecond + 1'b1;
                    if(O_millisecond >= 16'd999) begin
                        O_millisecond <= 16'd0;
                        O_second <= (O_second >= 8'd59) ? 8'd0 : (O_second + 1'b1);
                    end
                end
				end	else begin
                clk_count <= clk_count + 1'b1; // 时钟计数+1
            end
        end
		// 	if (clk_count >= 16'h1f40) begin			//100us
		// 		clk_count <= 0;
		// 		if (us_count >= 16'h2710) begin			//1s
		// 			us_count <= 0;
		// 			//O_second <= O_second + 1'b1;
		// 		end //end if
		// 		else begin
		// 			us_count <= us_count + 1'b1;
		// 		end //end else
		// 	end	//end if	
		// 	else  begin
		// 		clk_count <= clk_count + 1'b1;
		// 	end //end else
		// end //end else

		if (O_time_update_busy == 1) begin
			O_time_update_busy <= 0;
		end
	end //end else
end //end always

/////////////////////////////////////////////////
// always @(posedge I_clk) begin
// 	if (!I_rst) begin
// 		O_delay_time <= 0;
// 		delay_para <= 0;
// 	end //end if
// 	else begin
// 		if (I_delay_en) begin
// 			O_delay_time <= I_delay_param;
// 			delay_para <= I_delay_param - 16'h1;
// 			//O_tp <= ~O_tp;
// 		end //end if
// 	end //end else
// end //end always

reg [1:0] driver_en_fsm;
reg driver_off_fsm;
reg [15:0] count1;
reg [15:0] delay_cnt;
	
// always @(posedge I_clk) begin
// 	if (!I_rst) begin
// 		O_driver_en <= 0;
// 		driver_en_fsm <= 0;
// 		driver_off_fsm <= 0;
// 		// count1 <= 0;
// 		// delay_cnt <= 0;
// 	end //end if
// 	else begin
// 		case (driver_en_fsm)                                        //  driver enable
// 			0: begin
// 				O_driver_en <= O_driver_en;
// 				if (I_image_ctrl == 8'h5F) begin
// 					//driver_en_fsm <= 1;
// 					driver_en_fsm <= 1;					//????
// 				end //end if
// 			end //end case 0
// 			/* 1: begin
// 				if (pps_ready) begin          //wait for second pulse
// 					driver_en_fsm <= 2;
// 				end //end if
// 			end //end case 1 */
// 			1: begin
// 				//if (pps_sample == 2'b10) begin       //delay time    ????
// 					//if (delay_para == 0) begin
// 						driver_en_fsm <= 0;
// 						O_driver_en <= 1;
// 					// end //end if
// 					// else begin
// 					// 	if (count1 == 16'h1f40) begin	//100us
// 					// 		count1 <= 0;
// 					// 		if (delay_cnt == delay_para) begin
// 					// 			delay_cnt <= 0;
// 					// 			driver_en_fsm <= 0;
// 					// 			O_driver_en <= 1;
// 					// 		end //end if
// 					// 		else begin
// 					// 			delay_cnt <= delay_cnt + 1;
// 					// 		end //end else
// 					// 	end //end if
// 					// end //end else
// 				//end //end if
// 			end //end case 2
// 			default: begin
// 				driver_en_fsm <= 0;				
// 			end //end default
// 		endcase //end case
			
// 		case (driver_off_fsm)                                           //  close driver enable
// 			0: begin
// 				O_driver_en <= O_driver_en;
// 				if (I_image_ctrl == 8'hF5) begin
// 					driver_off_fsm <= 1;
// 				end //end if
// 			end //end case 0
// 			1: begin
// 				O_driver_en <= 0;
// 				driver_off_fsm <= 0;
// 			end //end case 1
// 			default: begin
// 				driver_off_fsm <= 0;				
// 			end //end default
// 		endcase //end case
// 	end //end else
// end //end always



endmodule
