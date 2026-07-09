`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/05/01 21:30:08
// Design Name: 
// Module Name: data_sync
// Project Name: 
// Target Devices: 
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


module data_sync(
	input		clk			,
	
	input		pre_data	,
	output		post_data	
);

(* ASYNC_REG = "TRUE" *) reg	pre_data0;
(* ASYNC_REG = "TRUE" *) reg	pre_data1;

always@(posedge clk)
	pre_data0 <= pre_data;

always@(posedge clk)
	pre_data1 <= pre_data0;

assign post_data = pre_data1;

endmodule
