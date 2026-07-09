`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Deng Yukun
// 
// Create Date: 2026/01/01 15:52:12
// Design Name: 
// Module Name: fco_bitslip
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

module fco_bitslip
(
    // ===================== 时钟与复位 =====================
    input                           I_reset_n           , // 复位信号（低有效）
    input                           bit_clk             , // 位时钟（320MHz）
    input                           W_fc_clk            , // 帧时钟（80MHz，分频后）

    // ===================== FCO 输入 =====================
    input                           fco                 , // 帧同步原始信号（差分转单端后）

    // ===================== 输出 =====================
    output                          frame_done          , // 帧对齐完成标志
    output reg                      R_bit_slip            // 位滑动控制信号（用于数据通道）
);

    // ===================== 内部信号定义 =====================
    wire                    [7:0]   W_fc_patten         ; // 解串后的 FCO 模式（8bit）
    reg                     [1:0]   R_wait              ; // 等待计数器
    wire                            bitslip             ; // 位滑动信号（调试用）

    assign bitslip = R_bit_slip;

    // ===================== ISERDESE2：FCO 串行转并行 =====================
    // 将 FCO 串行信号（DDR 模式）转换为 8bit 并行数据，用于检测帧同步模式
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
    ) ISERDESE2_inst0 (
        .O                  (                   ),
        .Q1                 (W_fc_patten[0]      ),
        .Q2                 (W_fc_patten[1]      ),
        .Q3                 (W_fc_patten[2]      ),
        .Q4                 (W_fc_patten[3]      ),
        .Q5                 (W_fc_patten[4]      ),
        .Q6                 (W_fc_patten[5]      ),
        .Q7                 (W_fc_patten[6]      ),
        .Q8                 (W_fc_patten[7]      ),
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
        .D                  (fco                ), // FCO 串行输入
        .DDLY               (1'b0               ),
        .OFB                (1'b0               ),
        .OCLKB              (1'b0               ),
        .RST                (!I_reset_n         ), // 复位（高有效）
        .SHIFTIN1           (1'b0               ),
        .SHIFTIN2           (1'b0               )
    );

    // ===================== 位滑动控制逻辑 =====================
    // 检测 FCO 模式是否为 8'b11110000，若不是则触发位滑动调整
    always @(negedge W_fc_clk or negedge I_reset_n) begin
        if (~I_reset_n) begin
            R_bit_slip <= 1'b0;
            R_wait     <= 2'd0;
        end else begin
            if (R_wait == 2'd3 && W_fc_patten != 8'b11110000) begin
                R_bit_slip <= 1'b1;   // 触发位滑动
                R_wait     <= 2'd1;
            end else begin
                R_bit_slip <= 1'b0;
                R_wait     <= R_wait + 1'b1;
            end
        end
    end

    // ===================== 帧对齐完成标志 =====================
    // 当 FCO 解串出的 8bit 模式等于 0xF0 时，表示帧同步完成
    assign frame_done = (W_fc_patten == 8'hf0) ? 1'b1 : 1'b0;

endmodule