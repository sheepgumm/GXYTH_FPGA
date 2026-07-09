`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Deng Yukun
// 
// Create Date: 2026/01/01 15:52:12
// Design Name: 
// Module Name: flash_control_kb
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

module flash_control_kb
(
    // ===================== 时钟与复位 =====================
    input   wire                        CLK             , // 80MHz 系统时钟
    input   wire                        RSTn            , // 复位信号（低有效）
    input   wire                        clk_spi         , // SPI 时钟（来自 MMCM 或外部）

    // ===================== SPI 接口 =====================
    output  reg                         clock25M        , // 25MHz SPI 时钟（分频后）
    (* mark_debug = "true" *) output reg [3:0]   cmd_type   , // SPI 命令类型（指示底层操作）
    input   wire                        Done_Sig        , // SPI 操作完成信号
    (* mark_debug = "true" *) output reg [7:0]   flash_cmd , // Flash 命令字节
    (* mark_debug = "true" *) output reg [23:0]  flash_addr, // Flash 地址
    input   wire                [7:0]   mydata_o        , // 从 Flash 读回的数据（用于 RDSR）
    input   wire                        myvalid_o       , // 数据有效标志（未用）

    // ===================== UART 控制接口 =====================
    input   wire                        I_start_erase_req, // 启动擦除请求（来自 UART）
    input   wire                        I_packet_ready_req, // 数据包准备好请求（来自 UART）
    output  reg                         O_rd_bank       , // 给乒乓 RAM 的读 Bank 指针
    (* mark_debug = "true" *) output reg O_es_done       , // 擦除完成信号
    (* mark_debug = "true" *) output reg O_wr_done       , // 写入完成信号
    (* mark_debug = "true" *) output reg O_update_active   // 更新进行中标志（高有效）
);

    // ========== 参数定义 ==========
    // 非均匀校正 KB 参数存储地址（匹配 bihua_openW 中 read_kb_from_flash1 的 kb_start_addr）
    localparam KB_START_ADDR = 24'h500000;  // 5,242,880 字节
    localparam KB_SECTOR_CNT = 7'd20;       // 擦除扇区数（20 × 64KB = 1,280KB）
    localparam KB_PAGE_CNT   = 16'd2560;    // 编程页数（2560 × 512B = 1,310,720B）

    // ========== 内部信号定义 ==========
    (* mark_debug = "true" *) reg     [3:0]   i               ; // Flash 操作状态机
    reg                     [31:0]  time_delay      ; // 延时计数器
    reg                     [23:0]  start_addr      ; // 当前操作起始地址
    (* mark_debug = "true" *) reg     [6:0]   se_cnt      ; // 剩余待擦除扇区数
    (* mark_debug = "true" *) reg     [15:0]  packet_remain   ; // 剩余待写包数（每包 512B）
    reg                     [2:0]   wren_cnt        ; // 写使能计数器（未使用）

    // 跨时钟域同步（sys_clk -> spi_clk）
    reg                     [2:0]   erase_req_sync  ; // I_start_erase_req 同步
    reg                     [2:0]   packet_req_sync ; // I_packet_ready_req 同步
    always @(posedge clk_spi) begin
        if (!RSTn) begin
            erase_req_sync  <= 3'd0;
            packet_req_sync <= 3'd0;
        end else begin
            erase_req_sync  <= {erase_req_sync[1:0], I_start_erase_req};
            packet_req_sync <= {packet_req_sync[1:0], I_packet_ready_req};
        end
    end

    wire erase_req_pulse  = erase_req_sync[2] ^ erase_req_sync[1]; // 上升沿检测
    wire packet_req_pulse = packet_req_sync[2] ^ packet_req_sync[1];

    reg                     pp_stage            ; // 0=写包的前 256B，1=写包的后 256B

    // ========== Flash 擦除/编程状态机 ==========
    always @(posedge clk_spi) begin
        if (!RSTn) begin
            i               <= 4'd0;
            start_addr      <= 24'd0;
            flash_addr      <= 24'd0;
            flash_cmd       <= 8'd0;
            cmd_type        <= 4'b0000;
            time_delay      <= 32'd0;
            se_cnt          <= 7'd0;
            packet_remain   <= 16'd0;
            O_es_done       <= 1'b0;
            O_wr_done       <= 1'b0;
            wren_cnt        <= 3'd0;
            O_update_active <= 1'b0;
            O_rd_bank       <= 1'b0;
            pp_stage        <= 1'b0;
        end else begin
            case (i)
                // ========== 状态 0：等待命令 ==========
                4'd0: begin
                    flash_cmd <= 8'h00;
                    cmd_type  <= 4'b0000;
                    O_update_active <= 1'b0;
                    O_es_done <= 1'b0;
                    O_wr_done <= 1'b0;
                    O_rd_bank <= 1'b0; // 重置 Bank

                    if (erase_req_pulse) begin
                        // 参数更新（擦除命令）
                        start_addr <= KB_START_ADDR;
                        i <= i + 4'd1;
                        se_cnt <= KB_SECTOR_CNT;    // 20 个扇区
                        packet_remain <= KB_PAGE_CNT; // 2560 页
                        O_update_active <= 1'b1;    // 更新开始
                    end else begin
                        i <= i;
                    end
                end

                // ========== 状态 1：准备擦除地址 ==========
                4'd1: begin
                    flash_addr <= start_addr;
                    i <= i + 4'd1;
                    time_delay <= 32'd0;
                end

                // ========== 状态 2：写使能（WREN 0x06） ==========
                4'd2: begin
                    if (time_delay < 4) begin // 保证 CS# 至少拉高 160ns（严格遵守 tSHSL 时序规范）
                        flash_cmd <= 8'd0;
                        cmd_type  <= 4'b0000;
                        time_delay <= time_delay + 1'b1;
                    end else begin
                        if (Done_Sig) begin
                            time_delay <= 32'd0;
                            i <= 4'd3;
                            flash_cmd <= 8'd0;
                            cmd_type  <= 4'b0000;
                        end else begin
                            flash_cmd <= 8'h06;   // WREN 命令
                            cmd_type  <= 4'b1001;
                        end
                    end
                end

                // ========== 状态 3：扇区擦除（Sector Erase 0xD8） ==========
                4'd3: begin
                    if (time_delay < 4) begin
                        flash_cmd <= 8'd0;
                        cmd_type  <= 4'b0000;      // 强制 CS# 保持拉高状态
                        time_delay <= time_delay + 1'b1;
                    end else begin
                        // 160ns 延时结束后，才真正开始发送 0xD8 擦除指令
                        if (Done_Sig) begin
                            flash_cmd <= 8'h00;
                            i <= i + 4'd1;
                            cmd_type <= 4'b0000;
                        end else begin
                            flash_cmd <= 8'hD8;    // Sector Erase 命令
                            flash_addr <= flash_addr;
                            cmd_type <= 4'b1010;
                        end
                    end
                end

                // ========== 状态 4：等待扇区擦除完成（约 1s） ==========
                4'd4: begin
                    flash_cmd <= 8'h00;
                    cmd_type  <= 4'b0000;
                    if (time_delay < 32'd20_000_000) begin
                        time_delay <= time_delay + 1'b1;
                    end else begin
                        time_delay <= 32'd0;
                        i <= i + 4'd1;
                    end
                end

                // ========== 状态 5：读状态寄存器（RDSR 0x05），等待 Flash 空闲 ==========
                4'd5: begin
                    if (time_delay < 4) begin
                        flash_cmd <= 8'd0;
                        cmd_type  <= 4'b0000;
                        time_delay <= time_delay + 1'b1;
                    end else begin
                        if (Done_Sig) begin
                            flash_cmd <= 8'd0;
                            cmd_type  <= 4'b0000;
                            if (mydata_o[0] == 1'b0) begin // 0=Flash 空闲，1=Flash 忙
                                if (se_cnt == 1'b1) begin
                                    i <= i + 4'd1;
                                    O_es_done <= 1'b1;      // 擦除完成
                                    flash_addr <= start_addr;
                                end else begin
                                    i <= 4'd2;
                                    se_cnt <= se_cnt - 1'b1;
                                    flash_addr <= flash_addr + 24'h10000; // +64KB，下一个扇区
                                    time_delay <= 32'd0;
                                end
                            end else begin
                                flash_cmd <= 8'h05; // RDSR 命令
                                cmd_type  <= 4'b1011;
                            end
                        end else begin
                            flash_cmd <= 8'h05;
                            cmd_type  <= 4'b1011;
                        end
                    end
                end

                // ========== 状态 6：等待写数据包请求 ==========
                4'd6: begin
                    O_es_done <= 1'b0; // 撤销完成信号
                    if (packet_req_pulse) begin
                        i <= 4'd7;
                        pp_stage <= 1'b0; // 准备写这包的前半个 256B
                    end
                end

                // ========== 状态 7：写使能（WREN 0x06） ==========
                4'd7: begin
                    if (Done_Sig) begin
                        flash_cmd <= 8'd0;
                        cmd_type  <= 4'b0000;
                        i <= 4'd8;
                    end else begin
                        flash_cmd <= 8'h06;
                        cmd_type  <= 4'b1001;
                    end
                end

                // ========== 状态 8：页编程（Page Program 0x02） ==========
                4'd8: begin
                    if (Done_Sig) begin
                        flash_cmd <= 8'd0;
                        cmd_type  <= 4'b0000;
                        i <= 4'd9;
                    end else begin
                        flash_cmd <= 8'h02;
                        // 1101 告诉底层读 RAM 0~255，1110 读 RAM 256~511
                        cmd_type <= (pp_stage == 1'b0) ? 4'b1101 : 4'b1110;
                    end
                end

                // ========== 状态 9：等待编程完成 ==========
                4'd9: begin
                    flash_cmd <= 8'd0;
                    cmd_type  <= 4'b0000;
                    if (time_delay < 32'd16_000) begin
                        time_delay <= time_delay + 1'b1;
                    end else begin
                        i <= 4'd10;
                        time_delay <= 32'd0;
                    end
                end

                // ========== 状态 10：读状态寄存器等待编程完成 ==========
                4'd10: begin
                    if (Done_Sig) begin
                        if (mydata_o[0] == 1'b0) begin
                            flash_cmd <= 8'd0;
                            cmd_type  <= 4'b0000;
                            flash_addr <= flash_addr + 24'd256; // 地址推进 256B

                            if (pp_stage == 1'b0) begin
                                // 第一页写完，去写这包的后半页
                                pp_stage <= 1'b1;
                                i <= 4'd7;
                            end else begin
                                // 512B 完整包全部写完
                                O_rd_bank <= ~O_rd_bank; // 翻转读取 Bank，等待下一包

                                if (packet_remain == 1) begin
                                    // 最后一包，跳转到新增的 1 秒延时状态
                                    i <= 4'd11;
                                    time_delay <= 32'd0;
                                end else begin
                                    packet_remain <= packet_remain - 1'b1;
                                    i <= 4'd6; // 回到状态 6 等待下一包触发
                                end
                            end
                        end else begin
                            time_delay <= 32'd0;
                            flash_cmd <= 8'h05;
                            cmd_type  <= 4'b1011;
                        end
                    end else begin
                        flash_cmd <= 8'h05;
                        cmd_type  <= 4'b1011;
                    end
                end

                // ========== 状态 11：最后一包完成后的 1 秒延时 ==========
                4'd11: begin
                    // 根据 clk_spi 频率调整计数值。这里假设 clk_spi = 20MHz，则 1 秒 = 20_000_000 个周期
                    if (time_delay < 32'd20_000_000) begin
                        time_delay <= time_delay + 1'b1;
                    end else begin
                        time_delay <= 32'd0;
                        i <= 4'd14;          // 延时满 1 秒，跳转到结束状态
                        O_wr_done <= 1'b1;   // 在此处输出完成信号
                    end
                end

                // ========== 状态 14：结束等待 ==========
                4'd14: begin
                    O_update_active <= 1'b0;
                    if (time_delay < 32'd16) begin
                        time_delay <= time_delay + 1'b1;
                    end else begin
                        i <= 4'd0;
                        time_delay <= 32'd0;
                        O_wr_done <= 1'b0; // 回到初始状态
                    end
                end

                default: i <= 4'd0;
            endcase
        end
    end

    // ========== 25MHz SPI 时钟生成 ==========
    // 从 80MHz CLK 分频得到 25MHz clock25M
    reg [1:0] clk_cnt;
    always @(posedge CLK) begin
        if (!RSTn) begin
            clock25M <= 1'b0;
            clk_cnt  <= 2'd0;
        end else begin
            if (clk_cnt == 2'd2) begin
                clock25M <= ~clock25M;
                clk_cnt  <= 2'd0;
            end else begin
                clk_cnt <= clk_cnt + 1'b1;
            end
        end
    end

endmodule