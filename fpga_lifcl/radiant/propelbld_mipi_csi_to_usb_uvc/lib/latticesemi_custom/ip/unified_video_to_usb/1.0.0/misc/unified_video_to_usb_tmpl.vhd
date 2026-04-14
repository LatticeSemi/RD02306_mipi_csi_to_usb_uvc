component unified_video_to_usb is
    port(
        clk_pll_72m: in std_logic;
        mipi_byte_clk: in std_logic;
        mipi_byte_clk_resetn: in std_logic;
        pixel_clk: in std_logic;
        pixel_clk_reset_n: in std_logic;
        system_reset_n: in std_logic;
        tdata: in std_logic_vector(31 downto 0);
        tuser: in std_logic_vector(1 downto 0);
        tlast: in std_logic;
        tready: out std_logic;
        tvalid: in std_logic;
        yuy2_tp_en: in std_logic;
        risc_v_system_reset_n_72m: in std_logic;
        mem_to_ahbl_32_wr_en_b: in std_logic;
        mem_to_ahbl_32_wr_data_b: in std_logic_vector(31 downto 0);
        mem_to_ahbl_32_addr_b: in std_logic_vector(9 downto 0);
        mem_to_ahbl_32_ben_b: in std_logic_vector(3 downto 0);
        mem_to_ahbl_32_rd_data_b: out std_logic_vector(31 downto 0);
        u23_axim_XMAWADDR: in std_logic_vector(31 downto 0);
        u23_axim_XMAWBURST: in std_logic_vector(1 downto 0);
        u23_axim_XMAWID: in std_logic_vector(7 downto 0);
        u23_axim_XMAWLEN: in std_logic_vector(7 downto 0);
        u23_axim_XMAWPROT: in std_logic_vector(2 downto 0);
        u23_axim_XMAWSIZE: in std_logic_vector(2 downto 0);
        u23_axim_XMAWREADY: out std_logic;
        u23_axim_XMAWVALID: in std_logic;
        u23_axim_XMWDATA: in std_logic_vector(63 downto 0);
        u23_axim_XMWSTRB: in std_logic_vector(7 downto 0);
        u23_axim_XMWLAST: in std_logic;
        u23_axim_XMWREADY: out std_logic;
        u23_axim_XMWVALID: in std_logic;
        u23_axim_XMARADDR: in std_logic_vector(31 downto 0);
        u23_axim_XMARBURST: in std_logic_vector(1 downto 0);
        u23_axim_XMARID: in std_logic_vector(7 downto 0);
        u23_axim_XMARLEN: in std_logic_vector(7 downto 0);
        u23_axim_XMARPROT: in std_logic_vector(2 downto 0);
        u23_axim_XMARSIZE: in std_logic_vector(2 downto 0);
        u23_axim_XMARREADY: out std_logic;
        u23_axim_XMARVALID: in std_logic;
        u23_axim_XMRDATA: out std_logic_vector(63 downto 0);
        u23_axim_XMRID: out std_logic_vector(7 downto 0);
        u23_axim_XMRRESP: out std_logic_vector(1 downto 0);
        u23_axim_XMRLAST: out std_logic;
        u23_axim_XMRREADY: in std_logic;
        u23_axim_XMRVALID: out std_logic;
        u23_axim_XMBID: out std_logic_vector(7 downto 0);
        u23_axim_XMBRESP: out std_logic_vector(1 downto 0);
        u23_axim_XMBREADY: in std_logic;
        u23_axim_XMBVALID: out std_logic;
        ahbl_haddr_i: in std_logic_vector(7 downto 0);
        ahbl_hburst_i: in std_logic_vector(2 downto 0);
        ahbl_hmastlock_i: in std_logic;
        ahbl_hprot_i: in std_logic_vector(3 downto 0);
        ahbl_hready_i: in std_logic;
        ahbl_hsel_i: in std_logic;
        ahbl_hsize_i: in std_logic_vector(2 downto 0);
        ahbl_htrans_i: in std_logic_vector(1 downto 0);
        ahbl_hwdata_i: in std_logic_vector(31 downto 0);
        ahbl_hwrite_i: in std_logic;
        ahbl_hrdata_o: out std_logic_vector(31 downto 0);
        ahbl_hreadyout_o: out std_logic;
        ahbl_hresp_o: out std_logic;
        iebm_ri_irq_o: out std_logic
    );
end component;

__: unified_video_to_usb port map(
    clk_pll_72m=>,
    mipi_byte_clk=>,
    mipi_byte_clk_resetn=>,
    pixel_clk=>,
    pixel_clk_reset_n=>,
    system_reset_n=>,
    tdata=>,
    tuser=>,
    tlast=>,
    tready=>,
    tvalid=>,
    yuy2_tp_en=>,
    risc_v_system_reset_n_72m=>,
    mem_to_ahbl_32_wr_en_b=>,
    mem_to_ahbl_32_wr_data_b=>,
    mem_to_ahbl_32_addr_b=>,
    mem_to_ahbl_32_ben_b=>,
    mem_to_ahbl_32_rd_data_b=>,
    u23_axim_XMAWADDR=>,
    u23_axim_XMAWBURST=>,
    u23_axim_XMAWID=>,
    u23_axim_XMAWLEN=>,
    u23_axim_XMAWPROT=>,
    u23_axim_XMAWSIZE=>,
    u23_axim_XMAWREADY=>,
    u23_axim_XMAWVALID=>,
    u23_axim_XMWDATA=>,
    u23_axim_XMWSTRB=>,
    u23_axim_XMWLAST=>,
    u23_axim_XMWREADY=>,
    u23_axim_XMWVALID=>,
    u23_axim_XMARADDR=>,
    u23_axim_XMARBURST=>,
    u23_axim_XMARID=>,
    u23_axim_XMARLEN=>,
    u23_axim_XMARPROT=>,
    u23_axim_XMARSIZE=>,
    u23_axim_XMARREADY=>,
    u23_axim_XMARVALID=>,
    u23_axim_XMRDATA=>,
    u23_axim_XMRID=>,
    u23_axim_XMRRESP=>,
    u23_axim_XMRLAST=>,
    u23_axim_XMRREADY=>,
    u23_axim_XMRVALID=>,
    u23_axim_XMBID=>,
    u23_axim_XMBRESP=>,
    u23_axim_XMBREADY=>,
    u23_axim_XMBVALID=>,
    ahbl_haddr_i=>,
    ahbl_hburst_i=>,
    ahbl_hmastlock_i=>,
    ahbl_hprot_i=>,
    ahbl_hready_i=>,
    ahbl_hsel_i=>,
    ahbl_hsize_i=>,
    ahbl_htrans_i=>,
    ahbl_hwdata_i=>,
    ahbl_hwrite_i=>,
    ahbl_hrdata_o=>,
    ahbl_hreadyout_o=>,
    ahbl_hresp_o=>,
    iebm_ri_irq_o=>
);
