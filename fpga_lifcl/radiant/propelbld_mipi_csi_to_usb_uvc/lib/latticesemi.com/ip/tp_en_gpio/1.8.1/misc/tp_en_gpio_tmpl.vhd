component tp_en_gpio is
    port(
        gpio_i: in std_logic_vector(0 to 0);
        gpio_o: out std_logic_vector(0 to 0);
        gpio_en_o: out std_logic_vector(0 to 0);
        clk_i: in std_logic;
        resetn_i: in std_logic;
        apb_penable_i: in std_logic;
        apb_psel_i: in std_logic;
        apb_pwrite_i: in std_logic;
        apb_paddr_i: in std_logic_vector(5 downto 0);
        apb_pwdata_i: in std_logic_vector(31 downto 0);
        apb_prdata_o: out std_logic_vector(31 downto 0);
        apb_pslverr_o: out std_logic;
        apb_pready_o: out std_logic;
        int_o: out std_logic
    );
end component;

__: tp_en_gpio port map(
    gpio_i=>,
    gpio_o=>,
    gpio_en_o=>,
    clk_i=>,
    resetn_i=>,
    apb_penable_i=>,
    apb_psel_i=>,
    apb_pwrite_i=>,
    apb_paddr_i=>,
    apb_pwdata_i=>,
    apb_prdata_o=>,
    apb_pslverr_o=>,
    apb_pready_o=>,
    int_o=>
);
