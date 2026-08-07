# RNN Hardware Support

This accelerator now exposes a small recurrent-vector instruction layer on top of the existing PE MAC path, ping-pong SRAM, sigmoid and tanh blocks. The intent is to support SimpleRNN, GRU and LSTM models from firmware/compiler scheduling without building three separate hardwired RNN engines.

## New hardware state

`decoder_acc.v` contains a 4096 x 16-bit recurrent state RAM implemented through the existing `scratchpad_sram` wrapper, so synthesis uses the same compiled 4096x16 SRAM macro style as the ping-pong storage instead of a large flip-flop array. Values are signed Q1.15 unless the value is a sigmoid gate, where the same 16-bit field represents 0..0x7fff.

The ping-pong SRAM remains the working vector memory for layer outputs and gate vectors. The recurrent RAM keeps hidden state, cell state, or temporary gate vectors across timesteps. Because both memories are synchronous SRAMs, the RNN FSM includes explicit read-settle and write-hold states before consuming read data or advancing after writes.

## Instruction map

All instructions use custom opcode `0x2b` and `funct3=0`.

| funct7 | Wrapper | Operation |
| --- | --- | --- |
| `0x17` | `acc_rnn_pp_to_state(pp_src, state_dst, len)` | Copy ping-pong vector to recurrent state RAM. |
| `0x18` | `acc_rnn_state_to_pp(state_src, pp_dst, len)` | Copy recurrent state vector to ping-pong SRAM. |
| `0x19` | `acc_rnn_add_pp_state(pp_src, state_src, pp_dst, len)` | Signed saturating Q1.15 vector add. |
| `0x1a` | `acc_rnn_mul_pp_state(pp_src, state_src, pp_dst, len)` | Signed Q1.15 vector multiply with rounding and saturation. |
| `0x1b` | `acc_rnn_one_minus_pp(pp_src, pp_dst, len)` | Compute `0x7fff - pp[i]`, useful for GRU update gates. |
| `0x1c` | `acc_rnn_write_state(state_addr, value)` | Write one state element from firmware. |
| `0x1d` | `acc_rnn_read_state(state_addr)` | Read one sign-extended state element. |
| `0x1e` | `acc_rnn_clear_state(state_dst, len)` | Clear a state vector to zero. |

## Why these primitives are enough

SimpleRNN uses:

```text
h_t = tanh(Wx_t + Uh_{t-1} + b)
```

The existing PE array computes the dense MACs. The new state instructions copy `h_{t-1}` into ping-pong SRAM for the recurrent dense path and copy `h_t` back into recurrent state RAM after activation.

GRU uses:

```text
z_t = sigmoid(W_z x_t + U_z h_{t-1} + b_z)
r_t = sigmoid(W_r x_t + U_r h_{t-1} + b_r)
n_t = tanh(W_n x_t + U_n (r_t * h_{t-1}) + b_n)
h_t = (1 - z_t) * n_t + z_t * h_{t-1}
```

The PE array computes each affine term, sigmoid/tanh produce gates, `mul_pp_state` forms gate-state products, `one_minus_pp` forms `(1-z)`, and `add_pp_state` combines partial vectors.

LSTM uses:

```text
i_t = sigmoid(W_i x_t + U_i h_{t-1} + b_i)
f_t = sigmoid(W_f x_t + U_f h_{t-1} + b_f)
g_t = tanh(W_g x_t + U_g h_{t-1} + b_g)
o_t = sigmoid(W_o x_t + U_o h_{t-1} + b_o)
c_t = f_t * c_{t-1} + i_t * g_t
h_t = o_t * tanh(c_t)
```

Keep `h` and `c` in different regions of recurrent state RAM. Gate vectors can live temporarily in ping-pong SRAM or state RAM depending on the compiler schedule.

## Verification

Run this from the server or any machine with Verilator installed:

```bash
cd /home/yash-bansal/Desktop/Mtp1/neonatal3/scripts
./verilator_lint_rnn.sh
```

The script lints both the standalone RNN decoder testbench and the integrated `hardware` top. The RNN testbench models ping-pong reads with synchronous one-cycle latency, matching the SRAM macro behavior. The warning disables in that script are for existing PicoRV32/SRAM-model/testbench noise; syntax, missing modules, port mismatches, and unsuppressed user-RTL warnings still fail the run.
