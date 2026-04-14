component ahbl_to_axilite_bridge is
    port(
        clk: in std_logic;
        reset_n: in std_logic;
        haddr_i: in std_logic_vector(6 downto 0);
        hburst_i: in std_logic_vector(2 downto 0);
        hmastlock_i: in std_logic;
        hprot_i: in std_logic_vector(3 downto 0);
        hready_i: in std_logic;
        hsel_i: in std_logic;
        hsize_i: in std_logic_vector(2 downto 0);
        htrans_i: in std_logic_vector(1 downto 0);
        hwdata_i: in std_logic_vector(31 downto 0);
        hwrite_i: in std_logic;
        hrdata_o: out std_logic_vector(31 downto 0);
        hready_o: out std_logic;
        hresp_o: out std_logic;
        axi4_m_araddr_o: out std_logic_vector(4 downto 0);
        axi4_m_arprot_o: out std_logic_vector(2 downto 0);
        axi4_m_arready_i: in std_logic;
        axi4_m_arvalid_o: out std_logic;
        axi4_m_rready_o: out std_logic;
        axi4_m_rvalid_i: in std_logic;
        axi4_m_rdata_i: in std_logic_vector(31 downto 0);
        axi4_m_rresp_i: in std_logic_vector(1 downto 0);
        axi4_m_awaddr_o: out std_logic_vector(4 downto 0);
        axi4_m_awprot_o: out std_logic_vector(2 downto 0);
        axi4_m_awready_i: in std_logic;
        axi4_m_awvalid_o: out std_logic;
        axi4_m_wdata_o: out std_logic_vector(31 downto 0);
        axi4_m_wstrb_o: out std_logic_vector(3 downto 0);
        axi4_m_wready_i: in std_logic;
        axi4_m_wvalid_o: out std_logic;
        axi4_m_bresp_i: in std_logic_vector(1 downto 0);
        axi4_m_bready_o: out std_logic;
        axi4_m_bvalid_i: in std_logic
    );
end component;

__: ahbl_to_axilite_bridge port map(
    clk=>,
    reset_n=>,
    haddr_i=>,
    hburst_i=>,
    hmastlock_i=>,
    hprot_i=>,
    hready_i=>,
    hsel_i=>,
    hsize_i=>,
    htrans_i=>,
    hwdata_i=>,
    hwrite_i=>,
    hrdata_o=>,
    hready_o=>,
    hresp_o=>,
    axi4_m_araddr_o=>,
    axi4_m_arprot_o=>,
    axi4_m_arready_i=>,
    axi4_m_arvalid_o=>,
    axi4_m_rready_o=>,
    axi4_m_rvalid_i=>,
    axi4_m_rdata_i=>,
    axi4_m_rresp_i=>,
    axi4_m_awaddr_o=>,
    axi4_m_awprot_o=>,
    axi4_m_awready_i=>,
    axi4_m_awvalid_o=>,
    axi4_m_wdata_o=>,
    axi4_m_wstrb_o=>,
    axi4_m_wready_i=>,
    axi4_m_wvalid_o=>,
    axi4_m_bresp_i=>,
    axi4_m_bready_o=>,
    axi4_m_bvalid_i=>
);
