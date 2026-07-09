`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: modbusCRC16
// Description: Modbus CRC-16校验模块, 多项式0xA001
// Source: 从kb_pp_done工程移植
//////////////////////////////////////////////////////////////////////////////////

module modbusCRC16 (
    input [15:0] crcIn,
    input [7:0] data,
    output [15:0] crcOut
);
    assign crcOut[0]  = crcIn[0] ^ crcIn[1] ^ crcIn[2] ^ crcIn[3] ^ crcIn[4] ^ crcIn[5] ^ crcIn[6] ^ crcIn[7] ^ crcIn[8] ^ data[0] ^ data[1] ^ data[2] ^ data[3] ^ data[4] ^ data[5] ^ data[6] ^ data[7];
    assign crcOut[1]  = crcIn[9];
    assign crcOut[2]  = crcIn[10];
    assign crcOut[3]  = crcIn[11];
    assign crcOut[4]  = crcIn[12];
    assign crcOut[5]  = crcIn[13];
    assign crcOut[6]  = crcIn[0] ^ crcIn[14] ^ data[0];
    assign crcOut[7]  = crcIn[0] ^ crcIn[1] ^ crcIn[15] ^ data[0] ^ data[1];
    assign crcOut[8]  = crcIn[1] ^ crcIn[2] ^ data[1] ^ data[2];
    assign crcOut[9]  = crcIn[2] ^ crcIn[3] ^ data[2] ^ data[3];
    assign crcOut[10] = crcIn[3] ^ crcIn[4] ^ data[3] ^ data[4];
    assign crcOut[11] = crcIn[4] ^ crcIn[5] ^ data[4] ^ data[5];
    assign crcOut[12] = crcIn[5] ^ crcIn[6] ^ data[5] ^ data[6];
    assign crcOut[13] = crcIn[6] ^ crcIn[7] ^ data[6] ^ data[7];
    assign crcOut[14] = crcIn[0] ^ crcIn[1] ^ crcIn[2] ^ crcIn[3] ^ crcIn[4] ^ crcIn[5] ^ crcIn[6] ^ data[0] ^ data[1] ^ data[2] ^ data[3] ^ data[4] ^ data[5] ^ data[6];
    assign crcOut[15] = crcIn[0] ^ crcIn[1] ^ crcIn[2] ^ crcIn[3] ^ crcIn[4] ^ crcIn[5] ^ crcIn[6] ^ crcIn[7] ^ data[0] ^ data[1] ^ data[2] ^ data[3] ^ data[4] ^ data[5] ^ data[6] ^ data[7];
endmodule
