`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: uart_tx
// Description: RS422 UART发送模块 (115200bps, 8N1)
// Source: 从kb_pp_done工程移植
//////////////////////////////////////////////////////////////////////////////////

module uart_tx(
	input	I_clk,
	input	I_rst,
	input	I_txclk,
	input	[7:0] I_tx_data,
	input	I_tx_en,

	output reg O_tx,
	output reg O_tx_busy
	);

reg [3:0] tx_cnt;
reg [7:0] data;
reg [3:0] odd;
reg [1:0] txclk_sample;

always @(posedge I_clk or negedge I_rst) begin
	if (!I_rst) begin
		txclk_sample <= 0;
	end //end if
	else begin
		txclk_sample[0] <= I_txclk;
		txclk_sample[1] <= txclk_sample[0];
	end //end else
end //end always

always @(posedge I_clk or negedge I_rst) begin
	if (!I_rst) begin
		tx_cnt <=0;
		data <= 0;
		odd <= 0;
		O_tx <= 1;
		O_tx_busy <= 0;
	end //end if
	else begin
		if (txclk_sample == 2'b01) begin
			if (I_tx_en) begin
				data <= I_tx_data;
				O_tx_busy <= 1;
			end	 //end if
			if (O_tx_busy) begin
				if (tx_cnt==0) begin
					O_tx <= 0;
					tx_cnt <= tx_cnt + 1'b1;
				end //end if
				if (tx_cnt > 0 && tx_cnt < 9) begin
					O_tx <= data[tx_cnt - 1'b1];
					odd <= odd + data[tx_cnt - 1'b1];
					tx_cnt <= tx_cnt + 1'b1;
				end //end if
				if(tx_cnt== 9) begin
					O_tx <= 1;
					tx_cnt <= tx_cnt + 1'b1;
				end //end if
				if (tx_cnt== 10) begin
					O_tx <= 1;
					tx_cnt <=0;
					O_tx_busy <= 0;
					odd <= 0;
				end //end if
			end //end if
		end //end if
	end	 //end if
end	//end always

endmodule
