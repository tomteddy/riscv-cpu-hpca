# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

RV32I CPU implemented in Verilog. Currently **5-stage pipelined**. The roadmap is to evolve into a **pipelined CPU with 2-bit branch prediction, M extension (MUL), and custom ML instructions (MAC, ReLU)** as an M.Tech term project. Target: Xilinx Vivado simulation, optional Artix-7 / Zynq synthesis.

**Harvard architecture**: separate instruction and data memories (both 16 KB, byte-addressable). No cache, no DRAM, no OS.

## Current state — Phase 3 complete

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
- **Phase 4** ⬅ *next*: Cycle counter (`RDCYC` custom instr), C benchmarks (matmul, ReLU, fib), report

**Locked architectural decisions:**
- Branch resolves in EX (2-cycle flush penalty on mispredict)
- Each phase adds a new top-level file; Phase 0 modules only modified for ISA extensions (`control_unit.v` updated in Phase 3)
- MAC encoding (Option B): `rd = rs1 + rs1*rs2` — `rd` is free, only 2 regfile reads

**Phase 4 design notes (for next session):**
- `RDCYC rd` reads a 32-bit free-running cycle counter into `rd`
- Counter increments every clock after reset
- Use opcode `0001011` (custom-0) with a new funct3 (e.g. `010`) to
  avoid colliding with MAC (`000`) and RELU (`001`)
- Decode in ID as another `ex_op` value, or widen `ex_op` to 3 bits;
  result mux in EX selects the counter register
- Deferred: C benchmarks and performance report (need Vivado runs)
