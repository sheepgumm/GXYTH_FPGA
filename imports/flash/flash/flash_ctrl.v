`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////
`include "top_define.vh"

module flash_ctrl#(
    parameter                           P_DATA_WIDTH        = 8 ,//数据位宽
                                        P_OP_LEN            = 32,//指令长度
                                        P_READ_DATA_WIDTH   = 8 ,//读数据位�?
                                        P_CPOL              = 0 ,//空闲时时钟状�?
                                        P_CPHL              = 0  //采集数据时钟�?
)(
  input                               i_clk                   ,//用户时钟
    input                               i_rst                   ,//用户复位

    /*--------用户接口--------*/    
 input  [1 :0]                       i_operation_type        ,//操作类型
    input  [23:0]                       i_operation_addr        ,//操作地址
    input  [8 :0]                       i_operation_num         ,//限制用户每次�?多写256字节
   input                               i_operation_valid       ,//操作握手有效
  output                              o_operation_ready       ,//操作握手准备

    input  [P_DATA_WIDTH - 1 :0]        i_write_data            ,//写数�?
    input                               i_write_sop             ,//写数�?-�?始信�?
    input                               i_write_eop             ,//写数�?-结束信号
    input                               i_write_valid           ,//写数�?-有效信号

    output [P_DATA_WIDTH - 1 :0]        o_read_data             ,//读数�?
    output                              o_read_sop              ,//读数�?-�?始信�?
    output                              o_read_eop              ,//读数�?-结束信号
    output                              o_read_valid            ,//读数�?-有效信号

    /*--------驱动接口--------*/    
   output   [P_OP_LEN - 1 :0]          o_user_op_data          ,//操作数据（指�?8bit+地址24bit�?
  output   [1 :0]                     o_user_op_type          ,//操作类型（读、写、指令）
    output   [15:0]                     o_user_op_len           ,//操作数据的长�?32�?8
    output   [15:0]                     o_user_clk_len          ,//时钟周期
 output                              o_user_op_valid         ,//用户的有效信�?
  input                               i_user_op_ready         ,//用户的准备信�?

    output  [P_DATA_WIDTH - 1 :0]       o_user_write_data       ,//写数�?
    input                               i_user_write_req        ,//写数据请�?

    input   [P_READ_DATA_WIDTH - 1:0]   i_user_read_data        ,//读数�?
    input                               i_user_read_valid        //读数据有�?
);

/***************function**************/

/***************parameter*************/
//用户接口操作类型
localparam                          P_TYPE_CLEAR    =   0   ,
                                    P_TYPE_WRITE    =   1   ,
                                    P_TYPE_READ     =   2   ;

//SPI总线驱动器操作类�?
localparam                          P_OP_TYPE_INS   =   0,
                                    P_OP_READ       =   1,
                                    P_OP_WRITE      =   2;

//状�?�机状�??
localparam                          P_IDLE          =   0   ,
                                    P_RUN           =   1   ,
                                    P_W_EN          =   2   ,
                                    P_W_INS         =   3   ,
                                    P_W_DATA        =   4   ,
                                    P_R_INS         =   5   ,
                                    P_R_DATA        =   6   ,
                                    P_CLEAR         =   7   ,
                                    P_BUSY          =   8   ,
                                    P_BUSY_CHECK    =   9   ,
                                    P_BUSY_WAIT     =   10  ;
/***************port******************/             

/***************mechine***************/
//状�?�机
reg  [7 :0]                         r_st_current        ;
reg  [7 :0]                         r_st_next           ;
reg  [7 :0]                         r_st_cnt            ;


/***************reg*******************/
reg  [1 :0]                         ri_operation_type   ;
reg  [23:0]                         ri_operation_addr   ;
reg  [8 :0]                         ri_operation_num    ;
reg  [P_DATA_WIDTH - 1 :0]          ri_write_data       ;
reg                                 ri_write_sop        ;
reg                                 ri_write_eop        ;
reg                                 ri_write_valid      ;
reg                                 r_user_ready_1d     ;
reg  [P_OP_LEN - 1 :0]              ro_user_op_data     ;
reg  [1 :0]                         ro_user_op_type     ;
reg  [15:0]                         ro_user_op_len      ;
reg  [15:0]                         ro_user_clk_len     ;
reg                                 ro_user_op_valid    ;
reg  [P_DATA_WIDTH - 1 :0]          ri_user_read_data   ;
reg                                 ri_user_read_valid  ;
reg                                 ro_operation_ready  ;
reg  [7 :0]                         ro_read_data        ;
reg                                 ro_read_sop         ;
reg                                 ro_read_eop         ;
reg                                 ro_read_valid       ;
 reg                                 r_fifo_read_rden    ;
reg                                 r_fifo_read_rden_1d ;
reg                                 r_fifo_read_pos     ;
reg                                 r_fifo_read_emp_1d  ;
 reg                                 r_fifo_read_wren    ;

/***************wire******************/
wire                                w_operation_active  ;
wire                                w_user_ready_pos    ;
wire                                w_spi_drive_act     ;
 wire                                w_fifo_read_empty   ;
wire [7 :0]                         w_read_data         ;

/***************component*************/
`ifdef VIVADO
    FLASH_CTRL_FIFO_DATA FLASH_CTRL_FIFO_DATA_U0 (
    .clk      (i_clk              ),  
    .srst     (i_rst              ),  
    .din      (ri_write_data      ),  
    .wr_en    (ri_write_valid     ),  
    .rd_en    (i_user_write_req   ),  
    .dout     (o_user_write_data  ),  
    .full     (), 
    .empty    ()  
    );

    FLASH_CTRL_FIFO_DATA FLASH_CTRL_FIFO_DATA_READ_U0 (
    .clk      (i_clk              ), 
    .srst     (i_rst              ), 
    .din      (ri_user_read_data  ), 
    .wr_en    (r_fifo_read_wren   ), 
    .rd_en    (r_fifo_read_rden   ), 
    .dout     (w_read_data        ), 
    .full     (),    
    .empty    (w_fifo_read_empty  )  
    );
`elsif QUARTUS
    FLASH_CTRL_FIFO_DATA FLASH_CTRL_FIFO_DATA_U0(
	    .clock  (i_clk              ),
	    .data   (ri_write_data      ),
	    .rdreq  (i_user_write_req   ),
	    .wrreq  (ri_write_valid     ),
	    .empty  (),
	    .full   (),
	    .q      (o_user_write_data  )
    );

    FLASH_CTRL_FIFO_DATA FLASH_CTRL_FIFO_DATA_READ_U0(
	    .clock  (i_clk                  ),
	    .data   (ri_user_read_data      ),
	    .rdreq  (r_fifo_read_rden       ),
	    .wrreq  (r_fifo_read_wren       ),
	    .empty  (w_fifo_read_empty      ),
	    .full   (),
	    .q      (w_read_data            )
    );

`endif

/***************assign****************/
assign w_operation_active   = i_operation_valid & o_operation_ready ;
assign w_user_ready_pos     = r_user_ready_1d & i_user_op_ready     ;
assign o_user_op_data       = ro_user_op_data                       ;
assign o_user_op_type       = ro_user_op_type                       ;
assign o_user_op_len        = ro_user_op_len                        ;
assign o_user_clk_len       = ro_user_clk_len                       ;
assign o_user_op_valid      = ro_user_op_valid                      ;
assign o_operation_ready    = ro_operation_ready                    ;
 assign w_spi_drive_act      = o_user_op_valid & i_user_op_ready     ;
// assign o_read_data          = ro_read_data                          ; 
assign o_read_sop           = ro_read_sop                           ; 
assign o_read_eop           = ro_read_eop                           ; 
assign o_read_valid         = ro_read_valid                         ; 
assign o_read_data          = ro_read_data                          ;

/***************always****************/
//状�?�机跳转
always@(posedge i_clk)
begin
    if(i_rst)
        r_st_current <= P_IDLE;
    else
        r_st_current <= r_st_next;
end

//跳转条件
always@(*)
begin
    case(r_st_current)
        P_IDLE          : r_st_next = w_operation_active    ? P_RUN    : P_IDLE    ;                //空闲状�?�，用户�?活时跳转
        P_RUN           : r_st_next = ri_operation_type  == P_TYPE_READ ? P_R_INS  : P_W_EN     ;   //�?始运行状态机，读/�?
        P_W_EN          : r_st_next = w_spi_drive_act       ? 
                                      ri_operation_type  == P_TYPE_WRITE ? P_W_INS : P_CLEAR         //判断是写数据还是擦除
                                      : P_W_EN    ;//写使能状�?
        P_W_INS         : r_st_next = w_spi_drive_act       ? P_W_DATA : P_W_INS   ;                //写数据指令状�?
        P_W_DATA        : r_st_next = i_user_op_ready       ? P_BUSY   : P_W_DATA  ;                //写数�?
        P_R_INS         : r_st_next = w_spi_drive_act       ? P_R_DATA : P_R_INS   ;                //读数据指令状�?
        P_R_DATA        : r_st_next = i_user_op_ready       ? P_BUSY   : P_R_DATA  ;                //读数�?
        P_CLEAR         : r_st_next = w_spi_drive_act       ? P_BUSY   : P_CLEAR   ;                
        P_BUSY          : r_st_next = w_spi_drive_act       ? P_BUSY_CHECK : P_BUSY  ;              //读状态寄存器
        P_BUSY_CHECK    : r_st_next = ri_user_read_valid    ? 
                                      i_user_read_data[0]   ? P_BUSY_WAIT : P_IDLE  
                                      : P_BUSY_CHECK        ;                                       //根据返回的状态�?�，判断是否繁忙
        P_BUSY_WAIT     : r_st_next = r_st_cnt == 255       ? P_BUSY       : P_BUSY_WAIT ;          //等待255个周期，重启读忙
        default         : r_st_next = P_W_EN; 
    endcase
end  

always@(posedge i_clk)
begin
    if(i_rst)
        r_st_cnt <= 'd0;
    else if(r_st_current != r_st_next)
        r_st_cnt <= 'd0;
    else 
        r_st_cnt <= r_st_cnt + 1;
end
/*--------驱动逻辑--------*/
//第三段状态机
always@(posedge i_clk)
begin
    if(i_rst) begin
        ro_user_op_data  <= 'd0;
        ro_user_op_type  <= 'd0;
        ro_user_op_len   <= 'd0;
        ro_user_clk_len  <= 'd0;
        ro_user_op_valid <= 'd0;
    end else if(r_st_current == P_W_EN) begin           //发�?�写使能指令
        ro_user_op_data  <= {8'h06,8'h00,8'h00,8'h00};
        ro_user_op_type  <= P_OP_TYPE_INS;
        ro_user_op_len   <= 8;
        ro_user_clk_len  <= 8;
        ro_user_op_valid <= 'd1;
    end else if(r_st_current == P_W_INS) begin          //发�?�写数据指令
        ro_user_op_data  <= {8'h02,ri_operation_addr};
        ro_user_op_type  <= P_OP_WRITE;
        ro_user_op_len   <= 32;
        ro_user_clk_len  <= 32 + 8 * ri_operation_num;
        ro_user_op_valid <= 'd1;
        /////////
//    end else if(r_st_current == P_R_INS) begin
//    if (ri_operation_addr == 24'hFF_FF_FF) begin
//        // ===== RDID: 0x9F, no address =====
//        ro_user_op_data  <= {8'h9F, 24'h00_00_00};      // op_data��Ȼ32bit��������
//        ro_user_op_type  <= P_OP_READ;
//        ro_user_op_len   <= 16'd8;                      // ֻ��8bitָ��
//        ro_user_clk_len  <= 16'd8 + 16'd8 * ri_operation_num; // �ٶ�N�ֽ�
//        ro_user_op_valid <= 1'b1;
//    end else begin
//        // ===== Normal READ: 0x03 + 24bit address =====
//        ro_user_op_data  <= {8'h03,ri_operation_addr};
//        ro_user_op_type  <= P_OP_READ;
//        ro_user_op_len   <= 16'd32;
//        ro_user_clk_len  <= 16'd32 + 16'd8 * ri_operation_num;
//        ro_user_op_valid <= 1'b1;
//    end
    end else if(r_st_current == P_R_INS) begin          //发�?�读数据指令
        ro_user_op_data  <= {8'h03,ri_operation_addr};
        ro_user_op_type  <= P_OP_READ;
        ro_user_op_len   <= 32;
        ro_user_clk_len  <= 32 + 8 * ri_operation_num;
        ro_user_op_valid <= 'd1;
    end else if(r_st_current == P_CLEAR) begin          //发�?�擦除指�?
//        ro_user_op_data  <= {8'h20,ri_operation_addr}; ////////////////////////////////////////////
        ro_user_op_data  <= {8'h20,ri_operation_addr};
        ro_user_op_type  <= P_OP_TYPE_INS;
        ro_user_op_len   <= 32;
        ro_user_clk_len  <= 32;
        ro_user_op_valid <= 'd1;
    end else if(r_st_current == P_BUSY) begin           //发�?�读状�??-BUSY
        ro_user_op_data  <= {8'h05,24'd0};
        ro_user_op_type  <= P_OP_READ;
        ro_user_op_len   <= 8;
        ro_user_clk_len  <= 16;
        ro_user_op_valid <= 'd1;
    end else begin
        ro_user_op_data  <= ro_user_op_data;
        ro_user_op_type  <= ro_user_op_type;
        ro_user_op_len   <= ro_user_op_len ;
        ro_user_clk_len  <= ro_user_clk_len;
        ro_user_op_valid <= 'd0;
    end
end

always@(posedge i_clk)
begin
    if(i_rst)
        r_user_ready_1d <= 'd0;
    else 
        r_user_ready_1d <= i_user_op_ready;
end


always@(posedge i_clk)
begin
    if(i_rst) begin
        ri_user_read_data  <= 'd0;
        ri_user_read_valid <= 'd0;
    end else begin
        ri_user_read_data  <= i_user_read_data  ;
        ri_user_read_valid <= i_user_read_valid ;
    end
end

/*--------用户逻辑--------*/
always@(posedge i_clk)
begin
    if(i_rst) begin
        ri_operation_type <= 'd0;
        ri_operation_addr <= 'd0;
        ri_operation_num  <= 'd0;
    end else if(w_operation_active) begin
        ri_operation_type <= i_operation_type;
        ri_operation_addr <= i_operation_addr;
        ri_operation_num  <= i_operation_num ;
    end else  begin
        ri_operation_type <= ri_operation_type;
        ri_operation_addr <= ri_operation_addr;
        ri_operation_num  <= ri_operation_num ;
    end
end

always@(posedge i_clk)
begin
    if(i_rst)
        ro_operation_ready <= 'd1;
    else if(r_st_next == P_IDLE)
        ro_operation_ready <= 'd1;
    else if(w_operation_active)   
        ro_operation_ready <= 'd0;
    else 
        ro_operation_ready <= ro_operation_ready;
end


always@(posedge i_clk)
begin
    if(i_rst) begin
        ri_write_data  <= 'd0;
        ri_write_sop   <= 'd0;
        ri_write_eop   <= 'd0;
        ri_write_valid <= 'd0;
    end else begin 
        ri_write_data  <= i_write_data ;
        ri_write_sop   <= i_write_sop  ;
        ri_write_eop   <= i_write_eop  ;
        ri_write_valid <= i_write_valid;
    end
end

always@(posedge i_clk)
begin
    if(i_rst) 
        r_fifo_read_rden <= 'd0;
    else if(w_fifo_read_empty)
        r_fifo_read_rden <= 'd0;
    else if(r_st_current == P_R_DATA && r_st_next != P_R_DATA)
        r_fifo_read_rden <= 'd1;
    else 
        r_fifo_read_rden <= r_fifo_read_rden;
end

always@(posedge i_clk)
begin
    if(i_rst) 
        r_fifo_read_rden_1d <= 'd0;
    else 
        r_fifo_read_rden_1d <= r_fifo_read_rden;
end

always@(posedge i_clk)
begin
    if(i_rst)
        r_fifo_read_pos <= 'd0;
    else 
        r_fifo_read_pos <= !r_fifo_read_rden_1d && r_fifo_read_rden;
end

always@(posedge i_clk)
begin
    if(i_rst)
        r_fifo_read_emp_1d <= 'd0;
    else
        r_fifo_read_emp_1d <= w_fifo_read_empty;
end

always@(posedge i_clk)
begin
    if(i_rst) 
        ro_read_sop <= 'd0;
    else if(r_fifo_read_pos)
        ro_read_sop <= 'd1;
    else
        ro_read_sop <= 'd0;
end

always@(posedge i_clk)
begin
    if(i_rst) 
        ro_read_eop <= 'd0;
    else if(w_fifo_read_empty && !r_fifo_read_emp_1d && ro_read_valid)
        ro_read_eop <= 'd1;
    else 
        ro_read_eop <= 'd0;
end 

always@(posedge i_clk)
begin
    if(i_rst) 
        ro_read_valid <= 'd0;
    else if(ro_read_eop)
        ro_read_valid <= 'd0;
    else if(r_fifo_read_pos)
        ro_read_valid <= 'd1;
    else 
        ro_read_valid <= ro_read_valid;
end

always@(posedge i_clk)
begin
    if(i_rst)
        ro_read_data <= 'd0;
    else 
        ro_read_data <= w_read_data;
end


always@(posedge i_clk)
begin
    if(i_rst)
        r_fifo_read_wren <= 'd0;
    else if(r_st_current == P_R_DATA)
        r_fifo_read_wren <= i_user_read_valid;
    else 
        r_fifo_read_wren <= 'd0;
end
endmodule
