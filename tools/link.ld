/* ============================================================
 * Linker script for bare-metal RV32I single-cycle CPU.
 *
 * Harvard model:
 *   .text  -> IMEM, VMA = LMA = 0x00000000
 *   .data  -> DMEM, VMA = 0x00000000 (CPU address space)
 *                   LMA = 0x00010000 (DMEM_LMA — avoids linker
 *                         LMA overlap with .text at 0x0)
 *
 * Both memories are 16 KB. build.bat strips the 0x10000 LMA
 * offset with --change-addresses when producing data.hex, so
 * $readmemh still loads data into dmem.mem[0..N-1] correctly.
 * ============================================================ */

ENTRY(_start)

MEMORY
{
    IMEM     (rx)  : ORIGIN = 0x00000000, LENGTH = 16K
    DMEM     (rw)  : ORIGIN = 0x00000000, LENGTH = 16K
    DMEM_LMA (r)   : ORIGIN = 0x00010000, LENGTH = 16K
}

SECTIONS
{
    .text : {
        *(.text.init)         /* _start goes first */
        *(.text)
        *(.text.*)
    } > IMEM

    /* .rodata/.data live in DMEM (VMA 0x0) but their LMA is placed
       in DMEM_LMA (0x10000) to avoid overlap with .text LMA at 0x0.
       build.bat uses --change-addresses -65536 when extracting data.hex
       so that $readmemh sees addresses starting from 0. */
    .rodata : {
        *(.rodata)
        *(.rodata.*)
    } > DMEM AT> DMEM_LMA

    .data : {
        *(.data)
        *(.data.*)
        *(.sdata)
        *(.sdata.*)
    } > DMEM AT> DMEM_LMA

    .bss (NOLOAD) : {
        *(.bss)
        *(.bss.*)
        *(.sbss)
        *(.sbss.*)
        *(COMMON)
    } > DMEM

    /DISCARD/ : { *(.comment) *(.note.*) *(.eh_frame) *(.riscv.attributes) }
}
