package LWC_TB_SCA_wrapper_conf_pkg is
    constant XRW : natural := 0;
end package;


use work.LWC_TB_SCA_wrapper_conf_pkg.all;

configuration LWC_TB_SCA_wrapper_conf of LWC_TB is
    for TB
        for all : LWC_SCA
            use entity work.LWC_SCA_wrapper
            generic map(
                XRW => XRW,
                XW => W,
                FIFOS_OUT_REG => FALSE
            )
            port map(
                clk       => clk,
                rst       => rst,
                pdi_data  => pdi_data_delayed,
                pdi_valid => pdi_valid_delayed,
                pdi_ready => pdi_ready,
                sdi_data  => sdi_data_delayed,
                sdi_valid => sdi_valid_delayed,
                sdi_ready => sdi_ready,
                do_data   => do_data,
                do_last   => do_last,
                do_valid  => do_valid,
                do_ready  => do_ready_delayed,
                rdi_data  => rdi_data_delayed(XRW - 1 downto 0),
                rdi_valid => rdi_valid_delayed,
                rdi_ready => rdi_ready
            );
        end for;

    end for;
end configuration;