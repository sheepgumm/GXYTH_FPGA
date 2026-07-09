`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Deng Yukun
// 
// Create Date: 2026/01/01 15:52:12
// Design Name: 
// Module Name: data_bitslip
// Project Name: GXYTH_LWIR
// Target Devices: lwir 640*512
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

module data_bitslip
(
    // ===================== 时钟与复位 =====================
    input                           I_reset_n           , // 复位信号（低有效）
    input                           bit_clk             , // 位时钟（320MHz）
    input                           W_fc_clk            , // 帧时钟（80MHz，分频后）

    // ===================== LVDS 差分数据输入 =====================
    input                           I_ad_lvds_d0_p      , // 通道 D0 正
    input                           I_ad_lvds_d0_n      , // 通道 D0 负
    input                           I_ad_lvds_d1_p      , // 通道 D1 正
    input                           I_ad_lvds_d1_n      , // 通道 D1 负

    // ===================== 控制信号 =====================
    input                           frame_done          , // 帧对齐完成（未直接使用）
    input                           R_bit_slip          , // 位滑动控制信号

    // ===================== 数据输出 =====================
    (* keep = "true" *) output      [13:0]  ad_data       // 最终 14bit ADC 数据
);

    // ===================== 内部信号定义 =====================
    wire                            data_d0             ; // D0 差分转单端
    wire                            data_d1             ; // D1 差分转单端
    wire                    [15:0]  data                ; // 拼接后的 16bit 数据（ad_data_d1 + ad_data_d0）
    wire                    [7:0]   ad_data_d0          ; // D0 解串后 8bit
    wire                    [7:0]   ad_data_d1          ; // D1 解串后 8bit

    assign data = {ad_data_d1, ad_data_d0}; // 拼接（未使用）

    // ===================== D0 差分输入缓冲（IBUFDS） =====================
    IBUFDS #(
        .DIFF_TERM    ("TRUE"         ),
        .IBUF_LOW_PWR ("FALSE"        ),
        .IOSTANDARD   ("LVDS_25"      )
    ) IBUFDS_inst0 (
        .O  (data_d0                  ),
        .I  (I_ad_lvds_d0_p           ),
        .IB (I_ad_lvds_d0_n           )
    );

    // ===================== D0 串行转并行（ISERDESE2） =====================
    // 将 DDR 模式、8bit 宽度的串行数据转换为并行
    ISERDESE2 #(
        .DATA_RATE          ("DDR"              ),
        .DATA_WIDTH         (8                  ),
        .DYN_CLKDIV_INV_EN  ("FALSE"            ),
        .DYN_CLK_INV_EN     ("FALSE"            ),
        .INIT_Q1            (1'b0               ),
        .INIT_Q2            (1'b0               ),
        .INIT_Q3            (1'b0               ),
        .INIT_Q4            (1'b0               ),
        .INTERFACE_TYPE     ("NETWORKING"       ),
        .IOBDELAY           ("NONE"             ),
        .NUM_CE             (1                  ),
        .OFB_USED           ("FALSE"            ),
        .SERDES_MODE        ("MASTER"           ),
        .SRVAL_Q1           (1'b0               ),
        .SRVAL_Q2           (1'b0               ),
        .SRVAL_Q3           (1'b0               ),
        .SRVAL_Q4           (1'b0               )
    ) ISERDESE2_inst1 (
        .O                  (                   ),
        .Q1                 (ad_data_d0[0]       ),
        .Q2                 (ad_data_d0[1]       ),
        .Q3                 (ad_data_d0[2]       ),
        .Q4                 (ad_data_d0[3]       ),
        .Q5                 (ad_data_d0[4]       ),
        .Q6                 (ad_data_d0[5]       ),
        .Q7                 (ad_data_d0[6]       ),
        .Q8                 (ad_data_d0[7]       ),
        .SHIFTOUT1          (                   ),
        .SHIFTOUT2          (                   ),
        .BITSLIP            (R_bit_slip         ), // 位滑动控制
        .CE1                (1'b1               ),
        .CE2                (1'b0               ),
        .CLKDIVP            (1'b0               ),
        .CLK                (bit_clk            ), // 高速时钟
        .CLKB               (~bit_clk           ), // 反相高速时钟
        .CLKDIV             (W_fc_clk           ), // 分频时钟（80MHz）
        .OCLK               (1'b0               ),
        .DYNCLKDIVSEL       (1'b0               ),
        .DYNCLKSEL          (1'b0               ),
        .D                  (data_d0            ), // 串行数据输入
        .DDLY               (1'b0               ),
        .OFB                (1'b0               ),
        .OCLKB              (1'b0               ),
        .RST                (!I_reset_n         ), // 复位（高有效）
        .SHIFTIN1           (1'b0               ),
        .SHIFTIN2           (1'b0               )
    );

    // ===================== D1 差分输入缓冲（IBUFDS） =====================
    IBUFDS #(
        .DIFF_TERM    ("TRUE"         ),
        .IBUF_LOW_PWR ("TRUE"         ),
        .IOSTANDARD   ("DEFAULT"      )
    ) IBUFDS_inst1 (
        .O  (data_d1                  ),
        .I  (I_ad_lvds_d1_p           ),
        .IB (I_ad_lvds_d1_n           )
    );

    // ===================== D1 串行转并行（ISERDESE2） =====================
    ISERDESE2 #(
        .DATA_RATE          ("DDR"              ),
        .DATA_WIDTH         (8                  ),
        .DYN_CLKDIV_INV_EN  ("FALSE"            ),
        .DYN_CLK_INV_EN     ("FALSE"            ),
        .INIT_Q1            (1'b0               ),
        .INIT_Q2            (1'b0               ),
        .INIT_Q3            (1'b0               ),
        .INIT_Q4            (1'b0               ),
        .INTERFACE_TYPE     ("NETWORKING"       ),
        .IOBDELAY           ("NONE"             ),
        .NUM_CE             (1                  ),
        .OFB_USED           ("FALSE"            ),
        .SERDES_MODE        ("MASTER"           ),
        .SRVAL_Q1           (1'b0               ),
        .SRVAL_Q2           (1'b0               ),
        .SRVAL_Q3           (1'b0               ),
        .SRVAL_Q4           (1'b0               )
    ) ISERDESE2_inst2 (
        .O                  (                   ),
        .Q1                 (ad_data_d1[0]       ),
        .Q2                 (ad_data_d1[1]       ),
        .Q3                 (ad_data_d1[2]       ),
        .Q4                 (ad_data_d1[3]       ),
        .Q5                 (ad_data_d1[4]       ),
        .Q6                 (ad_data_d1[5]       ),
        .Q7                 (ad_data_d1[6]       ),
        .Q8                 (ad_data_d1[7]       ),
        .SHIFTOUT1          (                   ),
        .SHIFTOUT2          (                   ),
        .BITSLIP            (R_bit_slip         ),
        .CE1                (1'b1               ),
        .CE2                (1'b0               ),
        .CLKDIVP            (1'b0               ),
        .CLK                (bit_clk            ),
        .CLKB               (~bit_clk           ),
        .CLKDIV             (W_fc_clk           ),
        .OCLK               (1'b0               ),
        .DYNCLKDIVSEL       (1'b0               ),
        .DYNCLKSEL          (1'b0               ),
        .D                  (data_d1            ),
        .DDLY               (1'b0               ),
        .OFB                (1'b0               ),
        .OCLKB              (1'b0               ),
        .RST                (!I_reset_n         ),
        .SHIFTIN1           (1'b0               ),
        .SHIFTIN2           (1'b0               )
    );

    // ===================== 数据格式转换（补码转二进制） =====================
    // 将 16bit 解串结果截取为 14bit（实际有效数据为高 14bit）
    wire [13:0] ad_data_complement; // 补码数据（带符号）
    assign ad_data_complement = {ad_data_d1, ad_data_d0[7:2]};

    // 将补码转换为二进制（偏移码）：对于 14bit 数据，加 8192（2^13）
    wire [13:0] ad_data_complement1;
    assign ad_data_complement1 = ad_data_complement + 14'd8192;

    // 最终输出（偏移码格式，适合后续处理）
    assign ad_data = ad_data_complement1;

endmodule