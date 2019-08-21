if {[tapasco::is_feature_enabled "HSA"]} {
    proc create_custom_subsystem_hsa {{args {}}} {
        set vlnv_package_processor "fau.de:hsa:accelerator_backend:1.0"
        set dir "$::env(FAU_HOME)"
        if { $dir eq "" } {
            puts "\[PLUGIN HSA\] FAU_HOME dir is not set."
            exit 1
        }

        set s_axi_host [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 "S_HSA"]
        set axi_host [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 "M_HSA_HOST"]
        set axi_mem [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 "M_MEM_HSA"]

        set repos [get_property ip_repo_paths [current_project]]
        set dirs [split $dir ":"]
        foreach path $dirs {
            puts "\[PLUGIN HSA\] Adding directory $path to IP-Repository-Cache"
            set repos [lappend repos $path]
        }
        set_property  ip_repo_paths $repos [current_project]
        update_ip_catalog

        # IP
        puts "\[PLUGIN HSA\] Creating IP"
        set wrapper [tapasco::ip::create_hsa_wrapper "HSAWrapper"]
        set accelerator [create_bd_cell -type ip -vlnv $vlnv_package_processor "HSAAccelerator"]
        puts "\[PLUGIN HSA\] Done creating IP"

        # Interconnects
        puts "\[PLUGIN HSA\] Creating interconnects"
        set to_ddr [tapasco::ip::create_axi_sc "to_ddr" 3 1]
        tapasco::ip::connect_sc_default_clocks $to_ddr "design"

        set from_host [tapasco::ip::create_axi_sc "from_host" 1 2]
        tapasco::ip::connect_sc_default_clocks $from_host "host"

        set to_pcie [tapasco::ip::create_axi_sc "to_pcie" 2 1]
        tapasco::ip::connect_sc_default_clocks $to_pcie "host"

        set to_wrapper [tapasco::ip::create_axi_sc "to_wrapper" 2 1]
        tapasco::ip::connect_sc_default_clocks $to_wrapper "design"

        set to_wrapper_acc [tapasco::ip::create_axi_sc "to_wrapper_acc" 2 1]
        tapasco::ip::connect_sc_default_clocks $to_wrapper_acc "design"
        puts "\[PLUGIN HSA\] Done creating interconnects"

        # AXI Connections
        puts "\[PLUGIN HSA\] Connecting AXI"
        connect_bd_intf_net [get_bd_intf_pins $from_host/M00_AXI] [get_bd_intf_pins $wrapper/squeue_axi]
        connect_bd_intf_net [get_bd_intf_pins $to_ddr/S00_AXI] [get_bd_intf_pins $wrapper/mddr_axi]
        connect_bd_intf_net [get_bd_intf_pins $to_ddr/S01_AXI] [get_bd_intf_pins $wrapper/mdma_ddr_axi]
        connect_bd_intf_net [get_bd_intf_pins $wrapper/mdma_pcie_axi] [get_bd_intf_pins $to_pcie/S00_AXI]
        connect_bd_intf_net [get_bd_intf_pins $wrapper/mpcie_axi] [get_bd_intf_pins $to_pcie/S01_AXI]
        connect_bd_intf_net [get_bd_intf_pins $accelerator/M_CMD_AXI] [get_bd_intf_pins $to_wrapper_acc/S00_AXI]
        connect_bd_intf_net [get_bd_intf_pins $to_wrapper_acc/M00_AXI] [get_bd_intf_pins $wrapper/swrapper_axi_acc]
        connect_bd_intf_net [get_bd_intf_pins $from_host/M01_AXI] [get_bd_intf_pins $to_wrapper/S00_AXI]
        connect_bd_intf_net [get_bd_intf_pins $to_wrapper/M00_AXI] [get_bd_intf_pins $wrapper/swrapper_axi_host]
        connect_bd_intf_net [get_bd_intf_pins $accelerator/M_DATA_AXI] [get_bd_intf_pins $to_ddr/S02_AXI]
        connect_bd_intf_net [get_bd_intf_pins $axi_mem] [get_bd_intf_pins $to_ddr/M00_AXI]
        connect_bd_intf_net [get_bd_intf_pins $axi_host] [get_bd_intf_pins $to_pcie/M00_AXI]
        connect_bd_intf_net [get_bd_intf_pins $s_axi_host] [get_bd_intf_pins $from_host/S00_AXI]
        puts "\[PLUGIN HSA\] Done with AXI"

        # Interrupts
        puts "\[PLUGIN HSA\] Connecting Interrupts"
        connect_bd_net [get_bd_pins $accelerator/tp_halt] [get_bd_pins $wrapper/pe_halt]
        connect_bd_net [get_bd_pins $accelerator/rcv_aql_irq] [get_bd_pins $wrapper/rcv_aql_irq]
        connect_bd_net [get_bd_pins $accelerator/rcv_cpl_irq] [get_bd_pins $wrapper/rcv_cpl_irq]
        connect_bd_net [get_bd_pins $accelerator/rcv_dma_irq] [get_bd_pins $wrapper/rcv_dma_irq]
        connect_bd_net [get_bd_pins $accelerator/snd_cpl_irq_ack] [get_bd_pins $wrapper/snd_cpl_irq_ack]
        connect_bd_net [get_bd_pins $accelerator/snd_dma_irq_ack] [get_bd_pins $wrapper/snd_dma_irq_ack]
        connect_bd_net [get_bd_pins $accelerator/rcv_aql_irq_ack] [get_bd_pins $wrapper/rcv_aql_irq_ack]
        connect_bd_net [get_bd_pins $accelerator/rcv_cpl_irq_ack] [get_bd_pins $wrapper/rcv_cpl_irq_ack]
        connect_bd_net [get_bd_pins $accelerator/rcv_dma_irq_ack] [get_bd_pins $wrapper/rcv_dma_irq_ack]
        connect_bd_net [get_bd_pins $accelerator/snd_cpl_irq] [get_bd_pins $wrapper/snd_cpl_irq]
        connect_bd_net [get_bd_pins $accelerator/snd_dma_irq] [get_bd_pins $wrapper/snd_dma_irq]

        connect_bd_net [get_bd_pins $accelerator/rcv_add_irq] [get_bd_pins $wrapper/rcv_add_irq]
        connect_bd_net [get_bd_pins $accelerator/rcv_rem_irq] [get_bd_pins $wrapper/rcv_rem_irq]
        connect_bd_net [get_bd_pins $accelerator/snd_add_irq_ack] [get_bd_pins $wrapper/snd_add_irq_ack]
        connect_bd_net [get_bd_pins $accelerator/snd_rem_irq_ack] [get_bd_pins $wrapper/snd_rem_irq_ack]
        connect_bd_net [get_bd_pins $accelerator/rcv_add_irq_ack] [get_bd_pins $wrapper/rcv_add_irq_ack]
        connect_bd_net [get_bd_pins $accelerator/rcv_rem_irq_ack] [get_bd_pins $wrapper/rcv_rem_irq_ack]
        connect_bd_net [get_bd_pins $accelerator/snd_add_irq] [get_bd_pins $wrapper/snd_add_irq]
        connect_bd_net [get_bd_pins $accelerator/snd_rem_irq] [get_bd_pins $wrapper/snd_rem_irq]
        puts "\[PLUGIN HSA\] Done connecting interrupts"

        puts "\[PLUGIN HSA\] Fix outside world connections"
        set pcie_aclk [tapasco::subsystem::get_port "host" "clk"]
        set pcie_aresetn [tapasco::subsystem::get_port "host" "rst" "peripheral" "resetn"]
        set design_aclk [tapasco::subsystem::get_port "design" "clk"]
        set design_aresetn [tapasco::subsystem::get_port "design" "rst" "peripheral" "resetn"]
        set mem_aclk [tapasco::subsystem::get_port "mem" "clk"]
        set mem_aresetn [tapasco::subsystem::get_port "mem" "rst" "peripheral" "resetn"]

        connect_bd_net $pcie_aclk [get_bd_pins -of_objects $wrapper -filter {NAME == "mdma_pcie_axi_aclk"}]
        connect_bd_net $pcie_aresetn [get_bd_pins -of_objects $wrapper -filter {NAME == "mdma_pcie_axi_aresetn"}]

        connect_bd_net $mem_aclk [get_bd_pins -of_objects $wrapper -filter {NAME == "mdma_ddr_axi_aclk"}]
        connect_bd_net $mem_aresetn [get_bd_pins -of_objects $wrapper -filter {NAME == "mdma_ddr_axi_aresetn"}]

        connect_bd_net $design_aclk [get_bd_pins -of_objects $wrapper -filter {NAME == "s_axi_aclk"}]
        connect_bd_net $design_aresetn [get_bd_pins -of_objects $wrapper -filter {NAME == "s_axi_aresetn"}]

        connect_bd_net $design_aclk [get_bd_pins -of_objects $accelerator -filter {NAME == "clk"}]
        connect_bd_net $design_aresetn [get_bd_pins -of_objects $accelerator -filter {NAME == "rstn"}]
        puts "\[PLUGIN HSA\] Outside world connected"

        # Fix connections to upstream interconnects
        set inst [current_bd_instance -quiet .]
        current_bd_instance -quiet

        puts "\[PLUGIN HSA\] Connecting outside world AXI and Interrupts"

        set m_si [create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 host/M_HSA]

        set num_mi_old [get_property CONFIG.NUM_MI [get_bd_cells host/out_ic]]
        set num_mi [expr "$num_mi_old + 1"]
        set_property -dict [list CONFIG.NUM_MI $num_mi] [get_bd_cells host/out_ic]
        connect_bd_intf_net $m_si [get_bd_intf_pins host/out_ic/[format "M%02d_AXI" $num_mi_old]]

        set s_si [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 host/S_HSA_HOST]

        set num_si_old [get_property CONFIG.NUM_SI [get_bd_cells host/in_ic]]
        set num_si [expr "$num_si_old + 1"]
        set_property -dict [list CONFIG.NUM_SI $num_si] [get_bd_cells host/in_ic]
        connect_bd_intf_net $s_si [get_bd_intf_pins host/in_ic/[format "S%02d_AXI" $num_si_old]]

        set s_si [create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 memory/S_MEM_HSA]

        set num_si_old [get_property CONFIG.NUM_SI [get_bd_cells memory/mig_ic]]
        set num_si [expr "$num_si_old + 1"]
        set_property -dict [list CONFIG.NUM_SI $num_si] [get_bd_cells memory/mig_ic]
        connect_bd_intf_net $s_si [get_bd_intf_pins memory/mig_ic/[format "S%02d_AXI" $num_si_old]]

        disconnect_bd_net /intc/irq_unused_dout [get_bd_pins intc/interrupt_concat/In2]
        connect_bd_net [get_bd_pins hsa/HSAWrapper/hsa_signal_interrupt] [get_bd_pins intc/interrupt_concat/In2]

        current_bd_instance -quiet $inst
        puts "\[PLUGIN HSA\] Plugin HSA instantiated"

        return {}
    }
}

namespace eval hsa {
  namespace export addressmap

  proc addressmap {args} {
    if {[tapasco::is_feature_enabled "HSA"]} {
        set max64 [expr "1 << 64"]
        set args [lappend args "M_HSA_HOST" [list 0 0 $max64 ""]]
        set args [lappend args "M_MEM_HSA" [list 0 0 $max64 ""]]
        set args [lappend args "M_HSA" [list 0 0 0 ""]]
    }
    return $args
  }

    proc set_pblocks {args} {
        if {[tapasco::is_feature_enabled "HSA"]} {
            create_pblock pblock_HSAWrapper
            resize_pblock pblock_HSAWrapper -add {SLICE_X92Y215:SLICE_X165Y424 DSP48_X6Y86:DSP48_X14Y169 RAMB18_X6Y86:RAMB18_X10Y169 RAMB36_X6Y43:RAMB36_X10Y84}
            add_cells_to_pblock pblock_HSAWrapper [get_cells [list system_i/hsa/HSAWrapper]]
        }
        return $args
    }
}

tapasco::register_plugin "platform::hsa::addressmap" "post-address-map"
tapasco::register_plugin "platform::hsa::set_pblocks" "post-synth"
