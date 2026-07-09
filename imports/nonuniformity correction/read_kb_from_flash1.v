`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/11/15 09:23:17
// Design Name: 
// Module Name: read_kb_from_flash1
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

module read_kb_from_flash1
	(
		(*mark_debug = "true"*)output	    wire	flash_clk,
		output 	    reg	    flash_cs,
		inout	     	    D0,
		inout		   		D1,
		input		flash_spi_clk,
        input		wire	CLK,
		input		wire	flash_rstn,
		input		wire	ddr_init_done,
		(*mark_debug = "true"*)output	    wire	k_b_finish_O,
  		output 	reg[7:0]		mydata_o,
		output	    wire	myvalid_o,
	    (*mark_debug = "true"*)output      wire    shift_sig,
		output	    wire	[7:0] o_data_sim,
		output		wire	[8:0] flash_read_num_test
	);


	reg clock25M;
	reg myvalid;
	reg[7:0] mydata;
	reg spi_clk_en = 1'b0;
	reg data_come;
	reg IO0;
	reg IO1;
	reg io_sig;
	reg [3:0] dummy_cnt;
	assign D0 = io_sig ? 1'bz : IO0;
	assign D1 = io_sig ? 1'bz : IO1;
	parameter idle = 3'b000;
	parameter cmd_send = 3'b001;
	parameter address_send = 3'b010;
	parameter read_wait = 3'b011;
	parameter finish_done = 3'b110;
	
	parameter kb_start_addr = 32'h004FFF00;//3825664 d3825920 第一个页读到的全�?1111，所以从数据的前�?�? 多读�?�?
	parameter kb_end_page_addr = 32'h0063FF00;//d5136384
	
	reg[2:0] spi_state;
	reg[7:0] cmd_reg;
	reg[31:0] address_reg;
	reg[7:0] cnta;
	reg[7:0] cntb;
	reg[8:0] read_cnt;
	reg[8:0] read_num;
	reg read_finish;
	reg k_b_finish;
	reg [9:0] fifo_delay_cnt;
	reg [1:0]ddr_init_done_a;
	reg [3:0] clock25M_cnt;
	//sim
	reg [7:0] sim_data;
	assign o_data_sim = sim_data;
	
	assign myvalid_o = myvalid;
	assign flash_clk = spi_clk_en ? flash_spi_clk : 1'b0;
	assign k_b_finish_O = k_b_finish;
	assign shift_sig = spi_clk_en;
	assign flash_read_num_test = read_cnt ;
	//产生40Mhz的SPI Clock		  
	always @(posedge CLK or negedge flash_rstn) begin
	   if(!flash_rstn)begin
			clock25M <= 1'b0;
			clock25M_cnt <= 0;
		end
		else begin
			
			if(clock25M_cnt == 4'd1) begin
				clock25M <= ~clock25M;
				clock25M_cnt <= 0;
			end
			else begin
				clock25M <= clock25M;
				clock25M_cnt <= clock25M_cnt + 1;
			end
		end
	end
	//打拍异步信号
	always @(posedge flash_spi_clk or negedge flash_rstn) begin
		if(!flash_rstn) begin
			ddr_init_done_a <= 0;
		end
		else begin
			ddr_init_done_a[0] <= ddr_init_done;
			ddr_init_done_a[1] <= ddr_init_done_a[0];
		end
	end
	//发�?�读flash命令
	always @(negedge flash_spi_clk or negedge flash_rstn) begin
		if(!flash_rstn)begin
			flash_cs <= 1'b1;		
			spi_state <= idle;
			cmd_reg <= 8'd0;
			address_reg <= kb_start_addr;//k start address in flash1  kb_start_addr
			spi_clk_en <= 1'b0;		//SPI clock输出不使�?
			cnta <= 8'd0;
			read_num <= 9'd0;	
			k_b_finish <= 1'b0;
			io_sig <= 0;
			dummy_cnt <= 0;
			fifo_delay_cnt <= 0;
		end
		else begin
			case(spi_state) 
				idle:begin	//idle 状�??	
					if(ddr_init_done_a[1] == 1'b1) begin	  //ddr初始化完�?
						spi_clk_en <= 1'b0;
						flash_cs <= 1'b1;
						IO0 <= 1'b1;	
						IO1 <= 1'b1;
						io_sig <= 0;
						cmd_reg <= 8'hBB;//page read	
						if(!k_b_finish)begin	//not finish, continue to read
							spi_state <= cmd_send;
							cnta <= 8'd7;	
							read_num <= 9'd0;		
										
						end
						
						else begin
							spi_state <= idle;
						end
					end
					else begin
						spi_state <= idle;
					end
				end
				
				cmd_send:begin	//发�?�命令状�?	
					spi_clk_en <= 1'b1;	//flash的SPI clock输出
					io_sig <= 0;
					flash_cs <= 1'b0;	//cs拉低
					if(cnta > 8'd0)begin	//如果cmd_reg还没有发送完
						IO0 <= cmd_reg[cnta];	//发�?�bit7~bit1�?
						   cnta <= cnta - 8'd1;
					end
					else begin	//发�?�bit0
						IO0 <= cmd_reg[0]; 
						//cmd_send finished,jump to address_send  
						spi_state <= address_send;
						cnta <= 8'd31;
						
					end
				end
				
				address_send:begin	//发�?�flash address	
				   if(cnta > 8'd1)begin	//如果cmd_reg还没有发送完
						IO1 <= address_reg[cnta];	//发�?�bit23~bit1�?
						IO0 <= address_reg[cnta - 8'b1];	//发�?�bit23~bit1�?
						   cnta <= cnta - 8'd2;						
					end				
					else begin	//发�?�bit0
						IO1 <= address_reg[1];   	
						IO0 <= address_reg[0];  					 
						spi_state <= read_wait;
						read_num <= 9'd256;	//如果是block读命�?,接收256个数�?	
						dummy_cnt <= 0;						 					 
					end
				end
				
				read_wait:begin	//等待flash数据读完�?
					io_sig <= 1;
					if(read_finish)begin
						spi_state <= finish_done;
						data_come <= 1'b0;
						if(address_reg >= kb_end_page_addr ) begin //kb_end_page_addr
							k_b_finish <= 1'b1;
						end
						else begin
							address_reg <= address_reg + 32'd256;
						end
					end
					else begin
						if(dummy_cnt == 4'd10) begin//6 7 8
							data_come <= 1'b1;
						end
						else begin
							dummy_cnt <= dummy_cnt + 1;
						end
					end
				end
				
				finish_done:begin	//flash操作完成
					flash_cs <= 1'b1;
					IO0 <= 1'b1;
					IO1 <= 1'b1;
					spi_clk_en <= 1'b0;
					spi_state <= idle;
					io_sig <= 0;
					// if(fifo_delay_cnt == 10'd100) begin
					// 	spi_state <= idle;
					// 	fifo_delay_cnt <= 0;
					// end
					// else begin
					// 	fifo_delay_cnt <= fifo_delay_cnt + 1;
					// end
				end
				
				default:begin
					spi_state <= idle;
				end
				
			endcase
		end
	end
	
	reg [1:0] tag;	
	reg [7:0] sim_data2;
	//接收flash数据	
	always @(posedge flash_spi_clk or negedge flash_rstn) begin //negedge flash_spi_clk or negedge flash_rstn
		if(!flash_rstn)begin
			read_cnt <= 9'd0;
			cntb <= 8'd0;
			read_finish <= 1'b0;
			myvalid <= 1'b0;
			mydata <= 8'd0;
			mydata_o <= 8'd0;
			sim_data <= 0;
			sim_data2 <= 8'd97;
			tag <= 0;
		end
		else begin
			if(data_come)begin
				if(read_cnt < read_num)begin	//接收数据			  
					if(cntb < 8'd6)begin	//接收�?个byte的bit0~bit6		  
						myvalid <= 1'b0;
						mydata <= {mydata[5:0], D1,D0};
						cntb <= cntb + 8'd2;
					end
					else begin
						myvalid <= 1'b1;	//�?个byte数据有效
						mydata_o <= {mydata[5:0], D1,D0};	//接收bit7
						cntb <= 8'd0;
						read_cnt <= read_cnt + 9'd1;
						if(sim_data2 == 8'd160 && tag == 1) begin
							sim_data <= sim_data2;
							sim_data2 <= 1;
							tag <= tag + 1;
						end	
						else begin
							tag <= tag + 1;
							if(tag == 1) begin
								sim_data <= sim_data2;
								sim_data2 <= sim_data2 + 1;
								
							end
							else begin
								
								sim_data <= 0;
							end
						end
					end
				end				 			 
				else begin 
					read_cnt <= 9'd0;
					read_finish <= 1'b1;
					myvalid <= 1'b0;
	
					// sim_data <= 0;
				end
			end
			else begin
				read_cnt <= 9'd0;
				cntb <= 8'd0;
				read_finish <= 1'b0;
				myvalid <= 1'b0;
				mydata <= 8'd0;
			 end
		end
	end	
	
	endmodule