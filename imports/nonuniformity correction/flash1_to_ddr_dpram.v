`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/11/28 19:30:49
// Design Name: 
// Module Name: flash1_to_ddr_dpram
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


module flash1_to_ddr_dpram(
    input I_clk,
    input rst_n,
    input [7:0] flash1_data,
    input I_shift_sig,
    input write_en,//from flash
    input read_clk,//from ddr
(* MARK_DEBUG="true" *)      input [3:0] wram_rd_addr,
    input I_ddr_finish,
(* MARK_DEBUG="true" *)    output [127:0] O_ddr_data,
    output reg O_fifo_finish,

    //sim
    output [8:0] wr_fifo1_count_test,
    output [8:0] wr_fifo2_count_test,
    output [6:0] rd_fifo1_count_test,
    output [6:0] rd_fifo2_count_test,
    output wr_en1_test,
    output wr_en2_test,
    output rd_en1_test,
    output rd_en2_test,
    output [1:0] write_clk_sample_test
    );
reg wr_en1;
reg wr_en2;
reg rd_en1;
reg rd_en2;
// wire [6:0] rd_fifo1_count;
// (* MARK_DEBUG="true" *) wire [9:0] wr_fifo1_count;
// wire [6:0] rd_fifo2_count;
// (* MARK_DEBUG="true" *) wire [9:0] wr_fifo2_count; 
reg dpram_order;
reg [1:0] shift_sig;
reg [1:0] write_en_sample;
reg [1:0] ddr_finish_sample;

(* MARK_DEBUG="true" *)  reg [8:0] wr_ram_num1;
(* MARK_DEBUG="true" *)  reg [8:0] wr_ram_num2;
reg [2:0] dpram1_state;
reg [2:0] dpram2_state;
reg dpram1_en;
reg dpram2_en;
reg fifo1_finish;
reg fifo2_finish;
reg [3:0] fifo1_finish_cnt;
reg [3:0] fifo2_finish_cnt;
wire [127:0] ddr_data1;
wire [127:0] ddr_data2;
reg isfirst_addr;
reg dout_sel;

assign wr_fifo1_count_test = wr_ram_num1;
// assign wr_fifo2_count_test = wr_fifo2_count;
// assign rd_fifo1_count_test = rd_fifo1_count;
// assign rd_fifo2_count_test = rd_fifo2_count;
assign wr_en1_test = wr_en1;
assign wr_en2_test = wr_en2;
assign rd_en1_test = rd_en1;
assign rd_en2_test = rd_en2;
// assign write_clk_sample_test = write_en_sample;

dpram2 dpram1_1 (
  .clka(I_clk),    // input wire clka
  .ena(wr_en1),      // input wire ena
  .wea(wr_en1),      // input wire [0 : 0] wea
  .addra(wr_ram_num1),  // input wire [6 : 0] addra
  .dina(flash1_data),    // input wire [127 : 0] dina
  .clkb(read_clk),    // input wire clkb
  .enb(rd_en1),      // input wire enb 
  .addrb(wram_rd_addr),  // input wire [6 : 0] addrb
  .doutb(ddr_data1)  // output wire [127 : 0] doutb
);

blk_mem_gen_0 dpram2_1 (
  .clka(I_clk),    // input wire clka
  .ena(wr_en2),      // input wire ena
  .wea(wr_en2),      // input wire [0 : 0] wea
  .addra(wr_ram_num2),  // input wire [6 : 0] addra
  .dina(flash1_data),    // input wire [127 : 0] dina
  .clkb(read_clk),    // input wire clkb
  .enb(rd_en2),      // input wire enb
  .addrb(wram_rd_addr),  // input wire [6 : 0] addrb
  .doutb(ddr_data2)  // output wire [127 : 0] doutb
);
assign O_ddr_data = dout_sel ? ddr_data1 : ddr_data2 ;//choose which fifo to output
//对异步信号打拍处理
always @(posedge I_clk or negedge rst_n) begin
    if(!rst_n) begin
        shift_sig <= 0;
        write_en_sample <= 0;
        ddr_finish_sample <= 0;
        
    end
    else begin
        shift_sig[0] <= I_shift_sig;
        shift_sig[1] <= shift_sig[0];

        write_en_sample[0] <= write_en;
        write_en_sample[1] <= write_en_sample[0];

        ddr_finish_sample[0] <= I_ddr_finish;
        ddr_finish_sample[1] <= ddr_finish_sample[0];

    end
end

//fifo ping-pang ctrl 切换dpram
always @(posedge I_clk or negedge rst_n) begin
    if(!rst_n) begin
        dpram_order <= 0;
        dpram1_en <= 0;
        dpram2_en <= 0;
    end
    else begin
        if(shift_sig == 2'b01 ) begin
            if(!dpram_order) begin
                dpram1_en <= 1;
                dpram_order <= 1;
            end
            else begin 
                dpram2_en <= 1;
                dpram_order <= 0;
            end
        end
        if(dpram1_en) dpram1_en <= 0;
        if(dpram2_en) dpram2_en <= 0;
    end
end

//dpram状态机
always @(posedge I_clk or negedge rst_n) begin
    if(!rst_n) begin
        wr_en1 <= 0;
        wr_en2 <= 0;
        rd_en1 <= 0;
        rd_en2 <= 0;
        dpram1_state <= 0;
        dpram2_state <= 0;
        wr_ram_num1 <= 0;
        wr_ram_num2 <= 0;
        fifo1_finish <= 0;
        fifo2_finish <= 0;
        dout_sel <= 0;
        fifo1_finish_cnt <= 0;
        fifo2_finish_cnt <= 0;
        isfirst_addr <= 1;
    end
    else begin
        //dpram1 ctrl
        case (dpram1_state)
           3'd0 : begin//等待ram启动使能
                if(dpram1_en) begin
                    dpram1_state <= 3'd1;
                    isfirst_addr <= 1;
                end
           end 

           3'd1 : begin//通过写使能计数写入数量
                if(wr_ram_num1 == 9'd255) begin
                    dpram1_state <= 3'd2;
                    wr_en1 <= 0;
                    rd_en1 <= 1;
                    fifo1_finish <= 1;//已完成一页的存储 发送信号给ddr    
                    dout_sel <= 1;  
                    wr_ram_num1 <= 0;
                    isfirst_addr <= 1;
                end
                else begin
                    if(write_en_sample == 2'b01) begin
                        if(isfirst_addr) begin
                            wr_en1 <= 1;
                            wr_ram_num1 <= wr_ram_num1;
                            isfirst_addr <= 0;
                        end
                        else begin
                            wr_en1 <= 1;
                            wr_ram_num1 <= wr_ram_num1 + 1;
                        end
                    end
                    else begin
                        wr_en1 <= 0;
                    end
                end     
           end

           3'd2 : begin//延长ram finish持续时间 方便捕获
                if(fifo1_finish_cnt == 4'd4) begin
                    fifo1_finish <= 0;
                    fifo1_finish_cnt <= 0;
                end
                else begin
                    fifo1_finish_cnt <= fifo1_finish_cnt + 1;
                end

                if(ddr_finish_sample == 2'b01) begin
                    dpram1_state <= 3'd0;
                    rd_en1 <= 0;
                end
           end

            default: begin
                dpram1_state <= 3'd0;
            end
        endcase

        //dpram2 ctrl
        case (dpram2_state)
           3'd0 : begin
                if(dpram2_en) begin
                    dpram2_state <= 3'd1;
                end
           end 

           3'd1 : begin
                if(wr_ram_num2 == 9'd255) begin
                    dpram2_state <= 3'd2;
                    wr_en2 <= 0;
                    rd_en2 <= 1;
                    fifo2_finish <= 1;//已完成一页的存储 发送信号给ddr    
                    dout_sel <= 0;  
                    wr_ram_num2 <= 0;
                    isfirst_addr <= 1;
                end
                else begin
                    if(write_en_sample == 2'b01) begin
                        if(isfirst_addr) begin
                            wr_en2 <= 1;
                            wr_ram_num2 <= wr_ram_num2;
                            isfirst_addr <= 0;
                        end
                        else begin
                            wr_en2 <= 1;
                            wr_ram_num2 <= wr_ram_num2 + 1;
                        end
                    end
                    else begin
                        wr_en2 <= 0;
                    end
                end     
           end

           3'd2 : begin
            if(fifo2_finish_cnt == 4'd4) begin
                fifo2_finish <= 0;
                fifo2_finish_cnt <= 0;
            end
            else begin
                fifo2_finish_cnt <= fifo2_finish_cnt + 1;
            end
                if(ddr_finish_sample == 2'b01) begin
                    dpram2_state <= 3'd0;
                    rd_en2 <= 0;
                end
           end

            default: begin
                dpram2_state <= 3'd0;
            end
        endcase
        //一页数据已写入ram 让ddr来读取
        if(fifo1_finish || fifo2_finish) begin
            O_fifo_finish <= 1;
        end
        else begin
            O_fifo_finish <= 0;
        end
    end
end
endmodule
