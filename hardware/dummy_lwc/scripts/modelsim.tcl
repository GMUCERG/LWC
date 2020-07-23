set INTERFACE_REPO "../../LWCsrc"
set TOP_LEVEL_NAME LWC_TB
set STOP_AT_FAULT True
set CUSTOM_DO_FILE "wave.do"

# ----------------------------------------
# Set implementation files
set src_vhdl [subst {
    "../src_rtl/design_pkg.vhd"
    "$INTERFACE_REPO/NIST_LWAPI_pkg.vhd"
    "../src_rtl/SPDRam.vhd"
    "$INTERFACE_REPO/StepDownCountLd.vhd"
    "../src_rtl/CryptoCore.vhd"
    "$INTERFACE_REPO/data_piso.vhd"
    "$INTERFACE_REPO/key_piso.vhd"
    "$INTERFACE_REPO/data_sipo.vhd"
    "$INTERFACE_REPO/PreProcessor.vhd"
    "$INTERFACE_REPO/PostProcessor.vhd"
    "$INTERFACE_REPO/fwft_fifo.vhd"
    "$INTERFACE_REPO/LWC.vhd"
}]

# ----------------------------------------
# Set simulation files
set tb_vhdl [subst {
    "$INTERFACE_REPO/std_logic_1164_additions.vhd"
    "$INTERFACE_REPO/$TOP_LEVEL_NAME.vhd"
}]

# ----------------------------------------
# Python interface for creating a distro
proc get_src {src}  {return $src}

# ----------------------------------------
# Create compilation libs
proc ensure_lib { lib } { if ![file isdirectory $lib] { vlib $lib } }
ensure_lib          ./libs/
ensure_lib          ./libs/work/
vmap       work     ./libs/work/

# ----------------------------------------
# Compile implementation files
alias imp_com {
    echo "imp_com"
    foreach f $src_vhdl {vcom -quiet -work work $f}
}

# ----------------------------------------
# Compile simulation files
alias sim_com {
    echo "sim_com"
    foreach f $tb_vhdl {vcom -quiet -work work $f}
}

# ----------------------------------------
# Compile simulation files
alias com {
    echo "com"
    imp_com
    sim_com
}

# ----------------------------------------
# Add wave form and run
alias run_wave {
    echo "\[exec\] run_wave"
    add wave -group PreProcessor  -ports     -radix hexadecimal $TOP_LEVEL_NAME/uut/Inst_PreProcessor/*
    add wave -group PreProcessor  -internals -radix hexadecimal $TOP_LEVEL_NAME/uut/Inst_PreProcessor/*
    add wave -group CipherCore    -ports     -radix hexadecimal $TOP_LEVEL_NAME/uut/Inst_Cipher/*
    add wave -group CipherCore    -internals -radix hexadecimal $TOP_LEVEL_NAME/uut/Inst_Cipher/*
    add wave -group PostProcessor -ports     -radix hexadecimal $TOP_LEVEL_NAME/uut/Inst_PostProcessor/*
    add wave -group PostProcessor -internals -radix hexadecimal $TOP_LEVEL_NAME/uut/Inst_PostProcessor/*
    ## add wave forms for 32 bit implementation
    add wave -group PostProcessor -internals -radix hexadecimal $TOP_LEVEL_NAME/uut/Inst_PostProcessor/FSM_32BIT/*
    add wave -group PreProcessor  -internals -radix hexadecimal $TOP_LEVEL_NAME/uut/Inst_PreProcessor/FSM_32BIT/*
    ## add wave forms for 32 bit PISOs and SIPO
    add wave -group PostProcessor -group bdoSIPO -ports     -radix hexadecimal $TOP_LEVEL_NAME/uut/Inst_PostProcessor/FSM_32BIT/bdoSIPO/*
    add wave -group PostProcessor -group bdoSIPO -internals -radix hexadecimal $TOP_LEVEL_NAME/uut/Inst_PostProcessor/FSM_32BIT/bdoSIPO/*
    add wave -group PreProcessor  -group keyPISO -ports     -radix hexadecimal $TOP_LEVEL_NAME/uut/Inst_PreProcessor/FSM_32BIT/keyPISO/*
    add wave -group PreProcessor  -group keyPISO -internals -radix hexadecimal $TOP_LEVEL_NAME/uut/Inst_PreProcessor/FSM_32BIT/keyPISO/*
    add wave -group PreProcessor  -group bdiPISO -ports     -radix hexadecimal $TOP_LEVEL_NAME/uut/Inst_PreProcessor/FSM_32BIT/bdiPISO/*
    add wave -group PreProcessor  -group bdiPISO -internals -radix hexadecimal $TOP_LEVEL_NAME/uut/Inst_PreProcessor/FSM_32BIT/bdiPISO/*
    ## add wave forms for 16 bit implementation
    #add wave -group PostProcessor -internals -radix hexadecimal $TOP_LEVEL_NAME/uut/Inst_PostProcessor/FSM_16BIT/*
    #add wave -group PreProcessor  -internals -radix hexadecimal $TOP_LEVEL_NAME/uut/Inst_PreProcessor/FSM_16BIT/*
    ## add wave forms for 8 bit implementation
    #add wave -group PostProcessor -internals -radix hexadecimal $TOP_LEVEL_NAME/uut/Inst_PostProcessor/FSM_8BIT/*
    #add wave -group PreProcessor  -internals -radix hexadecimal $TOP_LEVEL_NAME/uut/Inst_PreProcessor/FSM_8BIT/*


    # Configure wave panel
    configure wave -namecolwidth 180
    configure wave -valuecolwidth 200
    configure wave -signalnamewidth 1
    configure wave -timelineunits ns
    WaveRestoreZoom {0 ps} {2000 ns}
    configure wave -justifyvalue right
    configure wave -rowmargin 8
    configure wave -childrowmargin 5
}


# ----------------------------------------
# Compile all the design files and elaborate the top level design
alias ldd {
    com
    set run_do_file [file isfile $CUSTOM_DO_FILE]
    if {$run_do_file == 1} {
        vsim -t ps -L work $TOP_LEVEL_NAME -do $CUSTOM_DO_FILE  -gG_STOP_AT_FAULT=$STOP_AT_FAULT
    } else {
      vsim -t ps -L work $TOP_LEVEL_NAME -gG_STOP_AT_FAULT=$STOP_AT_FAULT
      run_wave
    }
    run 500 us
}

# ----------------------------------------
# Print out user commmand line aliases
alias h {
    echo "List Of Command Line Aliases"
    echo
    echo "imp_com                       -- Compile implementation files"
    echo
    echo "sim_com                       -- Compile simulation files"
    echo
    echo "com                           -- Compile files in the correct order"
    echo
    echo "ldd                           -- Compile and run"
    echo
}
h
