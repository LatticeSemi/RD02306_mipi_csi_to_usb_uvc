component mipi_csi_rx is
    port(
        clk_p_io: inout std_logic;
        clk_n_io: inout std_logic;
        d_p_io: inout std_logic_vector(1 downto 0);
        d_n_io: inout std_logic_vector(1 downto 0);
        fr_clk_i: in std_logic;
        fr_rst_n_i: in std_logic;
        ref_clk_i: in std_logic;
        ref_rst_n_i: in std_logic;
        byte_clk_o: out std_logic;
        axis_vid_clk_i: in std_logic;
        axis_vid_rst_n_i: in std_logic;
        axis_vid_tready_i: in std_logic;
        axis_vid_tvalid_o: out std_logic;
        axis_vid_tdata_o: out std_logic_vector(31 downto 0);
        axis_vid_tuser_o: out std_logic_vector(1 downto 0);
        axis_vid_tlast_o: out std_logic
    );
end component;

__: mipi_csi_rx port map(
    clk_p_io=>,
    clk_n_io=>,
    d_p_io=>,
    d_n_io=>,
    fr_clk_i=>,
    fr_rst_n_i=>,
    ref_clk_i=>,
    ref_rst_n_i=>,
    byte_clk_o=>,
    axis_vid_clk_i=>,
    axis_vid_rst_n_i=>,
    axis_vid_tready_i=>,
    axis_vid_tvalid_o=>,
    axis_vid_tdata_o=>,
    axis_vid_tuser_o=>,
    axis_vid_tlast_o=>
);
