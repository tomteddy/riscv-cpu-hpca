/* ============================================================
 * custom_ops.S : bare-metal wrappers for custom CPU instructions.
 *
 * Each function follows the RV32I/ilp32 calling convention:
 *   - First arg  : a0 (x10)
 *   - Second arg : a1 (x11)
 *   - Return val : a0 (x10)
 *
 * Instructions are emitted as .word literals so the assembler
 * does not need to know the ISA extension encoding.
 *
 * Instruction encodings (hand-computed):
 *
 *   MUL  a0, a0, a1  ->  0x02B50533
 *     opcode=0110011 funct7=0000001 funct3=000 rd=10 rs1=10 rs2=11
 *
 *   MAC  a0, a0, a1  ->  0x00B5050B
 *     opcode=0001011 funct3=000 rd=10 rs1=10 rs2=11
 *     semantics: a0 = a0 + (a0 * a1)
 *
 *   RELU a0, a0      ->  0x0005150B
 *     opcode=0001011 funct3=001 rd=10 rs1=10 rs2=00000
 *     semantics: a0 = (a0 < 0) ? 0 : a0
 *
 *   RDCYC a0         ->  0x0000250B
 *     opcode=0001011 funct3=010 rd=10 rs1=00000 rs2=00000
 *     semantics: a0 = cycle_counter
 * ============================================================ */

    .section .text
    .align 2

/* int mul_custom(int a, int b)  ->  a * b  (lower 32 bits, signed) */
    .globl mul_custom
mul_custom:
    .word 0x02B50533        /* MUL a0, a0, a1 */
    ret

/* int mac_custom(int a, int b)  ->  a + (a * b) */
    .globl mac_custom
mac_custom:
    .word 0x00B5050B        /* MAC a0, a0, a1 */
    ret

/* int relu_custom(int a)        ->  max(a, 0) */
    .globl relu_custom
relu_custom:
    .word 0x0005150B        /* RELU a0, a0 */
    ret

/* int rdcyc(void)               ->  current cycle counter value */
    .globl rdcyc
rdcyc:
    .word 0x0000250B        /* RDCYC a0 */
    ret
