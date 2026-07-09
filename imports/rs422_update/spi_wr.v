`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Deng Yukun
// 
// Create Date: 2026/01/01 15:52:12
// Design Name: 
// Module Name: spi_wr
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

module spi_wr
(
    // ===================== SPI 接口 =====================
    output  wire                        flash_clk       , // SPI 时钟（由 spi_clk_en 控制）
    output  reg                         flash_cs        , // SPI 片选
    output  reg                         flash_datain    , // SPI 数据输出（MOSI）
    input   wire                        flash_dataout   , // SPI 数据输入（MISO）

    // ===================== 时钟与复位 =====================
    input   wire                        CLK             , // 系统时钟 80MHz
    input   wire                        clock25M        , // 25MHz 时钟（未使用）
    input   wire                        flash_rstn      , // 复位信号（低有效）
    input   wire                        clk_spi         , // SPI 时钟（来自外部）

    // ===================== Flash 控制接口 =====================
    input   wire                [3:0]   cmd_type        , // 命令类型（指示操作模式）
    output  reg                         Done_Sig        , // SPI 操作完成信号
    input   wire                [7:0]   flash_cmd       , // Flash 命令字节
    input   wire                [23:0]  flash_addr      , // Flash 地址

    // ===================== 乒乓 RAM 读取接口 =====================
    output  wire                [8:0]   O_ping_pong_rd_addr, // 乒乓 RAM 读地址
    input   wire                [7:0]   I_ping_pong_rd_data, // 乒乓 RAM 读数据

    // ===================== 数据输出 =====================
    output  reg                 [7:0]   mydata_o        , // 从 Flash 读回的数据（用于 RDSR）
    output  wire                        myvalid_o       , // 数据有效标志
    output  wire                        O_spi_read        // 1=正在读 MISO（此时 IOBUF 应切为输入模式，T=1）
);

    // ===================== 内部信号定义 =====================
    reg                             myvalid         ; // 数据有效内部寄存器
    reg                     [7:0]   mydata          ; // 数据缓存
    reg                             spi_clk_en      ; // SPI 时钟使能
    reg                             data_come       ; // 数据接收标志

    // ===================== 状态机参数定义 =====================
    localparam idle         = 7'b0000001; // 空闲状态
    localparam cmd_send     = 7'b0000010; // 发送命令
    localparam address_send = 7'b0000100; // 发送地址
    localparam read_wait    = 7'b0001000; // 等待读取数据
    localparam write_data   = 7'b0010000; // 写入数据到 Flash
    localparam write_143    = 7'b0100000; // （未使用）
    localparam finish_done  = 7'b1000000; // 操作完成

    (* mark_debug = "true" *) reg     [6:0]   spi_state   ; // SPI 写状态机
    reg                     [7:0]   cmd_reg         ; // 命令寄存器
    reg                     [23:0]  address_reg     ; // 地址寄存器
    reg                     [7:0]   cnta            ; // 发送位计数
    (* mark_debug = "true" *) reg     [8:0]   write_cnt   ; // 当前页已写字节数（0~256）
    reg                     [7:0]   cntb            ; // 接收位计数
    reg                     [8:0]   read_cnt        ; // 已读字节数
    reg                     [8:0]   read_num        ; // 本次要读的总字节数
    reg                             read_finish     ; // 读取完成标志

    // ================== 预取逻辑（用于消除 BRAM 读延迟） ==================
    reg                     [8:0]   base_addr       ; // RAM 基地址（0 或 256）
    reg                     [8:0]   ram_rd_ptr      ; // RAM 读指针，比 write_cnt 快 1 拍
    reg                     [7:0]   shift_reg       ; // 移位寄存器，用于串行发送

    // 给乒乓 RAM 的读地址 = 基址 + ram_rd_ptr
    assign O_ping_pong_rd_addr = base_addr + ram_rd_ptr;
	// SPI 时钟输出：spi_clk_en 有效时输出 clk_spi，否则拉低
    assign flash_clk = spi_clk_en ? clk_spi : 1'b0;
    assign myvalid_o = myvalid;
    // 当处于 read_wait 状态时，表示正在从 Flash 读取数据（MISO 为输入）
    assign O_spi_read = (spi_state == read_wait);

    // ===================== 主 SPI 发送状态机（在 clk_spi 的下降沿） =====================
    always @(negedge clk_spi) begin
        if (!flash_rstn) begin
            flash_cs      <= 1'b1;
            spi_state     <= idle;
            cmd_reg       <= 8'd0;
            address_reg   <= 24'd0;
            spi_clk_en    <= 1'b0;
            cnta          <= 8'd0;
            write_cnt     <= 9'd0;
            read_num      <= 9'd0;
            Done_Sig      <= 1'b0;
            base_addr     <= 9'd0;
            shift_reg     <= 8'd0;
            ram_rd_ptr    <= 9'd0;
        end else begin
            case (spi_state)
                idle: begin
                    spi_clk_en <= 1'b0;
                    flash_cs   <= 1'b1;
                    flash_datain <= 1'b1;
                    cmd_reg    <= flash_cmd;
                    address_reg <= flash_addr;
                    Done_Sig   <= 1'b0;
                    ram_rd_ptr <= 9'd0; // 空闲时指针归零

                    // 根据 cmd_type 决定这次写 RAM 0~255 还是 256~511
                    if (cmd_type == 4'b1101)
                        base_addr <= 9'd0;
                    else if (cmd_type == 4'b1110)
                        base_addr <= 9'd256;

                    if (cmd_type[3] == 1'b1) begin
                        spi_state <= cmd_send;
                        cnta      <= 8'd7;
                        write_cnt <= 9'd0;
                        read_num  <= 9'd0;
                    end
                end

                cmd_send: begin
                    spi_clk_en <= 1'b1;
                    flash_cs   <= 1'b0;
                    if (cnta > 8'd0) begin
                        flash_datain <= cmd_reg[cnta];
                        cnta <= cnta - 8'd1;
                    end else begin
                        flash_datain <= cmd_reg[0];
                        if ((cmd_type[2:0] == 3'b001) || (cmd_type[2:0] == 3'b100)) begin
                            spi_state <= finish_done;
                        end else if (cmd_type[2:0] == 3'b011) begin
                            spi_state <= read_wait;
                            cnta      <= 8'd7;
                            read_num  <= 9'd1;
                        end else begin
                            spi_state <= address_send;
                            cnta      <= 8'd23;
                        end
                    end
                end

                address_send: begin
                    if (cnta > 8'd0) begin
                        flash_datain <= address_reg[cnta];
                        cnta <= cnta - 8'd1;
                    end else begin
                        flash_datain <= address_reg[0];
                        if (cmd_type[2:0] == 3'b010) begin
                            spi_state <= finish_done;
                        end else if (cmd_type[2:0] == 3'b101 || cmd_type[2:0] == 3'b110) begin
                            spi_state <= write_data;
                            cnta      <= 8'd7;
                            write_cnt <= 9'd0;
                            // 进入写状态时，获取第 0 个字节，并将读指针预取到第 1 个字节
                            shift_reg   <= I_ping_pong_rd_data;
                            ram_rd_ptr  <= 9'd1;
                        end else begin
                            spi_state <= read_wait;
                            read_num  <= 9'd256;
                        end
                    end
                end

                read_wait: begin
                    if (read_finish) begin
                        spi_state <= finish_done;
                        data_come <= 1'b0;
                    end else begin
                        data_come <= 1'b1;
                    end
                end

                write_data: begin
                    if (write_cnt < 9'd256) begin
                        if (cnta > 8'd0) begin
                            flash_datain <= shift_reg[cnta]; // 从高到低发送
                            cnta <= cnta - 8'd1;
                        end else begin
                            flash_datain <= shift_reg[0];
                            cnta <= 8'd7;
                            write_cnt <= write_cnt + 9'd1;
                            // 字节切换时，获取当前预取的字节，并继续预取下一个字节
                            shift_reg  <= I_ping_pong_rd_data;
                            ram_rd_ptr <= ram_rd_ptr + 9'd1;
                        end
                    end else begin
                        spi_state <= finish_done;
                        spi_clk_en <= 1'b0;
                    end
                end

                finish_done: begin
                    flash_cs <= 1'b1;
                    flash_datain <= 1'b1;
                    spi_clk_en <= 1'b0;
                    Done_Sig <= 1'b1;
                    spi_state <= idle;
                end

                default: spi_state <= idle;
            endcase
        end
    end

    // ===================== 接收 Flash 数据（在 clk_spi 的上升沿） =====================
    always @(posedge clk_spi) begin
        if (!flash_rstn) begin
            read_cnt    <= 9'd0;
            cntb        <= 8'd0;
            read_finish <= 1'b0;
            myvalid     <= 1'b0;
            mydata      <= 8'hff;
            mydata_o    <= 8'hff;
        end else begin
            if (data_come) begin
                if (read_cnt < read_num) begin
                    if (cntb < 8'd7) begin
                        myvalid <= 1'b0;
                        mydata  <= {mydata[6:0], flash_dataout};
                        cntb    <= cntb + 8'd1;
                    end else begin
                        myvalid <= 1'b1;
                        mydata_o <= {mydata[6:0], flash_dataout};
                        cntb    <= 8'd0;
                        read_cnt <= read_cnt + 9'd1;
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