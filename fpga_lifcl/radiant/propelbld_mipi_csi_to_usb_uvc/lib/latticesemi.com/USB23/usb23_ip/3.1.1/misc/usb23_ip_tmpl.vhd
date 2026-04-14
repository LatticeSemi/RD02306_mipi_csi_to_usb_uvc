component usb23_ip is
    port(
        USBPHY_REFCLK_ALT_i: in std_logic;
        USB_SUSPENDCLK_i: in std_logic;
        REFINCLKEXTP_i: in std_logic;
        REFINCLKEXTM_i: in std_logic;
        XOIN18_i: in std_logic;
        XOOUT18_o: out std_logic;
        USB3_SYSRSTN_i: in std_logic;
        USB_RESETN_i: in std_logic;
        USB2_RESET_i: in std_logic;
        usb23_DP: inout std_logic;
        usb23_DM: inout std_logic;
        RXM_i: in std_logic;
        RXP_i: in std_logic;
        TXM_o: out std_logic;
        TXP_o: out std_logic;
        lmmi_clk_i: in std_logic;
        lmmi_rst_n_i: in std_logic;
        lmmi_request_i: in std_logic;
        lmmi_wr_rdn_i: in std_logic;
        lmmi_offset_i: in std_logic_vector(14 downto 0);
        lmmi_wdata_i: in std_logic_vector(31 downto 0);
        lmmi_rdata_o: out std_logic_vector(31 downto 0);
        lmmi_rdata_valid_o: out std_logic;
        lmmi_ready_o: out std_logic;
        xm_awready_i: in std_logic;
        xm_wready_i: in std_logic;
        xm_bid_i: in std_logic_vector(7 downto 0);
        xm_bvalid_i: in std_logic;
        xm_bresp_i: in std_logic_vector(1 downto 0);
        xm_bmisc_info_i: in std_logic_vector(3 downto 0);
        xm_arready_i: in std_logic;
        xm_rid_i: in std_logic_vector(7 downto 0);
        xm_rvalid_i: in std_logic;
        xm_rlast_i: in std_logic;
        xm_rdata_i: in std_logic_vector(63 downto 0);
        xm_rresp_i: in std_logic_vector(1 downto 0);
        xm_rmisc_info_i: in std_logic_vector(3 downto 0);
        xm_awid_o: out std_logic_vector(7 downto 0);
        xm_awaddr_o: out std_logic_vector(31 downto 0);
        xm_awlen_o: out std_logic_vector(7 downto 0);
        xm_awsize_o: out std_logic_vector(2 downto 0);
        xm_awburst_o: out std_logic_vector(1 downto 0);
        xm_awcache_o: out std_logic_vector(3 downto 0);
        xm_awprot_o: out std_logic_vector(2 downto 0);
        xm_awvalid_o: out std_logic;
        xm_awlock_o: out std_logic_vector(1 downto 0);
        xm_awmisc_info_o: out std_logic_vector(3 downto 0);
        xm_wvalid_o: out std_logic;
        xm_wlast_o: out std_logic;
        xm_wdata_o: out std_logic_vector(63 downto 0);
        xm_wid_o: out std_logic_vector(7 downto 0);
        xm_wstrb_o: out std_logic_vector(7 downto 0);
        xm_bready_o: out std_logic;
        xm_arid_o: out std_logic_vector(7 downto 0);
        xm_arvalid_o: out std_logic;
        xm_araddr_o: out std_logic_vector(31 downto 0);
        xm_arlen_o: out std_logic_vector(7 downto 0);
        xm_arsize_o: out std_logic_vector(2 downto 0);
        xm_arburst_o: out std_logic_vector(1 downto 0);
        xm_arcache_o: out std_logic_vector(3 downto 0);
        xm_arprot_o: out std_logic_vector(2 downto 0);
        xm_armisc_info_o: out std_logic_vector(3 downto 0);
        xm_arlock_o: out std_logic_vector(1 downto 0);
        xm_rready_o: out std_logic;
        interrupt_o: out std_logic;
        VBUS_i: inout std_logic;
        RESEXTUSB2: inout std_logic;
        RESEXTUSB3: inout std_logic;
        USB3_MCUCLK_i: in std_logic
    );
end component;

__: usb23_ip port map(
    USBPHY_REFCLK_ALT_i=>,
    USB_SUSPENDCLK_i=>,
    REFINCLKEXTP_i=>,
    REFINCLKEXTM_i=>,
    XOIN18_i=>,
    XOOUT18_o=>,
    USB3_SYSRSTN_i=>,
    USB_RESETN_i=>,
    USB2_RESET_i=>,
    usb23_DP=>,
    usb23_DM=>,
    RXM_i=>,
    RXP_i=>,
    TXM_o=>,
    TXP_o=>,
    lmmi_clk_i=>,
    lmmi_rst_n_i=>,
    lmmi_request_i=>,
    lmmi_wr_rdn_i=>,
    lmmi_offset_i=>,
    lmmi_wdata_i=>,
    lmmi_rdata_o=>,
    lmmi_rdata_valid_o=>,
    lmmi_ready_o=>,
    xm_awready_i=>,
    xm_wready_i=>,
    xm_bid_i=>,
    xm_bvalid_i=>,
    xm_bresp_i=>,
    xm_bmisc_info_i=>,
    xm_arready_i=>,
    xm_rid_i=>,
    xm_rvalid_i=>,
    xm_rlast_i=>,
    xm_rdata_i=>,
    xm_rresp_i=>,
    xm_rmisc_info_i=>,
    xm_awid_o=>,
    xm_awaddr_o=>,
    xm_awlen_o=>,
    xm_awsize_o=>,
    xm_awburst_o=>,
    xm_awcache_o=>,
    xm_awprot_o=>,
    xm_awvalid_o=>,
    xm_awlock_o=>,
    xm_awmisc_info_o=>,
    xm_wvalid_o=>,
    xm_wlast_o=>,
    xm_wdata_o=>,
    xm_wid_o=>,
    xm_wstrb_o=>,
    xm_bready_o=>,
    xm_arid_o=>,
    xm_arvalid_o=>,
    xm_araddr_o=>,
    xm_arlen_o=>,
    xm_arsize_o=>,
    xm_arburst_o=>,
    xm_arcache_o=>,
    xm_arprot_o=>,
    xm_armisc_info_o=>,
    xm_arlock_o=>,
    xm_rready_o=>,
    interrupt_o=>,
    VBUS_i=>,
    RESEXTUSB2=>,
    RESEXTUSB3=>,
    USB3_MCUCLK_i=>
);
