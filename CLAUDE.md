# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

RV32I CPU implemented in Verilog. **5-stage pipelined CPU with 2-bit BTB branch prediction, M extension (MUL), and custom ML instructions (MAC, ReLU, RDCYC)** — completed M.Tech term project. Target: Xilinx Vivado simulation, Zynq Z-7020 (Zybo Z2) synthesis.

**Synthesis note:** Both `data_memory.v` and `instruction_memory.v` are restructured as 4 parallel byte-banks indexed by word address (canonical FPGA pattern), with `(* ram_style = "distributed" *)` attribute on each bank to force LUTRAM inference. Assumes naturally-aligned accesses (RV32I + GCC always aligned). Cost: ~2120 LUTs per 16 KB memory on Zynq Z-7020 (negligible — board has ~53K LUTs). See **Phase 5** below for full synthesis flow, timing results, and analysis.

**Harvard architecture**: separate instruction and data memories (both 16 KB, byte-addressable). No cache, no DRAM, no OS.

## Current state — All phases complete ✅

### Phase 0 — Single-cycle (complete, preserved)
Single-cycle CPU is stabilized. All 47 RV32I instructions verified.
- Top-level: `cpu_top.v` — pure wiring/muxing, no inline logic
- Testbench: `tb_cpu_top.v` — 47-instruction integration test, checks all regs + memory

### Phase 1 — 5-stage pipeline (complete, verified in Vivado simulation)
Pipeline added as a parallel top-level. **No existing Phase 0 modules were modified.**

New files added:
- `if_id_reg.v` — IF/ID pipeline register (stall + flush support)
- `id_ex_reg.v` — ID/EX pipeline register (flush support)
- `ex_mem_reg.v` — EX/MEM pipeline register
- `mem_wb_reg.v` — MEM/WB pipeline register
- `forwarding_unit.v` — EX→EX and MEM→EX data forwarding; also WB→ID bypass in top-level
- `hazard_unit.v` — load-use stall (1-cycle) and branch/jump flush (2-cycle)
- `cpu_top_pipeline.v` — pipelined top-level, instantiates all Phase 0 modules unchanged
- `tb_cpu_top_pipeline.v` — self-checking testbench, identical expected values to single-cycle

**Pipeline design decisions (locked):**
- Branch resolves in EX → 2-cycle flush penalty on mispredict
- Always predict not-taken (Phase 2 adds BTB)
- Forwarding: EX→EX (from EX/MEM.alu_result), MEM→EX (from WB mux output `wb_data`)
- Load-use stall: stall PC + IF/ID, flush ID/EX, MEM→EX forwarding resolves on next cycle
- PC stall method: feed `pc_out` back as `pc_next` when stall=1 (no changes to `pc.v`)
- NOP encoding: `32'h00000013` (ADDI x0, x0, 0)
- Store data uses forwarded rs2 (`ex_rs2_fwd`) not raw register file value

**Switching between single-cycle and pipelined:**
- Single-cycle: set `tb_cpu_top` as simulation top
- Pipelined: set `tb_cpu_top_pipeline` as simulation top
- Both use same `instructions.hex`, same expected results

### Phase 2 — BTB branch prediction (complete, verified)
16-entry direct-mapped BTB with 2-bit saturating counters in IF stage.
Correctly-predicted taken branches incur 0-cycle penalty; only mispredicts
and jumps still flush 2 cycles. **Phase 1 modules unmodified.**

New files added:
- `btb.v` — 16-entry BTB, indexed by PC[5:2], tag PC[31:6]
- `cpu_top_pipelined_branch.v` — Phase 2 top-level (based on Phase 1)
- `tb_cpu_top_pipelined_branch.v` — same 47-instr checks as Phase 1, 160-cycle wait

**Phase 2 design decisions (locked):**
- BTB only populated by branches (not jumps — jumps still flush 2 cycles)
- `predicted_taken` propagated through IF→ID→EX via inline registers in the
  top-level (no changes to Phase 1 pipeline register modules)
- Flush only on `branch_mispredict = ex_branch && (branch_taken != ex_predicted_taken)`
- Next-PC priority: EX redirect (mispredict/jump) > BTB predict_taken > PC+4
- Counter init: `2'b01` (weak not-taken) — conservative cold start
- **Bug learned:** Verilog creates implicit 1-bit nets for undeclared port
  connections. BTB instance must be placed *after* its input wires are
  declared (or forward-declare the wires) — otherwise silent corruption.

### Phase 3 — M extension + ML instructions (complete, verified)
Single-cycle signed multiplier supporting MUL, MAC, RELU. **First phase
to modify a Phase 0 module** (`control_unit.v` gained opcode `0001011`).

New instructions (Phase 3 semantics — preserved in `cpu_top_mext.v`):
| Instr | Opcode    | funct3 | funct7    | Semantics                       |
|-------|-----------|--------|-----------|---------------------------------|
| MUL   | `0110011` | `000`  | `0000001` | `rd = (rs1 * rs2)[31:0]`        |
| MAC   | `0001011` | `000`  | —         | `rd = rs1 + (rs1 * rs2)`        |
| RELU  | `0001011` | `001`  | —         | `rd = (rs1[31]) ? 0 : rs1`      |

> **Note:** Phase 4 redesigns MAC to the classical 3-operand form `rd = rd + rs1*rs2`
> (see Phase 4 below). Phase 3 MAC semantics are preserved unchanged in `cpu_top_mext.v`
> via `c = rs1_fwd` in the `mul_unit` instantiation.

New / modified files:
- `mul_unit.v` — NEW (modified in Phase 4 to add `c` input; see below)
- `control_unit.v` — MODIFIED, added opcode `0001011` (custom-0) case.
- `cpu_top_mext.v` — NEW, Phase 3 top-level (based on Phase 2).
- `tb_cpu_top_mext.v` — NEW, self-contained TB; hand-assembles 13 instructions.

**Phase 3 design decisions (locked):**
- `ex_op[1:0]` decoded in ID (`01`=MUL, `10`=MAC, `11`=RELU, `00`=ALU).
  Propagated through ID/EX via inline register in the top-level.
- EX stage result mux: `(ex_op == 00) ? ex_alu_result : ex_mul_result`.
- Branch unit still reads `ex_alu_result` (un-muxed).

**Switching between phases:**
- Phase 0 (single-cycle):  `tb_cpu_top`
- Phase 1 (5-stage):       `tb_cpu_top_pipeline`
- Phase 2 (+BTB):          `tb_cpu_top_pipelined_branch`
- Phase 3 (+MUL/MAC/RELU): `tb_cpu_top_mext`

### Phase 4 — RDCYC + 3-operand MAC + Benchmarks (complete, verified) ✅

Phase 4 adds:
1. **RDCYC** — 32-bit cycle counter readable from software
2. **3-operand MAC redesign** — `rd = rd + rs1*rs2` (classical FMA form, usable in real loops)
3. **Single-cycle Phase 4 top** — `cpu_top_sc_rdcyc.v` for cycle-count comparison
4. **BTB on/off parameter** — `USE_BTB` gate for fair pipeline comparison
5. **Benchmark suite** — 9 C programs (5 custom-op, 4 software-only baselines)
6. **Halt detection** — instruction-encoding detector (robust to BTB flush cycles)

#### New/modified files in Phase 4

| File | Change |
|------|--------|
| `cpu_top_mext_rdcyc.v` | NEW — Phase 4 pipelined top with RDCYC + 3-op MAC + USE_BTB |
| `tb_cpu_top_mext_rdcyc.v` | NEW — benchmark TB with halt detector, TIMEOUT=500000 |
| `cpu_top_sc_rdcyc.v` | NEW — single-cycle Phase 4 top (no pipeline, no BTB) |
| `tb_cpu_top_sc_rdcyc.v` | NEW — single-cycle benchmark TB, TIMEOUT=2000000 |
| `register_file_3p.v` | NEW — 3-port regfile (rs1, rs2, rs3 reads + 1 write) |
| `mul_unit.v` | MODIFIED — added `c [31:0]` input; MAC = `c + a*b` |
| `cpu_top_mext.v` | 1-line fix — passes `c=rs1_fwd` to preserve Phase 3 semantics |
| `tools/custom_ops.S` | Added `mac3_custom` function (encoding `0x00C5850B`) |
| `tools/custom_ops.h` | Added `extern int mac3_custom(int acc, int a, int b);` |
| `tests/matmul_8x8.c` | Updated inner loop to use `mac3_custom` |
| `tests/dotprod_16.c` | Updated loop to use `mac3_custom` |
| `tests/grad_descent.c` | NEW — fixed-point linear regression, 640 MACs total |
| `tests/matmul_8x8_nocustom.c` | NEW — same algorithm, software multiply only |
| `tests/dotprod_16_nocustom.c` | NEW — same algorithm, software multiply only |
| `tests/relu_32_nocustom.c` | NEW — branchless C ReLU instead of custom instruction |
| `tests/grad_descent_nocustom.c` | NEW — software multiply baseline for gradient descent |

#### Phase 4 ISA additions

| Instr | Opcode    | funct3 | Semantics                            | ex_op |
|-------|-----------|--------|--------------------------------------|-------|
| MAC   | `0001011` | `000`  | `rd = rd + rs1*rs2` (3-operand FMA)  | `010` |
| RELU  | `0001011` | `001`  | `rd = (rs1[31]) ? 0 : rs1`           | `011` |
| RDCYC | `0001011` | `010`  | `rd = cycle_counter`                 | `100` |

`ex_op` is now 3 bits: `000`=ALU, `001`=MUL, `010`=MAC, `011`=RELU, `100`=RDCYC.

**MAC calling convention:** `mac3_custom(acc, a, b)` — maps to `a0 = a0 + a1*a2`.
Encoding: `0000000_01100_01011_000_01010_0001011` = `0x00C5850B`.

#### Phase 4 design decisions

**3-operand MAC via 3rd register file port:**
- `register_file_3p` adds `rs3` read port (combinational, same as rs1/rs2).
- In Phase 4 tops, `rs3 = id_rd` (the accumulator register).
- WB→ID bypass for rs3: `id_rs3_data = (wb_reg_write && wb_rd == id_rd) ? wb_data : raw`.
- EX forwarding for rs3 (`forward_c`): inlined in top-level, checks `ex_rs3_reg` vs `mem_rd`/`wb_rd`.
- MAC load-use stall (`rs3_load_use`): stall when MAC's accumulator source follows a load.

**Halt detection (robust to BTB pipeline flush cycles):**
- Detects `32'h00000063` (`beq x0,x0,0`) at IF stage for HALT_WINDOW=8 consecutive fetches.
- BTB-off caused PC to cycle 0x08→0x0C→0x10 (2-cycle flush every iteration); PC-stability
  detector failed. Instruction-encoding approach works regardless of BTB state.

**`ex_correct_pc` fallthrough fix:**
- For a branch predicted-taken but actually-not-taken, redirect must use `ex_pc_plus4`
  (the branch's own PC+4), not `if_pc_plus4` (stale IF stage value). Bug fixed in Phase 4.

**BTB parameterization (`USE_BTB`):**
```verilog
parameter USE_BTB = 1;
// Gates: id_predicted_taken latch, btb_update_en, pc_next BTB branch
```

**Single-cycle top (`cpu_top_sc_rdcyc.v`):**
- No pipeline registers, no forwarding, no hazard unit.
- MAC rs3 read is combinational from prior cycle's write — correct for sequential execution.
- Exposes `if_instr`, `cycle_counter`, `dmem.mem` for testbench halt detection.

#### Simulating Phase 4 benchmarks

```
# 1. Build benchmark
tools\build.bat tests\<name>.c

# 2. Copy hex files to Vivado sim working directory
copy tests\<name>.instructions.hex instructions.hex
copy tests\<name>.data.hex data.hex

# 3. Set simulation top and run:
#    Pipeline + BTB:    tb_cpu_top_mext_rdcyc  (USE_BTB = 1, default)
#    Pipeline no-BTB:  tb_cpu_top_mext_rdcyc  (set USE_BTB = 0 in TB)
#    Single-cycle:     tb_cpu_top_sc_rdcyc
```

---

## Phase 4 Benchmark Results

> **Note:** Cycle counts below are from the Phase 6 validated run (include `validate_write()`
> overhead — typically 5–20 extra cycles per benchmark). CPI values are computed from
> the instruction-retired counter added in Phase 6.

### Table A — Cycle counts and CPI across CPU configurations

| Benchmark | SC cycles | SC CPI | PL+BTB cycles | PL+BTB CPI | PL no-BTB cycles | PL no-BTB CPI |
|---|---|---|---|---|---|---|
| fib_20 | 119 | 1.000 | 128 | 1.103 | 164 | 1.401 |
| dotprod_16 | 177 | 1.000 | 250 | 1.436 | 278 | 1.588 |
| dotprod_16_nocustom | 608 | 1.000 | 771 | 1.274 | 891 | 1.470 |
| matmul_8x8 | 5366 | 1.000 | 7721 | 1.439 | 8519 | 1.588 |
| matmul_8x8_nocustom | 16612 | 1.000 | 20698 | 1.246 | 24502 | 1.475 |
| relu_32 | 481 | 1.000 | 622 | 1.301 | 740 | 1.544 |
| relu_32_nocustom | 420 | 1.000 | 437 | 1.047 | 583 | 1.394 |
| grad_descent | 4845 | 1.000 | 7557 | 1.560 | 7731 | 1.596 |
| grad_descent_nocustom | 18686 | 1.000 | 26084 | 1.396 | 28756 | 1.539 |

> **Why single-cycle has fewer cycles than pipeline:** Each instruction takes exactly
> 1 clock cycle on the single-cycle CPU — no stalls, no flush overhead (CPI always 1.0).
> The pipeline adds load-use stall cycles (+1 each) and branch mispredict flush cycles
> (+2 each), causing higher cycle counts and CPI > 1. In real silicon the pipeline wins
> because its clock period is 3–5× shorter. In Vivado simulation both use the same
> abstract clock so cycle count is the only metric — pipeline appears "slower". This is
> the classic **CPI × clock-period tradeoff**.

### Table B — BTB speedup (pipeline+BTB vs pipeline no-BTB)

| Benchmark | No-BTB cycles | BTB cycles | BTB speedup |
|---|---|---|---|
| fib_20 | 164 | 128 | **1.28×** |
| dotprod_16 | 278 | 250 | **1.11×** |
| dotprod_16_nocustom | 891 | 771 | **1.16×** |
| matmul_8x8 | 8519 | 7721 | **1.10×** |
| matmul_8x8_nocustom | 24502 | 20698 | **1.18×** |
| relu_32 | 740 | 622 | **1.19×** |
| relu_32_nocustom | 583 | 437 | **1.33×** |
| grad_descent | 7731 | 7557 | **1.02×** |
| grad_descent_nocustom | 28756 | 26084 | **1.10×** |

### Table C — Custom instruction speedup (Pipeline + BTB)

| Benchmark | No-custom (cycles) | With custom (cycles) | Speedup |
|---|---|---|---|
| matmul_8x8 | 20698 | 7721 | **2.68×** |
| dotprod_16 | 771 | 250 | **3.08×** |
| relu_32 | 437 | 622 | 0.70× ⚠ |
| grad_descent | 26084 | 7557 | **3.45×** |

> **relu_32 anomaly — custom is SLOWER:** `relu_custom` is implemented as a
> function call (32 × JAL + RELU instruction + RET + 2-cycle flush = ~200 extra cycles).
> The no-custom version uses a branchless inline C expression
> `(x[i] & 0x80000000) ? 0 : x[i]` compiled to 2–3 ALU instructions with no call overhead.
> Fix: use `__attribute__((always_inline))` or a `.macro`-based inline assembly macro
> to eliminate call overhead.

### Key observations

- **MAC delivers the largest speedup** — grad_descent achieves **3.45×** and dotprod **3.08×**
  because each MAC replaces a full software-multiply loop (~30+ shift-add iterations).
- **BTB helps branch-heavy code most** — fib (1.28×), relu_nocustom (1.33×). Grad_descent
  is mostly compute with few branches → BTB barely helps (1.02×).
- **Pipeline CPI reveals stall pressure** — matmul CPI 1.44 (BTB) reflects heavy load-use
  stalls from back-to-back memory accesses. Grad_descent CPI 1.56 reflects MAC rs3
  forwarding stalls on the accumulator path.
- **SC CPI is always 1.000** — confirmed by the instruction-retired counter (Phase 6).

---

## Phase 5 — Synthesis & FPGA Timing Analysis (complete) ✅

Phase 5 extends the project from pure simulation into **post-synthesis static timing
analysis** on Zynq Z-7020 (Zybo Z2). Goal: convert simulation cycle counts into
real-world execution time by measuring actual achievable clock frequency.

### Why this phase was needed

Vivado behavioral simulation uses an **abstract clock** — both SC and pipeline tick
at the same rate. Cycle-count comparisons (Phase 4) make pipeline appear *slower*
than SC because pipelines accumulate stall and flush cycles. To prove the pipeline's
real-world advantage, we need each design's **actual clock period**, which only
comes from synthesis timing reports.

```
real_time = cycle_count (simulation) × clock_period (synthesis)
```

### Required code changes for synthesis

The project was simulation-only. Synthesis revealed several issues that required
code changes to all targets while preserving simulation behavior:

#### 1. Memory inference failure (data_memory.v, instruction_memory.v)

**Original error:**
```
[Synth 8-3391] Unable to infer a block/distributed RAM for 'mem_reg'
because the memory pattern used is not supported.
Failed to dissolve the memory into bits because the number of bits (131072) is too large.
```

**Root cause:** Original memories used `reg [7:0] mem [0:16383]` accessed with
computed byte addresses (`mem[a], mem[a+1], mem[a+2], mem[a+3]`). Vivado cannot
recognize this as a RAM pattern — it requires a single read port per array. With
4 simultaneous reads at computed offsets, Vivado tried to fall back to discrete
flip-flops (131072 of them), which is too large.

**Fix:** Restructured both memories as **4 parallel byte-banks indexed by word
address** (canonical FPGA-friendly pattern). Each bank gets `(* ram_style = "distributed" *)`
attribute to force LUTRAM inference. Assumes naturally-aligned accesses
(RV32I + GCC always emits aligned).

```verilog
(* ram_style = "distributed" *) reg [7:0] mem0 [0:NWORDS-1];  // byte 0 (LSB)
(* ram_style = "distributed" *) reg [7:0] mem1 [0:NWORDS-1];  // byte 1
(* ram_style = "distributed" *) reg [7:0] mem2 [0:NWORDS-1];  // byte 2
(* ram_style = "distributed" *) reg [7:0] mem3 [0:NWORDS-1];  // byte 3
```

For `instruction_memory.v`, a temp byte array preserves `$readmemh("instructions.hex")`
loading from the original byte format, then distributes to banks.

External port interfaces unchanged — no changes needed in any top-level file or
testbench. Cost: ~2120 LUTs per 16 KB memory on Zynq Z-7020.

#### 2. Logic trimming due to no output ports

`cpu_top_mext_rdcyc` and `cpu_top_sc_rdcyc` originally had only `clk` and `reset`
as ports — no outputs. Vivado's optimizer sees nothing driving external pins and
**trims away the entire CPU** during synthesis. First synthesis pass showed only
2 LUTs and 63 registers used (just the trimming residue).

**Fix:** Added 3 output ports to both tops to anchor the design:
```verilog
output wire [31:0] o_pc,            // current PC (IF stage)
output wire [31:0] o_cycle_counter, // RDCYC counter
output wire [31:0] o_wb_data        // writeback data — keeps pipeline alive
```
With these driving real outputs, Vivado preserves the full datapath.

#### 3. Missing clock constraint

Without an `.xdc` file, Vivado doesn't know `clk` is a real clock → cannot run
timing analysis → WNS reports as `NA`.

**Fix:** Added `constraints.xdc`:
```tcl
create_clock -period 10.000 -name clk [get_ports clk]
```
100 MHz target frequency (10 ns period).

### Synthesis flow (reproducible steps)

```
1. Set top in Sources panel: cpu_top_sc_rdcyc OR cpu_top_mext_rdcyc
2. Add constraints.xdc with create_clock command above
3. Flow Navigator → Run Synthesis (defaults: local host, 2 jobs)
4. Open Synthesized Design when complete
5. In Tcl console:
     report_timing_summary  -file timing_<top>.txt
     report_utilization     -file util_<top>.txt
```

### Synthesis utilization results (Zynq Z-7020)

| Resource | SC (`cpu_top_sc_rdcyc`) | Pipeline (`cpu_top_mext_rdcyc`) |
|----------|------------------------|--------------------------------|
| LUT as Logic | 1202 | 1698 |
| LUT as Distributed RAM | 2112 | 2120 |
| Total LUTs | 3314 (6.23%) | 3818 (7.18%) |
| Flip Flops | 64 | 1519 |
| DSP48E1 (multipliers) | 3 | 3 |
| Block RAM | 0 | 0 (using LUTRAM) |
| F7/F8 Muxes | 1089 / 544 | 1244 / 571 |

**Observations:**
- Pipeline uses ~1455 more flip-flops (pipeline registers + cycle counter wider
  than SC's 64 just-cycle-counter)
- Both use 3 DSP48E1 — Vivado mapped the multiplier to dedicated DSP slices
- Logic LUT difference (1202 → 1698) is forwarding/hazard logic added in pipeline
- LUTRAM cost is identical — both use the same memories

### Synthesis timing results

#### Single-cycle (`cpu_top_sc_rdcyc`)
```
WNS = +5.612 ns  (timing MET at 100 MHz target)
Critical path  = 10.000 - 5.612 = 4.388 ns
Reported max freq = 1 / 4.388 ns ≈ 227.9 MHz
Critical path: pc_reg[4] → CARRY4 chain × 8 → LUT6 → pc_reg[30]  (PC+4 adder)
Logic levels: 9 (CARRY4=8, LUT6=1)
```

#### Pipeline (`cpu_top_mext_rdcyc`)
```
WNS = -5.683 ns  (timing NOT met at 100 MHz target)
Critical path  = 10.000 + 5.683 = 15.683 ns
True max freq = 1 / 15.683 ns ≈ 63.8 MHz
Critical path: mem_wb/wb_reg_write → LUT × 2 → DSP48E1 × 2 → CARRY4 × 4 → LUT × 2
                → ex_mem/mem_alu_result_reg
Logic levels: 14 (CARRY4=5, DSP48E1=2, LUT2=1, LUT5=1, LUT6=5)
Data path delay: 15.546 ns (logic 9.125 ns / 58.7%, route 6.421 ns / 41.3%)
```

### **Critical interpretation: SC max-freq number is misleading**

The 227.9 MHz SC figure is **mathematically correct but practically wrong**. It
reflects only the **PC update path** (the only register-to-register path in SC).
The MAC/MUL combinational chain (IMEM → decode → multiply → writeback to regfile)
is **unconstrained** in SC because:

- **Start point** = IMEM output = combinational distributed-RAM read = NOT a flip-flop
- **End point** = register file write port = IS a flip-flop

Vivado's static timing analysis only times **flip-flop to flip-flop** paths. Since
the MAC path starts from a combinational source, Vivado treats it as unconstrained
and excludes it from WNS. The check_timing report flags this:
```
checking no_input_delay  (1)   ← HIGH
checking no_output_delay (96)  ← HIGH
```

In contrast, the pipeline has flip-flops between every stage (IF/ID, ID/EX,
EX/MEM, MEM/WB registers). The MAC path becomes register-to-register
(WB-forwarded operand → MUL → EX/MEM register), so Vivado fully constrains it
and reports the true 15.683 ns critical path.

**Conclusion:** Both designs share the same combinational multiplier hardware, so
their true clock periods should be approximately equal (~15 ns). Pipeline timing
is honest; SC timing hides the multiplier behind unconstrained paths.

### True execution time estimates

Using **15.683 ns** for both (the honest multiplier-bound clock period):

| Benchmark | Cycles SC | Cycles PL+BTB | Real time SC | Real time PL+BTB | Winner |
|-----------|-----------|---------------|--------------|------------------|--------|
| fib_20 | 112 | 121 | 1756 ns | 1898 ns | SC (1.08×) |
| matmul_8x8 | 5267 | 7614 | 82.6 µs | 119.4 µs | SC (1.45×) |
| grad_descent | 4831 | 7543 | 75.8 µs | 118.3 µs | SC (1.56×) |
| matmul_8x8_nocustom | 9857 | 12211 | 154.6 µs | 191.5 µs | SC (1.24×) |
| grad_desc_nocustom | 13440 | 18642 | 210.8 µs | 292.4 µs | SC (1.39×) |

**Counterintuitive finding:** SC outperforms pipeline in real time across all
benchmarks because the unpipelined multiplier dominates the pipeline's clock
period, negating the pipeline's stage-shortening advantage. Combined with
pipeline's stall/flush cycle overhead, SC wins on net execution time.

### **Root-cause analysis: pipeline negation by single-stage MUL**

The fundamental rule of pipelining:

> **A pipeline is only as fast as its slowest stage.**

Our `mul_unit.v` is purely combinational — the entire 32×32 multiply + carry-chain
addition completes in one cycle. When placed in the EX stage of the pipeline, it
forces:
- EX stage delay ≥ 15 ns (DSP cascade + carry chain + WB-forward routing)
- Therefore pipeline clock period ≥ 15 ns
- All other stages (IF ~3 ns, ID ~2 ns, MEM ~5 ns, WB ~2 ns) have huge slack but
  must wait for EX

This is why the pipeline delivers no clock-period advantage. The pipeline pays
all the costs of pipelining (extra registers, hazards, stalls, flushes) but
captures none of the benefits because one stage is 5× slower than the others.

### Recommended fix (future work): pipeline the multiplier

Production CPUs (ARM Cortex-A, RISC-V Rocket, x86) all use **multi-cycle
pipelined multipliers**. Splitting `mul_unit.v` into 3 internal stages would:

```
Original (1 stage, 15 ns):
  rs1, rs2 ──► [combinational mul + add] ──► result

Pipelined (3 stages, ~5 ns each):
  rs1, rs2 ──► MUL1 ──► [reg] ──► MUL2 ──► [reg] ──► MUL3 ──► [reg] ──► result
```

Expected impact:
- Pipeline clock period: 15 ns → ~5 ns (3× reduction → ~200 MHz)
- MAC instruction latency: 1 cycle → 3 cycles (throughput unchanged for
  back-to-back MACs)
- Net win: ~3× real-time speedup despite higher cycle count

**Implementation difficulty: medium (1–2 days).** Required changes:
1. Split `mul_unit.v` into MUL1/MUL2/MUL3 stages with internal pipeline registers
2. Add `mul_valid` output and stall logic in `hazard_unit` for MAC RAW hazards
3. Extend forwarding network to handle MUL2/MUL3 stage outputs
4. Resolve regfile write-port conflicts when 1-cycle ALU instruction follows MAC
5. Re-verify all benchmarks pass with new MAC latency

### Summary table (Phase 5 deliverables)

| Item | Result |
|------|--------|
| Target FPGA | Zynq Z-7020 (Zybo Z2), part `xc7z020clg400-1` |
| Vivado version | 2020.2 |
| SC LUT usage | 3314 (6.23% of 53200) |
| Pipeline LUT usage | 3818 (7.18% of 53200) |
| DSP usage (both) | 3 / 220 (1.36%) |
| SC reported max freq | 227.9 MHz (PC path only — misleading) |
| Pipeline true max freq | 63.8 MHz (multiplier-bound) |
| True SC max freq (estimated) | ~63.8 MHz (same multiplier bottleneck) |
| Critical path bottleneck | Combinational multiplier (mul_unit.v) |
| Recommended fix | 3-stage pipelined multiplier |

### Synthesis-related file changes

| File | Change |
|------|--------|
| `data_memory.v` | Restructured to 4 byte-banks indexed by word address; added `ram_style = "distributed"` attribute |
| `instruction_memory.v` | Same restructuring; uses temp byte array to preserve `$readmemh` byte-format compatibility |
| `cpu_top_mext_rdcyc.v` | Added `o_pc`, `o_cycle_counter`, `o_wb_data` output ports + assignments to prevent logic trimming |
| `cpu_top_sc_rdcyc.v` | Same output port additions as above |
| `constraints.xdc` | NEW — `create_clock -period 10.000 -name clk [get_ports clk]` |

### Key insight for report

The Phase 5 work uncovers a fundamental architecture lesson:

> The pipeline implementation does not deliver the expected clock-period reduction
> because the multiplier is implemented as a single-cycle combinational unit
> (~15 ns critical path). To achieve the theoretical pipeline speedup, the
> multiplier itself must be internally pipelined (3–5 stages) — the standard
> approach in production processors. Without this, the pipeline pays all the
> costs of pipelining (registers, hazards, stalls) but captures none of the
> clock-period benefits because one stage dominates the timing.

This is itself a strong result: it demonstrates **why** real CPUs design
multipliers as multi-stage units, and **why** simply splitting a single-cycle
datapath into pipeline stages is insufficient if any single stage contains
disproportionately deep combinational logic.

---

## Development Environment

Primary IDE: **Xilinx Vivado** (`hpca_riscv.xpr`). No Makefile — build, simulation, synthesis through Vivado GUI or Tcl console.

**RISC-V toolchain** (installed by user):
```
C:\riscv\riscv\riscv64-unknown-elf-toolchain-10.2.0-2020.12.8-x86_64-w64-mingw32\bin\
```
The riscv64 toolchain cross-compiles to rv32 via `-march=rv32i -mabi=ilp32 -nostdlib`.

## Building a C test program

```
tools\build.bat tests\smoke_add.c
```

Produces next to the `.c` file:
- `<name>.elf` — linked ELF
- `<name>.instructions.hex` — IMEM init (Verilog `$readmemh` format)
- `<name>.data.hex` — DMEM init (initialized `.data` / `.rodata`)
- `<name>.dis` — disassembly for debugging

To simulate a specific test in Vivado: copy/rename the two `.hex` files to `instructions.hex` and `data.hex` in the Vivado sim working directory, then run Behavioral Simulation on the appropriate testbench.

**Toolchain files** (in `tools/`):
- `link.ld` — linker script; `.text` → IMEM @ 0x0, `.rodata/.data/.bss` → DMEM @ 0x0
- `startup.S` — minimal `_start` that sets `sp = 0x4000` (top of DMEM) and calls `main`
- `build.bat` — one-command compile/link/objcopy pipeline
- `custom_ops.S` — inline assembly for `mul_custom`, `mac3_custom`, `relu_custom`, `rdcyc_custom`
- `custom_ops.h` — C declarations for the above

## Running simulations

**IMPORTANT: Always use "Run Behavioral Simulation" in the Flow Navigator — NOT "Elaborate Design" or "Run Synthesis". The testbenches are simulation-only.**

**Single-cycle integration test** (no C required):
- Top module: `tb_cpu_top`
- Reads `instructions.hex` (committed, pre-generated)
- Verifies all registers and memory via hierarchical references
- Check Vivado Tcl console for `PASS`/`FAIL`

**Pipelined integration test** (no C required):
- Top module: `tb_cpu_top_pipeline`
- Same `instructions.hex`, same expected values as single-cycle
- Wait time: 120 cycles after reset (accounts for pipeline fill + stalls + flushes)
- Click "Run All" (or `run all` in Tcl) — default 1000ns sim time is not enough

**Phase 4 benchmark TBs:**
- `tb_cpu_top_mext_rdcyc` — pipeline + BTB benchmark (`USE_BTB = 1` default; set to `0` for no-BTB)
- `tb_cpu_top_sc_rdcyc` — single-cycle benchmark (TIMEOUT=2,000,000 — software-multiply tests are slow)
- Both auto-detect halt via `beq x0,x0,0` instruction at IF; print `BENCHMARK COMPLETE: N cycles`

**Unit tests**: set `tb_<module>` as simulation top (e.g. `tb_alu`, `tb_control_unit`) and run Behavioral Simulation.

**Data memory init**: testbenches call `$readmemh("data.hex", uut.dmem.mem)` — missing file is harmless, just emits a warning. Only needed for C programs with initialized globals.

## Architecture

All source in `hpca_riscv.srcs/sources_1/new/`. Top-level datapath (`cpu_top.v`):

```
PC → imem → [instruction fields]
             ↓
         control_unit → ctrl signals
         alu_control  → alu_ctrl
         immediate_gen → imm_out
         register_file → rs1_data, rs2_data
             ↓
        ALU A MUX (rs1 / PC / 0)  [via alu_a_sel]
        ALU B MUX (rs2 / imm)     [via alu_src]
             ↓
            alu → result, zero
             ↓
        branch_unit (funct3, zero, result[0]) → branch_taken
        PC next MUX (PC+4 / PC+imm / rs1+imm)
             ↓
        dmem → mem_read_data
        writeback MUX → wb_data → regfile
```

**Control signal encodings:**
- `alu_op`: `00`=force ADD, `01`=branch, `10`=R-type, `11`=I-arith
- `alu_a_sel`: `00`=rs1, `01`=PC, `10`=zero
- `wb_sel`: `00`=ALU result, `01`=mem, `10`=PC+4
- `imm_sel`: `000`=I, `001`=S, `010`=B, `011`=U, `100`=J

**ALU control**: `0000`=ADD `0001`=SUB `0010`=AND `0011`=OR `0100`=XOR `0101`=SLL `0110`=SRL `0111`=SRA `1000`=SLT `1001`=SLTU

**PC next priority**: JALR > JAL > branch taken > PC+4.

**Memory layout**: both memories 16 KB, addressed from 0x0 in their own space. Stack grows down from 0x4000 (top of DMEM).

## Phase 6 — Validation Harness (complete) ✅

Phase 6 adds automated correctness validation and a full 27-run sweep (9 benchmarks × 3
configs) that populates a CSV with cycles, instructions retired, CPI, and pass/fail.

### What was added

| File | Change |
|------|--------|
| `tests/validate.h` | NEW — `validate_write(id, results, n)` convention; benchmark ID constants |
| `tests/*.c` (9 files) | MODIFIED — each calls `validate_write()` before halting |
| `cpu_top_mext_rdcyc.v` | MODIFIED — added `o_instr_retired` port + valid-bit pipeline counter |
| `cpu_top_sc_rdcyc.v` | MODIFIED — added `o_instr_retired` port (= `cycle_counter`, CPI always 1) |
| `tb_cpu_top_mext_rdcyc.v` | REWRITTEN — full validation harness with expected table + CSV append |
| `tb_cpu_top_sc_rdcyc.v` | REWRITTEN — same harness for single-cycle top |
| `tools/build_all.bat` | NEW — builds all 9 benchmarks in one command |
| `tools/run_all.tcl` | NEW — Tcl sweep: 3 configs × 9 benchmarks = 27 runs, appends to results.csv |
| `tools/run_all.bat` | NEW — headless wrapper: `vivado -mode batch -source tools/run_all.tcl` |
| `tools/build.bat` | FIXED — re-enabled `--change-addresses -65536` for correct data.hex LMA stripping |

### Validation block convention (tests/validate.h)

Each benchmark writes a structured block at DMEM byte address `0x3F00` (last 256 bytes,
never overlaps with globals or stack):

```
word 0 : 0xBEEF0000 | benchmark_id
word 1 : n  (number of result words)
word 2+: result[0..n-1]
```

The TB reads this block at halt, identifies the benchmark by id, and compares against
a hardcoded expected table (derived analytically, not from a pre-run).

### Expected values (analytically derived)

| id | Benchmark | Expected |
|----|-----------|----------|
| 1 | fib_20 | [6765] |
| 2 | dotprod_16 | [1496] |
| 3 | dotprod_16_nocustom | [1496] |
| 4 | matmul_8x8 | C[0][0..7] = {8,16,24,32,40,48,56,64} |
| 5 | matmul_8x8_nocustom | same |
| 6 | relu_32 | {0×16, 0,1,2,...,15} |
| 7 | relu_32_nocustom | same |
| 8 | grad_descent | w = {2,2,2,2} |
| 9 | grad_descent_nocustom | same |

### Instructions-retired counter (cpu_top_mext_rdcyc.v)

Valid bits are propagated inline through ID/EX/MEM/WB stages alongside the data path.
A bubble inserted by stall or flush has `valid=0` and is not counted. This gives an
accurate retired count independent of NOP encoding.

### Running the full validation sweep

```
# From worktree root (or project root):
tools\build_all.bat          # build all 9 benchmarks once
tools\run_all.bat            # 27 sims → results.csv (headless Vivado batch)

# Or interactively in Vivado Tcl console:
source tools/run_all.tcl
```

CSV format: `benchmark, config, cycles, instr_retired, cpi_x1000, pass`

All 27 runs verified PASS on 2026-04-27.

---

## Roadmap

- **Phase 0** ✅ Single-cycle RV32I, all 47 instructions (`cpu_top.v`)
- **Phase 1** ✅ 5-stage pipeline, forwarding, load-use stall, branch flush (`cpu_top_pipeline.v`)
- **Phase 2** ✅ 16-entry BTB + 2-bit saturating predictor (`cpu_top_pipelined_branch.v`)
- **Phase 3** ✅ M extension (MUL) + custom ML (MAC, ReLU) (`cpu_top_mext.v`)
- **Phase 4** ✅ RDCYC cycle counter, 3-operand MAC, single-cycle top, 9-benchmark suite (`cpu_top_mext_rdcyc.v`, `cpu_top_sc_rdcyc.v`)
- **Phase 5** ✅ Zynq Z-7020 synthesis & post-synthesis timing analysis. Memory restructured to 4 byte-banks for LUTRAM inference; output ports added to prevent logic trimming; `constraints.xdc` with 100 MHz clock. SC: 4.388 ns critical path (PC adder only). Pipeline: 15.683 ns critical path (multiplier-bound).
- **Phase 6** ✅ Automated validation harness. `validate_write()` convention, instructions-retired counter, 27-run Tcl sweep, results.csv output. All 27 benchmarks × configs verified PASS.

**Future work:** Pipeline `mul_unit.v` into 3 internal stages (~5 ns each) → expected ~3× pipeline real-time speedup. Requires hazard/forwarding/write-port-arbitration changes. ~1–2 days effort.

**Locked architectural decisions:**
- Branch resolves in EX (2-cycle flush penalty on mispredict)
- Each phase adds a new top-level file; Phase 0 modules only modified for ISA extensions
- Phase 4 MAC encoding (3-operand): `rd = rd + rs1*rs2` via `register_file_3p` + inline forwarding
- Phase 3 MAC encoding preserved (2-operand): `rd = rs1 + rs1*rs2` in `cpu_top_mext.v`

## Simulation top-level summary

| Phase | Testbench | Description |
|-------|-----------|-------------|
| 0 | `tb_cpu_top` | Single-cycle, 47-instruction verification |
| 1 | `tb_cpu_top_pipeline` | 5-stage pipeline, same 47 instructions |
| 2 | `tb_cpu_top_pipelined_branch` | Pipeline + BTB, same 47 instructions |
| 3 | `tb_cpu_top_mext` | Pipeline + BTB + MUL/MAC/RELU, 13-instruction MAC test |
| 4 (pipeline) | `tb_cpu_top_mext_rdcyc` | Pipeline + BTB + RDCYC + 3-op MAC benchmarks |
| 4 (single-cycle) | `tb_cpu_top_sc_rdcyc` | Single-cycle + RDCYC + 3-op MAC benchmarks |
| 6 (all) | `tb_cpu_top_mext_rdcyc` / `tb_cpu_top_sc_rdcyc` | Unified validation harness — auto-detects benchmark by id, checks expected results, reports CPI, appends to results.csv |
