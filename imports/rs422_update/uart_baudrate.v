`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: uart_baudrate
// Description: RS422 UART波特率生成模块 (115200bps @ 80MHz)
// Source: 从kb_pp_done工程移植
//////////////////////////////////////////////////////////////////////////////////

module uart_baudrate(
	input I_clk,
	input I_rst,
	output O_txclk,
	output O_rxclk
);
parameter rx_div1 = 21;                 //80MHz/(16*115200) = 43
parameter rx_div2 = 42;
parameter tx_div3 = 347;                //80MHz/(115200) = 694
parameter tx_div4 = 694;

reg [5:0] rx_cnt;
reg [9:0] tx_cnt;

reg rx_clkout, tx_clkout;

assign O_rxclk = rx_clkout;
assign O_txclk = tx_clkout;

always @(posedge I_clk or negedge I_rst) begin
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

always @(posedge I_clk or negedge I_rst) begin
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
