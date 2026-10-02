set device "LIFCL-33U"
set device_int "jd5u27a"
set package "FCCSP104"
set package_int "FCCSP104"
set speed "7_High-Performance_1.0V"
set speed_int "10"
set operation "Commercial"
set family "LIFCL"
set architecture "je5d00"
set partnumber "LIFCL-33U-7CTG104C"
set WRAPPER_INST "lscc_unified_interconnect_inst"
set TOTAL_EXTMAS_CNT 1
set TOTAL_EXTSLV_CNT 9
set FAMILY "LIFCL"
set AXI_USER_WIDTH 1
set LARGE_FIFO_MEM_TYPE "LUT"
set SIMULATION_EN 0
set XBAR_MODE 1
set XBAR_PRIMARY_MODE 2
set EXT_MAS_AXI_ID_WIDTH 2
set EXT_MAS_MAX_ADDR_WIDTH 32
set EXT_MAS_MAX_DATA_WIDTH 32
set EXT_MAS_PRIORITY_SCHEME 0
set EXT_SLV_AXI_ID_WIDTH 3
set EXT_SLV_MAX_ADDR_WIDTH 32
set EXT_SLV_MAX_DATA_WIDTH 32
set EXT_SLV_MAX_FRAGMENT_CNT 1
set EXT_SLV_AXI_SECURE_ACCESS "{1'd0,1'd0,1'd0,1'd0,1'd0,1'd0,1'd0,1'd0,1'd0}"
set EXT_SLV_AXI_SECURE_AXI_ACCESS 0
set EXT_SLV_AXI_SECURE_AXIL_ACCESS 0
set EXT_MAS_AXI_SECURE_ACCESS "1'd0"
set EXT_MAS_DATA_REGISTER_SLICE "1'd0"
set EXT_SLV_DATA_REGISTER_SLICE "{1'd0,1'd0,1'd0,1'd0,1'd0,1'd0,1'd0,1'd0,1'd0}"
set EXT_MAS_ACCESS_TYPE "2'd2"
set EXT_MAS_PROTOCOL  "3'd2"
set EXT_MAS_CDC_EN "1'd0"
set EXT_MAS_ADDR_WIDTH "7'd32"
set EXT_MAS_DATA_WIDTH "11'd32"
set EXT_MAS_AXI_WR_ACCEPTANCE_LIMIT "6'd1"
set EXT_MAS_AXI_RD_ACCEPTANCE_LIMIT "6'd1"
set EXT_MAS_WR_ADDR_DEPTH "5'd0"
set EXT_MAS_RD_ADDR_DEPTH "5'd0"
set EXT_MAS_BRESP_FIFO_DEPTH "5'd0"
set EXT_MAS_WR_DATA_FIFO_DEPTH "10'd2"
set EXT_MAS_RD_DATA_FIFO_DEPTH "10'd0"
set EXT_MAS_FIXED_PRIORITY  "5'd0"
set EXT_SLV_ACCESS_TYPE "{2'd2,2'd2,2'd2,2'd2,2'd2,2'd2,2'd2,2'd2,2'd2}"
set EXT_SLV_PROTOCOL  "{3'd3,3'd3,3'd3,3'd3,3'd2,3'd2,3'd2,3'd2,3'd2}"
set EXT_SLV_CDC_EN "{1'd0,1'd0,1'd0,1'd0,1'd0,1'd0,1'd0,1'd0,1'd0}"
set EXT_SLV_CDC_AXI_EN 0
set EXT_SLV_CDC_AXIL_EN 0
set EXT_SLV_CDC_AHBL_EN 0
set EXT_SLV_CDC_APB_EN 0
set EXT_SLV_ADDR_WIDTH "{7'd32,7'd32,7'd32,7'd32,7'd32,7'd32,7'd32,7'd32,7'd32}"
set EXT_SLV_DATA_WIDTH "{11'd32,11'd32,11'd32,11'd32,11'd32,11'd32,11'd32,11'd32,11'd32}"
set EXT_SLV_WR_ADDR_DEPTH "{5'd0,5'd0,5'd0,5'd0,5'd0,5'd0,5'd0,5'd0,5'd0}"
set EXT_SLV_RD_ADDR_DEPTH "{5'd0,5'd0,5'd0,5'd0,5'd0,5'd0,5'd0,5'd0,5'd0}"
set EXT_SLV_BRESP_FIFO_DEPTH "{5'd0,5'd0,5'd0,5'd0,5'd0,5'd0,5'd0,5'd0,5'd0}"
set EXT_SLV_WR_DATA_FIFO_DEPTH "{10'd0,10'd0,10'd0,10'd0,10'd0,10'd0,10'd0,10'd0,10'd0}"
set EXT_SLV_RD_DATA_FIFO_DEPTH "{10'd2,10'd2,10'd2,10'd2,10'd2,10'd2,10'd2,10'd2,10'd2}"
set  EXT_SLV_FRAGMENT_CNT "{5'd1,5'd1,5'd1,5'd1,5'd1,5'd1,5'd1,5'd1,5'd1}"
set EXT_SLV_FRAGMENT_BASE_ADDR "{64'h80000,64'h70000,64'h60000,64'h50000,64'h40000,64'h30000,64'h20000,64'h10000,64'h0}"
set EXT_SLV_FRAGMENT_END_ADDR   "{64'h80fff,64'h70fff,64'h60fff,64'h50fff,64'h40fff,64'h30fff,64'h20fff,64'h10fff,64'hfff}"
set PERFORMANCE_FMAX 0
set INVALID_ADDR_ERR_RESP_EN 1
set DSLICE_EN 0
set MAX_DWIDTH 32
set CONNECT_EN "{1'd1,1'd1,1'd1,1'd1,1'd1,1'd1,1'd1,1'd1,1'd1}"
set SECONDARY_AXI4_CONNECT_EN "1'd1"
set SECONDARY_AXI4L_CONNECT_EN "1'd1"
set SECONDARY_AHBL_CONNECT_EN "1'd1"
set SECONDARY_APB_CONNECT_EN "1'd1"


# function grep parameter set true or false
proc parameter_enable {parameter} {
    foreach item $parameter {
        if {[regexp {1'd1} $item]} {
            return true
        }
    }
    return false
}

# function grep parameter value
proc parameter_value {parameter} {
    regsub -all {\{|\}} $parameter "" cleaned
    set items [split $cleaned ","]
    set values ""

    foreach item $items {
        # Match any digit prefix like 7'd or 6'd and capture the number
        if {[regexp {(\d+)'d(\d+)} $item -> width value]} {
            append values "$value "
        }
    }
    return $values
}

# Check each part MAS CDC
set MAS_CDC_ENABLE_TRUE [parameter_enable $EXT_MAS_CDC_EN]


# Check each part SLV CDC
set SLV_CDC_ENABLE_TRUE [parameter_enable $EXT_SLV_CDC_EN]


# Check each WR ACCEPTANCE
set WR_ACCEPTANCE_LIMIT_EANBLE false
foreach value [parameter_value $EXT_MAS_AXI_WR_ACCEPTANCE_LIMIT]  {
    if {$value >2} {
        set WR_ACCEPTANCE_LIMIT_EANBLE true
        break
    }
}

# Check each SLV RD FIFO
set SLV_RD_DATA_FIFO_DEPTH_2 false
foreach value [parameter_value $EXT_SLV_RD_DATA_FIFO_DEPTH]  {
    if {$value == 2} {
        set SLV_RD_DATA_FIFO_DEPTH_2 true
        break
    }
}

# Set each data width max delay
set max_delay 6.5
foreach value [parameter_value $EXT_MAS_DATA_WIDTH]  {
    if {$value >= 128} {
        set max_delay 10
        break
    }
}

# extract speed
regexp {^(\d+)_} $speed match speed_number

