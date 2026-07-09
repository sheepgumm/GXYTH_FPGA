`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/03/29 13:18:53
// Design Name: 
// Module Name: image_sample
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

module image_sample(
	input I_clk,//100
	input I_rst,
    input I_adc_clk,
	input I_cl_clk, //read_clk 66M
	input I_line_vaild,//generate by st and row_st(from det)
    input fifo_ddr_done,
    input [7:0] two_point_sig,
    
	input [15:0] I_dataA1,
	input [15:0] I_dataB1,
    input [15:0] I_dataC1,
	input [15:0] I_dataD1,

	//input [9:0] I_addr_rd,
    input [9:0] last_line_addr,
	input [9:0] I_addr_rd1,
    input [9:0] I_addr_rd2,
    input [9:0] I_addr_rd3,
    // --- 【新增端口】从 aurora_tx 接收当前的读数据的行号 ---
    input [15:0] I_read_row,

	(*mark_debug = "true"*)input I_data_rd_finish,
    input fco,
    // output [127:0] O_sample_last_data,
    // output [63:0] O_sample_data1,    
    // output [63:0] O_sample_data2,
    // output [63:0] O_sample_data3,
	output [63:0] O_sample_data,
    output O_two_point_start,

    input [127:0] kb_data,
	output reg O_sample_finish,
    output reg [9:0] O_read_ram_addr1,
    output reg [9:0] O_read_ram_addr2,
    output reg read_rram_finish1,
    output reg read_rram_finish2,
    output rram_rclk
	// output ena1_test,
	// output enb1_test,
	// output ena2_test,
	// output enb2_test,
    // output [255:0] dout_fifo_test,
	// output [9:0] addra1_test,
    // output [9:0] addra2_test,
    // output [15:0] tempA_test,
    // output [15:0] tempE_test,
    // output [255:0] dina_test,
    // output fco_test,
    // output test_det_row
	);
	
reg[1:0] rd_finish_sample;
reg[1:0] row_st_sample;
(*mark_debug = "true"*)reg[5:0] fco_sample;
assign rram_rclk = fco_sample[0];
(*mark_debug = "true"*)reg rama_en;
(*mark_debug = "true"*)reg ramb_en;
(*mark_debug = "true"*)reg [3:0] rama_sample_fsm;
(*mark_debug = "true"*)reg [3:0] ramb_sample_fsm;


// reg sample_rdy;	

wire [15:0] tempA;
wire [15:0] tempB;	
wire [15:0] tempC;	
wire [15:0] tempD;

wire [15:0] tempA_a;
wire [15:0] tempB_a;	
wire [15:0] tempC_a;	
wire [15:0] tempD_a;
// reg [15:0] tempE;
// reg [15:0] tempF;	
// reg [15:0] tempG;	
// reg [15:0] tempH;
reg [67:0] dina;


//test



(*mark_debug = "true"*)reg ena1;
(*mark_debug = "true"*)reg wea1;
(*mark_debug = "true"*)reg enb1;
wire[135:0] doutaa1;
wire[67:0] douta1;
wire[67:0] douta2;
wire[67:0] douta3;

(*mark_debug = "true"*)reg ena2;
(*mark_debug = "true"*)reg enb2;
(*mark_debug = "true"*)reg wea2;
wire [135:0] doutbb1;
wire [67:0] doutb1;
wire [67:0] doutb2;
wire [67:0] doutb3;


(*mark_debug = "true"*)reg [9:0] addra1;
(*mark_debug = "true"*)reg [9:0] addra2;

reg [9:0] fco_cnt;
reg [3:0] read_rram_finish_cnt;

reg sim_row_st;
assign test_det_row = sim_row_st;

reg [9:0] sim_row_st_cnt;
reg [1:0] sim_row_st_sample;
/////test

reg first_addr_tap;
reg ram_state;

reg first_read_tag;

reg sample_finish_flag;
reg rama_sample_finish;
reg ramb_sample_finish;
reg rd_ramA;
reg [9:0] cnt_row;

(*mark_debug = "true"*)reg [127:0] kb_data_temp;
(*mark_debug = "true"*)reg [7:0] two_point_sig_a;
reg two_point_start;
reg [9:0] row_num;
reg fifo_ddr_done_a;
//read data delay
reg  [9:0] data_delay_cnt;
wire [63:0] din_fifo;
wire [63:0] dout_fifo;
assign din_fifo = {I_dataA1,I_dataB1,I_dataC1,I_dataD1};
assign O_two_point_start = two_point_start;

wire [135:0] sample_last_data;
wire [67:0] sample_data1;
wire [67:0] sample_data2;
wire [67:0] sample_data3;
// assign dout_fifo = din_fifo;
// wire [63:0] dout_fifo;
//////////////////////////
//跨时钟域处理
// fifo_generator_0 U_adc_to_sample (
//  .wr_clk(fco),            // input wire wr_clk fco
//  .rd_clk(I_clk),            // input wire rd_clk
//  .din(din_fifo),// //input wire [255 : 0] din
//  .wr_en(1'b1),              // input wire wr_en
//  .rd_en(1'b1),              // input wire rd_en
//  .dout(dout_fifo),                // output wire [255 : 0] dout
//  .full(),                // output wire full
//  .empty(empty)
// );
axis_data_fifo_0 U_adc_to_sample (
  .s_axis_aresetn(I_rst),  // input wire s_axis_aresetn
  .s_axis_aclk(fco),        // input wire s_axis_aclk
  .s_axis_tvalid(s_axis_tready),    // input wire s_axis_tvalid
  .s_axis_tready(s_axis_tready),    // output wire s_axis_tready
  .s_axis_tdata(din_fifo),      // input wire [63 : 0] s_axis_tdata
  .m_axis_aclk(I_clk),        // input wire m_axis_aclk
  .m_axis_tvalid(m_axis_tvalid),    // output wire m_axis_tvalid
  .m_axis_tready(m_axis_tvalid),    // input wire m_axis_tready
  .m_axis_tdata(dout_fifo)      // output wire [63 : 0] m_axis_tdata
);
// always @(posedge I_clk or negedge I_rst) begin
//     if(!I_rst) begin
//         dout_fifo <= 0;
//     end
//     else begin
//         if(fco_sample[1:0] == 2'b10) begin
//             dout_fifo<={I_dataC1,I_dataD1,I_dataA1,I_dataB1};//{I_dataG2,I_dataH2,I_dataE2,I_dataF2,I_dataC2,I_dataD2,I_dataA2,I_dataB2,I_dataG1,I_dataH1,I_dataE1,I_dataF1,I_dataC1,I_dataD1,I_dataA1,I_dataB1};//;
//         end
//     end
// end

//////////////////////////
wire [63:0] send_data;
assign O_sample_data = send_data;

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

// 增加打拍寄存器，精确匹配 BRAM 的 1 拍 Latency
reg [9:0] last_line_addr_d1;
// --- 【新增】为手动盲元补偿打拍行号与列号，匹配BRAM输出延迟 ---
reg [15:0] read_row_d1;
reg [9:0]  addr_rd2_d1;
always @(posedge I_cl_clk or negedge I_rst) begin
    if(!I_rst) begin
        last_line_addr_d1 <= 10'd0;
        read_row_d1 <= 16'd0;
        addr_rd2_d1 <= 10'd0;
    end else begin
        last_line_addr_d1 <= last_line_addr;
        read_row_d1 <= I_read_row;
        addr_rd2_d1 <= I_addr_rd2;
    end
end

//save last ram A output 上一行 输出与主数据同一组的8个像素
last_line_dpram U5_1 (
  .clka(I_cl_clk),    // input wire clka
  .ena(enb1),      // input wire ena
  .wea(enb1),      // input wire [0 : 0] wea
  .addra(last_line_addr_d1),  // input wire [7 : 0] addra
  .dina({douta2,douta3}),    // input wire [127 : 0] dina
  .clkb(I_cl_clk),    // input wire clkb
  .enb(enb2),      // input wire enb
  .addrb(last_line_addr),  // input wire [7 : 0] addrb
  .doutb(doutaa1)  // output wire [127 : 0] doutb
);
//主数据 左边4个像素
dpram1 U5_1_1 (
  .clka(I_clk),    // input wire clka
  .ena(ena1),      // input wire ena
  .wea(wea1),      // input wire [0 : 0] wea
  .addra(addra1),  // input wire [6 : 0] addra
  .dina(dina),    // input wire [127 : 0] dina
  .clkb(I_cl_clk),    // input wire clkb
  .enb(enb1),      // input wire enb
  .addrb(I_addr_rd1),  // input wire [7 : 0] addrb
  .doutb(douta1)  // output wire [63 : 0] doutb
);
//主数据 4个像素
dpram1 U5_1_2 (
  .clka(I_clk),    // input wire clka
  .ena(ena1),      // input wire ena
  .wea(wea1),      // input wire [0 : 0] wea
  .addra(addra1),  // input wire [6 : 0] addra
  .dina(dina),    // input wire [127 : 0] dina
  .clkb(I_cl_clk),    // input wire clkb
  .enb(enb1),      // input wire enb
  .addrb(I_addr_rd2),  // input wire [7 : 0] addrb
  .doutb(douta2)  // output wire [63 : 0] doutb
);
//主数据 右边4个像素
dpram1 U5_1_3 (
  .clka(I_clk),    // input wire clka
  .ena(ena1),      // input wire ena
  .wea(wea1),      // input wire [0 : 0] wea
  .addra(addra1),  // input wire [6 : 0] addra
  .dina(dina),    // input wire [127 : 0] dina
  .clkb(I_cl_clk),    // input wire clkb
  .enb(enb1),      // input wire enb
  .addrb(I_addr_rd3),  // input wire [7 : 0] addrb
  .doutb(douta3)  // output wire [63 : 0] doutb
);

//save last ram B output
last_line_dpram U5_2 (
  .clka(I_cl_clk),    // input wire clka
  .ena(enb2),      // input wire ena
  .wea(enb2),      // input wire [0 : 0] wea
  .addra(last_line_addr_d1),  // input wire [7 : 0] addra
  .dina({doutb2,doutb3}),    // input wire [127 : 0] dina
  .clkb(I_cl_clk),    // input wire clkb
  .enb(enb1),      // input wire enb
  .addrb(last_line_addr),  // input wire [7 : 0] addrb
  .doutb(doutbb1)  // output wire [127 : 0] doutb
);
dpram1_1 U5_2_1 (
  .clka(I_clk),    // input wire clka
  .ena(ena2),      // input wire ena
  .wea(wea2),      // input wire [0 : 0] wea
  .addra(addra2),  // input wire [6 : 0] addra
  .dina(dina),    // input wire [127 : 0] dina
  .clkb(I_cl_clk),    // input wire clkb
  .enb(enb2),      // input wire enb
  .addrb(I_addr_rd1),  // input wire [7 : 0] addrb
  .doutb(doutb1)  // output wire [63 : 0] doutb
);
dpram1_1 U5_2_2 (
  .clka(I_clk),    // input wire clka
  .ena(ena2),      // input wire ena
  .wea(wea2),      // input wire [0 : 0] wea
  .addra(addra2),  // input wire [6 : 0] addra
  .dina(dina),    // input wire [127 : 0] dina
  .clkb(I_cl_clk),    // input wire clkb
  .enb(enb2),      // input wire enb
  .addrb(I_addr_rd2),  // input wire [7 : 0] addrb
  .doutb(doutb2)  // output wire [63 : 0] doutb
);
dpram1_1 U5_2_3 (
  .clka(I_clk),    // input wire clka
  .ena(ena2),      // input wire ena
  .wea(wea2),      // input wire [0 : 0] wea
  .addra(addra2),  // input wire [6 : 0] addra
  .dina(dina),    // input wire [127 : 0] dina
  .clkb(I_cl_clk),    // input wire clkb
  .enb(enb2),      // input wire enb
  .addrb(I_addr_rd3),  // input wire [7 : 0] addrb
  .doutb(doutb3)  // output wire [63 : 0] doutb
);

//sim det_row_st signal
//  always @(posedge I_adc_clk ) begin
//      if(!I_rst) begin
//          sim_row_st <= 0;
//          sim_row_st_cnt <= 0;
//      end
//      else begin
//          if(sim_row_st_cnt < 10'd17) begin
//              sim_row_st <= 0;
//              sim_row_st_cnt <= sim_row_st_cnt + 1;
//          end
//          else if(sim_row_st_cnt < 10'd500) begin
//              sim_row_st <= 1;
//              sim_row_st_cnt <= sim_row_st_cnt + 1;
//          end
//          else begin
//              sim_row_st_cnt <= 0;
//          end
//      end
//  end

kx_b kx_b_1 (
  .A(dout_fifo[63:48]),                // input wire [15 : 0] A
  .B(kb_data[119:112]),                // input wire [7 : 0] B
  .C({kb_data[110:96],7'b0}),                // input wire [21 : 0] C
  .SUBTRACT(kb_data[111]),  // input wire SUBTRACT
  .P(tempA_a),                // output wire [22 : 7] P
  .PCOUT()        // output wire [47 : 0] PCOUT
);
kx_b kx_b_2 (
  .A(dout_fifo[47:32]),                // input wire [15 : 0] A
  .B(kb_data[87:80]),                // input wire [7 : 0] B
  .C({kb_data[78:64],7'b0}),                // input wire [21 : 0] C
  .SUBTRACT(kb_data[79]),  // input wire SUBTRACT
  .P(tempB_a),                // output wire [22 : 7] P
  .PCOUT()        // output wire [47 : 0] PCOUT
);
kx_b kx_b_3 (
  .A(dout_fifo[31:16]),                // input wire [15 : 0] A
  .B(kb_data[55:48]),                // input wire [7 : 0] B
  .C({kb_data[46:32],7'b0}),                // input wire [21 : 0] C
  .SUBTRACT(kb_data[47]),  // input wire SUBTRACT
  .P(tempC_a),                // output wire [22 : 7] P
  .PCOUT()        // output wire [47 : 0] PCOUT
);
kx_b kx_b_4 (
  .A(dout_fifo[15:0]),                // input wire [15 : 0] A
  .B(kb_data[23:16]),                // input wire [7 : 0] B
  .C({kb_data[14:0],7'b0}),                // input wire [21 : 0] C
  .SUBTRACT(kb_data[15]),  // input wire SUBTRACT
  .P(tempD_a),                // output wire [22 : 7] P
  .PCOUT()        // output wire [47 : 0] PCOUT
);

//当出现减法时，dsp会输出无符号补码，需要转换格式,并在第16bit添加盲元表示位
// assign tempA = kb_data[111] ? {kb_data[127],(~tempA_a + 1)} : {kb_data[127],tempA_a};
// assign tempB = kb_data[79]  ? {kb_data[95],(~tempB_a + 1)}  : {kb_data[95],tempB_a} ;
// assign tempC = kb_data[47]  ? {kb_data[63],(~tempC_a + 1)}  : {kb_data[63],tempC_a} ;
// assign tempD = kb_data[15]  ? {kb_data[31],(~tempD_a + 1)}  : {kb_data[31],tempD_a} ;
// assign tempE = kb_data[239] ? {kb_data[255],(~tempE_a + 1)} : {kb_data[255],tempE_a};
// assign tempF = kb_data[207] ? {kb_data[223],(~tempF_a + 1)} : {kb_data[223],tempF_a};
// assign tempG = kb_data[175] ? {kb_data[191],(~tempG_a + 1)} : {kb_data[191],tempG_a};
// assign tempH = kb_data[143] ? {kb_data[159],(~tempH_a + 1)} : {kb_data[159],tempH_a};
//注意有符号数 无符号数之间的混合运算，直接使用低15bit取反，容易出现越界数值
assign tempA = kb_data[111] ? (~tempA_a + 1'b1) : tempA_a;
assign tempB = kb_data[79]  ? (~tempB_a + 1'b1) : tempB_a;
assign tempC = kb_data[47]  ? (~tempC_a + 1'b1) : tempC_a;
assign tempD = kb_data[15]  ? (~tempD_a + 1'b1) : tempD_a;
// assign tempE = kb_data[239] ? (~tempE_a + 1'b1) : tempE_a;
// assign tempF = kb_data[207] ? (~tempF_a + 1'b1) : tempF_a;
// assign tempG = kb_data[175] ? (~tempG_a + 1'b1) : tempG_a;
// assign tempH = kb_data[143] ? (~tempH_a + 1'b1) : tempH_a;


// assign tempA = kb_data[127:112];
// assign tempB = kb_data[95:80];
// assign tempC = kb_data[63:48];
// assign tempD = kb_data[31:16];
// assign tempE = kb_data[255:240];
// assign tempF = kb_data[223:208];
// assign tempG = kb_data[191:176];
// assign tempH = kb_data[159:144];

always @(posedge I_clk or negedge I_rst) begin
    if(!I_rst) begin
		rd_finish_sample <= 0;
        fco_sample <= 0;
        row_st_sample <= 0;
        sim_row_st_sample <= 0;
        
		rama_en <= 0;
		ramb_en <= 0;
        // ramc_en <= 0;
		// tempA <= 0;
		// tempB <= 0;
		// tempC <= 0;
		// tempD <= 0;
		// tempE <= 0;
		// tempF <= 0;
		// tempG <= 0;
		// tempH <= 0;
		ram_state <= 0;
		cnt_row <= 0;
        fifo_ddr_done_a <= 0 ;
        two_point_sig_a <= 8'h00;
        
    end

    else begin
		rd_finish_sample[0] <= I_data_rd_finish;          //sample rd_finish signal
		rd_finish_sample[1] <= rd_finish_sample[0];
        fco_sample[0] <= fco;
        fco_sample[1] <= fco_sample[0];
        fco_sample[2] <= fco_sample[1];
        fco_sample[3] <= fco_sample[2];
        fco_sample[4] <= fco_sample[3];
        fco_sample[5] <= fco_sample[4];
        
        row_st_sample[0] <= I_line_vaild;//I_det_row_st
        row_st_sample[1] <= row_st_sample[0];

        // sim_row_st_sample[0] <= sim_row_st;
        // sim_row_st_sample[1] <= sim_row_st_sample[0];

        two_point_sig_a <= two_point_sig;

        fifo_ddr_done_a <= fifo_ddr_done;

        // tempA <= I_dataA;
        // tempB <= I_dataB;
        // tempC <= I_dataC;		
        // tempD <= I_dataD;
        // tempE <= I_dataE;
        // tempF <= I_dataF;
        // tempG <= I_dataG;		
        // tempH <= I_dataH;
        // tempA <= 16'ha;
        // tempB <= I_dataH;
        // tempC <= 16'ha;		
        // tempD <=  16'ha;
        // tempE <=  16'ha;
        // tempF <=  16'ha;
        // tempG <=  16'ha;		
        // tempH <=  16'ha;
        // dout_fifo <= din_fifo;


        
        if(row_st_sample[1:0] == 2'b01) begin //the first data coming soon  sim_row_st_sample
            cnt_row <= cnt_row + 1'b1;
            if(cnt_row > 0) begin
                if(ram_state == 0 ) begin
                    rama_en <= 1;
                    ram_state <= ram_state + 1;
                end
                else begin
                    ramb_en <= 1;
                    ram_state <= 0;
                end
                if(cnt_row == 10'd512) begin
                    cnt_row <= 0;
                    
                end
            end
        end

        if(rama_en) rama_en <= 0;
        if(ramb_en) ramb_en <= 0;
    end
end

//assign O_sample_data = rd_ramA? douta:doutb;    //select which ram to read from

always@(posedge I_clk or negedge I_rst) begin
    if(!I_rst) begin
        rama_sample_fsm <= 0;
		// half_en <= 0;
		ena1 <= 0;
        enb1 <= 0;
		wea1 <= 0;
		addra1 <= 0;
		dina <= 0;

		ramb_sample_fsm <= 0;
		ena2 <= 0;
        enb2 <= 0;
		wea2 <= 0;
		addra2 <= 0;

		
        first_addr_tap <= 0;
		
		sample_finish_flag <= 0;
		rama_sample_finish <= 0;
        ramb_sample_finish <= 0;
        rd_ramA <= 0;
        row_num <= 0;
        data_delay_cnt <= 0;
        O_sample_finish <= 0;

        O_read_ram_addr1 <= 0;
        O_read_ram_addr2 <= 0;
        read_rram_finish1 <= 0;
        read_rram_finish2 <= 0;
        read_rram_finish_cnt <= 0;
        two_point_start <= 0;
        //kb_data_temp <= 128'd0;
    end
    else begin
        //rama
        case (rama_sample_fsm)
            0: begin
                if(rama_en) begin
                    rama_sample_fsm <= 1;
                    first_addr_tap <= 0;
                    data_delay_cnt <= 0;
                end
            end
            1: begin
                    if(fco_sample[1:0] == 2'b01) begin//
                        if(data_delay_cnt == 10'd20) begin//25M 8;
                            data_delay_cnt <= 0;  

                            if(two_point_start) begin
                                rama_sample_fsm <= 3; 
                                // O_read_ram_addr1 <= O_read_ram_addr1 + 1;//dpram有1个clk的延迟  
                            end              
                            else begin
                                rama_sample_fsm <= 2; 
                            end
                        end
                        else begin
                            data_delay_cnt <= data_delay_cnt + 1;
                        end
                end
            end

            2: begin //直接存储
                if(addra1 == 10'd159) begin
                    wea1 <=0;
					ena1 <= 0;
					rama_sample_fsm <= 5;
					addra1 <= 0;
					sample_finish_flag <= 0;
					rama_sample_finish <= 1;
                    enb1 <= 1;
                    rd_ramA <= 1;
                    row_num <= row_num + 1;
                    read_rram_finish_cnt <= 0;
                    O_sample_finish <= 1;
                end
                else begin  
					ena1 <= 1;
                    wea1 <= 1;
                    if(fco_sample[1:0] == 2'b01) begin//
                        rama_sample_fsm <= 4;
                        if(first_addr_tap == 0) begin
                            // dina <= {tempE,tempF,tempG,tempH,tempA,tempB,tempC,tempD};
                            //dina <=dina+256'd1;//sim
                            dina<= {1'b0,dout_fifo[63:48],1'b0,dout_fifo[47:32],1'b0,dout_fifo[31:16],1'b0,dout_fifo[15:0]};
                            //dina <= dout_fifo;
                            first_addr_tap <= 1;
                            
                        end 
                        else begin
                            // dina <= {tempE,tempF,tempG,tempH,tempA,tempB,tempC,tempD};
                            //dina <=dina+256'd1;
                            dina<= {1'b0,dout_fifo[63:48],1'b0,dout_fifo[47:32],1'b0,dout_fifo[31:16],1'b0,dout_fifo[15:0]};
                            //dina <= dout_fifo;
                            addra1 <= addra1 + 1;
                            
                        end
                    end
                end
            end
            3: begin //两点校正后存储进ram
                if(addra1 == 10'd159) begin
                    wea1 <=0;
					ena1 <= 0;
					rama_sample_fsm <= 5;
					addra1 <= 0;
					sample_finish_flag <= 0;
					rama_sample_finish <= 1;
                    enb1 <= 1;
                    rd_ramA <= 1;
                    row_num <= row_num + 1;
                    O_read_ram_addr1 <= 0;
                    read_rram_finish1 <= 1;
                    read_rram_finish_cnt <= 0;
                    O_sample_finish <= 1;
                end
                else begin  
					ena1 <= 1;
                    wea1 <= 1;
                    if(fco_sample[1:0] == 2'b01) begin
                        rama_sample_fsm <= 4;
                        if(O_read_ram_addr1 == 10'd159) begin
                            O_read_ram_addr1 <= O_read_ram_addr1;
                        end
                        else begin
                            O_read_ram_addr1 <= O_read_ram_addr1 + 1;
                        end
                        if(first_addr_tap == 0) begin
                            //dina <= {tempA,tempB,tempC,tempD};
                            dina <= {kb_data[127],tempA,kb_data[95],tempB,kb_data[63],tempC,kb_data[31],tempD};
                            // dina <= {1'b0,tempE,1'b0,tempF,1'b0,tempG,1'b0,tempH,
                            //         1'b0,tempA,1'b0,tempB,1'b0,tempC,1'b0,tempD};
                            first_addr_tap <= 1;  
                        end 
                        else begin
                            // dina <= {1'b0,tempE,1'b0,tempF,1'b0,tempG,1'b0,tempH,
                            //         1'b0,tempA,1'b0,tempB,1'b0,tempC,1'b0,tempD};
                            dina <= {kb_data[127],tempA,kb_data[95],tempB,kb_data[63],tempC,kb_data[31],tempD};
                            //dina <= {tempA,tempB,tempC,tempD};
                            addra1 <= addra1 + 1;  
                        end
                    end
                end
            end
            4: begin
                if(data_delay_cnt == 10'd3) begin
                    //rama_sample_fsm <= 2;
                    data_delay_cnt <= 0;
                    if(two_point_start) begin
                        rama_sample_fsm <= 3; 
                        // O_read_ram_addr1 <= O_read_ram_addr1 + 1;//dpram有1个clk的延迟  
                    end              
                    else begin
                        rama_sample_fsm <= 2; 
                    end
                end
                else begin
                    if(fco_sample[1:0] == 2'b01) begin
                        data_delay_cnt <= data_delay_cnt + 1'b1;
                    end
                end
            end
            5: begin
                if (sample_finish_flag == 1) begin //??sample_finish_flag=1???????????????????
					rama_sample_finish <= 0;
				end 
				else begin
					sample_finish_flag <= 1;
				end
                //read_rram
                if(read_rram_finish1) begin
                    if(read_rram_finish_cnt == 4'd2) begin
                        read_rram_finish1 <= 0;
                    end
                    else begin
                        read_rram_finish_cnt <= read_rram_finish_cnt + 1;
                    end
                end
				if(rd_finish_sample == 2'b01) begin
					rama_sample_fsm <= 0;
					rd_ramA <= 0;
					enb1 <= 0;
                    O_sample_finish <= 0;
				end
            end
            default: begin
                rama_sample_fsm <= 0;
            end

        endcase

        //ramb
        case (ramb_sample_fsm)
            0: begin
                if(ramb_en) begin
                    ramb_sample_fsm <= 1;
                    first_addr_tap <= 0;
                    data_delay_cnt <= 0; 
                end
            end
            1: begin
                if(fco_sample[1:0] == 2'b01) begin//
                    if(data_delay_cnt == 10'd20) begin//25M 8;
                        data_delay_cnt <= 0;  
                        if(two_point_start) begin
                            ramb_sample_fsm <= 3; 
                            // O_read_ram_addr2 <= O_read_ram_addr2 + 1;//dpram有1个clk的延迟   
                        end    
                        else begin  
                            ramb_sample_fsm <= 2; 
                        end                 
                    end
                    else begin
                        data_delay_cnt <= data_delay_cnt + 1;
                    end
                end
            end
            2: begin
                if(addra2 == 10'd159) begin
                    wea2 <=0;
					ena2 <= 0;
					ramb_sample_fsm <= 5;
					addra2<= 0;
                    sample_finish_flag <= 0;
					ramb_sample_finish <= 1;
                    enb2 <= 1;
                    row_num <= row_num + 1;
                    read_rram_finish_cnt <= 0;
                    O_sample_finish <= 1;
				end
                else begin  
                    ena2 <= 1;
					wea2 <= 1;
                    if(fco_sample[1:0] == 2'b01) begin//
                        ramb_sample_fsm <= 4;
                        if(first_addr_tap == 0) begin
                            // dina <= {tempE,tempF,tempG,tempH,tempA,tempB,tempC,tempD};
                            dina <= {1'b0,dout_fifo[63:48],1'b0,dout_fifo[47:32],1'b0,dout_fifo[31:16],1'b0,dout_fifo[15:0]};
                            //dina <= dout_fifo;
                            first_addr_tap <= 1;
                            
                        end 
                        else begin
                            // dina <= {tempE,tempF,tempG,tempH,tempA,tempB,tempC,tempD};
                            dina <= {1'b0,dout_fifo[63:48],1'b0,dout_fifo[47:32],1'b0,dout_fifo[31:16],1'b0,dout_fifo[15:0]};
                            //dina <= dout_fifo;
                            addra2 <= addra2 + 1;
                        end
                    end
                    
                end
            end
            3: begin //两点校正后存储
                if(addra2 == 10'd159) begin
                    wea2 <=0;
					ena2 <= 0;
					ramb_sample_fsm <= 5;
                    ramb_sample_finish <= 1;
					sample_finish_flag <= 0;
					addra2<= 0;
                    enb2 <= 1;
                    row_num <= row_num + 1;
                    O_read_ram_addr2 <= 0;
                    read_rram_finish2 <= 1;
                    read_rram_finish_cnt <= 0;
                    O_sample_finish <= 1;
				end
                else begin  
                    ena2 <= 1;
					wea2 <= 1;
                    if(fco_sample[1:0] == 2'b01) begin
                        ramb_sample_fsm <= 4;
                        if(O_read_ram_addr2 == 10'd159) begin
                            O_read_ram_addr2 <= O_read_ram_addr2;
                        end
                        else begin
                            O_read_ram_addr2 <= O_read_ram_addr2 + 1;
                        end
                        if(first_addr_tap == 0) begin
                            //dina <= {tempA,tempB,tempC,tempD};
                            dina <= {kb_data[127],tempA,kb_data[95],tempB,kb_data[63],tempC,kb_data[31],tempD};
                            // dina <= {1'b0,tempE,1'b0,tempF,1'b0,tempG,1'b0,tempH,
                            //         1'b0,tempA,1'b0,tempB,1'b0,tempC,1'b0,tempD};
                            first_addr_tap <= 1;  
                        end 
                        else begin
                            // dina <= {1'b0,tempE,1'b0,tempF,1'b0,tempG,1'b0,tempH,
                            //         1'b0,tempA,1'b0,tempB,1'b0,tempC,1'b0,tempD};
                            dina <= {kb_data[127],tempA,kb_data[95],tempB,kb_data[63],tempC,kb_data[31],tempD};
                            //dina <= {tempA,tempB,tempC,tempD};
                            addra2 <= addra2 + 1;  
                        end
                    end
                    
                end
            end
            4: begin
                if(data_delay_cnt == 10'd3) begin
                    //ramb_sample_fsm <= 2;
                    data_delay_cnt <= 0;
                    if(two_point_start) begin
                        ramb_sample_fsm <= 3; 
                        // O_read_ram_addr2 <= O_read_ram_addr2 + 1;//dpram有1个clk的延迟   
                    end    
                    else begin  
                        ramb_sample_fsm <= 2; 
                    end
                end
                else begin
                    if(fco_sample[1:0] == 2'b01) begin
                        data_delay_cnt <= data_delay_cnt + 1'b1;
                    end
                end
            end
            5: begin
                if (sample_finish_flag == 1) begin
					ramb_sample_finish <= 0;
				end
				else begin
					sample_finish_flag <= 1;
				end
                //read_rram
                if(read_rram_finish2) begin
                    if(read_rram_finish_cnt == 4'd2) begin
                        read_rram_finish2 <= 0;
                    end
                    else begin
                        read_rram_finish_cnt <= read_rram_finish_cnt + 1;
                    end
                end
                //非均匀校正切换 传输完1帧且kb ddr初始化完成才判断是否切换
                if(row_num == 10'd512 ) begin
                    row_num <= 0;
                    if((fifo_ddr_done_a) && ((two_point_sig_a == 8'h02)||(two_point_sig_a == 8'h04))) begin
                        two_point_start <= 1;
                        //kb_data_temp <= kb_data;
                    end
                    else begin
                        two_point_start <= 0;
                        //kb_data_temp <= 128'd0;
                    end
                end
				if(rd_finish_sample == 2'b01) begin
					enb2 <= 0;
					ramb_sample_fsm <= 0;
                    O_sample_finish <= 0;
				end
            end
            default: begin
                ramb_sample_fsm <= 0;
            end

        endcase

        // if(rama_sample_finish) O_sample_finish <= 1;           //sample_finish use in module data_send
		// if(ramb_sample_finish) O_sample_finish <= 1;
		// if(rd_finish_sample == 2'b01) O_sample_finish <= 0;
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

// =========================================================================
// --- 【修改区块】将单纯的自动补偿替换为：自动补偿基础 + 手动坐标覆盖 ---
// --- 采用与 camlink_send 相同的 case(行号) 组合逻辑结构 ---
// =========================================================================

wire [63:0] auto_compensate_data;
reg  [63:0] manual_compensate_data;

// 1. 保留原本依靠标志位的自动盲元补偿生成底层数据
assign auto_compensate_data = {
    (sample_data2[67] ? ((sample_data1[15:0]>>2) + (sample_data2[49:34]>>2) + (sample_last_data[134:119]>>2) + (sample_last_data[117:102]>>2)) : sample_data2[66:51]),
    (sample_data2[50] ? ((sample_data2[66:51]>>2) + (sample_data2[32:17]>>2) + (sample_last_data[117:102]>>2) + (sample_last_data[100:85]>>2))  : sample_data2[49:34]),
    (sample_data2[33] ? ((sample_data2[49:34]>>2) + (sample_data2[15:0]>>2) + (sample_last_data[100:85]>>2) + (sample_last_data[83:68]>>2)) : sample_data2[32:17]),
    (sample_data2[16] ? ((sample_data2[32:17]>>2) + (sample_data3[66:51]>>2) + (sample_last_data[83:68]>>2) + (sample_last_data[66:51]>>2)) : sample_data2[15:0])
};

// 2. 利用组合逻辑和 case 语句，在特定坐标覆盖掉上述像素
always @(*) begin
    // 【关键】默认先将自动补偿的结果赋给输出变量，避免生成锁存器 (Latch)
    manual_compensate_data = auto_compensate_data; 

    // 仅在非均匀校正开启时，才执行手动盲元补偿逻辑
    if (two_point_start) begin
    // 以打拍对齐后的行号作为 case 的判断条件
        case (read_row_d1)
            16'd3: begin
                // 实例 1: 第3行，第92列 (92/4 = 23，余数0，对应 [15:0])
                if (addr_rd2_d1 == 10'd23) begin
                    // 使用左边加头顶相邻像素求均值
                    manual_compensate_data[15:0] = (auto_compensate_data[31:16] >> 1) + (sample_last_data[83:68] >> 1);
                end
                if (addr_rd2_d1 == 10'd24) begin
                    // 使用左边加头顶相邻像素求均值
                    manual_compensate_data[63:48] = (sample_last_data[134:119] >> 1) + (auto_compensate_data[47:32] >> 1);
                end
                // 如果同一行还有其他盲元，可以继续加 else if
                // else if (addr_rd2_d1 == 10'dXX) begin ... end
            end
            
            
            default: begin
                // 默认情况什么都不做，保持 manual_compensate_data = auto_compensate_data
                manual_compensate_data = auto_compensate_data;
            end
        endcase
    end
end

// 3. 赋值给实际发送线
assign send_data = manual_compensate_data;



//test 
// assign dout_fifo_test = dout_fifo;//din_fifo dout_fifo
// assign ena1_test = ena1;
// assign enb1_test = enb1;
// assign ena2_test = ena2;
// assign enb2_test = enb2;
// assign dina_test = dina;
// assign addra1_test = addra1;
// assign addra2_test = addra2;
// assign tempA_test = tempA;
// assign tempE_test = tempE;
// assign fco_test = fco_sample[1];
endmodule