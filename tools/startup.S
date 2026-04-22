/* ============================================================
 * startup.S : minimal bare-metal entry point.
 *   - Sets up stack pointer at top of DMEM (16 KB)
 *   - Calls main()
 *   - On return, halts by jumping to self (infinite loop)
 * No .bss zeroing (testbench inits DMEM to 0).
 * ============================================================ */

    .section .text.init
    .globl _start
_start:
    la   sp, 0x4000          /* stack top = end of 16 KB DMEM */
    call main
halt:
    beq zero, zero, halt     /* spin forever — BEQ so BTB can predict it,
                                keeping if_pc_out stable for halt detection.
                                (JAL would cause 2-cycle flush every iteration,
                                 making if_pc_out cycle 3 addresses → timeout) */
