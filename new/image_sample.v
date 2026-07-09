`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Deng Yukun
// 
// Create Date: 2026/01/01 15:52:12
// Design Name: 
// Module Name: image_sample
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

module image_sample(
	// ===================== 时钟与复位 =====================
    input                           I_clk               , // 80M系统时钟
    input                           I_rst               , // 复位信号
    input                           I_adc_clk           , // ADC采样时钟
    input                           I_cl_clk            , // GTX用户读取时钟
    
    // ===================== 控制与状态信号 =====================
    input                           I_line_vaild        , // 行有效信号(来自探测器驱动)
    input                           fifo_ddr_done       , // DDR存储完成标志
    input                   [7:0]   two_point_sig       , // 两点校正模式选择
    input                           I_data_rd_finish    , // 数据读取完成信号
    input                           fco                 , // 帧同步时钟
    
    // ===================== ADC输入数据 =====================
    input                   [15:0]  I_dataA1            , // ADC通道A数据
    input                   [15:0]  I_dataB1            , // ADC通道B数据
    input                   [15:0]  I_dataC1            , // ADC通道C数据
    input                   [15:0]  I_dataD1            , // ADC通道D数据
    
    // ===================== 地址与行号 =====================
    input                   [9:0]   last_line_addr      , // 最后一行地址
    input                   [9:0]   I_addr_rd1          , // RAM读取地址1
    input                   [9:0]   I_addr_rd2          , // RAM读取地址2
    input                   [9:0]   I_addr_rd3          , // RAM读取地址3
    input                   [15:0]  I_read_row          , // Aurora模块当前的读取行号

    // ===================== 校正系数 =====================
    input                   [127:0] kb_data             , // K/B 校正系数
    
    // ===================== 输出信号 =====================
    output                  [63:0]  O_sample_data       , // 采样数据输出
    output                          O_two_point_start   , // 两点校正启动信号
    output reg                      O_sample_finish     , // 采样完成标志
    output reg              [9:0]   O_read_ram_addr1    , // 读取RAM地址1
    output reg              [9:0]   O_read_ram_addr2    , // 读取RAM地址2
    output reg                      read_rram_finish1   , // RAM1读取结束
    output reg                      read_rram_finish2   , // RAM2读取结束
    output                          rram_rclk             // RAM读取时钟
);
	
    // ===================== 内部信号定义 =====================
    // 同步信号打拍
reg                     [1:0]   rd_finish_sample        ; // 读完成信号同步
reg                     [1:0]   row_st_sample           ; // 行同步信号同步
(*mark_debug = "true"*)reg   [5:0]  fco_sample          ; // FCO时钟同步

// RAM控制信号
(*mark_debug = "true"*)reg          rama_en             ; // RAM A 使能
(*mark_debug = "true"*)reg          ramb_en             ; // RAM B 使能
(*mark_debug = "true"*)reg  [3:0]   rama_sample_fsm     ; // RAM A 采样状态机
(*mark_debug = "true"*)reg  [3:0]   ramb_sample_fsm     ; // RAM B 采样状态机

   // DSP运算中间信号
    wire                    [15:0]  tempA               ; // 临时数据A
    wire                    [15:0]  tempB               ; // 临时数据B
    wire                    [15:0]  tempC               ; // 临时数据C
    wire                    [15:0]  tempD               ; // 临时数据D
    wire                    [15:0]  tempA_a             ; // 运算中间值A
    wire                    [15:0]  tempB_a             ; // 运算中间值B
    wire                    [15:0]  tempC_a             ; // 运算中间值C
    wire                    [15:0]  tempD_a             ; // 运算中间值D

    reg                     [67:0]  dina                ; // RAM写入数据总线

    // RAM A 接口
(*mark_debug = "true"*)reg          ena1                ; // RAM使能1
(*mark_debug = "true"*)reg          wea1                ; // RAM写使能1
(*mark_debug = "true"*)reg          enb1                ; // RAM读使能1
    wire                    [135:0] doutaa1             ; // RAM A输出
    wire                    [67:0]  douta1              ; // 通道1数据
    wire                    [67:0]  douta2              ; // 通道2数据
    wire                    [67:0]  douta3              ; // 通道3数据

    // RAM B 接口
(*mark_debug = "true"*)reg          ena2                ; // RAM使能2
(*mark_debug = "true"*)reg          wea2                ; // RAM写使能2
(*mark_debug = "true"*)reg          enb2                ; // RAM读使能2
    wire                    [135:0] doutbb1             ; // RAM B输出
    wire                    [67:0]  doutb1              ; // 通道1数据
    wire                    [67:0]  doutb2              ; // 通道2数据
    wire                    [67:0]  doutb3              ; // 通道3数据


    // 地址与计数
    (*mark_debug = "true"*) reg     [9:0]   addra1              ; // 地址A1
    (*mark_debug = "true"*) reg     [9:0]   addra2              ; // 地址A2
    reg                     [9:0]   fco_cnt             ; // FCO计数
    reg                     [3:0]   read_rram_finish_cnt; // 读取完成计数

   // 状态与标志
    reg                             sim_row_st          ; // 模拟行同步
    reg                     [9:0]   sim_row_st_cnt      ; // 模拟计数
    reg                     [1:0]   sim_row_st_sample   ; // 模拟同步采样
    reg                             first_addr_tap      ; // 地址打拍标志
    reg                             ram_state           ; // RAM状态切换
    reg                             first_read_tag      ; // 首次读取标志
    reg                             sample_finish_flag  ; // 采样完成标志
    reg                             rama_sample_finish  ; // RAM A 采样完成
    reg                             ramb_sample_finish  ; // RAM B 采样完成
    reg                             rd_ramA             ; // 读RAM A选择
    reg                     [9:0]   cnt_row             ; // 行计数

    (*mark_debug = "true"*) reg     [127:0] kb_data_temp        ; // 系数缓存
    (*mark_debug = "true"*) reg     [7:0]   two_point_sig_a     ; // 校正模式缓存
    reg                             two_point_start     ; // 校正启动标志
    reg                     [9:0]   row_num             ; // 当前行号
    reg                             fifo_ddr_done_a     ; // FIFO完成标志
    reg                     [9:0]   data_delay_cnt      ; // 数据延时计数

    // FIFO与数据总线
    wire                    [63:0]  din_fifo            ; // FIFO输入总线
    wire                    [63:0]  dout_fifo           ; // FIFO输出总线
    wire                    [135:0] sample_last_data    ; // 上一行数据
    wire                    [67:0]  sample_data1        ; // 当前行数据1
    wire                    [67:0]  sample_data2        ; // 当前行数据2
    wire                    [67:0]  sample_data3        ; // 当前行数据3
    wire                    [63:0]  auto_compensate_data; // 自动补偿数据
    reg                     [63:0]  manual_compensate_data; // 手动盲元补偿数据
// assign dout_fifo = din_fifo;
// wire [63:0] dout_fifo;
    // ===================== 赋值与实例化 =====================
    assign din_fifo             = {I_dataA1, I_dataB1, I_dataC1, I_dataD1};
    assign O_two_point_start    = two_point_start;
    assign rram_rclk            = fco_sample[0];
    assign O_sample_data        = manual_compensate_data;

    // ===================== 跨时钟域FIFO =====================
    // 将ADC数据跨时钟域从fco同步到I_clk
    axis_data_fifo_0 U_adc_to_sample (
        .s_axis_aresetn(I_rst),         // input wire s_axis_aresetn
        .s_axis_aclk(fco),              // input wire s_axis_aclk
        .s_axis_tvalid(s_axis_tready),  // input wire s_axis_tvalid
        .s_axis_tready(s_axis_tready),  // output wire s_axis_tready
        .s_axis_tdata(din_fifo),        // input wire [63:0] s_axis_tdata
        .m_axis_aclk(I_clk),            // input wire m_axis_aclk
        .m_axis_tvalid(m_axis_tvalid),  // output wire m_axis_tvalid
        .m_axis_tready(m_axis_tvalid),  // input wire m_axis_tready
        .m_axis_tdata(dout_fifo)        // output wire [63:0] m_axis_tdata
    );
    
    // ===================== 两点校正DSP运算 =====================
    kx_b kx_b_1 (
        .A(dout_fifo[63:48]),           // input wire [15:0] A
        .B(kb_data[119:112]),           // input wire [7:0] B
        .C({kb_data[110:96],7'b0}),     // input wire [21:0] C
        .SUBTRACT(kb_data[111]),        // input wire SUBTRACT
        .P(tempA_a),                    // output wire [22:7] P
        .PCOUT()                        // output wire [47:0] PCOUT
    );
    kx_b kx_b_2 (
        .A(dout_fifo[47:32]),           // input wire [15:0] A
        .B(kb_data[87:80]),             // input wire [7:0] B
        .C({kb_data[78:64],7'b0}),      // input wire [21:0] C
        .SUBTRACT(kb_data[79]),         // input wire SUBTRACT
        .P(tempB_a),                    // output wire [22:7] P
        .PCOUT()                        // output wire [47:0] PCOUT
    );
    kx_b kx_b_3 (
        .A(dout_fifo[31:16]),           // input wire [15:0] A
        .B(kb_data[55:48]),             // input wire [7:0] B
        .C({kb_data[46:32],7'b0}),      // input wire [21:0] C
        .SUBTRACT(kb_data[47]),         // input wire SUBTRACT
        .P(tempC_a),                    // output wire [22:7] P
        .PCOUT()                        // output wire [47:0] PCOUT
    );
    kx_b kx_b_4 (
        .A(dout_fifo[15:0]),            // input wire [15:0] A
        .B(kb_data[23:16]),             // input wire [7:0] B
        .C({kb_data[14:0],7'b0}),       // input wire [21:0] C
        .SUBTRACT(kb_data[15]),         // input wire SUBTRACT
        .P(tempD_a),                    // output wire [22:7] P
        .PCOUT()                        // output wire [47:0] PCOUT
    );

    // 有符号数转换与盲元标识位处理
    assign tempA = kb_data[111] ? (~tempA_a + 1'b1) : tempA_a;
    assign tempB = kb_data[79]  ? (~tempB_a + 1'b1) : tempB_a;
    assign tempC = kb_data[47]  ? (~tempC_a + 1'b1) : tempC_a;
    assign tempD = kb_data[15]  ? (~tempD_a + 1'b1) : tempD_a;

    // ===================== 双端口RAM实例化 =====================
    // 为匹配BRAM的1时钟延迟，增加打拍寄存器
    reg [9:0] last_line_addr_d1;
    reg [15:0] read_row_d1;
    reg [9:0]  addr_rd2_d1;

    always @(posedge I_cl_clk or negedge I_rst) begin
        if(!I_rst) begin
            last_line_addr_d1 <= 10'd0;
            read_row_d1       <= 16'd0;
            addr_rd2_d1       <= 10'd0;
        end else begin
            last_line_addr_d1 <= last_line_addr;
            read_row_d1       <= I_read_row;
            addr_rd2_d1       <= I_addr_rd2;
        end
    end

// assign O_sample_last_data = rd_ramA? doutbb1:doutaa1;    //select which ram to read from
// assign O_sample_data1 = rd_ramA? douta1:doutb1;
// assign O_sample_data2 = rd_ramA? douta2:doutb2;    //select which ram to read from
// assign O_sample_data3 = rd_ramA? douta3:doutb3;    //select which ram to read from

assign sample_last_data = rd_ramA? doutbb1:doutaa1;    //select which ram to read from
assign sample_data1 = rd_ramA? douta1:doutb1;
assign sample_data2 = rd_ramA? douta2:doutb2;    //select which ram to read from
assign sample_data3 = rd_ramA? douta3:doutb3;    //select which ram to read from

// dpram1 U5_1 (
//   .clka(I_clk),       // input wire clka
//   .ena(ena1),         // input wire ena
//   .wea(wea1),         // input wire [0 : 0] wea
//   .addra(addra1),     //  input wire [7 : 0] addra 640/4=160
//   .dina(dina),        // input wire [255 : 0] dina
//   .clkb(~I_cl_clk),   // input wire clkb
//   .enb(enb1),         // input wire enb
//   .addrb(I_addr_rd),  // input wire [9 : 0] addrb    
//   .doutb(douta)       // output wire [31 : 0] doutb 
// );      

// dpram1 U5_2 (
//   .clka(I_clk),        // input wire clka
//   .ena(ena2),          // input wire ena
//   .wea(wea2),          // input wire [0 : 0] wea
//   .addra(addra2),      // input wire [7 : 0] addra 640/4=160
//   .dina(dina),         // input wire [255 : 0] dina
//   .clkb(~I_cl_clk),    // input wire clkb
//   .enb(enb2),          // input wire enb
//   .addrb(I_addr_rd),   // input wire [9 : 0] addrb    
//   .doutb(doutb)        // output wire [31 : 0] doutb 
// );


    // ---- RAM A 组 ----
    // 上一行数据缓存 (128bit)
    last_line_dpram U5_1 (
        .clka(I_cl_clk),                // input wire clka
        .ena(enb1),                     // input wire ena
        .wea(enb1),                     // input wire [0:0] wea
        .addra(last_line_addr_d1),      // input wire [7:0] addra
        .dina({douta2,douta3}),         // input wire [127:0] dina
        .clkb(I_cl_clk),                // input wire clkb
        .enb(enb2),                     // input wire enb
        .addrb(last_line_addr),         // input wire [7:0] addrb
        .doutb(doutaa1)                 // output wire [127:0] doutb
    );
    // 主数据缓存 (64bit) - 通道1
    dpram1 U5_1_1 (
        .clka(I_clk),                   // input wire clka
        .ena(ena1),                     // input wire ena
        .wea(wea1),                     // input wire [0:0] wea
        .addra(addra1),                 // input wire [6:0] addra
        .dina(dina),                    // input wire [127:0] dina
        .clkb(I_cl_clk),                // input wire clkb
        .enb(enb1),                     // input wire enb
        .addrb(I_addr_rd1),             // input wire [7:0] addrb
        .doutb(douta1)                  // output wire [63:0] doutb
    );
    // 主数据缓存 (64bit) - 通道2
    dpram1 U5_1_2 (
        .clka(I_clk),                   // input wire clka
        .ena(ena1),                     // input wire ena
        .wea(wea1),                     // input wire [0:0] wea
        .addra(addra1),                 // input wire [6:0] addra
        .dina(dina),                    // input wire [127:0] dina
        .clkb(I_cl_clk),                // input wire clkb
        .enb(enb1),                     // input wire enb
        .addrb(I_addr_rd2),             // input wire [7:0] addrb
        .doutb(douta2)                  // output wire [63:0] doutb
    );
    // 主数据缓存 (64bit) - 通道3
    dpram1 U5_1_3 (
        .clka(I_clk),                   // input wire clka
        .ena(ena1),                     // input wire ena
        .wea(wea1),                     // input wire [0:0] wea
        .addra(addra1),                 // input wire [6:0] addra
        .dina(dina),                    // input wire [127:0] dina
        .clkb(I_cl_clk),                // input wire clkb
        .enb(enb1),                     // input wire enb
        .addrb(I_addr_rd3),             // input wire [7:0] addrb
        .doutb(douta3)                  // output wire [63:0] doutb
    );

    // ---- RAM B 组 ----
    // 上一行数据缓存 (128bit)
    last_line_dpram U5_2 (
        .clka(I_cl_clk),                // input wire clka
        .ena(enb2),                     // input wire ena
        .wea(enb2),                     // input wire [0:0] wea
        .addra(last_line_addr_d1),      // input wire [7:0] addra
        .dina({doutb2,doutb3}),         // input wire [127:0] dina
        .clkb(I_cl_clk),                // input wire clkb
        .enb(enb1),                     // input wire enb
        .addrb(last_line_addr),         // input wire [7:0] addrb
        .doutb(doutbb1)                 // output wire [127:0] doutb
    );
    // 主数据缓存 (64bit) - 通道1
    dpram1_1 U5_2_1 (
        .clka(I_clk),                   // input wire clka
        .ena(ena2),                     // input wire ena
        .wea(wea2),                     // input wire [0:0] wea
        .addra(addra2),                 // input wire [6:0] addra
        .dina(dina),                    // input wire [127:0] dina
        .clkb(I_cl_clk),                // input wire clkb
        .enb(enb2),                     // input wire enb
        .addrb(I_addr_rd1),             // input wire [7:0] addrb
        .doutb(doutb1)                  // output wire [63:0] doutb
    );
    // 主数据缓存 (64bit) - 通道2
    dpram1_1 U5_2_2 (
        .clka(I_clk),                   // input wire clka
        .ena(ena2),                     // input wire ena
        .wea(wea2),                     // input wire [0:0] wea
        .addra(addra2),                 // input wire [6:0] addra
        .dina(dina),                    // input wire [127:0] dina
        .clkb(I_cl_clk),                // input wire clkb
        .enb(enb2),                     // input wire enb
        .addrb(I_addr_rd2),             // input wire [7:0] addrb
        .doutb(doutb2)                  // output wire [63:0] doutb
    );
    // 主数据缓存 (64bit) - 通道3
    dpram1_1 U5_2_3 (
        .clka(I_clk),                   // input wire clka
        .ena(ena2),                     // input wire ena
        .wea(wea2),                     // input wire [0:0] wea
        .addra(addra2),                 // input wire [6:0] addra
        .dina(dina),                    // input wire [127:0] dina
        .clkb(I_cl_clk),                // input wire clkb
        .enb(enb2),                     // input wire enb
        .addrb(I_addr_rd3),             // input wire [7:0] addrb
        .doutb(doutb3)                  // output wire [63:0] doutb
    );

    // ===================== 读取数据分配 =====================
    assign sample_last_data = rd_ramA ? doutbb1 : doutaa1;  // 选择读取的RAM
    assign sample_data1     = rd_ramA ? douta1  : doutb1;
    assign sample_data2     = rd_ramA ? douta2  : doutb2;
    assign sample_data3     = rd_ramA ? douta3  : doutb3;

    // ===================== 同步与行状态机 =====================
    always @(posedge I_clk or negedge I_rst) begin
        if(!I_rst) begin
            rd_finish_sample    <= 0;
            fco_sample          <= 0;
            row_st_sample       <= 0;
            sim_row_st_sample   <= 0;
            rama_en             <= 0;
            ramb_en             <= 0;
            ram_state           <= 0;
            cnt_row             <= 0;
            fifo_ddr_done_a     <= 0;
            two_point_sig_a     <= 8'h00;
        end else begin
            rd_finish_sample[0] <= I_data_rd_finish;       // 同步读完成信号
            rd_finish_sample[1] <= rd_finish_sample[0];    // 打拍同步
            fco_sample[0]       <= fco;                    // 同步FCO时钟
            fco_sample[1]       <= fco_sample[0];          // 打拍同步
            fco_sample[2]       <= fco_sample[1];          
            fco_sample[3]       <= fco_sample[2];          
            fco_sample[4]       <= fco_sample[3];          
            fco_sample[5]       <= fco_sample[4];          
            row_st_sample[0]    <= I_line_vaild;           // 同步行有效信号
            row_st_sample[1]    <= row_st_sample[0];       // 打拍同步
            two_point_sig_a     <= two_point_sig;          // 同步两点校正模式选择
            fifo_ddr_done_a     <= fifo_ddr_done;          // 同步DDR存储完成标志

            // 检测行有效信号上升沿，开始处理新的一行数据
            if(row_st_sample[1:0] == 2'b01) begin
                cnt_row <= cnt_row + 1'b1;                 // 行计数加1
                if(cnt_row > 0) begin
                    if(ram_state == 0) begin
                        rama_en     <= 1;                  // 使能RAM A写入
                        ram_state   <= ram_state + 1;      // 切换RAM状态
                    end else begin
                        ramb_en     <= 1;                  // 使能RAM B写入
                        ram_state   <= 0;                  // 切换RAM状态
                    end
                    if(cnt_row == 10'd512) begin
                        cnt_row <= 0;                      // 行计数满512时归零
                    end
                end
            end
            if(rama_en) rama_en <= 0;                      // RAM A使能信号单周期脉冲
            if(ramb_en) ramb_en <= 0;                      // RAM B使能信号单周期脉冲
        end
    end

// ===================== RAM A 采样状态机 =====================
    always@(posedge I_clk or negedge I_rst) begin
        if(!I_rst) begin
            rama_sample_fsm     <= 0; // 复位清零
            ena1                <= 0;
            enb1                <= 0;
            wea1                <= 0;
            addra1              <= 0;
            dina                <= 0;
            ramb_sample_fsm     <= 0;
            ena2                <= 0;
            enb2                <= 0;
            wea2                <= 0;
            addra2              <= 0;
            first_addr_tap      <= 0;
            sample_finish_flag  <= 0;
            rama_sample_finish  <= 0;
            ramb_sample_finish  <= 0;
            rd_ramA             <= 0;
            row_num             <= 0;
            data_delay_cnt      <= 0;
            O_sample_finish     <= 0;
            O_read_ram_addr1    <= 0;
            O_read_ram_addr2    <= 0;
            read_rram_finish1   <= 0;
            read_rram_finish2   <= 0;
            read_rram_finish_cnt<= 0;
            two_point_start     <= 0;
        end else begin
        // ---------- RAM A 状态机 ----------
            case (rama_sample_fsm)
                0: begin
                    if(rama_en) begin                      // 等待RAM A使能信号
                        rama_sample_fsm <= 1;             // 进入状态1
                        first_addr_tap  <= 0;             // 清零地址打拍标志
                        data_delay_cnt  <= 0;             // 清零延时计数
                    end
                end
                1: begin
                    if(fco_sample[1:0] == 2'b01) begin    // 检测FCO上升沿
                        if(data_delay_cnt == 10'd10) begin // 达到预定延迟（25M时钟下约10周期）
                            data_delay_cnt <= 0;          // 清零延时计数
                            if(two_point_start) begin
                                rama_sample_fsm <= 3;     // 已开启校正，进入校正写入状态
                            end else begin
                                rama_sample_fsm <= 2;     // 未开启校正，进入直接存储状态
                            end
                        end else begin
                            data_delay_cnt <= data_delay_cnt + 1; // 继续等待
                        end
                    end
                end
                2: begin // 直接存储（无校正）
                    if(addra1 == 10'd159) begin           // 写满一行（160个地址）
                        wea1                <= 0;        // 关闭写使能
                        ena1                <= 0;        // 关闭RAM使能
                        rama_sample_fsm     <= 5;        // 进入状态5（等待读取完成）
                        addra1              <= 0;        // 地址归零
                        sample_finish_flag  <= 0;        // 清零采样完成标志
                        rama_sample_finish  <= 1;        // 标记RAM A采样完成
                        enb1                <= 1;        // 开启读使能
                        rd_ramA             <= 1;        // 切换到读RAM A
                        row_num             <= row_num + 1; // 行号加1
                        read_rram_finish_cnt<= 0;        // 清零读完成计数
                        O_sample_finish     <= 1;        // 输出采样完成信号
                    end else begin
                        ena1 <= 1;                       // 开启RAM使能
                        wea1 <= 1;                       // 开启写使能
                        if(fco_sample[1:0] == 2'b01) begin // 在FCO上升沿写入数据
                            rama_sample_fsm <= 4;       // 进入状态4（延时等待）
                            if(first_addr_tap == 0) begin
                                dina            <= {1'b0,dout_fifo[63:48],1'b0,dout_fifo[47:32],1'b0,dout_fifo[31:16],1'b0,dout_fifo[15:0]};
                                first_addr_tap  <= 1;   // 标记首地址已写入
                            end else begin
                                dina            <= {1'b0,dout_fifo[63:48],1'b0,dout_fifo[47:32],1'b0,dout_fifo[31:16],1'b0,dout_fifo[15:0]};
                                addra1          <= addra1 + 1; // 地址递增
                            end
                        end
                    end
                end
                3: begin // 两点校正后存储
                    if(addra1 == 10'd159) begin          // 写满一行
                        wea1                <= 0;       // 关闭写使能
                        ena1                <= 0;       // 关闭RAM使能
                        rama_sample_fsm     <= 5;       // 进入状态5
                        addra1              <= 0;       // 地址归零
                        sample_finish_flag  <= 0;       // 清零标志
                        rama_sample_finish  <= 1;       // 标记RAM A采样完成
                        enb1                <= 1;       // 开启读使能
                        rd_ramA             <= 1;       // 切换到读RAM A
                        row_num             <= row_num + 1; // 行号加1
                        O_read_ram_addr1    <= 0;       // 清零读取地址1
                        read_rram_finish1   <= 1;       // 标记RAM1读取结束
                        read_rram_finish_cnt<= 0;       // 清零读完成计数
                        O_sample_finish     <= 1;       // 输出采样完成信号
                    end else begin
                        ena1 <= 1;                      // 开启RAM使能
                        wea1 <= 1;                      // 开启写使能
                        if(fco_sample[1:0] == 2'b01) begin
                            rama_sample_fsm <= 4;      // 进入状态4
                            if(O_read_ram_addr1 == 10'd159) begin
                                O_read_ram_addr1 <= O_read_ram_addr1; // 地址保持
                            end else begin
                                O_read_ram_addr1 <= O_read_ram_addr1 + 1; // 地址递增
                            end
                            if(first_addr_tap == 0) begin
                                dina            <= {kb_data[127],tempA,kb_data[95],tempB,kb_data[63],tempC,kb_data[31],tempD};
                                first_addr_tap  <= 1;  // 标记首地址已写入
                            end else begin
                                dina            <= {kb_data[127],tempA,kb_data[95],tempB,kb_data[63],tempC,kb_data[31],tempD};
                                addra1          <= addra1 + 1; // 地址递增
                            end
                        end
                    end
                end
                4: begin
                    if(data_delay_cnt == 10'd3) begin    // 等待3周期延迟，匹配数据对齐
                        data_delay_cnt <= 0;            // 清零延时计数
                        if(two_point_start) begin
                            rama_sample_fsm <= 3;       // 回到校正写入状态
                        end else begin
                            rama_sample_fsm <= 2;       // 回到直接存储状态
                        end
                    end else begin
                        if(fco_sample[1:0] == 2'b01) begin
                            data_delay_cnt <= data_delay_cnt + 1'b1; // 继续计数
                        end
                    end
                end
                5: begin
                    if(sample_finish_flag == 1) begin
                        rama_sample_finish <= 0;        // 采样完成标志保持1后清零
                    end else begin
                        sample_finish_flag <= 1;        // 设置采样完成标志
                    end
                    // 读完成标志延时处理
                    if(read_rram_finish1) begin
                        if(read_rram_finish_cnt == 4'd2) begin
                            read_rram_finish1 <= 0;     // 延时2周期后清除读完成标志
                        end else begin
                            read_rram_finish_cnt <= read_rram_finish_cnt + 1;
                        end
                    end
                    if(rd_finish_sample == 2'b01) begin // 检测到读取完成信号上升沿
                        rama_sample_fsm <= 0;           // 回到空闲状态
                        rd_ramA         <= 0;           // 清除读RAM选择
                        enb1            <= 0;           // 关闭读使能
                        O_sample_finish <= 0;           // 清除采样完成信号
                    end
                end
                default: rama_sample_fsm <= 0;          // 默认回到空闲状态
            endcase

        // ---------- RAM B 状态机 ----------
            case (ramb_sample_fsm)
                0: begin
                    if(ramb_en) begin                    // 等待RAM B使能信号
                        ramb_sample_fsm <= 1;            // 进入状态1
                        first_addr_tap  <= 0;            // 清零地址打拍标志
                        data_delay_cnt  <= 0;            // 清零延时计数
                    end
                end
                1: begin
                    if(fco_sample[1:0] == 2'b01) begin   // 检测FCO上升沿
                        if(data_delay_cnt == 10'd10) begin
                            data_delay_cnt <= 0;         // 清零延时计数
                            if(two_point_start) begin
                                ramb_sample_fsm <= 3;    // 已开启校正，进入校正写入状态
                            end else begin
                                ramb_sample_fsm <= 2;    // 未开启校正，进入直接存储状态
                            end
                        end else begin
                            data_delay_cnt <= data_delay_cnt + 1; // 继续等待
                        end
                    end
                end
                2: begin // 直接存储
                    if(addra2 == 10'd159) begin          // 写满一行
                        wea2                <= 0;       // 关闭写使能
                        ena2                <= 0;       // 关闭RAM使能
                        ramb_sample_fsm     <= 5;       // 进入状态5
                        addra2              <= 0;       // 地址归零
                        sample_finish_flag  <= 0;       // 清零标志
                        ramb_sample_finish  <= 1;       // 标记RAM B采样完成
                        enb2                <= 1;       // 开启读使能
                        row_num             <= row_num + 1; // 行号加1
                        read_rram_finish_cnt<= 0;       // 清零读完成计数
                        O_sample_finish     <= 1;       // 输出采样完成信号
                    end else begin
                        ena2 <= 1;                      // 开启RAM使能
                        wea2 <= 1;                      // 开启写使能
                        if(fco_sample[1:0] == 2'b01) begin
                            ramb_sample_fsm <= 4;      // 进入状态4
                            if(first_addr_tap == 0) begin
                                dina            <= {1'b0,dout_fifo[63:48],1'b0,dout_fifo[47:32],1'b0,dout_fifo[31:16],1'b0,dout_fifo[15:0]};
                                first_addr_tap  <= 1;  // 标记首地址已写入
                            end else begin
                                dina            <= {1'b0,dout_fifo[63:48],1'b0,dout_fifo[47:32],1'b0,dout_fifo[31:16],1'b0,dout_fifo[15:0]};
                                addra2          <= addra2 + 1; // 地址递增
                            end
                        end
                    end
                end
                3: begin // 两点校正后存储
                    if(addra2 == 10'd159) begin          // 写满一行
                        wea2                <= 0;       // 关闭写使能
                        ena2                <= 0;       // 关闭RAM使能
                        ramb_sample_fsm     <= 5;       // 进入状态5
                        ramb_sample_finish  <= 1;       // 标记RAM B采样完成
                        sample_finish_flag  <= 0;       // 清零标志
                        addra2              <= 0;       // 地址归零
                        enb2                <= 1;       // 开启读使能
                        row_num             <= row_num + 1; // 行号加1
                        O_read_ram_addr2    <= 0;       // 清零读取地址2
                        read_rram_finish2   <= 1;       // 标记RAM2读取结束
                        read_rram_finish_cnt<= 0;       // 清零读完成计数
                        O_sample_finish     <= 1;       // 输出采样完成信号
                    end else begin
                        ena2 <= 1;                      // 开启RAM使能
                        wea2 <= 1;                      // 开启写使能
                        if(fco_sample[1:0] == 2'b01) begin
                            ramb_sample_fsm <= 4;      // 进入状态4
                            if(O_read_ram_addr2 == 10'd159) begin
                                O_read_ram_addr2 <= O_read_ram_addr2; // 地址保持
                            end else begin
                                O_read_ram_addr2 <= O_read_ram_addr2 + 1; // 地址递增
                            end
                            if(first_addr_tap == 0) begin
                                dina            <= {kb_data[127],tempA,kb_data[95],tempB,kb_data[63],tempC,kb_data[31],tempD};
                                first_addr_tap  <= 1;  // 标记首地址已写入
                            end else begin
                                dina            <= {kb_data[127],tempA,kb_data[95],tempB,kb_data[63],tempC,kb_data[31],tempD};
                                addra2          <= addra2 + 1; // 地址递增
                            end
                        end
                    end
                end
                4: begin
                    if(data_delay_cnt == 10'd3) begin    // 等待3周期延迟
                        data_delay_cnt <= 0;            // 清零延时计数
                        if(two_point_start) begin
                            ramb_sample_fsm <= 3;       // 回到校正写入状态
                        end else begin
                            ramb_sample_fsm <= 2;       // 回到直接存储状态
                        end
                    end else begin
                        if(fco_sample[1:0] == 2'b01) begin
                            data_delay_cnt <= data_delay_cnt + 1'b1; // 继续计数
                        end
                    end
                end
                5: begin
                    if(sample_finish_flag == 1) begin
                        ramb_sample_finish <= 0;        // 采样完成标志保持1后清零
                    end else begin
                        sample_finish_flag <= 1;        // 设置采样完成标志
                    end
                    // 读完成标志延时处理
                    if(read_rram_finish2) begin
                        if(read_rram_finish_cnt == 4'd2) begin
                            read_rram_finish2 <= 0;     // 延时2周期后清除读完成标志
                        end else begin
                            read_rram_finish_cnt <= read_rram_finish_cnt + 1;
                        end
                    end
                    // 当行计数达到512时，判断是否开启两点校正
                    if(row_num == 10'd512) begin
                        row_num <= 0;                   // 行号归零
                        if((fifo_ddr_done_a) && ((two_point_sig_a == 8'hEE)||(two_point_sig_a == 8'hFF))) begin
                            two_point_start <= 1;       // 满足条件，启动两点校正
                        end else begin
                            two_point_start <= 0;       // 不满足条件，关闭两点校正
                        end
                    end
                    if(rd_finish_sample == 2'b01) begin // 检测到读取完成信号上升沿
                        enb2            <= 0;           // 关闭读使能
                        ramb_sample_fsm <= 0;           // 回到空闲状态
                        O_sample_finish <= 0;           // 清除采样完成信号
                    end
                end
                default: ramb_sample_fsm <= 0;          // 默认回到空闲状态
            endcase
        end
    end

// assign send_data = {(kb_data[127] ? ((sample_data1[15:0]>>2) + (sample_data2[47:32]>>2) + (sample_last_data[127:112]>>2) + (sample_last_data[111:96]>>2)) : sample_data2[63:48]),
// 					(kb_data[95] ? ((sample_data2[62:48]>>2) + (sample_data2[30:16]>>2) + (sample_last_data[110:96]>>2) + (sample_last_data[94:80]>>2))  : sample_data2[47:32]),
// 					(kb_data[63] ? ((sample_data2[46:32]>>2) + (sample_data2[14:0]>>2) + (sample_last_data[94:80]>>2) + (sample_last_data[78:64]>>2)) : sample_data2[31:16]),
// 					(kb_data[31] ? ((sample_data2[30:16]>>2) + (sample_data3[62:48]>>2) + (sample_last_data[78:64]>>2) + (sample_last_data[62:48]>>2)) : sample_data2[15:0])};

// assign send_data = {(sample_data2[67] ? ((sample_data1[15:0]>>2) + (sample_data2[49:34]>>2) + (sample_last_data[134:119]>>2) + (sample_last_data[117:102]>>2)) : sample_data2[66:51]),
					// (sample_data2[50] ? ((sample_data2[66:51]>>2) + (sample_data2[32:17]>>2) + (sample_last_data[117:102]>>2) + (sample_last_data[100:85]>>2))  : sample_data2[49:34]),
					// (sample_data2[33] ? ((sample_data2[49:34]>>2) + (sample_data2[15:0]>>2) + (sample_last_data[100:85]>>2) + (sample_last_data[83:68]>>2)) : sample_data2[32:17]),
					// (sample_data2[16] ? ((sample_data2[32:17]>>2) + (sample_data3[66:51]>>2) + (sample_last_data[83:68]>>2) + (sample_last_data[66:51]>>2)) : sample_data2[15:0])};

    // ===================== 自动盲元补偿与手动坐标覆盖 =====================
    // 1. 自动盲元补偿（基于标志位）
assign auto_compensate_data = {
    (sample_data2[67] ? ((sample_data1[15:0]>>2) + (sample_data2[49:34]>>2) + (sample_last_data[134:119]>>2) + (sample_last_data[117:102]>>2)) : sample_data2[66:51]),
    (sample_data2[50] ? ((sample_data2[66:51]>>2) + (sample_data2[32:17]>>2) + (sample_last_data[117:102]>>2) + (sample_last_data[100:85]>>2))  : sample_data2[49:34]),
    (sample_data2[33] ? ((sample_data2[49:34]>>2) + (sample_data2[15:0]>>2) + (sample_last_data[100:85]>>2) + (sample_last_data[83:68]>>2)) : sample_data2[32:17]),
    (sample_data2[16] ? ((sample_data2[32:17]>>2) + (sample_data3[66:51]>>2) + (sample_last_data[83:68]>>2) + (sample_last_data[66:51]>>2)) : sample_data2[15:0])
};

    // 2. 手动盲元补偿（基于坐标表，覆盖自动补偿结果）
always @(*) begin
    manual_compensate_data = auto_compensate_data; // 默认输出自动补偿结果

    // // 仅在非均匀校正开启时，才执行手动盲元补偿逻辑
    if (two_point_start) begin
    // 以打拍对齐后的行号作为case 的判断条件
        case (read_row_d1)  // 根据当前读取行号进行坐标匹配
            16'd11: begin
                if (addr_rd2_d1 == 10'd126) begin
                    // 使用左边加头顶相邻像素求均值
                    manual_compensate_data[15:0] = (auto_compensate_data[31:16] >> 1) + (sample_last_data[83:68] >> 1);
                end
                if (addr_rd2_d1 == 10'd127) begin
                    // 使用右边加头顶相邻像素求均值
                    manual_compensate_data[63:48] = (sample_last_data[134:119] >> 1) + (auto_compensate_data[47:32] >> 1);
                end
                // 如果同一行还有其他盲元，可以继续else if
                // else if (addr_rd2_d1 == 10'dXX) begin ... end
            end

            16'd12: begin //(508,12) (509,12)
                if (addr_rd2_d1 == 10'd126) begin
                    manual_compensate_data[15:0] = (auto_compensate_data[31:16] >> 1) + (sample_last_data[100:85] >> 1);
                end
                if (addr_rd2_d1 == 10'd127) begin
                    manual_compensate_data[63:48] = (sample_last_data[117:102] >> 1) + (auto_compensate_data[47:32] >> 1);
                    manual_compensate_data[15:0] = (sample_data3[66:51] >> 1) + (sample_last_data[83:68] >> 1);
                end
            end

            16'd25: begin //(287,25)
                if (addr_rd2_d1 == 10'd71) begin
                    manual_compensate_data[31:16] = (auto_compensate_data[47:32] >> 1) + (sample_last_data[100:85] >> 1);
                    manual_compensate_data[15:0] = (sample_last_data[83:68] >> 1) + (sample_data3[66:51] >> 1);
                end
            end

            16'd29: begin //(95,29) (131,29)
                if (addr_rd2_d1 == 10'd23) begin
                    manual_compensate_data[31:16] = (auto_compensate_data[47:32] >> 1) + (sample_last_data[100:85] >> 1);
                    manual_compensate_data[15:0] = (sample_last_data[83:68] >> 1) + (sample_data3[66:51] >> 1);
                end
                if (addr_rd2_d1 == 10'd32) begin
                    manual_compensate_data[31:16] = (auto_compensate_data[47:32] >> 1) + (auto_compensate_data[15:0] >> 1);
                end
            end

            16'd46: begin //(20,46)
                if (addr_rd2_d1 == 10'd4) begin
                    manual_compensate_data[15:0] = (auto_compensate_data[31:16] >> 1) + (sample_data3[66:51] >> 1);
                end
            end

            16'd54: begin //(306,54)
                if (addr_rd2_d1 == 10'd76) begin
                    manual_compensate_data[47:32] = (auto_compensate_data[63:48] >> 1) + (auto_compensate_data[31:16] >> 1);
                end
            end

            16'd61: begin //(120,61)
                if (addr_rd2_d1 == 10'd29) begin
                    manual_compensate_data[15:0] = (auto_compensate_data[31:16] >> 1) + (sample_data3[66:51] >> 1);
                end
            end

            16'd68: begin //(569,68)
                if (addr_rd2_d1 == 10'd142) begin
                    manual_compensate_data[63:48] = (sample_last_data[134:119] >> 1) + (auto_compensate_data[47:32] >> 1);
                end
            end

            16'd72: begin //(89,72)
                if (addr_rd2_d1 == 10'd22) begin
                    manual_compensate_data[63:48] = (sample_last_data[134:119] >> 1) + (sample_data1[15:0] >> 1);
                    manual_compensate_data[47:32] = (sample_last_data[117:102] >> 1) + (auto_compensate_data[31:16] >> 1);
                end
            end

            16'd76: begin //(541,76)
                if (addr_rd2_d1 == 10'd135) begin
                    manual_compensate_data[63:48] = (sample_last_data[134:119] >> 1) + (sample_data1[15:0] >> 1);
                    manual_compensate_data[47:32] = (sample_last_data[117:102] >> 1) + (auto_compensate_data[31:16] >> 1);
                end
            end

            16'd93: begin //(246,93)
                if (addr_rd2_d1 == 10'd61) begin
                    manual_compensate_data[47:32] = (sample_last_data[117:102] >> 1) + (auto_compensate_data[63:48] >> 1);
                    manual_compensate_data[31:16] = (sample_last_data[100:85] >> 1) + (auto_compensate_data[15:0] >> 1);
                end
            end

            16'd107: begin //(491,107)
                if (addr_rd2_d1 == 10'd122) begin
                    manual_compensate_data[31:16] = (auto_compensate_data[47:32] >> 1) + (auto_compensate_data[15:0] >> 1);
                end
            end

            16'd109: begin //(86,109)
                if (addr_rd2_d1 == 10'd21) begin
                    manual_compensate_data[47:32] = (sample_last_data[117:102] >> 1) + (auto_compensate_data[63:48] >> 1);
                    manual_compensate_data[31:16] = (sample_last_data[100:85] >> 1) + (auto_compensate_data[15:0] >> 1);
                end
            end

            16'd118: begin //(235,118)
                if (addr_rd2_d1 == 10'd58) begin
                    manual_compensate_data[31:16] = (sample_last_data[100:85] >> 1) + (auto_compensate_data[47:32] >> 1);
                    manual_compensate_data[15:0] = (sample_last_data[83:68] >> 1) + (sample_data3[66:51] >> 1);
                end
            end

            16'd123: begin //(13,123)
                if (addr_rd2_d1 == 10'd3) begin
                    manual_compensate_data[63:48] = (sample_last_data[134:119] >> 1) + (auto_compensate_data[47:32] >> 1);
                end
            end

            16'd124: begin //(12,124)
                if (addr_rd2_d1 == 10'd2) begin
                    manual_compensate_data[15:0] = (auto_compensate_data[31:16] >> 1) + (sample_data3[66:51] >> 1);
                end
            end

            16'd127: begin //(146,127)
                if (addr_rd2_d1 == 10'd36) begin
                    manual_compensate_data[47:32] = (auto_compensate_data[63:48] >> 1) + (auto_compensate_data[31:16] >> 1);
                end
            end

            16'd128: begin //(146,128)
                if (addr_rd2_d1 == 10'd36) begin
                    manual_compensate_data[47:32] = (auto_compensate_data[63:48] >> 1) + (auto_compensate_data[31:16] >> 1);
                end
            end

            16'd129: begin //(145,129)
                if (addr_rd2_d1 == 10'd36) begin
                    manual_compensate_data[63:48] = sample_data1[15:0];
                    manual_compensate_data[47:32] = auto_compensate_data[31:16];
                end
            end

            16'd130: begin //(145,130)
                if (addr_rd2_d1 == 10'd36) begin
                    manual_compensate_data[63:48] = (sample_data1[15:0] >> 1) + (auto_compensate_data[47:32] >> 1);
                end
                if (addr_rd2_d1 == 10'd103) begin
                    manual_compensate_data[31:16] = (sample_last_data[100:85] >> 1) + (auto_compensate_data[47:32] >> 1);
                    manual_compensate_data[15:0] = (sample_last_data[83:68] >> 1) + (sample_data3[66:51] >> 1);
                end
            end

            16'd131: begin //(414,131)
                if (addr_rd2_d1 == 10'd103) begin
                    manual_compensate_data[47:32] = (sample_last_data[117:102] >> 1) + (auto_compensate_data[63:48] >> 1);
                    manual_compensate_data[15:0] = sample_data3[66:51];
                end
            end

            16'd140: begin //(110,140)
                if (addr_rd2_d1 == 10'd27) begin
                    manual_compensate_data[47:32] = (sample_last_data[117:102] >> 1) + (auto_compensate_data[63:48] >> 1);
                    manual_compensate_data[31:16] = (sample_last_data[100:85] >> 1) + (auto_compensate_data[15:0] >> 1);
                end
            end

            16'd141: begin //(111,141)
                if (addr_rd2_d1 == 10'd27) begin
                    manual_compensate_data[31:16] = auto_compensate_data[47:32];
                    manual_compensate_data[15:0] = (sample_last_data[83:68] >> 1) + (sample_data3[66:51] >> 1);
                end
            end

            16'd143: begin //(204,143)
                if (addr_rd2_d1 == 10'd50) begin
                    manual_compensate_data[15:0] = (auto_compensate_data[31:16] >> 1) + (sample_last_data[83:68] >> 1);
                end
                if (addr_rd2_d1 == 10'd51) begin
                    manual_compensate_data[63:48] = (sample_last_data[134:119] >> 1) + (auto_compensate_data[47:32] >> 1);
                end
            end

            16'd149: begin //(96,149)
                if (addr_rd2_d1 == 10'd23) begin
                    manual_compensate_data[15:0] = (auto_compensate_data[31:16] >> 1) + (sample_data3[66:51] >> 1);
                end
            end

            16'd154: begin //(100,154)
                if (addr_rd2_d1 == 10'd24) begin
                    manual_compensate_data[15:0] = (auto_compensate_data[31:16] >> 1) + (sample_data3[66:51] >> 1);
                end
            end

            16'd189: begin //(165,189)
                if (addr_rd2_d1 == 10'd41) begin
                    manual_compensate_data[63:48] = (sample_last_data[134:119] >> 1) + (sample_data1[15:0] >> 1);
                    manual_compensate_data[47:32] = (sample_last_data[117:102] >> 1) + (auto_compensate_data[31:16] >> 1);
                end
            end

            16'd192: begin //(396,192)
                if (addr_rd2_d1 == 10'd98) begin
                    manual_compensate_data[15:0] = (auto_compensate_data[31:16] >> 1) + (sample_last_data[83:68] >> 1);
                end
                if (addr_rd2_d1 == 10'd99) begin
                    manual_compensate_data[63:48] = (auto_compensate_data[47:32] >> 1) + (sample_last_data[117:102] >> 1);
                end
            end

            16'd193: begin //(396,193)
                if (addr_rd2_d1 == 10'd98) begin
                    manual_compensate_data[15:0] = (auto_compensate_data[31:16] >> 1) + (sample_last_data[100:85] >> 1);
                end
                if (addr_rd2_d1 == 10'd99) begin
                    manual_compensate_data[63:48] = (auto_compensate_data[47:32] >> 1) + (sample_last_data[117:102] >> 1);
                end
            end

            16'd194: begin //(396,194)
                if (addr_rd2_d1 == 10'd98) begin
                    manual_compensate_data[15:0] = (auto_compensate_data[31:16] >> 1) + (sample_data3[66:51] >> 1);
                end
            end

            16'd195: begin //(396,195)
                if (addr_rd2_d1 == 10'd98) begin
                    manual_compensate_data[15:0] = (auto_compensate_data[31:16] >> 1) + (sample_last_data[100:85] >> 1);
                end
                if (addr_rd2_d1 == 10'd99) begin
                    manual_compensate_data[63:48] = (auto_compensate_data[47:32] >> 1) + (sample_last_data[117:102] >> 1);
                end
            end

            16'd196: begin //(396,196)
                if (addr_rd2_d1 == 10'd98) begin
                    manual_compensate_data[15:0] = (auto_compensate_data[31:16] >> 1) + (sample_data3[66:51] >> 1);
                end
            end

            16'd197: begin //(395,197)
                if (addr_rd2_d1 == 10'd98) begin
                    manual_compensate_data[31:16] = (auto_compensate_data[47:32] >> 1) + (sample_last_data[100:85] >> 1);
                    manual_compensate_data[15:0] = (sample_last_data[66:51] >> 1) + (sample_data3[66:51] >> 1);
                end
            end

            16'd198: begin //(396,198)
                if (addr_rd2_d1 == 10'd98) begin
                    manual_compensate_data[15:0] = (auto_compensate_data[31:16] >> 1) + (sample_data3[66:51] >> 1);
                end
            end

            16'd209: begin //(151,209)
                if (addr_rd2_d1 == 10'd37) begin
                    manual_compensate_data[31:16] = (auto_compensate_data[47:32] >> 1) + (auto_compensate_data[15:0] >> 1);
                end
            end

            16'd210: begin //(151,210)
                if (addr_rd2_d1 == 10'd37) begin
                    manual_compensate_data[31:16] = (auto_compensate_data[47:32] >> 1) + (auto_compensate_data[15:0] >> 1);
                end
            end

            16'd211: begin //(151,211)
                if (addr_rd2_d1 == 10'd37) begin
                    manual_compensate_data[31:16] = (auto_compensate_data[47:32] >> 1) + (auto_compensate_data[15:0] >> 1);
                end
            end

            16'd213: begin //(150,213)
                if (addr_rd2_d1 == 10'd37) begin
                    manual_compensate_data[47:32] = (auto_compensate_data[63:48] >> 1) + (auto_compensate_data[31:16] >> 1);
                end
            end

            16'd214: begin //(1,214) (150,214)
                if (addr_rd2_d1 == 10'd0) begin
                    manual_compensate_data[63:48] = (sample_last_data[134:119] >> 1) + (auto_compensate_data[47:32] >> 1);
                end
                if (addr_rd2_d1 == 10'd1) begin
                    manual_compensate_data[47:32] = auto_compensate_data[63:48];
                    manual_compensate_data[31:16] = (sample_last_data[100:85] >> 1) + (auto_compensate_data[15:0] >> 1);
                end
                if (addr_rd2_d1 == 10'd37) begin
                    manual_compensate_data[47:32] = (auto_compensate_data[63:48] >> 1) + (sample_last_data[134:119] >> 1);
                    manual_compensate_data[31:16] = (sample_last_data[100:85] >> 1) + (auto_compensate_data[15:0] >> 1);
                end
            end

            16'd215: begin //(7,215)
                if (addr_rd2_d1 == 10'd1) begin
                    manual_compensate_data[31:16] = (auto_compensate_data[47:32] >> 1) + (auto_compensate_data[15:0] >> 1);
                end
                if (addr_rd2_d1 == 10'd37) begin
                    manual_compensate_data[47:32] = (auto_compensate_data[63:48] >> 1) + (auto_compensate_data[31:16] >> 1);
                end
                if (addr_rd2_d1 == 10'd134) begin
                    manual_compensate_data[63:48] = (sample_last_data[134:119] >> 1) + (sample_data1[15:0] >> 1);
                end
            end

            16'd216: begin //(6,216)
                if (addr_rd2_d1 == 10'd1) begin
                    manual_compensate_data[47:32] = (auto_compensate_data[63:48] >> 1) + (auto_compensate_data[31:16] >> 1);
                end
                if (addr_rd2_d1 == 10'd37) begin
                    manual_compensate_data[63:48] = (sample_last_data[134:119] >> 1) + (sample_data1[15:0] >> 1);
                    manual_compensate_data[47:32] = (sample_last_data[100:85] >> 1) + (auto_compensate_data[31:16] >> 1);
                end
            end

            16'd217: begin //(3,217)
                if (addr_rd2_d1 == 10'd0) begin
                    manual_compensate_data[31:16] = sample_last_data[100:85];
                    manual_compensate_data[15:0] = sample_last_data[83:68];
                end
                if (addr_rd2_d1 == 10'd1) begin
                    manual_compensate_data[63:48] = sample_last_data[134:119];
                    manual_compensate_data[47:32] = auto_compensate_data[31:16];
                end
            end

            16'd218: begin //(378,218)
                if (addr_rd2_d1 == 10'd94) begin
                    manual_compensate_data[47:32] = (auto_compensate_data[63:48] >> 1) + (auto_compensate_data[31:16] >> 1);
                end
            end

            16'd219: begin //(202,219)
                if (addr_rd2_d1 == 10'd50) begin
                    manual_compensate_data[47:32] = (auto_compensate_data[63:48] >> 1) + (auto_compensate_data[31:16] >> 1);
                end
            end

            16'd228: begin //(384,228)
                if (addr_rd2_d1 == 10'd95) begin
                    manual_compensate_data[15:0] = (auto_compensate_data[31:16] >> 1) + (sample_data3[66:51] >> 1);
                end
            end

            16'd236: begin //(228,236)
                if (addr_rd2_d1 == 10'd56) begin
                    manual_compensate_data[15:0] = (auto_compensate_data[31:16] >> 1) + (sample_data3[66:51] >> 1);
                end
            end

            16'd239: begin //(227,239)
                if (addr_rd2_d1 == 10'd56) begin
                    manual_compensate_data[31:16] = (auto_compensate_data[47:32] >> 1) + (auto_compensate_data[15:0] >> 1);
                end
            end

            16'd240: begin //(227,240)
                if (addr_rd2_d1 == 10'd42) begin
                    manual_compensate_data[15:0] = (auto_compensate_data[31:16] >> 1) + (sample_data3[66:51] >> 1);
                end
                if (addr_rd2_d1 == 10'd56) begin
                    manual_compensate_data[31:16] = (auto_compensate_data[47:32] >> 1) + (auto_compensate_data[15:0] >> 1);
                end
            end

            16'd241: begin //(227,241)
                if (addr_rd2_d1 == 10'd56) begin
                    manual_compensate_data[31:16] = (auto_compensate_data[47:32] >> 1) + (auto_compensate_data[15:0] >> 1);
                end
            end

            16'd253: begin //(575,253)
                if (addr_rd2_d1 == 10'd143) begin
                    manual_compensate_data[31:16] = (auto_compensate_data[47:32] >> 1) + (sample_last_data[100:85] >> 1);
                    manual_compensate_data[15:0] = (sample_last_data[83:68] >> 1) + (sample_data3[66:51] >> 1);
                end
            end

            16'd280: begin //(527,280)
                if (addr_rd2_d1 == 10'd131) begin
                    manual_compensate_data[31:16] = (auto_compensate_data[47:32] >> 1) + (auto_compensate_data[15:0] >> 1);
                end
            end

            16'd285: begin //(247,285)
                if (addr_rd2_d1 == 10'd61) begin
                    manual_compensate_data[31:16] = (auto_compensate_data[47:32] >> 1) + (sample_last_data[100:85] >> 1);
                    manual_compensate_data[15:0] = (sample_last_data[83:68] >> 1) + (sample_data3[66:51] >> 1);
                end
            end

            16'd286: begin //(101,286)
                if (addr_rd2_d1 == 10'd25) begin
                    manual_compensate_data[63:48] = (sample_last_data[134:119] >> 1) + (sample_data1[15:0] >> 1);
                    manual_compensate_data[47:32] = (sample_last_data[100:85] >> 1) + (auto_compensate_data[31:16] >> 1);
                end
                if (addr_rd2_d1 == 10'd57) begin
                    manual_compensate_data[15:0] = (auto_compensate_data[31:16] >> 1) + (sample_data3[66:51] >> 1);
                end
            end

            16'd298: begin //(182,298)
                if (addr_rd2_d1 == 10'd45) begin
                    manual_compensate_data[47:32] = (sample_last_data[117:102] >> 1) + (auto_compensate_data[63:48] >> 1);
                    manual_compensate_data[31:16] = (sample_last_data[100:85] >> 1) + (auto_compensate_data[15:0] >> 1);
                end
            end

            16'd302: begin //(513,302)
                if (addr_rd2_d1 == 10'd128) begin
                    manual_compensate_data[63:48] = (auto_compensate_data[47:32] >> 1) + (sample_data1[15:0] >> 1);
                end
            end

            16'd303: begin //(153,303)
                if (addr_rd2_d1 == 10'd38) begin
                    manual_compensate_data[63:48] = (sample_last_data[134:119] >> 1) + (sample_data1[15:0] >> 1);
                    manual_compensate_data[47:32] = (sample_last_data[100:85] >> 1) + (auto_compensate_data[31:16] >> 1);
                end
            end

            16'd306: begin //(393,306)
                if (addr_rd2_d1 == 10'd98) begin
                    manual_compensate_data[63:48] = (auto_compensate_data[47:32] >> 1) + (sample_data1[15:0] >> 1);
                end
            end

            16'd307: begin //(393,307)
                if (addr_rd2_d1 == 10'd98) begin
                    manual_compensate_data[63:48] = (auto_compensate_data[47:32] >> 1) + (sample_data1[15:0] >> 1);
                end
            end

            16'd310: begin //(261,310)
                if (addr_rd2_d1 == 10'd65) begin
                    manual_compensate_data[63:48] = (auto_compensate_data[47:32] >> 1) + (sample_data1[15:0] >> 1);
                end
            end

            16'd317: begin //(398,317)
                if (addr_rd2_d1 == 10'd99) begin
                    manual_compensate_data[47:32] = (auto_compensate_data[63:48] >> 1) + (auto_compensate_data[31:16] >> 1);
                end
            end

            16'd318: begin //(75,318)
                if (addr_rd2_d1 == 10'd18) begin
                    manual_compensate_data[31:16] = (sample_last_data[100:85] >> 1) + (auto_compensate_data[47:32] >> 1);
                    manual_compensate_data[15:0] = (sample_last_data[66:51] >> 1) + (sample_data3[66:51] >> 1);
                end
                if (addr_rd2_d1 == 10'd24) begin
                    manual_compensate_data[47:32] = (auto_compensate_data[63:48] >> 1) + (auto_compensate_data[31:16] >> 1);
                end
            end

            16'd319: begin //(75,319)
                if (addr_rd2_d1 == 10'd18) begin
                    manual_compensate_data[31:16] = (sample_last_data[117:102] >> 1) + (auto_compensate_data[47:32] >> 1);
                    manual_compensate_data[15:0] = (sample_last_data[66:51] >> 1) + (sample_data3[66:51] >> 1);
                end
                if (addr_rd2_d1 == 10'd24) begin
                    manual_compensate_data[47:32] = (auto_compensate_data[63:48] >> 1) + (auto_compensate_data[31:16] >> 1);
                end
            end

            16'd322: begin //(72,322)
                if (addr_rd2_d1 == 10'd17) begin
                    manual_compensate_data[15:0] = (sample_last_data[100:85] >> 1) + (auto_compensate_data[31:16] >> 1);
                end
                if (addr_rd2_d1 == 10'd18) begin
                    manual_compensate_data[63:48] = (sample_last_data[134:119] >> 1) + (auto_compensate_data[47:32] >> 1);
                end
            end

            16'd323: begin //(72,323)
                if (addr_rd2_d1 == 10'd17) begin
                    manual_compensate_data[15:0] = (sample_last_data[66:51] >> 1) + (auto_compensate_data[31:16] >> 1);
                end
                if (addr_rd2_d1 == 10'd18) begin
                    manual_compensate_data[63:48] = (sample_last_data[117:102] >> 1) + (auto_compensate_data[47:32] >> 1);
                end
            end

            16'd328: begin //(391,328)
                if (addr_rd2_d1 == 10'd97) begin
                    manual_compensate_data[31:16] = (auto_compensate_data[47:32] >> 1) + (sample_data3[15:0] >> 1);
                end
            end

            16'd329: begin //(534,328)
                if (addr_rd2_d1 == 10'd133) begin
                    manual_compensate_data[47:32] = (auto_compensate_data[31:16] >> 1) + (auto_compensate_data[63:48] >> 1);
                end
            end

            16'd330: begin //(346,328)
                if (addr_rd2_d1 == 10'd86) begin
                    manual_compensate_data[47:32] = (auto_compensate_data[31:16] >> 1) + (auto_compensate_data[63:48] >> 1);
                end
            end

            16'd331: begin //(391,331)
                if (addr_rd2_d1 == 10'd97) begin
                    manual_compensate_data[31:16] = (auto_compensate_data[47:32] >> 1) + (sample_data3[15:0] >> 1);
                end
            end

            16'd333: begin //(271,333)
                if (addr_rd2_d1 == 10'd67) begin
                    manual_compensate_data[31:16] = (auto_compensate_data[15:0] >> 1) + (auto_compensate_data[47:32] >> 1);
                end
            end

            16'd342: begin //(141,342)
                if (addr_rd2_d1 == 10'd35) begin
                    manual_compensate_data[63:48] = (auto_compensate_data[47:32] >> 1) + (sample_data1[15:0] >> 1);
                end
            end

            16'd344: begin //(532,344)
                if (addr_rd2_d1 == 10'd132) begin
                    manual_compensate_data[15:0] = (auto_compensate_data[31:16] >> 1) + (sample_data3[66:51] >> 1);
                end
            end

            16'd357: begin //(436,357)
                if (addr_rd2_d1 == 10'd108) begin
                    manual_compensate_data[15:0] = (auto_compensate_data[31:16] >> 1) + (sample_last_data[83:68] >> 1);
                end
                if (addr_rd2_d1 == 10'd133) begin
                    manual_compensate_data[31:16] = (auto_compensate_data[15:0] >> 1) + (auto_compensate_data[47:32] >> 1);
                end
            end

            16'd363: begin //(9,363)
                if (addr_rd2_d1 == 10'd2) begin
                    manual_compensate_data[63:48] = (sample_last_data[134:119] >> 1) + (sample_data1[15:0] >> 1);
                    manual_compensate_data[47:32] = (sample_last_data[100:85] >> 1) + (auto_compensate_data[31:16] >> 1);
                end
                if (addr_rd2_d1 == 10'd3) begin
                    manual_compensate_data[47:32] = (sample_last_data[117:102] >> 1) + (auto_compensate_data[63:48] >> 1);
                end
            end

            16'd367: begin //(29,367)
                if (addr_rd2_d1 == 10'd7) begin
                    manual_compensate_data[63:48] = (auto_compensate_data[47:32] >> 1) + (sample_data1[15:0] >> 1);
                end
            end

            16'd378: begin //(456,378)
                if (addr_rd2_d1 == 10'd113) begin
                    manual_compensate_data[15:0] = (auto_compensate_data[31:16] >> 1) + (sample_data3[66:51] >> 1);
                end
            end

            16'd380: begin //(307,380)
                if (addr_rd2_d1 == 10'd76) begin
                    manual_compensate_data[31:16] = (sample_last_data[100:85] >> 1) + (auto_compensate_data[47:32] >> 1);
                    manual_compensate_data[15:0] = (sample_last_data[83:68] >> 1) + (sample_data3[66:51] >> 1);
                end
            end

            16'd382: begin //(344,382)
                if (addr_rd2_d1 == 10'd85) begin
                    manual_compensate_data[15:0] = (sample_last_data[83:68] >> 1) + (auto_compensate_data[31:16] >> 1);
                end
                if (addr_rd2_d1 == 10'd86) begin
                    manual_compensate_data[63:48] = (sample_last_data[134:119] >> 1) + (auto_compensate_data[47:32] >> 1);
                end
                if (addr_rd2_d1 == 10'd124) begin
                    manual_compensate_data[63:48] = (sample_last_data[134:119] >> 1) + (sample_data1[15:0] >> 1);
                    manual_compensate_data[47:32] = (sample_last_data[117:102] >> 1) + (auto_compensate_data[31:16] >> 1);
                end
            end

            16'd384: begin //(254,384)
                if (addr_rd2_d1 == 10'd63) begin
                    manual_compensate_data[47:32] = (sample_last_data[117:102] >> 1) + (auto_compensate_data[63:48] >> 1);
                    manual_compensate_data[31:16] = (sample_last_data[100:85] >> 1) + (auto_compensate_data[15:0] >> 1);
                end
            end

            16'd389: begin //(120,389)
                if (addr_rd2_d1 == 10'd29) begin
                    manual_compensate_data[15:0] = (sample_data3[66:51] >> 1) + (auto_compensate_data[31:16] >> 1);
                end
            end

            16'd399: begin //(386,399)
                if (addr_rd2_d1 == 10'd96) begin
                    manual_compensate_data[47:32] = (sample_last_data[117:102] >> 1) + (auto_compensate_data[63:48] >> 1);
                    manual_compensate_data[31:16] = (sample_last_data[100:85] >> 1) + (auto_compensate_data[15:0] >> 1);
                end
            end

            16'd402: begin //(210,402)
                if (addr_rd2_d1 == 10'd52) begin
                    manual_compensate_data[47:32] = (sample_last_data[117:102] >> 1) + (auto_compensate_data[63:48] >> 1);
                    manual_compensate_data[31:16] = (sample_last_data[100:85] >> 1) + (auto_compensate_data[15:0] >> 1);
                end
            end

            16'd403: begin //(321,403)
                if (addr_rd2_d1 == 10'd80) begin
                    manual_compensate_data[63:48] = (sample_last_data[134:119] >> 1) + (sample_data1[15:0] >> 1);
                    manual_compensate_data[47:32] = (sample_last_data[117:102] >> 1) + (auto_compensate_data[31:16] >> 1);
                end
            end

            16'd409: begin //(454,409)
                if (addr_rd2_d1 == 10'd113) begin
                    manual_compensate_data[47:32] = (auto_compensate_data[63:48] >> 1) + (auto_compensate_data[31:16] >> 1);
                end
            end

            16'd416: begin //(461,416)
                if (addr_rd2_d1 == 10'd115) begin
                    manual_compensate_data[63:48] = (sample_last_data[134:119] >> 1) + (sample_data1[15:0] >> 1);
                    manual_compensate_data[47:32] = (sample_last_data[117:102] >> 1) + (auto_compensate_data[31:16] >> 1);
                end
            end

            16'd423: begin //(162,423)
                if (addr_rd2_d1 == 10'd40) begin
                    manual_compensate_data[47:32] = (sample_last_data[117:102] >> 1) + (auto_compensate_data[63:48] >> 1);
                    manual_compensate_data[31:16] = (sample_last_data[100:85] >> 1) + (auto_compensate_data[15:0] >> 1);
                end
            end

            16'd455: begin //(427,455)
                if (addr_rd2_d1 == 10'd106) begin
                    manual_compensate_data[31:16] = (auto_compensate_data[47:32] >> 1) + (auto_compensate_data[15:0] >> 1);
                end
            end

            16'd465: begin //(427,465)
                if (addr_rd2_d1 == 10'd53) begin
                    manual_compensate_data[63:48] = (sample_last_data[134:119] >> 1) + (sample_data1[15:0] >> 1);
                    manual_compensate_data[47:32] = (sample_last_data[117:102] >> 1) + (auto_compensate_data[31:16] >> 1);
                end
            end

            16'd467: begin //(348,467)
                if (addr_rd2_d1 == 10'd86) begin
                    manual_compensate_data[15:0] = (sample_data3[66:51] >> 1) + (auto_compensate_data[31:16] >> 1);
                end
            end

            16'd469: begin //(401,469)
                if (addr_rd2_d1 == 10'd100) begin
                    manual_compensate_data[63:48] = (sample_last_data[134:119] >> 1) + (sample_data1[15:0] >> 1);
                    manual_compensate_data[47:32] = (sample_last_data[117:102] >> 1) + (auto_compensate_data[31:16] >> 1);
                end
            end

            16'd501: begin //(287,501)
                if (addr_rd2_d1 == 10'd71) begin
                    manual_compensate_data[31:16] = (sample_last_data[100:85] >> 1) + (auto_compensate_data[47:32] >> 1);
                    manual_compensate_data[15:0] = (sample_last_data[83:68] >> 1) + (sample_data3[66:51] >> 1);
                end
            end

            16'd507: begin //(308,507)
                if (addr_rd2_d1 == 10'd76) begin
                    manual_compensate_data[15:0] = (auto_compensate_data[31:16] >> 1) + (sample_data3[66:51] >> 1);
                end
            end

            16'd508: begin //(317,508)
                if (addr_rd2_d1 == 10'd79) begin
                    manual_compensate_data[63:48] = (sample_last_data[134:119] >> 1) + (sample_data1[15:0] >> 1);
                    manual_compensate_data[47:32] = (sample_last_data[117:102] >> 1) + (auto_compensate_data[31:16] >> 1);
                end
            end

            16'd509: begin //(316,509)
                if (addr_rd2_d1 == 10'd78) begin
                    manual_compensate_data[15:0] = (auto_compensate_data[31:16] >> 1) + (sample_data3[66:51] >> 1);
                end
            end

            default: begin
                // 默认情况什么都不做，保持 manual_compensate_data = auto_compensate_data
                manual_compensate_data = auto_compensate_data;
            end
        endcase
    end
end

endmodule