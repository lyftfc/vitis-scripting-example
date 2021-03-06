VPRJ_NAME := $(KRNL_NAME)_packprj

kernel: $(VPRJ_NAME)/$(KRNL_NAME).xo

$(VPRJ_NAME)/$(KRNL_NAME).xo:
	vivado -nolog -nojournal -mode batch \
		-source kernel_config.tcl -source ../../script/pack_xo.tcl

clean:
	@rm -rf $(VPRJ_NAME)/ .hbs/ .Xil/ *.log *.jou

.PHONY: kernel clean
