component cpu0 is
    port(
        clk_i: in std_logic;
        rst_n_i: in std_logic;
        system_resetn_o: out std_logic;
        irq3_i: in std_logic_vector(0 to 0);
        irq2_i: in std_logic_vector(0 to 0);
        irq1_i: in std_logic_vector(0 to 0);
        irq0_i: in std_logic_vector(0 to 0);
        timer_irq_o: out std_logic;
        ahbl_m_instr_haddr_o: out std_logic_vector(31 downto 0);
        ahbl_m_instr_hwrite_o: out std_logic;
        ahbl_m_instr_hsize_o: out std_logic_vector(2 downto 0);
        ahbl_m_instr_hburst_o: out std_logic_vector(2 downto 0);
        ahbl_m_instr_hprot_o: out std_logic_vector(3 downto 0);
        ahbl_m_instr_htrans_o: out std_logic_vector(1 downto 0);
        ahbl_m_instr_hmastlock_o: out std_logic;
        ahbl_m_instr_hwdata_o: out std_logic_vector(31 downto 0);
        ahbl_m_instr_hrdata_i: in std_logic_vector(31 downto 0);
        ahbl_m_instr_hready_i: in std_logic;
        ahbl_m_instr_hresp_i: in std_logic;
        ahbl_m_data_haddr_o: out std_logic_vector(31 downto 0);
        ahbl_m_data_hwrite_o: out std_logic;
        ahbl_m_data_hsize_o: out std_logic_vector(2 downto 0);
        ahbl_m_data_hburst_o: out std_logic_vector(2 downto 0);
        ahbl_m_data_hprot_o: out std_logic_vector(3 downto 0);
        ahbl_m_data_htrans_o: out std_logic_vector(1 downto 0);
        ahbl_m_data_hmastlock_o: out std_logic;
        ahbl_m_data_hwdata_o: out std_logic_vector(31 downto 0);
        ahbl_m_data_hrdata_i: in std_logic_vector(31 downto 0);
        ahbl_m_data_hready_i: in std_logic;
        ahbl_m_data_hresp_i: in std_logic
    );
end component;

__: cpu0 port map(
    clk_i=>,
    rst_n_i=>,
    system_resetn_o=>,
    irq3_i=>,
    irq2_i=>,
    irq1_i=>,
    irq0_i=>,
    timer_irq_o=>,
    ahbl_m_instr_haddr_o=>,
    ahbl_m_instr_hwrite_o=>,
    ahbl_m_instr_hsize_o=>,
    ahbl_m_instr_hburst_o=>,
    ahbl_m_instr_hprot_o=>,
    ahbl_m_instr_htrans_o=>,
    ahbl_m_instr_hmastlock_o=>,
    ahbl_m_instr_hwdata_o=>,
    ahbl_m_instr_hrdata_i=>,
    ahbl_m_instr_hready_i=>,
    ahbl_m_instr_hresp_i=>,
    ahbl_m_data_haddr_o=>,
    ahbl_m_data_hwrite_o=>,
    ahbl_m_data_hsize_o=>,
    ahbl_m_data_hburst_o=>,
    ahbl_m_data_hprot_o=>,
    ahbl_m_data_htrans_o=>,
    ahbl_m_data_hmastlock_o=>,
    ahbl_m_data_hwdata_o=>,
    ahbl_m_data_hrdata_i=>,
    ahbl_m_data_hready_i=>,
    ahbl_m_data_hresp_i=>
);
