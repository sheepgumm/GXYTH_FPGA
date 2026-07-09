`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Deng Yukun
// 
// Create Date: 2026/01/01 15:52:12
// Design Name: 
// Module Name: reset
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

module reset
(
    // ===================== 时钟与复位输出 =====================
    input                           I_clk               , // 系统时钟（80MHz）
    output reg                      O_rst                 // 复位输出（低有效？本模块输出先低后高，用于初始化）
);

    // ===================== 内部信号定义 =====================
    reg                     [31:0]  cnt_reset           ; // 复位延时计数器

    // ===================== 复位生成逻辑 =====================
    always @(posedge I_clk) begin
        if (cnt_reset < 32'd160_000) begin          // 前 2ms（160000 @ 80MHz），O_rst 保持为低（复位有效）
            O_rst     <= 1'b0;
            cnt_reset <= cnt_reset + 1'b1;
        end else if (cnt_reset < 32'd480_000) begin // 接下来 4ms（480000 - 160000），O_rst 拉高（复位释放）
            O_rst     <= 1'b1;
            cnt_reset <= cnt_reset + 1'b1;
        end else begin                              // 达到 6ms 后，保持当前状态不再递增
            cnt_reset <= cnt_reset;
            O_rst     <= O_rst;
        end
    end

endmodule