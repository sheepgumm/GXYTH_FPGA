`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Deng Yukun
// 
// Create Date: 2026/01/01 15:52:12
// Design Name: 
// Module Name: read_kb_from_flash1_1
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

module read_kb_from_flash1_1
(
    // ===================== Flash SPI 接口 =====================
    (*mark_debug = "true"*) output  wire            flash_clk       , // Flash 时钟（由 SPI 使能控制）
    output  reg                     flash_cs        , // Flash 片选
    output  wire                    D0_o            , // D0 输出（MOSI/写数据）
    input   wire                    D0_i            , // D0 输入（MISO/读数据）
    output  wire                    D1_o            , // D1 输出（Dual Output 数据线）
    input   wire                    D1_i            , // D1 输入（Dual Output 读数据）

    // ===================== 时钟与复位 =====================
    input                           flash_spi_clk   , // SPI 时钟（来自 flash_top）
    input   wire                    CLK             , // 系统时钟 80MHz
    input   wire                    flash_rstn      , // 复位信号（低有效）

    // ===================== DDR 初始化与状态 =====================
    input   wire                    ddr_init_done   , // DDR 初始化完成
    (*mark_debug = "true"*) output  wire            k_b_finish_O    , // KB 参数读取完成标志
    output  reg             [7:0]   mydata_o        , // 输出 8bit 数据（给 DDR FIFO）
    output  wire                    myvalid_o       , // 数据有效信号
    (*mark_debug = "true"*) output  wire            shift_sig       , // SPI 时钟使能（用于 FIFO 写入）
    output  wire            [7:0]   o_data_sim      , // 仿真数据输出（未用）
    output  wire            [8:0]   flash_read_num_test, // 已读取的 Flash 页数（测试用）

    // ===================== RS422 参数更新接口 =====================
    (*mark_debug = "true"*) input   wire            update_active   , // 1=正在更新 Flash，本模块挂起 SPI 并将 D0/D1 设为高阻
    input   wire                    re_read_req     , // 重新读取请求（1拍高脉冲），清除 k_b_finish 并重置地址
    input   wire                    I_wr_mosi       , // 更新模式下写入数据（由 flash_top 传入），驱动 D0
    output  wire                    flash_io_sig      // 读模式=1(FPGA 不驱动 D0/D1)，写模式=0(FPGA 驱动)
);

    // ===================== 内部信号定义 =====================
    reg                             clock25M        ; // 分频后的 SPI 时钟（25MHz? 实际为 40MHz）
    reg                             myvalid         ; // 数据有效内部寄存器
    reg                     [7:0]   mydata          ; // 数据缓存
    reg                             spi_clk_en      ; // SPI 时钟使能
    reg                             data_come       ; // 数据接收标志
    reg                             IO0             ; // D0 输出数据
    reg                             IO1             ; // D1 输出数据
    reg                             io_sig          ; // IO 方向控制（1=高阻，0=输出）
    reg                     [3:0]   dummy_cnt       ; // 虚拟字节计数（用于等待 Flash 数据就绪）

    // 状态机状态定义
    localparam idle        = 3'b000;
    localparam cmd_send    = 3'b001;
    localparam address_send = 3'b010;
    localparam read_wait   = 3'b011;
    localparam finish_done = 3'b110;

    // Flash 地址参数
    parameter kb_start_addr     = 24'd5242624; // 起始地址（跳过全 0 数据页）第一个页读到的全是1111，所以从数据的前一页 多读一页
    parameter kb_end_page_addr  = 24'd6553344; // 结束地址

    reg                     [2:0]   spi_state       ; // SPI 状态机
    reg                     [7:0]   cmd_reg         ; // 命令寄存器
    reg                     [23:0]  address_reg     ; // 地址寄存器
    reg                     [7:0]   cnta            ; // 发送计数
    reg                     [7:0]   cntb            ; // 接收计数
    reg                     [8:0]   read_cnt        ; // 已读字节数
    reg                     [8:0]   read_num        ; // 本次要读的总字节数
    reg                             read_finish     ; // 读取完成标志
    (*mark_debug = "true"*) reg     k_b_finish      ; // KB 读取完成内部标志
    reg                     [9:0]   fifo_delay_cnt  ; // FIFO 延迟计数（未使用）
    reg                     [1:0]   ddr_init_done_a ; // ddr_init_done 同步打拍
    reg                     [3:0]   clock25M_cnt    ; // 分频计数器

    // 仿真用
    reg                     [7:0]   sim_data        ; // 仿真数据
    reg                     [1:0]   tag             ; // 仿真标志
    reg                     [7:0]   sim_data2       ; // 仿真数据2

    // 更新状态同步
    reg                     [1:0]   update_active_spi; // update_active 同步到 SPI 时钟域
    reg                             update_active_spi_delay; // 延时一拍，用于下降沿检测

    // ===================== 输出赋值 =====================
    assign myvalid_o     = myvalid;
    assign k_b_finish_O  = k_b_finish;
    assign shift_sig     = spi_clk_en;
    assign flash_read_num_test = read_cnt;
    assign o_data_sim    = sim_data;

    // ===================== D0/D1 输出驱动 =====================
    // update_active=1：spi_wr 写入模式，D0_o 输出 I_wr_mosi
    // io_sig=1        ：读数据模式，D0_o/D1_o 高阻（1'bz）→ 顶层 IOBUF 转向输入
    // 其他            ：正常输出模式，D0_o/D1_o 输出 IO0/IO1
    assign D0_o = update_active ? I_wr_mosi : (io_sig ? 1'bz : IO0);
    assign D1_o = (io_sig || update_active) ? 1'bz : IO1;

    // update_active 时停止 SPI 时钟输出
    assign flash_clk = (spi_clk_en && !update_active) ? flash_spi_clk : 1'b0;

    // ===================== flash_io_sig 输出 =====================
    // 读模式=1（FPGA 高阻 OE=0），写模式=0（FPGA 驱动 OE=1）
    assign flash_io_sig = io_sig;

    // ===================== 产生 40MHz SPI 时钟（分频） =====================
    always @(posedge CLK or negedge flash_rstn) begin
        if (!flash_rstn) begin
            clock25M     <= 1'b0;
            clock25M_cnt <= 4'd0;
        end else begin
            if (clock25M_cnt == 4'd1) begin
                clock25M     <= ~clock25M;
                clock25M_cnt <= 4'd0;
            end else begin
                clock25M     <= clock25M;
                clock25M_cnt <= clock25M_cnt + 1'b1;
            end
        end
    end

    // ===================== 同步异步信号 =====================
    // ddr_init_done 同步到 SPI 时钟域
    always @(posedge flash_spi_clk or negedge flash_rstn) begin
        if (!flash_rstn) begin
            ddr_init_done_a <= 2'b00;
        end else begin
            ddr_init_done_a[0] <= ddr_init_done;
            ddr_init_done_a[1] <= ddr_init_done_a[0];
        end
    end

    // update_active 同步到 SPI 时钟域
    always @(posedge flash_spi_clk or negedge flash_rstn) begin
        if (!flash_rstn) begin
            update_active_spi <= 2'b00;
        end else begin
            update_active_spi[0] <= update_active;
            update_active_spi[1] <= update_active_spi[0];
        end
    end

    // ===================== 检测 update_active 下降沿作为重新读取触发 =====================
    // 在 SPI 时钟的下降沿打一拍，用于比较前后状态
    always @(negedge flash_spi_clk or negedge flash_rstn) begin
        if (!flash_rstn)
            update_active_spi_delay <= 1'b0;
        else
            update_active_spi_delay <= update_active_spi[1];
    end

    // 产生下降沿脉冲：上一拍是高电平，当前拍是低电平
    wire update_done_pulse = (~update_active_spi[1]) & update_active_spi_delay;

    // ===================== 主 SPI 发送状态机 =====================
    always @(negedge flash_spi_clk or negedge flash_rstn) begin
        if (!flash_rstn) begin
            flash_cs      <= 1'b1;
            spi_state     <= idle;
            cmd_reg       <= 8'd0;
            address_reg   <= kb_start_addr;       // Flash 起始地址
            spi_clk_en    <= 1'b0;                // SPI 时钟输出不使能
            cnta          <= 8'd0;
            read_num      <= 9'd0;
            k_b_finish    <= 1'b0;
            io_sig        <= 1'b0;
            dummy_cnt     <= 4'd0;
            fifo_delay_cnt <= 10'd0;
        end else begin
            // ====== 重新读取触发：检测到 update_active 下降沿时重置状态机 ======
            if (update_done_pulse) begin
                k_b_finish    <= 1'b0;
                address_reg   <= kb_start_addr;
                spi_state     <= idle;
                flash_cs      <= 1'b1;
                spi_clk_en    <= 1'b0;
                io_sig        <= 1'b0;
            end
            // ====== 更新进行中：暂停 SPI 操作 ======
            else if (update_active_spi[1]) begin
                flash_cs   <= 1'b1;      // CS 拉高，释放 Flash 片选
                spi_clk_en <= 1'b0;      // 停止 SPI 时钟
                io_sig     <= 1'b1;      // D0/D1 高阻
                // spi_state 保持不变，等待 update 结束后继续
            end
            else begin
                case (spi_state)
                    idle: begin
                        if (ddr_init_done_a[1] == 1'b1) begin   // DDR 初始化完成
                            spi_clk_en <= 1'b0;
                            flash_cs   <= 1'b1;
                            IO0        <= 1'b1;
                            IO1        <= 1'b1;
                            io_sig     <= 1'b0;
                            cmd_reg    <= 8'hBB;                // Page Read 命令
                            if (!k_b_finish) begin              // 未完成，继续读取
                                spi_state <= cmd_send;
                                cnta      <= 8'd7;
                                read_num  <= 9'd0;
                            end else begin
                                spi_state <= idle;
                            end
                        end else begin
                            spi_state <= idle;
                        end
                    end

                    cmd_send: begin
                        spi_clk_en <= 1'b1;    // Flash SPI 时钟输出使能
                        io_sig     <= 1'b0;
                        flash_cs   <= 1'b0;    // CS 拉低
                        if (cnta > 8'd0) begin
                            IO0 <= cmd_reg[cnta];    // 发送 bit7~bit1
                            cnta <= cnta - 8'd1;
                        end else begin
                            IO0 <= cmd_reg[0];       // 发送 bit0
                            spi_state <= address_send;
                            cnta      <= 8'd23;
                        end
                    end

                    address_send: begin
                        if (cnta > 8'd1) begin
                            IO1 <= address_reg[cnta];       // 发送 bit23~bit1
                            IO0 <= address_reg[cnta - 8'b1];
                            cnta <= cnta - 8'd2;
                        end else begin
                            IO1 <= address_reg[1];
                            IO0 <= address_reg[0];
                            spi_state <= read_wait;
                            read_num  <= 9'd256;           // 如果是 Block Read 命令，接收 256 个数据
                            dummy_cnt <= 4'd0;
                        end
                    end

                    read_wait: begin
                        io_sig <= 1'b1;
                        if (read_finish) begin
                            spi_state <= finish_done;
                            data_come <= 1'b0;
                            if (address_reg >= kb_end_page_addr) begin
                                k_b_finish <= 1'b1;
                            end else begin
                                address_reg <= address_reg + 24'd256;
                            end
                        end else begin
                            if (dummy_cnt == 4'd4) begin   // 等待 4 个 dummy 字节
                                data_come <= 1'b1;
                            end else begin
                                dummy_cnt <= dummy_cnt + 1'b1;
                            end
                        end
                    end

                    finish_done: begin
                        flash_cs   <= 1'b1;
                        IO0        <= 1'b1;
                        IO1        <= 1'b1;
                        spi_clk_en <= 1'b0;
                        spi_state  <= idle;
                        io_sig     <= 1'b0;
                    end

                    default: spi_state <= idle;
                endcase
            end
        end
    end

    // ===================== 接收 Flash 数据 =====================
    always @(negedge flash_spi_clk or negedge flash_rstn) begin
        if (!flash_rstn) begin
            read_cnt     <= 9'd0;
            cntb         <= 8'd0;
            read_finish  <= 1'b0;
            myvalid      <= 1'b0;
            mydata       <= 8'd0;
            mydata_o     <= 8'd0;
            sim_data     <= 8'd0;
            sim_data2    <= 8'd97;
            tag          <= 2'd0;
        end else begin
            if (data_come) begin
                if (read_cnt < read_num) begin          // 接收数据
                    if (cntb < 8'd6) begin              // 接收一个字节的 bit0~bit6
                        myvalid <= 1'b0;
                        mydata <= {mydata[5:0], D1_i, D0_i};
                        cntb   <= cntb + 8'd2;
                    end else begin
                        myvalid <= 1'b1;                // 一个字节数据有效
                        mydata_o <= {mydata[5:0], D1_i, D0_i}; // 接收 bit7
                        cntb     <= 8'd0;
                        read_cnt <= read_cnt + 9'd1;
                        // 仿真数据生成（仅用于测试）
                        if (sim_data2 == 8'd160 && tag == 2'd1) begin
                            sim_data  <= sim_data2;
                            sim_data2 <= 8'd1;
                            tag       <= tag + 1'b1;
                        end else begin
                            tag <= tag + 1'b1;
                            if (tag == 2'd1) begin
                                sim_data  <= sim_data2;
                                sim_data2 <= sim_data2 + 1'b1;
                            end else begin
                                sim_data <= 8'd0;
                            end
                        end
                    end
                end else begin
                    read_cnt    <= 9'd0;
                    read_finish <= 1'b1;
                    myvalid     <= 1'b0;
                end
            end else begin
                read_cnt    <= 9'd0;
                cntb        <= 8'd0;
                read_finish <= 1'b0;
                myvalid     <= 1'b0;
                mydata      <= 8'd0;
            end
        end
    end

endmodule