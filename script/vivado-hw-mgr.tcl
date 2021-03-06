open_hw_manager
connect_hw_server -allow_non_jtag
open_hw_target -xvc_url localhost:10200

set probeFile {./hw_build/endianess_trial.ltx}
set debugBridges [get_hw_devices debug_bridge_0]
set_property PROBES.FILE $probeFile $debugBridges
set_property FULL_PROBES.FILE $probeFile $debugBridges
refresh_hw_device [lindex $debugBridges 0]
display_hw_ila_data [ get_hw_ila_data hw_ila_data_1 -of_objects [get_hw_ilas \
    -of_objects $debugBridges -filter {CELL_NAME=~"pfm_top_i/dynamic_region/system_ila_0/inst/ila_lib"}]]
