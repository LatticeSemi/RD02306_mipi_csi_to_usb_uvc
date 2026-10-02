import os

def load_parameter(param_name):
    f_params = open('eval/dut_params.v', 'r')
    while f_params:
        line = f_params.readline()
        if (param_name in line):
            str_spl = line.split('=')
            param = str_spl[-1]
            val = str_spl[1]
            f_val = val.replace(";\n",'')
            f_val2 = f_val.replace("\"",'')
            f_val3 = f_val2.replace(" ",'')
            break
    f_params.close()
    return (f_val3)

def load_define_device(device_name):
    f_params = open('eval/dut_params.v', 'r')
    counter = 0
    while f_params:
        line = f_params.readline()
        if not line:
            break
        str_split = line.split(" ")
        print(str_split)
        if str_split[0] == "`define":
            counter += 1
        if counter == 3:
            f_val = str_split[1].strip()
            break
    f_params.close()
    return (f_val)

f_pdc = open('eval/constraint.pdc', 'w')
LFMXO4D_ZC      = ["LFMXO4D_040ZC", "LFMXO4D_050ZC", "LFMXO4D_080ZC", "LFMXO4D_110ZC"]
sys_clk_freq    = load_parameter("SYS_CLOCK_FREQ")
device_name     = load_define_device("DEVICE_NAME")
f_pdc.write("##================================================================================##\n")
f_pdc.write("## Copy these constraints to your top-level pdc and replace path with actual path \n")
f_pdc.write("##================================================================================##\n")
f_pdc.write("\n")
f_pdc.write("ldc_set_port -iobuf {PULLMODE=UP} [get_ports {scl_io}]\n")
f_pdc.write("ldc_set_port -iobuf {PULLMODE=UP} [get_ports {sda_io}]\n")
f_pdc.write("\n")
"""
if device_name in LFMXO4D_ZC and float(sys_clk_freq) > 30:
    f_pdc.write("set CLK_PERIOD 33.3333333\n")
else:
    f_pdc.write("set CLK_PERIOD %0.1f\n" % (1000.0/float(sys_clk_freq)))
"""
f_pdc.write("set CLK_PERIOD %0.1f\n" % (1000.0/float(sys_clk_freq)))
f_pdc.write("create_clock -name {clk_i} -period $CLK_PERIOD [get_ports clk_i]\n")
f_pdc.write("##================================================================================##\n")
f_pdc.write("## The following are used for maverick regression only, remove when using in Radiant \n")
f_pdc.write("##================================================================================##\n")
f_pdc.write("\n")
f_pdc.write("ldc_set_attribute {VIRTUAL_IO=TRUE} [get_ports apb*]\n")
f_pdc.write("ldc_set_attribute {VIRTUAL_IO=TRUE} [get_ports lmmi*]\n")
f_pdc.close()