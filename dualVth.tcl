proc dualVth {args} {
	parse_proc_arguments -args $args results
	set savings $results(-savings)

	#################################
	### INSERT YOUR COMMANDS HERE ###
	#################################

	#set start_time [clock milliseconds]
	suppress_message NED-045
	suppress_message LNK-041
	suppress_message LNK-005
	suppress_message PTE-018
	suppress_message PWR-601
	suppress_message PWR-246
	proc cells_swapping { cell_list vt_type } {
	
		set lvt_lib  "CORE65LPLVT_nom_1.20V_25C.db:CORE65LPLVT/"
		set hvt_lib  "CORE65LPHVT_nom_1.20V_25C.db:CORE65LPHVT/"
	
	
		if { [regexp -all "LVT" $vt_type] } {
		
			foreach cell $cell_list {
				set cell_refname [get_attribute [get_cell $cell] ref_name]
				if { ![regexp "_LL" $cell_refname ] } { 
					regsub  {_LH} $cell_refname "_LL" cell_sw
					size_cell $cell $lvt_lib$cell_sw
				}
			}
		} else {
				
				foreach cell $cell_list {
					set cell_refname [get_attribute [get_cell $cell] ref_name]
					if { ![regexp "_LH" $cell_refname ] } {
						regsub {_LL} $cell_refname "_LH" cell_sw
						size_cell $cell $hvt_lib$cell_sw
					}
				}
			}
	
	
	
	}
	
	proc extract_leak {} {
	set pow 0.0
	set pow_tmp 0.0
	foreach_in_collection cell_pt [get_cells] {
        	set pow_tmp [get_attribute $cell_pt leakage_power]
        	set pow [expr $pow + $pow_tmp]
	}
	return $pow
	}
	
	
	set start_power 0.0
	set end_power 0.0
	set list_full_name ""
	set list_leak_pow_lvt  ""
	set list_arrtime_lvt   ""
	set index_table  ""
	
	set list_leak_pow_hvt  ""
	set list_arrtime_hvt   ""
	
	set sorted_cell_list ""
	
	foreach_in_collection cell_pt [get_cell] {
		set cell_fn [get_attribute $cell_pt full_name]
		lappend list_full_name  $cell_fn
		lappend list_leak_pow_lvt [get_attribute $cell_pt leakage_power]
		lappend list_arrtime_lvt  [get_attribute [ get_timing_paths -through "$cell_fn/Z" ] arrival]
	}
	
	
	cells_swapping $list_full_name HVT
	set end_power [extract_leak]
	
	foreach cell_pt $list_full_name {
		

		lappend list_leak_pow_hvt [get_attribute [get_cell $cell_pt] leakage_power]
		lappend list_arrtime_hvt  [get_attribute [ get_timing_paths -through "$cell_pt/Z" ] arrival]
	}
	
	cells_swapping $list_full_name LVT
	
	set start_power [extract_leak]
	#puts "this is the start power $start_power"	
	set ll [llength $list_full_name]
	set k 0
	set k_list ""
	set delta_leak_pow 0.0
	set delta_arr_time 0.0
	set cur_lvt_leak 0.0
	set cur_hvt_leak 0.0
	set cur_lvt_arr  0.0
	set cur_hvt_arr  0.0
	
	for {set i 0} {$i < $ll} {incr i} {
		set cur_hvt_leak [lindex $list_leak_pow_hvt $i]
		set cur_lvt_leak [lindex $list_leak_pow_lvt $i]
		set cur_hvt_arr  [lindex $list_arrtime_hvt $i]
		set cur_lvt_arr  [lindex $list_leak_pow_hvt $i]
		set delta_arr_time [expr $cur_hvt_arr - $cur_lvt_arr]
		set delta_leak_pow [expr $cur_hvt_leak - $cur_lvt_leak]
		set k [expr $delta_leak_pow/$delta_arr_time]
		lappend k_list $k
	}
	
	for {set j 0} {$j < $ll} {incr j} {
		set temp_list ""
		lappend temp_list [lindex $list_full_name $j]
		lappend temp_list [lindex $k_list $j]
		lappend index_table $temp_list
	}
	
	set index_table_sorted [lsort -real -increasing -index 1 $index_table]
	
	foreach tab_element $index_table_sorted {
		lappend sorted_cell_list [lindex $tab_element 0]
	}
	
	
	
	set delta_pow [expr $start_power - $end_power] 
	set max_savings [expr $delta_pow/$start_power]
	
	if { $savings > $max_savings } {
		puts "minimun of leakage power in range 0-$max_savings"
		return 0
	} else {	
		
		set start 0
		set end [expr $ll-1]
		set hvt 1
		set step_back 1
		set step_forward 0
		set curr_savings 0.0
		set average [expr ($start + $end)/2]
		
		while {1} {
		
			if { $hvt } {
			
				set cell_list_temp [lrange $sorted_cell_list $start $average]
				cells_swapping $cell_list_temp HVT
				set end_power [extract_leak]
				set delta_pow [ expr $start_power - $end_power]
				set curr_savings [expr $delta_pow/$start_power]
			}
		
			if { $savings==$curr_savings} {
				break;
			}
		
			if {$curr_savings>$savings} {
		
				if {$start == $average} {
					#puts "this is the end power $end_power"
					break;
				} else {
						if {$step_back} {
							set end $average
							set step_back 0
						} else {
							set end [expr $average -1]
						}
					set average [expr ($start + $end)/2]
					set hvt 0
					set cell_list_temp [lrange $sorted_cell_list $average $end]
					cells_swapping $cell_list_temp LVT
					set end_power [extract_leak]
					set delta_pow [ expr $start_power - $end_power]
					set curr_savings [expr $delta_pow/$start_power]
					set step_forward 1
				}
			} else {
					if {$step_forward} {
						set start $average
						set step_forward 0
					} else {
							set start [expr $average + 1]
						}
					set average [expr ($start + $end)/2]
					set hvt 1
					set step_back 1
			}
		}
	}                                                                                
	
					
	
	#set end_time [clock milliseconds]
	#puts " execution time [expr ($end_time - $start_time)/1000.0] sec "
	return   
}

define_proc_attributes dualVth \
-info "Post-Synthesis Dual-Vth cell assignment" \
-define_args \
{
	{-savings "minimum % of leakage savings in range [0, 1]" lvt float required}
}
