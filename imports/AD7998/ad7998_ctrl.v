`timescale 1ns / 1ps
 
module ad7998_ctrl(
input                               SysClk                     ,
input                               SysReset_p                 ,
inout                               sda                        ,//总线数据
(*mark_debug = "TRUE" *)output                              scl                        ,//总线时钟
(*mark_debug = "TRUE" *)output reg                          convst                     ,//转换启动信号
input                               Alt_busy                   ,
(*mark_debug = "TRUE" *)output             [  15:0]         o_rd_data                  ,//读出数据
(*mark_debug = "TRUE" *)output                              o_rd_data_vaild             
);

/*************************************************************************
变量定义
****************************************************************************/
(*mark_debug = "TRUE" *)reg               [   4:0]         conv_state                 ;
reg               [  31:0]         clk_cnt                    ;
(*mark_debug = "TRUE" *)reg                                i_rd_en                    ;
(*mark_debug = "TRUE" *)reg                                i_wr_en                    ;
(*mark_debug = "TRUE" *)wire                               o_cfg_done                 ;
(*mark_debug = "TRUE" *)reg                                i2c_start                  ;
reg               [  15:0]         i_wr_data                  ;
reg               [   7:0]         i_reg_addr                 ;
wire              [   6:0]         DEVICE_ADDR                ;
reg               [   7:0]         timeout_cnt                ;
reg               [   3:0]         addr_cnt                   ;
reg               [  15:0]         rd_temp_reg                ;

localparam Second_1Count=100_000_000;//100MHz时钟 计1s
localparam uSecond_1Count=100;//100MHz时钟 计1us

/*************************************************************************
读写寄存器VIO控制
****************************************************************************/
wire rd_flag;
wire wr_flag;
reg  conv_test_mode=0; //0自动执行 1通过VIO控制
reg [1:0] rd_flag_temp=0;
reg [1:0] wr_flag_temp=0;

/* vio_ad7998 u_vio_ad7998 (
.clk                               (SysClk                    ),// input wire clk
.probe_out0                        (rd_flag                   ),// output wire [0 : 0] probe_out0
.probe_out1                        (wr_flag                   ),// output wire [0 : 0] probe_out1
.probe_out2                        (DEVICE_ADDR               ),// output wire [6 : 0] probe_out2
.probe_out3                        (			              ) // output wire [0 : 0] probe_out3 conv_test_mode 测试用
); */

always@(posedge SysClk)
begin
	rd_flag_temp[1]<=rd_flag_temp[0]; rd_flag_temp[0]<=rd_flag;
	wr_flag_temp[1]<=wr_flag_temp[0]; wr_flag_temp[0]<=rd_flag;
end

/*************************************************************************
AD7998 控制主状态机
****************************************************************************/
always@(posedge SysClk)
begin
	if(SysReset_p)
		begin
			conv_state<=0;
			convst<=0;
			i_rd_en<=0;
			i_wr_en<=0;
			addr_cnt<=0;
			rd_temp_reg<=0;
			clk_cnt<=0;
			timeout_cnt<=0;
			i2c_start<=0;
			i_reg_addr<=8'b0;
			i_wr_data<=16'h001B;//$ 配置寄存器：0000_0000_0001_1011
			conv_test_mode=0;
		end
	else
		begin
			case(conv_state)
				5'd0://IDLE 空闲
					begin
						if(conv_test_mode)
							begin
								if(rd_flag_temp==2'b01)
									begin
										conv_state<=conv_state+1;
										addr_cnt<=0;
									end
								else if(wr_flag_temp==2'b01)
									begin
										conv_state<=conv_state+6;
										addr_cnt<=0;
									end
								else conv_state<=conv_state;
							end
						else
							begin
								addr_cnt<=0;
								conv_state<=conv_state+1;
							end
					end
				5'd1://准备读寄存器地址 写入 地址指针寄存器
					begin
						i_rd_en<=1;
						conv_state<=conv_state+1;
						case(addr_cnt)
							0: i_reg_addr <= 8'b0000_0000;//转换结果寄存器 2Byte
							1: i_reg_addr <= 8'b0000_0010;//配置寄存器 2Byte
							default:i_reg_addr <= 8'b0;
						endcase
					end
				5'd2://开始工作
					begin
						i2c_start<=1;
						i_rd_en<=0;
						i_wr_en<=0;
						addr_cnt<=addr_cnt+1;
						conv_state<=conv_state+1;
					end
				5'd3://等待读数据有效
					begin
						i2c_start<=0;
						if(o_rd_data_vaild)
							begin
								rd_temp_reg<=o_rd_data;//存储寄存器数据
								conv_state<=15;
								clk_cnt<=0;
							end
						else //读取超时情况
							begin
								if(clk_cnt>=3*Second_1Count)
									begin	
										clk_cnt<=0;
										conv_state<=0; //返回IDLE状态
										timeout_cnt<=timeout_cnt+1;//记录超时次数
									end
								else
									begin
										clk_cnt<=clk_cnt+1;
										conv_state<=conv_state;
									end
							end
					end
				5'd15://一次读寄存器结束
					begin
						if(o_cfg_done) conv_state<=4;
						else conv_state<= conv_state;
					end
				5'd4://判断所有寄存器是否读完 没读完更新寄存器地址再读
					begin
						if(addr_cnt>=2)	begin conv_state<=conv_state+1;end
						else conv_state<=conv_state-3;
					end
				5'd5://所以寄存器读完后 回到IDLE 等待写标志
					begin 
						if(conv_test_mode) begin conv_state<=0; addr_cnt<=0; end
						else begin conv_state<=conv_state+1; addr_cnt<=0; end
					end
				5'd6://写寄存器
					begin
						i_wr_en<=1;
						conv_state<=conv_state+1;
						case(addr_cnt)
							0: begin i_reg_addr <= 8'b0000_0010; i_wr_data <= 16'h001B; end //$ 写配置寄存器：选择模拟转换通道CH1 开启滤波功能 ALT/BUSY引脚输出BUSY信号(高有效)
							default: begin i_reg_addr <= 8'b0000_0010; i_wr_data <= 16'h001B; end
						endcase
					end
				5'd7://开始工作
					begin
						i2c_start<=1;
						i_rd_en<=0;
						i_wr_en<=0;
						conv_state<=conv_state+1;
						addr_cnt<=addr_cnt+1;
					end
				5'd8://等待写入寄存器结束
					begin
						i2c_start<=0;
						if(o_cfg_done)
							begin
								conv_state<=conv_state+1;
								clk_cnt<=0;
							end
						else //写入超时情况
							begin
								if(clk_cnt>=3*Second_1Count)
									begin
										clk_cnt<=0;
										conv_state<=0; //返回IDLE状态
										timeout_cnt<=timeout_cnt+1;//记录超时次数
									end
								else
									begin
										clk_cnt<=clk_cnt+1;
										conv_state<=conv_state;
									end
							end
					end
				5'd9://判断所有寄存器是否写完 寄存器配置完成后 开始AD7998的一次转换
					begin
						if(addr_cnt>=1)	begin conv_state<=conv_state+1;end
						else conv_state<=conv_state-3;
					end
				5'd10://开启转换过程 convst信号高电平必须至少保持1us以确保系统完全上电 convst下降沿使得采保进入保持模式
					begin
						convst<=1;
						if(clk_cnt>=uSecond_1Count*2)
							begin
								convst<=0;
								clk_cnt<=0;
								conv_state<=conv_state+1;
							end
						else
							begin
								clk_cnt<=clk_cnt+1;
								conv_state<=conv_state;
							end
							
					end
				5'd11://等待一次转换完成的时间近似2us
					begin
						if(clk_cnt>=uSecond_1Count*3)
							begin
								clk_cnt<=0;
								conv_state<=conv_state+1;
							end
						else
							begin
								clk_cnt<=clk_cnt+1;
								conv_state<=conv_state;
							end
					end
				5'd12://读转换结果寄存器里的量化值
					begin
						i_rd_en<=1;
						i_reg_addr<=8'b0; //不需要case 只读转换结果寄存器 地址8'b0
						conv_state<=conv_state+1;
					end
				5'd13://开始工作
					begin
						i2c_start<=1;
						i_rd_en<=0;
						i_wr_en<=0;
						conv_state<=conv_state+1;
					end
				5'd14://等待读数据有效
					begin
						i2c_start<=0;
						if(o_rd_data_vaild)
							begin
								rd_temp_reg<=o_rd_data;//存储寄存器数据
								conv_state<=conv_state+2;
								clk_cnt<=0;
							end
						else //读取超时情况
							begin
								if(clk_cnt>=3*Second_1Count)
									begin	
										clk_cnt<=0;
										conv_state<=0; //返回IDLE状态
										timeout_cnt<=timeout_cnt+1;//记录超时次数
									end
								else
									begin
										clk_cnt<=clk_cnt+1;
										conv_state<=conv_state;
									end
							end
					end
				5'd16://一次转换和读寄存器结束 自动进入下一次转换和读取
					begin
						if(o_cfg_done)
							begin
								if(conv_test_mode) begin conv_state<=0; addr_cnt<=0; end//测试模式下只触发一次
								else conv_state<=10;
							end
						else conv_state<= conv_state;
					end

				default:conv_state<=0;
			endcase
		end

 end
 
/*************************************************************************
总线读写控制模块
****************************************************************************/
iic_comm #(
.SYS_CLOCK                         (32'd100_000_000           ),//系统时钟频率 100MHz
.SCL_CLOCK                         (20'd100_000               ) //SCL时钟频率 100kHz
)
u_iic_comm
(
.i_clk                             (SysClk                    ),//input 系统时钟 100MHz
.i_rst_n                           (!SysReset_p               ),//input 复位信号 低有效
.i_wr_en                           (i_wr_en                   ),//input 写使能信号
.i_rd_en                           (i_rd_en                   ),//input 读使能信号
.i_dev_addr                        (7'b010_0011               ),//input 设备地址 DEVICE_ADDR 测试时与VIO连接
.i_reg_addr_num                    (2'd1                      ),//input 寄存器地址字节数
.i_reg_addr                        ({8'b0,i_reg_addr}         ),//input 寄存器地址
.i_wr_data                         (i_wr_data                 ),//input 写入寄存器数据
.i_wr_data_num                     (2'd2                      ),//input 写入寄存器数据字节数
.o_rd_data_vaild                   (o_rd_data_vaild           ),//output 读出寄存器数据有效
.o_rd_data                         (o_rd_data                 ),//output 读出寄存器数据
.i_rd_data_num                     (2'd2                      ),//output 读出寄存器数据字节数
.o_cfg_done                        (o_cfg_done                ),//output iic一次读写操作完成
.o_SCL                             (scl                       ),//output i2c设备的串行时钟信号scl
.io_SDA                            (sda                       ) //output i2c设备的串行数据信号sda
);

endmodule
