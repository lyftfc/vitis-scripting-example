#!/bin/bash

# Card 0 is on PCIe 0x3b00 => 15105
debug_hw --xvc_pcie /dev/xfpga/xvc_pub.u15105.0 --hw_server
