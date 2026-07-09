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
module uart_baudrate(
	input I_clk,
	input I_rst,
	output O_txclk,
	output O_rxclk
);

// parameter rx_div1 = 7;					//100MHz/(16*460800) = 13
// parameter rx_div2 = 13; 
// parameter tx_div3 = 109;				//100MHz/(460800) = 217
// parameter tx_div4 = 217; 

parameter rx_div1 = 22;					//80MHz/(16*115200) = 44
parameter rx_div2 = 44; 
parameter tx_div3 = 348;				//80MHz/(115200) = 695
parameter tx_div4 = 695; 

reg [6:0] rx_cnt; 
reg [10:0] tx_cnt;

reg rx_clkout, tx_clkout;

assign O_rxclk = rx_clkout;
assign O_txclk = tx_clkout;

always @(posedge I_clk) begin
	if (!I_rst) begin
		rx_cnt <= 0;
		rx_clkout <= 0;
	end //end if
	else begin
		if (rx_cnt == rx_div1) begin
			rx_clkout <= 1;
			rx_cnt <= rx_cnt + 1'b1;
		end //end if
		else if (rx_cnt == rx_div2) begin
			rx_clkout <= 0; 
			rx_cnt <= 0;
		end //end else if
		else begin
			rx_cnt <= rx_cnt + 1'b1;
		end //end else
	end //end else
end //end always

always @(posedge I_clk) begin
	if (!I_rst) begin
		tx_cnt <= 0;
		tx_clkout <= 0;
	end //end if
	else begin
		if (tx_cnt == tx_div3) begin
			tx_cnt <= tx_cnt + 1'b1;
			tx_clkout <= 1;
		end //end if
		else if (tx_cnt == tx_div4)begin
			tx_clkout <= 0;
			tx_cnt <= 0;
		end //end else if
		else begin
			tx_cnt <= tx_cnt + 1'b1;
		end //end else
	end //end else
end //end always

endmodule
