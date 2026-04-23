/*
 * dotprod_16.c — dot product of two 16-element vectors using mac3_custom.
 *
 * A[i] = i + 1   (1..16)
 * B[i] = i + 1   (1..16)
 * dot  = Σ_{i=0}^{15} A[i]*B[i] = Σ_{i=1}^{16} i^2 = 1496
 *
 * Uses mac3_custom(acc, a, b) = acc + a*b  (3-operand MAC, Phase 4).
 * Inner loop: dot = mac3_custom(dot, A[i], B[i])
 *   => one MAC instruction per element (vs MUL+ADD = 2 instrs).
 *
 * Compile:  tools\build.bat tests\dotprod_16.c
 */

#include "../tools/custom_ops.h"

#define N 16

int A[N] = { 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15,16 };
int B[N] = { 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15,16 };

int result;

int main(void) {
    int i;
    int dot = 0;
    for (i = 0; i < N; i++)
        dot = mac3_custom(dot, A[i], B[i]);
    result = dot;   /* store so compiler can't eliminate loop */
    return 0;
}
