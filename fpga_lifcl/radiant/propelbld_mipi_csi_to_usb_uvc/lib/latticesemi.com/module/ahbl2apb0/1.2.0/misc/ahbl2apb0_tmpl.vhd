component ahbl2apb0 is
    port(
        clk_i: in std_logic;
        rst_n_i: in std_logic;
        ahbl_hsel_i: in std_logic;
        ahbl_hready_i: in std_logic;
        ahbl_haddr_i: in std_logic_vector(31 downto 0);
        ahbl_hburst_i: in std_logic_vector(2 downto 0);
        ahbl_hsize_i: in std_logic_vector(2 downto 0);
        ahbl_hmastlock_i: in std_logic;
        ahbl_hprot_i: in std_logic_vector(3 downto 0);
        ahbl_htrans_i: in std_logic_vector(1 downto 0);
        ahbl_hwdata_i: in std_logic_vector(31 downto 0);
        ahbl_hwrite_i: in std_logic;
        ahbl_hreadyout_o: out std_logic;
        ahbl_hresp_o: out std_logic;
        ahbl_hrdata_o: out std_logic_vector(31 downto 0);
        apb_pready_i: in std_logic;
        apb_pslverr_i: in std_logic;
        apb_prdata_i: in std_logic_vector(31 downto 0);
        apb_psel_o: out std_logic;
        apb_paddr_o: out std_logic_vector(31 downto 0);
        apb_pwrite_o: out std_logic;
        apb_pwdata_o: out std_logic_vector(31 downto 0);
        apb_penable_o: out std_logic
    );
end component;

__: ahbl2apb0 port map(
    clk_i=>,
    rst_n_i=>,
    ahbl_hsel_i=>,
    ahbl_hready_i=>,
    ahbl_haddr_i=>,
    ahbl_hburst_i=>,
    ahbl_hsize_i=>,
    ahbl_hmastlock_i=>,
    ahbl_hprot_i=>,
    ahbl_htrans_i=>,
    ahbl_hwdata_i=>,
    ahbl_hwrite_i=>,
    ahbl_hreadyout_o=>,
    ahbl_hresp_o=>,
    ahbl_hrdata_o=>,
    apb_pready_i=>,
    apb_pslverr_i=>,
    apb_prdata_i=>,
    apb_psel_o=>,
    apb_paddr_o=>,
    apb_pwrite_o=>,
    apb_pwdata_o=>,
    apb_penable_o=>
);
