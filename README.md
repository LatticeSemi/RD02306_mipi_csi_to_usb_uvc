# MIPI CSI to USB UVC Reference Design

## Introduction
The Lattice Semiconductor CrosslinkU™-NX Mobile Industry Processor Interface (MIPI®) Camera Serial Interface-2 (CSI-2) to Universal Serial Bus (USB) reference design provides a template for unified video streaming from a camera sensor, utilizing the USB hard IP in a CrosslinkU-NX device.

## Features
Key features of the MIPI CSI-2 to USB reference design include:
- The Lattice MIPI CSI/DSI RX IP Core in this reference design is configured to support two lanes (capped by IMX219 capability) with lane rate of 592 Mbps (capped by driver configuration). The IP receives, processes, and converts incoming MIPI video payload packets into Unified Video Streaming Interface (UVSI) packets. For details, refer to \<Project_Directory>/latticesemi_custom_ip_mipi_csi_dsi_1.0.0.02/doc/IP_Design_Notes.pdf.
- The Lattice Debayer IP Core extracts the R, G, and B components from the pixel data output by the image sensor, converting the RAW10 data format into full RGB components. For details, refer to \<Project_Directory>/isp_debayer_1_4_0_01_development/doc/IP_Design_Notes.pdf
- The Lattice Color Correction Matrix IP Core performs pixel data correction by adjusting R, G, and B components gain and compensates for color channel crosstalk. For details, refer to \<Project_Directory>/isp_ccm_1_3_1_01_development/doc/IP_Design_Notes.pdf.
- The Color Space Converter IP Core converts RGB data into the YUV format. For details, refer to \<Project_Directory>/color_space_converter_2_4_1_01_development/doc/IP_Design_Notes.pdf
- The Chroma Resampler converts YUV444 data into the YUV422 format by reducing the chroma component.
- The Video to USB bridge takes in UVSI packets and form data stream in USB Video Class (UVC) format for USB transfer.
- The hardware USB IP Core streams the unified video data from the image sensor to a PC through a USB Type-C connector.
- The RISC-V MC processor uses the I2C Controller IP to configure the registers of the MIPI camera sensor, enabling proper initialization and operation of the camera.

Note: USB 2.0 configurations support up to 720p30 equivalent video bandwidth.

## Getting started
Refer to [FPGA-RD-02306-1-2-MIPI-CSI-2-USB-UVC-Reference-Design.pdf](docs/FPGA-RD-02306-1-2-MIPI-CSI-2-USB-UVC-Reference-Design.pdf) for more information.

## Project and Executables
| Directory                                            | Description                                                  |
|:-----------------------------------------------------|:-------------------------------------------------------------|
| [mipi_csi_to_usb_uvc.rdf](fpga_lifcl/radiant/mipi_csi_to_usb_uvc.rdf)                           | Lattice Radiant project file for reference design            |
| [mipi_csi_to_usb_uvc.sbx](fpga_lifcl/radiant/propelbld_mipi_csi_to_usb_uvc/mipi_csi_to_usb_uvc.sbx)  | Lattice Propel Builder project file for reference design     |
| [mipi_csi_to_usb_uvc_impl_1.bit](fpga_lifcl/precompiled_file/mipi_csi_to_usb_uvc_impl_1.bit)    | Precompiled bit file (IP Evaluation) to run reference design on the hardware |

## File Directory
```
<RD02306_mipi_csi_to_usb_uvc>
├── docs
├── fpga_lifcl                               (Project files used in this design for device CrossLink)
│   ├── precompiled_file                     (Precompile bitstream for this design)
│   ├── propelsdk                            (Propel SDK project)
│   │   └── riscv_mc                         (risc-v source code)
│   └── radiant                              (Radiant and Propel Buidler project materials for this design)
│       ├── propelbld_mipi_csi_to_usb_uvc    (Propel Builder project materials for this design)
│       ├── sge
│       ├── src
│       │   └── constraints
│       └── verification
└── misc                                     (Non-FPGA related files)
    └── custom_ip                            (Lattice IP Packagers for custom IPs)
```

## Resources
[Lattice Semiconductor Support Center](https://www.latticesemi.com/support)