`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: uart_top_422
// Description: RS422 UART顶层控制模块 (分包重构版)
// 协议:
// 1. 发 0x22+CRC, 等待回复 0xAA(收到) -> 0xBB(擦除完毕)
// 2. 发 0x33 + ID_H + ID_L + 512字节数据 + CRC(低) + CRC(高)
//    若校验正确,回 0xCC 0xCC; 错误回 0xEE 0xEE(需重传该包)
// 3. 所有包写完后, 最终回复 0xDD 0xDD
//////////////////////////////////////////////////////////////////////////////////

module uart_top_422(
    input  CLK,            // 80MHz系统时钟
    input  rst_n,
    input  I_rs422_rx,     // RS422接收
    output O_rs422_tx,     // RS422发送
    output O_tx_en,        // RS422发送使能(DE/RE管脚)

    // 乒乓缓存写接口
    output reg        O_ping_pong_wr_en,
    output reg [8:0]  O_ping_pong_wr_addr,
    output reg [7:0]  O_ping_pong_wr_data,
    output reg        O_wr_bank,

    // 控制接口
    output reg        O_start_erase_req,
    output reg        O_packet_ready_req,
    
    input  I_es_done,      // Flash擦除完成脉冲
    input  I_wr_done       // Flash全部写入完成脉冲
);

wire txclk, rxclk, rx_rdy, tx_busy;
wire [7:0] rx_data;
wire [15:0] crc_out;

reg [7:0] tx_data;
reg get_data, tx_en, send_en, send_rdy;
reg [5:0] send_cnt;
reg [1:0] send_fsm;
reg [31:0] cnt_tx_delay;

reg [1:0] es_done;
reg [1:0] wr_done;

reg [3:0] receive_fsm;
reg [15:0] crc_in;
reg [7:0] crc_data;
reg [7:0] packdata[1:0];

// 包处理相关变量
reg [8:0] pack_byte_cnt;
reg [15:0] pack_id;

assign O_tx_en = ~tx_en;

uart_rx U_1(
    .I_clk(CLK), .I_rst(rst_n), .I_rxclk(rxclk), .I_rx(I_rs422_rx),
    .I_get_data(get_data), .O_rx_data(rx_data), .O_rx_rdy(rx_rdy)
);
uart_tx U_2(
    .I_clk(CLK), .I_rst(rst_n), .I_txclk(txclk),
    .I_tx_data(tx_data), .I_tx_en(send_en), .O_tx(O_rs422_tx), .O_tx_busy(tx_busy)
);
uart_baudrate U_3(.I_clk(CLK), .I_rst(rst_n), .O_txclk(txclk), .O_rxclk(rxclk));

modbusCRC16 U_4(.crcIn(crc_in), .data(crc_data), .crcOut(crc_out));

reg [1:0] rxclk_sample;
reg [1:0] txclk_sample;

always @(posedge CLK) begin
    if (!rst_n) begin
        rxclk_sample <= 0; txclk_sample <= 0;
        es_done <= 0; wr_done <= 0;
    end else begin
        rxclk_sample <= {rxclk_sample[0], rxclk};
        txclk_sample <= {txclk_sample[0], txclk};
        es_done <= {es_done[0], I_es_done};
        wr_done <= {wr_done[0], I_wr_done};
    end
end

// ========== UART 接收状态机 ==========
always @(posedge CLK) begin
    if(!rst_n) begin
        receive_fsm <= 0;
        crc_in <= 16'hffff; crc_data <= 0;
        packdata[0] <= 0; packdata[1] <= 0;
        send_rdy <= 0; get_data <= 0;
        
        O_ping_pong_wr_en <= 0;
        O_ping_pong_wr_addr <= 0;
        O_ping_pong_wr_data <= 0;
        O_wr_bank <= 0;
        O_start_erase_req <= 0;
        O_packet_ready_req <= 0;
        pack_byte_cnt <= 0;
    end else begin
        if (send_rdy) send_rdy <= 0;
        O_ping_pong_wr_en <= 0; // 默认不写RAM
        
        // 跨域完成后回复 0xBB(擦除完) 和 0xDD(全部写完)
        if(es_done[1] && receive_fsm == 2) begin
            send_rdy <= 1; receive_fsm <= 0;
            packdata[0] <= 8'hbb; packdata[1] <= 8'hbb;
        end
        //将下面这行修改为这样：只要全部写完脉冲到来，就回复 DD
        if (wr_done[1]) begin
            send_rdy <= 1; receive_fsm <= 0;
            packdata[0] <= 8'hdd; packdata[1] <= 8'hdd;
        end
        // if (wr_done[1] && receive_fsm == 6) begin
        //     send_rdy <= 1; receive_fsm <= 0;
        //     packdata[0] <= 8'hdd; packdata[1] <= 8'hdd;
        // end

        if (rxclk_sample == 2'b10) begin 
            if(get_data) get_data <= 0;
            if (rx_rdy) begin
                get_data <= 1;
                case (receive_fsm)
                    0: begin // 等待指令头 0x22 或 0x33
                        if (rx_data == 8'h22) begin // 擦除命令
                            crc_in <= 16'hffff; crc_data <= rx_data;
                            receive_fsm <= 1; 
                        end else if (rx_data == 8'h33) begin // 数据包命令
                            crc_in <= 16'hffff; crc_data <= rx_data;
                            receive_fsm <= 10;
                        end else begin
                            send_rdy <= 1; packdata[0] <= 8'hff; packdata[1] <= 8'hff;
                        end
                    end
                    
                    // --- 0x22 擦除命令CRC校验 ---
                    1: begin // CRC低位
                        if (rx_data == crc_out[7:0]) receive_fsm <= 2;
                        else begin send_rdy <= 1; packdata[0] <= 8'hff; packdata[1] <= 8'hff; receive_fsm <= 0; end
                    end
                    2: begin // CRC高位
                        if (rx_data == crc_out[15:8]) begin
                            O_start_erase_req <= ~O_start_erase_req; // 翻转触发擦除
                            send_rdy <= 1; packdata[0] <= 8'haa; packdata[1] <= 8'haa; // 回复0xAA AA
                            // 保持在状态2等待 es_done
                        end else begin
                            send_rdy <= 1; packdata[0] <= 8'hff; packdata[1] <= 8'hff; receive_fsm <= 0;
                        end
                    end
                    
                    // --- 0x33 分包数据接收 ---
                    10: begin // 包号高位
                        pack_id[15:8] <= rx_data;
                        crc_in <= crc_out; crc_data <= rx_data;
                        receive_fsm <= 11;
                    end
                    11: begin // 包号低位
                        pack_id[7:0] <= rx_data;
                        crc_in <= crc_out; crc_data <= rx_data;
                        pack_byte_cnt <= 0;
                        receive_fsm <= 12;
                    end
                    12: begin // 512字节数据
                        O_ping_pong_wr_en <= 1;
                        O_ping_pong_wr_addr <= pack_byte_cnt;
                        O_ping_pong_wr_data <= rx_data;
                        
                        crc_in <= crc_out; crc_data <= rx_data;
                        
                        if (pack_byte_cnt == 9'd511) receive_fsm <= 13;
                        else pack_byte_cnt <= pack_byte_cnt + 1;
                    end
                    13: begin // 数据包CRC低位
                        if (rx_data == crc_out[7:0]) receive_fsm <= 14;
                        else begin
                            send_rdy <= 1; packdata[0] <= 8'hee; packdata[1] <= 8'hee; // 校验错
                            receive_fsm <= 0; 
                        end
                    end
                    14: begin // 数据包CRC高位
                        if (rx_data == crc_out[15:8]) begin
                            // 校验成功！翻转Bank，通知Flash状态机开始写这包
                            O_wr_bank <= ~O_wr_bank;
                            O_packet_ready_req <= ~O_packet_ready_req; 
                            
                            send_rdy <= 1; packdata[0] <= 8'hcc; packdata[1] <= 8'hcc; 
                            //receive_fsm <= 6; // 等状态6接收最后一包的 wr_done，或者直接回0
                            receive_fsm <= 0;
                        end else begin
                            send_rdy <= 1; packdata[0] <= 8'hee; packdata[1] <= 8'hee; // 校验错
                            receive_fsm <= 0;
                        end
                    end
                    
                    // 6: begin
                    //      receive_fsm <= 0; // 此处只是个中转，如果没有wr_done就立刻回0等下一包
                    // end
                    
                    default: receive_fsm <= 0;
                endcase
            end
        end
    end
end

// ========== UART 发送状态机 (与原版一致) ==========
always @(posedge CLK) begin
    if (!rst_n) begin
        tx_data <= 0; tx_en <= 0; send_cnt <= 0; send_en <= 0;
        send_fsm <= 0; cnt_tx_delay <= 0;
    end else begin
        case (send_fsm)
            0: if (send_rdy) send_fsm <= 1;
            1: begin // 延时防冲突
                if (cnt_tx_delay == 7999) begin // 缩短了一点延时，约100us
                    send_fsm <= 2; tx_en <= 1; cnt_tx_delay <= 0;
                end else cnt_tx_delay <= cnt_tx_delay + 1;
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