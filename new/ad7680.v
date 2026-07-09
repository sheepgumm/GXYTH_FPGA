`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: SITP
// Engineer: He Daogang
// 
// Create Date:    11:09:29 2019/01/03 
// Design Name:    JDMA_T01
// Module Name:    test
// Project Name:   FPGA Send module
// Target Devices: XC6SLX75-2FGG676
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
module ad7680(
	input	I_clk, 
	input	I_rst, 

	output	O_temp_cs, 
	output	O_temp_sclk, 
	input	I_temp_sdata, 
	output	O_temp_rdy, 
	output	[15:0]	O_temperature
	);

reg		temp_cs;
reg		temp_sclk;
reg		temp_rdy;
reg	[15:0]	temperature;

assign	O_temp_cs = temp_cs;
assign	O_temp_sclk = temp_sclk;
assign	O_temp_rdy = temp_rdy;
assign	O_temperature = temperature;

reg	[7:0] cnt_sclk;
always @(posedge I_clk) begin
	if (!I_rst) begin
		temp_sclk <= 0;
		cnt_sclk <= 0;
	end //end if
	else begin
		cnt_sclk <= cnt_sclk + 1'b1;
		if (cnt_sclk == 39) begin
			temp_sclk <= 1;
		end //end if
		else if (cnt_sclk == 79) begin
			cnt_sclk <= 0;
			temp_sclk <= 0;
		end //end else if
	end //end else 
end //end always

reg	[1:0]	temp_sclk_sample;
reg			temp_sdata_r1;
reg			temp_sdata_r2;
always @(posedge I_clk) begin
	if (!I_rst) begin
		temp_sclk_sample <= 0;
		temp_sdata_r1 <= 0;
		temp_sdata_r2 <= 0;
	end //end if
	else begin
		temp_sclk_sample[0] <= O_temp_sclk;
		temp_sclk_sample[1] <= temp_sclk_sample[0];
		
		temp_sdata_r1 <= I_temp_sdata;
		temp_sdata_r2 <= temp_sdata_r1;
	end //end else 
end //end always

reg	[3:0]	fsm_temp;
reg	[7:0]	cnt_pos;
reg	[0:23]	temperature_tmp;
reg	[23:0]	temperature_sum;
reg	[7:0]	cnt_temp_sum;
always @(posedge I_clk) begin
	if (!I_rst) begin
		fsm_temp <= 0;
		temp_rdy <= 0;
		temperature <= 0;
		temp_cs <= 1;
		cnt_pos <= 0;
		temperature_tmp <= 0;
		temperature_sum <= 0;
		cnt_temp_sum <= 0;
	end //end if
	else begin
		if (temp_sclk_sample == 2'b01) begin
			case (fsm_temp)
				0: begin
					temp_cs <= 0;
					cnt_pos <= 0;
					temperature_tmp <= 0;
					
					fsm_temp <= 1;
				end //end case 0
				
				1: begin
					if (cnt_pos == 23) begin
						cnt_pos <= 0;
						temp_cs <= 1;
						
						fsm_temp <= 2;
					end //end if
					else begin
						temperature_tmp[cnt_pos] <= temp_sdata_r2;
						cnt_pos <= cnt_pos + 1'b1;
					end //end else
				end //end case 1
				
				2: begin
					if (cnt_temp_sum < 255) begin
						cnt_temp_sum <= cnt_temp_sum + 1'b1;
						temperature_sum[23:0] <= temperature_sum[23:0] + {8'b0000_0000, temperature_tmp[3:18]};
						fsm_temp <= 0;
					end //end if
					else begin
						cnt_temp_sum <= 0;
						temperature_sum[23:0] <= temperature_sum[23:0] + {8'b0000_0000, temperature_tmp[3:18]};
						fsm_temp <= 3;
					end //end else
				end //end case 2
				
				3: begin
					temperature_sum <= 0;
					temp_rdy <= 1;
					temperature[15:0] <= temperature_sum >> 8;
					
					fsm_temp <= 0;
				end //end case 3
				
				default: begin
					fsm_temp <= 0;
				end //end default
			endcase //end case
		end //end if
	end //end else 
end //end always

endmodule
