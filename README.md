LWC HARDWARE API
==============

This is a development package for the GMU authenticated encryption hardware API.
This package is divided into two primary parts, hardware and software.


Hardware
-----------

`$root/hardware`

Templates for CryptoCore and design_pkg.

* `./LWCsrc`

    Universal Pre- and Post-processors and the associated testbench.
    
*  `./dummy_lwc`
   
    Example implementation of a dummy authenticated cipher and hash function. 

    The full source list required to implement and simulate the design can be found in the ModelSim script located in the /scripts folder.
    Note: It is recommended to use the provided ModelSim script for a quick evaluation of the design.

    * `./src_rtl`
   
        Code that is required for implementation.
        
    * `./KAT`
    
        Known-Answer-Test files folder.

        * `./KAT_{8,16,32}`
    
            Known-Answer-Test files for a 8, 16, and 32 bus width
           
        * `./KAT_MS_{8,16,32}`
    
            Known-Answer-Test files with multiple segments for
            plaintext, ciphertext, associated data and hash message


    * `./scripts`
    
        ModelSim script for a quick simulation.
        Vivado script for a quick simulation.


Software
----------

* `$root/software/crypto_aead`

    Folder follows SUPERCOP package structure.
    It contains the dummy reference implementation for AEAD.
    
* `$root/software/crypto_hash`

    Folder follows SUPERCOP package structure. It contains the dummy reference implementation for hash.
    
    User should obtain the latest reference code from [SUPERCOP's website](https://bench.cr.yp.to/supercop.html) and place relevant implementation in the above locations.
    
* `$root/software/prepare_src`

  A Python utility to help prepare code from `$root/software/crypto_aead` and `$root/software/crypto_hash` for test vector generation.
    
* `$root/software/cryptotvgen`

   Python package for the cryptographic hardware test vector generation tool.

Notes
------

Please refer to the latest Implementer’s Guide to the LWC Hardware API
available at https://cryptography.gmu.edu/athena/index.php?id=LWC
for more detail.
