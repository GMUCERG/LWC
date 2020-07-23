The following instruction provides a step-by-step guide into preparing a shared library for use with cryptotvgen using prepare_src utility. The instruction assumes that all build environment is setup correctly.

Step 1: Prepare SUPERCOP source code using prepare_src utility.

    This step searches all crypto_aead and crypto_hash folder inside SUPERCOP directory and look for a reference (ref) implemetation of an algorithm.
    The reference code are copied to a work directory. SUPERCOP software API funtion declaration identifier is modified during this process to include is slightly modified to include export identifie
    It then modify function declaration specifier of SUPERCOP software API to include additional identifier. Finally, it creates Makefile.paths pointing to all prepared reference algorithm.

    > python3 prepare_src.py -p <PATH>
    e.g.
    > python3 prepare_src.py -p ..

Step 2: Modify generated Makefile.paths

    Most of the time, user likely interest only a single algorithm. Modify Makefile.paths only to the target algorithm of interest. Make sure to remove any trailing spaces.

    > vi Makefile.paths

Step 3: Generate shared library

    > make -j 16 -k > log.make
