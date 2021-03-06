if { $::argc eq 0 } {
    puts "Usage: vivado -source vivado-read-ila.tcl -tclargs <ila_file>"
} else {
    set ilaFile [lindex $::argv 0]
    open_hw_manager
    read_hw_ila_data $ilaFile
    display_hw_ila_data
}