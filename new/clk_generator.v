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
module clk_generator(
	I_clk, 
	I_adc_clk, 
	I_rst, 
	O_clk_drv, 
	O_clk_adc
    );

input	I_clk;
input	I_adc_clk;
input	I_rst;
output	O_clk_drv;
output	O_clk_adc;

reg		[8:0] cnt_drv, cnt_adc;
reg		clk_tmp1;
reg		clk_tmp2;

assign O_clk_drv = clk_tmp1;
assign O_clk_adc = clk_tmp2;

always @(posedge I_clk) begin
	if(!I_rst) begin
		clk_tmp1 <= 0;
		cnt_drv <= 0;
	end //end if
	else begin
		cnt_drv <=cnt_drv + 1'b1;
		if (cnt_drv == 15) begin
			cnt_drv <= 0;
		end //end if
		if (cnt_drv == 0) begin	//????
			clk_tmp1 <= 1;
		end //end else if
		else if (cnt_drv == 8) begin
			clk_tmp1 <= 0;
		end //end else if
	end //end else
end //end always

always @(posedge I_clk) begin
	if(!I_rst) begin
		clk_tmp2 <= 0;
		cnt_adc <= 0;
	end //end if
	else begin
		cnt_adc <=cnt_adc + 1'b1;
		if (cnt_adc == 15) begin
			cnt_adc <= 0;
		end //end if
		if (cnt_adc == 1) begin
			clk_tmp2 <= 1;
		end //end if
		else if (cnt_adc == 9) begin
			clk_tmp2 <= 0;
		end	//end else if
	end //end else
end //end always
//*/
endmodule
