//欢迎白嫖，小趴菜的行列程序？谢谢支持！
//微信公众号搜索改为详细的介绍，学习和交流请加公众号私聊小趴菜！
//////////////////////////////////////////////////////////////////////////////////
module ADC_CONFIGURE(
	input		CLK		,  	//系统工作时钟，20MHz
	input		reset	,	//系统同步复位
	input image_en,
	input spi_en,
	output	reg sclk	,	//to ADC
	output	reg cs_b	,	//to ADC
	input 	 	sdin	,	//to FPGA
	output	reg sdout	,	//to ADC
	output	reg CfgDone	,	//配置成功拉高1
	output  reg Tri_en		//FPGA 三态总线信号
    );
///////////////////////////////////////////////////////	
    // 【修改 1】：将写寄存器数量修改为 7 (原本是 5 + 新增 2)
	localparam	Wr_n		=	8'd7;			
	wire	[23:00]	WriteReg1;
	wire	[23:00]	WriteReg2;
	wire	[23:00]	WriteReg3;
	wire	[23:00]	WriteReg4;
	wire	[23:00]	WriteReg5;
    // 【修改 2】：增加 WriteReg6 和 WriteReg7
	wire	[23:00]	WriteReg6;
	wire	[23:00]	WriteReg7;

	assign 	WriteReg1		= {3'b000,13'h000,8'h3c}; //all registers revert to default
    assign 	WriteReg2		= {3'b000,13'h015,8'h30}; //100ou
	assign 	WriteReg3		= {3'b000,13'h109,8'h00}; //50 14bit 20MSPS  52 14bit 40MSPS
	assign 	WriteReg4		= {3'b000,13'h018,8'h01}; //Set resolution/sample rate override
	assign 	WriteReg5		= {3'b000,13'h00d,8'h00}; //off 00    output test mode 0/1 09
    
    // 【修改 3】：为新增的两个寄存器赋初值（请根据你的芯片手册修改地址和数据）
	assign  WriteReg6 		= {3'b000,13'h009,8'h01};   // 打开 DCS 
	assign  WriteReg7 		= {3'b000,13'h0FF,8'h01};   // 向 0xFF 写 0x01，使前面配置生效

///////////////////////////////////////////////////////	    
	localparam	Rd_n			=	8'd4; //需读3个寄存器的值为例
	wire	[23:0]	RdAddr1;
	wire	[23:0]	RdAddr2;
	wire	[23:0]	RdAddr3;
	wire	[23:0]	RdAddr4;
	assign 	RdAddr1	= 24'h80_08_FF		; //默认99为正常模式，BD为测试模式。
	assign 	RdAddr2	= 24'h80_0d_FF		; //chip ID，0x29	
	assign 	RdAddr3	= 24'h80_00_FF		; //0X01
	assign 	RdAddr4	= 24'h81_09_FF		; //0X01
///////////////////////////////////////////////////////	
                                          
(*mark_debug = "true"*)	reg			[7:0]	RdData1; //存储读取的3个寄存器的值
(*mark_debug = "true"*)	reg			[7:0]	RdData2;
(*mark_debug = "true"*)	reg			[7:0]	RdData3;
(*mark_debug = "true"*)	reg			[7:0]	RdData4;
//////////////////////////////////////////////////////////////////////////////////////////////	
	
		
//////////////////////////////////////////////////////////////////////////////////////////////	                                       
(*mark_debug = "true"*)	reg	[7:0] 	state;
reg	[21:0]	cnt;                       
	reg	[7:0]	n; //写寄存器第几个？                      
	reg	[7:0]	m; //读几个寄存器第几个？  

	always @(posedge CLK or negedge reset)               
		if(~reset)                          
			begin                          
			state	<=8'd16;
			cs_b	<=1'b1;
			sdout	<=1'b1;
			sclk	<=1'b1;
			CfgDone	<=1'b0;
			cnt		<=22'd23;

			n			<=8'd0;
			m			<=8'd0;
			RdData1		<=8'd0;
			RdData2		<=8'd0;
			RdData3		<=8'd0;
			RdData4     <= 0;
			Tri_en      <=1'b1; //置为1时代表方向为sdio为输出
			end
		else case(state)
		8'd16:	begin	         
					if(cnt==22'd0) //外部复位后，等待15个时钟周期，使电平稳定再进行ADC寄存器配置
						begin
						state	<=8'd0;
						cnt		<=22'd23;
						end
					else
						begin
						cnt		<=cnt-1'b1;
						state	<=8'd16;
						Tri_en  <=1'b1;
						end		
				end
		8'd0:	begin //初始化所有寄存器初始值
					cs_b		<=1'b1;
					sdout		<=1'b1;
					sclk		<=1'b1;
					cnt			<=22'd23;
					n			<=8'd1;
					m			<=8'd1;
					
					CfgDone 	<=1'b0;
					RdData1		<=8'd0;
					RdData2		<=8'd0;
					RdData3		<=8'd0;
					Tri_en  	<=1'b1;
					if(spi_en)
					    state		<=8'd1;
					else
						state		<=8'd0;
				end
		8'd1:	begin //写入24bit寄存器数据的MSB
					cs_b	<=1'b0;
					sclk	<=1'b0;
					if(n==8'd1)
						sdout	<=WriteReg1[cnt];
					else if(n==8'd2)
						sdout	<=WriteReg2[cnt];
					else if(n==8'd3)
						sdout	<=WriteReg3[cnt];
					else if(n==8'd4)
						sdout	<=WriteReg4[cnt];
					else if(n==8'd5)
						sdout	<=WriteReg5[cnt];
                    // 【修改 4】：在发送状态机中增加 6 和 7 的分支
					else if(n==8'd6)
						sdout	<=WriteReg6[cnt];
					else if(n==8'd7)
						sdout	<=WriteReg7[cnt];	
					
                    state	<=8'd2;
				end
		8'd2:	begin //循环24次，将24bit数据从高到低写入
					sclk	<=1'b1;
					if(cnt==22'd0)
						begin
						state<=8'd3;
						cnt	<=22'd23;
						end
					else
						begin
						cnt	<=cnt-1'b1;
						state	<=8'd1;
						end		
				end
		8'd3:	begin //写入一个24bit数据后，等待24个时钟周期再开始下一个状态
					if(cnt==22'd0)
						begin
						state<=8'd4;
						cnt	<=22'd23;
						end
					else
						begin
						cnt	<=cnt-1'b1;
						cs_b	<=1'b1;
						sclk	<=1'b1;
						sdout	<=1'b1;
						state	<=8'd3;
						end		
				end	
		8'd4:	begin //判断n值，如果n没到设定的总数，则更新n并回到状态1继续写
                    // 【修改 5】：这里直接用 n==Wr_n 判断即可，去掉了多余的 || n==5，修复了只能发4个的bug
					if(n==Wr_n) 
						begin
						state<=8'd7; //循环写完毕，准备开始下一个读操作
						n<=8'd1;
						cnt<=22'd23;
						end
					else if(n < Wr_n)
						begin
						n		<=n+1;
						state	<=8'd1; //返回状态1循环写
						end
				end
///////////////////////////////////////////////////////////////读寄存器////////////////////////////						
		8'd7:	begin //等待23个时钟周期后再进行下一个读操作
				if(cnt==22'd0)
					begin
					state<=8'd8; 
					cnt	<=22'd23;
					end
				else
					begin
					cnt	<=cnt-1'b1;
					state	<=8'd7;
					end
				end
////////////////////////////////////////////////////////////////////////////////////				
		8'd8:	begin //开始读操作，先写入3位指令+13位地址
					cs_b	<=1'b0;
					sclk	<=1'b0;
					Tri_en  <=1'b1;
					if(m==8'd1)
						sdout	<=RdAddr1[cnt];
					else if(m==8'd2)
						sdout	<=RdAddr2[cnt];
					else if(m==8'd3)
						sdout	<=RdAddr3[cnt];
					else if(m==8'd4)
						sdout	<=RdAddr4[cnt];
			
					state	<=8'd9;	
				end		
		8'd9:	begin //循环写入直到写入16bit，在最后一个sclk下降沿即将写入第10bit地址
					sclk	<=1'b1;
					if(cnt==22'd8) //这里需要注意当cnt为8时，16bit写完，在接下来的sclk下降沿ADC开始输出寄存器数据，此时FPGA
						begin	   //的三态门要变为输入，接收数据进行
						state<=8'd10; //读等待状态
						cnt		<=22'd7; //读数cnt要赋值为7，因为对于adc读出是8bit，所以只需要接收7个移位即可。
						end
					else
						begin
						cnt	<=cnt-1'b1;
						state	<=8'd8;
						end
				end	
		8'd10:	begin //在sclk下降沿，三态变为输入
					sclk	<=1'b0; //下降沿ADC输出数据开始，因为FPGA在sclk上升沿读取，等待数据稳定
					cs_b	<=1'b0;
					Tri_en  <=1'b0; //状态转换
					state	<=8'd11;
					
				end	
		8'd11:	begin //在sclk上升沿，开始读取
					
					sclk	<=1'b1;
					
					if(cnt==22'd0) //8bit读完
						begin
						state<=8'd12; //读完毕状态
						end
					else
						begin
						cnt	<=cnt-1'b1;
						state	<=8'd10;
						end
						
					if((cnt<=22'd7)&&m==8'd1) //当cnt为7时，因为前面写入16bit的读指令和地址，
						begin		          //把地址和数据在接下来的8个clk内
							RdData1	<={RdData1[6:0],sdin}; //移位寄存读取串行数据
						end		
					if((cnt<=22'd7)&&m==8'd2) 
						begin		
							RdData2	<={RdData2[6:0],sdin};
						end	
					if((cnt<=22'd7)&&m==8'd3) 
						begin		
							RdData3	<={RdData3[6:0],sdin};
						end	
					if((cnt<=22'd7)&&m==8'd4) 
						begin		
							RdData4	<={RdData4[6:0],sdin};
						end	
				end	

				
		8'd12:	begin //拉高相关信号
					sclk	<=1'b1;
					cs_b	<=1'b1;
					state	<=8'd13;
					cnt		<=22'd23;
				end				
				
					
		8'd13:	begin //读完一个地址数据之后等待24个时钟周期
				if(cnt==22'd0)
						begin
						state<=8'd14;
						end
					else
						begin
						cnt	<=cnt-1'b1;
						cs_b	<=1'b1;
						sclk	<=1'b1;
						sdout	<=1'b1;
						state	<=8'd13;
						end			
				end				
		8'd14:	begin      //判断读写是否完成，没有的话返回状态8继续
				if(m==Rd_n) //读完一个地址数据的读操作即算完成。
						begin
						state<=8'd15;
						m<=8'd1;
						cnt<=22'd23;
						end
				else
						begin
						m		<=m+1;
						state	<=8'd8;
						cnt		<=22'd23;
						end
				end							
		8'd15:	begin
					// (原被注释掉的逻辑)
					state		<=8'd15;
				end	
		default:	state	<=8'd16;			
	endcase
endmodule
				