#########################
# Kernel Configurations #
#########################

set krnl_name "krnl_dual_fifo"
set krnl_vendor "nus.edu.sg"
# Kernel ap_clk frequency in Hz
set krnl_freq 250000000
# Kernel extra AXIS intefaces
set krnl_intfs {
	s_dina
	s_dinb
	m_douta
	m_doutb
}
# Kernel parameters - those will not be exposed in IP
set krnl_params {
	C_S_AXI_CONTROL_ADDR_WIDTH
	C_S_AXI_CONTROL_DATA_WIDTH
	DWIDTH_A
	DEPTH_A
	DWIDTH_B
	DEPTH_B
}
# Kernel source file set
set krnl_srcs {
	./src/axis_queue_bram.v
	./src/s_axi_ctrl_none.v
	./src/krnl_dual_fifo.v
}
# Kernel XML definition
set krnl_xml "./kernel.xml"
