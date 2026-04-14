component mipi_csi_rx is
    port(
        sync_clk_i: in std_logic;
        sync_rst_i: in std_logic;
        ready_o: out std_logic;
        clk_fr_i: in std_logic;
        clk_byte_o: out std_logic;
        reset_fr_n_i: in std_logic;
        pll_lock_i: in std_logic;
        clk_p_io: inout std_logic;
        clk_n_io: inout std_logic;
        d_p_io: inout std_logic_vector(1 downto 0);
        d_n_io: inout std_logic_vector(1 downto 0);
        axis_vid_clk_i: in std_logic;
        axis_vid_rstn_i: in std_logic;
        axis_vid_tready_i: in std_logic;
        axis_vid_tvalid_o: out std_logic;
        axis_vid_tdata_o: out std_logic_vector(31 downto 0);
        axis_vid_tuser_o: out std_logic_vector(2 downto 0);
        axis_vid_tlast_o: out std_logic
    );
end component;

__: mipi_csi_rx port map(
    sync_clk_i=>,
    sync_rst_i=>,
    ready_o=>,
    clk_fr_i=>,
    clk_byte_o=>,
    reset_fr_n_i=>,
    pll_lock_i=>,
    clk_p_io=>,
    clk_n_io=>,
    d_p_io=>,
    d_n_io=>,
    axis_vid_clk_i=>,
    axis_vid_rstn_i=>,
    axis_vid_tready_i=>,
    axis_vid_tvalid_o=>,
    axis_vid_tdata_o=>,
    axis_vid_tuser_o=>,
    axis_vid_tlast_o=>
);
