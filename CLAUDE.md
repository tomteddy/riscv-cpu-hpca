# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

RV32I CPU implemented in Verilog. **5-stage pipelined CPU with 2-bit BTB branch prediction, M extension (MUL), and custom ML instructions (MAC, ReLU, RDCYC)** — completed M.Tech term project. Target: Xilinx Vivado simulation, optional Artix-7 / Zynq synthesis.

**Harvard architecture**: separate instruction and data memories (both 16 KB, byte-addressable). No cache, no DRAM, no OS.

## Current state — All 4 phases complete ✅

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

### Table A — Cycle counts across CPU configurations

| Benchmark | Single-cycle | Pipeline (no BTB) | Pipeline + BTB | BTB speedup |
|---|---|---|---|---|
| fib_20 | 112 | 157 | 121 | 1.30× |
| matmul_8x8 | 5267 | 8392 | 7614 | 1.10× |
| dotprod_16 | — | 271 | 243 | 1.12× |
| relu_32 | — | 509 | 449 | 1.13× |
| grad_descent | 4831 | 7717 | 7543 | 1.02× |
| matmul_8x8_nocustom | 9857 | 16055 | 12211 | 1.31× |
| dotprod_16_nocustom | — | 499 | 381 | 1.31× |
| relu_32_nocustom | — | 369 | 247 | 1.49× |
| grad_desc_nocustom | 13440 | 22686 | 18642 | 1.22× |

> **Why single-cycle has fewer cycles than pipeline:** Each instruction takes exactly
> 1 clock cycle on the single-cycle CPU — no stalls, no flush overhead. The pipeline
> adds load-use stall cycles (+1 each) and branch mispredict flush cycles (+2 each),
> causing higher cycle counts. In real silicon the pipeline wins because its clock
> period is 3–5× shorter (each stage is simpler = faster). In Vivado simulation,
> both use the same abstract clock, so cycle count is the only metric and pipeline
> appears "slower". This is the classic **CPI × clock-period tradeoff**.

### Table B — Custom instruction speedup (Pipeline + BTB)

| Benchmark | No-custom (cycles) | With custom (cycles) | Speedup |
|---|---|---|---|
| matmul_8x8 | 12211 | 7614 | **1.60×** |
| dotprod_16 | 381 | 243 | **1.57×** |
| relu_32 | 247 | 449 | 0.55× ⚠ |
| grad_descent | 18642 | 7543 | **2.47×** |

> **relu_32 anomaly — custom is SLOWER:** `relu_custom` is implemented as a
> function call (32 × JAL + RELU instruction + RET + 2-cycle flush = ~200 extra cycles).
> The no-custom version uses a branchless inline C expression
> `(x[i] & 0x80000000) ? 0 : x[i]` compiled to 2–3 ALU instructions with no call overhead.
> Fix: use `__attribute__((always_inline))` or a `.macro`-based inline assembly macro
> to eliminate call overhead. For MAC/MUL-heavy kernels the call overhead amortizes
> over many multiply cycles, so they still show a real speedup.

### Key observations

- **MAC delivers the largest speedup** — grad_descent achieves **2.47×** because 640 MACs
  replace 640 software-multiply loops (each sw_mul takes ~30+ shift-add iterations).
- **BTB helps branch-heavy code most** — fib (1.30×), matmul_nocustom (1.31×), relu_nocustom
  (1.49×). Grad_descent is mostly compute with few branches → BTB barely helps (1.02×).
- **Pipeline stalls dominate matmul** — back-to-back loads/stores create many load-use
  stalls, explaining the high pipeline cycle count vs single-cycle.

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

## Roadmap

- **Phase 0** ✅ Single-cycle RV32I, all 47 instructions (`cpu_top.v`)
- **Phase 1** ✅ 5-stage pipeline, forwarding, load-use stall, branch flush (`cpu_top_pipeline.v`)
- **Phase 2** ✅ 16-entry BTB + 2-bit saturating predictor (`cpu_top_pipelined_branch.v`)
- **Phase 3** ✅ M extension (MUL) + custom ML (MAC, ReLU) (`cpu_top_mext.v`)
- **Phase 4** ✅ RDCYC cycle counter, 3-operand MAC, single-cycle top, 9-benchmark suite, performance report (`cpu_top_mext_rdcyc.v`, `cpu_top_sc_rdcyc.v`)

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
