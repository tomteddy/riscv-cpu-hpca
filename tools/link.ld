/* ============================================================
 * Linker script for bare-metal RV32I single-cycle CPU.
 *
 * Harvard model:
 *   .text  -> instruction memory, VMA starts at 0x00000000
 *   .data  -> data memory,        VMA starts at 0x00000000
 *             (separate address space, loaded via data.hex)
 *
 * Both memories are 16 KB. Keep programs + data well below.
 * ============================================================ */

ENTRY(_start)

MEMORY
{
    IMEM (rx)  : ORIGIN = 0x00000000, LENGTH = 16K
    DMEM (rw)  : ORIGIN = 0x00000000, LENGTH = 16K
}

SECTIONS
{
    .text : {
        *(.text.init)         /* _start goes first */
        *(.text)
        *(.text.*)
    } > IMEM

    /* .rodata lives in DMEM — Harvard CPU cannot read IMEM as data.
       Loads of const arrays go through the data-memory path. */
    .rodata : {
        *(.rodata)
        *(.rodata.*)
    } > DMEM

    .data : {
        *(.data)
        *(.data.*)
        *(.sdata)
        *(.sdata.*)
    } > DMEM

    .bss : {
        *(.bss)
        *(.bss.*)
        *(.sbss)
        *(.sbss.*)
        *(COMMON)
    } > DMEM

    /DISCARD/ : { *(.comment) *(.note.*) *(.eh_frame) *(.riscv.attributes) }
}
