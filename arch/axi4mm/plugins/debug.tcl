#
# Copyright (C) 2017 Jens Korinth, TU Darmstadt
#
# This file is part of Tapasco (TPC).
#
# Tapasco is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Tapasco is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with Tapasco.  If not, see <http://www.gnu.org/licenses/>.
#
# @file   mb_shifter.tcl
# @brief  Plugin to insert the MicroBlaze Debug Module (MDM) for all DEBUG ports
#         found in the Architecture.
# @author J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
#
namespace eval debug {
  proc debug_feature {args} {
    if {[tapasco::is_feature_enabled "Debug"]} {
      # set defaults
      set depth       1024
      set stages      0
      set interfaces  {}

      set debug [tapasco::get_feature "Debug"]
      puts "Debug feature enabled: $debug"
      dict with debug {
        set num_ifs [llength $interfaces]
        if {$num_ifs > 0} {
          set i 0
          foreach ifs $interfaces {
            puts "   found interface def: $ifs"
            if {[llength $ifs] == 3} {
              set s_ila [tapasco::ip::create_system_ila "SILA_$i" $num_ifs $depth $stages]
              puts "  create System ILA SILA_$i for $num_ifs interfaces with depth $depth and $stages stages"
              set intf [get_bd_intf_pins [lindex $ifs 0]]
              set clk [get_bd_pins [lindex $ifs 1]]
              set rst [get_bd_pins [lindex $ifs 2]]
              puts "  connecting $intf to port #$i, clock to $clk, reset to $rst ..."
              connect_bd_intf_net $intf [get_bd_intf_pins "$s_ila/SLOT_${i}_AXI"]
              connect_bd_net $clk [get_bd_pins -of_objects $s_ila -filter {TYPE == clk && DIR == I}]
              connect_bd_net $rst [get_bd_pins -of_objects $s_ila -filter {TYPE == rst && DIR == I}]
              incr i
            } else {
              error "expected three elements for debugging interface: interface, clock and reset; found: $ifs"
            }
          }
        }
      }
    }
  }
}

tapasco::register_plugin "arch::debug::debug_feature" "pre-wrapper"
