component ahbl_to_lmmi_inst is
    port(
        ahbl_clk: in std_logic;
        ahbl_reset_n: in std_logic;
        ahbls_c_hburst_i: in std_logic_vector(2 downto 0);
        ahbls_c_hmastlock_i: in std_logic;
        ahbls_c_hprot_i: in std_logic_vector(3 downto 0);
        ahbls_c_hready_i: in std_logic;
        ahbls_c_hsel_i: in std_logic;
        ahbls_c_haddr_i: in std_logic_vector(16 downto 0);
        ahbls_c_hwrite_i: in std_logic;
        ahbls_c_hwdata_i: in std_logic_vector(31 downto 0);
        ahbls_c_hsize_i: in std_logic_vector(2 downto 0);
        ahbls_c_htrans_i: in std_logic_vector(1 downto 0);
        ahbls_c_hrdata_o: out std_logic_vector(31 downto 0);
        ahbls_c_hready_o: out std_logic;
        ahbls_c_hresp_o: out std_logic;
        lm_clk_i: in std_logic;
        lm_reset_n_i: in std_logic;
        lmmi_rdata_i: in std_logic_vector(31 downto 0);
        lmmi_rdata_valid_i: in std_logic;
        lmmi_ready_i: in std_logic;
        lmmi_request_o: out std_logic;
        lmmi_wr_rdn_o: out std_logic;
        lmmi_offset_o: out std_logic_vector(14 downto 0);
        lmmi_wdata_o: out std_logic_vector(31 downto 0)
    );
end component;

__: ahbl_to_lmmi_inst port map(
    ahbl_clk=>,
    ahbl_reset_n=>,
    ahbls_c_hburst_i=>,
    ahbls_c_hmastlock_i=>,
    ahbls_c_hprot_i=>,
    ahbls_c_hready_i=>,
    ahbls_c_hsel_i=>,
    ahbls_c_haddr_i=>,
    ahbls_c_hwrite_i=>,
    ahbls_c_hwdata_i=>,
    ahbls_c_hsize_i=>,
    ahbls_c_htrans_i=>,
    ahbls_c_hrdata_o=>,
    ahbls_c_hready_o=>,
    ahbls_c_hresp_o=>,
    lm_clk_i=>,
    lm_reset_n_i=>,
    lmmi_rdata_i=>,
    lmmi_rdata_valid_i=>,
    lmmi_ready_i=>,
    lmmi_request_o=>,
    lmmi_wr_rdn_o=>,
    lmmi_offset_o=>,
    lmmi_wdata_o=>
);
