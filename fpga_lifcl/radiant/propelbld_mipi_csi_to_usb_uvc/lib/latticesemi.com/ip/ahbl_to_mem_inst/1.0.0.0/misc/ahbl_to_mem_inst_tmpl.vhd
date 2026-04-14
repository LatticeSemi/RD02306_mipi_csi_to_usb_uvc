component ahbl_to_mem_inst is
    port(
        clk: in std_logic;
        reset_n: in std_logic;
        haddr_i: in std_logic_vector(13 downto 0);
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
        avm_wait_req_i: in std_logic;
        avm_rd_data_valid_pl_i: in std_logic;
        avm_rd_data_i: in std_logic_vector(31 downto 0);
        avm_addr_32_o: out std_logic_vector(11 downto 0);
        avm_wr_req_o: out std_logic;
        avm_rd_req_o: out std_logic;
        avm_wr_data_o: out std_logic_vector(31 downto 0);
        avm_wr_byte_en_o: out std_logic_vector(3 downto 0)
    );
end component;

__: ahbl_to_mem_inst port map(
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
    avm_wait_req_i=>,
    avm_rd_data_valid_pl_i=>,
    avm_rd_data_i=>,
    avm_addr_32_o=>,
    avm_wr_req_o=>,
    avm_rd_req_o=>,
    avm_wr_data_o=>,
    avm_wr_byte_en_o=>
);
