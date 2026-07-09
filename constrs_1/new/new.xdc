
set_property IOSTANDARD LVCMOS33 [get_ports I_CLK40M]
set_property PACKAGE_PIN T26 [get_ports I_CLK40M]

set_property IOSTANDARD LVCMOS33 [get_ports led]
set_property PACKAGE_PIN D27 [get_ports led]

set_property IOSTANDARD LVCMOS33 [get_ports button1]
set_property PACKAGE_PIN G23 [get_ports button1]
set_property IOSTANDARD LVCMOS33 [get_ports button2]
set_property PACKAGE_PIN G24 [get_ports button2]
set_property IOSTANDARD LVCMOS33 [get_ports button3]
set_property PACKAGE_PIN B27 [get_ports button3]
set_property IOSTANDARD LVCMOS33 [get_ports button4]
set_property PACKAGE_PIN A27 [get_ports button4]

set_property IOSTANDARD LVCMOS33 [get_ports zk_pps]
set_property PACKAGE_PIN H26 [get_ports zk_pps]
set_property IOSTANDARD LVCMOS33 [get_ports pps_en]
set_property PACKAGE_PIN H27 [get_ports pps_en]

##gtx
set_property PACKAGE_PIN Y2 [get_ports TXP_OUT]
#set_property PACKAGE_PIN V2 [get_ports TXP_OUT1]
set_property PACKAGE_PIN R8 [get_ports Q0_CLK1_GTREFCLK_PAD_P_IN]

#set_property PACKAGE_PIN L15 [get_ports cdcm_ce]
#set_property PACKAGE_PIN L16 [get_ports cdcm_rst]
#set_property PACKAGE_PIN J11 [get_ports hts8502_los]
#set_property PACKAGE_PIN J14 [get_ports hts8502_tdis]
#
#set_property IOSTANDARD LVCMOS33 [get_ports cdcm_ce]
#set_property IOSTANDARD LVCMOS33 [get_ports cdcm_rst]
#set_property IOSTANDARD LVCMOS33 [get_ports hts8502_los]
#set_property IOSTANDARD LVCMOS33 [get_ports hts8502_tdis]

#comm
#set_property PACKAGE_PIN H15 [get_ports trig]
set_property PACKAGE_PIN G27 [get_ports rs422_txd]
set_property PACKAGE_PIN F27 [get_ports rs422_rxd]
set_property PACKAGE_PIN G29 [get_ports rs422_txden]
#set_property IOSTANDARD LVCMOS33 [get_ports trig]
set_property IOSTANDARD LVCMOS33 [get_ports rs422_rxd]
set_property IOSTANDARD LVCMOS33 [get_ports rs422_txd]
set_property IOSTANDARD LVCMOS33 [get_ports rs422_txden]

#det
set_property IOSTANDARD LVCMOS33 [get_ports fpga_det_valid]
set_property IOSTANDARD LVCMOS33 [get_ports fpga_det_error]

set_property IOSTANDARD LVCMOS33 [get_ports fpga_det_int]
set_property IOSTANDARD LVCMOS33 [get_ports det_rst_b]
set_property IOSTANDARD LVCMOS33 [get_ports det_data]
set_property IOSTANDARD LVCMOS33 [get_ports fpga_det_mclk]

set_property PACKAGE_PIN N24 [get_ports fpga_det_valid]
set_property PACKAGE_PIN L28 [get_ports fpga_det_error]

set_property PACKAGE_PIN D17 [get_ports fpga_det_int]
set_property PACKAGE_PIN P23 [get_ports det_rst_b]
set_property PACKAGE_PIN K29 [get_ports det_data]
set_property PACKAGE_PIN D19 [get_ports fpga_det_mclk]

set_property IOSTANDARD LVCMOS33 [get_ports fpga_pwr_ctrl1]
set_property IOSTANDARD LVCMOS33 [get_ports fpga_pwr_ctrl2]
set_property IOSTANDARD LVCMOS33 [get_ports fpga_pwr_ctrl3]
set_property PACKAGE_PIN K28 [get_ports fpga_pwr_ctrl1]
set_property PACKAGE_PIN E19 [get_ports fpga_pwr_ctrl2]
set_property PACKAGE_PIN D18 [get_ports fpga_pwr_ctrl3]

#testpoint
set_property IOSTANDARD LVCMOS33 [get_ports testpoint1]
set_property PACKAGE_PIN H24 [get_ports testpoint1]
set_property IOSTANDARD LVCMOS33 [get_ports testpoint2]
set_property PACKAGE_PIN G28 [get_ports testpoint2]
set_property IOSTANDARD LVCMOS33 [get_ports testpoint3]
set_property PACKAGE_PIN E28 [get_ports testpoint3]
set_property IOSTANDARD LVCMOS33 [get_ports testpoint4]
set_property PACKAGE_PIN C29 [get_ports testpoint4]
set_property IOSTANDARD LVCMOS33 [get_ports testpoint5]
set_property PACKAGE_PIN B29 [get_ports testpoint5]
set_property IOSTANDARD LVCMOS33 [get_ports testpoint6]
set_property PACKAGE_PIN D28 [get_ports testpoint6]

##ad7680
#set_property IOSTANDARD LVCMOS33 [get_ports tempa_sclk]
#set_property IOSTANDARD LVCMOS33 [get_ports tempa_cs]
#set_property IOSTANDARD LVCMOS33 [get_ports tempa_sdata]
#set_property PACKAGE_PIN W24 [get_ports tempa_sclk]
#set_property PACKAGE_PIN V27 [get_ports tempa_cs]
#set_property PACKAGE_PIN W23 [get_ports tempa_sdata]

#flash
set_property PACKAGE_PIN P24 [get_ports flash1_D0]
set_property IOSTANDARD LVCMOS33 [get_ports flash1_D0]
set_property PACKAGE_PIN R25 [get_ports flash1_D1]
set_property IOSTANDARD LVCMOS33 [get_ports flash1_D1]
set_property PACKAGE_PIN U19 [get_ports flash_cs]
set_property IOSTANDARD LVCMOS33 [get_ports flash_cs]
# set_property IOSTANDARD LVCMOS33 [get_ports flash_clk]

#flash
#set_property PACKAGE_PIN P24 [get_ports flash1_D0]
#set_property IOSTANDARD LVCMOS33 [get_ports flash1_D0]
#set_property PACKAGE_PIN R25 [get_ports flash1_D1]
#set_property IOSTANDARD LVCMOS33 [get_ports flash1_D1]
#set_property PACKAGE_PIN R20 [get_ports flash1_D2]
#set_property IOSTANDARD LVCMOS33 [get_ports flash1_D2]
#set_property PACKAGE_PIN R21 [get_ports flash1_D3]
#set_property IOSTANDARD LVCMOS33 [get_ports flash1_D3]
#set_property PACKAGE_PIN U19 [get_ports flash1_cs]
#set_property IOSTANDARD LVCMOS33 [get_ports flash1_cs]
#set_property IOSTANDARD LVCMOS33 [get_ports flash1_clk]

#set_property PACKAGE_PIN F13 [get_ports flash2_D0]
#set_property IOSTANDARD LVCMOS33 [get_ports flash2_D0]
#set_property PACKAGE_PIN G15 [get_ports flash2_D1]
#set_property IOSTANDARD LVCMOS33 [get_ports flash2_D1]
#set_property PACKAGE_PIN G14 [get_ports flash2_D2]
#set_property IOSTANDARD LVCMOS33 [get_ports flash2_D2]
#set_property PACKAGE_PIN D13 [get_ports flash2_D3]
#set_property IOSTANDARD LVCMOS33 [get_ports flash2_D3]
#set_property PACKAGE_PIN K25 [get_ports flash2_cs]
#set_property IOSTANDARD LVCMOS33 [get_ports flash2_cs]
#set_property PACKAGE_PIN D14 [get_ports flash2_clk]
#set_property IOSTANDARD LVCMOS33 [get_ports flash2_clk]



#ADC1
set_property PACKAGE_PIN AH26 [get_ports I_D1A_Data_p]
set_property PACKAGE_PIN AB29 [get_ports {ad0fclk[0]}]
set_property PACKAGE_PIN AJ27 [get_ports I_D0A_Data_p]
set_property PACKAGE_PIN AJ28 [get_ports I_D1B_Data_p]
set_property PACKAGE_PIN AG30 [get_ports I_D0B_Data_p]
set_property PACKAGE_PIN AF26 [get_ports I_D1C_Data_p]
set_property PACKAGE_PIN AE30 [get_ports I_D0C_Data_p]
set_property PACKAGE_PIN Y30 [get_ports I_D1D_Data_p]
set_property PACKAGE_PIN AC29 [get_ports I_D0D_Data_p]
set_property PACKAGE_PIN AE28 [get_ports {ad0dclk[0]}]
set_property PACKAGE_PIN AG29 [get_ports O_adc0_clk_p]

set_property IOSTANDARD LVDS_25 [get_ports I_D1A_Data_p]
set_property IOSTANDARD LVDS_25 [get_ports I_D1A_Data_n]
set_property IOSTANDARD LVDS_25 [get_ports I_D1B_Data_p]
set_property IOSTANDARD LVDS_25 [get_ports I_D1B_Data_n]
set_property IOSTANDARD LVDS_25 [get_ports I_D1C_Data_p]
set_property IOSTANDARD LVDS_25 [get_ports I_D1C_Data_n]
set_property IOSTANDARD LVDS_25 [get_ports I_D1D_Data_p]
set_property IOSTANDARD LVDS_25 [get_ports I_D1D_Data_n]


##




#adc_9253_spi


set_property PACKAGE_PIN AD28 [get_ports ad9253_sclk1]
set_property IOSTANDARD LVCMOS25 [get_ports ad9253_sclk1]

set_property PACKAGE_PIN AB27 [get_ports ad9253_sdio1]
set_property IOSTANDARD LVCMOS25 [get_ports ad9253_sdio1]

set_property PACKAGE_PIN AA28 [get_ports ad9253_csb1]
set_property IOSTANDARD LVCMOS25 [get_ports ad9253_csb1]

set_property PACKAGE_PIN AD27 [get_ports ad9253_sync1]
set_property IOSTANDARD LVCMOS25 [get_ports ad9253_sync1]

set_property PACKAGE_PIN Y28 [get_ports adpdwn]
set_property IOSTANDARD LVCMOS25 [get_ports adpdwn]



#temp
set_property PACKAGE_PIN F28 [get_ports IO_ds18b20_ctrl_dq]
#set_property PACKAGE_PIN T23 [get_ports IO_ds18b20_pwr_dq]
set_property IOSTANDARD LVCMOS33 [get_ports IO_ds18b20_ctrl_dq]
#set_property IOSTANDARD LVCMOS33 [get_ports IO_ds18b20_pwr_dq]

##ad7998 temp
set_property PACKAGE_PIN D16 [get_ports sda]
set_property IOSTANDARD LVCMOS33 [get_ports sda]
set_property PACKAGE_PIN M28 [get_ports scl]
set_property IOSTANDARD LVCMOS33 [get_ports scl]
set_property PACKAGE_PIN M29 [get_ports convst]
set_property IOSTANDARD LVCMOS33 [get_ports convst]
set_property PACKAGE_PIN F20 [get_ports Alt_busy]
set_property IOSTANDARD LVCMOS33 [get_ports Alt_busy]

#spi config
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
#set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 2 [current_design]

#flash
# set_property BITSTREAM.CONFIG.CONFIGRATE 12 [current_design]
# set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
# set_property CONFIG_MODE SPIx4 [current_design]
# set_property BITSTREAM.CONFIG.CONFIGRATE 50 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS true [current_design]

# Logical async groups (by design intent)
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins U0_dcm/inst/mmcm_adv_inst/CLKIN1]] -group [get_clocks -of_objects [get_pins U0_dcm/inst/mmcm_adv_inst/CLKOUT0]]
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins U0_dcm/inst/mmcm_adv_inst/CLKIN1]] -group [get_clocks -of_objects [get_pins U0_dcm/inst/mmcm_adv_inst/CLKOUT2]]
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins U0_dcm/inst/mmcm_adv_inst/CLKIN1]] -group [get_clocks -of_objects [get_pins U0_dcm/inst/mmcm_adv_inst/CLKFBOUT]]
# set_clock_groups -asynchronous -group [get_clocks clk_pll_i] -group [get_clocks user_clk_i]
# set_clock_groups -asynchronous -group [get_clocks clk_80MHz_clk_wiz_0] -group [get_clocks user_clk_i]
# set_clock_groups -asynchronous -group [get_clocks clk_pll_i] -group [get_clocks clk_80MHz_clk_wiz_0]
# set_clock_groups -asynchronous -group [get_clocks clk_80MHz_clk_wiz_0] -group [get_clocks clk_100M_clk_wiz_0]
# set_clock_groups -asynchronous -group [get_clocks user_clk_i] -group [get_clocks clk_100M_clk_wiz_0]
# set_clock_groups -asynchronous -group [get_clocks REFCLK_clk_wiz_0] -group [get_clocks clk_pll_i]

set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins U_nonuniformity_correction/u_ddr3_mig/u_mig_7series_0_mig/u_ddr3_infrastructure/gen_mmcm.mmcm_i/CLKFBOUT]] -group [get_clocks -of_objects [get_pins U6_aurora_64b66b/u_aurora_64b66b_0/inst/clock_module_i/mmcm_adv_inst/CLKOUT0]]
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins U0_dcm/inst/mmcm_adv_inst/CLKOUT0]] -group [get_clocks -of_objects [get_pins U6_aurora_64b66b/u_aurora_64b66b_0/inst/clock_module_i/mmcm_adv_inst/CLKOUT0]]
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins U_nonuniformity_correction/u_ddr3_mig/u_mig_7series_0_mig/u_ddr3_infrastructure/gen_mmcm.mmcm_i/CLKFBOUT]] -group [get_clocks -of_objects [get_pins U0_dcm/inst/mmcm_adv_inst/CLKOUT0]]
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins U0_dcm/inst/mmcm_adv_inst/CLKOUT0]] -group [get_clocks -of_objects [get_pins U0_dcm/inst/mmcm_adv_inst/CLKOUT3]]
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins U6_aurora_64b66b/u_aurora_64b66b_0/inst/clock_module_i/mmcm_adv_inst/CLKOUT0]] -group [get_clocks -of_objects [get_pins U0_dcm/inst/mmcm_adv_inst/CLKOUT3]]
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins U0_dcm/inst/mmcm_adv_inst/CLKFBOUT]] -group [get_clocks -of_objects [get_pins U0_dcm/inst/mmcm_adv_inst/CLKOUT0]]
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins U0_dcm/inst/mmcm_adv_inst/CLKOUT4]] -group [get_clocks -of_objects [get_pins U_nonuniformity_correction/u_ddr3_mig/u_mig_7series_0_mig/u_ddr3_infrastructure/gen_mmcm.mmcm_i/CLKFBOUT]]
# set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins U_nonuniformity_correction/u_ddr3_mig/u_mig_7series_0_mig/u_memc_ui_top_std/mem_intfc0/ddr_phy_top0/u_ddr_mc_phy_wrapper/u_ddr_mc_phy/ddr_phy_4lanes_0.u_ddr_phy_4lanes/ddr_byte_lane_B.ddr_byte_lane_B/phaser_out/OCLK]] -group [get_clocks -of_objects [get_pins U_nonuniformity_correction/u_ddr3_mig/u_mig_7series_0_mig/u_memc_ui_top_std/mem_intfc0/ddr_phy_top0/u_ddr_mc_phy_wrapper/u_ddr_mc_phy/ddr_phy_4lanes_0.u_ddr_phy_4lanes/ddr_byte_lane_B.ddr_byte_lane_B/phaser_out/OCLKDIV]]
# set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins U_nonuniformity_correction/u_ddr3_mig/u_mig_7series_0_mig/u_memc_ui_top_std/mem_intfc0/ddr_phy_top0/u_ddr_mc_phy_wrapper/u_ddr_mc_phy/ddr_phy_4lanes_0.u_ddr_phy_4lanes/ddr_byte_lane_C.ddr_byte_lane_C/phaser_out/OCLK]] -group [get_clocks -of_objects [get_pins U_nonuniformity_correction/u_ddr3_mig/u_mig_7series_0_mig/u_memc_ui_top_std/mem_intfc0/ddr_phy_top0/u_ddr_mc_phy_wrapper/u_ddr_mc_phy/ddr_phy_4lanes_0.u_ddr_phy_4lanes/ddr_byte_lane_C.ddr_byte_lane_C/phaser_out/OCLKDIV]]
# set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins U_nonuniformity_correction/u_ddr3_mig/u_mig_7series_0_mig/u_memc_ui_top_std/mem_intfc0/ddr_phy_top0/u_ddr_mc_phy_wrapper/u_ddr_mc_phy/ddr_phy_4lanes_0.u_ddr_phy_4lanes/ddr_byte_lane_D.ddr_byte_lane_D/phaser_out/OCLK]] -group [get_clocks -of_objects [get_pins U_nonuniformity_correction/u_ddr3_mig/u_mig_7series_0_mig/u_memc_ui_top_std/mem_intfc0/ddr_phy_top0/u_ddr_mc_phy_wrapper/u_ddr_mc_phy/ddr_phy_4lanes_0.u_ddr_phy_4lanes/ddr_byte_lane_D.ddr_byte_lane_D/phaser_out/OCLKDIV]]
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins U0_dcm/inst/mmcm_adv_inst/CLKOUT0]] -group [get_clocks -of_objects [get_pins U0_dcm/inst/mmcm_adv_inst/CLKOUT5]]

#debug




create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 8192 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list U0_dcm/inst/clk_80MHz]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 4 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {U_det/driver_fsm[0]} {U_det/driver_fsm[1]} {U_det/driver_fsm[2]} {U_det/driver_fsm[3]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 3 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {U_det/fsm_detout_rd[0]} {U_det/fsm_detout_rd[1]} {U_det/fsm_detout_rd[2]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 8 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {U_det/trigger[0]} {U_det/trigger[1]} {U_det/trigger[2]} {U_det/trigger[3]} {U_det/trigger[4]} {U_det/trigger[5]} {U_det/trigger[6]} {U_det/trigger[7]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
set_property port_width 1 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list U_time_update/O_pps_ready]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
set_property port_width 1 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list U_det/pps_ready]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
set_property port_width 1 [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list U_time_update/O_time_update_busy]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
set_property port_width 1 [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list U5_aurora_tx/frame_req_latched]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets CLK80M]
