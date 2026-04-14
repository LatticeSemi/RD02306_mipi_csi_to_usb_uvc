component isp_chroma_resampler is
    port(
        clk_i: in std_logic;
        rstn_i: in std_logic;
        rx_tdata_i: in std_logic_vector(47 downto 0);
        rx_tuser_i: in std_logic_vector(1 downto 0);
        rx_tlast_i: in std_logic;
        rx_tvalid_i: in std_logic;
        rx_tready_o: out std_logic;
        tx_tready_i: in std_logic;
        tx_tdata_o: out std_logic_vector(31 downto 0);
        tx_tvalid_o: out std_logic;
        tx_tlast_o: out std_logic;
        tx_tuser_o: out std_logic_vector(1 downto 0)
    );
end component;

__: isp_chroma_resampler port map(
    clk_i=>,
    rstn_i=>,
    rx_tdata_i=>,
    rx_tuser_i=>,
    rx_tlast_i=>,
    rx_tvalid_i=>,
    rx_tready_o=>,
    tx_tready_i=>,
    tx_tdata_o=>,
    tx_tvalid_o=>,
    tx_tlast_o=>,
    tx_tuser_o=>
);
