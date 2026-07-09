----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    10:29:12 11/25/2021 
-- Design Name: 
-- Module Name:    det - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity det is
    Port ( I_clk 				: in  STD_LOGIC;
           I_reset_n 		: in  STD_LOGIC;
           MC 					: in  STD_LOGIC;
		   I_dip_sts			: in	std_logic_vector(3 downto 0);
           I_cmd_update 	: in  STD_LOGIC;
           I_gain_num 		: in  STD_LOGIC_VECTOR (7 downto 0);
           I_int_num 		: in  STD_LOGIC_VECTOR (15 downto 0);
           I_freframe_num 	: in  STD_LOGIC_VECTOR (15 downto 0);
           I_driven_en 		: in  STD_LOGIC;
           I_window_place 	: in  STD_LOGIC_VECTOR (31 downto 0);
		   I_image_mode		: in	std_logic;
		   I_power_state_reg	:	in	std_logic_vector(7 downto 0);
		   I_over_current	:	in		std_logic;

		   test1			: out	 std_logic;
		   test2			: out	 std_logic;
		   test3			: out	 std_logic;

		   det_ctrl_step1	: out	 std_logic;
		   det_ctrl_step2	: out	 std_logic;
		   det_ctrl_step3	: out	 std_logic;
		   O_frame_num		: out	 std_logic_vector(31 downto 0);
           O_fpga_fsync	 	: out  STD_LOGIC;
		   O_fpga_lsync	 	: out  STD_LOGIC;
		   O_det_rst_b		: out	 STD_LOGIC;
		   O_det_data		: out	 STD_LOGIC;
           O_fpga_mclk 		: out  STD_LOGIC;
           O_frame_valid_syn : out  STD_LOGIC;
		   O_det_245_oe		: out	 std_logic;
		   O_line_num		: out	std_logic_vector(8 downto 0);
		   O_cam_sta_flag	: out	std_logic;
           O_det_update_end : out  STD_LOGIC
			 );
end det;

architecture Behavioral of det is

type	DET_STATE	is
(DET_IDLE,DET_WAIT,DET_POWER1,DET_POWER2,DET_POWER3,DET_POWER4,DET_IMAGE_NUM,DET_STA,DET_STA_END,DET_STA_END_DELAY,DET_POWER_DOWN1,DET_POWER_DOWN2,DET_POWER_DOWN3);
signal	nxt_det_state		:	DET_STATE;

type	ROW_COL_STATE is
(CNT_IDLE,CNT_STA,CNT_END);
signal	nxt_cnt_state		:	ROW_COL_STATE;

type	WINDOS_SET_STATE	is
(WIN_IDLE,WIN_SER,WIN_DAT);
signal	nxt_win_state		:	WINDOS_SET_STATE;

signal	cnt_frame			:	std_logic_vector(31 downto 0);
signal	cnt_line			:	std_logic_vector(15 downto 0);
signal	cnt_col				:	std_logic_vector(15 downto 0);
signal	mc_clk_sample		:	std_logic_vector(1 downto 0);
signal	datavalid_sample	:	std_logic_vector(1 downto 0);
signal	driven_sample		:	std_logic_vector(1 downto 0);
signal	serclk_sample		:	std_logic_vector(1 downto 0);
signal	int_num_reg,freframe_num_reg		:	integer;
signal	gain_num_reg		:	std_logic_vector(7 downto 0);
signal	flag_rd_finish		:	std_logic;
signal	windos_set_flag	:	std_logic;
signal	windos_param		:	std_logic_vector(31 downto 0);
signal	tmp_N_FRAME,tmp_N_INT	:	std_logic_vector(15 downto 0);
signal	tmp_N_GAIN			:	std_logic_vector(7 downto 0);
signal	tmp_N_WIN			:	std_logic_vector(31 downto 0);
signal	sizea,sizeb			:	std_logic;
signal	det_update_end		:	std_logic;
signal	param_en				:	std_logic;
signal	windos_mode			:	std_logic_vector(7 downto 0);
signal	frame_valid_syn	:	std_logic;
signal	cnt_serdat			:	integer range 0 to 31;
signal	serclr,serdat,serclk		:	std_logic;
signal	int_reg				:	std_logic;
signal	int_reg_sample		:	std_logic_vector(1 downto 0);
signal	datavalid			:	std_logic;
signal	cnt_datavalid		:	std_logic_vector(11 downto 0);
signal	cnt_image			:	std_logic_vector(15 downto 0);
signal	nxt_datavalid_state : std_logic_vector(1 downto 0);
signal	frame_num			:	std_logic_vector(31 downto 0);
signal	cnt_det_ctrl		:	std_logic_vector(31 downto 0);
--signal	det_ctrl_step1,det_ctrl_step2,det_ctrl_step3		:	std_logic;
signal	flag_poweron		:	std_logic;
signal	imro_frame_no		:	std_logic_vector(15 downto 0);
signal	tmp_N_IMRO_NUM		:	std_logic_vector(15 downto 0);
signal	cnt_frame_no		:	std_logic_vector(15 downto 0);
signal	flag_imro_finish	:	std_logic;
signal	tmp_N_IMAGE_MODE	:	std_logic_vector(7 downto 0);
signal	det_mclk,det_fsync,det_lsync				:	std_logic;
signal	cnt_line_no			:	std_logic_vector(15 downto 0);
signal	det_data				:	std_logic;
signal	det_data_func,det_data_windows	:	std_logic_vector(31 downto 0);
signal	N_IMAGE_MODE		:	std_logic_vector(7 downto 0):=X"00";

signal	cnt_line_no_WIN	:	std_logic_vector(15 downto 0);
signal	cnt_line_no_cnt	:	std_logic_vector(15 downto 0);
signal	cnt_line_WIN		:	std_logic_vector(15 downto 0);

constant	N_START				:	std_logic_vector(7 downto 0):=X"02";
constant	DET_DATA_F 			:	std_logic_vector(31 downto 0):= "10001001010010101010000000011100";
constant	DET_DATA_W 			:	std_logic_vector(31 downto 0):= "11000000000000000101000001111111";--"11000000000011000101000001100000";--"11000000000000000101000001100000"; 11000000000000000101000001111111
constant	N_DET_CTRL			:	std_logic_vector(63 downto 0):= X"0000000004C4B400";--���µ�֮������? 1s

constant	MC_PERIOD			:	integer := 167;--5MHZ 200ns
constant	INTNUM_CONVERT			:	integer := 6;--1000/200 = 5 ����ʱ�䵥λus
constant	FRANUM_CONVERT			:	integer := 60;--10000/200 =50 ֡���ڵ�λms

signal	O_gain				:	std_logic;

signal	cam_sta_flag		:	std_logic;

signal	line_num				:	std_logic_vector(8 downto 0);

signal	flag_over_current	:	std_logic;
signal	over_current_sample	:	std_logic_vector(1 downto 0);


begin

O_frame_valid_syn <= frame_valid_syn;
O_det_update_end <= det_update_end;

test1<= det_mclk;
test2<= det_fsync;
test3<= det_lsync;


O_fpga_mclk <= det_mclk;
O_fpga_fsync <= det_fsync;
O_fpga_lsync <= det_lsync;
O_det_data <= det_data;
O_line_num <= line_num;
O_frame_num <= frame_num;
O_cam_sta_flag <= cam_sta_flag;
------------------------------------------------------simulation signal----------------------------------------------------
--process(I_clk,I_reset_n)begin
--	if(I_reset_n = '0')then
--		int_reg_sample <= "00";
--	elsif(rising_edge(I_clk))then
--		int_reg_sample(0) <= int_reg;
--		int_reg_sample(1) <= int_reg_sample(0);
--	end if;
--end process;
--
----process(I_clk,I_reset_n)begin
----	if(I_reset_n = '0')then
----		datavalid <= '0';
----		cnt_datavalid <= X"AAA";
----		cnt_image <= X"0000";
----	elsif(rising_edge(I_clk))then
----		if(int_reg_sample = "10")then
----			cnt_datavalid <= X"000";
----		end if;
----		if(mc_clk_sample = "01")then	
----			if(cnt_datavalid < 19)then
----				cnt_datavalid <= cnt_datavalid + '1';
----			else
----				cnt_datavalid <= X"AAA";
----				if(cnt_image = 20480)then
----					datavalid <= '0';
----				else
----					datavalid <= '1';
----					cnt_image <= cnt_image+ '1';
----				end if;
----			end if;
----		end if;
----		if(cnt_datavalid = X"AAA")then
----			datavalid <= '0';
----		end if;
----	end if;
----end process;
--
--process(I_clk,I_reset_n)begin
--	if(I_reset_n = '0')then
--		nxt_datavalid_state <= "00";
--		datavalid <= '0';
--		cnt_datavalid <= X"000";
--		cnt_image <= X"0000";
--	elsif(rising_edge(I_clk))then
--		case	nxt_datavalid_state	is
--			when	"00"	=>
--				if(int_reg_sample = "10")then
--					nxt_datavalid_state <= "01";
--				end if;
--			when	"01"	=>
--				if(mc_clk_sample = "01")then	
--					if(cnt_datavalid = 19)then
--						cnt_datavalid <= X"000";
--						datavalid <= '1';
--						nxt_datavalid_state <= "10";
--					else
--						cnt_datavalid <= cnt_datavalid + '1';
--					end if;
--				end if;
--			when	"10"	=>
--				if(mc_clk_sample = "01")then
--					if(windos_param(21 downto 14) = X"FF")then
--						if(cnt_image = 20480)then
--							cnt_image <= X"0000";
--							datavalid <= '0';
--							nxt_datavalid_state <= "00";
--						else
--							cnt_image <= cnt_image + '1';
--						end if;
--					elsif(windos_param(21 downto 14) = X"75")then
--						if(cnt_image = 9440)then
--							cnt_image <= X"0000";
--							datavalid <= '0';
--							nxt_datavalid_state <= "00";
--						else
--							cnt_image <= cnt_image + '1';
--						end if;
--					end if;
--				end if;
--			when	others	=>
--				nxt_datavalid_state <= "00";
--				datavalid <= '0';
--				cnt_datavalid <= X"000";
--				cnt_image <= X"0000";
--		end case;
--	end if;
--end process;
------------------------------------------------------------------------------------------------------------------------------------------------------------------						
process(I_clk,I_reset_n)begin
	if(I_reset_n = '0')then
		int_num_reg <= 12000;--94208;--X"00017000";--X"00FA";									--INT 50us
		freframe_num_reg <= 50000;--1388;--50848;--98304;--X"00018000";--X"515E";				--125ms
		gain_num_reg <= X"00";
		det_update_end <= '0';
		windos_param <= "11000000000000000101000001100000";--"11000000000000000101000001111111";û��
--		sizea <= '0';
--		sizeb <= '0';
		tmp_N_FRAME <= X"0000";
		tmp_N_INT <= X"0000";
		tmp_N_GAIN <= X"00";
		tmp_N_WIN <= "11000000000000000101000001100000";--"11000000000000000101000001111111";û��
		tmp_N_IMRO_NUM <= X"FFFF";
		tmp_N_IMAGE_MODE <= X"00";
		cnt_line_no_WIN <= X"0186";--X"0186";--X"0203";
		cnt_line_no_cnt <= X"0187";--X"0187";--X"0204";
		line_num <= "110000011";
	elsif(rising_edge(I_clk))then
		if(I_cmd_update = '1')then
			tmp_N_FRAME <= I_freframe_num;
			tmp_N_INT <= I_int_num;--X"00FA";--I_int_num;
			tmp_N_GAIN <= I_gain_num;
			tmp_N_WIN <= I_window_place;
			det_update_end <= '1';
			param_en <= '1';
		end if;
		windos_param <= tmp_N_WIN;
		if(param_en = '1')then
			if(nxt_det_state = DET_IMAGE_NUM)then   --CNT_IDLE)then--DET_IMAGE_NUM)then--CNT_IDLE)then--DET_IMAGE_NUM)then
				int_num_reg <= conv_integer(tmp_N_INT) * INTNUM_CONVERT; --ת��Ϊ����ʱ���Ӧ̽����ʱ�ӵļ����?
				freframe_num_reg <= conv_integer(tmp_N_FRAME) * FRANUM_CONVERT;--ת��Ϊ֡���ڶ�Ӧ̽����ʱ�ӵļ���ֵ
				gain_num_reg <= tmp_N_GAIN;
--				windos_param <= tmp_N_WIN;
				param_en <= '0';
				det_update_end <= '0';
				-- if(I_image_mode = '1')then--������
					cnt_line_no_WIN <= X"0202";--X"0202";
					cnt_line_no_cnt <= X"0203";--X"0203";				--516= 1data line + 512 + 4
					line_num <= "111111111"; --512
				-- elsif(I_image_mode = '0')then--����
				-- 	cnt_line_no_WIN <= X"0186";--X"0186";
				-- 	cnt_line_no_cnt <= X"0187";--X"0187";				--392
				-- 	line_num <= "110000011";--388
				-- end if;
			end if;
		end if;
	end if;
end process;

--process(I_clk,I_reset_n)begin
--	if(I_reset_n = '0')then
--		O_gain <= '0';
--	elsif(rising_edge(I_clk))then
--		if(gain_num_reg = X"00")then
--			O_gain <= '0';
--		elsif(gain_num_reg = X"01")then
--			O_gain <= '1';
--		end if;
--	end if;
--end process;
			
process(I_clk,I_reset_n)begin
	if(I_reset_n = '0')then
		mc_clk_sample <= "00";
		datavalid_sample <= "00";
		driven_sample <= "00";
		over_current_sample <= "00";
--		serclk_sample <= "00";
	elsif(rising_edge(I_clk))then
		mc_clk_sample(0) <= mc;
		mc_clk_sample(1) <= mc_clk_sample(0);
		
		datavalid_sample(0) <= datavalid;--I_datavalid;
		datavalid_sample(1) <= datavalid_sample(0);
		
		driven_sample(0) <= I_driven_en;
		driven_sample(1) <= driven_sample(0);
		
		over_current_sample(0) <= I_over_current;
		over_current_sample(1) <= over_current_sample(0);
		
--		serclk_sample(0) <= I_serclk;
--		serclk_sample(1) <= serclk_sample(0);
	end if;
end process;

process(I_clk,I_reset_n)begin
	if(I_reset_n = '0')then
		cnt_frame <= X"00000000";
		cnt_col <= X"0000";
		flag_rd_finish <= '0';
		windos_set_flag <= '0';
		int_reg <= '0';
		nxt_det_state	<= DET_IDLE;
		det_ctrl_step1 <= '0';
		det_ctrl_step2 <= '0';
		det_ctrl_step3 <= '0';
		flag_poweron <= '0';
		flag_imro_finish <= '0';
		det_mclk <= '0';
		det_fsync <= '0';
		cnt_det_ctrl <= X"00000000";
		cnt_frame_no <= X"0000";
		imro_frame_no <= X"0000";
		O_det_245_oe <= '0';
		O_det_rst_b <= '0';
		flag_poweron <= '0';
		flag_over_current <= '0';
	elsif(rising_edge(I_clk))then
		O_det_245_oe <= '1';
		cnt_det_ctrl <= cnt_det_ctrl + '1';
		if((I_dip_sts(3) = '1') or (flag_poweron = '0') or ((over_current_sample = "00") and (flag_over_current = '0')))then
			case	nxt_det_state	is
				when	DET_IDLE	=>
					if(driven_sample = "11")then
						cnt_frame <= X"00000000";
						nxt_det_state <= DET_POWER1;
						cnt_det_ctrl <= X"00000000";
						flag_poweron <= '0';
						O_det_rst_b <= '0';--�ϵ����? ̽������λ
					end if;
				when	DET_POWER1	=>
						if(cnt_det_ctrl = N_DET_CTRL)then--�ϵ��ӳ�ʱ�� Ҫ�����?1s �˴�Ϊ1s
		--				if(cnt_det_ctrl = 5)then
							det_ctrl_step1 <= '1';
							cnt_det_ctrl <= X"00000000";
							nxt_det_state <= DET_POWER2;
						end if;
				when	DET_POWER2	=>
						if(cnt_det_ctrl = N_DET_CTRL)then
		--				if(cnt_det_ctrl = 5)then
							det_ctrl_step2 <= '1';
							cnt_det_ctrl <= X"00000000";
							nxt_det_state <= DET_POWER3;
					end if;
				when	DET_POWER3	=>
						if(cnt_det_ctrl = N_DET_CTRL)then
		--				if(cnt_det_ctrl = 5)then
							det_ctrl_step3 <= '1';
							cnt_det_ctrl <= X"00000000";
							nxt_det_state <= DET_POWER4;
					end if;
				when	DET_POWER4	=>
					if(cnt_det_ctrl = N_DET_CTRL)then
						cnt_det_ctrl <= X"00000000";
						nxt_det_state <= DET_IMAGE_NUM;
					elsif(cnt_det_ctrl = conv_integer(N_DET_CTRL)/2)then
						O_det_rst_b <= '1';--�ϵ��������? ��������ʱ����
					end if;
				when	DET_IMAGE_NUM	=>
					flag_poweron <= '1';--��Ч��1
					if(driven_sample = "11")then
						nxt_det_state <= DET_STA;
						if((imro_frame_no = tmp_N_IMRO_NUM) and (tmp_N_IMRO_NUM /= X"FFFF"))then
							cnt_frame_no <= X"0000";
							imro_frame_no <= X"0000";
							flag_imro_finish <= '1';
						else
							if((tmp_N_IMAGE_MODE = X"01") and (flag_imro_finish = '0') and (cnt_frame_no = 3))then
								imro_frame_no <= imro_frame_no + '1';
							elsif(tmp_N_IMAGE_MODE = X"01")then
								imro_frame_no <= X"0001";
							else
								imro_frame_no <= X"0000";
							end if;
						end if;
					else
						cnt_frame_no <= X"0000";
						nxt_det_state <= DET_STA_END_DELAY;--����ʹ����Ч �������״�?
					end if;
				when	DET_STA => --����״̬
					if(mc_clk_sample = "10")then--�½���
						det_mclk <= '0';--����̽����ʱ��
						cnt_frame <= cnt_frame + '1';--֡��ʱ�Ӽ���
						if(cnt_frame = freframe_num_reg - 1)then--һ֡����
							cnt_frame <= X"00000000";
							nxt_det_state <= DET_STA_END;--һ֡����
						elsif(cnt_frame = 32)then
							if(cnt_frame_no < 3)then--ǰ��֡�ǿ�����
								cnt_frame_no <= cnt_frame_no + '1';
							else
								cnt_frame_no <= cnt_frame_no;
							end if;
						elsif((cnt_frame >= 33)and(cnt_frame < 33 + freframe_num_reg  + 26 - int_num_reg))then--����ʱ�䣺fsync�½��ص������غ�ĵ�?26��clk freframe_num��ʾFSYNC������֮��ľ���?
							det_fsync <= '1';
						else
							det_fsync <= '0';--�½���ʱcnt_frame����
						end if;
					elsif(mc_clk_sample = "01")then--������
						det_mclk <= '1';
					end if;
				when	DET_STA_END	=>--һ֡���ݲɼ����?
					nxt_det_state <= DET_IMAGE_NUM;
				when	DET_STA_END_DELAY	=>
					cnt_det_ctrl <= X"00000000";
					O_det_rst_b <= '0';
					nxt_det_state <= DET_POWER_DOWN1;
				when	DET_POWER_DOWN1	=>
					if (cnt_det_ctrl = N_DET_CTRL) then
						det_ctrl_step3 <= '0';--�µ�˳����ϵ�˳����?
						cnt_det_ctrl <= X"00000000";
						nxt_det_state <= DET_POWER_DOWN2;
					end if;
				when	DET_POWER_DOWN2	=>
					if (cnt_det_ctrl = N_DET_CTRL) then
						det_ctrl_step2 <= '0';
						cnt_det_ctrl <= X"00000000";
						nxt_det_state <= DET_POWER_DOWN3;
					end if;
				when	DET_POWER_DOWN3	=>
					if (cnt_det_ctrl = N_DET_CTRL) then
						det_ctrl_step1 <= '0';
						cnt_det_ctrl <= X"00000000";
						nxt_det_state <= DET_IDLE;
					end if;
				when OTHERS	=>
					nxt_det_state <= DET_IDLE;
			end case;
		else
			if(flag_poweron = '1')then
				flag_over_current <= '1';
				det_ctrl_step1 <= '0';
				det_ctrl_step2 <= '0';
				det_ctrl_step3 <= '0';
			end if;
		end if;
	end if;
end process;

process(I_clk,I_reset_n)begin
	if(I_reset_n = '0')then
		det_lsync <= '0';
--		cnt_line_no_WIN <= X"0203";
--		cnt_line_no_cnt <= X"0204";
		cnt_line_no <= X"0000";
		cnt_line <= X"0000";
	elsif(rising_edge(I_clk))then
----		if(nxt_cnt_state = CNT_IDLE)then
--		if(nxt_cnt_state = CNT_IDLE)then--nxt_det_state = DET_IMAGE_NUM)then
----		IF(nxt_det_state = DET_STA_END)then
--			if(I_image_mode = '1')then
--				cnt_line_no_WIN <= X"0202";
--				cnt_line_no_cnt <= X"0203";				--516
--			elsif(I_image_mode = '0')then
--				cnt_line_no_WIN <= X"0186";
--				cnt_line_no_cnt <= X"0187";				--392
--			end if;
--		end if;
		if(mc_clk_sample = "10")then
			if((cnt_frame_no >= 2) and (cnt_line = 91))then
				if(cnt_line_no < cnt_line_no_cnt + '1')then-- ��Ч���� ���������?512+3=515
					cnt_line_no <= cnt_line_no + '1';				--�м���
				end if;
			end if;
			
			if(cnt_frame_no >= 2)then --���������꿪ʼ��
				cnt_line <= cnt_line + '1';--�������ڼ���
				if((cnt_frame = 0) or (cnt_line = 120))then--һ��96��clk
					cnt_line <= X"0000";
				end if;
				if((cnt_line_no >= 0) and (cnt_line_no <= cnt_line_no_cnt))then--516))then  ��ʼ����
					if((cnt_line = 91)and (cnt_frame >=33) and (cnt_frame<=33+freframe_num_reg+26-int_num_reg) )then --92����
						det_lsync <= '1';
					else
						det_lsync <= '0';
					end if;
				else
					det_lsync <= '0';
				end if;
			end if;
		end if;
		if(cnt_frame = 0)then
			cnt_line_no <= X"0000";
		end if;
	end if;
end process;

process(I_clk,I_reset_n)begin
	if(I_reset_n = '0')then
		det_data <= '0';
		det_data_func <= DET_DATA_F;--Ĭ�����������?
		det_data_windows <= DET_DATA_W;--Ĭ�ϴ��ڿ�����
	elsif(rising_edge(I_clk))then
		if(mc_clk_sample = "01")then
			if((cnt_frame >= 1) and (cnt_frame < 33))then --32λ
				--��һ֡FSYNC��ʼǰ���������?
				if (cnt_frame_no = 0)then
					det_data <= det_data_func(31);
					det_data_func<= det_data_func(30 downto 0) & '0';--����
				
				--�ڶ�֡FSYNC��ʼǰ�ʹ��ڿ���
				elsif(cnt_frame_no = 1)then
					det_data <= det_data_windows(31);
					det_data_windows<= det_data_windows(30 downto 0) & '0';
				end if;

			else
				det_data <= '0';--�����ʱ����?
				if(gain_num_reg(3 downto 0) = "0000")then
					if ((N_IMAGE_MODE = X"00") or (flag_imro_finish = '1'))then--N_IMAGE_MODE��ʼ��Ϊ00
						det_data_func <= DET_DATA_F; --10001001010010101010000000011100 ������
					elsif(N_IMAGE_MODE = X"01")then
						det_data_func <= DET_DATA_F or "00000100000000000000000000000000";--��26λ��1 ����imro
					end if;
				elsif(gain_num_reg(3 downto 0) = "0001")then
					if ((N_IMAGE_MODE = X"00") or (flag_imro_finish = '1'))then
						det_data_func <= DET_DATA_F or "00010000000000000000000000000000";--��28λ��1 С���� ������imro
					elsif(N_IMAGE_MODE = X"01")then
						det_data_func <= DET_DATA_F or "00010100000000000000000000000000";--��26��28λ��1 ��������ѡ��imro
					end if;
				else
					det_data_func <= DET_DATA_F;
				end if;
				det_data_windows <= I_window_place;--tmp_N_WIN;--windos_param;--tmp_N_WIN;���´��ڿ�����
			end if;
		end if;
	end if;
end process;

process(I_clk,I_reset_n)begin
	if(I_reset_n = '0')then
		frame_valid_syn <= '0';
		frame_num <= X"00000001";
		nxt_cnt_state <= CNT_IDLE;
		cam_sta_flag <= '0';
	elsif(rising_edge(I_clk))then
		case	nxt_cnt_state	is
			when	CNT_IDLE	=>
				if (driven_sample = "11") then
					nxt_cnt_state <= CNT_STA;
				else
					frame_num <= X"00000001";
				end if;
			when	CNT_STA	=>
				if(mc_clk_sample = "10")then
					if(cnt_frame_no = 3)then
						if(cnt_line_no = 3)then
							if (cnt_line = 2) then
								cam_sta_flag <= '1';--�ڶ�֡�Ժ� ÿ֡�ĵ�����  ����������camlink�����Ч���ر�־��ÿһ֡�Ŀ�ʼ��Ч�����־��
							elsif (cnt_line = 3) then
								cam_sta_flag <= '0';
							end if;
						else
							cam_sta_flag <= '0';
						end if;
						if ((cnt_line_no >= 3) and (cnt_line_no <= cnt_line_no_WIN + '1')) then--��Ч�п�ʼ �����ڱ�Ե����
							if ((cnt_line = 104 ) and (cnt_frame >=33) and (cnt_frame<=33+freframe_num_reg+26-int_num_reg)) then
								frame_valid_syn <= '1';		--����ʹ�� ��ÿ�е�3��clk��ʼ����Ч���أ�   ��ÿһ�е���Ч�����־��?
							elsif(cnt_line = N_START + '1')then
								frame_valid_syn <= '0';
								if(cnt_line_no = cnt_line_no_WIN + '1')then
									nxt_cnt_state <= CNT_END;
								end if;
							end if;
						end if;
						if(cnt_frame = 0) then
							frame_num <= frame_num + '1';--֡��
						end if;
					else
						nxt_cnt_state <= CNT_END;
					end if;
				end if;
			when	CNT_END	=>
				nxt_cnt_state <= CNT_IDLE;
			when others	=>
				nxt_cnt_state <= CNT_IDLE;
		end case;
	end if;
end process;
							

end Behavioral;

