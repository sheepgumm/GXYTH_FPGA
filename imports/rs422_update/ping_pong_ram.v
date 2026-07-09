`timescale 1ns/1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: ping_pong_ram
// Description: 512字节乒乓缓存包装层 (底层调用Vivado BRAM IP)
// 巧妙利用1024深度的单块BRAM：
// - Bank0 映射到物理地址 0 ~ 511
// - Bank1 映射到物理地址 512 ~ 1023
//////////////////////////////////////////////////////////////////////////////////

module ping_pong_ram (
    // UART 写端口 (80MHz CLK时钟域)
    input  wire       wr_clk,
    input  wire       wr_en,
    input  wire       wr_bank,   // 0:写Bank0(0~511), 1:写Bank1(512~1023)
    input  wire [8:0] wr_addr,   // 0~511
    input  wire [7:0] wr_data,
    
    // SPI Flash 读端口 (clk_spi时钟域)
    input  wire       rd_clk,
    input  wire       rd_bank,   // 0:读Bank0(0~511), 1:读Bank1(512~1023)
    input  wire [8:0] rd_addr,   // 0~511
    output wire [7:0] rd_data    // 注意：改为了wire类型，直接接IP核输出
);

    // 将 Bank 指示位和 9-bit 地址拼接，形成 10-bit BRAM 物理地址
    wire [9:0] bram_wr_addr = {wr_bank, wr_addr};
    wire [9:0] bram_rd_addr = {rd_bank, rd_addr};

    // 例化 Vivado 生成的 Block Memory Generator IP 核
    // 配置: Simple Dual Port RAM, 独立时钟, 宽8, 深1024
    bram_ping_pong U_bram_ping_pong (
      .clka  (wr_clk),         // 写时钟
      .wea   (wr_en),          // 写使能
      .addra (bram_wr_addr),   // 写地址 [9:0]
      .dina  (wr_data),        // 写数据 [7:0]
      
      .clkb  (rd_clk),         // 读时钟
      .addrb (bram_rd_addr),   // 读地址 [9:0]
      .doutb (rd_data)         // 读数据 [7:0]
    );

endmodule