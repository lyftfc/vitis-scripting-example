############################################
# Helper procedure from package_kernel.tcl #
############################################

proc edit_core {core frequency user_interfaces} {
	foreach usrintf $user_interfaces {
		::ipx::associate_bus_interfaces -busif $usrintf -clock "ap_clk" $core
	}
	::ipx::associate_bus_interfaces -busif "s_axi_control" -clock "ap_clk" $core

	# Specify the freq_hz parameter 
	set clkbif      [::ipx::get_bus_interfaces -of $core "ap_clk"]
	set clkbifparam [::ipx::add_bus_parameter -quiet "FREQ_HZ" $clkbif]
	# Set desired frequency                   
	set_property value $frequency $clkbifparam
	# set value_resolve_type 'user' if the frequency can vary. 
	set_property value_resolve_type user $clkbifparam
	# set value_resolve_type 'immediate' if the frequency cannot change. 
	# set_property value_resolve_type immediate $clkbifparam
	set mem_map    [::ipx::add_memory_map -quiet "s_axi_control" $core]
	set addr_block [::ipx::add_address_block -quiet "reg0" $mem_map]

	set reg      [::ipx::add_register "NO_CTRL" $addr_block]
	set_property description    "No control signals (reserved)"    $reg
	set_property address_offset 0x000 $reg
	set_property size           32    $reg
	set_property slave_memory_map_ref "s_axi_control" [::ipx::get_bus_interfaces -of $core "s_axi_control"]

	set_property xpm_libraries {XPM_CDC XPM_MEMORY XPM_FIFO} $core
	set_property sdx_kernel true $core
	set_property sdx_kernel_type rtl $core
}

proc package_project {path_to_packaged kernel_vendor kernel_library kernel_name frequency user_interfaces user_parameters} {
	set core [::ipx::package_project -root_dir $path_to_packaged -vendor $kernel_vendor -library $kernel_library -taxonomy "/KernelIP" -import_files -set_current false ]
	foreach user_param $user_parameters {
		::ipx::remove_user_parameter $user_param $core
	}
	::ipx::create_xgui_files $core
	set_property supported_families { } $core
	set_property auto_family_support_level level_2 $core
	set_property used_in {out_of_context implementation synthesis} [::ipx::get_files -type xdc -of_objects [::ipx::get_file_groups "xilinx_anylanguagesynthesis" -of_objects $core] *_ooc.xdc]
	edit_core $core $frequency $user_interfaces
	::ipx::update_checksums $core
	::ipx::check_integrity -kernel $core
	::ipx::save_core $core
	::ipx::unload_core $core
	unset core
}

###################
# Vivado Commands #
###################

set prj_name "${krnl_name}_packprj"
create_project -force -part $hw_part -rtl_kernel $prj_name "./${prj_name}"

file mkdir "./${prj_name}/imports"
set ooc_constr_path "./${prj_name}/imports/${krnl_name}_ooc.xdc"
set ooc_constr [open $ooc_constr_path w]
set clk_period [expr {1.0e9 / $krnl_freq}]
puts $ooc_constr "create_clock -period $clk_period \[get_ports ap_clk\]"
close $ooc_constr

set_property board_part $hw_board [current_project]
add_files -fileset sources_1 -norecurse $krnl_srcs
add_files -fileset constrs_1 -norecurse $ooc_constr_path
update_compile_order -fileset sources_1
package_project "./${prj_name}/${krnl_name}" $krnl_vendor kernel $krnl_name $krnl_freq $krnl_intfs $krnl_params
package_xo -xo_path "./${prj_name}/${krnl_name}.xo" -kernel_name ${krnl_name} -ip_directory "./${prj_name}/${krnl_name}" -kernel_xml $krnl_xml

