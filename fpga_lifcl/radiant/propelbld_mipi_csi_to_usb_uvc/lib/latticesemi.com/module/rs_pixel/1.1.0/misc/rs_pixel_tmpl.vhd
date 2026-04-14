component rs_pixel is
    port(
        src_rst_n: in std_logic;
        dest_clk: in std_logic;
        dest_rst: out std_logic;
        dest_rst_n: out std_logic
    );
end component;

__: rs_pixel port map(
    src_rst_n=>,
    dest_clk=>,
    dest_rst=>,
    dest_rst_n=>
);
