`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////


module flash_drive(
    input                               i_clk       ,
    input                               i_rst       ,

    /*--------用户接口--------*/
    input  [1 :0]                       i_operation_type        ,//操作类型
    input  [23:0]                       i_operation_addr        ,//操作地址
   input  [8 :0]                       i_operation_num         ,//限制用户每次�?多写256字节
    input                               i_operation_valid       ,//操作握手有效
    output                              o_operation_ready       ,//操作握手准备
    input  [7 :0]                       i_write_data            ,//写数�?
    input                               i_write_sop             ,//写数�?-�?始信�?
    input                               i_write_eop             ,//写数�?-结束信号
    input                               i_write_valid           ,//写数�?-有效信号
   output [7 :0]                       o_read_data             ,//读数�?
    output                              o_read_sop              ,//读数�?-�?始信�?
    output                              o_read_eop              ,//读数�?-结束信号
    output                              o_read_valid            ,//读数�?-有效信号
    /*--------SPI接口--------*/
   output                              o_spi_clk               ,//spi的clk
    output                              o_spi_cs                ,//spi的片�?
    output                              o_spi_mosi              ,//spi的主机输�?
   input                               i_spi_miso              //spi的从机输�?
);

wire [8:0] dgb_operation_num;
assign dgb_operation_num = i_operation_num;
wire [23:0] dgb_operation_addr;
assign  dgb_operation_addr = i_operation_addr;
wire [31:0]                             w_user_op_data          ;
wire [1 :0]                             w_user_op_type          ;
wire [15:0]                             w_user_op_len           ;
wire [15:0]                             w_user_clk_len          ;
wire                                    w_user_op_valid         ;
wire                                    w_user_op_ready         ;
wire [7 :0]                             w_user_write_data       ;
wire                                    w_user_write_req        ;
wire [7 :0]                             w_user_read_data        ;
wire                                    w_user_read_valid       ;

flash_ctrl#(
    .P_DATA_WIDTH               (8                  ),//数据位宽
    .P_OP_LEN                   (32                 ),//指令长度
    .P_READ_DATA_WIDTH          (8                  ),//读数据位�?
    .P_CPOL                     (0                  ),//空闲时时钟状�?
    .P_CPHL                     (0                  ) //采集数据时钟�?
)
flash_ctrl_u0
(
    .i_clk                      (i_clk              ),//用户时钟
    .i_rst                      (i_rst              ),//用户复位

/*--------user--------*/    
    .i_operation_type           (i_operation_type   ),//操作类型
    .i_operation_addr           (i_operation_addr   ),//操作地址
    .i_operation_num            (i_operation_num    ),//限制用户每次�?多写256字节
    .i_operation_valid          (i_operation_valid  ),//操作握手有效
    .o_operation_ready          (o_operation_ready  ),//操作握手准备
    .i_write_data               (i_write_data       ),//写数�?
    .i_write_sop                (i_write_sop        ),//写数�?-�?始信�?
    .i_write_eop                (i_write_eop        ),//写数�?-结束信号
    .i_write_valid              (i_write_valid      ),//写数�?-有效信号
    .o_read_data                (o_read_data        ),//读数�?
    .o_read_sop                 (o_read_sop         ),//读数�?-�?始信�?
    .o_read_eop                 (o_read_eop         ),//读数�?-结束信号
    .o_read_valid               (o_read_valid       ),//读数�?-有效信号
/*--------spi drive--------*/   
    .o_user_op_data             (w_user_op_data     ),//操作数据（指�?8bit+地址24bit�?
    .o_user_op_type             (w_user_op_type     ),//操作类型（读、写、指令）
    .o_user_op_len              (w_user_op_len      ),//操作数据的长�?32�?8
    .o_user_clk_len             (w_user_clk_len     ),//时钟周期
    .o_user_op_valid            (w_user_op_valid    ),//用户的有效信�?
    .i_user_op_ready            (w_user_op_ready    ),//用户的准备信�?
    .o_user_write_data          (w_user_write_data  ),//写数�?
    .i_user_write_req           (w_user_write_req   ),//写数据请�?
    .i_user_read_data           (w_user_read_data   ),//读数�?
    .i_user_read_valid          (w_user_read_valid  ) //读数据有�?
);

spi_drive#(
    .P_DATA_WIDTH               (8                  ),
    .P_OP_LEN                   (32                 ),
    .P_READ_DATA_WIDTH          (8                  ), 
    .P_CPOL                     (0                  ),
    .P_CPHL                     (0                  )
)
spi_drive_u0
(                                  
    .i_clk                      (i_clk              ),
    .i_rst                      (i_rst              ),
        
    .o_spi_clk                  (o_spi_clk          ),
    .o_spi_cs                   (o_spi_cs           ),
    .o_spi_mosi                 (o_spi_mosi         ),
    .i_spi_miso                 (i_spi_miso         ),

    .i_user_op_data             (w_user_op_data     ),
    .i_user_op_type             (w_user_op_type     ),
    .i_user_op_len              (w_user_op_len      ),
    .i_user_clk_len             (w_user_clk_len     ),
    .i_user_op_valid            (w_user_op_valid    ),
    .o_user_op_ready            (w_user_op_ready    ),
    .i_user_write_data          (w_user_write_data  ),
    .o_user_write_req           (w_user_write_req   ),
    .o_user_read_data           (w_user_read_data   ),
    .o_user_read_valid          (w_user_read_valid  )
);

endmodule
