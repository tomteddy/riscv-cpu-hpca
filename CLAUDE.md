# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

RV32I CPU implemented in Verilog. Currently **5-stage pipelined**. The roadmap is to evolve into a **pipelined CPU with 2-bit branch prediction, M extension (MUL), and custom ML instructions (MAC, ReLU)** as an M.Tech term project. Target: Xilinx Vivado simulation, optional Artix-7 / Zynq synthesis.

**Harvard architecture**: separate instruction and data memories (both 16 KB, byte-addressable). No cache, no DRAM, no OS.

## Current state — Phase 1 complete

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
- **Phase 2** ⬅ *next*: BTB + 2-bit saturating predictor in IF stage
- **Phase 3**: M extension (MUL), then custom ML instructions (MAC, ReLU) in opcode `0001011`
- **Phase 4**: Cycle counter (`RDCYC` custom instr), C benchmarks (matmul, ReLU, fib), report

**Locked architectural decisions:**
- Branch resolves in EX (2-cycle flush penalty on mispredict)
- Each phase adds a new top-level file; Phase 0 modules only modified in Phase 3 (ISA extension)
- MAC encoding: `rs1 += rs1 * rs2` (no third regfile port needed)

**Phase 2 design notes (for next session):**
- BTB sits in IF stage, indexed by PC bits
- 2-bit saturating counter per BTB entry: 00=strong-not-taken, 01=weak-not-taken, 10=weak-taken, 11=strong-taken
- On BTB hit + predict taken: PC jumps to BTB target immediately in IF (0-cycle penalty)
- On mispredict (resolved in EX): flush IF+ID, update BTB entry and counter
- On BTB miss: fall through to current always-not-taken behavior
- New files expected: `btb.v`, updated `cpu_top_pipeline.v` or new `cpu_top_pipeline2.v`
