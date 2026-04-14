# Source SDC for Generated Variables
set base_dir [pwd]
set relative_sdc_path "../inst_1/constraints/constraint.sdc"
set full_sdc_path [file join $base_dir $relative_sdc_path]
source $full_sdc_path

# Clock Should Be Constrained on Design Top-Level or Inferred from PLL
if {$PHY_MODE == "HARD_DPHY"} {
    create_clock -name pclk         -period [expr {$pclk_period         / 1.1}] [get_ports pclk]
    create_clock -name mipi_refclk  -period $mipi_refclk_period                 [get_ports mipi_refclk_p]
} else {
    create_clock -name sync_clk     -period $sync_clk_i_period                  [get_ports sync_clk_i]
}
create_clock     -name dphy_clk     -period $dphy_clk_period                    [get_ports clk_p_io]
create_clock     -name clk_fr       -period [expr {$clk_fr_period       / 1.1}] [get_ports clk_fr_i]
create_clock     -name axis_vid_clk -period [expr {$axis_vid_clk_period / 1.1}] [get_ports axis_vid_clk_i]

# Reset Synchronizers
set_false_path -through [get_nets -hierarchical {*lscc_mipi_csi_dsi_rx_top*.reset_fr_n_sync.rstn_sync[0]}]
set_false_path -through [get_nets -hierarchical {*lscc_mipi_csi_dsi_rx_top*.reset_fr_n_w}]
set_false_path -through [get_nets -hierarchical {*lscc_mipi_csi_dsi_rx_top*.axis_vid_rstn_sync.rstn_sync[0]}]
set_false_path -through [get_nets -hierarchical {*lscc_mipi_csi_dsi_rx_top*.axis_vid_rstn_w}]
if {$PHY_MODE == "HARD_DPHY"} {
    set_false_path -through [get_nets -hierarchical {*lscc_mipi_csi_dsi_rx_top*.u_lscc_cdphy_rx_top.*u_lscc_cdphy_rx_hard_top.rst_sync_phy_inst.rstn_sync[0]}]
} else {
    set_false_path -through [get_nets -hierarchical {*lscc_mipi_csi_dsi_rx_top*.sync_rst_sync.rst_sync[0]}]
    set_false_path -through [get_nets -hierarchical {*lscc_mipi_csi_dsi_rx_top*.sync_rst_w}]
    set_false_path -through [get_nets -hierarchical {*lscc_mipi_csi_dsi_rx_top*.u_lscc_cdphy_rx_top.*u_lscc_dphy_rx_soft_top.u_clk_byte_reset_n_sync.rstn_sync[0]}]
}
if {$B2P == "ON"} {
    set_false_path -through [get_nets -hierarchical {*lscc_mipi_csi_dsi_rx_top*.*u_lscc_byte2pixel.lscc_b2p_core.b2p_pixel_reset_sync.rstn_sync[0]}]
    set_false_path -through [get_nets -hierarchical {*lscc_mipi_csi_dsi_rx_top*.*u_lscc_byte2pixel.lscc_b2p_core.b2p_pixel_reset_n}]
}

# Asynchronous Signals
if {$PHY_MODE == "HARD_DPHY"} {
    set_false_path -through [get_nets -hierarchical {*lscc_mipi_csi_dsi_rx_top*.u_lscc_cdphy_rx_top.*u_lscc_cdphy_rx_hard_top.rx_soft_rst_n}]
    set_false_path -through [get_nets -hierarchical {*lscc_mipi_csi_dsi_rx_top*.u_lscc_cdphy_rx_top.*u_lscc_cdphy_rx_hard_top.rx_soft_shutdown_n}]
} else {
    set_false_path -through [get_nets -hierarchical {*lscc_mipi_csi_dsi_rx_top*.u_lscc_cdphy_rx_top.*u_lscc_dphy_rx_soft_top.u0_lscc_dphy_rx_io.u0_lscc_dphy_rx_soft.ddr_reset_o}]
    set_false_path -through [get_nets -hierarchical {*lscc_mipi_csi_dsi_rx_top*.u_lscc_cdphy_rx_top.*u_lscc_dphy_rx_soft_top.u0_lscc_dphy_rx_io.u0_lscc_dphy_rx_soft.u_lscc_gddr_sync.cs_gddr_sync[*]}]
	set_false_path -through [get_nets -hierarchical {*lscc_mipi_csi_dsi_rx_top*.u_lscc_cdphy_rx_top.*u_lscc_dphy_rx_soft_top.u0_lscc_dphy_rx_io.pll_lock_i}]
    set_false_path -through [get_nets -hierarchical {*lscc_mipi_csi_dsi_rx_top*.u_lscc_cdphy_rx_top.*u_lscc_dphy_rx_soft_top.u0_rx_global_ctrl.*lp_hs_ctrl*.lp_rx_p_i}]
    set_false_path -through [get_nets -hierarchical {*lscc_mipi_csi_dsi_rx_top*.u_lscc_cdphy_rx_top.*u_lscc_dphy_rx_soft_top.u0_rx_global_ctrl.*lp_hs_ctrl*.lp_rx_n_i}]
    set_false_path -through [get_nets -hierarchical {*lscc_mipi_csi_dsi_rx_top*.u_lscc_cdphy_rx_top.*u_lscc_dphy_rx_soft_top.u0_rx_global_ctrl.*lp_hs_ctrl*.term_en_o}]
    set_false_path -through [get_nets -hierarchical {*lscc_mipi_csi_dsi_rx_top*.u_lscc_cdphy_rx_top.*u_lscc_dphy_rx_soft_top.u0_rx_global_ctrl.*lp_hs_ctrl*.hs_en_o}]
    set_false_path -through [get_nets -hierarchical {*lscc_mipi_csi_dsi_rx_top*.u_lscc_cdphy_rx_top.*u_lscc_dphy_rx_soft_top.u0_word_align.shift_en_d*}]
}
