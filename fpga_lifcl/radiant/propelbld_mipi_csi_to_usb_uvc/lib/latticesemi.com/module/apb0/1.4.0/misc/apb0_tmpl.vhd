component apb0 is
    port(
        apb_pclk_i: in std_logic;
        apb_presetn_i: in std_logic;
        apb_m03_pready_mstr_i: in std_logic_vector(0 to 0);
        apb_m03_pslverr_mstr_i: in std_logic_vector(0 to 0);
        apb_m03_prdata_mstr_i: in std_logic_vector(31 downto 0);
        apb_m03_psel_mstr_o: out std_logic_vector(0 to 0);
        apb_m03_paddr_mstr_o: out std_logic_vector(31 downto 0);
        apb_m03_pwrite_mstr_o: out std_logic_vector(0 to 0);
        apb_m03_pwdata_mstr_o: out std_logic_vector(31 downto 0);
        apb_m03_penable_mstr_o: out std_logic_vector(0 to 0);
        apb_m02_pready_mstr_i: in std_logic_vector(0 to 0);
        apb_m02_pslverr_mstr_i: in std_logic_vector(0 to 0);
        apb_m02_prdata_mstr_i: in std_logic_vector(31 downto 0);
        apb_m02_psel_mstr_o: out std_logic_vector(0 to 0);
        apb_m02_paddr_mstr_o: out std_logic_vector(31 downto 0);
        apb_m02_pwrite_mstr_o: out std_logic_vector(0 to 0);
        apb_m02_pwdata_mstr_o: out std_logic_vector(31 downto 0);
        apb_m02_penable_mstr_o: out std_logic_vector(0 to 0);
        apb_m01_pready_mstr_i: in std_logic_vector(0 to 0);
        apb_m01_pslverr_mstr_i: in std_logic_vector(0 to 0);
        apb_m01_prdata_mstr_i: in std_logic_vector(31 downto 0);
        apb_m01_psel_mstr_o: out std_logic_vector(0 to 0);
        apb_m01_paddr_mstr_o: out std_logic_vector(31 downto 0);
        apb_m01_pwrite_mstr_o: out std_logic_vector(0 to 0);
        apb_m01_pwdata_mstr_o: out std_logic_vector(31 downto 0);
        apb_m01_penable_mstr_o: out std_logic_vector(0 to 0);
        apb_s00_psel_slv_i: in std_logic_vector(0 to 0);
        apb_s00_paddr_slv_i: in std_logic_vector(31 downto 0);
        apb_s00_pwrite_slv_i: in std_logic_vector(0 to 0);
        apb_s00_pwdata_slv_i: in std_logic_vector(31 downto 0);
        apb_s00_penable_slv_i: in std_logic_vector(0 to 0);
        apb_s00_pready_slv_o: out std_logic_vector(0 to 0);
        apb_s00_pslverr_slv_o: out std_logic_vector(0 to 0);
        apb_s00_prdata_slv_o: out std_logic_vector(31 downto 0);
        apb_m00_pready_mstr_i: in std_logic_vector(0 to 0);
        apb_m00_pslverr_mstr_i: in std_logic_vector(0 to 0);
        apb_m00_prdata_mstr_i: in std_logic_vector(31 downto 0);
        apb_m00_psel_mstr_o: out std_logic_vector(0 to 0);
        apb_m00_paddr_mstr_o: out std_logic_vector(31 downto 0);
        apb_m00_pwrite_mstr_o: out std_logic_vector(0 to 0);
        apb_m00_pwdata_mstr_o: out std_logic_vector(31 downto 0);
        apb_m00_penable_mstr_o: out std_logic_vector(0 to 0)
    );
end component;

__: apb0 port map(
    apb_pclk_i=>,
    apb_presetn_i=>,
    apb_m03_pready_mstr_i=>,
    apb_m03_pslverr_mstr_i=>,
    apb_m03_prdata_mstr_i=>,
    apb_m03_psel_mstr_o=>,
    apb_m03_paddr_mstr_o=>,
    apb_m03_pwrite_mstr_o=>,
    apb_m03_pwdata_mstr_o=>,
    apb_m03_penable_mstr_o=>,
    apb_m02_pready_mstr_i=>,
    apb_m02_pslverr_mstr_i=>,
    apb_m02_prdata_mstr_i=>,
    apb_m02_psel_mstr_o=>,
    apb_m02_paddr_mstr_o=>,
    apb_m02_pwrite_mstr_o=>,
    apb_m02_pwdata_mstr_o=>,
    apb_m02_penable_mstr_o=>,
    apb_m01_pready_mstr_i=>,
    apb_m01_pslverr_mstr_i=>,
    apb_m01_prdata_mstr_i=>,
    apb_m01_psel_mstr_o=>,
    apb_m01_paddr_mstr_o=>,
    apb_m01_pwrite_mstr_o=>,
    apb_m01_pwdata_mstr_o=>,
    apb_m01_penable_mstr_o=>,
    apb_s00_psel_slv_i=>,
    apb_s00_paddr_slv_i=>,
    apb_s00_pwrite_slv_i=>,
    apb_s00_pwdata_slv_i=>,
    apb_s00_penable_slv_i=>,
    apb_s00_pready_slv_o=>,
    apb_s00_pslverr_slv_o=>,
    apb_s00_prdata_slv_o=>,
    apb_m00_pready_mstr_i=>,
    apb_m00_pslverr_mstr_i=>,
    apb_m00_prdata_mstr_i=>,
    apb_m00_psel_mstr_o=>,
    apb_m00_paddr_mstr_o=>,
    apb_m00_pwrite_mstr_o=>,
    apb_m00_pwdata_mstr_o=>,
    apb_m00_penable_mstr_o=>
);
