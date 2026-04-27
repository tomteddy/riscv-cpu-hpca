/* validate.h — Phase 4 benchmark validation block convention.
 *
 * Each benchmark calls validate_write(id, results, n) right before halting.
 * It writes a structured block at DMEM byte address 0x3F00:
 *
 *   word 0  : magic = 0xBEEF0000 | id   (TB looks this up)
 *   word 1  : n                          (number of result words)
 *   word 2+ : result[0..n-1]
 *
 * The TB reads this block at halt, identifies the benchmark by id, and
 * compares result words against a hardcoded expected table.
 *
 * Block lives at 0x3F00..0x3FFF (last 256 bytes of 16 KB DMEM) so it
 * never overlaps with normal globals/stack.
 */
#ifndef VALIDATE_H
#define VALIDATE_H

static inline void validate_write(int id, int *results, int n) {
    volatile int *v = (volatile int *)0x3F00;
    int i;
    v[0] = 0xBEEF0000 | id;
    v[1] = n;
    for (i = 0; i < n; i++) v[2 + i] = results[i];
}

#define BENCH_ID_FIB_20              1
#define BENCH_ID_DOTPROD_16          2
#define BENCH_ID_DOTPROD_16_NOCUST   3
#define BENCH_ID_MATMUL_8X8          4
#define BENCH_ID_MATMUL_8X8_NOCUST   5
#define BENCH_ID_RELU_32             6
#define BENCH_ID_RELU_32_NOCUST      7
#define BENCH_ID_GRAD_DESC           8
#define BENCH_ID_GRAD_DESC_NOCUST    9

#endif
