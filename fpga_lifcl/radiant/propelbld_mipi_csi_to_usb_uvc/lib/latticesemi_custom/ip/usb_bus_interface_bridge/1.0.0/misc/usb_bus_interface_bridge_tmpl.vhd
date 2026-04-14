component usb_bus_interface_bridge is
    port(
        lmmi_rdata_o: out std_logic_vector(31 downto 0);
        lmmi_rdata_valid_o: out std_logic;
        lmmi_ready_o: out std_logic;
        lmmi_request_i: in std_logic;
        lmmi_wr_rdn_i: in std_logic;
        lmmi_offset_i: in std_logic_vector(14 downto 0);
        lmmi_wdata_i: in std_logic_vector(31 downto 0);
        LMMIRDATA: in std_logic_vector(31 downto 0);
        LMMIRDATAVALID: in std_logic;
        LMMIREADY: in std_logic;
        LMMIREQUEST: out std_logic;
        LMMIWRRD_N: out std_logic;
        LMMIOFFSET: out std_logic_vector(14 downto 0);
        LMMIWDATA: out std_logic_vector(31 downto 0);
        INTERRUPT: in std_logic;
        RISCV_USB_INTERRUPT: out std_logic
    );
end component;

__: usb_bus_interface_bridge port map(
    lmmi_rdata_o=>,
    lmmi_rdata_valid_o=>,
    lmmi_ready_o=>,
    lmmi_request_i=>,
    lmmi_wr_rdn_i=>,
    lmmi_offset_i=>,
    lmmi_wdata_i=>,
    LMMIRDATA=>,
    LMMIRDATAVALID=>,
    LMMIREADY=>,
    LMMIREQUEST=>,
    LMMIWRRD_N=>,
    LMMIOFFSET=>,
    LMMIWDATA=>,
    INTERRUPT=>,
    RISCV_USB_INTERRUPT=>
);
