`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/11/15 09:23:17
// Design Name: 
// Module Name: read_kb_from_flash1
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

`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: read_kb_from_flash1
// Description: MX25U51245G 2x I/O Read Mode (BBh) Driver
//              采用外部锁相环时钟 flash_spi_clk 进行数据收发
//////////////////////////////////////////////////////////////////////////////////

module read_kb_from_flash_new
(
    (*mark_debug = "true"*) output wire flash_clk,
    output reg             flash_cs,
    inout                  D0,
    inout                  D1,
    input                  flash_spi_clk,
    input  wire            CLK,             // 兼容原有接口，本模块核心逻辑使用 flash_spi_clk
    input  wire            flash_rstn,
    input  wire            ddr_init_done,
    (*mark_debug = "true"*) output wire k_b_finish_O,
    output reg [7:0]       mydata_o,
    output wire            myvalid_o,
    (*mark_debug = "true"*) output wire shift_sig,
    output wire [7:0]      o_data_sim,
    output wire [8:0]      flash_read_num_test
);

    // --- 参数与命令定义 ---
    localparam CMD_2READ        = 8'hBB;
    localparam kb_start_addr    = 32'h00CFFF00; // 起始地址
    localparam kb_end_page_addr = 32'h00E3FF00; // 终止地址
    localparam PAGE_SIZE        = 32'd256;      // 一页 256 字节

    // --- 状态机定义 ---
    localparam IDLE         = 3'd0;
    localparam CMD          = 3'd1;  // 发送 BBh
    localparam ADDR         = 3'd2;  // 双线发送 32位地址
    localparam DUMMY        = 3'd3;  // 10个时钟周期的 Dummy
    localparam READ         = 3'd4;  // 双线接收数据
    localparam CS_HIGH_WAIT = 3'd5;  // 页与页之间 CS# 拉高的等待时间
    localparam NEXT_PAGE    = 3'd6;  // 地址累加，判断是否结束
    localparam DONE         = 3'd7;  // 全部完成

    reg [2:0]  state;
    reg [31:0] current_addr;      
    reg [3:0]  bit_cnt;           // 时钟周期计数器
    reg [8:0]  byte_cnt;          // 已经读取的字节计数 (0~256)
    
    reg        spi_clk_en;
    reg [1:0]  sio_oe;
    reg [1:0]  sio_out;
    
    reg        k_b_finish;
    reg        myvalid;
    reg [7:0]  mydata_shift;      // 用于接收数据的内部移位寄存器
    reg [1:0]  ddr_init_done_a;   // ddr_init_done 的跨时钟域打拍同步寄存器

    // --- 端口连线 ---
    assign D0 = sio_oe[0] ? sio_out[0] : 1'bz;
    assign D1 = sio_oe[1] ? sio_out[1] : 1'bz;

    // 时钟与使能信号 (将使能信号和时钟相与输出，在下降沿翻转使能信号可保证无毛刺)
    assign flash_clk = spi_clk_en ? flash_spi_clk : 1'b0;
    assign shift_sig = spi_clk_en;
    
    assign k_b_finish_O = k_b_finish;
    assign myvalid_o    = myvalid;
    
    // 测试与仿真端口赋值 (根据需要保留，不用的赋0防止综合出多余逻辑)
    assign flash_read_num_test = byte_cnt;
    assign o_data_sim          = 8'd0; 

    // --- 跨时钟域同步 (ddr_init_done -> flash_spi_clk) ---
    always @(posedge flash_spi_clk or negedge flash_rstn) begin
        if (!flash_rstn) begin
            ddr_init_done_a <= 2'b00;
        end else begin
            ddr_init_done_a <= {ddr_init_done_a[0], ddr_init_done};
        end
    end

    // -----------------------------------------------------------------
    // 发送与状态机控制 (下降沿触发，确保数据在 flash_clk 上升沿被 Flash 稳定采样)
    // -----------------------------------------------------------------
    always @(negedge flash_spi_clk or negedge flash_rstn) begin
        if (!flash_rstn) begin
            state        <= IDLE;
            flash_cs     <= 1'b1;
            spi_clk_en   <= 1'b0;
            current_addr <= kb_start_addr;
            bit_cnt      <= 4'd0;
            byte_cnt     <= 9'd0;
            sio_oe       <= 2'b00;
            sio_out      <= 2'b00;
            k_b_finish   <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    flash_cs   <= 1'b1;
                    spi_clk_en <= 1'b0;
                    // 等待 DDR 初始化完成，且之前未读取完毕时启动
                    if (ddr_init_done_a[1] && !k_b_finish) begin
                        state        <= CMD;
                        flash_cs     <= 1'b0;
                        spi_clk_en   <= 1'b1;    // 开启输出时钟
                        current_addr <= kb_start_addr;
                        bit_cnt      <= 4'd7;    // 8位命令
                        sio_oe       <= 2'b01;   // 仅 D0 输出
                        sio_out[0]   <= CMD_2READ[7];
                    end
                end
                
                CMD: begin
                    if (bit_cnt == 0) begin
                        state      <= ADDR;
                        bit_cnt    <= 4'd15;     // 32位地址，双线发送需16个周期
                        sio_oe     <= 2'b11;     // D1, D0 双线输出
                        sio_out[1] <= current_addr[31];
                        sio_out[0] <= current_addr[30];
                    end else begin
                        bit_cnt    <= bit_cnt - 1;
                        sio_out[0] <= CMD_2READ[bit_cnt - 1]; 
                    end
                end
                
                ADDR: begin
                    if (bit_cnt == 0) begin
                        state      <= DUMMY;
                        bit_cnt    <= 4'd9;      // 芯片默认 10 个 Dummy clock
                        sio_oe     <= 2'b00;     // 切换为输入，总线释放给Flash
                    end else begin
                        bit_cnt    <= bit_cnt - 1;
                        sio_out[1] <= current_addr[{bit_cnt-1, 1'b1}];
                        sio_out[0] <= current_addr[{bit_cnt-1, 1'b0}];
                    end
                end
                
                DUMMY: begin
                    if (bit_cnt == 0) begin
                        state      <= READ;
                        bit_cnt    <= 4'd3;      // 一字节双线接收需4个周期
                        byte_cnt   <= 9'd0;
                    end else begin
                        bit_cnt    <= bit_cnt - 1;
                    end
                end
                
                READ: begin
                    if (bit_cnt == 0) begin
                        if (byte_cnt == PAGE_SIZE - 1) begin
                            state      <= CS_HIGH_WAIT;
                            flash_cs   <= 1'b1;  // 读完一页 256 字节，拉高 CS#
                            spi_clk_en <= 1'b0;  // 停止输出时钟
                            bit_cnt    <= 4'd3;  // 等待 4 个周期 tSHSL 恢复时间
                        end else begin
                            bit_cnt  <= 4'd3;
                            byte_cnt <= byte_cnt + 1;
                        end
                    end else begin
                        bit_cnt <= bit_cnt - 1;
                    end
                end
                
                CS_HIGH_WAIT: begin
                    if (bit_cnt == 0) begin
                        state <= NEXT_PAGE;
                    end else begin
                        bit_cnt <= bit_cnt - 1;
                    end
                end

                NEXT_PAGE: begin
                    // 判断是否已经读到了末地址
                    if (current_addr >= kb_end_page_addr) begin
                        state      <= DONE;
                        k_b_finish <= 1'b1;
                    end else begin
                        current_addr <= current_addr + PAGE_SIZE;
                        state        <= CMD;
                        flash_cs     <= 1'b0;
                        spi_clk_en   <= 1'b1;
                        bit_cnt      <= 4'd7;
                        sio_oe       <= 2'b01;
                        sio_out[0]   <= CMD_2READ[7];
                    end
                end
                
                DONE: begin
                    // 保持完成状态，直到系统级复位
                    k_b_finish <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // -----------------------------------------------------------------
    // 接收数据采样逻辑 (上升沿触发，采集 Flash 送来的稳定数据)
    // -----------------------------------------------------------------
    always @(posedge flash_spi_clk or negedge flash_rstn) begin
        if (!flash_rstn) begin
            mydata_shift <= 8'd0;
            mydata_o     <= 8'd0;
            myvalid      <= 1'b0;
        end else begin
            myvalid <= 1'b0;  // 默认每拍清零有效脉冲

            if (state == READ && !flash_cs) begin
                // D1 和 D0 并行采入暂存移位寄存器，高位先发
                mydata_shift <= {mydata_shift[5:0], D1, D0};
                
                // 当读取到一个字节的最后 2 个 bit 时，更新稳定输出并拉高 valid
                if (bit_cnt == 4'd0) begin
                    myvalid  <= 1'b1;
                    mydata_o <= {mydata_shift[5:0], D1, D0};
                end
            end
        end
    end

endmodule