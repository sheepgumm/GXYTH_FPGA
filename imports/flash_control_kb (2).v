`timescale 1ns/1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: flash_control_kb
// Description: Flash擦除/编程控制状态机 (用于RS422参数更新)
// Source: 从kb_pp_done工程flash_control移植并适配
// Editor: 针对bihua_openW的RS422参数更新功能
//
// 主要修改:
// 1. 参数更新起始地址从0x3C0000改为0x3A6000 (匹配bihua_openW的KB参数存储地址)
// 2. 去掉0x11程序更新命令,只保留0x22参数更新命令
// 3. 去掉multiboot相关逻辑
// 4. 保留参数: 20个扇区, 5120页 (共1,310,720字节 = 640×512×4字节)
//////////////////////////////////////////////////////////////////////////////////

module flash_control_kb
	(
		input		wire	CLK,           // 80MHz系统时钟
		input		wire	RSTn,
        input       wire    clk_spi,       // SPI时钟(来自MMCM或外部)
		output	reg	clock25M,
		(* mark_debug = "true" *) output	reg[3:0]	cmd_type,
		input		wire	Done_Sig,
		(* mark_debug = "true" *) output	reg[7:0]	flash_cmd,
		(* mark_debug = "true" *) output	reg[23:0]	flash_addr,
		input		wire[7:0]	mydata_o,
		input		wire	myvalid_o,

        // UART 控制接口
    	input  wire        I_start_erase_req,
    	input  wire        I_packet_ready_req,
    	output reg         O_rd_bank,     // 给乒乓RAM的读Bank指针
        (* mark_debug = "true" *) output      reg     O_es_done,     // 擦除完成信号
        (* mark_debug = "true" *) output      reg     O_wr_done,     // 写入完成信号

        (* mark_debug = "true" *) output      reg     O_update_active // 更新进行中标志(高有效)
	);

// ========== 参数定义 ==========
// 非均匀校正KB参数存储地址 (匹配bihua_openW中read_kb_from_flash1的kb_start_addr)
localparam KB_START_ADDR = 24'h500000;  // 3,825,664字节
localparam KB_SECTOR_CNT = 7'd20;       // 擦除扇区数 (20×64KB = 1,280KB)
localparam KB_PAGE_CNT   = 16'd2560;    // 编程页数 (2560×512B = 1,310,720B)

(* mark_debug = "true" *) reg[3:0] i;          // Flash操作状态机: 0等待命令,2-5擦除,6-9编程
reg[31:0] time_delay;
reg[23:0]	start_addr;
(* mark_debug = "true" *) reg [6:0] se_cnt;    // 剩余待擦除扇区数
(* mark_debug = "true" *) reg [15:0] packet_remain; // 剩余待写包数 (每包512B)
wire [7:0] uart_cmd;
reg [2:0] wren__cnt;

// 跨时钟域同步 (sys_clk -> spi_clk)
reg [2:0] erase_req_sync;
reg [2:0] packet_req_sync;
always @(posedge clk_spi) begin
    if(!RSTn) begin
        erase_req_sync <= 0; packet_req_sync <= 0;
    end else begin
        erase_req_sync <= {erase_req_sync[1:0], I_start_erase_req};
        packet_req_sync <= {packet_req_sync[1:0], I_packet_ready_req};
    end
end
wire erase_req_pulse = erase_req_sync[2] ^ erase_req_sync[1];
wire packet_req_pulse = packet_req_sync[2] ^ packet_req_sync[1];

reg pp_stage; // 0=写包的前256B, 1=写包的后256B

// // 边沿检测: I_256_done和I_143_done从UART时钟域跨到spi时钟域
// always @(posedge clk_spi) begin
// 	if(~RSTn) begin
// 		done_256 <= 0;
// 		done_143 <= 0;
// 	end
// 	else begin
// 		done_256[0] <= I_256_done;
// 		done_256[1] <= done_256[0];
// 		done_143[0] <= I_143_done;
// 		done_143[1] <= done_143[0];
// 	end
// end

// ========== Flash擦除/编程状态机 ==========
always @(posedge clk_spi)
begin
   if(!RSTn)begin
		i <= 4'd0;
        start_addr <= 24'd0;
		flash_addr <= 24'd0;
		flash_cmd <= 8'd0;
		cmd_type <= 4'b0000;
		time_delay <= 32'd0;
        se_cnt <= 7'd0;
        packet_remain <= 16'd0;
        O_es_done <= 1'b0;
        O_wr_done <= 1'b0;
		wren__cnt <= 1'b0;
        O_update_active <= 1'b0;
		O_rd_bank <= 0;
		pp_stage <= 0;
	end
	else begin
	   case(i)
			4'd0:begin
                flash_cmd <= 8'h00;
                cmd_type <= 4'b0000;
                O_update_active <= 1'b0;
                O_es_done <= 1'b0;
                O_wr_done <= 1'b0;
				O_rd_bank <= 0; // 重置Bank

                if(erase_req_pulse) begin
                    // ========== 参数更新 (擦除命令) ==========
                    start_addr <= KB_START_ADDR;  // 0x3A6000
					i <= i + 4'd1;
                    se_cnt <= KB_SECTOR_CNT;      // 20个扇区
                    packet_remain <= KB_PAGE_CNT;      // 5120页
                    O_update_active <= 1'b1;     // 更新开始
                end
				else begin
					i <= i;
				end
			end

            4'd1:begin
                flash_addr <= start_addr;
                i <= i + 4'd1;
                time_delay <= 0;
            end

			// ========== 写使能(WREN) ==========
			4'd2:begin
                if (time_delay < 4) begin // 保证 CS# 至少拉高 160ns (严格遵守 tSHSL 时序规范)
                    flash_cmd <= 0; cmd_type <= 0; time_delay <= time_delay + 1;
                end else begin
                    if(Done_Sig)begin
                        time_delay <= 0; i <= 4'd3;
                        flash_cmd <= 0; cmd_type <= 0;
                    end else begin
                        flash_cmd <= 8'h06; cmd_type <= 4'b1001;
                    end
                end
            end

			// ========== 扇区擦除(Sector Erase 0xD8) ==========
			4'd3:begin
                if (time_delay < 4) begin 
                    flash_cmd <= 0; 
                    cmd_type <= 0;       // 强制 CS# 保持拉高状态
                    time_delay <= time_delay + 1;
                end else begin
                    // 160ns 延时结束后，才真正开始发送 0xD8 擦除指令
                    if(Done_Sig)begin
                        flash_cmd <= 8'h00;
                        i <= i + 4'd1;
                        cmd_type<=4'b0000;
                    end
                    else begin
                        flash_cmd <= 8'hD8;         // Sector Erase命令
                        flash_addr <= flash_addr;
                        cmd_type <= 4'b1010;
                    end
				end
			end

			// ========== 等待扇区擦除完成 (~1s @ clk_spi) ==========
	        4'd4:begin
                flash_cmd <= 8'h00;
                cmd_type <= 4'b0000;
				if(time_delay < 32'd20_000_000)begin
					time_delay <= time_delay + 8'd1;
				end
				else begin
                    time_delay <= 32'd0;
                    i <= i + 4'd1;
				end
			end

			// ========== 读状态寄存器1,等待Flash空闲 ==========
			4'd5:begin
                if (time_delay < 4) begin 
                    flash_cmd <= 0; cmd_type <= 0; time_delay <= time_delay + 1;
                end else begin
                    if(Done_Sig)begin
                        flash_cmd <= 0; cmd_type <= 0;
                        if(mydata_o[0] == 1'b0)begin  // 0=Flash空闲, 1=Flash忙
                            // flash_cmd <= 8'h00;
                            // cmd_type <= 4'b0000;
                            if(se_cnt == 1'b1) begin
                                i <= i + 4'd1;
                                O_es_done <= 1'b1;    // 擦除完成
                                flash_addr <= start_addr;
                            end
                            else begin
                                i <= 4'd2;
                                se_cnt <= se_cnt - 1'b1;
                                flash_addr <= flash_addr + 24'h10000; // +64KB, 下一个扇区
                                time_delay <= 0;
                            end
                        end
                        else begin
                            //time_delay <= 0;
                            flash_cmd <= 8'h05;       // RDSR命令
                            cmd_type <= 4'b1011;
                        end
                    end
                    else begin
                        flash_cmd <= 8'h05;
                        cmd_type <= 4'b1011;
                    end
				end
			end

			// ============================================
            // 以下为分包写入逻辑
            // ============================================
	        4'd6: begin
                O_es_done <= 0; // 撤销完成信号
                if (packet_req_pulse) begin
                    i <= 4'd7; 
                    pp_stage <= 0; // 准备写这包的前半个256B
                end
            end

            // ========== 写使能(WREN) ==========
            4'd7: begin
                if(Done_Sig) begin
                    flash_cmd <= 0; cmd_type <= 0; i <= 4'd8;
                end else begin
                    flash_cmd <= 8'h06; cmd_type <= 4'b1001; 
                end
            end

            // ========== 页编程 (Page Program 0x02) ==========
            4'd8: begin
                if(Done_Sig) begin
                    flash_cmd <= 0; cmd_type <= 0; i <= 4'd9;
                end else begin
                    flash_cmd <= 8'h02; 
                    // 1101告诉底层读RAM 0~255, 1110读RAM 256~511
                    cmd_type <= (pp_stage == 0) ? 4'b1101 : 4'b1110;
                end
            end

            // ========== 等待编程 ==========
            4'd9: begin
                flash_cmd <= 0; cmd_type <= 0;
                if(time_delay < 32'd16_000) time_delay <= time_delay + 1;
                else begin i <= 4'd10; time_delay <= 0; end
            end

            // ========== 读寄存器等编程完成 ==========
            4'd10: begin
                if(Done_Sig) begin
                    if(mydata_o[0] == 1'b0) begin
                        flash_cmd <= 0; cmd_type <= 0;
                        flash_addr <= flash_addr + 24'd256; // 地址推进256B
                        
                        if (pp_stage == 0) begin
                            // 第一页写完，去写这包的后半页
                            pp_stage <= 1; i <= 4'd7;
                        end else begin
                            // 512B 完整包全部写完
                            O_rd_bank <= ~O_rd_bank; // 翻转读取Bank，等下一包
                            
                            if (packet_remain == 1) begin
                                // 这是最后一包！跳转到新增的1秒延时状态
                                i <= 4'd11; 
                                time_delay <= 0;
                            end else begin
                                packet_remain <= packet_remain - 1;
                                i <= 4'd6; // 回到状态6等下一包触发
                            end
                        end
                    end else begin time_delay <= 0;flash_cmd <= 8'h05; cmd_type <= 4'b1011; end
                end else begin flash_cmd <= 8'h05; cmd_type <= 4'b1011; end
            end

            // ========== 新增：最后一包完成后的 1秒 延时状态 ==========
            4'd11: begin
                // 注意：这里的计数值取决于你的 clk_spi 频率。
                // 如果你的 clk_spi 是 30MHz，那么 1秒 = 30_000_000 个周期。
                // 如果你的 clk_spi 是 20MHz，请将下方的 30_000_000 改为 20_000_000。
                if(time_delay < 32'd20_000_000) begin
                    time_delay <= time_delay + 1;
                end else begin
                    time_delay <= 0;
                    i <= 4'd14;         // 延时满 1秒，跳转到结束状态
                    O_wr_done <= 1'b1;  // 在此时才输出完成信号
                end
            end

            // ========== 结束等待 ==========
            4'd14: begin
                O_update_active <= 0;
                if(time_delay < 32'd16) time_delay <= time_delay + 1;
                else begin i <= 4'd0; time_delay <= 0; O_wr_done <= 0; end // 回到初始状态
            end

		endcase
	end
end

// ========== 25MHz SPI时钟生成 ==========
// 从80MHz CLK分频得到25MHz clock25M
reg [1:0] clk_cnt;
always @(posedge CLK)
begin
   if(!RSTn)begin
		clock25M <= 1'b0;
        clk_cnt <= 0;
	end
	else begin
        if(clk_cnt == 2'd2) begin
		    clock25M <= ~clock25M;
            clk_cnt <= 0;
        end
        else begin
            clk_cnt <= clk_cnt + 1;
        end
	end
end

endmodule
