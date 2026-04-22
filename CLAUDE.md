# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

RV32I CPU implemented in Verilog. Currently **5-stage pipelined**. The roadmap is to evolve into a **pipelined CPU with 2-bit branch prediction, M extension (MUL), and custom ML instructions (MAC, ReLU)** as an M.Tech term project. Target: Xilinx Vivado simulation, optional Artix-7 / Zynq synthesis.

**Harvard architecture**: separate instruction and data memories (both 16 KB, byte-addressable). No cache, no DRAM, no OS.

## Current state — Phase 3 complete, Phase 4 (RDCYC + Benchmarks) in design

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

New instructions:
| Instr | Opcode    | funct3 | funct7    | Semantics                       |
|-------|-----------|--------|-----------|---------------------------------|
| MUL   | `0110011` | `000`  | `0000001` | `rd = (rs1 * rs2)[31:0]`        |
| MAC   | `0001011` | `000`  | —         | `rd = rs1 + (rs1 * rs2)`        |
| RELU  | `0001011` | `001`  | —         | `rd = (rs1[31]) ? 0 : rs1`      |

**MAC encoding choice (Option B):** `rd = rs1 + rs1*rs2` — `rd` is a free
destination, accumulator source is `rs1`. Keeps the 2-port regfile.

New / modified files:
- `mul_unit.v` — NEW, single-cycle combinational multiplier + MAC + RELU.
  Vivado infers a DSP48 slice for the 32×32 signed multiply.
- `control_unit.v` — MODIFIED, added opcode `0001011` (custom-0) case.
  Sets `reg_write=1`, everything else default. Decode of MAC vs RELU
  happens in the top-level via `ex_op` (funct3).
- `cpu_top_mext.v` — NEW, Phase 3 top-level (based on Phase 2).
- `tb_cpu_top_mext.v` — NEW, self-contained TB; hand-assembles 13
  instructions and loads them directly into `uut.imem.mem` byte-by-byte
  (imem is byte-addressed little-endian — don't write 32-bit words to
  `mem[i]` indices!).

**Phase 3 design decisions (locked):**
- `ex_op[1:0]` decoded in ID (`01`=MUL, `10`=MAC, `11`=RELU, `00`=ALU).
  Propagated through ID/EX via inline register in the top-level (id_ex_reg
  module unchanged).
- EX stage result mux: `(ex_op == 00) ? ex_alu_result : ex_mul_result`.
  The muxed value is written into EX/MEM's `alu_result` slot so forwarding
  (which keys off `mem_rd`/`wb_rd`) handles MUL/MAC/RELU writes with
  zero changes to `forwarding_unit`.
- Branch unit still reads `ex_alu_result` (un-muxed) — branches never
  care about the mul_unit path.

**Switching between phases:**
- Phase 0 (single-cycle):  `tb_cpu_top`
- Phase 1 (5-stage):       `tb_cpu_top_pipeline`
- Phase 2 (+BTB):          `tb_cpu_top_pipelined_branch`
- Phase 3 (+MUL/MAC/RELU): `tb_cpu_top_mext`

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

To simulate a specific test in Vivado: copy/rename the two `.hex` files to `instructions.hex` and `data.hex` in the Vivado sim working directory, then run Behavioral Simulation on `tb_cpu_top` (single-cycle) or `tb_cpu_top_pipeline` (pipelined).

**Toolchain files** (in `tools/`):
- `link.ld` — linker script; `.text` → IMEM @ 0x0, `.rodata/.data/.bss` → DMEM @ 0x0
- `startup.S` — minimal `_start` that sets `sp = 0x4000` (top of DMEM) and calls `main`
- `build.bat` — one-command compile/link/objcopy pipeline

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
- **Phase 4** ⬅ *in progress*: 32-bit cycle counter (`RDCYC`), 4 C benchmarks (matmul, ReLU, dot product, fib), performance report

**Locked architectural decisions:**
- Branch resolves in EX (2-cycle flush penalty on mispredict)
- Each phase adds a new top-level file; Phase 0 modules only modified for ISA extensions (`control_unit.v` updated in Phase 3)
- MAC encoding (Option B): `rd = rs1 + rs1*rs2` — `rd` is free, only 2 regfile reads

### Phase 4 — Cycle counter + Benchmarks (design locked, awaiting implementation)

**RDCYC instruction — reads cycle counter into `rd`:**
- **Encoding:** opcode=`0001011` (custom-0), funct3=`010` (to avoid MAC `000` and RELU `001`), rs1=unused, rs2=unused
  - Binary: `0000000_00000_00000_010_rd_0001011`
  - Semantics: `rd = cycle_counter` (side-effect-free read)
- **Cycle counter register:**
  - 32-bit free-running counter, auto-increments on every clock after reset release
  - Never wraps (or wraps to 0 at 2^32, but benchmarks won't reach that)
  - Read combinationally in WB (no write port)
- **Integration into cpu_top_mext.v:**
  - ID stage: Decode RDCYC via `id_is_rdcyc = (id_opcode == 7'b0001011) && (id_funct3 == 3'b010)`
  - Add to `id_ex_op` decoder: `id_ex_op = ... id_is_rdcyc ? 2'b00 : ... ` (treat as third special op, OR widen ex_op to 3 bits)
  - **Cleaner approach:** Widen `ex_op` to 3 bits: `00`=ALU, `01`=MUL, `10`=MAC, `11`=RELU, `100`=RDCYC
  - EX stage result mux: add `(ex_op == 3'b100) ? cycle_counter : ...` before existing `(ex_op == 2'b00) ? alu : mul` logic
  - Cycle counter register: instantiate as a simple `always @(posedge clk)` counter in the top-level
  - Update CLAUDE.md after Phase 4 implementation with final opcode choices

**Benchmark programs (C source → hand-assemble or use custom toolchain directives):**

1. **Matmul (8×8 int32, in `.data` section):**
   - Initialize 8×8 matrices A, B in DMEM
   - C[i][j] = Σ(A[i][k] * B[k][j]) for k ∈ [0, 7]
   - Uses MUL per element, 512 multiplies total
   - Expected: ~650–800 cycles (pipelined with forwarding)

2. **ReLU (32-element array):**
   - Load array from DMEM
   - For each element: `y[i] = (x[i] < 0) ? 0 : x[i]` via RELU instr
   - 32 ReLU ops
   - Expected: ~100–150 cycles

3. **Dot product (16-element vectors):**
   - Σ(A[i] * B[i]) for i ∈ [0, 15]
   - Uses MAC (or MUL + ADD sequence)
   - 16 MACs (or 32 ops if MUL+ADD)
   - Expected: ~100–200 cycles depending on forwarding

4. **Fibonacci (fib(20)):**
   - Recursive or iterative; stress branch prediction (BTB in Phase 2+)
   - Many branches → shows BTB benefit vs always-not-taken
   - Expected: Phase 0 ~5000 cycles, Phase 2 ~3500 cycles (BTB saves ~30%)

**Performance measurement approach:**
- Write all 4 benchmarks as C source (no M-ext asm directives yet — assemble manually or via `__asm__` inline)
- Compile each for Phase 0 (single-cycle) → Phase 3 (with BTB+MUL)
- In each testbench, read `cycle_counter` at start and end: `cycles_elapsed = end_count - start_count`
- Table results (Phases 0 → 3, per benchmark):

  | Benchmark | Phase 0 | Phase 1 | Phase 2 | Phase 3 | Phase 1 speedup | Phase 2 speedup | Phase 3 speedup |
  |-----------|---------|---------|---------|---------|-----------------|-----------------|-----------------|
  | Matmul    | ~900    | ~750    | ~700    | ~600    | 1.2×            | 1.3×            | 1.5×            |
  | ReLU      | ~160    | ~140    | ~130    | ~110    | 1.1×            | 1.2×            | 1.5×            |
  | DotProd   | ~400    | ~350    | ~330    | ~280    | 1.1×            | 1.2×            | 1.4×            |
  | Fib(20)   | ~8000   | ~7200   | ~5500   | ~5500   | 1.1×            | 1.5×            | 1.5×            |

- Include waveform snapshots (one per benchmark showing MUL, forwarding, BTB mispredict)

**Testing procedure (per phase):**
1. Assemble benchmark to `.hex` files → place in Vivado sim directory
2. Set appropriate testbench as top (tb_cpu_top / tb_cpu_top_pipeline / tb_cpu_top_pipelined_branch / tb_cpu_top_mext_with_rdcyc)
3. Run Behavioral Simulation for enough cycles to complete benchmark
4. Read cycle count from RDCYC register or add display statements
5. Tabulate and compare

**Files to add/modify in Phase 4:**
- `cpu_top_mext_rdcyc.v` (or extend `cpu_top_mext.v`) — widen `ex_op`, add cycle counter, RDCYC decode
- `tb_cpu_top_mext_rdcyc.v` — testbench that runs a single benchmark, reports cycle count
- `tests/matmul_8x8.c`, `tests/relu_32.c`, `tests/dotprod_16.c`, `tests/fib_20.c` — benchmark sources
- Update CLAUDE.md after implementation with final design decisions and results table
