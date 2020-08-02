The following instruction provides a step-by-step guide into preparing a shared
library for use with cryptotvgen using prepare_src utility. The instruction
assumes that all build environment is setup correctly.

### Requirements

- python3 >= 3.6
- SUPERCOP directory: Setup of SUPERCOP maybe required(see Notes)

### Notes
The `LWC/software/prepare_src/include` directory comes from the SUPERCOP
`supercop/bench/*/include`. It does not contain the sub directories that
are typically found in that directory. If the desired algorithm does not
build its lib out of the box by following the steps below. These directories
may need to the include path in the Makefile.
This could be accomplished by updating the include path highlighted in
the Makefile with text `UPDATE REQUIRED?`.

If the supercop/bench/*/include directory does not exist it is
suggested that the SUPERCOP do-part script is used to generate it.
Example:
    > do-part init
    > do-part crypto_aead acorn128

Step 1: Prepare SUPERCOP source code using prepare_src utility.

    This step searches all crypto_aead and crypto_hash folder inside SUPERCOP
    directory and look for a reference (ref) implemetation of an algorithm.
    The reference code are copied to a work directory. SUPERCOP software API
    funtion declaration identifier is modified during this process to include
    is slightly modified to include export identifier.
    It then modify function declaration specifier of SUPERCOP software API to
    include additional identifier. Finally, it creates Makefile.paths pointing
    to all prepared reference algorithm.

    > python3 prepare_src.py -p <PATH>
    e.g.
    > python3 prepare_src.py -p ..

Step 2: Modify generated Makefile.paths

    Most of the time, user likely interest only a single algorithm. Modify
    Makefile.paths only to the target algorithm of interest. Make sure to
    remove any trailing spaces.

    > vi Makefile.paths

Step 3: Generate shared library

    > make -j 16 -k > log.make
