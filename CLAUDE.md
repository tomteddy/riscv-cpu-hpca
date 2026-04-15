# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

RV32I CPU implemented in Verilog. Currently **single-cycle**. The roadmap is to evolve into a **5-stage pipeline with forwarding, load-use stall, 2-bit branch prediction, M extension (MUL), and custom ML instructions (MAC, ReLU)** as an M.Tech term project. Target: Xilinx Vivado simulation, optional Artix-7 / Zynq synthesis.

**Harvard architecture**: separate instruction and data memories (both 16 KB, byte-addressable). No cache, no DRAM, no OS.

## Current state — Phase 0 complete

Single-cycle CPU is stabilized and cleaned up. All 47 RV32I instructions work. Changes since initial commit:

- `data_memory.v` — address now masked to `addr[13:0]` to prevent out-of-range access
- `instruction_memory.v` — now byte-addressable (was word-wide), matches dmem style; loads from `@`-addressed byte-wise hex
- `branch_unit.v` — new module; branch evaluation extracted from `cpu_top.v`
- `cpu_top.v` — rewritten as pure wiring/muxing, no inline logic
- All modules — trimmed verbose boilerplate comments, standardized naming (`rs1_data`, `rs2_data`)
- `instructions.hex` — converted from word-per-line to `@`-addressed byte-wise little-endian format

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

To simulate a specific test in Vivado: copy/rename the two `.hex` files to `instructions.hex` and `data.hex` in the Vivado sim working directory, then run Behavioral Simulation on `tb_cpu_top`.

**Toolchain files** (in `tools/`):
- `link.ld` — linker script; `.text` → IMEM @ 0x0, `.rodata/.data/.bss` → DMEM @ 0x0
- `startup.S` — minimal `_start` that sets `sp = 0x4000` (top of DMEM) and calls `main`
- `build.bat` — one-command compile/link/objcopy pipeline

## Running simulations

**Existing 47-instruction integration test** (no C required):
- Top module: `tb_cpu_top`
- Reads `instructions.hex` (committed, pre-generated)
- Verifies all registers and memory via hierarchical references
- Check Vivado Tcl console for `PASS`/`FAIL`

**Unit tests**: set `tb_<module>` as simulation top (e.g. `tb_alu`, `tb_control_unit`) and run Behavioral Simulation.

**Data memory init**: `tb_cpu_top.v` calls `$readmemh("data.hex", uut.dmem.mem)` — missing file is harmless, just emits a warning.

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

## Roadmap (phases ahead)

- **Phase 1**: 5-stage pipeline (IF/ID/EX/MEM/WB) with explicit pipeline-register modules, forwarding unit (EX→EX, MEM→EX), load-use stall, branch flush on mispredict (branch resolves in EX, 2-cycle penalty)
- **Phase 2**: BTB + 2-bit saturating predictor in IF
- **Phase 3**: M extension (MUL), then custom ML instructions (MAC, ReLU) in opcode `0001011`
- **Phase 4**: Cycle counter (`RDCYC` custom instr), C benchmarks (matmul, ReLU, fib), report

Branch-in-EX with 2-cycle flush is the locked pipelining strategy. MAC uses `rs1 += rs1 * rs2` encoding (no third regfile port needed).
