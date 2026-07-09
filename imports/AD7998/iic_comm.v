`timescale 1ns / 1ps

module iic_comm #(
parameter                               SYS_CLOCK = 100_000_000    ,//系统时钟频率 100MHz 10ns
parameter                               SCL_CLOCK = 100_000         //iic时钟频率 100kHz 10000ns 
)(
input            	                    i_clk                      ,//系统时钟
input            	                    i_rst_n                    ,//系统复位
input            	                    i_wr_en                    ,//写使能
input            	                    i_rd_en                    ,//读使能
input            	  [   6:0]          i_dev_addr                 ,//器件地址
input            	  [  15:0]          i_reg_addr                 ,//寄存器地址，单字节时从低字节有效
input            	  [   1:0]          i_reg_addr_num             ,//寄存器地址字节数 1: 1字节，其他：2字节
input            	  [  15:0]          i_wr_data                  ,//写数据
input            	  [   1:0]          i_wr_data_num              ,//写数据字节数，默认为1
input            	  [   1:0]          i_rd_data_num              ,//读数据字节数，默认为1
output reg       	  [  15:0]          o_rd_data                  ,//读数据
output reg       	                    o_rd_data_vaild            ,//读数据有效
output reg       	                    o_cfg_done                 ,//一次读写操作完成标志
inout                            	    io_SDA                     ,//SDA
output reg                       	    o_SCL                       //SCL
);

localparam                              SCL_CNT_M 	= SYS_CLOCK / SCL_CLOCK; //1000

localparam                              IDLE 	 	= 9'b0_0000_0001   	;
localparam                              WR_START 	= 9'b0_0000_0010 	;
localparam                              WR_CTRL 	= 9'b0_0000_0100	;
localparam                              WR_REG_ADDR = 9'b0_0000_1000	;
localparam                              WR_DATA 	= 9'b0_0001_0000 	;
localparam                              RD_START 	= 9'b0_0010_0000 	;
localparam                              RD_CTRL 	= 9'b0_0100_0000 	;
localparam                              RD_DATA 	= 9'b0_1000_0000 	;
localparam                              STOP 		= 9'b1_0000_0000    ;

//-------------------------------------------------
// 变量定义
//-------------------------------------------------
reg                    [  15:0]         scl_cnt                    ;//clk计数器 用于产生scl时钟
reg                                     scl_high                   ;//scl高电平中部标志
reg                                     scl_low                    ;//scl低电平中部标志
reg                                     scl_vaild                  ;//scl有效标志
reg                    [   8:0]         main_state                 ;//状态寄存器
reg                                     sda_reg                    ;//sda输出寄存器
reg                                     sda_en                     ;//sda三态使能
reg                                     sda_task_flag              ;//串行输出输入任务执行标志位
reg                                     w_flag                     ;//写标志
reg                                     r_flag                     ;//读标志
reg                    [   7:0]         scl_level_cnt              ;//scl高低电平计数器
reg                                     ack                        ;//应答信号
reg                    [   1:0]         wdata_cnt                  ;//写数据字节数计数器
reg                    [   1:0]         rdata_cnt                  ;//读数据字节数计数器
reg                    [   1:0]         reg_addr_cnt               ;//地址字节数计数器
reg                    [   7:0]         sda_data_out               ;//数据输出buffer
reg                    [   7:0]         sda_data_in                ;//数据输入buffer
wire                   [   7:0]         wr_ctrl_word               ;//写控制字
wire                   [   7:0]         rd_ctrl_word               ;//读控制字
wire                                    rdata_vaild                ;//读数据有效前寄存器

assign wr_ctrl_word = {i_dev_addr,1'b0};//写操作
assign rd_ctrl_word = {i_dev_addr,1'b1};//读操作

/*************************************************************************
iic时钟信号生成
****************************************************************************/
//iic 控制SCL时钟的启停 scl_vaild
always @(posedge i_clk) begin
	if(!i_rst_n)
		scl_vaild <= 1'b0;
	else begin
		if(i_wr_en | i_rd_en)
			scl_vaild <= 1'b1;
		else if(o_cfg_done)
			scl_vaild <= 1'b0;
	end
end
	
//o_SCL 分频计数器
always @(posedge i_clk) begin
	if(!i_rst_n)
		scl_cnt <= 16'd0;
	else begin
		if(scl_vaild) begin
				if(scl_cnt == SCL_CNT_M-1'b1)
					scl_cnt <= 16'd0;
				else
					scl_cnt <= scl_cnt + 16'd1;
			end
		else
			scl_cnt <= 16'd0;
	end
end
	
//o_SCL 时钟产生
always @(posedge i_clk) begin
	if(!i_rst_n)
		o_SCL <= 1'b1;
	else begin
		if(scl_cnt == SCL_CNT_M >> 1) 
			o_SCL <= 1'b0;
		else if(scl_cnt == 16'd0)
			o_SCL <= 1'b1;
	end
end

//o_SCL 高低电平中部标志
always @(posedge i_clk) begin
	if(!i_rst_n) begin
		scl_high <= 1'b0;
		scl_low  <= 1'b0;
	end
	else begin
		if(scl_cnt == (SCL_CNT_M >> 2))
			scl_high <= 1'b1;
		else
			scl_high <= 1'b0;

		if(scl_cnt == ((SCL_CNT_M >> 1) + (SCL_CNT_M >> 2)))
			scl_low <= 1'b1;
		else
			scl_low <= 1'b0;			
	end
end

/*************************************************************************
iic主程序状态机
****************************************************************************/
always @(posedge i_clk) begin
	if(!i_rst_n) begin
		main_state 		<= IDLE;
		sda_reg 	  	<= 1'b1;	
		w_flag 			<= 1'b0;
		r_flag 			<= 1'b0;
		o_cfg_done 		<= 1'b0;
		reg_addr_cnt 	<= 2'd1;
		wdata_cnt 		<= 2'd1;
		rdata_cnt 		<= 2'd1;
	end
	else begin		
		case(main_state)
			IDLE: begin
				sda_reg   	 <= 1'b1;//默认为高电平
				w_flag    	 <= 1'b0;
				r_flag 	 	 <= 1'b0;
				o_cfg_done 	 <= 1'b0;
				reg_addr_cnt <= 2'd1;
				wdata_cnt 	 <= 2'd1;
				rdata_cnt 	 <= 2'd1;
				
				if(i_wr_en) begin 
					main_state <= WR_START;
					w_flag     <= 1'b1;
				end	
				else if(i_rd_en) begin
					main_state <= WR_START; 
					r_flag     <= 1'b1;
				end
			end
			//$ 起始信号		
			WR_START: begin
				if(scl_high) begin
					main_state <= WR_START; //拉低SDA总线 发送START信号
					sda_reg    <= 1'b0;
				end
				else if(scl_low) begin
					main_state    <= WR_CTRL;
					sda_data_out  <= wr_ctrl_word;	//$ 准备要发送的控制字 FRAME1：SERIAL BUS ADDRESS BYTE 
					sda_task_flag <= 1'b0; 			// 开始串行传输任务
				end
			end
			//$ 写设备地址、寄存器地址
			WR_CTRL: begin
				if(sda_task_flag == 1'b0) // 发送数据
					send_8bit_data;
				else begin	              // 等待响应
					if(ack == 1'b1) begin // 收到响应
						if(scl_low) begin // 准备发送的寄存器地址数据
							main_state 	  <= WR_REG_ADDR;// 转换到寄存器地址
							sda_task_flag <= 1'b0;
							if(i_reg_addr_num == 2'b1)
								sda_data_out <= i_reg_addr[7:0];//$ 准备要发送的寄存器地址 FRAME2：ADDRESS POINTER REGISTER
							else
								sda_data_out <= i_reg_addr[15:8];//如果寄存器地址为2个字节 要保证先发的最高位
						end
					end
					else // 未收到响应
						main_state <= IDLE;
				end
			end
			WR_REG_ADDR: begin
				if(sda_task_flag == 1'b0)
					send_8bit_data;
				else begin
					if(ack == 1'b1) begin //收到响应
						if(reg_addr_cnt == i_reg_addr_num) begin // 寄存器地址数据发送完成（若只需发送一个字节）
							if(w_flag && scl_low) begin
								main_state    <= WR_DATA;        // 状态转移
								sda_task_flag <= 1'b0;
								reg_addr_cnt  <= 2'd1;
								if(i_wr_data_num == 2'b1)
									sda_data_out  <= i_wr_data[7:0]; // 写入寄存器数据准备
								else
									sda_data_out  <= i_wr_data[15:8]; //$ 如果写入数据为2个字节 要保证先发的最高位 FRAME3：MOST SIGNIFICANT DATA BYTE
							end
							else if(r_flag && scl_low) begin
								main_state    <= RD_START; 
								sda_reg       <= 1'b1; // sda总线拉高 准备发送一个START信号 
							end
						end
						else begin // 寄存器地址数据没有发送完成 i_reg_addr_num=2
							if(scl_low) begin
								main_state    <= WR_REG_ADDR;
								reg_addr_cnt  <= reg_addr_cnt + 2'd1;
								sda_data_out  <= i_reg_addr[7:0]; // 准备低8位寄存器地址
								sda_task_flag <= 1'b0; // 状态清零
							end
						end		
					end
					else	// 未收到响应
						main_state <= IDLE;					
				end
			end		
			//$ 写寄存器数据
			WR_DATA: begin
				if(sda_task_flag == 1'b0)
					send_8bit_data;
				else begin
					if(ack == 1'b1) begin // 收到响应
						if(wdata_cnt == i_wr_data_num) begin //发送完成 只写入一个字节 i_wr_data_num=1
							if(scl_low) begin
								main_state <= STOP;
								sda_reg    <= 1'b0; //sda总线提前拉低 用于待会儿生成STOP信号
								wdata_cnt  <= 2'd1;
							end
						end
						else begin //未发送完成 需写入两个字节 i_wr_data_num2
							if(scl_low) begin
								main_state    <= WR_DATA;
								sda_data_out  <= i_wr_data[7:0]; //$ FRAME4：LEAST SIGNIFICANT DATA BYTE
								wdata_cnt     <= wdata_cnt + 2'd1;
								sda_task_flag <= 1'b0;
							end
						end
					end
					else // 未收到响应
						main_state <= IDLE;
				end
			end
			//$ 读寄存器数据
			RD_START: begin
				if(scl_high) begin
					main_state    <= RD_START;
					sda_reg       <= 1'b0; //第一次写完设备地址和寄存器地址后 发送START信号
				end
				else if(scl_low) begin
					main_state    <= RD_CTRL;
					sda_data_out  <= rd_ctrl_word;	//$ 准备要发送的控制字 FRAME3：SERIAL BUS ADDRESS BYTE (最低位为1表示读)
					sda_task_flag <= 1'b0; 			// 准备开始串行传输任务
				end
			end			
			RD_CTRL: begin
				if(sda_task_flag == 1'b0)  // 发送数据
					send_8bit_data;
				else begin	// 等待响应
					if(ack == 1'b1) begin  // 收到响应
						if(scl_low) begin  // 准备接收FRAME2的寄存器数据
							main_state    <= RD_DATA; // 转换到读寄存器
							sda_task_flag <= 1'b0;
						end
					end
					else // 未收到响应
						main_state <= IDLE;
				end
			end			
			RD_DATA: begin
				if(sda_task_flag == 1'b0)
					receive_8bit_data;
				else begin
					if(rdata_cnt == i_rd_data_num) begin  // 接收完成
						sda_reg <= 1'b1;  // 发送NACK 不读了 
						if(scl_low) begin
							main_state <= STOP;
							sda_reg    <= 1'b0; //提前拉低sda总线 准备发送STOP信号
						end
					end
					else begin
						sda_reg <= 1'b0; // 发送ACK 继续读下一个字节
						if(scl_low) begin
							main_state    <= RD_DATA;
							rdata_cnt     <= rdata_cnt + 2'd1;
							sda_task_flag <= 1'b0;
						end
					end
				end
			end
			//$ 停止信号
			STOP: begin
				if(scl_high) begin
					sda_reg    <= 1'b1;
					main_state <= IDLE;
					o_cfg_done <= 1'b1;
				end
			end
			
			default: main_state <= IDLE;
		endcase
	end
	
end

/*************************************************************************
串行数据任务 收发8bit数据
****************************************************************************/
//发送接收数据时 o_SCL 时钟计数
always @(posedge i_clk) begin
	if(!i_rst_n)
		scl_level_cnt <= 8'd0;
    else begin
		//这几个状态需要执行数据发送接收任务
		if(main_state == WR_CTRL || main_state == WR_REG_ADDR || main_state == WR_DATA ||
		   main_state == RD_CTRL || main_state == RD_DATA) begin  
			if(scl_low | scl_high) begin
				if(scl_level_cnt == 8'd17)
					scl_level_cnt <= 8'd0;
				else
					scl_level_cnt <= scl_level_cnt + 8'd1;
			end
		end
		else
			scl_level_cnt <= 8'd0;
	end
end

//数据接收对发送的响应标志位
always @(posedge i_clk) begin
	if(!i_rst_n)
		ack <= 1'b0;
	else begin
		if((scl_level_cnt == 8'd16) && scl_high && (io_SDA == 1'd0))
			ack <= 1'b1;
		else if((scl_level_cnt == 8'd17) && scl_low)
			ack <= 1'b0;
	end
end

/* 输出串行数据任务
使用scl_level_cnt=16作为完成标志，因为发送需要额外1个周期处理ACK位（第9个时钟周期）完整周期：8位数据(0-7) + 1位ACK(8) */ 
task send_8bit_data;
	if(scl_high && (scl_level_cnt == 8'd16)) //8bit data send o_cfg_done
		sda_task_flag <= 1'b1;
	else if(scl_level_cnt < 8'd17) begin
		sda_reg <= sda_data_out[7];
		if(scl_low)
			sda_data_out <= {sda_data_out[6:0],1'b0};
	end
endtask
	
/* 接收串行数据任务
使用scl_level_cnt=15作为完成标志 仅需8个时钟周期完成数据接收(0-7) 提前1个周期置位标志 为后续MASTER发送ACK响应留出时间 */
task receive_8bit_data;
	if(scl_low && (scl_level_cnt == 8'd15))
		sda_task_flag <= 1'b1;
	else if(scl_level_cnt < 8'd15) begin
		if(scl_high)
			sda_data_in <= {sda_data_in[6:0],io_SDA};
	end
endtask

/*************************************************************************
SDA三态门控制输出 当sda_en=1时输出sda_reg 否则高阻态(释放总线)
****************************************************************************/					
//$ io_SDA 三态门输出
assign io_SDA = sda_en ? sda_reg : 1'bz;

always @(*) begin
	case(main_state)
		IDLE: sda_en <= 1'b0;  //输入 （MASTER 释放总线）
			
		WR_START,RD_START,STOP: sda_en <= 1'b1;  //输出 MASTER 发送START/STOP信号 （MASTER 占用总线）
			
		WR_CTRL,WR_REG_ADDR,WR_DATA,RD_CTRL: begin
			if(scl_level_cnt < 8'd16)
				sda_en <= 1'b1; //前16个周期输出数据 （MASTER 占用总线）
			else
				sda_en <= 1'b0; //第16周期后释放总线等待ACK （MASTER 释放总线）
		end		
		RD_DATA: begin
			if(scl_level_cnt < 8'd16)
				sda_en <= 1'b0; //前16个周期接收从设备数据 （MASTER 释放总线）
			else	
				sda_en <= 1'b1; //第16周期后输出主设备ACK（MASTER 占用总线）
		end
		default: sda_en <= 1'b0;
	endcase
end
	
/*************************************************************************
读有效数据
****************************************************************************/		
//$ 读出数据有效标志位
assign rdata_vaild = (main_state == RD_DATA) && (scl_level_cnt == 8'd15) && scl_low;

//$ 读出的有效数据
always @(posedge i_clk) begin
	if(!i_rst_n) begin
		o_rd_data_vaild <= 1'b0;
		o_rd_data       <= 16'h0;
	end
	else begin
			case(i_rd_data_num)
				2'd1://一次只读一个字节
					begin
						if(rdata_vaild)
							begin
								o_rd_data[7:0]  <= sda_data_in;
								o_rd_data_vaild <= 1'b1;
							end
						else
							o_rd_data_vaild <= 1'b0;
					end
				2'd2://一次连续读两个字节
					begin
						if(rdata_vaild && rdata_cnt==2'd1)
							begin
								o_rd_data[15:8]  <= sda_data_in;
							end
						else if(rdata_vaild && rdata_cnt==2'd2)
							begin
								o_rd_data[7:0]  <= sda_data_in;
								o_rd_data_vaild <= 1'b1;
							end
						else
							o_rd_data_vaild <= 1'b0;
					end
				default:    o_rd_data_vaild <= 1'b0;	
			endcase
	end
end

endmodule

