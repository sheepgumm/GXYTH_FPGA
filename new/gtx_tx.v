`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/03/31 16:45:04
// Design Name: 
// Module Name: gtx_tx
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

// `define DLY #1

(* DowngradeIPIdentifiedWarnings="yes" *)
//***********************************Entity Declaration************************
(* CORE_GENERATION_INFO = "gtx_tx_156_32,gtwizard_v3_6_11,{protocol_file=Start_from_scratch}" *)
module gtx_tx #
(
    parameter EXAMPLE_SIM_GTRESET_SPEEDUP          =   "FALSE",    // simulation setting for GT SecureIP model
    parameter STABLE_CLOCK_PERIOD                  = 12

)
(
    input wire  Q0_CLK1_GTREFCLK_PAD_N_IN,
    input wire  Q0_CLK1_GTREFCLK_PAD_P_IN,
    input wire  DRPCLK_IN,
    input rst_n,
    input I_LSYNC,
    input I_sim_data_en,
    input I_sample_done,
    input [31:0] I_sample_data,
    input [543:0] I_gtx_mc_data,
    input [151:0] I_gtx_cam_data,
    input [79:0] I_cam_time,
    output reg   O_HTS_TDIS,
    output clk_gtx_tx,
(*mark_debug = "true"*)    output reg          O_tx_done,
(*mark_debug = "true"*)    output reg   [9:0]  O_addr,
    output wire         TXN_OUT,
    output wire         TXP_OUT,
    output wire  [31:0] O_frame_num,
    //test
    output  reg o_gtx_wr_en
);

    wire soft_reset_i;
    (*mark_debug = "TRUE" *) wire soft_reset_vio_i;

//************************** Register Declarations ****************************

    wire            gt_txfsmresetdone_i;
    wire            gt_rxfsmresetdone_i;
    (* ASYNC_REG = "TRUE" *)reg             gt_txfsmresetdone_r;
    (* ASYNC_REG = "TRUE" *)reg             gt_txfsmresetdone_r2;



//**************************** Wire Declarations ******************************//
    //------------------------ GT Wrapper Wires ------------------------------
    //________________________________________________________________________
    //________________________________________________________________________
    //GT0  (X1Y0)
    //------------------------------- CPLL Ports -------------------------------
    wire            gt0_cpllfbclklost_i;
    wire            gt0_cplllock_i;
    wire            gt0_cpllrefclklost_i;
    wire            gt0_cpllreset_i;
    //-------------------------- Channel - DRP Ports  --------------------------
    wire    [8:0]   gt0_drpaddr_i;
    wire    [15:0]  gt0_drpdi_i;
    wire    [15:0]  gt0_drpdo_i;
    wire            gt0_drpen_i;
    wire            gt0_drprdy_i;
    wire            gt0_drpwe_i;
    //------------------------- Digital Monitor Ports --------------------------
    wire    [7:0]   gt0_dmonitorout_i;
    //------------------- RX Initialization and Reset Ports --------------------
    wire            gt0_eyescanreset_i;
    //------------------------ RX Margin Analysis Ports ------------------------
    wire            gt0_eyescandataerror_i;
    wire            gt0_eyescantrigger_i;
    //------------------- Receive Ports - RX Equalizer Ports -------------------
    wire    [6:0]   gt0_rxmonitorout_i;
    wire    [1:0]   gt0_rxmonitorsel_i;
    //----------- Receive Ports - RX Initialization and Reset Ports ------------
    wire            gt0_gtrxreset_i;
    //------------------- TX Initialization and Reset Ports --------------------
    wire            gt0_gttxreset_i;
    wire            gt0_txuserrdy_i;
    //---------------- Transmit Ports - TX Data Path interface -----------------
    wire    [31:0]  gt0_txdata_i;
    //-------------- Transmit Ports - TX Driver and OOB signaling --------------
    wire            gt0_gtxtxn_i;
    wire            gt0_gtxtxp_i;
    //--------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
    wire            gt0_txoutclk_i;
    wire            gt0_txoutclkfabric_i;
    wire            gt0_txoutclkpcs_i;
    //------------------- Transmit Ports - TX Gearbox Ports --------------------
    wire    [3:0]   gt0_txcharisk_i;
    //----------- Transmit Ports - TX Initialization and Reset Ports -----------
    wire            gt0_txresetdone_i;

    //____________________________COMMON PORTS________________________________
    //-------------------- Common Block  - Ref Clock Ports ---------------------
    wire            gt0_gtrefclk0_common_i;
    wire            gt0_gtrefclk1_common_i;
    //----------------------- Common Block - QPLL Ports ------------------------
    wire            gt0_qplllock_i;
    wire            gt0_qpllrefclklost_i;
    wire            gt0_qpllreset_i;


    //----------------------------- Global Signals -----------------------------

    wire            drpclk_in_i;
    wire            gt0_rx_system_reset_c;
    wire            tied_to_ground_i;
    wire    [63:0]  tied_to_ground_vec_i;
    wire            tied_to_vcc_i;
    wire    [7:0]   tied_to_vcc_vec_i;
    wire            GTTXRESET_IN;
    wire            GTRXRESET_IN;
    wire            CPLLRESET_IN;
    wire            QPLLRESET_IN;

     //--------------------------- User Clocks ---------------------------------
     wire            gt0_txusrclk_i; 
     wire            gt0_txusrclk2_i; 
     wire            gt0_rxusrclk_i; 
     wire            gt0_rxusrclk2_i; 
 
    //--------------------------- Reference Clocks ----------------------------
    
    wire            q0_clk1_refclk_i;


    //--------------------- Frame check/gen Module Signals --------------------
    wire            gt0_matchn_i;
    
   
    
    
    wire            gt0_block_sync_i;
    wire            gt0_track_data_i;
    wire    [7:0]   gt0_error_count_i;
    wire            gt0_frame_check_reset_i;
    wire            gt0_inc_in_i;
    wire            gt0_inc_out_i;
    wire    [19:0]  gt0_unscrambled_data_i;

    wire            reset_on_data_error_i;
    wire            track_data_out_i;
  

    //--------------------- Chipscope Signals ---------------------------------
    (*mark_debug = "TRUE" *)wire   rxresetdone_vio_i;
    wire    [35:0]  tx_data_vio_control_i;
    wire    [35:0]  rx_data_vio_control_i;
    wire    [35:0]  shared_vio_control_i;
    wire    [35:0]  ila_control_i;
    wire    [35:0]  channel_drp_vio_control_i;
    wire    [35:0]  common_drp_vio_control_i;
    wire    [31:0]  tx_data_vio_async_in_i;
    wire    [31:0]  tx_data_vio_sync_in_i;
    wire    [31:0]  tx_data_vio_async_out_i;
    wire    [31:0]  tx_data_vio_sync_out_i;
    wire    [31:0]  rx_data_vio_async_in_i;
    wire    [31:0]  rx_data_vio_sync_in_i;
    wire    [31:0]  rx_data_vio_async_out_i;
    wire    [31:0]  rx_data_vio_sync_out_i;
    wire    [31:0]  shared_vio_in_i;
    wire    [31:0]  shared_vio_out_i;
    wire    [163:0] ila_in_i;
    wire    [31:0]  channel_drp_vio_async_in_i;
    wire    [31:0]  channel_drp_vio_sync_in_i;
    wire    [31:0]  channel_drp_vio_async_out_i;
    wire    [31:0]  channel_drp_vio_sync_out_i;
    wire    [31:0]  common_drp_vio_async_in_i;
    wire    [31:0]  common_drp_vio_sync_in_i;
    wire    [31:0]  common_drp_vio_async_out_i;
    wire    [31:0]  common_drp_vio_sync_out_i;

    wire    [31:0]  gt0_tx_data_vio_async_in_i;
    wire    [31:0]  gt0_tx_data_vio_sync_in_i;
    wire    [31:0]  gt0_tx_data_vio_async_out_i;
    wire    [31:0]  gt0_tx_data_vio_sync_out_i;
    wire    [31:0]  gt0_rx_data_vio_async_in_i;
    wire    [31:0]  gt0_rx_data_vio_sync_in_i;
    wire    [31:0]  gt0_rx_data_vio_async_out_i;
    wire    [31:0]  gt0_rx_data_vio_sync_out_i;
    wire    [163:0] gt0_ila_in_i;
    wire    [31:0]  gt0_channel_drp_vio_async_in_i;
    wire    [31:0]  gt0_channel_drp_vio_sync_in_i;
    wire    [31:0]  gt0_channel_drp_vio_async_out_i;
    wire    [31:0]  gt0_channel_drp_vio_sync_out_i;
    wire    [31:0]  gt0_common_drp_vio_async_in_i;
    wire    [31:0]  gt0_common_drp_vio_sync_in_i;
    wire    [31:0]  gt0_common_drp_vio_async_out_i;
    wire    [31:0]  gt0_common_drp_vio_sync_out_i;


    wire            gttxreset_i;
    wire            gtrxreset_i;

    wire            user_tx_reset_i;
    wire            user_rx_reset_i;
    wire            tx_vio_clk_i;
    wire            tx_vio_clk_mux_out_i;    
    wire            rx_vio_ila_clk_i;
    wire            rx_vio_ila_clk_mux_out_i;

    wire            cpllreset_i;
    


  wire [(80 -20) -1:0] zero_vector_rx_80 ;
  wire [(8 -2) -1:0] zero_vector_rx_8 ;
  wire [79:0] gt0_rxdata_ila ;
  wire [1:0]  gt0_rxdatavalid_ila; 
  wire [7:0]  gt0_rxcharisk_ila ;
  wire gt0_txmmcm_lock_ila ;
  wire gt0_rxmmcm_lock_ila ;
  wire gt0_rxresetdone_ila ;
  wire gt0_txresetdone_ila ;

//**************************** Main Body of Code *******************************

    //  Static signal Assigments    
    assign tied_to_ground_i             = 1'b0;
    assign tied_to_ground_vec_i         = 64'h0000000000000000;
    assign tied_to_vcc_i                = 1'b1;
    assign tied_to_vcc_vec_i            = 8'hff;

    assign zero_vector_rx_80 = 0;
    assign zero_vector_rx_8 = 0;

assign  drpclk_in_i = DRPCLK_IN;    
assign  q0_clk1_refclk_i                     =  1'b0;

    //***********************************************************************//
    //                                                                       //
    //--------------------------- The GT Wrapper ----------------------------//
    //                                                                       //
    //***********************************************************************//
    
    // Use the instantiation template in the example directory to add the GT wrapper to your design.
    // In this example, the wrapper is wired up for basic operation with a frame generator and frame 
    // checker. The GTs will reset, then attempt to align and transmit data. If channel bonding is 
    // enabled, bonding should occur after alignment.
    // While connecting the GT TX/RX Reset ports below, please add a delay of
    // minimum 500ns as mentioned in AR 43482.

    
    gtx_tx_156_32_support #
    (
        .EXAMPLE_SIM_GTRESET_SPEEDUP    (EXAMPLE_SIM_GTRESET_SPEEDUP),
        .STABLE_CLOCK_PERIOD            (STABLE_CLOCK_PERIOD)
    )
    gtx_tx_156_32_support_i
    (
        .soft_reset_tx_in               (soft_reset_i),
        .dont_reset_on_data_error_in    (tied_to_ground_i),
    .q0_clk1_gtrefclk_pad_n_in(Q0_CLK1_GTREFCLK_PAD_N_IN),
    .q0_clk1_gtrefclk_pad_p_in(Q0_CLK1_GTREFCLK_PAD_P_IN),
        .gt0_data_valid_in              (tied_to_ground_i),
 
    .gt0_txusrclk_out(gt0_txusrclk_i),
    .gt0_txusrclk2_out(gt0_txusrclk2_i),


        //_____________________________________________________________________
        //_____________________________________________________________________
        //GT0  (X1Y0)

        //------------------------------- CPLL Ports -------------------------------
        .gt0_cpllfbclklost_out          (gt0_cpllfbclklost_i),
        .gt0_cplllock_out               (gt0_cplllock_i),
        .gt0_cpllreset_in               (tied_to_ground_i),
        //-------------------------- Channel - DRP Ports  --------------------------
        .gt0_drpaddr_in                 (gt0_drpaddr_i),
        .gt0_drpdi_in                   (gt0_drpdi_i),
        .gt0_drpdo_out                  (gt0_drpdo_i),
        .gt0_drpen_in                   (gt0_drpen_i),
        .gt0_drprdy_out                 (gt0_drprdy_i),
        .gt0_drpwe_in                   (gt0_drpwe_i),
        //------------------------- Digital Monitor Ports --------------------------
        .gt0_dmonitorout_out            (gt0_dmonitorout_i),
        //------------------- RX Initialization and Reset Ports --------------------
        .gt0_eyescanreset_in            (tied_to_ground_i),
        //------------------------ RX Margin Analysis Ports ------------------------
        .gt0_eyescandataerror_out       (gt0_eyescandataerror_i),
        .gt0_eyescantrigger_in          (tied_to_ground_i),
        //------------------- Receive Ports - RX Equalizer Ports -------------------
        .gt0_rxmonitorout_out           (gt0_rxmonitorout_i),
        .gt0_rxmonitorsel_in            (2'b00),
        //----------- Receive Ports - RX Initialization and Reset Ports ------------
        .gt0_gtrxreset_in               (tied_to_ground_i),
        //------------------- TX Initialization and Reset Ports --------------------
        .gt0_gttxreset_in               (tied_to_ground_i),
        .gt0_txuserrdy_in               (tied_to_vcc_i),
        //---------------- Transmit Ports - TX Data Path interface -----------------
        .gt0_txdata_in                  (gt0_txdata_i),//32bit data input
        //-------------- Transmit Ports - TX Driver and OOB signaling --------------
        .gt0_gtxtxn_out                 (TXN_OUT),
        .gt0_gtxtxp_out                 (TXP_OUT),
        //--------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
        .gt0_txoutclkfabric_out         (gt0_txoutclkfabric_i),
        .gt0_txoutclkpcs_out            (gt0_txoutclkpcs_i),
        //------------------- Transmit Ports - TX Gearbox Ports --------------------
        .gt0_txcharisk_in               (gt0_txcharisk_i),
        //----------- Transmit Ports - TX Initialization and Reset Ports -----------
        .gt0_txresetdone_out            (gt0_txresetdone_i),


    //____________________________COMMON PORTS________________________________
    .gt0_qplloutclk_out(),
    .gt0_qplloutrefclk_out(),
    .sysclk_in(drpclk_in_i)
    );

assign gt0_drpaddr_i = 9'd0;
assign gt0_drpdi_i = 16'd0;
assign gt0_drpen_i = 1'b0;
assign gt0_drpwe_i = 1'b0;
assign soft_reset_i = tied_to_ground_i;
///////////////////////////////////////////////////////////////////
////////////////////    tx_data_part
parameter column = 648;
parameter row = 513;
(*mark_debug = "true"*)reg [31:0] tx_data_temp;
reg [3:0]  txcharisk_temp;
reg [15:0] tx_done_cnt;
(*mark_debug = "true"*)reg [15:0] line_num;
reg [31:0] frame_num;
reg [11:0] tx_word_num;
reg [543:0] gtx_mc_data;
reg [151:0] gtx_cam_data;
reg [79:0] cam_time;
reg [15:0] crc_send;
reg [15:0] data_ram;
assign gt0_txdata_i = tx_data_temp;
assign gt0_txcharisk_i = txcharisk_temp;
assign clk_gtx_tx = gt0_txusrclk2_i;
assign O_frame_num = frame_num;
//异步信号打拍
reg [1:0] sample_done;
(*mark_debug = "TRUE" *)reg [1:0] sim_data_en;
reg [1:0] sample_I_LSYNC;
reg [1:0] image_start;
reg sim_en;
reg [31:0] sim_data;
//gtx发送状态机
(*mark_debug = "true"*)reg [3:0] gtx_tx_state;
//head data状态机
reg [4:0] head_data_state1;
reg [9:0] head_data_state2;
localparam [3:0] IDLE       = 3'd0,
                 LINE_NUM   = 3'd1,
                 TX         = 3'd2,
                 TX_SIM     = 3'd3,
                 WAIT       = 3'd4,
                 HEAD_DATA1  = 3'd5,
                 HEAD_DATA2  = 3'd6;   
always @(posedge clk_gtx_tx ) begin
    if(!rst_n) begin
        sample_done <= 0;
        sim_data_en <= 0;
        image_start <= 0;
        sample_I_LSYNC <= 0;
    end
    else begin
        sample_done[0] <= I_sample_done;
        sample_done[1] <= sample_done[0];

        sim_data_en[0] <= I_sim_data_en;
        sim_data_en[1] <= sim_data_en[0];

        //sample_I_LSYNC[0] <= I_LSYNC;
        sample_I_LSYNC[0] <= I_LSYNC;
        sample_I_LSYNC[1] <= sample_I_LSYNC[0];
    end
end
always @(posedge clk_gtx_tx ) begin
    if(!rst_n) begin
        tx_data_temp    <= 32'h0302_01BC;//k码
        txcharisk_temp  <= 4'b0001;//1指示传输数据那里是k码，0则为数据
        gtx_tx_state <= IDLE;
        tx_done_cnt <= 0;
        O_tx_done <= 0;
        O_HTS_TDIS <= 1'b1;
        O_addr <= 0;
        line_num <= 0;
        frame_num <= 0;
        sim_en <= 0;
        tx_word_num <= 1;
        head_data_state1 <= 0;
        head_data_state2 <= 0;
        sim_data <= 32'h00010002;  
        gtx_mc_data <= 0;
        gtx_cam_data <= 0; 
        cam_time <= 0;  
        crc_send <= 0;  
        data_ram <= 0;
        o_gtx_wr_en <= 0;
    end
    else begin
        O_HTS_TDIS <= 1'b0;
        case (gtx_tx_state)
            IDLE: begin
                tx_data_temp    <= 32'h0302_01BC;//k码 32'h0302_01BC  32'h01BC_0302
                txcharisk_temp  <= 4'b0001;//1指示传输数据那里是k码，0则为数据
                 if(sample_I_LSYNC == 2'b11) begin   //sample_I_LSYNC == 2'b11
                    if(sim_data_en[1]) begin//检测是否发送模拟源
                        sim_en <= 1'b1;
                    end
                    else begin
                        sim_en <= 0;
                    end
                    o_gtx_wr_en <= 1'b1;
                    gtx_tx_state <= LINE_NUM;
                    O_addr <= 0;
                    gtx_mc_data <= I_gtx_mc_data;
                    gtx_cam_data <= I_gtx_cam_data;
                    cam_time <= I_cam_time;
                 end
            end 
            
            LINE_NUM: begin
                if(line_num == row) begin
                    gtx_tx_state <= IDLE;
                    line_num <= 0;
                    frame_num <= frame_num + 1;
                end
                else begin
                    if((sample_done == 2'b11) || (line_num == 0)) begin //(sample_done == 2'b11) || (line_num == 0)
                        tx_data_temp    <= 32'h0302_01BC;//k码 32'h0302_01BC  32'h01BC_0302
                        txcharisk_temp  <= 4'b0001;//1指示传输数据那里是k码，0则为数据
                        gtx_tx_state <= HEAD_DATA1;
                        head_data_state1 <= 0;
                        tx_word_num <= 1;
                        crc_send <= 0;
                    end
                end
            end
            HEAD_DATA1: begin
                case (head_data_state1)
                    0: begin
                        tx_data_temp    <= 32'hfdfd_7f7f;//数据传输标识 SOF 同步头
                        txcharisk_temp  <= 4'b0000;//1指示传输数据那里是k码，0则为数据
                        head_data_state1 <= 1;
                        tx_word_num <= tx_word_num + 2;
                        crc_send <= crc_send + 16'hfdfd + 16'h7f7f;
                    end
                    1: begin
                        tx_data_temp    <= {16'h7f7f,16'd1024};//同步头 包长度：1024
                        txcharisk_temp  <= 4'b0000;//1指示传输数据那里是k码，0则为数据
                        head_data_state1 <= 2;
                        tx_word_num <= tx_word_num + 2;
                        crc_send <= crc_send + 16'h7f7f + 16'd1024;
                        o_gtx_wr_en <= 1'b0;
                    end
                    2: begin
                        tx_data_temp    <= {((line_num == 0) ? 8'haa : 8'h55),4'h3,4'h0,frame_num[15:0]};//包类型 设备标识1 设备标识2 帧号
                        txcharisk_temp  <= 4'b0000;//1指示传输数据那里是k码，0则为数据
                        tx_word_num <= tx_word_num + 2;
                        crc_send <= crc_send + 16'haa30 + frame_num[15:0];
                        if(line_num == 0) begin
                            gtx_tx_state <= HEAD_DATA2;
                            head_data_state2 <= 0;
                        end
                        else begin
                            if(sim_en) begin
                                gtx_tx_state <= TX_SIM;
                            end
                            else begin
                                gtx_tx_state <= TX;
                            end
                        end
                    end

                    default: begin
                        head_data_state1 <= 0;
                    end
                endcase
            end
            HEAD_DATA2: begin
                tx_word_num <= tx_word_num + 2;
                case (head_data_state2)
                    0: begin
                        tx_data_temp    <= {line_num,8'h0,cam_time[79:72]};//行号 日内秒8 低八位有效 
                        txcharisk_temp  <= 4'b0000;//1指示传输数据那里是k码，0则为数据
                        crc_send <= crc_send + line_num + cam_time[79:72];
                        head_data_state2 <= 1;
                    end
                    1: begin
                        tx_data_temp    <= {8'h0,cam_time[71:64],8'h0,cam_time[63:56]};//日内秒7 6
                        txcharisk_temp  <= 4'b0000;//1指示传输数据那里是k码，0则为数据
                        crc_send <= crc_send + cam_time[71:64] + cam_time[63:56];
                        head_data_state2 <= 2;
                    end
                    2: begin
                        tx_data_temp    <= {8'h0,cam_time[55:48],8'h0,cam_time[47:40]};//日内秒5 4低八位有效 其他置0
                        txcharisk_temp  <= 4'b0000;//1指示传输数据那里是k码，0则为数据
                        crc_send <= crc_send + cam_time[55:48] + cam_time[47:40];
                        head_data_state2 <= 3;
                    end
                    3: begin
                        tx_data_temp    <= {8'h0,cam_time[39:32],8'h0,cam_time[31:24]};//日内秒3 2低八位有效 其他置0
                        txcharisk_temp  <= 4'b0000;//1指示传输数据那里是k码，0则为数据
                        crc_send <= crc_send + cam_time[39:32] + cam_time[31:24];
                        head_data_state2 <= 4;
                    end
                    4: begin
                        tx_data_temp    <= {8'h0,cam_time[23:16],16'h0};//日内秒1 低八位有效 其他置0 冗余32
                        txcharisk_temp  <= 4'b0000;//1指示传输数据那里是k码，0则为数据
                        crc_send <= crc_send + cam_time[23:16];
                        head_data_state2 <= 5;
                    end
                    5: begin
                        tx_data_temp    <= {16'h0,16'h0};//冗余31 - 2
                        txcharisk_temp  <= 4'b0000;//1指示传输数据那里是k码，0则为数据
                        if(tx_word_num == 12'd45) begin
                            head_data_state2 <= 6;
                        end
                    end
                    6: begin
                        tx_data_temp    <= {16'h0,gtx_mc_data[543:528]};//冗余1 扫描角时间4
                        txcharisk_temp  <= 4'b0000;//1指示传输数据那里是k码，0则为数据
                        crc_send <= crc_send + gtx_mc_data[543:528];
                        head_data_state2 <= 7;
                    end
                    7: begin
                        tx_data_temp    <= {gtx_mc_data[527:496]};//扫描角时间3 扫描角时间2
                        txcharisk_temp  <= 4'b0000;//1指示传输数据那里是k码，0则为数据
                        crc_send <= crc_send + gtx_mc_data[527:512] + gtx_mc_data[511:496];
                        head_data_state2 <= 8;
                    end
                    8: begin
                        tx_data_temp    <= {gtx_mc_data[495:464]};//扫描角时间1 扫描角4
                        txcharisk_temp  <= 4'b0000;//1指示传输数据那里是k码，0则为数据
                        crc_send <= crc_send + gtx_mc_data[495:480] + gtx_mc_data[479:464];
                        head_data_state2 <= 9;
                    end
                    9: begin
                        tx_data_temp    <= {gtx_mc_data[463:432]};//扫描角3 扫描角2
                        txcharisk_temp  <= 4'b0000;//1指示传输数据那里是k码，0则为数据
                        crc_send <= crc_send + gtx_mc_data[463:448] + gtx_mc_data[447:432];
                        head_data_state2 <= 10;
                    end
                    10: begin
                        tx_data_temp    <= {gtx_mc_data[431:400]};//扫描角1 电机状态
                        txcharisk_temp  <= 4'b0000;//1指示传输数据那里是k码，0则为数据
                        crc_send <= crc_send + gtx_mc_data[431:416] + gtx_mc_data[415:400];
                        head_data_state2 <= 11;
                    end
                    11: begin
                        tx_data_temp    <= {gtx_mc_data[399:368]};//8B二路温度点16  8B二路温度点15 
                        txcharisk_temp  <= 4'b0000;//1指示传输数据那里是k码，0则为数据
                        crc_send <= crc_send + gtx_mc_data[399:384] + gtx_mc_data[383:368];
                        head_data_state2 <= 12;
                    end
                    12: begin
                        tx_data_temp    <= {gtx_mc_data[367:336]};//8B二路温度点14  8B二路温度点13 
                        txcharisk_temp  <= 4'b0000;//1指示传输数据那里是k码，0则为数据
                        crc_send <= crc_send + gtx_mc_data[367:352] + gtx_mc_data[351:336];
                        head_data_state2 <= 13;
                    end
                    13: begin
                        tx_data_temp    <= {gtx_mc_data[335:304]};//8B二路温度点12  8B二路温度点11 
                        txcharisk_temp  <= 4'b0000;//1指示传输数据那里是k码，0则为数据
                        crc_send <= crc_send + gtx_mc_data[335:320] + gtx_mc_data[319:304];
                        head_data_state2 <= 14;
                    end
                    14: begin
                        tx_data_temp    <= {gtx_mc_data[303:272]};//8B二路温度点10  8B二路温度点9 
                        txcharisk_temp  <= 4'b0000;//1指示传输数据那里是k码，0则为数据
                        crc_send <= crc_send + gtx_mc_data[303:288] + gtx_mc_data[287:272];
                        head_data_state2 <= 15;
                    end
                    15: begin
                        tx_data_temp    <= {gtx_mc_data[271:240]};//8B二路温度点8  8B二路温度点7 
                        txcharisk_temp  <= 4'b0000;//1指示传输数据那里是k码，0则为数据
                        crc_send <= crc_send + gtx_mc_data[271:256] + gtx_mc_data[255:240];
                        head_data_state2 <= 16;
                    end
                    16: begin
                        tx_data_temp    <= {gtx_mc_data[239:208]};//8B二路温度点6  8B二路温度点5
                        txcharisk_temp  <= 4'b0000;//1指示传输数据那里是k码，0则为数据
                        crc_send <= crc_send + gtx_mc_data[239:224] + gtx_mc_data[223:208];
                        head_data_state2 <= 17;
                    end
                    17: begin
                        tx_data_temp    <= {gtx_mc_data[207:176]};//8B二路温度点4  8B二路温度点3 
                        txcharisk_temp  <= 4'b0000;//1指示传输数据那里是k码，0则为数据
                        crc_send <= crc_send + gtx_mc_data[207:192] + gtx_mc_data[191:176];
                        head_data_state2 <= 18;
                    end
                    18: begin
                        tx_data_temp    <= {gtx_mc_data[175:144]};//8B二路温度点2  8B二路温度点1 
                        txcharisk_temp  <= 4'b0000;//1指示传输数据那里是k码，0则为数据
                        crc_send <= crc_send + gtx_mc_data[175:160] + gtx_mc_data[159:144];
                        head_data_state2 <= 19;
                    end
                    19: begin
                        tx_data_temp    <= {gtx_mc_data[143:112]};//冷箱状态10  冷箱状态9
                        txcharisk_temp  <= 4'b0000;//1指示传输数据那里是k码，0则为数据
                        crc_send <= crc_send + gtx_mc_data[143:128] + gtx_mc_data[127:112];
                        head_data_state2 <= 20;
                    end
                    20: begin
                        tx_data_temp    <= {gtx_mc_data[111:80]};//冷箱状态8  冷箱状态7
                        txcharisk_temp  <= 4'b0000;//1指示传输数据那里是k码，0则为数据
                        crc_send <= crc_send + gtx_mc_data[111:96] + gtx_mc_data[95:80];
                        head_data_state2 <= 21;
                    end
                    21: begin
                        tx_data_temp    <= {gtx_mc_data[79:48]};//冷箱状态6  冷箱状态5
                        txcharisk_temp  <= 4'b0000;//1指示传输数据那里是k码，0则为数据
                        crc_send <= crc_send + gtx_mc_data[79:64] + gtx_mc_data[63:48];
                        head_data_state2 <= 22;
                    end
                    22: begin
                        tx_data_temp    <= {gtx_mc_data[47:16]};//冷箱状态4  冷箱状态3
                        txcharisk_temp  <= 4'b0000;//1指示传输数据那里是k码，0则为数据
                        crc_send <= crc_send + gtx_mc_data[47:32] + gtx_mc_data[31:16];
                        head_data_state2 <= 23;
                    end
                    23: begin
                        tx_data_temp    <= {gtx_mc_data[15:0],16'h0};//冷箱状态2  冷箱状态1
                        txcharisk_temp  <= 4'b0000;//1指示传输数据那里是k码，0则为数据
                        crc_send <= crc_send + gtx_mc_data[15:0];
                        head_data_state2 <= 24;
                    end
                    24: begin
                        tx_data_temp    <= {16'h03,16'h0};//光谱仪类型 积分时间2
                        txcharisk_temp  <= 4'b0000;//1指示传输数据那里是k码，0则为数据
                        crc_send <= crc_send + 16'h03;
                        head_data_state2 <= 25;
                    end
                    25: begin
                        tx_data_temp    <= {gtx_cam_data[151:136],8'h0,gtx_cam_data[135:128]};//积分时间1 成像增益
                        txcharisk_temp  <= 4'b0000;//1指示传输数据那里是k码，0则为数据
                        crc_send <= crc_send + gtx_cam_data[151:136] + gtx_cam_data[135:128];
                        head_data_state2 <= 26;
                    end
                    26: begin
                        tx_data_temp    <= {16'h0,gtx_cam_data[127:112]};//成像周期2 1
                        txcharisk_temp  <= 4'b0000;//1指示传输数据那里是k码，0则为数据
                        crc_send <= crc_send + gtx_cam_data[127:112];
                        head_data_state2 <= 27;
                    end
                    27: begin
                        tx_data_temp    <= {16'h0,gtx_cam_data[111:96]};//调焦位置2 1
                        txcharisk_temp  <= 4'b0000;//1指示传输数据那里是k码，0则为数据
                        crc_send <= crc_send + gtx_cam_data[111:96];
                        head_data_state2 <= 28;
                    end
                    28: begin
                        tx_data_temp    <= {16'h0,gtx_cam_data[95:80]};//制冷门限2 1
                        txcharisk_temp  <= 4'b0000;//1指示传输数据那里是k码，0则为数据
                        crc_send <= crc_send + gtx_cam_data[95:80];
                        head_data_state2 <= 29;
                    end
                    29: begin
                        tx_data_temp    <= {8'h0,gtx_cam_data[79:72],8'h0,gtx_cam_data[71:64]};//光谱仪上电状态 光谱仪内部状态
                        txcharisk_temp  <= 4'b0000;//1指示传输数据那里是k码，0则为数据
                        crc_send <= crc_send + {8'h0,gtx_cam_data[79:72]} + {8'h0,gtx_cam_data[71:64]};
                        head_data_state2 <= 30;
                    end
                    30: begin
                        tx_data_temp    <= {16'h0,16'h0};//冗余97-128
                        txcharisk_temp  <= 4'b0000;//1指示传输数据那里是k码，0则为数据
                        if(tx_word_num == 127) begin
                            head_data_state2 <= 31;
                        end
                    end
                    31: begin
                        tx_data_temp    <= {16'h0,16'h0};//冗余1 光谱仪温度1_2
                        txcharisk_temp  <= 4'b0000;//1指示传输数据那里是k码，0则为数据
                        head_data_state2 <= 32;
                    end
                    32: begin
                        tx_data_temp    <= {gtx_cam_data[63:48],16'h0};//光谱仪温度1_1 光谱仪温度2_2
                        txcharisk_temp  <= 4'b0000;//1指示传输数据那里是k码，0则为数据
                        crc_send <= crc_send + gtx_cam_data[63:48];
                        head_data_state2 <= 33;
                    end
                    33: begin
                        tx_data_temp    <= {gtx_cam_data[47:32],16'h0};//光谱仪温度2_1 光谱仪温度3_2
                        txcharisk_temp  <= 4'b0000;//1指示传输数据那里是k码，0则为数据
                        crc_send <= crc_send + gtx_cam_data[47:32];
                        head_data_state2 <= 34;
                    end
                    34: begin
                        tx_data_temp    <= {gtx_cam_data[31:16],16'h0};//光谱仪温度3_1 光谱仪版本2
                        txcharisk_temp  <= 4'b0000;//1指示传输数据那里是k码，0则为数据
                        crc_send <= crc_send + gtx_cam_data[31:16];
                        head_data_state2 <= 35;
                    end
                    35: begin
                        tx_data_temp    <= {gtx_cam_data[15:0],16'h0};//光谱仪版本1 光谱仪时间8
                        txcharisk_temp  <= 4'b0000;//1指示传输数据那里是k码，0则为数据
                        crc_send <= crc_send + gtx_cam_data[15:0];
                        head_data_state2 <= 36;
                    end
                    36: begin
                        tx_data_temp    <= {8'h0,cam_time[71:64],16'h0};//光谱仪时间7 光谱仪时间6
                        txcharisk_temp  <= 4'b0000;//1指示传输数据那里是k码，0则为数据
                        crc_send <= crc_send + {8'h0,cam_time[71:64]};
                        head_data_state2 <= 37;
                    end
                    37: begin
                        tx_data_temp    <= {8'h0,cam_time[55:48],16'h0};//光谱仪时间5 光谱仪时间4
                        txcharisk_temp  <= 4'b0000;//1指示传输数据那里是k码，0则为数据
                        crc_send <= crc_send + {8'h0,cam_time[55:48]};
                        head_data_state2 <= 38;
                    end
                    38: begin
                        tx_data_temp    <= {8'h0,cam_time[39:32],8'h0,cam_time[15:8]};//光谱仪时间3 光谱仪时间2
                        txcharisk_temp  <= 4'b0000;//1指示传输数据那里是k码，0则为数据
                        crc_send <= crc_send + {8'h0,cam_time[39:32]} + {8'h0,cam_time[15:8]};
                        head_data_state2 <= 39;
                    end
                    39: begin
                        tx_data_temp    <= {8'h0,cam_time[7:0],16'h0};//光谱仪时间1 光谱仪成像数4
                        txcharisk_temp  <= 4'b0000;//1指示传输数据那里是k码，0则为数据
                        crc_send <= crc_send + {8'h0,cam_time[7:0]};
                        head_data_state2 <= 40;
                    end
                    40: begin
                        tx_data_temp    <= {16'h0,frame_num[31:16]};//光谱仪成像数3 光谱仪成像数2
                        txcharisk_temp  <= 4'b0000;//1指示传输数据那里是k码，0则为数据
                        crc_send <= crc_send + frame_num[31:16];
                        head_data_state2 <= 41;
                    end
                    41: begin
                        tx_data_temp    <= {frame_num[15:0],16'h0};//光谱仪成像数1 光谱仪冗余150
                        txcharisk_temp  <= 4'b0000;//1指示传输数据那里是k码，0则为数据
                        crc_send <= crc_send + frame_num[15:0];
                        head_data_state2 <= 42;
                    end
                    42: begin
                        tx_data_temp    <= {16'h0,16'h0};//光谱仪冗余151-176
                        txcharisk_temp  <= 4'b0000;//1指示传输数据那里是k码，0则为数据
                        if(tx_word_num == 175) begin
                            head_data_state2 <= 43;
                        end
                    end
                    43: begin
                        tx_data_temp    <= {16'h0,16'h0};//备用177-1030
                        txcharisk_temp  <= 4'b0000;//1指示传输数据那里是k码，0则为数据
                        if(tx_word_num == (column - 3)) begin
                            head_data_state2 <= 44;
                            crc_send <= crc_send + 16'h1234;
                        end
                    end
                    44: begin
                        tx_data_temp    <= {16'h1234,crc_send};//版本号 校验和
                        txcharisk_temp  <= 4'b0000;//1指示传输数据那里是k码，0则为数据
                        gtx_tx_state <= WAIT;
                    end
                    
                    default: begin
                        head_data_state2 <= 0;
                    end
                endcase
            end
            TX: begin
                txcharisk_temp  <= 4'b0000;//1指示传输数据那里是k码，0则为数据
                data_ram <= I_sample_data[15:0];
                tx_word_num <= tx_word_num + 2;
                if(tx_word_num == (column - 1)) begin
                    tx_data_temp <= {data_ram,{crc_send + data_ram}};   
                    line_num <= line_num + 1'b1;
                    O_tx_done <= 1;
                    O_addr <= 0;
                    gtx_tx_state <= WAIT;
                end
                else if(tx_word_num == 7) begin
                    tx_data_temp <= {line_num,I_sample_data[31:16]};
                    crc_send <= crc_send + line_num + I_sample_data[31:16];
                    O_addr <= O_addr + 1'b1;
                end
                else begin
                    tx_data_temp <= {data_ram,I_sample_data[31:16]};    
                    crc_send <= crc_send + data_ram + I_sample_data[31:16];
                    O_addr <= O_addr + 1'b1;
                end
            end
            TX_SIM: begin//发送模拟源
                txcharisk_temp  <= 4'b0000;//1指示传输数据那里是k码，0则为数据
                tx_word_num <= tx_word_num + 2; 
                if(tx_word_num == (column - 1)) begin
                    tx_data_temp <= {sim_data[31:16],{crc_send + sim_data[31:16]}};
                    line_num <= line_num + 1'b1;
                    O_tx_done <= 1;
                    gtx_tx_state <= WAIT;
                end
                else if(tx_word_num == 7) begin
                    tx_data_temp <= {line_num,16'h0};
                    sim_data <= 32'h00010002;
                    crc_send <= crc_send + line_num;
                end
                else begin
                    tx_data_temp <= sim_data;
                    crc_send <= crc_send + sim_data[31:16] + sim_data[15:0];
                    sim_data <= sim_data + 32'h00020002;
                end
            end
            WAIT: begin
                tx_data_temp    <= 32'h0302_01BC;//k码
                txcharisk_temp  <= 4'b0001;//1指示传输数据那里是k码，0则为数据
                if(line_num == 0) begin
                    if(tx_done_cnt == 16'd500) begin//延时，避免行与行之间间隔太短 gtx fifo丢弃该行
                        tx_done_cnt <= 0;
                        line_num <= line_num + 1'b1;
                        gtx_tx_state <= LINE_NUM;
                    end
                    else begin
                        tx_done_cnt <= tx_done_cnt + 1'b1;
                    end
                end
                if(O_tx_done) begin
                    if(tx_done_cnt == 16'd500) begin//延时，避免捕捉不到上升沿13
                        tx_done_cnt <= 0;
                        O_tx_done <= 0;
                        gtx_tx_state <= LINE_NUM;
                    end
                    else begin
                        tx_done_cnt <= tx_done_cnt + 1'b1;
                    end
                end
            end
            default: begin
                gtx_tx_state <= IDLE;
            end
        endcase
    end
end

endmodule
    
