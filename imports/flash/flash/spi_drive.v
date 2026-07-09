`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/07/16 21:39:18
// Design Name: 
// Module Name: spi_drive
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


module spi_drive#(
    parameter                           P_DATA_WIDTH        = 8 ,
                                        P_OP_LEN            = 32,
                                        P_READ_DATA_WIDTH   = 8 , 
                                        P_CPOL              = 0 ,
                                        P_CPHL              = 0 
)(                  
    input                               i_clk               ,//系统时钟
    input                               i_rst               ,//复位

    output                              o_spi_clk           ,//spi的clk
    output                              o_spi_cs            ,//spi的片�??
    output                              o_spi_mosi          ,//spi的主机输�??
    input                               i_spi_miso          ,//spi的从机输�??

    input   [P_OP_LEN - 1 :0]           i_user_op_data      ,//操作数据（指�??8bit+地址24bit�??
    input   [1 :0]                      i_user_op_type      ,//操作类型（读、写、指令）
    input   [15:0]                      i_user_op_len       ,//操作数据的长�??32�??8
    input   [15:0]                      i_user_clk_len      ,//时钟周期
    input                               i_user_op_valid     ,//用户的有效信�??
    output                              o_user_op_ready     ,//用户的准备信�??

    input   [P_DATA_WIDTH - 1 :0]       i_user_write_data   ,//写数�??
    output                              o_user_write_req    ,//写数据请�??

    output  [P_READ_DATA_WIDTH - 1:0]   o_user_read_data    ,//读数�??
    output                              o_user_read_valid    //读数据有�??
);

/***************function**************/

/***************parameter*************/
localparam                              P_OP_TYPE_INS   =   0,
                                        P_OP_READ       =   1,
                                        P_OP_WRITE      =   2;
/***************port******************/             

/***************mechine***************/

/***************reg*******************/
reg                                 ro_spi_clk          ;
reg                                 ro_spi_cs           ;
reg                                 ro_spi_mosi         ;
reg                                 ro_user_ready       ;
reg  [P_OP_LEN - 1:0]               r_user_op_data      ;
reg  [1 :0]                         r_user_op_type      ;
reg  [15:0]                         r_user_op_len       ;
reg  [15:0]                         r_user_clk_len      ;
reg  [P_DATA_WIDTH - 1:0]           r_user_data         ;
reg                                 r_run               ;
reg  [15:0]                         r_cnt               ;
reg                                 r_spi_cnt           ;
reg  [P_READ_DATA_WIDTH - 1:0]      ro_user_read_data   ;
reg                                 ro_user_read_valid  ;
reg                                 r_run_1d            ;
reg                                 ro_user_write_req   ;
reg                                 ro_user_write_req_1d;
reg  [15:0]                         r_write_cnt         ;
reg  [P_DATA_WIDTH - 1 :0]          r_user_write_data   ;
reg  [15:0]                          r_read_cnt          ;

/***************wire******************/
wire                                w_user_active       ;
wire                                w_run_negedge       ;

/***************component*************/

/***************assign****************/
assign o_spi_clk            = ro_spi_clk            ;
assign o_spi_cs             = ro_spi_cs             ;
assign o_spi_mosi           = ro_spi_mosi           ;
assign o_user_op_ready      = ro_user_ready         ;
assign o_user_read_data     = ro_user_read_data     ;
assign o_user_read_valid    = ro_user_read_valid    ;
assign w_run_negedge        = !r_run & r_run_1d     ;
assign o_user_write_req     = ro_user_write_req     ;

/***************always****************/
assign w_user_active = i_user_op_valid & o_user_op_ready;

//控制准备信号
always@(posedge i_clk)
begin
    if(i_rst)
        ro_user_ready <='d1;
    else if(w_user_active)
        ro_user_ready <= 'd0;
    else if(w_run_negedge)
        ro_user_ready <= 'd1;
    else 
        ro_user_ready <= ro_user_ready;
end

//操作总线�??活寄存数�??
always@(posedge i_clk)
begin
    if(i_rst) begin
        r_user_op_type <= 'd0;
        r_user_op_len  <= 'd0;
        r_user_clk_len <= 'd0;
    end else if(w_user_active) begin
        r_user_op_type <= i_user_op_type;
        r_user_op_len  <= i_user_op_len ;
        r_user_clk_len <= i_user_clk_len;
    end else begin 
        r_user_op_type <= r_user_op_type;
        r_user_op_len  <= r_user_op_len ;
        r_user_clk_len <= r_user_clk_len;
    end   
end

always@(posedge i_clk)
begin
    if(i_rst)
        r_user_op_data <= 'd0;
    else if(w_user_active)
        r_user_op_data <= i_user_op_data;//指令8bit + 24bit地址
    else if(r_spi_cnt)//spi输出时，并转
        r_user_op_data <= r_user_op_data << 1;
    else 
        r_user_op_data <= r_user_op_data;
end

//总线运行标志
always@(posedge i_clk)
begin
    if(i_rst)
        r_run <= 'd0;
    else if(r_spi_cnt && r_cnt == r_user_clk_len - 1)
        r_run <= 'd0;
    else if(w_user_active)
        r_run <= 'd1;
    else 
        r_run <= r_run;
end

always@(posedge i_clk)
begin
    if(i_rst)
        r_run_1d <= 'd0;
    else
        r_run_1d <= r_run;
end

//spi时钟周期计数�??
always@(posedge i_clk)
begin
    if(i_rst)
        r_cnt <= 'd0;
    else if(r_spi_cnt && r_cnt == r_user_clk_len - 1)
        r_cnt <= 'd0;
    else if(r_spi_cnt)
        r_cnt <= r_cnt + 1;
    else 
        r_cnt <= r_cnt;
end

//spi时钟计数�??
always@(posedge i_clk)
begin
    if(i_rst)
        r_spi_cnt <= 'd0;
    else if(r_run)
        r_spi_cnt <= r_spi_cnt + 1;
    else 
        r_spi_cnt <= 'd0;
end

//spi时钟信号
always@(posedge i_clk)
begin
    if(i_rst)
        ro_spi_clk <= P_CPOL;
    else if(r_run)
        ro_spi_clk <= ~ro_spi_clk;
    else 
        ro_spi_clk <= P_CPOL; 
end

//spi片�?�信�??
always@(posedge i_clk)
begin
    if(i_rst)
        ro_spi_cs <= 'd1;
    else if(w_user_active)
        ro_spi_cs <= 'd0;
    else if(!r_run)
        ro_spi_cs <= 'd1;
    else 
        ro_spi_cs <= ro_spi_cs;
end

//spi输出引脚
always@(posedge i_clk)
begin
    if(i_rst)
        ro_spi_mosi <= 'd0;
    else if(w_user_active)//输出操作数据�??高位 指令+地址
        ro_spi_mosi <= i_user_op_data[P_OP_LEN - 1];//operation
    else if(r_spi_cnt && r_cnt < r_user_op_len - 1)//依次输出操作数据次高�??
        ro_spi_mosi <= r_user_op_data[P_OP_LEN - 2];
    else if(r_user_op_type == P_OP_WRITE && r_spi_cnt)//串行输出写数�??
        ro_spi_mosi <= r_user_write_data[7];
    else 
        ro_spi_mosi <= ro_spi_mosi;
end     


always@(posedge i_clk)
begin
    if(i_rst)
        ro_user_write_req <= 'd0;
    else if(r_cnt >= r_user_clk_len - 5)
        ro_user_write_req <= 'd0;
    else if(((!r_spi_cnt && r_cnt == 30) || r_write_cnt == 15) &&  r_user_op_type == P_OP_WRITE )
        ro_user_write_req <= 'd1;
    else 
        ro_user_write_req <= 'd0;
end

always@(posedge i_clk)
begin
    if(i_rst)
        ro_user_write_req_1d <= 'd0;
    else 
        ro_user_write_req_1d <= ro_user_write_req;
end

always@(posedge i_clk)
begin
    if(i_rst)
        r_user_write_data <= 'd0;
    else if(ro_user_write_req_1d)
        r_user_write_data <= i_user_write_data;
    else if(r_spi_cnt)
        r_user_write_data <= r_user_write_data << 1;
    else 
        r_user_write_data <= r_user_write_data;
end

always@(posedge i_clk)
begin
    if(i_rst)
        r_write_cnt <= 'd0;
    else if(r_write_cnt == 15 || ro_spi_cs)
        r_write_cnt <= 'd0;
    else if(ro_user_write_req || r_write_cnt)
        r_write_cnt <= r_write_cnt + 1;
    else 
        r_write_cnt <= r_write_cnt;
end

//读数�??
always@(posedge ro_spi_clk)
begin
    if(i_rst)
        ro_user_read_data <= 'd0;
    else if(r_cnt >= r_user_op_len - 1)
        ro_user_read_data <= {ro_user_read_data[P_DATA_WIDTH - 2 : 0],i_spi_miso};
    else 
        ro_user_read_data <= ro_user_read_data;
end

always@(posedge i_clk)
begin
    if(i_rst)
        r_read_cnt <= 'd0;
    else if(r_read_cnt == 8 || ro_spi_cs)
        r_read_cnt <= 'd0;
    else if(r_spi_cnt && r_cnt >= r_user_op_len - 0 && r_user_op_type == P_OP_READ)
        r_read_cnt <= r_read_cnt + 1;
    else 
        r_read_cnt <= r_read_cnt;
end

//读数据有�??
always@(posedge i_clk) 
begin
    if(i_rst)
        ro_user_read_valid <= 'd0;
    else if(r_spi_cnt && r_read_cnt == 7 && r_user_op_type == P_OP_READ)
        ro_user_read_valid <= 'd1;
    else 
        ro_user_read_valid <= 'd0;
end

endmodule
