`timescale 1ns / 1ps

module uart_top_422(
    input  CLK, rst_n, I_rs422_rx, 
    output O_rs422_tx, O_tx_en,
    output reg        O_ping_pong_wr_en,
    output reg [8:0]  O_ping_pong_wr_addr,
    output reg [7:0]  O_ping_pong_wr_data,
    output reg        O_wr_bank,
    output reg        O_start_erase_req,
    output reg        O_packet_ready_req,
    input  I_es_done, I_wr_done
);

wire txclk, rxclk, rx_rdy, tx_busy;
wire [7:0] rx_data;
reg [7:0] tx_data;
reg get_data, tx_en, send_en, send_rdy;
reg [5:0] send_cnt;
reg [1:0] send_fsm;
reg [31:0] cnt_tx_delay;
reg [1:0] es_done, wr_done;

reg [5:0] receive_fsm; 
reg [7:0] sum; 
(* mark_debug = "true" *)reg [7:0] packdata[1:0];
reg [8:0] pack_byte_cnt;
reg [31:0] pack_id;

reg [7:0] rx_data_d1; // 滑动窗口历史寄存器

reg [31:0] last_pack_id;

assign O_tx_en = ~tx_en;

uart_rx U_1(.I_clk(CLK), .I_rst(rst_n), .I_rxclk(rxclk), .I_rx(I_rs422_rx), .I_get_data(get_data), .O_rx_data(rx_data), .O_rx_rdy(rx_rdy));
uart_tx U_2(.I_clk(CLK), .I_rst(rst_n), .I_txclk(txclk), .I_tx_data(tx_data), .I_tx_en(send_en), .O_tx(O_rs422_tx), .O_tx_busy(tx_busy));
uart_baudrate U_3(.I_clk(CLK), .I_rst(rst_n), .O_txclk(txclk), .O_rxclk(rxclk));

reg [1:0] rxclk_sample, txclk_sample;

always @(posedge CLK) begin
    if (!rst_n) begin
        rxclk_sample <= 0; txclk_sample <= 0; es_done <= 0; wr_done <= 0;
    end else begin
        rxclk_sample <= {rxclk_sample[0], rxclk};
        txclk_sample <= {txclk_sample[0], txclk};
        es_done <= {es_done[0], I_es_done};
        wr_done <= {wr_done[0], I_wr_done};
    end
end

wire es_done_pulse = es_done[0] & ~es_done[1];
wire wr_done_pulse = wr_done[0] & ~wr_done[1];

always @(posedge CLK) begin
    if(!rst_n) begin
        receive_fsm <= 0; sum <= 0; rx_data_d1 <= 0;
        packdata[0] <= 0; packdata[1] <= 0; send_rdy <= 0; get_data <= 0;
        O_ping_pong_wr_en <= 0; O_ping_pong_wr_addr <= 0; O_ping_pong_wr_data <= 0;
        O_wr_bank <= 0; O_start_erase_req <= 0; O_packet_ready_req <= 0; pack_byte_cnt <= 0;
        last_pack_id <= 32'hFFFF_FFFF;
    end else begin
        if (send_rdy) send_rdy <= 0;
        O_ping_pong_wr_en <= 0; 
        
        // 跨域异步脉冲触发回复
        if(es_done_pulse) begin
            send_rdy <= 1; receive_fsm <= 0; packdata[0] <= 8'hbb; packdata[1] <= 8'hbb;
        end
        if (wr_done_pulse) begin
            send_rdy <= 1; receive_fsm <= 0; packdata[0] <= 8'hdd; packdata[1] <= 8'hdd;
        end

        if (rxclk_sample == 2'b10) begin 
            if(get_data) get_data <= 0;
            if (rx_rdy) begin
                get_data <= 1;
                
                rx_data_d1 <= rx_data; 
                
                case (receive_fsm)
                    0: begin 
                        if ({rx_data_d1, rx_data} == 16'h90A5) begin 
                            receive_fsm <= 30; // 导向擦除
                        end 
                        else if ({rx_data_d1, rx_data} == 16'h905A) begin 
                            //注意：这里去掉了旧版包头累加的逻辑
                            receive_fsm <= 11; // 导向数据更新
                        end 
                        else begin
                            receive_fsm <= 0; 
                        end
                    end
                    
                    // ================= 轨道 A：擦除专属分支 (90 A5 已接收) =================
                    30: begin if(rx_data == 8'hFF) receive_fsm <= 31; else receive_fsm <= 0; end 
                    31: begin if(rx_data == 8'h07) receive_fsm <= 32; else receive_fsm <= 0; end 
                    32: begin if(rx_data == 8'h07) receive_fsm <= 33; else receive_fsm <= 0; end 
                    33: begin if(rx_data == 8'h22) receive_fsm <= 34; else receive_fsm <= 0; end 
                    34: begin 
                        if (rx_data == 8'h29) begin
                            O_start_erase_req <= ~O_start_erase_req; 
                            O_wr_bank <= 0; 
                            last_pack_id <= 32'hFFFF_FFFF;
                            send_rdy <= 1; packdata[0] <= 8'haa; packdata[1] <= 8'haa; 
                        end else begin
                            send_rdy <= 1; packdata[0] <= 8'hff; packdata[1] <= 8'hff; 
                        end
                        receive_fsm <= 0;
                    end
                    
                    // ================= 轨道 B：数据包专属分支 (90 5A 已接收) =================
                    //以下状态仅作跳转和赋值，剔除了一切 sum 的累加操作
                    11: begin if(rx_data == 8'hFF) receive_fsm <= 12; else receive_fsm <= 0; end 
                    12: begin if(rx_data == 8'h07) receive_fsm <= 13; else receive_fsm <= 0; end 
                    
                    13: begin pack_id[31:24] <= rx_data; receive_fsm <= 14; end 
                    14: begin pack_id[23:16] <= rx_data; receive_fsm <= 15; end
                    15: begin pack_id[15:8]  <= rx_data; receive_fsm <= 16; end
                    16: begin pack_id[7:0]   <= rx_data; receive_fsm <= 17; end
                    
                    //只有从长度的第一个字节（0x02）开始，才给 sum 寄存器赋值并启动校验计算！
                    17: begin if(rx_data == 8'h02) begin sum <= rx_data; receive_fsm <= 18; end else receive_fsm <= 0; end 
                    18: begin if(rx_data == 8'h0B) begin sum <= sum + rx_data; receive_fsm <= 19; pack_byte_cnt <= 0; end else receive_fsm <= 0; end 
                    
                    19: begin // 512字节负载写入乒乓RAM，并全程参与 sum 累加
                        sum <= sum + rx_data;
                        O_ping_pong_wr_en <= 1;
                        O_ping_pong_wr_addr <= pack_byte_cnt;
                        O_ping_pong_wr_data <= rx_data;
                        if (pack_byte_cnt == 9'd511) receive_fsm <= 20;
                        else pack_byte_cnt <= pack_byte_cnt + 1;
                    end
                    20: begin // 对比这 514 字节的校验和
                        if (rx_data == sum) begin
                            if (pack_id != last_pack_id) begin
                                // 这确实是一个崭新的数据包，正常翻转指针并触发写入
                                O_wr_bank <= ~O_wr_bank;
                                O_start_erase_req <= 1'b0;
                                O_packet_ready_req <= ~O_packet_ready_req; 
                                last_pack_id <= pack_id; // 记录包号，下次再发同一个就不写了
                            end
                            send_rdy <= 1; packdata[0] <= 8'hcc; packdata[1] <= 8'hcc; 
                        end else begin
                            send_rdy <= 1; packdata[0] <= 8'hee; packdata[1] <= 8'hee; 
                        end
                        receive_fsm <= 0;
                    end
                    
                    default: receive_fsm <= 0;
                endcase
            end
        end
    end
end

always @(posedge CLK) begin
    if (!rst_n) begin
        tx_data <= 0; tx_en <= 0; send_cnt <= 0; send_en <= 0; send_fsm <= 0; cnt_tx_delay <= 0;
    end else begin
        case (send_fsm)
            0: if (send_rdy) send_fsm <= 1;
            1: begin
                if (cnt_tx_delay == 7999) begin send_fsm <= 2; tx_en <= 1; cnt_tx_delay <= 0; end 
                else cnt_tx_delay <= cnt_tx_delay + 1;
            end
            2: begin
                if (txclk_sample == 2'b10) begin
                    if (send_cnt < 2) begin
                        if (!tx_busy) begin tx_data <= packdata[send_cnt]; send_cnt <= send_cnt + 1; send_en <= 1; end
                    end else begin
                        if (!tx_busy) begin send_fsm <= 3; send_cnt <= 0; end
                    end
                    if (send_en) send_en <= 0;
                end
            end
            3: begin tx_en <= 0; send_fsm <= 0; end
        endcase
    end
end
endmodule