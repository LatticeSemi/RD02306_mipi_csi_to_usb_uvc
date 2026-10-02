component unified_interconnect_0 is
    port(
        clk_i: in std_logic;
        resetn_i: in std_logic;
        ahbl_S00_hsel_i: in std_logic_vector(0 to 0);
        ahbl_S00_haddr_i: in std_logic_vector(31 downto 0);
        ahbl_S00_hwrite_i: in std_logic_vector(0 to 0);
        ahbl_S00_hwdata_i: in std_logic_vector(31 downto 0);
        ahbl_S00_hsize_i: in std_logic_vector(2 downto 0);
        ahbl_S00_htrans_i: in std_logic_vector(1 downto 0);
        ahbl_S00_hprot_i: in std_logic_vector(3 downto 0);
        ahbl_S00_hmastlock_i: in std_logic_vector(0 to 0);
        ahbl_S00_hburst_i: in std_logic_vector(2 downto 0);
        ahbl_S00_hready_i: in std_logic_vector(0 to 0);
        ahbl_S00_hreadyout_o: out std_logic_vector(0 to 0);
        ahbl_S00_hrdata_o: out std_logic_vector(31 downto 0);
        ahbl_S00_hresp_o: out std_logic_vector(0 to 0);
        ahbl_M04_hsel_o: out std_logic_vector(0 to 0);
        ahbl_M04_haddr_o: out std_logic_vector(31 downto 0);
        ahbl_M04_hburst_o: out std_logic_vector(2 downto 0);
        ahbl_M04_hsize_o: out std_logic_vector(2 downto 0);
        ahbl_M04_hmastlock_o: out std_logic_vector(0 to 0);
        ahbl_M04_hprot_o: out std_logic_vector(3 downto 0);
        ahbl_M04_htrans_o: out std_logic_vector(1 downto 0);
        ahbl_M04_hwdata_o: out std_logic_vector(31 downto 0);
        ahbl_M04_hwrite_o: out std_logic_vector(0 to 0);
        ahbl_M04_hready_o: out std_logic_vector(0 to 0);
        ahbl_M04_hready_i: in std_logic_vector(0 to 0);
        ahbl_M04_hresp_i: in std_logic_vector(0 to 0);
        ahbl_M04_hrdata_i: in std_logic_vector(31 downto 0);
        ahbl_M03_hsel_o: out std_logic_vector(0 to 0);
        ahbl_M03_haddr_o: out std_logic_vector(31 downto 0);
        ahbl_M03_hburst_o: out std_logic_vector(2 downto 0);
        ahbl_M03_hsize_o: out std_logic_vector(2 downto 0);
        ahbl_M03_hmastlock_o: out std_logic_vector(0 to 0);
        ahbl_M03_hprot_o: out std_logic_vector(3 downto 0);
        ahbl_M03_htrans_o: out std_logic_vector(1 downto 0);
        ahbl_M03_hwdata_o: out std_logic_vector(31 downto 0);
        ahbl_M03_hwrite_o: out std_logic_vector(0 to 0);
        ahbl_M03_hready_o: out std_logic_vector(0 to 0);
        ahbl_M03_hready_i: in std_logic_vector(0 to 0);
        ahbl_M03_hresp_i: in std_logic_vector(0 to 0);
        ahbl_M03_hrdata_i: in std_logic_vector(31 downto 0);
        ahbl_M02_hsel_o: out std_logic_vector(0 to 0);
        ahbl_M02_haddr_o: out std_logic_vector(31 downto 0);
        ahbl_M02_hburst_o: out std_logic_vector(2 downto 0);
        ahbl_M02_hsize_o: out std_logic_vector(2 downto 0);
        ahbl_M02_hmastlock_o: out std_logic_vector(0 to 0);
        ahbl_M02_hprot_o: out std_logic_vector(3 downto 0);
        ahbl_M02_htrans_o: out std_logic_vector(1 downto 0);
        ahbl_M02_hwdata_o: out std_logic_vector(31 downto 0);
        ahbl_M02_hwrite_o: out std_logic_vector(0 to 0);
        ahbl_M02_hready_o: out std_logic_vector(0 to 0);
        ahbl_M02_hready_i: in std_logic_vector(0 to 0);
        ahbl_M02_hresp_i: in std_logic_vector(0 to 0);
        ahbl_M02_hrdata_i: in std_logic_vector(31 downto 0);
        ahbl_M01_hsel_o: out std_logic_vector(0 to 0);
        ahbl_M01_haddr_o: out std_logic_vector(31 downto 0);
        ahbl_M01_hburst_o: out std_logic_vector(2 downto 0);
        ahbl_M01_hsize_o: out std_logic_vector(2 downto 0);
        ahbl_M01_hmastlock_o: out std_logic_vector(0 to 0);
        ahbl_M01_hprot_o: out std_logic_vector(3 downto 0);
        ahbl_M01_htrans_o: out std_logic_vector(1 downto 0);
        ahbl_M01_hwdata_o: out std_logic_vector(31 downto 0);
        ahbl_M01_hwrite_o: out std_logic_vector(0 to 0);
        ahbl_M01_hready_o: out std_logic_vector(0 to 0);
        ahbl_M01_hready_i: in std_logic_vector(0 to 0);
        ahbl_M01_hresp_i: in std_logic_vector(0 to 0);
        ahbl_M01_hrdata_i: in std_logic_vector(31 downto 0);
        ahbl_M00_hsel_o: out std_logic_vector(0 to 0);
        ahbl_M00_haddr_o: out std_logic_vector(31 downto 0);
        ahbl_M00_hburst_o: out std_logic_vector(2 downto 0);
        ahbl_M00_hsize_o: out std_logic_vector(2 downto 0);
        ahbl_M00_hmastlock_o: out std_logic_vector(0 to 0);
        ahbl_M00_hprot_o: out std_logic_vector(3 downto 0);
        ahbl_M00_htrans_o: out std_logic_vector(1 downto 0);
        ahbl_M00_hwdata_o: out std_logic_vector(31 downto 0);
        ahbl_M00_hwrite_o: out std_logic_vector(0 to 0);
        ahbl_M00_hready_o: out std_logic_vector(0 to 0);
        ahbl_M00_hready_i: in std_logic_vector(0 to 0);
        ahbl_M00_hresp_i: in std_logic_vector(0 to 0);
        ahbl_M00_hrdata_i: in std_logic_vector(31 downto 0);
        apb_M08_psel_o: out std_logic_vector(0 to 0);
        apb_M08_paddr_o: out std_logic_vector(31 downto 0);
        apb_M08_pwrite_o: out std_logic_vector(0 to 0);
        apb_M08_pwdata_o: out std_logic_vector(31 downto 0);
        apb_M08_penable_o: out std_logic_vector(0 to 0);
        apb_M08_pready_i: in std_logic_vector(0 to 0);
        apb_M08_pslverr_i: in std_logic_vector(0 to 0);
        apb_M08_prdata_i: in std_logic_vector(31 downto 0);
        apb_M07_psel_o: out std_logic_vector(0 to 0);
        apb_M07_paddr_o: out std_logic_vector(31 downto 0);
        apb_M07_pwrite_o: out std_logic_vector(0 to 0);
        apb_M07_pwdata_o: out std_logic_vector(31 downto 0);
        apb_M07_penable_o: out std_logic_vector(0 to 0);
        apb_M07_pready_i: in std_logic_vector(0 to 0);
        apb_M07_pslverr_i: in std_logic_vector(0 to 0);
        apb_M07_prdata_i: in std_logic_vector(31 downto 0);
        apb_M06_psel_o: out std_logic_vector(0 to 0);
        apb_M06_paddr_o: out std_logic_vector(31 downto 0);
        apb_M06_pwrite_o: out std_logic_vector(0 to 0);
        apb_M06_pwdata_o: out std_logic_vector(31 downto 0);
        apb_M06_penable_o: out std_logic_vector(0 to 0);
        apb_M06_pready_i: in std_logic_vector(0 to 0);
        apb_M06_pslverr_i: in std_logic_vector(0 to 0);
        apb_M06_prdata_i: in std_logic_vector(31 downto 0);
        apb_M05_psel_o: out std_logic_vector(0 to 0);
        apb_M05_paddr_o: out std_logic_vector(31 downto 0);
        apb_M05_pwrite_o: out std_logic_vector(0 to 0);
        apb_M05_pwdata_o: out std_logic_vector(31 downto 0);
        apb_M05_penable_o: out std_logic_vector(0 to 0);
        apb_M05_pready_i: in std_logic_vector(0 to 0);
        apb_M05_pslverr_i: in std_logic_vector(0 to 0);
        apb_M05_prdata_i: in std_logic_vector(31 downto 0)
    );
end component;

__: unified_interconnect_0 port map(
    clk_i=>,
    resetn_i=>,
    ahbl_S00_hsel_i=>,
    ahbl_S00_haddr_i=>,
    ahbl_S00_hwrite_i=>,
    ahbl_S00_hwdata_i=>,
    ahbl_S00_hsize_i=>,
    ahbl_S00_htrans_i=>,
    ahbl_S00_hprot_i=>,
    ahbl_S00_hmastlock_i=>,
    ahbl_S00_hburst_i=>,
    ahbl_S00_hready_i=>,
    ahbl_S00_hreadyout_o=>,
    ahbl_S00_hrdata_o=>,
    ahbl_S00_hresp_o=>,
    ahbl_M04_hsel_o=>,
    ahbl_M04_haddr_o=>,
    ahbl_M04_hburst_o=>,
    ahbl_M04_hsize_o=>,
    ahbl_M04_hmastlock_o=>,
    ahbl_M04_hprot_o=>,
    ahbl_M04_htrans_o=>,
    ahbl_M04_hwdata_o=>,
    ahbl_M04_hwrite_o=>,
    ahbl_M04_hready_o=>,
    ahbl_M04_hready_i=>,
    ahbl_M04_hresp_i=>,
    ahbl_M04_hrdata_i=>,
    ahbl_M03_hsel_o=>,
    ahbl_M03_haddr_o=>,
    ahbl_M03_hburst_o=>,
    ahbl_M03_hsize_o=>,
    ahbl_M03_hmastlock_o=>,
    ahbl_M03_hprot_o=>,
    ahbl_M03_htrans_o=>,
    ahbl_M03_hwdata_o=>,
    ahbl_M03_hwrite_o=>,
    ahbl_M03_hready_o=>,
    ahbl_M03_hready_i=>,
    ahbl_M03_hresp_i=>,
    ahbl_M03_hrdata_i=>,
    ahbl_M02_hsel_o=>,
    ahbl_M02_haddr_o=>,
    ahbl_M02_hburst_o=>,
    ahbl_M02_hsize_o=>,
    ahbl_M02_hmastlock_o=>,
    ahbl_M02_hprot_o=>,
    ahbl_M02_htrans_o=>,
    ahbl_M02_hwdata_o=>,
    ahbl_M02_hwrite_o=>,
    ahbl_M02_hready_o=>,
    ahbl_M02_hready_i=>,
    ahbl_M02_hresp_i=>,
    ahbl_M02_hrdata_i=>,
    ahbl_M01_hsel_o=>,
    ahbl_M01_haddr_o=>,
    ahbl_M01_hburst_o=>,
    ahbl_M01_hsize_o=>,
    ahbl_M01_hmastlock_o=>,
    ahbl_M01_hprot_o=>,
    ahbl_M01_htrans_o=>,
    ahbl_M01_hwdata_o=>,
    ahbl_M01_hwrite_o=>,
    ahbl_M01_hready_o=>,
    ahbl_M01_hready_i=>,
    ahbl_M01_hresp_i=>,
    ahbl_M01_hrdata_i=>,
    ahbl_M00_hsel_o=>,
    ahbl_M00_haddr_o=>,
    ahbl_M00_hburst_o=>,
    ahbl_M00_hsize_o=>,
    ahbl_M00_hmastlock_o=>,
    ahbl_M00_hprot_o=>,
    ahbl_M00_htrans_o=>,
    ahbl_M00_hwdata_o=>,
    ahbl_M00_hwrite_o=>,
    ahbl_M00_hready_o=>,
    ahbl_M00_hready_i=>,
    ahbl_M00_hresp_i=>,
    ahbl_M00_hrdata_i=>,
    apb_M08_psel_o=>,
    apb_M08_paddr_o=>,
    apb_M08_pwrite_o=>,
    apb_M08_pwdata_o=>,
    apb_M08_penable_o=>,
    apb_M08_pready_i=>,
    apb_M08_pslverr_i=>,
    apb_M08_prdata_i=>,
    apb_M07_psel_o=>,
    apb_M07_paddr_o=>,
    apb_M07_pwrite_o=>,
    apb_M07_pwdata_o=>,
    apb_M07_penable_o=>,
    apb_M07_pready_i=>,
    apb_M07_pslverr_i=>,
    apb_M07_prdata_i=>,
    apb_M06_psel_o=>,
    apb_M06_paddr_o=>,
    apb_M06_pwrite_o=>,
    apb_M06_pwdata_o=>,
    apb_M06_penable_o=>,
    apb_M06_pready_i=>,
    apb_M06_pslverr_i=>,
    apb_M06_prdata_i=>,
    apb_M05_psel_o=>,
    apb_M05_paddr_o=>,
    apb_M05_pwrite_o=>,
    apb_M05_pwdata_o=>,
    apb_M05_penable_o=>,
    apb_M05_pready_i=>,
    apb_M05_pslverr_i=>,
    apb_M05_prdata_i=>
);
