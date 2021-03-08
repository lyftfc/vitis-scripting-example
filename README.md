# Vitis Scripting Example

Example and template project for Vitis scripting workflow.

This project demonstrates the following topics:

* Kernels written in HLS C++
    - Communicate with host using memory mapping
    - AXI Streaming with other kernels
* Kernels written in RTL
    - Free-running AXI streaming kernel
    - Construct from Verilog sources and package into XO files
* Linking kernels into bitstreams
* Host-side OpenCL program that controls execution
* Hardware ILA debug utilities
    - Adding debug kernels to the design
    - Attach to virtual (PCIe) JTAG probe and setup ILA trigger
    - Load captured ILA waveform

## The Example Project

The dataflow of this project is as follow:
```
krnl_feeder =(ms2b,ls2b)=> krnl_dual_fifo =(ms2b,ls2b)=> krnl_poller
```
while `krnl_feeder` and `krnl_poller` read/write the host through OpenCL DMA (via PCIe).
`krnl_feeder` tears 32-bit data into 2 16-bit integers and feed into AXI stream buffer 
`krnl_dual_fifo` written in Verilog. `krnl_poller` cross the two streams and write back 
to the host.

### Running the Example

The project is tested with Vitis/Vivado 2020.1 on platform `xilinx_u250_xdma_201830_2`.
To run the example on your environment, perform the following procedure:

1. Check the first 20 lines of `./Makefile` and modify them as needed.
2. Execute `make` in the project root directory. This may take several hours.
3. Run the executable (default `./et_host`) in the project root.
4. Observe the results.

In particular, the `PLATFORM` should match your Alveo development/deployment shell 
version. `PF_PART` and `PF_BOARD` are chip model and board ID of the hardware, which 
can be found by creating a Vivado project using the corresponding Alveo board.

### Hardware Debugging

Xilinx XRT and the Shell on FPGA provides virtual JTAG connection to the FPGA chip. 
Using their toolchain, it is possible to attach ILA using Vivado and observe the 
hardware signals. This project provides scripts to facilitate this process.

1. From the project root directory, execute `./et_host` and let it runs till showing 
    "... setting up ILA trigger".
2. Find the XVC device by execute `ls /etc/xfpga/` and locate the file that names 
    as `xvc_pub.u<device_id>`. In case of machine with multiple FPGA cards, confirm 
    the device ID by converting their PCIe endpoint address to decimal and plus 1.
    - Run `xbutil scan` and find the PCIe address of your target card, such as 
        `0000:3b:00.1`
    - The device ID of its XVC will be dec(0x3b00)+1=15105
    - Thus the XVC device will be `/etc/xfpga/xvc_pub.u15105.0`
3. Modify `./script/start-xvc.sh` to use that device, or simply execute 
    ```
    debug_hw --xvc_pcie /dev/xfpga/xvc_pub.u<device_id> --hw_server
    ```
4. Examine the script `./script/vivado-hw-mgr.tcl` and confirm that it is loading 
    the `probeFile` accompanying the bitstream, in this case 
    `./hw_build/endianess_trial.ltx`
5. Execute Vivado sourcing the script by
    ```
    vivado -source ./script/vivado-hw-mgr.tcl
    ```
6. Setup signal trigers as needed in the Vivado GUI, and arm the capture.
7. Press enter for the executable in step 1.
8. If the trigger condition is met, the Vivado hardware manager will show the 
    captured signals. You may optionally save the capture results as an ILA file.
9. To review the ILA file saved in step 8, run
    ```
    vivado -source ./script/vivado-read-ila.tcl -tclargs <path_to_ila_file>
    ```
    to load the file and open it in Vivado hardware manager.

## Using as Template

This example project is parameterised and designed to be used as a template. To adapt 
it for your new design, refer to the following information:

### HLS Kernels

For every entry `<krnl_name>` in `$HLS_KRNL` in `./Makefile`, the make script assumes 
its (only) source file is `./src/<krnl_name>.cpp`.

If this does not suit your needs, modify the HLS kernel rule. `v++` accept sources, 
include directories using `-I`, defines using `-D` similar to `g++`. Refer to 
`v++ -h` for more helps.

### RTL Kernels

For every entry `<krnl_name>` in `$RTL_KRNL` in `./Makefile`, the make script assumes 
its source files reside in `./rtl/<krnl_name>`. It then package the design using 
`pack_xo.tcl` and `rtl_kernel.makefile` under `./script`. Normally it is not necessary 
to modify these scripts.

To create your RTL kernel from (System)Verilog/VHDL sources using the provided 
scripts, follow the below procedure:

1. Put your `<krnl_name>` into `$RTL_KRNL` in `./Makefile`.
2. Make directory `./rtl/<krnl_name>/src` and put all your sources there. The top-level 
    module has to have the following interfaces:
    - Clock and reset named `ap_clk` and `ap_rst_n`
    - AXI-Lite slave interface. For default controller and its signals refer to 
        `./rtl/krnl_dual_fifo/src/s_axi_ctrl_none.v`
    - AXI stream interfaces
3. Write the configuration script `kernel_config.tcl` under `./rtl/<krnl_name>/`. Refer 
    to `./rtl/krnl_dual_fifo/kernel_config.tcl` as an example. Note that `$krnl_freq` 
    is for kernel generation only and does not determine the final design clock.
4. Write the description file required by Vitis `kernel.xml` under `./rtl/<krnl_name>/`. 
    Refer to `./rtl/krnl_dual_fifo/kernel.xml` as an example. Note that the offset of 
    AXI stream interfaces is normally 8-bytes.

Now the make script will compile your RTL kernel into a XO file.

### Linking

The linking process essentially extracts the IP cores from their corresponding XO files, 
connects them into a Vivado block design targeting a partially reconfigurable region on 
the FPGA, and then running synthesis, implementation and bitstream generation. The 
linking configuration file, in this example `./linking.cfg`, defines how these IPs 
would be placed and connected.

The options used in the example are:

* `dk`: Debug kernel insertion at specified port, in the format of 
    `<debug_ip_name>:<krnl_inst_id>:<port_name>`
* `connectivity.nk`: Define the kernel count and instance names, in the format of 
    `<krnl_name>:<count>:<krnl_inst_id>...
* `connectivity.sc`: Define the AXI stream connection (aka `stream_connect`), in the 
    format of `<krnl_inst_id_upstr>.<port_upstr>:<krnl_inst_id_downstr>.<port_downstr>`

Refer to `v++ -h` which provides detailed descriptions about link script options. 