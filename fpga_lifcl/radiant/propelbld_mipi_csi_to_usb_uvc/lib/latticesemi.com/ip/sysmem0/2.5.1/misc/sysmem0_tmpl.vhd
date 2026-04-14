component sysmem0 is
    port(
        ahbl_hclk_i: in std_logic;
        ahbl_hresetn_i: in std_logic;
        ahbl_s0_hsel_i: in std_logic;
        ahbl_s0_hready_i: in std_logic;
        ahbl_s0_haddr_i: in std_logic_vector(31 downto 0);
        ahbl_s0_hburst_i: in std_logic_vector(2 downto 0);
        ahbl_s0_hsize_i: in std_logic_vector(2 downto 0);
        ahbl_s0_hmastlock_i: in std_logic;
        ahbl_s0_hprot_i: in std_logic_vector(3 downto 0);
        ahbl_s0_htrans_i: in std_logic_vector(1 downto 0);
        ahbl_s0_hwrite_i: in std_logic;
        ahbl_s0_hwdata_i: in std_logic_vector(31 downto 0);
        ahbl_s0_hreadyout_o: out std_logic;
        ahbl_s0_hresp_o: out std_logic;
        ahbl_s0_hrdata_o: out std_logic_vector(31 downto 0);
        ahbl_s1_hsel_i: in std_logic;
        ahbl_s1_hready_i: in std_logic;
        ahbl_s1_haddr_i: in std_logic_vector(31 downto 0);
        ahbl_s1_hburst_i: in std_logic_vector(2 downto 0);
        ahbl_s1_hsize_i: in std_logic_vector(2 downto 0);
        ahbl_s1_hmastlock_i: in std_logic;
        ahbl_s1_hprot_i: in std_logic_vector(3 downto 0);
        ahbl_s1_htrans_i: in std_logic_vector(1 downto 0);
        ahbl_s1_hwrite_i: in std_logic;
        ahbl_s1_hwdata_i: in std_logic_vector(31 downto 0);
        ahbl_s1_hreadyout_o: out std_logic;
        ahbl_s1_hresp_o: out std_logic;
        ahbl_s1_hrdata_o: out std_logic_vector(31 downto 0)
    );
end component;

__: sysmem0 port map(
    ahbl_hclk_i=>,
    ahbl_hresetn_i=>,
    ahbl_s0_hsel_i=>,
    ahbl_s0_hready_i=>,
    ahbl_s0_haddr_i=>,
    ahbl_s0_hburst_i=>,
    ahbl_s0_hsize_i=>,
    ahbl_s0_hmastlock_i=>,
    ahbl_s0_hprot_i=>,
    ahbl_s0_htrans_i=>,
    ahbl_s0_hwrite_i=>,
    ahbl_s0_hwdata_i=>,
    ahbl_s0_hreadyout_o=>,
    ahbl_s0_hresp_o=>,
    ahbl_s0_hrdata_o=>,
    ahbl_s1_hsel_i=>,
    ahbl_s1_hready_i=>,
    ahbl_s1_haddr_i=>,
    ahbl_s1_hburst_i=>,
    ahbl_s1_hsize_i=>,
    ahbl_s1_hmastlock_i=>,
    ahbl_s1_hprot_i=>,
    ahbl_s1_htrans_i=>,
    ahbl_s1_hwrite_i=>,
    ahbl_s1_hwdata_i=>,
    ahbl_s1_hreadyout_o=>,
    ahbl_s1_hresp_o=>,
    ahbl_s1_hrdata_o=>
);
