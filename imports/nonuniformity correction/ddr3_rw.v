`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Deng Yukun
// 
// Create Date: 2026/01/01 15:52:12
// Design Name: 
// Module Name: DDR3_rw
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

module ddr3_rw
(
    // ===================== 输入信号 =====================
    input                           ui_clk              , // 用户时钟（来自 MIG）
    input                           ui_clk_sync_rst     , // MIG 提供的复位（高有效）
    input                           init_calib_complete , // DDR3 初始化完成
    input                           app_rdy             , // MIG IP 核就绪
    input                           app_wdf_rdy         , // MIG 写 FIFO 空闲
    input                           app_rd_data_valid   , // 读数据有效
    input                           I_wram_sample_finish, // 写 FIFO 写满信号
    input                           I_rram_rq_read      , // 读缓存请求读

    // ===================== 输出信号 =====================
    output                          rram_wren           , // 从 DDR3 读出数据的有效使能
    output                  [28:0]  app_addr            , // DDR3 地址
    output                          app_en              , // MIG IP 核操作使能
    output                          app_wdf_wren        , // 用户写使能（给 MIG）
    output                          app_wdf_end         , // 突发写当前时钟最后一个数据
    output                  [2:0]   app_cmd             , // MIG IP 核操作命令（读/写）
    output reg                      ddr_wr_finish       , // DDR 写完成
    output reg                      read_ram_en         , // 读 RAM 使能
    (* MARK_DEBUG="true" *) output reg    fifo_ddr_done, // FIFO 到 DDR 写入完成
    output reg              [3:0]   wram_rd_addr          // WRAM 读地址
);

    // ===================== 参数定义 =====================
    // 状态机编码
    localparam IDLE        = 6'b000001;   // 空闲状态
    localparam DDR3_DONE   = 6'b000010;   // DDR3 初始化完成状态
    localparam WRITE       = 6'b000100;   // 写 FIFO 保持状态
    localparam READ_k      = 6'b001000;   // 读 FIFO 保持状态
    localparam INIT_kb     = 6'b010000;   // 初始化 KB，先写入两行数据进 RAM
    localparam WRITE_DONE  = 6'b100000;   // 发送写一页完成信号给 RAM

    // 读写地址与突发长度参数
    parameter app_addr_rd_k_min = 28'd128;   // 读 K 的 DDR3 起始地址（128，多写的一页无效数据直接跳过）
    parameter app_addr_rd_k_max = 28'd655480;// 读 DDR3 结束地址（655480 = 5240 * 128? 实际需计算）
    parameter rd_bust_len_k     = 8'd160;    // 从 DDR3 中读数据时的突发长度（640*8/64）
    parameter app_addr_wr_min   = 28'd0;     // 写 DDR3 起始地址
    parameter app_addr_wr_max   = 28'd655480;// 写 DDR3 结束地址
    parameter wr_bust_len       = 8'd16;     // 从 DDR3 中写数据时的突发长度
    parameter app_addr_rd_b_min = 28'd327680;// 读 DDR3 起始地址（B 组）
    parameter app_addr_rd_b_max = 28'd983032;// 读 DDR3 结束地址（B 组）
    parameter rd_bust_len_b     = 8'd160;    // 从 DDR3 中读数据时的突发长度（640*16/64）

    // ===================== 内部信号定义 =====================
    reg                     [27:0]  app_addr_rd        ; // DDR3 读地址
    reg                     [27:0]  app_addr_wr        ; // DDR3 写地址
    (* MARK_DEBUG="true" *) reg     [5:0]   state_cnt  ; // 状态机计数器
    (* MARK_DEBUG="true" *) reg     [9:0]   rd_addr_cnt; // 用户读地址计数
    reg                     [9:0]   wr_addr_cnt        ; // 用户写地址计数
    reg                     [3:0]   ddr_finish_cnt     ; // ddr_wr_finish 延迟计数

    // 异步信号打拍同步
    reg                     [1:0]   I_wram_sample_finish_a; // 写采样完成信号打拍
    reg                     [1:0]   I_rram_rq_read_a     ; // 读请求信号打拍
    reg                     [1:0]   sample_cl_finish    ; // 采样完成打拍（未用）
    reg                     [2:0]   ddr_w_finish_cnt    ; // DDR 写完成计数（未用）
    reg                     [1:0]   init_kb_finish      ; // 初始化 KB 完成计数

    wire                            rst_n               ; // 内部复位（低有效）

    // ===================== 组合逻辑赋值 =====================
    assign rst_n = ~ui_clk_sync_rst;

    // 将数据有效信号赋给 rram 写使能
    assign rram_wren = app_rd_data_valid;

    // app_en：在写状态 MIG 空闲且写有效，或读状态 MIG 空闲时拉高
    assign app_en = ((state_cnt == WRITE && (app_rdy && app_wdf_rdy)) ||
                     (state_cnt == READ_k && app_rdy) ||
                     (state_cnt == INIT_kb && app_rdy)) ? 1'b1 : 1'b0;

    // app_wdf_wren：写状态时 MIG 空闲且写有效则拉高
    assign app_wdf_wren = (state_cnt == WRITE && (app_rdy && app_wdf_rdy)) ? 1'b1 : 1'b0;

    // 突发长度 8，故 app_wdf_end = app_wdf_wren
    assign app_wdf_end = app_wdf_wren;

    // app_cmd：读状态或初始化 KB 时命令为 1（读），否则为 0（写）
    assign app_cmd = (state_cnt == READ_k || state_cnt == INIT_kb) ? 3'd1 : 3'd0;

    // app_addr：读状态或初始化 KB 时使用读地址，否则使用写地址
    assign app_addr = ((state_cnt == READ_k) || (state_cnt == INIT_kb)) ? app_addr_rd : app_addr_wr;

    // ===================== 异步信号同步打拍 =====================
    always @(posedge ui_clk or negedge rst_n) begin
        if (~rst_n) begin
            I_wram_sample_finish_a <= 2'b00;
            I_rram_rq_read_a       <= 2'b00;
        end else begin
            I_wram_sample_finish_a[0] <= I_wram_sample_finish;
            I_wram_sample_finish_a[1] <= I_wram_sample_finish_a[0];

            I_rram_rq_read_a[0] <= I_rram_rq_read;
            I_rram_rq_read_a[1] <= I_rram_rq_read_a[0];
        end
    end

    // ===================== DDR3 读写状态机 =====================
    always @(posedge ui_clk or negedge rst_n) begin
        if (~rst_n) begin
            state_cnt       <= IDLE;
            wr_addr_cnt     <= 10'd0;
            rd_addr_cnt     <= 10'd0;
            app_addr_wr     <= app_addr_wr_min;
            app_addr_rd     <= app_addr_rd_k_min;
            fifo_ddr_done   <= 1'b0;
            wram_rd_addr    <= 4'd0;
            init_kb_finish  <= 2'd0;
            ddr_wr_finish   <= 1'b0;
            ddr_finish_cnt  <= 4'd0;
            read_ram_en     <= 1'b0;
        end else begin
            case (state_cnt)
                // ---------- IDLE：等待 DDR 初始化完成 ----------
                IDLE: begin
                    if (init_calib_complete)
                        state_cnt <= DDR3_DONE;
                    else
                        state_cnt <= IDLE;
                end

                // ---------- DDR3_DONE：等待写请求或读请求 ----------
                DDR3_DONE: begin
                    // 读地址达到结束地址时复位
                    if (app_addr_rd >= app_addr_rd_k_max) begin
                        state_cnt   <= DDR3_DONE;
                        rd_addr_cnt <= 10'd0;
                        app_addr_rd <= app_addr_rd_k_min;
                    end
                    // 写地址达到结束地址时复位
                    else if (app_addr_wr >= app_addr_wr_max) begin
                        state_cnt   <= DDR3_DONE;
                        wr_addr_cnt <= 10'd0;
                        app_addr_wr <= app_addr_wr_min;
                        init_kb_finish <= 2'd2;
                    end
                    // 收到写 FIFO 满信号，进入写状态
                    else if (I_wram_sample_finish_a == 2'b01) begin
                        state_cnt     <= WRITE;
                        wr_addr_cnt   <= 10'd0;
                        app_addr_wr   <= app_addr_wr;
                        wram_rd_addr  <= wram_rd_addr + 1; // dpram 输出有 1 个 clk 延迟，提前 +1
                    end
                    // 初始化 KB 完成计数不为 0，进入 INIT_kb 状态
                    else if (init_kb_finish != 2'd0) begin
                        state_cnt     <= INIT_kb;
                        rd_addr_cnt   <= 10'd0;
                        app_addr_rd   <= app_addr_rd;
                        init_kb_finish <= init_kb_finish - 1;
                        read_ram_en   <= 1'b1;
                    end
                    // 收到读请求，进入读状态
                    else if (I_rram_rq_read_a == 2'b01) begin
                        state_cnt     <= READ_k;
                        rd_addr_cnt   <= 10'd0;
                        app_addr_rd   <= app_addr_rd;
                        read_ram_en   <= 1'b1;
                    end
                    else begin
                        state_cnt <= DDR3_DONE;
                    end
                end

                // ---------- WRITE：写 DDR3 ----------
                WRITE: begin
                    if ((wr_addr_cnt == (wr_bust_len - 1'b1)) && (app_rdy && app_wdf_rdy)) begin
                        // 写满设定的长度，进入写完成状态
                        state_cnt   <= WRITE_DONE;
                        app_addr_wr <= app_addr_wr + 4'd8; // 最后一组突发写 8 个数，地址 +8
                        wr_addr_cnt <= wr_addr_cnt + 1'b1;
                        wram_rd_addr <= 4'd0; // wram 地址置 0，为下次读 wram 做准备
                    end
                    else if (app_rdy && app_wdf_rdy) begin
                        // 写条件满足，正常写入
                        wr_addr_cnt  <= wr_addr_cnt + 1'b1;
                        wram_rd_addr <= wram_rd_addr + 1;
                        app_addr_wr  <= app_addr_wr + 4'd8; // 每次突发写 8 个数，地址 +8
                    end
                    else begin
                        // 写条件不满足，保持当前状态
                        wr_addr_cnt  <= wr_addr_cnt;
                        app_addr_wr  <= app_addr_wr;
                        wram_rd_addr <= wram_rd_addr;
                    end
                end

                // ---------- INIT_kb：初始化 KB 数据（读 DDR） ----------
                INIT_kb: begin
                    if ((rd_addr_cnt == (rd_bust_len_k - 1'b1)) && (app_rdy)) begin
                        // 读满设定长度，返回 DDR3_DONE
                        state_cnt   <= DDR3_DONE;
                        app_addr_rd <= app_addr_rd + 4'd8; // 传最后一个地址
                        rd_addr_cnt <= rd_addr_cnt + 1'b1;
                        if (init_kb_finish == 2'd0) begin
                            fifo_ddr_done <= 1'b1;
                        end
                    end
                    else if (app_rdy) begin
                        // MIG 已准备好，继续读
                        rd_addr_cnt <= rd_addr_cnt + 1'b1;
                        app_addr_rd <= app_addr_rd + 4'd8; // 每次读 8 个数，地址 +8
                        read_ram_en <= 1'b0;
                    end
                    else begin
                        // MIG 未准备好，保持
                        rd_addr_cnt <= rd_addr_cnt;
                        app_addr_rd <= app_addr_rd;
                    end
                end

                // ---------- READ_k：正常读 DDR ----------
                READ_k: begin
                    if ((rd_addr_cnt == (rd_bust_len_k - 1'b1)) && (app_rdy)) begin
                        // 读满设定长度，返回 DDR3_DONE
                        state_cnt   <= DDR3_DONE;
                        app_addr_rd <= app_addr_rd + 4'd8;
                        rd_addr_cnt <= rd_addr_cnt + 1'b1;
                    end
                    else if (app_rdy) begin
                        // MIG 已准备好，继续读
                        rd_addr_cnt <= rd_addr_cnt + 1'b1;
                        app_addr_rd <= app_addr_rd + 4'd8;
                        read_ram_en <= 1'b0;
                    end
                    else begin
                        // MIG 未准备好，保持
                        rd_addr_cnt <= rd_addr_cnt;
                        app_addr_rd <= app_addr_rd;
                    end
                end

                // ---------- WRITE_DONE：写完成，延迟输出完成信号 ----------
                WRITE_DONE: begin
                    if (ddr_finish_cnt == 4'd3) begin
                        ddr_wr_finish <= 1'b0;
                        ddr_finish_cnt <= 4'd0;
                        state_cnt <= DDR3_DONE;
                    end else begin
                        ddr_wr_finish <= 1'b1;
                        ddr_finish_cnt <= ddr_finish_cnt + 1'b1;
                    end
                end

                default: begin
                    state_cnt   <= IDLE;
                    wr_addr_cnt <= 10'd0;
                    rd_addr_cnt <= 10'd0;
                end
            endcase
        end
    end

endmodule