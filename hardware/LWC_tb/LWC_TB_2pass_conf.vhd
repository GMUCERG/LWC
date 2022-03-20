configuration LWC_TB_2Pass_conf of LWC_TB is
    for TB
        for uut : LWC
            use entity work.LWC_TB_2Pass_uut; -- either RTL or Verilog netlist
        end for;
    end for;
end configuration;