`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/07/17 21:24:05
// Design Name: 
// Module Name: spi_top
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
`include "top_define.vh"
module spi_top(
    input               i_clk,
    output              o_flash_clk,
    // SPI physical
    output              o_spi_clk,
    output              o_spi_cs,
    output              o_spi_mosi,
    input               i_spi_miso,

    // ===== �û��ӿڣ��� flash_drive �ã�=====
    input       [1:0]   i_operation_type,
    input       [23:0]  i_operation_addr,
    input       [8:0]   i_operation_num,
    input               i_operation_valid,

    input       [7:0]   i_write_data,
    input               i_write_sop,
    input               i_write_eop,
    input               i_write_valid,

    output              o_operation_ready,

    output      [7:0]   o_read_data,
    output              o_read_sop,
    output              o_read_eop,
    output              o_read_valid
);

wire                w_clk_5Mhz          ;
wire                w_clk_5Mhz_lock     ;
wire                w_clk_5Mhz_rst      ;
//wire [1 :0]         w_operation_type    ;
//wire [23:0]         w_operation_addr    ;
//wire [8 :0]         w_operation_num     ;
//wire                w_operation_valid   ;
//wire                w_operation_ready   ;
//wire [7 :0]         w_write_data        ;
//wire                w_write_sop         ;
//wire                w_write_eop         ;
//wire                w_write_valid       ;
//wire [7 :0]         w_read_data         ;
//wire                w_read_sop          ;
//wire                w_read_eop          ;
//wire                w_read_valid        ;

assign w_clk_5Mhz_rst = ~w_clk_5Mhz_lock;
assign o_flash_clk = w_clk_5Mhz;
`ifdef VIVADO
    SYSTEM_CLK SYSTEM_CLK_U0
    (
        .clk_in1                (i_clk              ),
        .clk_out1               (w_clk_5Mhz         ),  
        .locked                 (w_clk_5Mhz_lock    ) 
    );
`elsif QUARTUS
    SYSTEM_CLK SYSTEM_CLK_U0
    (
	    .inclk0                 (i_clk              ),
	    .c0                     (w_clk_5Mhz         ),
	    .locked                 (w_clk_5Mhz_lock    )
    );

`endif

flash_drive flash_drive_u0(
    .i_clk              (w_clk_5Mhz),
    .i_rst              (w_clk_5Mhz_rst),

    .i_operation_type   (i_operation_type),
    .i_operation_addr   (i_operation_addr),
    .i_operation_num    (i_operation_num),
    .i_operation_valid  (i_operation_valid),
    .o_operation_ready  (o_operation_ready),

    .i_write_data       (i_write_data),
    .i_write_sop        (i_write_sop),
    .i_write_eop        (i_write_eop),
    .i_write_valid      (i_write_valid),

    .o_read_data        (o_read_data),
    .o_read_sop         (o_read_sop),
    .o_read_eop         (o_read_eop),
    .o_read_valid       (o_read_valid),

    .o_spi_clk          (o_spi_clk),
    .o_spi_cs           (o_spi_cs),
    .o_spi_mosi         (o_spi_mosi),
    .i_spi_miso         (i_spi_miso)
);



//user_gen_data user_gen_data_U0(
//    .i_clk                   (w_clk_5Mhz        ),
//    .i_rst                   (w_clk_5Mhz_rst    ),
//    .o_operation_type        (w_operation_type  ),//操作类型
//    .o_operation_addr        (w_operation_addr  ),//操作地址
//    .o_operation_num         (w_operation_num   ),//限制用户每次�?多写256字节
//    .o_operation_valid       (w_operation_valid ),//操作握手有效
//    .i_operation_ready       (w_operation_ready ),//操作握手准备
//    .o_write_data            (w_write_data      ),//写数�?
//    .o_write_sop             (w_write_sop       ),//写数�?-�?始信�?
//    .o_write_eop             (w_write_eop       ),//写数�?-结束信号
//    .o_write_valid           (w_write_valid     ),//写数�?-有效信号
//    .i_read_data             (w_read_data       ),//读数�?
//    .i_read_sop              (w_read_sop        ),//读数�?-�?始信�?
//    .i_read_eop              (w_read_eop        ),//读数�?-结束信号
//    .i_read_valid            (w_read_valid      ) //读数�?-有效信号
//);

//`ifdef VIVADO
//    SPI_ILA SPI_ILA_U0 (
//        .clk                    (w_clk_5Mhz         ),
//        .probe0                 (w_write_data       ),
//        .probe1                 (w_write_valid      ),
//        .probe2                 (w_read_data        ),
//        .probe3                 (w_read_valid       ),
//        .probe4                 (w_operation_valid  ),
//        .probe5                 (w_operation_ready  ) 
//    );
//`endif

endmodule
