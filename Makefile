VPP := v++
TGT := hw
NJOBS := 12
PLATFORM := xilinx_u250_xdma_201830_2
OBJ_DIR := hw_build
TEMP_DIR := vpp_temp

HLS_KRNL := krnl_feeder krnl_poller
RTL_KRNL := krnl_dual_fifo
LINK_CFG := ./linking.cfg
BS_NAME := endianess_trial.xclbin

EXEC_NAME := et_host
HOST_SRC := $(EXEC_NAME).cpp xcl2.cpp
HOST_INC := xcl2.hpp

XRT_DIR := /opt/xilinx/xrt
VITIS_DIR := /opt/Xilinx/Vitis/2020.1

HLS_XO := $(patsubst %, $(OBJ_DIR)/hls/%.xo, $(HLS_KRNL))
RTL_XO := $(patsubst %, $(OBJ_DIR)/rtl/%.xo, $(RTL_KRNL))
HSTSRC_ABS := $(patsubst %, src/%, $(HOST_SRC))
HSTINC_ABS := $(patsubst %, src/%, $(HOST_INC))

all: host bitstream

bitstream: $(OBJ_DIR)/$(BS_NAME)

host: $(EXEC_NAME)

kernels: hls_kernels rtl_kernels

hls_kernels: $(HLS_XO)

rtl_kernels: $(RTL_XO)

# Host OpenCL program
$(EXEC_NAME): $(HSTSRC_ABS) $(HSTINC_ABS)
	g++ -o $@ $(HSTSRC_ABS) \
		-Isrc -I$(XRT_DIR)/include -I$(VITIS_DIR)/include \
		-Wall -O0 -g -std=c++11 -fmessage-length=0 \
		-L$(XRT_DIR)/lib -lOpenCL -lpthread -lrt -lstdc++

# HLS Kernels
$(OBJ_DIR)/hls/%.xo: src/%.cpp
	$(eval KRNL_NAME := $(patsubst $(OBJ_DIR)/hls/%.xo,%,$@))
	v++ -t $(TGT) -f $(PLATFORM) -c -j $(NJOBS) --temp_dir $(TEMP_DIR) -s \
		-k $(KRNL_NAME) -o $@ $^

# RTL Kernels
# Note that RTL sources are NOT included as dependancy!
$(OBJ_DIR)/rtl/%.xo: rtl/%/kernel.xml rtl/%/kernel_config.tcl
	$(eval KRNL_NAME := $(patsubst $(OBJ_DIR)/rtl/%.xo,%,$@))
	@make -C ./rtl/$(KRNL_NAME)/ -f ../../script/rtl_kernel.makefile \
		-j $(NJOBS) KRNL_NAME=$(KRNL_NAME)
	@mkdir -p $(OBJ_DIR)/rtl
	@cp ./rtl/$(KRNL_NAME)/$(KRNL_NAME)_packprj/$(KRNL_NAME).xo $(OBJ_DIR)/rtl/

# Linking (bitstream)
$(OBJ_DIR)/$(BS_NAME): $(HLS_XO) $(RTL_XO) $(LINK_CFG)
	v++ -t $(TGT) -f $(PLATFORM) -l --config $(LINK_CFG) \
		-j $(NJOBS) --temp_dir $(TEMP_DIR) -s -o $@ $(HLS_XO) $(RTL_XO)

clean:
	@rm -rf .Xil/ $(OBJ_DIR)/ $(TEMP_DIR)/ *.log *.jou *.str $(EXEC_NAME)
	$(foreach rtlk,$(RTL_KRNL),make clean -C ./rtl/$(rtlk)/ \
		-f ../../script/rtl_kernel.makefile KRNL_NAME=$(rtlk);)

clean_log:
	@rm -f *.log *.jou *.str

.PHONY: clean all bitstream host kernels hls_kernels rtl_kernels
