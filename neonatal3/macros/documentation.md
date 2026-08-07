
#Memory1
/arm_pdk/tsmc/cln65gplus/rf_sp_hdd_svt_rvt_hvt/r0p0/bin/rf_sp_hdd_svt_rvt_hvt &


#Memory2
/arm_pdk/tsmc/cln65gplus/sram_sp_hdc_svt_rvt_hvt/r0p0-00eac0/bin/sram_sp_hdc_svt_rvt_hvt &


# ASIC Memory Generation & Integration Guide
**Technology:** TSMC 65nm  
**Memory Vendor:** ARM Artisan Physical IP  

## 1. Introduction: Why use a Memory Compiler?
In an FPGA or a quick university project, memories are often written in behavioral Verilog (e.g., `reg [31:0] mem [0:511]`). Synthesis tools (like Cadence Genus) will synthesize these arrays into thousands of individual standard-cell flip-flops. 

* **The Problem:** Flip-flop arrays consume massive amounts of silicon area and power, and cause severe routing congestion in physical design (Innovus).
* **The ASIC Solution:** We treat memories as **Hard Macros**. We use a foundry-specific Memory Compiler (e.g., ARM Artisan) to generate highly optimized, dense SRAM/Register File blocks. The synthesis and PnR tools treat these blocks as "black boxes" and simply route wires to their pins.

## 2. Decoding the ARM Artisan Nomenclature
When you look at the compiler executable name (e.g., `rf_sp_hdd_svt_rvt_hvt`), it tells you the exact physical and electrical properties of the memory macro it will generate:

* **`rf` vs `sram` (Architecture):**
  * **`rf` (Register File):** Optimized for shallow depths (e.g., 16 to 2048 words). Uses a different internal sensing and layout structure to be extremely fast and area-efficient for small data buffers.
  * **`sram` (Static RAM):** Optimized for deeper memory arrays (e.g., 256 to 16,384+ words). 
* **`sp` vs `dp` (Port Configuration):**
  * **`sp` (Single-Port):** Has one shared address bus. You can either Read OR Write in a single clock cycle, but not both at the same time.
  * **`dp` (Dual-Port):** Has two independent address buses (Port A and Port B). You can Read and Write simultaneously to different addresses without contention.
* **`hdd` / `hdc` (Density/Speed Target):**
  * **`hd` (High Density):** The bitcells are squeezed as tightly as possible to save silicon area, at a slight cost to maximum frequency.
  * **`hs` (High Speed):** The bitcells are spaced out or use larger transistors to achieve maximum clock frequency, at the cost of silicon area.
  * The 'c' or 'd' suffix usually refers to the specific bitcell size/architecture variant provided by the foundry (e.g., 0.62um² bitcell).
* **`svt_rvt_hvt` (Threshold Voltage - $V_t$):** 
  * **`lvt` (Low $V_t$):** Fastest switching speed, but massive leakage power.
  * **`svt` / `rvt` (Standard/Regular $V_t$):** The baseline balance of speed and leakage.
  * **`hvt` (High $V_t$):** Slowest switching speed, but lowest leakage power.
  * *Why does the compiler name have all three?* Memory compilers use a mix of transistors. To save power, the massive core array of memory bitcells is almost always built using `hvt` transistors. However, to keep the memory fast, the peripheral logic (address decoders, sense amplifiers) uses faster `rvt` or `svt` transistors.

## 3. Architectural Analysis (Choosing the Right Compiler)
Before generating a memory, you must analyze your RTL to determine the Depth (Words), Width (Bits), and specific features required.

### Memory 1: Processing Element (PE) Buffer
* **RTL Parameters:** 128 Depth x 10 Bits. 
* **Compiler Choice:** **Register File (RF)**. 
  * *Why?* Standard SRAM compilers are optimized for larger depths (usually 256 to 16,384 words). For very small depths (16 to 2048 words), a Register File compiler yields better area and performance.
  * **Compiler Executable:** `rf_sp_hdd_svt_rvt_hvt` (Single-Port Register File).

### Memory 2: Main System RAM
* **RTL Parameters:** 10 Kilobytes = 2560 bytes = 512 Words x 32 Bits.
* **Special Feature:** The RTL uses `mem_wstrb[3:0]` to write to specific bytes (8-bit chunks) rather than the whole 32-bit word at once.
* **Compiler Choice:** **SRAM**.
  * *Why?* Depth is >= 256. 
  * **Compiler Executable:** `sram_sp_hdc_svt_rvt_hvt` (Single-Port SRAM).

## 4. Generating the Macros (GUI Parameters & Commands)

### Launching the Compilers
To launch the GUI, you must execute the specific binary file inside the PDK path (ensuring X11 forwarding is enabled in your SSH terminal).

**Command for Memory 1 (128x10 Register File):**
```bash
/arm_pdk/tsmc/cln65gplus/rf_sp_hdd_svt_rvt_hvt/r0p0/bin/rf_sp_hdd_svt_rvt_hvt &



###########################################################################################
/arm_pdk/tsmc/cln65gplus/sram_sp_hdc_svt_rvt_hvt/r0p0-00eac0/bin/sram_sp_hdc_svt_rvt_hvt &
##############################################################################################################
Setting the Parameters

When launching the ARM Artisan GUI, specific parameters must be set:

    Multiplexer Width (MUX): Controls the physical aspect ratio (shape) of the generated macro. A smaller MUX makes the macro shorter and wider; a larger MUX makes it taller and thinner.

        Note on Divisibility Rules: The compiler requires that the Number of Bits is divisible by (4/MUX). For a 10-bit memory, MUX=1 fails (10 is not divisible by 4). Changing MUX to 2 solves this (10 is divisible by 2).

    Word-Write Mask: Must be checked "ON" if the RTL uses byte-enables (wstrb).

    Word Partition Size: Set to 8 to allow the 32-bit word to be written in 8-bit increments.

5. Output Views (Files) Explained

The compiler generates several files ("Views"). Each serves a distinct purpose in the ASIC flow:

    Verilog Model (.v): A behavioral simulation model of the memory. Used in Xcelium/ModelSim to verify the design. Crucially, this is NOT read by the synthesis tool.

    Synopsys Model (.lib): The non-linear delay model (NLDM). Contains timing, power, and pin capacitance data. Genus and Innovus use this to calculate setup/hold paths through the memory. We generate both Worst Case (ss) and Best Case (ff) corners for Multi-Mode Multi-Corner (MMMC) analysis.

    VCLEF Footprint (.vclef / .lef): The physical abstract of the macro. Contains the exact dimensions (bounding box) and physical pin locations (M3/M4 coordinates) so Innovus knows how to place it and route metal to it.

    PostScript Datasheet (.ps): The human-readable manual containing the exact pin names (e.g., CEN, WEN, A, D, Q) needed to write the Verilog wrapper.

Note on .db files: Older tools (like Synopsys Design Compiler) require .lib files to be converted to binary .db files using lc_shell. Modern tools like Cadence Genus can read plain-text .lib files directly, so this conversion step is skipped.
6. Workspace Organization

To prevent synthesis and PnR tools from grabbing incorrect files, every macro must be isolated into its own directory.
###########################################################################################

Standard CLI Cleanup Flow:
# Create dedicated directories
mkdir -p macros/rf_sp_128x10
mkdir -p macros/sram_sp_512x32

# Move files from generation directory to isolated folders
mv ~/rf_sp_128x10* macros/rf_sp_128x10/
mv ~/sram_sp_512x32* macros/sram_sp_512x32/

# Rename the proprietary .vclef extension to the standard .lef extension
cd macros/rf_sp_128x10/
mv rf_sp_128x10.vclef rf_sp_128x10.lef

cd ../sram_sp_512x32/
mv sram_sp_512x32.vclef sram_sp_512x32.lef
###########################################################################


