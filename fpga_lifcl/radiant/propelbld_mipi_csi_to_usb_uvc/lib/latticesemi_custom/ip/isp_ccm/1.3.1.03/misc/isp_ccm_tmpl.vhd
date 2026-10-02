component isp_ccm is
    port(
        axis_rx_clk_i: in std_logic;
        axis_rx_arstn_i: in std_logic;
        axis_tx_clk_i: in std_logic;
        axis_tx_arstn_i: in std_logic;
        rx_tdata_i: in std_logic_vector(47 downto 0);
        rx_tuser_i: in std_logic_vector(1 downto 0);
        rx_tlast_i: in std_logic;
        rx_tvalid_i: in std_logic;
        rx_tready_o: out std_logic;
        tx_tready_i: in std_logic;
        tx_tdata_o: out std_logic_vector(47 downto 0);
        tx_tvalid_o: out std_logic;
        tx_tlast_o: out std_logic;
        tx_tuser_o: out std_logic_vector(1 downto 0);
        axi_lite_clk_i: in std_logic;
        axi_lite_rst_n_i: in std_logic;
        aw_valid_i: in std_logic;
        aw_address_i: in std_logic_vector(4 downto 0);
        aw_ready_o: out std_logic;
        w_valid_i: in std_logic;
        w_data_i: in std_logic_vector(31 downto 0);
        w_strb_i: in std_logic_vector(3 downto 0);
        w_ready_o: out std_logic;
        b_valid_o: out std_logic;
        b_response_o: out std_logic_vector(1 downto 0);
        b_ready_i: in std_logic;
        ar_valid_i: in std_logic;
        ar_address_i: in std_logic_vector(4 downto 0);
        ar_ready_o: out std_logic;
        r_data_o: out std_logic_vector(31 downto 0);
        r_valid_o: out std_logic;
        r_response_o: out std_logic_vector(1 downto 0);
        r_ready_i: in std_logic
    );
end component;

__: isp_ccm port map(
    axis_rx_clk_i=>,
    axis_rx_arstn_i=>,
    axis_tx_clk_i=>,
    axis_tx_arstn_i=>,
    rx_tdata_i=>,
    rx_tuser_i=>,
    rx_tlast_i=>,
    rx_tvalid_i=>,
    rx_tready_o=>,
    tx_tready_i=>,
    tx_tdata_o=>,
    tx_tvalid_o=>,
    tx_tlast_o=>,
    tx_tuser_o=>,
    axi_lite_clk_i=>,
    axi_lite_rst_n_i=>,
    aw_valid_i=>,
    aw_address_i=>,
    aw_ready_o=>,
    w_valid_i=>,
    w_data_i=>,
    w_strb_i=>,
    w_ready_o=>,
    b_valid_o=>,
    b_response_o=>,
    b_ready_i=>,
    ar_valid_i=>,
    ar_address_i=>,
    ar_ready_o=>,
    r_data_o=>,
    r_valid_o=>,
    r_response_o=>,
    r_ready_i=>
);
