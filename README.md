Hi

Is it possible to discuss with someone
low level security issues?

1. All police investigations are based on the inductive logic.
2. And there is famous https://en.wikipedia.org/wiki/Problem_of_induction
3. So if results of inductive logic reasoning are random then it means that police is catching innocent people.

But any person,
including young woman and woman with kids
can have firearms exactly as police.

So why all woman killed in the woods did not have a chance to buy firearms without any restriction?

Also according to the properties of the Turing machines
all software contains unavoidable security issue.
And all fixes to the security issues just moves the hole to the
another place.

And it is possible to train AI system so that system
will give you a fresh zero day exploit from the fresh fix.

Also it is possible to force your hardware
vendor to place any issue in the hardware.
Police will not help them.

Any kind of police.

Will we start to fix it?

# MIPI CSI-2 to USB UVC Reference Design

## Introduction
The Lattice Semiconductor CrosslinkU™-NX Mobile Industry Processor Interface (MIPI®) Camera Serial Interface-2 (CSI-2) to Universal Serial Bus (USB) reference design provides a template for unified video streaming from a camera sensor, utilizing the USB hard IP in a CrosslinkU-NX device.

## Features
Key features of the MIPI CSI-2 to USB UVC reference design include:
- The Lattice MIPI CSI/DSI IP Core in this reference design is configured to support two lanes (capped by IMX219 capability) with a lane rate of 592 Mbps (capped by driver configuration). The IP receives, processes, and converts incoming MIPI video payload packets into Unified Video Streaming Interface (UVSI) packets. For details, refer to the MIPI CSI/DSI IP User Guide (FPGA-IPUG-02321).
- The Lattice Debayer IP Core extracts the R, G, and B components from the pixel data output by the image sensor, converting the RAW10 data format into full RGB components. For details, refer to \<IP_Installation_Path>/latticesemi_custom_ip_debayer_1.4.0.03/doc/IP_Design_Notes.pdf.
- The Lattice Color Correction Matrix IP Core performs pixel data correction by adjusting R, G, and B components gain and compensates for color channel crosstalk. For details, refer to \<IP_Installation_Path>/latticesemi_custom_ip_ccm_1.3.1.03/doc/IP_Design_Notes.pdf.
- The Color Space Converter IP Core converts RGB data into the YUV format. For details, refer to \<IP_Installation_Path>/latticesemi_custom_ip_color_space_converter_2.4.1.03/doc/IP_Design_Notes.pdf.
- The Chroma Resampler converts YUV444 data into the YUV422 format by reducing the chroma component.
- The Video to USB bridge takes in UVSI packets and form data stream in USB Video Class (UVC) format for USB transfer.
- The hardware USB IP Core streams the unified video data from the image sensor to a PC through a USB Type-C connector.
- The RISC-V MC processor uses the I2C Controller IP to configure the registers of the MIPI camera sensor, enabling proper initialization and operation of the camera.

## Getting started
Refer to [FPGA-RD-02306-1-4-MIPI-CSI-2-to-USB-UVC-Reference-Design-User-Guide.pdf](docs/FPGA-RD-02306-1-4-MIPI-CSI-2-to-USB-UVC-Reference-Design-User-Guide.pdf) for more information.

## Project and Executables
| Directory                                            | Description                                                  |
|:-----------------------------------------------------|:-------------------------------------------------------------|
| [mipi_csi_to_usb_uvc.rdf](fpga_lifcl/radiant/mipi_csi_to_usb_uvc.rdf)                           | Lattice Radiant project file for reference design            |
| [mipi_csi_to_usb_uvc.sbx](fpga_lifcl/radiant/propelbld_mipi_csi_to_usb_uvc/mipi_csi_to_usb_uvc.sbx)  | Lattice Propel Builder project file for reference design     |
| [mipi_csi_to_usb_uvc_impl_1.bit](fpga_lifcl/precompiled_file/mipi_csi_to_usb_uvc_impl_1.bit)    | Precompiled bit file (IP Evaluation) to run reference design on the hardware |

## File Directory
```
<RD02306_mipi_csi_to_usb_uvc>
├── docs                                     (Documentation and Reference Design User Guide)
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
