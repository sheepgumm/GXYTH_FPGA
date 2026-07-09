`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: SITP
// Engineer: He Daogang
// 
// Create Date:    11:09:29 08/03/2014 
// Design Name:    HSTA
// Module Name:    dcm 
// Project Name:   FPGA Send module
// Target Devices: XC6SLX72-2FGG484
// Tool versions:  ISE 13.1
// Description: 
//
// Dependencies: 
//
// Revision: V0.01
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////

module time_update
(
    // ===================== 时钟与复位 =====================
    input                           I_clk               , // 系统时钟
    input                           I_rst               , // 复位信号

    // ===================== PPS 输入 =====================
    input                           I_zk_pps            , // 1Hz 秒脉冲（用于时间同步）

    // ===================== 外部时间与控制接口 =====================
    input                           I_ctrl2time_datardy , // 控制模块发送时间数据就绪
    output                          O_time2ctrl_paraen  , // 参数使能应答
    input                   [63:0]  I_zk_TIME           , // 外部时间（64位）
    input                   [7:0]   I_zk_CAMERA_SDZT    , // 相机状态/控制字

    // ===================== 时间输出 =====================
    output                          O_pps_ready         , // PPS 有效标志（去抖动后）
    output reg              [63:0]  zk_TIME             , // 当前本地时间
    output                          O_TIME_update_busy  , // 时间更新忙标志
    output                  [63:0]  O_loc_TIME          , // 本地时间（包含微秒计数）
    output                          O_driver_en         , // 驱动器使能输出
    output                  [12:2]  O_testpoint           // 测试点输出
);

    // ===================== 参数定义 =====================
    // 每秒中部接收一次外部时间，窗口为 PPS 后 450~550 ms。
    // us_count 的单位是 100 us。
    localparam [15:0] TIME_WIN_BEGIN = 16'd4500;
    localparam [15:0] TIME_WIN_END   = 16'd5500;

    // ===================== 内部信号定义 =====================
    wire                            CAMERA_img_ctrl     ; // 相机图像控制（来自 zk_CAMERA_SDZT[7]）

    reg                             time2ctrl_paraen    ; // 参数使能内部寄存器
    reg                     [7:0]   zk_CAMERA_SDZT      ; // 相机状态缓存
    reg                     [15:0]  us_count            ; // 微秒计数（单位 100us）
    reg                     [15:0]  clk_count           ; // 时钟分频计数
    reg                             TIME_update_busy    ; // 时间更新忙
    reg                             pps_ready           ; // PPS 去抖动后有效
    reg                     [1:0]   pps_sample          ; // PPS 同步打拍
    reg                     [1:0]   fsm_pps_jitter      ; // PPS 去抖动状态机
    reg                     [31:0]  cnt_jitter          ; // 去抖动计数
    reg                     [15:0]  temp_us_count       ; // 临时微秒计数
    reg                     [15:0]  temp_clk_count      ; // 临时时钟计数
    reg                     [1:0]   us_fsm              ; // 微秒计数测量状态机
    reg                             driver_en           ; // 驱动器使能
    reg                     [1:0]   driver_en_fsm       ; // 驱动器使能状态机
    reg                             driver_off_fsm      ; // 驱动器关闭状态机

    reg                     [63:0]  ext_time_buf        ; // 外部时间缓存
    reg                             ext_time_valid      ; // 外部时间缓存有效
    reg                             time_initialized    ; // 时间已初始化标志
    reg                             first_pps_done      ; // 第一次 PPS 对齐完成标志

    reg                     [12:2]  testpoint           ; // 测试点寄存器

    // ===================== 输出赋值 =====================
    assign O_time2ctrl_paraen = time2ctrl_paraen;
    // O_loc_TIME  = (zk_TIME << 13) + (zk_TIME << 10) + (zk_TIME << 9) + (zk_TIME << 8) + (zk_TIME << 4) + us_count;
    // 上述移位乘法实际上等价于 zk_TIME * 10000 + us_count（10000 = 8192+1024+512+256+16）
    assign O_loc_TIME = (zk_TIME << 13) + (zk_TIME << 10) + (zk_TIME << 9) + (zk_TIME << 8) + (zk_TIME << 4) + us_count;
    assign O_TIME_update_busy = TIME_update_busy;
    assign CAMERA_img_ctrl = zk_CAMERA_SDZT[7];
    assign O_driver_en = driver_en;
    assign O_pps_ready = pps_ready;
    assign O_testpoint[12:2] = testpoint[12:2];

    // ===================== 时间窗口判断 =====================
    // 只有完成第一次 PPS 对齐之后，才使用每秒中间时间窗口。
    assign time_latch_window = first_pps_done &&
                               (us_count >= TIME_WIN_BEGIN) &&
                               (us_count <= TIME_WIN_END);

    // ===================== PPS 同步打拍 =====================
    always @(posedge I_clk) begin
        if (!I_rst) begin
            pps_sample <= 2'b00;
        end else begin
            pps_sample[0] <= I_zk_pps;
            pps_sample[1] <= pps_sample[0];
        end
    end

    // ===================== PPS 去抖动检测（消除毛刺） =====================
    always @(posedge I_clk) begin
        if (!I_rst) begin
            pps_ready     <= 1'b0;
            cnt_jitter    <= 32'd0;
            fsm_pps_jitter <= 2'd0;
        end else begin
            case (fsm_pps_jitter)
                2'd0: begin
                    if (pps_sample == 2'b01) begin
                        fsm_pps_jitter <= 2'd1;
                        // testpoint[8] <= ~testpoint[8];
                    end
                end
                2'd1: begin
                    if (cnt_jitter == 32'd19999) begin // 200μs
                        if (pps_sample == 2'b11) begin
                            cnt_jitter <= cnt_jitter + 1'b1;
                            fsm_pps_jitter <= 2'd2;
                            // testpoint[9] <= ~testpoint[9];
                        end else begin
                            cnt_jitter <= 32'd0;
                            fsm_pps_jitter <= 2'd0;
                        end
                    end else begin
                        cnt_jitter <= cnt_jitter + 1'b1;
                    end
                end
                2'd2: begin
                    if (cnt_jitter == 32'd59999) begin // 600μs
                        if (pps_sample == 2'b11) begin
                            cnt_jitter <= 32'd0;
                            pps_ready <= 1'b1;
                            fsm_pps_jitter <= 2'd3;
                            // testpoint[10] <= ~testpoint[10];
                        end else begin
                            cnt_jitter <= 32'd0;
                            fsm_pps_jitter <= 2'd0;
                        end
                    end else begin
                        cnt_jitter <= cnt_jitter + 1'b1;
                    end
                end
                2'd3: begin
                    pps_ready <= 1'b0;
                    fsm_pps_jitter <= 2'd0;
                end
                default: begin
                    cnt_jitter <= 32'd0;
                    fsm_pps_jitter <= 2'd0;
                end
            endcase
        end
    end

    // ===================== 测量 PPS 后经过的微秒数（用于补偿延迟） =====================
    always @(posedge I_clk) begin
        if (!I_rst) begin
            temp_us_count  <= 16'd0;
            temp_clk_count <= 16'd0;
            us_fsm         <= 2'd0;
        end else begin
            case (us_fsm)
                2'd0: begin
                    if (pps_sample == 2'b01) begin
                        us_fsm         <= 2'd1;
                        temp_us_count  <= 16'd0;
                        temp_clk_count <= 16'd0;
                    end
                end
                2'd1: begin
                    if (pps_ready) begin
                        us_fsm <= 2'd2;
                    end else begin
                        if (temp_clk_count == 16'd9999) begin // 100us
                            temp_clk_count <= 16'd0;
                            temp_us_count  <= temp_us_count + 1'b1;
                        end else begin
                            temp_clk_count <= temp_clk_count + 1'b1;
                        end
                    end
                end
                2'd2: begin
                    us_fsm <= 2'd0;
                end
                default: us_fsm <= 2'd0;
            endcase
        end
    end

    // ===================== 本地时间管理与更新 =====================
    always @(posedge I_clk) begin
        if (!I_rst) begin
            time2ctrl_paraen <= 1'b0;
            TIME_update_busy <= 1'b0;
            zk_TIME          <= 64'd0;
            zk_CAMERA_SDZT   <= 8'd0;
            us_count         <= 16'd0;
            clk_count        <= 16'd0;
            ext_time_buf     <= 64'd0;
            ext_time_valid   <= 1'b0;
            time_initialized <= 1'b0;
            first_pps_done   <= 1'b0;
        end else begin
            time2ctrl_paraen <= 1'b0;
            TIME_update_busy <= 1'b0;

            // 每次收到控制参数都更新相机状态并返回接收应答。
            if (I_ctrl2time_datardy) begin
                time2ctrl_paraen <= 1'b1;
                zk_CAMERA_SDZT   <= I_zk_CAMERA_SDZT;
            end

            if (!time_initialized) begin
                // 阶段一：上电后尚未接收到第一帧外部时间
                us_count  <= 16'd0;
                clk_count <= 16'd0;

                if (I_ctrl2time_datardy) begin
                    // 第一帧外部时间立即装载
                    zk_TIME          <= I_zk_TIME;
                    ext_time_buf     <= I_zk_TIME;
                    ext_time_valid   <= 1'b1;
                    time_initialized <= 1'b1;
                    us_count         <= 16'd0;
                    clk_count        <= 16'd0;
                end
            end else begin
                // 阶段二、三：已经获得第一帧外部时间
                if (pps_ready) begin
                    // 补偿检测确认造成的延迟。
                    us_count  <= temp_us_count;
                    clk_count <= temp_clk_count;

                    if (ext_time_valid) begin
                        // 当前 PPS 应对应 ext_time_buf + 1
                        zk_TIME <= ext_time_buf + 64'd1;
                    end

                    ext_time_valid   <= 1'b0;
                    first_pps_done   <= 1'b1;
                    TIME_update_busy <= 1'b1;
                end else begin
                    // 非 PPS 时刻：缓存外部时间并运行秒内 100 us 计数。
                    // 第一次 PPS 对齐前：允许每次新报文刷新缓存，但不再反复覆盖 zk_TIME。
                    if (!first_pps_done) begin
                        if (I_ctrl2time_datardy) begin
                            ext_time_buf   <= I_zk_TIME;
                            ext_time_valid <= 1'b1;
                        end
                    end else begin
                        // 正常运行阶段：仅在 PPS 后 450~550 ms 窗口缓存一次。
                        if (I_ctrl2time_datardy && time_latch_window && !ext_time_valid) begin
                            ext_time_buf   <= I_zk_TIME;
                            ext_time_valid <= 1'b1;
                        end
                    end

                    // 本地秒内计数每经过 100 us，us_count 加 1。
                    if (clk_count >= 16'd9999) begin // 100us
                        clk_count <= 16'd0;
                        if (us_count >= 16'd9999) begin // 1s
                            us_count <= 16'd0;
                            zk_TIME  <= zk_TIME + 64'd1;
                        end else begin
                            us_count <= us_count + 1'b1;
                        end
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end
            end
        end
    end

    // ===================== 驱动器使能控制 =====================
    always @(posedge I_clk) begin
        if (!I_rst) begin
            driver_en      <= 1'b0;
            driver_en_fsm  <= 2'd0;
            driver_off_fsm <= 1'b0;
        end else begin
            case (driver_en_fsm)
                2'd0: begin
                    if (CAMERA_img_ctrl == 1'b1) begin
                        driver_en_fsm <= 2'd2;  // 直接进入使能状态（原有注释“????”，根据代码意图修正）
                    end
                end
                2'd1: begin
                    if (pps_ready) begin // 等待秒脉冲
                        driver_en_fsm <= 2'd2;
                    end
                end
                2'd2: begin
                    // 此处原先有延迟逻辑，但已注释，故直接使能并复位状态机
                    driver_en_fsm <= 2'd0;
                    driver_en     <= 1'b1;
                end
                default: driver_en_fsm <= 2'd0;
            endcase

            case (driver_off_fsm) // 关闭驱动器使能
                1'b0: begin
                    if (CAMERA_img_ctrl == 1'b0) begin
                        driver_off_fsm <= 1'b1;
                    end
                end
                1'b1: begin
                    driver_en      <= 1'b0;
                    driver_off_fsm <= 1'b0;
                end
            endcase
        end
    end


endmodule