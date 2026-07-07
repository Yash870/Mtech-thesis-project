# Xcelium simulation initialisation
# X initialization handled by -xprop tbx in xrun_options.glv.

# qspi_cs_n_reg synthesized without reset pin (EDFQD — Genus enable optimization).
# TSMC_INIT_0 sets it to 0 (CS asserted) at t=0. Force to 1 (CS deasserted) before run.
#force testbench.dut.qspi_cs_n 1 0
#force testbench.dut.qspi_cs_n = 1

run
